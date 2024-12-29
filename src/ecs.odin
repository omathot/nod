package nod

Entity_ID :: distinct u64
MAX_ENTITIES :: 10_000

World :: struct {
	// entities
	entities:          [MAX_ENTITIES]Entity_ID,
	entity_count:      int,
	next_entity_id:    Entity_ID,

	// components
	core:              Core,
	custom_components: map[string]rawptr,
}

Core :: struct {
	transform: [MAX_ENTITIES]Transform,
	velocity:  [MAX_ENTITIES]Vec2,
}

