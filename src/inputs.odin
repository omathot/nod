package nod

import "core:container/queue"
import "core:fmt"
import sdl "vendor:sdl2"

InputState :: struct {
	keyboard:         KeyboardState,
	mouse:            MouseState,
	// gamepads:         [4]GamePadState,
	quit_request:     bool,

	// buffer
	event_buffer:     queue.Queue(InputEvent),
	fixed_state:      FixedInputState,

	// time
	last_update_time: u32,
	fixed_timestep:   f32,
}

FixedInputState :: struct {
	keyboard:      KeyboardState,
	mouse:         MouseState,
	prev_keyboard: KeyboardState,
	prev_mouse:    MouseState,
}

InputEvent :: struct {
	type:           InputEventType,
	key:            Key,
	mouse_button:   MouseButton,
	mouse_position: Vec2,
	scroll_delta:   f32,
	timestamp:      u32,
}

KeyboardState :: struct {
	keys: bit_set[Key],
}

MouseState :: struct {
	position:     Vec2,
	buttons:      bit_set[MouseButton],
	scroll_delta: f32,
}

InputEventType :: enum {
	KeyDown,
	KeyUp,
	MouseDown,
	MouseUp,
	MouseMove,
	MouseScroll,
}

init_input_state :: proc(input: ^InputState) {
	queue.init(&input.event_buffer)
	input.fixed_timestep = 1.0 / 60.0
	input.last_update_time = 0
	input.quit_request = false
}

cleanup_input_state :: proc(input: ^InputState) {
	if input != nil {
		queue.destroy(&input.event_buffer)
	}
}

update_input :: proc(input: ^InputState) {
	current_time := sdl.GetTicks()

	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			input.quit_request = true
		case .KEYDOWN, .KEYUP:
			keycode := sdl.GetKeyFromScancode(event.key.keysym.scancode)
			if key, ok := sdl_keycode_to_key(keycode).?; ok {
				queue.push_back(
					&input.event_buffer,
					InputEvent{type = .KeyDown, key = key, timestamp = current_time},
				)
			}
		case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP, .MOUSEMOTION, .MOUSEWHEEL:
			queue.push_back(&input.event_buffer, make_mouse_event(event, current_time))
		}
	}

	update_keyboard_state(&input.keyboard)
	update_mouse_state(&input.mouse)
	input.last_update_time = current_time
}


process_fixed_update :: proc(input: ^InputState) {
	input.fixed_state.prev_keyboard = input.fixed_state.keyboard
	input.fixed_state.prev_mouse = input.fixed_state.mouse

	input.fixed_state.keyboard = {}
	input.fixed_state.mouse = {}

	current_time := sdl.GetTicks()

	for queue.len(input.event_buffer) > 0 {
		p_event := queue.peek_front(&input.event_buffer)
		if p_event.timestamp > current_time {
			break // we in the future baby
		}

		event := queue.pop_front(&input.event_buffer)
		process_event(&input.fixed_state, event)
	}
}

process_event :: proc(state: ^FixedInputState, event: InputEvent) {
	current_time := sdl.GetTicks()

	switch event.type {
	case .KeyDown:
		state.keyboard.keys += {event.key}
	case .KeyUp:
		state.keyboard.keys -= {event.key}
	case .MouseDown:
		state.mouse.buttons += {event.mouse_button}
		state.mouse.position = event.mouse_position
	case .MouseUp:
		state.mouse.buttons -= {event.mouse_button}
		state.mouse.position = event.mouse_position
	case .MouseMove:
		state.mouse.position = event.mouse_position
	case .MouseScroll:
		state.mouse.scroll_delta = event.scroll_delta
	}
}

// process_input_events :: proc(input: ^InputState) {
// 	current_time := sdl.GetTicks()

// 	for queue.len(input.event_buffer) > 0 {
// 		event := queue.peek_front(&input.event_buffer)

// 		if event.timestamp > current_time {
// 			break // we in the future baby
// 		}

// 		queue.pop_front(&input.event_buffer)

// 		switch event.type {
// 		}
// 	}
// 	input.last_update_time = current_time
// }

is_key_pressed :: proc(input: ^InputState, key: Key) -> bool {
	return(
		key in input.fixed_state.keyboard.keys &&
		key not_in input.fixed_state.prev_keyboard.keys \
	)
}

is_key_held :: proc(input: ^InputState, key: Key) -> bool {
	return key in input.fixed_state.keyboard.keys
}

is_key_released :: proc(input: ^InputState, key: Key) -> bool {
	return(
		key not_in input.fixed_state.keyboard.keys &&
		key in input.fixed_state.prev_keyboard.keys \
	)
}

// menu navigation
is_key_down_immediate :: proc(input: ^InputState, key: Key) -> bool {
	return key in input.keyboard.keys
}

