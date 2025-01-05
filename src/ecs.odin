package nod

import "core:container/queue"
import "core:fmt"
import "core:hash"
import "core:mem"

/*
	goals:
		- Components of the same type stored together in CONTIGUOUS MEMORY, !NOT! under the entity they belong to
		- FAST
		- Entity -> Archetype lookup table
		- Custom user components
		- Custom user systems
		- simple API but lets implement the skeleton first
*/


// dont ask
@(private)
hash_mask :: proc(mask: bit_set[0 ..= MAX_COMPONENTS]) -> u64 {
	bytes: [MAX_COMPONENTS / 8 + 1]u8
	for i := 0; i < MAX_COMPONENTS; i += 1 {
		if i in mask {
			bytes[i / 8] |= 1 << uint(i % 8)
		}
	}

	return hash.fnv64(bytes[:])
}

@(private)
resize_column :: proc(column: ^Column, new_capacity: int) -> mem.Allocator_Error {
	new_data, err := mem.alloc(new_capacity * column.stride)
	if err != .None {
		return err
	}
	mem.copy(new_data, column.data, column.count * column.stride)
	mem.free(column.data)
	column.data = new_data
	column.capacity = new_capacity
	return .None
}

create_world :: proc(job_system: ^JobSystem) -> ^World {
	world := new(World)

	world.next_entity_id = 1
	world.entity_count = 0

	world.component_registry = create_component_registry()
	world.component_count = 0
	world.archetypes = make(map[u64]Archetype)
	world.columns = make(map[u64]map[ComponentID]Column)
	world.systems = make([dynamic]System)
	world.free_entities = make([dynamic]EntityID)
	world.entity_to_archetype = make(map[EntityID]u64)
	world.system_map = make(map[SystemID]^System)
	world.job_system = job_system

	world.resources = create_resources()

	init_tag_system()

	input_state := new(InputState)
	init_input_state(input_state)
	insert_resource(world.resources, InputState, input_state^)
	free(input_state)

	physics_world: PhysicsWorld
	physics_init_world(&physics_world)
	insert_resource(world.resources, PhysicsWorld, physics_world)

	insert_resource(
		world.resources,
		TimeResource,
		TimeResource{delta_time = 0, total_time = 0, fixed_delta = f32(FIXED_DT)},
	)

	return world
}

destroy_world :: proc(world: ^World) {
	if world != nil {
		// Clean up input state
		if input_state, err := get_resource(world.resources, InputState); err == .None {
			cleanup_input_state(input_state)
		}
		destroy_resources(world.resources)

		cleanup_tags()
		destroy_component_registry(&world.component_registry)

		// components
		for archetype_id, columns in world.columns {
			for _, column in columns {
				free(column.data)
			}
			delete(columns)
		}
		delete(world.columns)

		// archetypes
		for _, archetype in &world.archetypes {
			delete(archetype.entities)
		}
		delete(world.archetypes)

		// rest
		delete(world.systems)
		delete(world.free_entities)
		delete(world.entity_to_archetype)
		delete(world.system_map)

		free(world)

	}
}


// ----------------------------------------
//----------------USER SPACE---------------
// ----------------------------------------

// __COMPONENTS

// !! LEGACY CODE FROM BEFORE ComponentRegistry !! delete 

register_component :: proc(world: ^World, $T: typeid) -> ComponentID {
	type_info := type_info_of(T)
	id := ComponentID(world.component_count)

	world.component_types[world.component_count] = ComponentType {
		id        = id,
		size      = type_info.size,
		alignment = type_info.align,
	}
	world.component_count += 1
	return id
}

// !DEBUG function
// register_component :: proc(world: ^World, $T: typeid) -> ComponentID {
// 	type_info := type_info_of(T)
// 	id := ComponentID(world.component_count)

// 	fmt.println("Registering component:")
// 	fmt.println("  Type:", type_info_of(T))
// 	fmt.println("  Size:", type_info.size)
// 	fmt.println("  Alignment:", type_info.align)
// 	fmt.println("  Component ID:", id)

// 	world.component_types[world.component_count] = ComponentType {
// 		id        = id,
// 		size      = type_info.size,
// 		alignment = type_info.align,
// 	}
// 	world.component_count += 1
// 	return id
// }

create_entity :: proc(world: ^World) -> EntityID {
	id: EntityID
	if len(world.free_entities) > 0 {
		id = pop(&world.free_entities)
	} else {
		id = world.next_entity_id
		world.next_entity_id += 1
	}

	world.entities[world.entity_count] = id
	world.entity_count += 1
	return id
}

destroy_entity :: proc(world: ^World, entity: EntityID) {
	// remove from archetype
	if archetype_id, ok := world.entity_to_archetype[entity]; ok {
		archetype := &world.archetypes[archetype_id]
		for i := 0; i < len(archetype.entities); i += 1 {
			if archetype.entities[i] == entity {
				ordered_remove(&archetype.entities, i)
				break
			}
		}
		delete_key(&world.entity_to_archetype, entity) // update lookup
	}
	if world.resources != nil {
		if physics_world, err := get_resource(world.resources, PhysicsWorld); err == .None {
			destroy_physics_body(physics_world, entity)
		}
	}
	append_elem(&world.free_entities, entity)
}

add_component :: proc(
	world: ^World,
	entity: EntityID,
	component: ComponentID,
	data: rawptr,
) -> mem.Allocator_Error {
	// checks if already exists
	current_id, ok := world.entity_to_archetype[entity]
	current_mask: bit_set[0 ..= MAX_COMPONENTS]
	if ok {
		fmt.println("Found entity archetype")
		current_mask = world.archetypes[current_id].component_mask
	}

	// matching archetype not found
	new_mask := current_mask + {int(component)}
	new_id := hash_mask(new_mask)

	if new_id not_in world.archetypes {
		columns := make(map[ComponentID]Column)

		// init columns for all components in new archetype
		for id := ComponentID(0); id < ComponentID(world.component_count); id += 1 {
			if int(id) in new_mask {
				component_type := world.component_types[id]

				// Allocate memory first
				data_ptr, err := mem.alloc(component_type.size * 8)
				if err != .None {
					fmt.println("Failed to allocate memory for column")
					return err
				}

				// Insert the full column value into the map
				columns[id] = Column {
					data     = data_ptr,
					size     = component_type.size,
					stride   = component_type.size,
					count    = 0,
					capacity = 8,
				}
			}
		}

		// Create the archetype first
		world.archetypes[new_id] = Archetype {
			id             = new_id,
			component_mask = new_mask,
			entities       = make([dynamic]EntityID),
		}

		// Then assign the columns
		world.columns[new_id] = columns
	}
	// move entity to new archetype
	archetype := &world.archetypes[new_id]
	columns := &world.columns[new_id]

	// If entity was in a previous archetype, copy existing component data
	if ok {
		old_columns := &world.columns[current_id]
		for id := ComponentID(0); id < ComponentID(world.component_count); id += 1 {
			if int(id) in current_mask {
				old_col := &old_columns[id]
				new_col := &columns[id]

				old_idx := -1
				old_arch := &world.archetypes[current_id]
				for i := 0; i < len(old_arch.entities); i += 1 {
					if old_arch.entities[i] == entity {
						old_idx = i
						break
					}
				}

				if old_idx >= 0 {
					old_ptr := rawptr(uintptr(old_col.data) + uintptr(old_idx * old_col.stride))
					new_ptr := rawptr(
						uintptr(new_col.data) + uintptr(new_col.count * new_col.stride),
					)
					mem.copy(new_ptr, old_ptr, new_col.size)
				}
			}
		}
		// remove entity id from old archetype
		for i := 0; i < len(world.archetypes[current_id].entities); i += 1 {

			if world.archetypes[current_id].entities[i] == entity {
				to_remove := &world.archetypes[current_id]
				ordered_remove(&to_remove.entities, i)
				break
			}
		}
	}

	// add new component data
	col := &columns[component]
	t := size_of(col.data)
	if col.count > col.capacity {
		new_capacity := max(8, 2 * col.capacity)
		err := resize_column(col, new_capacity)
		if err != .None {
			fmt.println("Error during column resizing")
			return err
		}
	}

	dest := rawptr(uintptr(col.data) + uintptr(col.count * col.stride))
	mem.copy(dest, data, col.size)
	col.count += 1

	append_elem(&archetype.entities, entity) // !!! leak 64 bytes
	world.entity_to_archetype[entity] = new_id

	return .None

}

query :: proc(
	world: ^World,
	required: bit_set[0 ..= MAX_COMPONENTS],
	excluded: bit_set[0 ..= MAX_COMPONENTS] = {},
) -> Query {
	matching := make([dynamic]Archetype)

	// find matches
	for _, archetype in world.archetypes {
		// check for ALL required components
		if required & archetype.component_mask != required {
			continue
		}

		if excluded & archetype.component_mask != {} {
			continue
		}

		append(&matching, archetype)
	}

	return Query {
		world = world,
		required_component = required,
		excluded_coomponents = excluded,
		match_archetype = matching[:],
	}
}

iterate_query :: proc(query: ^Query) -> QueryIterator {
	return QueryIterator{query = query, archetype_index = 0, entity_index = 0}
}

next_entity :: proc(iter: ^QueryIterator) -> (EntityID, bool) {
	for iter.archetype_index < len(iter.query.match_archetype) {
		archetype := &iter.query.match_archetype[iter.archetype_index]

		if iter.entity_index < len(archetype.entities) {
			entity := archetype.entities[iter.entity_index]
			iter.entity_index += 1
			return entity, true
		}
		iter.archetype_index += 1
		iter.entity_index = 0
	}

	return 0, false
}

get_component :: proc(world: ^World, id: EntityID, component: ComponentID) -> (rawptr, bool) {
	archetype_id, a_ok := world.entity_to_archetype[id]
	if !a_ok {
		return nil, false
	}

	columns, c_ok := &world.columns[archetype_id]
	if !c_ok {
		return nil, false
	}

	column, d_ok := columns[component]
	if !d_ok {
		return nil, false
	}

	archetype := &world.archetypes[archetype_id]
	entity_idx := -1
	for i := 0; i < len(archetype.entities); i += 1 {
		if archetype.entities[i] == id {
			entity_idx += 1
			break
		}
	}

	if entity_idx == -1 {
		return nil, false
	}

	data_ptr := rawptr(uintptr(column.data) + uintptr(entity_idx * column.stride)) // data[0] + (idx * size)
	return data_ptr, true
}

// for user type safety
get_component_typed :: proc(
	world: ^World,
	id: EntityID,
	component_id: ComponentID,
	$T: typeid,
) -> (
	^T,
	bool,
) {
	data, ok := get_component(world, id, component_id)
	if !ok {
		return nil, false
	}
	return cast(^T)data, true
}

get_input :: proc(world: ^World) -> ^InputState {
	if input, err := get_resource(world.resources, InputState); err == .None {
		return input
	}
	return nil
}


// ___SYSTEMS
system_add :: proc(
	world: ^World,
	name: string,
	required_components: bit_set[0 ..= MAX_COMPONENTS],
	fn: proc(_: ^World, _: f32),
) -> SystemID {
	system := System {
		id                  = SystemID(len(world.systems)),
		name                = name,
		required_components = required_components,
		update_proc         = fn,
	}

	append(&world.systems, system)
	world.system_map[system.id] = &world.systems[len(world.systems) - 1] // update system lookup map
	return system.id
}

system_remove :: proc(world: ^World, id: SystemID) {
	for i := 0; i < len(world.systems); i += 1 {
		if world.systems[i].id == id {
			ordered_remove(&world.systems, i)
			delete_key(&world.system_map, id) // update system lookup

			// update map pointers, ordered_remove moved elements
			for j := i; j < len(world.systems); j += 1 {
				world.system_map[world.systems[j].id] = &world.systems[j]
			}

			break
		}
	}
}

systems_update :: proc(world: ^World, dt: f32) {
	for system in world.systems {
		system.update_proc(world, dt) // i feel so fancy
	}
}

system_create_group :: proc() -> SystemGroup {
	return SystemGroup{systems = make([dynamic]SystemID), enabled = true}
}

system_add_to_group :: proc(group: ^SystemGroup, id: SystemID) {
	append(&group.systems, id)
}

system_update_group :: proc(world: ^World, group: ^SystemGroup, dt: f32) {
	if !group.enabled {
		return
	}

	for id in group.systems {
		if system, ok := world.system_map[id]; ok {
			system.update_proc(world, dt)
		}
	}
}

