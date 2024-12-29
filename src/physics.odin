package nod

import "core:math"
import b2 "vendor:box2d"

PhysicsWorld :: struct {
	handle:   b2.WorldId,
	bodies:   map[EntityID]PhysicsBody,
	contacts: [dynamic]Contact,
	hits:     [dynamic]Hit,
	// joints:   [dynamic]PhysicsJoint,    not implemented yet
	gravity:  Vec2,
}

@(private)
physics_init_world :: proc(world: ^PhysicsWorld, gravity: Vec2 = {0.0, -9.81}) {
	def_world := b2.DefaultWorldDef()
	def_world.gravity = {f32(gravity.x), f32(gravity.y)}

	world.handle = b2.CreateWorld(def_world)
	world.gravity = gravity
	world.bodies = make(map[EntityID]PhysicsBody)
	world.contacts = make([dynamic]Contact)
	world.hits = make([dynamic]Hit)
}

@(private)
physics_cleanup :: proc(world: ^PhysicsWorld) {
	for _, body in world.bodies {
		for shape in body.shapes {
			b2.DestroyShape(transmute(b2.ShapeId)u64(shape))
		}
		delete(body.shapes)
		b2.DestroyBody(body.handle)
	}
	delete(world.contacts)
	delete(world.hits)
	delete(world.bodies)
	b2.DestroyWorld(world.handle)
}

@(private)
physics_update :: proc(world: ^PhysicsWorld, dt: f32) {
	// cache
	physics_cache(world)

	new_contacts := make([dynamic]Contact)
	for &contact in world.contacts {
		if contact.state == .Begin {
			contact.state = .Stay
			append(&new_contacts, contact)
		} else if contact.state == .Stay {
			append(&new_contacts, contact)
		}
	}
	delete(world.contacts)
	world.contacts = new_contacts

	velocity_iterations: f32 = 8
	position_iterations: i32 = 3
	b2.World_Step(world.handle, velocity_iterations, position_iterations)

	// get new contacts/hits
	process_contacts_and_hits(world)

}

@(private)
process_contacts_and_hits :: proc(world: ^PhysicsWorld) {
	clear(&world.hits)
	contact_events := b2.World_GetContactEvents(world.handle)
	for i: i32 = 0; i < contact_events.beginCount; i += 1 {
		contact := contact_events.beginEvents[i]
		body_a := b2.Shape_GetBody(contact.shapeIdA)
		body_b := b2.Shape_GetBody(contact.shapeIdB)
		entity_a := cast(EntityID)(uintptr(b2.Body_GetUserData(body_a)))
		entity_b := cast(EntityID)(uintptr(b2.Body_GetUserData(body_b))) // holy shit... casting to uintptr first for compiler

		append(&world.contacts, Contact{body_a = entity_a, body_b = entity_b, state = .Begin})
	}

	for i: i32 = 0; i < contact_events.hitCount; i += 1 {
		hit := contact_events.hitEvents[i]
		body_a := b2.Shape_GetBody(hit.shapeIdA)
		body_b := b2.Shape_GetBody(hit.shapeIdB)

		append(
			&world.hits,
			Hit {
				body_a = cast(EntityID)uintptr(b2.Body_GetUserData(body_a)),
				body_b = cast(EntityID)uintptr(b2.Body_GetUserData(body_b)),
				point = {f64(hit.point.x), f64(hit.point.y)},
				normal = {f64(hit.normal.x), f64(hit.normal.y)},
				approach_speed = hit.approachSpeed,
			},
		)

	}

}

@(private)
physics_cache :: proc(world: ^PhysicsWorld) {
	for _, &body in world.bodies {
		body.prev_transform = body.transform
	}
	for _, &body in world.bodies {
		transform := b2.Body_GetTransform(body.handle)
		body.transform = Transform {
			position = {f64(transform.p.x), f64(transform.p.y)},
			rotation = math.atan2(transform.q.s, transform.q.c), // get angle from sin/cos
			scale    = body.transform.scale,
		}
	}
}


// Body Creation
add_rigid_body :: proc(
	nod: ^Nod,
	entity_id: EntityID,
	body_type: PhysicsBodyType,
	position: Vec2,
) -> ^PhysicsBody {

	body_def := b2.DefaultBodyDef()
	switch body_type {
	case .Static:
		body_def.type = .staticBody
	case .Dynamic:
		body_def.type = .dynamicBody
	case .Kinematic:
		body_def.type = .kinematicBody
	}
	body_def.position = {f32(position.x), f32(position.y)}
	body_def.userData = rawptr(uintptr(entity_id))

	body_handle := b2.CreateBody(nod.physics_world.handle, body_def)
	body := PhysicsBody {
		handle = body_handle,
		type = body_type,
		entity_id = entity_id,
		transform = Transform{position = position},
	}

	nod.physics_world.bodies[entity_id] = body
	return &nod.physics_world.bodies[entity_id]
}

add_box_collider :: proc(
	nod: ^Nod,
	entity_id: EntityID,
	half_width: f32,
	half_height: f32,
	density: f32 = 1.0,
	friction: f32 = 0.3,
	is_sensor: bool,
) -> ShapeID {
	if body, ok := &nod.physics_world.bodies[entity_id]; ok {
		shape_def := b2.DefaultShapeDef()
		shape_def.density = density
		shape_def.friction = friction
		shape_def.isSensor = is_sensor

		shape := b2.Polygon {
			vertices = {
				-half_width,
				-half_height,
				half_width,
				-half_height,
				half_width,
				half_height,
				-half_width,
				half_height,
			},
			count    = 4,
		}
		shape_id := b2.CreatePolygonShape(body.handle, shape_def, shape)
		shape_wrap := ShapeID(transmute(u64)shape_id)
		append(&body.shapes, shape_wrap)
		return shape_wrap
		// body.shapes = ShapeID(transmute(u64)shape_id)
	}
	return ShapeID(0)
}

add_circle_collider :: proc(
	nod: ^Nod,
	entity_id: EntityID,
	radius: f32,
	density: f32 = 1.0,
	friction: f32 = 0.3,
	is_sensor: bool,
) -> ShapeID {
	if body, ok := &nod.physics_world.bodies[entity_id]; ok {
		shape_def := b2.DefaultShapeDef()
		shape_def.density = density
		shape_def.friction = friction
		shape_def.isSensor = is_sensor

		circle := b2.Circle {
			radius = radius,
		}
		shape_id := b2.CreateCircleShape(body.handle, shape_def, circle)
		shape_wrap := ShapeID(transmute(u64)shape_id)

		append(&body.shapes, shape_wrap)
		return shape_wrap
	}
	return ShapeID(0)
}


// Movement n Forces
set_gravity :: proc(nod: ^Nod, gravity: Vec2) {
	nod.physics_world.gravity = gravity
	b2.World_SetGravity(nod.physics_world.handle, {f32(gravity.x), f32(gravity.y)})
}

set_position :: proc(nod: ^Nod, entity_id: EntityID, position: Vec2) {
	if body, ok := &nod.physics_world.bodies[entity_id]; ok {
		b2.Body_SetTransform(
			body.handle,
			{f32(position.x), f32(position.y)},
			b2.MakeRot(body.transform.rotation),
		)
	}
}


set_velocity :: proc(nod: ^Nod, entity_id: EntityID, velocity: Vec2) {
	if body, ok := nod.physics_world.bodies[entity_id]; ok {
		b2.Body_SetLinearVelocity(body.handle, {f32(velocity.x), f32(velocity.y)})
	}
}

set_angular_velocity :: proc(nod: ^Nod, entity_id: EntityID, velocity: f32) {
	if body, ok := nod.physics_world.bodies[entity_id]; ok {
		b2.Body_SetAngularVelocity(body.handle, velocity)
	}
}

apply_force :: proc(nod: ^Nod, entity_id: EntityID, impulse: Vec2, world_point: Vec2) {
	if body, ok := nod.physics_world.bodies[entity_id]; ok {
		b2.Body_ApplyForce(
			body.handle,
			{f32(impulse.x), f32(impulse.y)},
			{f32(world_point.x), f32(world_point.y)},
			true, // b2 puts bodies to sleep after a while, so they're not simulated
		)
	}
}

set_body_awake :: proc(nod: ^Nod, entity_id: EntityID, awake: bool) {
	if body, ok := nod.physics_world.bodies[entity_id]; ok {
		b2.Body_SetAwake(body.handle, awake)
	}
}

// should be used for one shot impulses
apply_impulse :: proc(nod: ^Nod, entity_id: EntityID, impulse: Vec2, world_point: Vec2) {
	if body, ok := nod.physics_world.bodies[entity_id]; ok {
		b2.Body_ApplyLinearImpulse(
			body.handle,
			{f32(impulse.x), f32(impulse.y)},
			{f32(world_point.x), f32(world_point.y)},
			true,
		)
	}
}

set_linear_damping :: proc(nod: ^Nod, entity_id: EntityID, damping: f32) {
	if body, ok := nod.physics_world.bodies[entity_id]; ok {
		b2.Body_SetLinearDamping(body.handle, damping)
	}
}

// Queries
get_position :: proc(nod: ^Nod, entity_id: EntityID) -> Vec2 {
	if body, ok := nod.physics_world.bodies[entity_id]; ok {
		return body.transform.position
	}
	return Vec2{}
}

get_velocity :: proc(nod: ^Nod, entity_id: EntityID) -> Vec2 {
	if body, ok := nod.physics_world.bodies[entity_id]; ok {
		vel := b2.Body_GetLinearVelocity(body.handle)
		return {f64(vel.x), f64(vel.y)}
	}
	return Vec2{}
}

get_angular_velocity :: proc(nod: ^Nod, entity_id: EntityID) -> f32 {
	if body, ok := nod.physics_world.bodies[entity_id]; ok {
		return b2.Body_GetAngularVelocity(body.handle)
	}
	return 0
}

get_contacts :: proc(nod: ^Nod, entity_id: EntityID, allocator := context.allocator) -> []Contact {
	contacts := make([dynamic]Contact, allocator)
	for contact in nod.physics_world.contacts {
		if contact.body_a == entity_id || contact.body_b == entity_id {
			append(&contacts, contact)
		}
	}
	return contacts[:]
}

get_hits :: proc(nod: ^Nod, entity_id: EntityID, allocator := context.allocator) -> []Hit {
	hits := make([dynamic]Hit, allocator)
	for hit in nod.physics_world.hits {
		if hit.body_a == entity_id || hit.body_b == entity_id {
			append(&hits, hit)
		}
	}
	return hits[:]
}

get_body_mass :: proc(nod: ^Nod, entity_id: EntityID) -> f32 {
	if body, ok := nod.physics_world.bodies[entity_id]; ok {
		return b2.Body_GetMass(body.handle)
	}
	return 0
}

is_body_awake :: proc(nod: ^Nod, entity_id: EntityID) -> bool {
	if body, ok := nod.physics_world.bodies[entity_id]; ok {
		return b2.Body_IsAwake(body.handle)
	}
	return false
}

// JOINTS
