package nod

EntityID :: distinct u64
MAX_ENTITIES :: 10_000

World :: struct {
	// entities
	entities:          [MAX_ENTITIES]EntityID,
	entity_count:      int,
	next_entity_id:    EntityID,

	// components
	core:              Core,
	custom_components: map[string]rawptr,
}

Core :: struct {
	transform: [MAX_ENTITIES]Transform,
	velocity:  [MAX_ENTITIES]Vec2,
}

