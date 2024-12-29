package nod

import b2 "vendor:box2d"

ShapeID :: distinct int

PhysicsBody :: struct {
	handle:         b2.BodyId,
	type:           PhysicsBodyType,
	entity_id:      EntityID,
	shapes:         [dynamic]ShapeID,

	// cache
	prev_transform: Transform,
	transform:      Transform,
}

PhysicsJoint :: struct {
	handle:     b2.JointId,
	joint_type: b2.BodyType,
	body_a:     EntityID,
	body_b:     EntityID,
}

Contact :: struct {
	body_a: EntityID,
	body_b: EntityID,
	normal: Vec2,
	point:  Vec2,
	state:  ContactState,
}

ContactState :: enum {
	Begin,
	Stay,
	End,
}

PhysicsBodyType :: enum {
	Static,
	Dynamic,
	Kinematic,
}

Hit :: struct {
	body_a:         EntityID,
	body_b:         EntityID,
	normal:         Vec2,
	point:          Vec2,
	approach_speed: f32,
}

