package nod

import "core:container/queue"
import "core:fmt"
import "core:sync"
import "core:thread"
import sdl "vendor:sdl2"

StateBuffer :: struct {
	states:      [3]GameState,
	read_index:  int,
	write_index: int,
	mutex:       sync.Mutex,
}


GameState :: struct {
	transform: map[EntityID]TransformState,
	input:     InputSnapshot,
	// animation: AnimationState
	// particles: ParticleState
}

InputSnapshot :: struct {
	keyboard:       bit_set[Key],
	mouse_position: Vec2,
	mouse_buttons:  bit_set[MouseButton],
}

TransformState :: struct {
	position: Vec2,
	rotation: f32,
	scale:    Vec2,
}

