package nod


Rect :: struct {
	x, y: int,
	w, h: int,
}


Color :: struct {
	r, g, b, a: u8,
}

Vec2 :: struct {
	x, y: f64,
}

Vec3 :: struct {
	x, y, z: f64,
}

Transform :: struct {
	position: Vec2,
	rotation: f32,
	scale:    Vec2,
}


RigidBody :: struct {
	velocity:     Vec2,
	acceleration: Vec2,
	mass:         f32,
}

