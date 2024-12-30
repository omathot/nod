package nod

import "core:container/queue"
import "core:fmt"
import "core:sync"
import "core:thread"
import sdl "vendor:sdl2"

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
	transform: map[EntityID]TransformState,
	input:     InputSnapshot,
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

InputSnapshot :: struct {
	keyboard:       bit_set[Key],
	mouse_position: Vec2,
	mouse_buttons:  bit_set[MouseButton],
}

TransformState :: struct {
	position: Vec2,
	rotation: f32,
	scale:    Vec2,
}

init_threads :: proc(nod: ^Nod) {
	queue.init(&nod.command_queue.commands)

	// semaphores
	nod.command_queue.sem = sync.Sema{}
	nod.physics_complete = sync.Sema{}

	// state buffer indices
	nod.state_buffer.read_index = 0
	nod.state_buffer.write_index = 1

	nod.physics_thread = thread.create_and_start_with_data(nod, proc(data: rawptr) {
		nod := cast(^Nod)data
		physics_thread_loop(nod)
	})
}


push_command :: proc(cmd_queue: ^CommandQueue, cmd: Command) {
	sync.mutex_lock(&cmd_queue.mutex)
	defer sync.mutex_unlock(&cmd_queue.mutex)
	queue.push_back(&cmd_queue.commands, cmd)
	sync.sema_post(&cmd_queue.sem)
}

pop_command :: proc(cmd_queue: ^CommandQueue) -> (Command, bool) {
	sync.mutex_lock(&cmd_queue.mutex)
	defer sync.mutex_unlock(&cmd_queue.mutex)
	if queue.len(cmd_queue.commands) == 0 {
		return Command{}, false
	}
	return queue.pop_front(&cmd_queue.commands), true
}

physics_thread_loop :: proc(nod: ^Nod) {
	// fmt.println("Physics thread started")
	for nod.is_running {
		// fmt.println("Physics: Waiting for command")
		sync.sema_wait(&nod.command_queue.sem)
		// fmt.println("Physics: Got semaphore signal")

		if cmd, ok := pop_command(&nod.command_queue); ok {
			// fmt.println("Physics: Processing command:", cmd.type)
			#partial switch cmd.type {
			case .UpdatePhysics:
				physics_update(&nod.physics_world, 1.0 / f32(TICKS_PER_SECOND))
				// fmt.println("Physics: Update complete, posting completion")
				sync.sema_post(&nod.physics_complete)
			case .Quit:
				// fmt.println("Physics: Quit command received")
				sync.sema_post(&nod.physics_complete)
				break
			}
		} else {
			// fmt.println("Physics: Failed to get command")
		}
	}
	// fmt.println("Physics thread ended")
}

