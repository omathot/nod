package nod

import "core:container/queue"
import "core:fmt"
import "core:sync"
import "core:thread"
import sdl "vendor:sdl2"


TICKS_PER_SECOND :: 25
MAX_FRAMESKIP :: 5 // sqrt(TICKS_PER_SECOND)

Nod :: struct {
	window:            Window,
	renderer:          Renderer,

	// core
	input_state:       InputState,
	is_running:        bool,
	physics_world:     PhysicsWorld,
	// asset_manager: AssetManager
	// audio_system: AudioSystem,
	// scene_manager: SceneManager,

	// threading
	physics_thread:    ^thread.Thread,
	render_thread:     ^thread.Thread,

	// state n sync
	state_buffer:      StateBuffer,
	command_queue:     CommandQueue,
	frame_complete:    sync.Sema,
	physics_complete:  sync.Sema,

	//time
	current_time:      f64,
	prev_time:         f64,
	delta_time:        f64,
	config:            NodConfig,

	// user's game
	game:              rawptr,
	fixed_update_game: proc(_: rawptr, input_state: ^InputState),
	frame_update_game: proc(_: rawptr, input_state: ^InputState),
	render_game:       proc(_: rawptr, nod_renderer: ^Renderer, dt: f32),
	should_quit:       proc(_: rawptr) -> bool,
}

StateBuffer :: struct {
	states:      [3]GameState,
	read_index:  int,
	write_index: int,
	mutex:       sync.Mutex,
}

CommandQueue :: struct {
	commands: queue.Queue(Command),
	mutex:    sync.Mutex,
	sem:      sync.Sema,
}

GameState :: struct {
	transform: Transform,
	physics:   PhysicsState,
	input:     InputState,
	// animation: AnimationState
	// particles: ParticleState
}

Command :: struct {
	type: CommandType,
	data: rawptr,
}

CommandType :: enum {
	Quit,
	UpdatePhysics,
	UpdateRender,
	UpdateInput,
	// UpdateAnimation,
	// UpdateParticle
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
	physics_init_world(&nod.physics_world)
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
	performance_frequency := f64(sdl.GetPerformanceFrequency())
	prev_counter := f64(sdl.GetPerformanceCounter())
	accumulator := f64(0)
	nod.is_running = true

	FIXED_DT := 1.0 / f64(TICKS_PER_SECOND) // 0.04 for 25 TPS


	for nod.is_running {
		current_counter := f64(sdl.GetPerformanceCounter())
		frame_time := f64(current_counter - prev_counter) / performance_frequency
		prev_counter = current_counter

		if frame_time > 0.250 {
			frame_time = 0.25
		}

		nod.prev_time = nod.current_time
		nod.current_time += frame_time
		nod.delta_time = frame_time

		update_input(&nod.input_state)
		if nod.input_state.quit_request {
			nod.is_running = false
		}

		accumulator += frame_time
		loops := 0
		for accumulator > FIXED_DT && loops < MAX_FRAMESKIP {
			fixed_update(nod)
			accumulator -= FIXED_DT
			loops += 1
		}
		variable_update(nod)

		interpolation := clamp(accumulator / FIXED_DT, 0, 1)
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

draw_sprite :: proc(renderer: ^Renderer, texture: ^sdl.Texture, src, dest: Rect) {
	sdl.RenderCopy(
		renderer.handle,
		texture,
		&sdl.Rect{i32(src.x), i32(src.y), i32(src.w), i32(src.h)},
		&sdl.Rect{i32(dest.x), i32(dest.y), i32(dest.w), i32(dest.h)},
	)
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

