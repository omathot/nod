package nod

import b2 "vendor:box2d"

Area :: struct {
	entity_id:   EntityID,
	body:        ^PhysicsBody,
	shapes:      [dynamic]ShapeID,

	// cache
	overlapping: map[EntityID]bool,
}

create_area :: proc(world: ^World, entity_id: EntityID, position: Vec2) -> ^Area {
	area := new(Area)
	area.entity_id = entity_id
	area.overlapping = make(map[EntityID]bool)

	area.body = add_rigid_body(world, entity_id, .Kinematic, position)
	return area
}

add_box_area :: proc(world: ^World, area: ^Area, half_width: f32, half_height: f32) -> ShapeID {
	return add_box_collider(world, area.entity_id, half_width, half_height, 0, 0, true)
}

add_circle_area :: proc(world: ^World, area: ^Area, radius: f32) -> ShapeID {
	return add_circle_collider(world, area.entity_id, radius, 0, 0, true)
}

destroy_area :: proc(area: ^Area) {
	delete(area.overlapping)
	free(area)
}

update_area_overlaps :: proc(world: ^World, area: ^Area) {
	clear(&area.overlapping)

	contacts := get_contacts(world, area.entity_id)
	defer delete(contacts)

	for contact in contacts {
		if contact.state != .End { 	// include both .Begin and .End
			other_id := contact.body_a == area.entity_id ? contact.body_b : contact.body_a
			area.overlapping[other_id] = true
		}
	}
}

is_point_inside :: proc(area: ^Area, point: Vec2) -> bool {
	for shape_id in area.shapes {
		if b2.Shape_TestPoint(transmute(b2.ShapeId)shape_id, {f32(point.x), f32(point.y)}) {
			return true
		}
	}
	return false
}

get_overlapping_bodies :: proc(area: ^Area, allocator := context.allocator) -> []EntityID {
	bodies := make([dynamic]EntityID, allocator)
	for id in area.overlapping {
		append(&bodies, id)
	}
	return bodies[:]
}

