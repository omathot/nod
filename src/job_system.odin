package nod

import "core:container/queue"
import "core:sync"
import "core:thread"

// Helper structs and procedures
FixedUpdateData :: struct {
	world:       ^World,
	input:       ^InputState,
	dt:          f64,
	completion:  ^sync.Sema,
	should_quit: ^bool,
}

VariableUpdateData :: struct {
	world:      ^World,
	dt:         f32,
	completion: ^sync.Sema,
}


Job :: struct {
	procedure:     proc(data: rawptr),
	data:          rawptr,
	completion:    ^sync.Sema,
	creation_time: f64,
}

WorkerContext :: struct {
	jobs:       ^queue.Queue(Job),
	mutex:      ^sync.Mutex,
	semaphore:  ^sync.Sema,
	is_running: ^bool,
}

JobSystem :: struct {
	workers:         [dynamic]^thread.Thread,
	contexts:        [dynamic]^WorkerContext,
	job_queue:       queue.Queue(Job),
	queue_mutex:     sync.Mutex,
	queue_semaphore: sync.Sema,
	is_running:      bool,
}


create_job_system :: proc(num_threads := 4) -> ^JobSystem {
	system := new(JobSystem)
	system.workers = make([dynamic]^thread.Thread)
	system.contexts = make([dynamic]^WorkerContext)
	queue.init(&system.job_queue)
	system.is_running = true

	for i := 0; i < num_threads; i += 1 {
		ctx := new(WorkerContext)
		ctx.jobs = &system.job_queue
		ctx.mutex = &system.queue_mutex
		ctx.semaphore = &system.queue_semaphore
		ctx.is_running = &system.is_running

		worker := thread.create_and_start_with_data(ctx, worker_proc)
		append(&system.workers, worker)
		append(&system.contexts, ctx)
	}

	return system
}

destroy_job_system :: proc(system: ^JobSystem) {
	if system == nil do return

	system.is_running = false
	for i := 0; i < len(system.workers); i += 1 {
		sync.sema_post(&system.queue_semaphore)
	}

	for worker in system.workers {
		thread.join(worker)
		thread.destroy(worker)
	}

	for ctx in system.contexts {
		free(ctx)
	}

	delete(system.workers)
	delete(system.contexts)
	queue.destroy(&system.job_queue)
	free(system)
}


worker_proc :: proc(data: rawptr) {
	ctx := cast(^WorkerContext)data
	for ctx.is_running^ {
		sync.sema_wait(ctx.semaphore)
		if !ctx.is_running^ do break

		sync.mutex_lock(ctx.mutex)
		if queue.len(ctx.jobs^) > 0 {
			job := queue.pop_front(ctx.jobs)
			sync.mutex_unlock(ctx.mutex)

			// run
			job.procedure(job.data)

			// signal complete
			if job.completion != nil {
				sync.sema_post(job.completion)
			}
		} else {
			sync.mutex_unlock(ctx.mutex)
		}
	}
}

schedule_job :: proc(system: ^JobSystem, job: Job) {
	sync.mutex_lock(&system.queue_mutex)
	queue.push_back(&system.job_queue, job)
	sync.mutex_unlock(&system.queue_mutex)
	sync.sema_post(&system.queue_semaphore)
}

fixed_update_job :: proc(data: rawptr) {
	update_data := cast(^FixedUpdateData)data

	process_fixed_update(update_data.input)

	if update_data.input.quit_request {
		update_data.should_quit^ = true
		return
	}

	systems_update(update_data.world, f32(update_data.dt))
}

variable_update_job :: proc(data: rawptr) {
	update_date := cast(^VariableUpdateData)data

	// !EXAMPLES
	// particle_system(update_date.world, update_date.dt)
	// camera_smooth_system(update_date.world, update_date.dt)
	// ui_animation_system(update_date.world, update_date.dt)
	// visual_effects_system(update_date.world, update_date.dt)
}

