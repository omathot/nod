package nod

import "core:c"
import "core:strings"
import sdl "vendor:sdl2"
import sdlimg "vendor:sdl2/image"

TextureID :: distinct u32

Texture :: struct {
	handle: ^sdl.Texture,
	id:     TextureID,
	path:   string,
}

Sprite :: struct {
	texture:     Texture,
	source_rect: Rect,
	layer:       int,
}

TextureError :: enum {
	None,
	FileNotFound,
	LoadFailed,
	InvalidDimensions,
}

create_texture :: proc(renderer: ^Renderer, path: string) -> (^Texture, TextureError) {
	texture := new(Texture)
	texture.path = path
	cpath := strings.clone_to_cstring(path)
	defer delete(cpath)

	texture.handle = sdlimg.LoadTexture(renderer.handle, cpath)
	if texture.handle == nil {
		free(texture)
		return nil, .LoadFailed
	}

	return texture, .None
}

texture_get_dimensions :: proc(texture: ^Texture) -> (width: int, height: int) {
	if texture.handle != nil {
		w, h: c.int
		sdl.QueryTexture(texture.handle, nil, nil, &w, &h)
		return int(w), int(h)
	}

	return 0, 0
}

create_sprite :: proc(texture: ^Texture, source_rect: Rect = {}, layer: int = 0) -> Sprite {
	rect: Rect
	if source_rect == (Rect{}) {
		w, h := texture_get_dimensions(texture)
		rect = Rect{0, 0, w, h}
	}
	return Sprite{texture = texture^, source_rect = rect, layer = layer}
}

destroy_texture :: proc(texture: ^Texture) {
	if texture != nil {
		if texture.handle != nil {
			sdl.DestroyTexture(texture.handle)
		}
		free(texture)
	}
}

