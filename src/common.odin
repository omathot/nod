package nod

import sdl "vendor:sdl2"

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

Sprite :: struct {
	texture:     ^sdl.Texture,
	source_rect: Rect,
	layer:       int,
}

RigidBody :: struct {
	velocity:     Vec2,
	acceleration: Vec2,
	mass:         f32,
}

