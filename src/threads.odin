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

PhysicsThreadContext :: struct {
	world:            ^World,
	command_queue:    ^CommandQueue,
	physics_complete: ^sync.Sema,
	is_running:       ^bool, // nod.is_running
}

init_threads :: proc(nod: ^Nod) {
	queue.init(&nod.command_queue.commands)

	// semaphores
	nod.command_queue.sem = sync.Sema{}
	nod.physics_complete = sync.Sema{}

	// state buffer indices
	nod.state_buffer.read_index = 0
	nod.state_buffer.write_index = 1

	// context
	nod.physics_thread_ctx = new(PhysicsThreadContext)
	nod.physics_thread_ctx.world = nod.ecs_manager.world
	nod.physics_thread_ctx.command_queue = &nod.command_queue
	nod.physics_thread_ctx.physics_complete = &nod.physics_complete
	nod.physics_thread_ctx.is_running = &nod.is_running

	nod.physics_thread = thread.create_and_start_with_data(
		nod.physics_thread_ctx,
		physics_thread_loop,
	)
}

cleanup_threads :: proc(nod: ^Nod) {
	if nod == nil do return

	if nod.is_running {
		push_command(&nod.command_queue, Command{type = .Quit})
	}

	if nod.physics_thread != nil {
		thread.join(nod.physics_thread)
		free(nod.physics_thread_ctx)
		thread.destroy(nod.physics_thread)
	}

	sync.mutex_lock(&nod.command_queue.mutex)
	queue.destroy(&nod.command_queue.commands)
	sync.mutex_unlock(&nod.command_queue.mutex)
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

physics_thread_loop :: proc(data: rawptr) {
	ctx := cast(^PhysicsThreadContext)data

	for ctx.is_running^ {
		sync.sema_wait(&ctx.command_queue.sem)

		if cmd, ok := pop_command(ctx.command_queue); ok {
			#partial switch cmd.type {
			case .UpdatePhysics:
				if physics_world, err := get_resource(ctx.world.resources, PhysicsWorld);
				   err == .None {
					physics_update(physics_world, 1.0 / f32(TICKS_PER_SECOND))
				}
				sync.sema_post(ctx.physics_complete)
			case .Quit:
				sync.sema_post(ctx.physics_complete)
				break
			}
		}
	}
}

