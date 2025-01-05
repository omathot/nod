package nod

import "core:container/queue"
import "core:fmt"
import "core:mem"
import "core:sync"
import "core:thread"
import b2 "vendor:box2d"
import sdl "vendor:sdl2"


TICKS_PER_SECOND :: 60
// MAX_FRAMESKIP :: 6 // sqrt(TICKS_PER_SECOND)
FIXED_DT := 1.0 / f64(TICKS_PER_SECOND) // ~16.67ms

Nod :: struct {
	window:                Window,
	renderer:              Renderer,

	// core
	is_running:            bool,
	ecs_manager:           ECSManager,
	// asset_manager: AssetManager
	// audio_system: AudioSystem,
	// scene_manager: SceneManager,

	// threading
	job_system:            ^JobSystem,

	//time
	performance_frequency: f64,
	current_time:          f64,
	prev_counter:          f64,
	delta_time:            f64,
	config:                NodConfig,

	// user's game
	game:                  rawptr,
	// fixed_update_game:     proc(_: rawptr, input_state: ^InputState),
	// frame_update_game:     proc(_: rawptr, input_state: ^InputState),
	// render_game:           proc(_: rawptr, nod: ^Nod, dt: f32),
}


nod_init :: proc(config: NodConfig) -> (^Nod, NodError) {
	nod := new(Nod)
	nod.config = config
	nod.job_system = create_job_system()

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

	nod.is_running = true
	nod.ecs_manager.world = create_world(nod.job_system)

	nod.window = window
	nod.renderer = renderer
	init_render_system(nod.ecs_manager.world)
	return nod, .None
}

nod_clean :: proc(nod: ^Nod) {
	if nod != nil {
		if nod.game != nil {
			// not allocated rn its just tests, probably add for real games
			// free(nod.game)
		}
		if nod.ecs_manager.world != nil {
			destroy_world(nod.ecs_manager.world)
		}
		if nod.window.handle != nil {
			sdl.DestroyWindow(nod.window.handle)
		}
		if nod.renderer.handle != nil {
			sdl.DestroyRenderer(nod.renderer.handle)
		}

		// threads
		destroy_job_system(nod.job_system)

		sdl.Quit()
		nod.is_running = false
		free(nod)
	}

}

nod_run :: proc(nod: ^Nod) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer alloc_clean(&track)

	// time
	nod.performance_frequency = f64(sdl.GetPerformanceFrequency())
	nod.prev_counter = f64(sdl.GetPerformanceCounter())
	nod.current_time = nod.prev_counter / nod.performance_frequency
	accumulator := f64(0)

	nod.is_running = true
	for nod.is_running {
		// time update
		current_counter := f64(sdl.GetPerformanceCounter())
		frame_time := f64(current_counter - nod.prev_counter) / nod.performance_frequency
		nod.prev_counter = current_counter

		if frame_time > 0.16 {
			frame_time = 0.16
		}

		nod.current_time += frame_time
		nod.delta_time = frame_time
		// update time resource
		if time_res, err := get_resource(nod.ecs_manager.world.resources, TimeResource);
		   err == .None {
			time_res.delta_time = f32(frame_time)
			time_res.total_time += time_res.delta_time
		}

		// update InputState Resource
		input: ^InputState
		if inp, err := get_resource(nod.ecs_manager.world.resources, InputState); err == .None {
			input = inp
		} else {
			fmt.eprintln("Failed to get input state resource")
			nod.is_running = false
			break
		}
		update_input(input)
		if input.quit_request {
			nod.is_running = false
			break
		}

		// fixed timestep update
		accumulator += frame_time
		for accumulator > FIXED_DT {
			// fixed update job
			fixed_update(nod.ecs_manager.world, input)

			// physics job (can run parallel with fixed update)
			if physics_world, err := get_resource(nod.ecs_manager.world.resources, PhysicsWorld);
			   err == .None {
				physics_update(nod.ecs_manager.world, physics_world, f32(FIXED_DT))
			}

			accumulator -= FIXED_DT
		}
		variable_update(nod)


		interpolation := f32(accumulator / FIXED_DT)
		render(nod, interpolation)
	}
}

render :: proc(nod: ^Nod, interpolation: f32) {
	render_system(nod.ecs_manager.world, &nod.renderer, interpolation)
}


fixed_update :: proc(world: ^World, input: ^InputState) {
	completion := sync.Sema{}
	should_quit := false

	fixed_update_data := FixedUpdateData {
		world       = world,
		input       = input,
		dt          = FIXED_DT,
		completion  = &completion,
		should_quit = &should_quit,
	}

	fixed_job := Job {
		procedure  = fixed_update_job,
		data       = &fixed_update_data,
		completion = &completion,
	}

	schedule_job(world.job_system, fixed_job)
	sync.sema_wait(&completion)

}

variable_update :: proc(nod: ^Nod) {
	completion := sync.Sema{}

	update_data := VariableUpdateData {
		world      = nod.ecs_manager.world,
		dt         = f32(nod.delta_time),
		completion = &completion,
	}

	job := Job {
		procedure  = variable_update_job,
		data       = &update_data,
		completion = &completion,
	}

	schedule_job(nod.job_system, job)
	sync.sema_wait(&completion)
}

// to be called during game setup, during runtime everything goes through systems and Resources
get_world :: proc(nod: ^Nod) -> ^World {
	return nod.ecs_manager.world
}

// to use for precise timing
get_ticks :: proc() -> u32 {
	return sdl.GetTicks()
}

// to use for general seconds timing
get_time :: proc() -> f64 {
	return f64(sdl.GetTicks()) / 1000.0
}

get_delta_time :: proc(nod: ^Nod) -> f64 {
	return nod.delta_time
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

