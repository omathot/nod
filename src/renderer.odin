package nod

// import "core:fmt"
import "core:slice"
import sdl "vendor:sdl2"

ShaderID :: distinct u32
transform_component_id: ComponentID
sprite_component_id: ComponentID
camera_component_id: ComponentID
text_component_id: ComponentID

InternalRenderState :: struct {
	current_camera: EntityID,
}

camera_system :: proc(world: ^World) {
	required := bit_set[0 ..= MAX_COMPONENTS]{}
	required += {int(camera_component_id)}

	q := query(world, required)
	defer delete(q.match_archetype)

	if render_state, err := get_resource(world.resources, InternalRenderState); err == .None {
		it := iterate_query(&q)
		for entity, ok := next_entity(&it); ok; entity, ok = next_entity(&it) {
			if camera, c_ok := get_component_typed(
				world,
				entity,
				camera_component_id,
				CameraComponent,
			); c_ok {
				if camera.is_active {
					render_state.current_camera = entity
					break
				}
			}
		}
	}
}

sprite_render_system :: proc(world: ^World, renderer: ^Renderer) {
	// 	fmt.println("Setting Sprite rendering")
	required := bit_set[0 ..= MAX_COMPONENTS]{}
	required += {int(sprite_component_id), int(transform_component_id)}

	SpriteEntry :: struct {
		entity:  EntityID,
		z_index: f32,
	}
	sprites := make([dynamic]SpriteEntry)
	defer delete(sprites)

	// 	fmt.println("Querying for sprites")
	q := query(world, required)
	defer delete(q.match_archetype)

	it := iterate_query(&q)
	sprite_count := 0
	for entity, ok := next_entity(&it); ok; entity, ok = next_entity(&it) {
		sprite_count += 1
		if sprite, s_ok := get_component_typed(
			world,
			entity,
			sprite_component_id,
			SpriteComponent,
		); s_ok {
			append(&sprites, SpriteEntry{entity = entity, z_index = sprite.z_index})
		}
	}
	// 	fmt.printfln("found %d sprites to render\n", sprite_count)

	// sort by z index
	slice.sort_by(sprites[:], proc(a, b: SpriteEntry) -> bool {
		return a.z_index < b.z_index
	})

	// render 
	for entry in sprites {
		sprite, _ := get_component_typed(world, entry.entity, sprite_component_id, SpriteComponent)
		transform, _ := get_component_typed(world, entry.entity, transform_component_id, Transform)
		// screen position relative to camera
		dest := Rect {
			x = int(transform.position.x - f64(sprite.rect.w) / 2 * transform.scale.x),
			y = int(transform.position.y - f64(sprite.rect.h) / 2 * transform.scale.y),
			w = int(f64(sprite.rect.w) * transform.scale.x),
			h = int(f64(sprite.rect.h) * transform.scale.y),
		}
		// color
		sdl.SetTextureColorMod(
			sprite.texture.handle,
			sprite.color.r,
			sprite.color.g,
			sprite.color.b,
		)

		flip := sdl.RendererFlip.NONE
		if sprite.flip_h do flip |= .HORIZONTAL
		if sprite.flip_v do flip |= .VERTICAL

		// draw
		sdl.RenderCopyExF(
			renderer.handle,
			sprite.texture.handle,
			&sdl.Rect {
				i32(sprite.rect.x),
				i32(sprite.rect.y),
				i32(sprite.rect.w),
				i32(sprite.rect.h),
			},
			&sdl.FRect{f32(dest.x), f32(dest.y), f32(dest.w), f32(dest.h)},
			f64(transform.rotation),
			nil,
			flip,
		)
	}
}

// main system, coordinates all others
render_system :: proc(world: ^World, renderer: ^Renderer) {
	// 	fmt.println("\nStarting render frame")

	// clear screen
	sdl.SetRenderDrawColor(renderer.handle, 0, 0, 0, 255)
	sdl.RenderClear(renderer.handle)

	// 	fmt.println("Running camera system...")
	camera_system(world)

	// 	fmt.println("Running sprite system...")
	sprite_render_system(world, renderer)

	// 	fmt.println("Present renderer...")
	sdl.RenderPresent(renderer.handle)
	// 	fmt.println("Frame complete\n")
}

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

init_render_system :: proc(world: ^World) {
	register_core_components(world)
	render_state := InternalRenderState{}
	insert_resource(world.resources, InternalRenderState, render_state)
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

