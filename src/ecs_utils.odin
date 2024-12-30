package nod

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

	// systems
	systems:             [dynamic]System,
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

