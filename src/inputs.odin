package nod

import "core:fmt"
import sdl "vendor:sdl2"

InputState :: struct {
	keyboard:      KeyboardState,
	mouse:         MouseState,
	prev_keyboard: KeyboardState,
	prev_mouse:    MouseState,
	quit_request:  bool,
}

KeyboardState :: struct {
	keys: bit_set[Key],
}

MouseState :: struct {
	position:     Vec2,
	buttons:      bit_set[MouseButton],
	scroll_delta: f32,
}

update_input :: proc(input: ^InputState) {
	// Create a new fresh KeyboardState for current frame
	new_keyboard: KeyboardState

	// Store the current state as previous before updating
	input.prev_keyboard = input.keyboard
	// Reset current state to the fresh one
	input.keyboard = new_keyboard

	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			input.quit_request = true
		}
	}

	update_keyboard_state(&input.keyboard)
	update_mouse_state(&input.mouse)
}

is_key_pressed :: proc(input: ^InputState, key: Key) -> bool {
	return key in input.keyboard.keys && key not_in input.prev_keyboard.keys
}

is_key_held :: proc(input: ^InputState, key: Key) -> bool {
	return key in input.keyboard.keys
}

is_key_released :: proc(input: ^InputState, key: Key) -> bool {
	return key not_in input.keyboard.keys && key in input.prev_keyboard.keys
}

update_keyboard_state :: proc(keyboard: ^KeyboardState) {
	num_keys: i32
	sdl_keys := sdl.GetKeyboardState(&num_keys)
	if sdl_keys[sdl.SCANCODE_ESCAPE] != 0 {
		keyboard.keys += {.ESCAPE}
	}
	if sdl_keys[sdl.SCANCODE_A] != 0 {
		keyboard.keys += {.A}
	}
	if sdl_keys[sdl.SCANCODE_B] != 0 {
		keyboard.keys += {.B}
	}
	if sdl_keys[sdl.SCANCODE_C] != 0 {
		keyboard.keys += {.C}
	}
	if sdl_keys[sdl.SCANCODE_D] != 0 {
		keyboard.keys += {.D}
	}
	if sdl_keys[sdl.SCANCODE_E] != 0 {
		keyboard.keys += {.E}
	}
	if sdl_keys[sdl.SCANCODE_F] != 0 {
		keyboard.keys += {.F}
	}
	if sdl_keys[sdl.SCANCODE_G] != 0 {
		keyboard.keys += {.G}
	}
	if sdl_keys[sdl.SCANCODE_H] != 0 {
		keyboard.keys += {.H}
	}
	if sdl_keys[sdl.SCANCODE_I] != 0 {
		keyboard.keys += {.I}
	}
	if sdl_keys[sdl.SCANCODE_J] != 0 {
		keyboard.keys += {.J}
	}
	if sdl_keys[sdl.SCANCODE_K] != 0 {
		keyboard.keys += {.K}
	}
	if sdl_keys[sdl.SCANCODE_L] != 0 {
		keyboard.keys += {.L}
	}
	if sdl_keys[sdl.SCANCODE_M] != 0 {
		keyboard.keys += {.M}
	}
	if sdl_keys[sdl.SCANCODE_N] != 0 {
		keyboard.keys += {.N}
	}
	if sdl_keys[sdl.SCANCODE_O] != 0 {
		keyboard.keys += {.O}
	}
	if sdl_keys[sdl.SCANCODE_P] != 0 {
		keyboard.keys += {.P}
	}
	if sdl_keys[sdl.SCANCODE_Q] != 0 {
		keyboard.keys += {.Q}
	}
	if sdl_keys[sdl.SCANCODE_R] != 0 {
		keyboard.keys += {.R}
	}
	if sdl_keys[sdl.SCANCODE_S] != 0 {
		keyboard.keys += {.S}
	}
	if sdl_keys[sdl.SCANCODE_T] != 0 {
		keyboard.keys += {.T}
	}
	if sdl_keys[sdl.SCANCODE_U] != 0 {
		keyboard.keys += {.U}
	}
	if sdl_keys[sdl.SCANCODE_V] != 0 {
		keyboard.keys += {.V}
	}
	if sdl_keys[sdl.SCANCODE_W] != 0 {
		keyboard.keys += {.W}
	}
	if sdl_keys[sdl.SCANCODE_X] != 0 {
		keyboard.keys += {.X}
	}
	if sdl_keys[sdl.SCANCODE_Y] != 0 {
		keyboard.keys += {.Y}
	}
	if sdl_keys[sdl.SCANCODE_Z] != 0 {
		keyboard.keys += {.Z}
	}
	if sdl_keys[sdl.SCANCODE_UP] != 0 {
		keyboard.keys += {.ARROW_UP}
	}
	if sdl_keys[sdl.SCANCODE_DOWN] != 0 {
		keyboard.keys += {.ARROW_DOWN}
	}
	if sdl_keys[sdl.SCANCODE_LEFT] != 0 {
		keyboard.keys += {.ARROW_LEFT}
	}
	if sdl_keys[sdl.SCANCODE_RIGHT] != 0 {
		keyboard.keys += {.ARROW_RIGHT}
	}
	if sdl_keys[sdl.SCANCODE_0] != 0 {
		keyboard.keys += {.KEY0}
	}
	if sdl_keys[sdl.SCANCODE_1] != 0 {
		keyboard.keys += {.KEY1}
	}
	if sdl_keys[sdl.SCANCODE_2] != 0 {
		keyboard.keys += {.KEY2}
	}
	if sdl_keys[sdl.SCANCODE_3] != 0 {
		keyboard.keys += {.KEY3}
	}
	if sdl_keys[sdl.SCANCODE_4] != 0 {
		keyboard.keys += {.KEY4}
	}
	if sdl_keys[sdl.SCANCODE_5] != 0 {
		keyboard.keys += {.KEY5}
	}
	if sdl_keys[sdl.SCANCODE_6] != 0 {
		keyboard.keys += {.KEY6}
	}
	if sdl_keys[sdl.SCANCODE_7] != 0 {
		keyboard.keys += {.KEY7}
	}
	if sdl_keys[sdl.SCANCODE_8] != 0 {
		keyboard.keys += {.KEY8}
	}
	if sdl_keys[sdl.SCANCODE_9] != 0 {
		keyboard.keys += {.KEY9}
	}
	if sdl_keys[sdl.SCANCODE_SPACE] != 0 {
		keyboard.keys += {.SPACE}
	}
	if sdl_keys[sdl.SCANCODE_LSHIFT] != 0 {
		keyboard.keys += {.LSHIFT}
	}
	if sdl_keys[sdl.SCANCODE_RSHIFT] != 0 {
		keyboard.keys += {.RSHIFT}
	}
	if sdl_keys[sdl.SCANCODE_LCTRL] != 0 {
		keyboard.keys += {.LCTRL}
	}
	if sdl_keys[sdl.SCANCODE_RCTRL] != 0 {
		keyboard.keys += {.RCTRL}
	}
}

update_mouse_state :: proc(mouse: ^MouseState) {
	x, y: i32
	mouse.buttons = {}
	mouse_button := sdl.GetMouseState(&x, &y)

	mouse.position = {f64(x), f64(y)}
	if mouse_button & u32(sdl.BUTTON_LEFT) != 0 {
		mouse.buttons += {.Left}
	}
	if mouse_button & u32(sdl.BUTTON_RIGHT) != 0 {
		mouse.buttons += {.Right}
	}
	if mouse_button & u32(sdl.BUTTON_MIDDLE) != 0 {
		mouse.buttons += {.Middle}
	}
}

MouseButton :: enum {
	Left,
	Right,
	Middle,
}

Key :: enum {
	ESCAPE,
	A,
	B,
	C,
	D,
	E,
	F,
	G,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	R,
	S,
	T,
	U,
	V,
	W,
	X,
	Y,
	Z,
	ARROW_UP,
	ARROW_DOWN,
	ARROW_LEFT,
	ARROW_RIGHT,
	KEY0,
	KEY1,
	KEY2,
	KEY3,
	KEY4,
	KEY5,
	KEY6,
	KEY7,
	KEY8,
	KEY9,
	SPACE,
	LSHIFT,
	RSHIFT,
	LCTRL,
	RCTRL,
}

