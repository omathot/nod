package nod

import "core:strings"
import sdl "vendor:sdl2"

Window :: struct {
	handle: ^sdl.Window,
	width:  int,
	height: int,
}

WindowError :: enum {
	None,
	FailedToCreate,
}

create_window :: proc(title: string, width: int, height: int) -> (Window, WindowError) {
	window: Window
	window.width = width
	window.height = height
	window.handle = sdl.CreateWindow(
		strings.clone_to_cstring(title),
		sdl.WINDOWPOS_CENTERED,
		sdl.WINDOWPOS_CENTERED,
		i32(width),
		i32(height),
		sdl.WINDOW_SHOWN | sdl.WINDOW_RESIZABLE,
	)
	if window.handle == nil {
		return {}, .FailedToCreate
	}
	return window, .None
}

