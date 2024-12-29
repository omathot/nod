package nod

import "core:fmt"
import sdl "vendor:sdl2"

TICKS_PER_SECOND :: 25
SKIP_TICKS :: 1000 / TICKS_PER_SECOND
MAX_FRAMESKIP :: 5 // sqrt(TICKS_PER_SECOND)

Nod :: struct {
	window:            Window,
	renderer:          Renderer,
	input_state:       InputState,
	is_running:        bool,
	//time
	current_time:      f64,
	prev_time:         f64,
	delta_time:        f64,
	next_tick:         f64,
	// asset_manager: AssetManager
	// audio_system: AudioSystem,
	// scene_manager: SceneManager,
	// physics_world: PhysicsWorld,
	config:            NodConfig,

	// user's game
	game:              rawptr,
	fixed_update_game: proc(_: rawptr, input_state: ^InputState),
	frame_update_game: proc(_: rawptr, input_state: ^InputState),
	render_game:       proc(_: rawptr, nod_renderer: ^Renderer, dt: f32),
	should_quit:       proc(_: rawptr) -> bool,
}

NodConfig :: struct {
	window_title:  string,
	window_width:  int,
	window_height: int,
	target_fps:    int,
	vsync:         bool,
}

NodError :: enum {
	None,
	FailedToInitSdl,
	FailedToCreateWindow,
	FailedToCreateRenderer,
}

nod_init :: proc(config: NodConfig) -> (^Nod, NodError) {
	nod := new(Nod)
	nod.config = config

	if sdl.Init(sdl.INIT_VIDEO) < 0 {
		return nil, .FailedToInitSdl
	}

	window, w_err := create_window(
		nod.config.window_title,
		nod.config.window_width,
		nod.config.window_height,
	)
	if w_err != .None {
		return nil, .FailedToCreateWindow
	}

	renderer, r_err := create_renderer(&window, nil)
	if r_err != .None {
		return nil, .FailedToCreateRenderer
	}

	nod.is_running = false
	nod.window = window
	nod.renderer = renderer
	// nod.input_state := InputState

	return nod, .None
}

nod_clean :: proc(nod: ^Nod) {
	if nod != nil {
		if nod.window.handle != nil {
			sdl.DestroyWindow(nod.window.handle)
		}
		if nod.renderer.handle != nil {
			sdl.DestroyRenderer(nod.renderer.handle)
		}
		if nod.game != nil {
			// not allocated rn its just tests, probably add for real games
			// free(nod.game)
		}

		sdl.Quit()
		nod.is_running = false
		free(nod)
	}

}

nod_run :: proc(nod: ^Nod) {
	nod.is_running = true
	nod.current_time = f64(sdl.GetTicks())
	nod.next_tick = nod.current_time

	for nod.is_running {
		// fmt.println("looping")
		update_input(&nod.input_state)
		if nod.input_state.quit_request {
			nod.is_running = false
		}
		// cache time info
		nod.prev_time = nod.current_time
		nod.current_time = f64(sdl.GetTicks())
		nod.delta_time = (nod.current_time - nod.prev_time) / 1000.0 // seconds

		loops := 0

		for nod.current_time > nod.next_tick && loops < MAX_FRAMESKIP {
			fixed_update(nod) // physics/game_logic
			nod.next_tick += SKIP_TICKS
			loops += 1
		}
		variable_update(nod) // inputs, ui, particle effects, cameras

		interpolation := f64(nod.current_time + SKIP_TICKS - nod.next_tick) / f64(SKIP_TICKS)
		interpolation = clamp(interpolation, 0, 1)
		render(nod, f32(interpolation))
	}
}

render :: proc(nod: ^Nod, interpolation: f32) {
	sdl.SetRenderDrawColor(nod.renderer.handle, 0, 0, 0, 255)
	sdl.RenderClear(nod.renderer.handle)

	if nod.render_game != nil && nod.game != nil {
		nod.render_game(nod.game, &nod.renderer, interpolation)
	}

	sdl.RenderPresent(nod.renderer.handle)
}

fixed_update :: proc(nod: ^Nod) {
	// quit event check
	if nod.input_state.quit_request ||
	   (nod.should_quit != nil && nod.game != nil && nod.should_quit(nod.game)) {
		fmt.println("received quit event")
		nod.is_running = false
		return
	}
	// physics sim
	// physics_update(nod)

	// user's game logic
	if nod.fixed_update_game != nil && nod.game != nil {
		nod.fixed_update_game(nod.game, &nod.input_state)
	}
}

draw_sprite :: proc(renderer: ^Renderer, texture: ^sdl.Texture, src, dest: Rect) {
	sdl.RenderCopy(
		renderer.handle,
		texture,
		&sdl.Rect{i32(src.x), i32(src.y), i32(src.w), i32(src.h)},
		&sdl.Rect{i32(dest.x), i32(dest.y), i32(dest.w), i32(dest.h)},
	)
}

// Separate from fixed_update, this runs every frame:
// Things that can run at variable timestep:
// - Particle effects
// - UI animations
// - Camera smoothing
// - Visual effects
variable_update :: proc(nod: ^Nod) {
	if nod.frame_update_game != nil && nod.game != nil {
		nod.frame_update_game(nod.game, &nod.input_state)
	}
}

// physics_update :: proc(nod: ^nod) {
// 	// Physics timestep is constant (40ms at 25 TPS)
// 	physics_dt := 1.0 / f32(TICKS_PER_SECOND)

// 	for entity in nod.physics_world.bodies {
// 		// Update physics with constant dt
// 		entity.velocity += entity.acceleration * physics_dt
// 		entity.position += entity.velocity * physics_dt
// 	}

// 	// Collision detection & resolution
// 	resolve_collisions(nod.physics_world)
// }

