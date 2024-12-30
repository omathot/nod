package nod

import "core:fmt"
import "core:mem"
import sdl "vendor:sdl2"

ECSTest :: struct {
	using game:  Game,
	entity:      EntityID,
	position_id: ComponentID,
	velocity_id: ComponentID,
}
TestPosition :: struct {
	x, y: f32,
}

TestVelocity :: struct {
	x, y: f32,
}

test_position_id: ComponentID
test_velocity_id: ComponentID

movement_system :: proc(world: ^World, dt: f32) {
	required := bit_set[0 ..= MAX_COMPONENTS]{}
	required += {int(test_position_id), int(test_velocity_id)}

	fmt.println("\nMovement system running")
	fmt.println("Required components:", required)

	q := query(world, required)
	defer delete(q.match_archetype)

	fmt.println("Query found", len(q.match_archetype), "matching archetypes")

	it := iterate_query(&q)
	found_entities := 0
	for entity, ok := next_entity(&it); ok; entity, ok = next_entity(&it) {
		found_entities += 1
		pos, pos_ok := get_component_typed(world, entity, test_position_id, TestPosition)
		vel, vel_ok := get_component_typed(world, entity, test_velocity_id, TestVelocity)

		if pos_ok && vel_ok {
			fmt.printf(
				"Updating entity %d pos:(%f, %f) vel:(%f, %f) dt:%f\n",
				entity,
				pos.x,
				pos.y,
				vel.x,
				vel.y,
				dt,
			)
			pos.x += vel.x * dt
			pos.y += vel.y * dt
		}
	}
	fmt.println("Movement system processed", found_entities, "entities")
}

init_ecs_test :: proc(game: ^ECSTest, nod: ^Nod) {
	fmt.println("Initializing ECS test")

	// Register components
	test_position_id = register_component(nod.ecs_manager.world, TestPosition)
	test_velocity_id = register_component(nod.ecs_manager.world, TestVelocity)
	fmt.println("Registered components:", test_position_id, test_velocity_id)

	// Add movement system - store the ID
	required := bit_set[0 ..= MAX_COMPONENTS]{}
	required += {int(test_position_id), int(test_velocity_id)}
	fmt.println("System required components:", required)
	movement_sys_id := system_add(nod.ecs_manager.world, "Movement", required, movement_system)
	fmt.println("Added movement system with ID:", movement_sys_id)

	// Create test entity
	game.entity = create_entity(nod.ecs_manager.world)
	fmt.println("Created entity:", game.entity)

	// Add components with verification
	pos := TestPosition {
		x = 400,
		y = 300,
	}
	err := add_component(nod.ecs_manager.world, game.entity, test_position_id, &pos)
	if err != .None {
		fmt.println("Error adding position component:", err)
		return
	}

	// Verify position was added
	if pos_ptr, ok := get_component_typed(
		nod.ecs_manager.world,
		game.entity,
		test_position_id,
		TestPosition,
	); ok {
		fmt.printf("Position component added successfully: (%f, %f)\n", pos_ptr.x, pos_ptr.y)
	}

	vel := TestVelocity {
		x = 100,
		y = 50,
	}
	err = add_component(nod.ecs_manager.world, game.entity, test_velocity_id, &vel)
	if err != .None {
		fmt.println("Error adding velocity component:", err)
		return
	}

	// Verify velocity was added
	if vel_ptr, ok := get_component_typed(
		nod.ecs_manager.world,
		game.entity,
		test_velocity_id,
		TestVelocity,
	); ok {
		fmt.printf("Velocity component added successfully: (%f, %f)\n", vel_ptr.x, vel_ptr.y)
	}

	// Verify entity has correct archetype
	if archetype_id, ok := nod.ecs_manager.world.entity_to_archetype[game.entity]; ok {
		archetype := nod.ecs_manager.world.archetypes[archetype_id]
		fmt.println("Entity archetype mask:", archetype.component_mask)
	}

	game.running = true
}

ecs_test_update :: proc(game_ptr: rawptr, input_state: ^InputState) {
	game := cast(^ECSTest)game_ptr
	if is_key_pressed(input_state, .ESCAPE) {
		game.running = false
	}
}

ecs_test_display :: proc(game_ptr: rawptr, nod: ^Nod, interpolation: f32) {
	game := cast(^ECSTest)game_ptr

	if pos_ptr, ok := get_component_typed(
		nod.ecs_manager.world,
		game.entity,
		game.position_id,
		TestPosition,
	); ok {
		fmt.printf("Display - Drawing at: (%f, %f)\n", pos_ptr.x, pos_ptr.y)
		sdl.SetRenderDrawColor(nod.renderer.handle, 255, 0, 0, 255)
		rect := sdl.Rect{i32(pos_ptr.x - 25), i32(pos_ptr.y - 25), 50, 50}
		sdl.RenderFillRect(nod.renderer.handle, &rect)
	}
}
ecs_test_should_quit :: proc(game_ptr: rawptr) -> bool {
	game := cast(^ECSTest)game_ptr
	return !game.running
}

alloc_clean :: proc(track: ^mem.Tracking_Allocator) {
	for _, leak in track.allocation_map {
		fmt.printfln("%v leaked %v bytes", leak.location, leak.size)
	}
	mem.tracking_allocator_destroy(track)
}

ecs_test :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer alloc_clean(&track)

	fmt.println("Starting ECS test")
	nod, err := nod_init(
		NodConfig {
			window_title = "ECS Test",
			window_width = 800,
			window_height = 600,
			target_fps = 60,
			vsync = false,
		},
	)

	if err != .None {
		fmt.println("Failed to init:", err)
		return
	}
	defer nod_clean(nod)

	test: ECSTest
	init_ecs_test(&test, nod)

	nod.game = &test
	nod.fixed_update_game = ecs_test_update
	nod.frame_update_game = ecs_test_update
	nod.render_game = ecs_test_display
	nod.should_quit = ecs_test_should_quit

	fmt.println("Setup complete, starting game loop")
	nod_run(nod)
}

