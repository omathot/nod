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
	physics_world:         PhysicsWorld,
	ecs_manager:           ECSManager,
	// asset_manager: AssetManager
	// audio_system: AudioSystem,
	// scene_manager: SceneManager,

	// threading
	physics_thread:        ^thread.Thread,

	// state n sync
	state_buffer:          StateBuffer,
	command_queue:         CommandQueue,
	physics_complete:      sync.Sema,

	//time
	performance_frequency: f64,
	current_time:          f64,
	prev_counter:          f64,
	delta_time:            f64,
	config:                NodConfig,

	// user's game
	game:                  rawptr,
	fixed_update_game:     proc(_: rawptr, input_state: ^InputState),
	frame_update_game:     proc(_: rawptr, input_state: ^InputState),
	render_game:           proc(_: rawptr, nod: ^Nod, dt: f32),
	should_quit:           proc(_: rawptr) -> bool,
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

	nod.is_running = true
	nod.ecs_manager.world = create_world()

	if physics_world, err := get_resource(nod.ecs_manager.world.resources, PhysicsWorld);
	   err == .None {
		nod.physics_world = physics_world^
	}
	physics_init_world(&nod.physics_world)
	init_threads(nod)

	nod.window = window
	nod.renderer = renderer
	return nod, .None
}

nod_clean :: proc(nod: ^Nod) {
	if nod != nil {
		if nod.game != nil {
			// not allocated rn its just tests, probably add for real games
			// free(nod.game)
		}
		// Clean up input system
		// if nod.ecs_manager.world != nil && nod.ecs_manager.world.input_state != nil {
		// queue.destroy(&nod.ecs_manager.world.input_state.event_buffer)
		// }
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
		queue.destroy(&nod.command_queue.commands)
		if nod.physics_thread != nil {
			thread.destroy(nod.physics_thread)
		}

		physics_cleanup(&nod.physics_world)
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
	nod.performance_frequency = f64(sdl.GetPerformanceFrequency())
	nod.prev_counter = f64(sdl.GetPerformanceCounter())
	nod.current_time = nod.prev_counter / nod.performance_frequency
	accumulator := f64(0)
	nod.is_running = true


	for nod.is_running {
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
			push_command(&nod.command_queue, Command{type = .Quit})
			break
		}

		accumulator += frame_time
		loops := 0
		for accumulator > FIXED_DT { 	// && loops < MAX_FRAMESKIP
			process_fixed_update(input)
			// update game world
			fixed_update(nod)

			// signal physics thread
			push_command(&nod.command_queue, Command{type = .UpdatePhysics})
			sync.sema_wait(&nod.physics_complete)

			// update state buffer
			sync.mutex_lock(&nod.state_buffer.mutex)
			next_write := (nod.state_buffer.write_index + 1) % 3
			if next_write != nod.state_buffer.read_index {
				nod.state_buffer.write_index = next_write
			}
			sync.mutex_unlock(&nod.state_buffer.mutex)

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
		nod.render_game(nod.game, nod, interpolation)
	}

	sdl.RenderPresent(nod.renderer.handle)
}

// fixed_update :: proc(nod: ^Nod) {
// 	// quit event check
// 	if nod.input_state.quit_request ||
// 	   (nod.should_quit != nil && nod.game != nil && nod.should_quit(nod.game)) {
// 		fmt.println("received quit event")
// 		nod.is_running = false
// 		return
// 	}

// 	// ecs sytems
// 	systems_update(nod.ecs_manager.world, f32(nod.delta_time))

// 	// exposed fixed function
// 	if nod.fixed_update_game != nil && nod.game != nil {
// 		nod.fixed_update_game(nod.game, &nod.input_state)
// 	}
// }
fixed_update :: proc(nod: ^Nod) {
	input: ^InputState
	if inp, err := get_resource(nod.ecs_manager.world.resources, InputState); err == .None {
		input = inp
	} else {
		fmt.eprintln("Failed to get InputState Resource")
		nod.is_running = false
	}

	// quit event check
	if input.quit_request ||
	   (nod.should_quit != nil && nod.game != nil && nod.should_quit(nod.game)) {
		fmt.println("Received quit event")
		nod.is_running = false
		return
	}

	// fmt.println("Running fixed update with dt:", nod.delta_time) // Debug print
	systems_update(nod.ecs_manager.world, 1.0 / f32(TICKS_PER_SECOND))

	// user's game logic
	if nod.fixed_update_game != nil && nod.game != nil {
		nod.fixed_update_game(nod.game, input)
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
		if input, err := get_resource(nod.ecs_manager.world.resources, InputState); err == .None {
			nod.frame_update_game(nod.game, input)
		} else {
			fmt.eprintln("Failed to get InputState Resource")
			nod.is_running = false
		}
	}
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

