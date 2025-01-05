package nod

import "core:sync"
import "core:thread"

EntityID :: distinct u64
SystemID :: distinct u32
ComponentID :: distinct u32

MAX_ENTITIES :: 10_000
MAX_COMPONENTS :: 100

ECSManager :: struct {
	world: ^World,
}

// represents a unique combination of components
Archetype :: struct {
	id:             u64, // hash of component combination
	component_mask: bit_set[0 ..= MAX_COMPONENTS],
	entities:       [dynamic]EntityID,
}

// internally gonna be using stride to move between components, ADDING A NEW COMPONENT REQUIRES RESIZING
Column :: struct {
	data:     rawptr,
	size:     int, // size of each element
	stride:   int, // nbr of bytes between consecutive elements
	count:    int, // nbr of elements
	capacity: int, // total number of elements that can be stored
}

// Component metadata
ComponentType :: struct {
	id:        ComponentID,
	size:      int,
	alignment: int,
}

// Only accessible to the user through their nod_instance until they call nod_run(), then must query from World
World :: struct {
	// entities
	entities:            [MAX_ENTITIES]EntityID,
	entity_count:        int,
	next_entity_id:      EntityID,
	free_entities:       [dynamic]EntityID, // list of IDs that were assigned but are now free for re-usage

	// components
	component_types:     #soa[MAX_COMPONENTS]ComponentType,
	component_count:     int,

	// storage
	archetypes:          map[u64]Archetype,
	columns:             map[u64]map[ComponentID]Column, // a map <ArchetypeID, k> where k = map <ComponentId, Column>, where column is Component data

	// lookup
	entity_to_archetype: map[EntityID]u64,
	system_map:          map[SystemID]^System,
	component_registry:  ComponentRegistry,

	// systems
	systems:             [dynamic]System,

	// job system
	job_system:          ^JobSystem,

	// Queriable resources
	resources:           ^Resources,
}


// User helpers
Query :: struct {
	world:                ^World,
	required_component:   bit_set[0 ..= MAX_COMPONENTS],
	excluded_coomponents: bit_set[0 ..= MAX_COMPONENTS],
	match_archetype:      []Archetype,
}

QueryIterator :: struct {
	query:           ^Query,
	archetype_index: int,
	entity_index:    int,
}

// user logic
System :: struct {
	id:                  SystemID,
	name:                string,
	required_components: bit_set[0 ..= MAX_COMPONENTS],
	update_proc:         proc(world: ^World, dt: f32),
}

SystemGroup :: struct {
	systems: [dynamic]SystemID,
	enabled: bool,
}

ComponentRegistry :: struct {
	type_to_id:       map[typeid]ComponentID,
	registered_types: [dynamic]ComponentType,
	next_id:          ComponentID,
}

create_component_registry :: proc() -> ComponentRegistry {
	return ComponentRegistry {
		type_to_id = make(map[typeid]ComponentID),
		registered_types = make([dynamic]ComponentType),
		next_id = 0,
	}
}

destroy_component_registry :: proc(registry: ^ComponentRegistry) {
	delete(registry.type_to_id)
	delete(registry.registered_types)
}

get_or_register_component :: proc(world: ^World, $T: typeid) -> ComponentID {
	// already exists
	if id, ok := world.component_registry.type_to_id[T]; ok {
		return id
	}

	// do the work
	ti := type_info_of(T)

	id := world.component_registry.next_id
	world.component_registry.next_id += 1

	component_type := ComponentType {
		id        = id,
		size      = ti.size,
		alignment = ti.align,
	}

	append(&world.component_registry.registered_types, component_type)
	world.component_registry.type_to_id[T] = id

	world.component_types[world.component_count] = component_type
	world.component_count += 1
	return id
}


is_component_registered :: proc(world: ^World, $T: typeid) -> (ComponentType, bool) {
	_, ok := world.component_registry.type_to_id[T]
	return ok
}

get_component_info :: proc(world: ^World, $T: typeid) -> (ComponentType, bool) {
	if id, ok := world.component_registry.type_to_id[T]; ok {
		for component in world.component_registry.registered_types {
			if component.id == id {
				return component, true
			}
		}
	}
	return ComponentType{}, false
}

get_component_id :: proc(world: ^World, $T: typeid) -> (ComponentID, bool) {
	id, ok := world.component_registry.type_to_id[T]
	return id, ok
}

