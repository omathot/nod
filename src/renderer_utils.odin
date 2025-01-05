package nod

import "core:container/queue"
import "core:sync"


// Specific renderable types
SpriteComponent :: struct {
	texture: ^Texture,
	rect:    Rect,
	flip_h:  bool,
	flip_v:  bool,
	color:   Color,
	z_index: f32,
}

TextComponent :: struct {
	content: string,
	font:    FontID,
	size:    f32,
	color:   Color,
	z_index: f32,
}

CameraComponent :: struct {
	projection_type: enum {
		Orthographic,
		Perspective,
	},
	viewport:        Rect,
	zoom:            f32,
	is_active:       bool,
}

Material :: struct {
	shader:     ShaderID,
	properties: map[string]union {
		f32,
		Vec2,
		Color,
		^Texture,
	},
}


register_core_components :: proc(world: ^World) {
	transform_component_id = get_or_register_component(world, Transform)
	camera_component_id = get_or_register_component(world, CameraComponent)
	sprite_component_id = get_or_register_component(world, SpriteComponent)
	text_component_id = get_or_register_component(world, TextComponent)
}

