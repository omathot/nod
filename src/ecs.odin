package nod

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

create_world :: proc() -> ^World {
	world := new(World)

	world.next_entity_id = 1
	world.entity_count = 0
	world.component_count = 0
	world.archetypes = make(map[u64]Archetype)
	world.columns = make(map[u64]map[ComponentID]Column)
	world.systems = make([dynamic]System)
	world.free_entities = make([dynamic]EntityID)
	world.entity_to_archetype = make(map[EntityID]u64)
	return world
}

destroy_world :: proc(world: ^World) {
	for archetype_id, columns in world.columns {
		for _, column in columns {
			free(column.data)
		}
		delete(columns)
	}
	delete(world.columns)

	delete(world.archetypes)
	delete(world.systems)
	delete(world.free_entities)
	delete(world.entity_to_archetype)

	free(world)
}

register_component :: proc(world: ^World, id: $T) -> ComponentID {
	type_info := type_info_of(T)
	id := ComponentID(world.component_count)

	world.component_types[world.component_count] = ComponentType {
		id        = id,
		name      = type_info.name,
		size      = type_info.size,
		alignment = type_info.align,
	}
	world.component_count += 1
	return id
}

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
		fmt.println("new archetype ID not found in world.archetypes")
		world.archetypes[new_id] = Archetype {
			id             = new_id,
			component_mask = new_mask,
			entities       = make([dynamic]EntityID),
		}
		world.columns[new_id] = make(map[ComponentID]Column)

		// init columns for all components in new archetype
		for id := ComponentID(0); id < ComponentID(world.component_count); id += 1 {
			if int(id) in new_mask {
				component_type := world.component_types[id]
				column := &world.columns[new_id][id]
				column.size = component_type.size
				column.stride = component_type.size
				column.count = 0
				column.capacity = 8
				data_ptr, err := mem.alloc(component_type.size * 8)
				if err != .None {
					fmt.println("Failed to resize columns in add_component()")
					return err
				}
				column.data = data_ptr
			}
		}
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
						old_idx = 1
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

	append_elem(&archetype.entities, entity)
	world.entity_to_archetype[entity] = new_id

	return .None

}

