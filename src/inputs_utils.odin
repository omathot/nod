package nod

import sdl "vendor:sdl2"

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

update_keyboard_state :: proc(keyboard: ^KeyboardState) {
	previous_state := keyboard.keys

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


@(private)
sdl_keycode_to_key :: proc(keycode: sdl.Keycode) -> Maybe(Key) {
	#partial switch keycode {
	case .ESCAPE:
		return Key.ESCAPE
	case .a:
		return Key.A
	case .b:
		return Key.B
	case .c:
		return Key.C
	case .d:
		return Key.D
	case .e:
		return Key.E
	case .f:
		return Key.F
	case .g:
		return Key.G
	case .h:
		return Key.H
	case .i:
		return Key.I
	case .j:
		return Key.J
	case .k:
		return Key.K
	case .l:
		return Key.L
	case .m:
		return Key.M
	case .n:
		return Key.N
	case .o:
		return Key.O
	case .p:
		return Key.P
	case .q:
		return Key.Q
	case .r:
		return Key.R
	case .s:
		return Key.S
	case .t:
		return Key.T
	case .u:
		return Key.U
	case .v:
		return Key.V
	case .w:
		return Key.W
	case .x:
		return Key.X
	case .y:
		return Key.Y
	case .z:
		return Key.Z
	case .UP:
		return Key.ARROW_UP
	case .DOWN:
		return Key.ARROW_DOWN
	case .LEFT:
		return Key.ARROW_LEFT
	case .RIGHT:
		return Key.ARROW_RIGHT
	case .SPACE:
		return Key.SPACE
	case .LSHIFT:
		return Key.LSHIFT
	case .RSHIFT:
		return Key.RSHIFT
	case .LCTRL:
		return Key.LCTRL
	case .RCTRL:
		return Key.RCTRL
	case .NUM0, .KP_0:
		return Key.KEY0
	case .NUM1, .KP_1:
		return Key.KEY1
	case .NUM2, .KP_2:
		return Key.KEY2
	case .NUM3, .KP_3:
		return Key.KEY3
	case .NUM4, .KP_4:
		return Key.KEY4
	case .NUM5, .KP_5:
		return Key.KEY5
	case .NUM6, .KP_6:
		return Key.KEY6
	case .NUM7, .KP_7:
		return Key.KEY7
	case .NUM8, .KP_8:
		return Key.KEY8
	case .NUM9, .KP_9:
		return Key.KEY9
	}
	return nil
}

@(private)
sdl_button_to_mouse_button :: proc(button: u8) -> Maybe(MouseButton) {
	switch button {
	case u8(sdl.BUTTON_LEFT):
		return MouseButton.Left
	case u8(sdl.BUTTON_RIGHT):
		return MouseButton.Right
	case u8(sdl.BUTTON_MIDDLE):
		return MouseButton.Middle
	case:
		return nil
	}
}

make_mouse_event :: proc(sdl_event: sdl.Event, current_time: u32) -> InputEvent {
	event := InputEvent {
		timestamp = current_time,
	}

	#partial switch sdl_event.type {
	case .MOUSEMOTION:
		event.type = .MouseMove
		event.mouse_position = {f64(sdl_event.motion.x), f64(sdl_event.motion.y)}

	case .MOUSEBUTTONDOWN:
		event.type = .MouseDown
		if btn, ok := sdl_button_to_mouse_button(sdl_event.button.button).?; ok {
			event.mouse_button = btn
			event.mouse_position = {f64(sdl_event.button.x), f64(sdl_event.button.y)}
		}

	case .MOUSEBUTTONUP:
		event.type = .MouseUp
		if btn, ok := sdl_button_to_mouse_button(sdl_event.button.button).?; ok {
			event.mouse_button = btn
			event.mouse_position = {f64(sdl_event.button.x), f64(sdl_event.button.y)}
		}

	case .MOUSEWHEEL:
		event.type = .MouseScroll
		scroll_direction := sdl_event.wheel.y
		if sdl_event.wheel.direction == u32(sdl.MouseWheelDirection.FLIPPED) {
			scroll_direction *= -1
		}
		event.scroll_delta = f32(scroll_direction)
		// Note: For wheel events, we need to get the current mouse position separately
		x, y: i32
		sdl.GetMouseState(&x, &y)
		event.mouse_position = {f64(x), f64(y)}

	}
	return event
}

