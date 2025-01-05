package nod

import "core:fmt"
import "core:mem"
import sdl "vendor:sdl2"

PIXELS_PER_METER :: 100.0
WALL_THICKNESS_PIXELS :: 20.0 // For rendering
WALL_THICKNESS_METERS :: WALL_THICKNESS_PIXELS / PIXELS_PER_METER // For physics

PhysicsTest :: struct {
	running:       bool,
	player_entity: EntityID,
	wall_entities: [4]EntityID, // top, right, bottom, left walls
	test_texture:  ^Texture,
}

physics_movement_system :: proc(world: ^World, dt: f32) {
	input := get_input(world)
	if is_key_pressed(input, .ESCAPE) {
		input.quit_request = true
		return
	}

	// Get player entity from Resource since we can't pass it directly to the system
	if physics_state, err := get_resource(world.resources, PhysicsTest); err == .None {
		pos := get_position(world, physics_state.player_entity)
		impulse_strength := f64(500.0 * PIXELS_PER_METER)
		force_strength := f64(50000.0 * PIXELS_PER_METER)

		if is_key_pressed(input, .S) || is_key_held(input, .S) {
			apply_force(world, physics_state.player_entity, {0, force_strength}, pos)
			// apply_impulse(world, physics_state.player_entity, {0, impulse_strength}, pos)
		}
		if is_key_pressed(input, .A) || is_key_held(input, .A) {
			apply_force(world, physics_state.player_entity, {-force_strength, 0}, pos)
			// apply_impulse(world, physics_state.player_entity, {-impulse_strength, 0}, pos)
		}
		if is_key_pressed(input, .D) | is_key_held(input, .D) {
			apply_force(world, physics_state.player_entity, {force_strength, 0}, pos)
			// apply_impulse(world, physics_state.player_entity, {impulse_strength, 0}, pos)
		}
		if is_key_pressed(input, .SPACE) {
			apply_impulse(world, physics_state.player_entity, {0, -impulse_strength}, pos)
		}
	}
}

create_wall :: proc(
	game: ^PhysicsTest,
	world: ^World,
	pos: Vec2,
	size: Vec2,
	is_horizontal: bool,
) -> EntityID {
	wall := create_entity(world)

	// Add static physics body
	body := add_rigid_body(world, wall, .Static, pos)
	if body != nil {
		// Don't scale the collider size - we want it to match screen coordinates
		add_box_collider(
			world,
			wall,
			f32(size.x / 2), // Use full pixel sizes
			f32(size.y / 2),
			0.0,
			0.3,
			false,
		)
	}

	// Add transform for rendering
	transform := Transform {
		position = pos,
		rotation = 0,
		scale    = {1, 1},
	}
	add_component(world, wall, transform_component_id, &transform)

	// Add sprite
	sprite := SpriteComponent {
		texture = game^.test_texture,
		rect    = Rect{0, 0, int(size.x), int(size.y)},
		color   = {128, 128, 128, 255},
		z_index = 0,
	}
	add_component(world, wall, sprite_component_id, &sprite)

	return wall
}

init_physics_test :: proc(game: ^PhysicsTest, nod: ^Nod) {
	// Create camera
	camera_entity := create_entity(nod.ecs_manager.world)
	camera := CameraComponent {
		projection_type = .Orthographic,
		viewport        = Rect{0, 0, 800, 600},
		zoom            = 1.0,
		is_active       = true,
	}
	add_component(nod.ecs_manager.world, camera_entity, camera_component_id, &camera)

	camera_transform := Transform {
		position = {400, 300},
		rotation = 0,
		scale    = {1, 1},
	}
	add_component(nod.ecs_manager.world, camera_entity, transform_component_id, &camera_transform)

	// Create test texture
	surface := sdl.CreateRGBSurface(0, 50, 50, 32, 0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF)
	if surface == nil {
		return
	}
	defer sdl.FreeSurface(surface)

	sdl.FillRect(surface, nil, sdl.MapRGBA(surface.format, 255, 0, 0, 255))

	game^.test_texture = new(Texture)
	game^.test_texture.handle = sdl.CreateTextureFromSurface(nod.renderer.handle, surface)
	if game^.test_texture.handle == nil {
		free(game^.test_texture)
		return
	}

	// Set gravity
	set_gravity(nod.ecs_manager.world, {0, 9.81 * PIXELS_PER_METER}) // Positive Y is down

	// Create player entity
	game^.player_entity = create_entity(nod.ecs_manager.world)

	// Add dynamic physics body to player
	player_body := add_rigid_body(nod.ecs_manager.world, game^.player_entity, .Dynamic, {400, 300})
	if player_body != nil {
		add_box_collider(nod.ecs_manager.world, game^.player_entity, 25, 25, 0.1, 0.3, false)
		// set_linear_damping(nod.ecs_manager.world, game^.player_entity, 0.5) // Add some drag
	}

	player_transform := Transform {
		position = {400, 100},
		rotation = 0,
		scale    = {1, 1},
	}
	add_component(
		nod.ecs_manager.world,
		game^.player_entity,
		transform_component_id,
		&player_transform,
	)

	player_sprite := SpriteComponent {
		texture = game^.test_texture,
		rect    = Rect{0, 0, 50, 50},
		color   = {255, 0, 0, 255},
		z_index = 1,
	}
	add_component(nod.ecs_manager.world, game^.player_entity, sprite_component_id, &player_sprite)

	FLOOR_THICKNESS :: 20.0
	floor := create_wall(
		game,
		nod.ecs_manager.world,
		{400, 550}, // Position near bottom of screen
		{10000, FLOOR_THICKNESS}, // Full width, modest thickness
		true,
	)
	game^.wall_entities[0] = floor
	// Add movement system
	system_add(nod.ecs_manager.world, "Physics Movement", {}, physics_movement_system)

	// Add the PhysicsTest struct as a resource so the system can access it
	insert_resource(nod.ecs_manager.world.resources, PhysicsTest, game^)

	game^.running = true
}

ecs_test :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer alloc_clean(&track)

	nod, err := nod_init(
		NodConfig {
			window_title = "Physics Test",
			window_width = 800,
			window_height = 600,
			target_fps = 60,
			vsync = false,
		},
	)

	if err != .None {
		return
	}
	defer nod_clean(nod)

	test: PhysicsTest
	init_physics_test(&test, nod)
	nod.game = &test

	nod_run(nod)

	if test.test_texture != nil {
		destroy_texture(test.test_texture)
	}
}

alloc_clean :: proc(track: ^mem.Tracking_Allocator) {
	for _, leak in track.allocation_map {
		fmt.printfln("%v leaked %v bytes", leak.location, leak.size)
	}
	mem.tracking_allocator_destroy(track)
}

