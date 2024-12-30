package nod

import "core:fmt"
import "core:os"

import imgui "lib:odin-imgui"
import sdl "vendor:sdl2"
import sdl_img "vendor:sdl2/image"


Game :: struct {
	d_rect:         Rect,
	s_rect:         Rect,
	sprite:         Sprite,
	next_game_tick: u32,
	running:        bool,
}


display_game :: proc(game_ptr: rawptr, nod: ^Nod, interpolation: f32) {
	game := cast(^Game)game_ptr
	draw_sprite(&nod.renderer, game.sprite.texture, game.s_rect, game.d_rect)
}

game_update :: proc(game_ptr: rawptr, input_state: ^InputState) {
	game := cast(^Game)game_ptr
}

init_test :: proc(game: ^Game, renderer: ^Renderer) {
	game.d_rect.x = 0
	game.d_rect.y = 0
	game.d_rect.w = 96
	game.d_rect.h = 96

	game.s_rect.x = 0
	game.s_rect.y = 0
	game.s_rect.w = 96
	game.s_rect.h = 96

	game.running = false
	game.next_game_tick = sdl.GetTicks()

	game.sprite = Sprite {
		texture     = sdl_img.LoadTexture(renderer.handle, "./assets/Hero_01.png"),
		source_rect = game.s_rect,
		layer       = 0,
	}

}

fgame_update :: proc(game_ptr: rawptr, input_state: ^InputState) {
	game := cast(^Game)game_ptr
	if is_key_pressed(input_state, Key.ESCAPE) {
		// fmt.println("caught escape")
		game.running = false
	}
	if is_key_pressed(input_state, .W) {
		fmt.println("Pressed W")
	}
	if is_key_pressed(input_state, .S) {
		fmt.println("Pressed S")
	}
	if is_key_pressed(input_state, .A) {
		fmt.println("Pressed A")
	}
	if is_key_pressed(input_state, .D) {
		fmt.println("Pressed D")
	}
	if is_key_pressed(input_state, .SPACE) {
		fmt.println("Pressed SPACE")
	}
	if is_key_held(input_state, .SPACE) {
		fmt.println("Holding SPACE")
	}

}

game_should_quit :: proc(game_ptr: rawptr) -> bool {
	game := cast(^Game)game_ptr
	return !game.running
}

main :: proc() {
	args := os.args
	if len(args) > 1 {
		if args[1] == "test" {
			physics_test()
			return
		}
	}
	exit_status := 0
	defer os.exit(exit_status)
	nod, err := nod_init(
		NodConfig {
			window_title = "test",
			window_width = 1200,
			window_height = 800,
			target_fps = 60,
			vsync = false,
		},
	)
	if err != .None {
		fmt.println(err)
		return
	}
	defer nod_clean(nod)
	game: Game
	init_test(&game, &nod.renderer)
	nod.game = &game
	nod.fixed_update_game = game_update
	nod.frame_update_game = fgame_update
	nod.render_game = display_game
	nod.should_quit = game_should_quit

	nod.is_running = true
	game.running = true
	fmt.println("running nod")
	nod_run(nod)
}


// PHYSICS


PhysicsTest :: struct {
	using game: Game,
	floor_id:   EntityID,
	box_id:     EntityID,
}

init_physics_test :: proc(game: ^PhysicsTest, nod: ^Nod) {
	fmt.println("Initializing physics test")

	// Set and verify gravity
	set_gravity(nod, {0, -9.81})
	fmt.println("Set gravity to (0, -9.81)")

	// Create floor (static body)
	game.floor_id = 1
	floor_body := add_rigid_body(nod, game.floor_id, .Static, {0, -2})
	if floor_body == nil {
		fmt.println("Failed to create floor body!")
		return
	}
	fmt.println("Created floor body at y=-2")

	shape_id := add_box_collider(nod, game.floor_id, 5, 0.5, 1.0, 0.3, false)
	fmt.println("Added floor collider, shape_id:", shape_id)

	// Create falling box (dynamic body)
	game.box_id = 2
	box_body := add_rigid_body(nod, game.box_id, .Dynamic, {0, 5})
	if box_body == nil {
		fmt.println("Failed to create box body!")
		return
	}
	fmt.println("Created box body at y=5")

	shape_id = add_box_collider(nod, game.box_id, 0.5, 0.5, 1.0, 0.3, false)
	fmt.println("Added box collider, shape_id:", shape_id)

	// Verify physics world state
	fmt.println("\nPhysics world state:")
	fmt.println("Number of bodies:", len(nod.physics_world.bodies))
	for id, body in nod.physics_world.bodies {
		fmt.printf(
			"Body ID %d: type=%v, position=(%.2f, %.2f)\n",
			id,
			body.type,
			body.transform.position.x,
			body.transform.position.y,
		)
	}

	game.running = true
}

physics_test_update :: proc(game_ptr: rawptr, input_state: ^InputState) {
	game := cast(^PhysicsTest)game_ptr
	if is_key_pressed(input_state, .ESCAPE) {
		game.running = false
	}
}

physics_test_display :: proc(game_ptr: rawptr, nod: ^Nod, interpolation: f32) {
	game := cast(^PhysicsTest)game_ptr

	// Get and print positions with error checking
	floor_pos := get_position(nod, game.floor_id)
	box_pos := get_position(nod, game.box_id)
	box_vel := get_velocity(nod, game.box_id)

	fmt.printf(
		"Floor pos: (%.2f, %.2f) | Box pos: (%.2f, %.2f) | Box vel: (%.2f, %.2f)\n",
		floor_pos.x,
		floor_pos.y,
		box_pos.x,
		box_pos.y,
		box_vel.x,
		box_vel.y,
	)
}

physics_test_should_quit :: proc(game_ptr: rawptr) -> bool {
	game := cast(^PhysicsTest)game_ptr
	return !game.running
}

physics_test :: proc() {
	fmt.println("Starting physics test initialization")

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
		fmt.println("Failed to init:", err)
		return
	}
	defer nod_clean(nod)

	test: PhysicsTest
	init_physics_test(&test, nod)

	nod.game = &test
	nod.fixed_update_game = physics_test_update
	nod.frame_update_game = physics_test_update
	nod.render_game = physics_test_display
	nod.should_quit = physics_test_should_quit

	fmt.println("Setup complete, starting game loop")
	nod_run(nod)
}

