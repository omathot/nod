package nod

import sdl "vendor:sdl2"

Renderer :: struct {
	handle:             ^sdl.Renderer,
	current_color:      Color,
	current_blend_mode: BlendMode,
	viewport:           Rect,
	render_scale:       Vec2,
	vsync_enabled:      bool,
}

BlendMode :: enum {
	None,
	Blend,
	Add,
	Multiply,
}

create_renderer :: proc(window: ^Window, flags: RendererFlags) -> (Renderer, RendererError) {
	renderer: Renderer
	sdl_flags := flags_to_sdl(flags)

	renderer.handle = sdl.CreateRenderer(window.handle, -1, sdl_flags)
	if renderer.handle == nil {
		return {}, RendererError.FailedToCreate
	}

	renderer.current_color = {255, 255, 255, 255}
	renderer.current_blend_mode = .None
	renderer.vsync_enabled = (.VSync in flags)
	renderer.viewport.w = window.width
	renderer.viewport.h = window.height
	renderer.render_scale = {1, 1}
	// rest is 0 init'd
	return renderer, RendererError.None
}

flags_to_sdl :: proc(flags: RendererFlags) -> sdl.RendererFlags {
	sw := .Software in flags ? sdl.RendererFlag.SOFTWARE : sdl.RendererFlag(0)
	acc := .Accelerated in flags ? sdl.RendererFlag.ACCELERATED : sdl.RendererFlag(0)
	vs := .VSync in flags ? sdl.RendererFlag.PRESENTVSYNC : sdl.RendererFlag(0)
	tt := .TargetTexture in flags ? sdl.RendererFlag.TARGETTEXTURE : sdl.RendererFlag(0)

	return sdl.RendererFlags{sw, acc, vs, tt}
}

RendererError :: enum {
	None,
	FailedToCreate,
}

RendererFlags :: bit_set[RendererFlag]
RendererFlag :: enum {
	Software,
	Accelerated,
	PresentVSync,
	VSync,
	TargetTexture,
}

