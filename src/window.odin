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

// leaked 8 bytes here when directly assigning the c_str copy. Tmp to delete after assigned
create_window :: proc(title: string, width: int, height: int) -> (Window, WindowError) {
	c_title := strings.clone_to_cstring(title)
	window: Window
	window.width = width
	window.height = height
	window.handle = sdl.CreateWindow(
		c_title,
		sdl.WINDOWPOS_CENTERED,
		sdl.WINDOWPOS_CENTERED,
		i32(width),
		i32(height),
		sdl.WINDOW_SHOWN | sdl.WINDOW_RESIZABLE,
	)
	if window.handle == nil {
		return {}, .FailedToCreate
	}
	delete(c_title)
	return window, .None
}

