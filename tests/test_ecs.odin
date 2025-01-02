package tests

import nod "../src"
import "core:log"
import test "core:testing"

TestComponent :: struct {
	v: u32,
}

@(test)
ecs_world_creation :: proc(t: ^test.T) {
	world := nod.create_world()
	defer nod.destroy_world(world)
	test.expect(t, world != nil, "World should not be nil")
}

@(test)
entity_add :: proc(t: ^test.T) {
	world := nod.create_world()
	defer nod.destroy_world(world)
	log.info("World created")


	entity_id := nod.create_entity(world)
	log.info("Got entity id:", entity_id)
	component_id := nod.register_component(world, TestComponent)
	log.info("Registered component id:", component_id)

	c_test := TestComponent {
		v = 3,
	}
	log.info("Created test component with value: ", c_test.v)
	err := nod.add_component(world, entity_id, component_id, &c_test)
	if err != .None {
		log.error("Failed to add component:", err)
	}
	log.info("Added component")

	if component_ptr, ok := nod.get_component_typed(world, entity_id, component_id, TestComponent);
	   ok {
		test.expect(t, component_ptr.v == 3, "Wrong value in returned component_ptr")
		log.info("Succesfully retrieved component, value:", component_ptr.v)
	}
}


@(test)
get_component_after_entity_remove :: proc(t: ^test.T) {
	world := nod.create_world()
	defer nod.destroy_world(world)
	log.info("World created")

	entity_id := nod.create_entity(world)
	component_id := nod.register_component(world, TestComponent)
	c_test := TestComponent {
		v = 12,
	}
	err := nod.add_component(world, entity_id, component_id, &c_test)
	nod.destroy_entity(world, entity_id)
	component_ptr, ok := nod.get_component_typed(world, entity_id, component_id, TestComponent)
	test.expect(t, ok == false, "Managed to retrive component when entity was destroyed?")
}

@(test)
iterate_query :: proc(t: ^test.T) {
	world := nod.create_world()
	defer nod.destroy_world(world)

	entity_id1 := nod.create_entity(world)
	entity_id2 := nod.create_entity(world)
	entity_id3 := nod.create_entity(world)
	component_id := nod.register_component(world, TestComponent)

	c_test := TestComponent {
		v = 20,
	}
	err := nod.add_component(world, entity_id1, component_id, &c_test)
	_err := nod.add_component(world, entity_id2, component_id, &c_test)
	__err := nod.add_component(world, entity_id3, component_id, &c_test)
	test.expect(t, err == .None, "Error when adding component 1")
	test.expect(t, _err == .None, "Error when adding component 2")
	test.expect(t, __err == .None, "Error when adding component 3")

	required := bit_set[0 ..= nod.MAX_COMPONENTS]{}
	required += {int(component_id)}
	query := nod.query(world, required)
	defer delete(query.match_archetype)

	iter := nod.iterate_query(&query)
	count := 0
	for entity, ok := nod.next_entity(&iter); ok; entity, ok = nod.next_entity(&iter) {
		count += 1
		if comp, ok := nod.get_component_typed(world, entity, component_id, TestComponent); ok {
			test.expect(t, comp.v == 20, "Component value missmatch")
		} else {
			test.fail_now(t, "Failed to get component data")
		}
	}

	test.expectf(t, count == 3, "Expected 3 entities with component, found %d", count)
}

