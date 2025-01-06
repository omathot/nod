package game

import nod "../src"
import "core:fmt"
import "core:math"
import "core:mem"
import sdl "vendor:sdl2"

METERS_PER_PIXEL :: 100.0

// Tags for our game entities
Player :: struct {}
Enemy :: struct {}
Bullet :: struct {}

// Game-specific components
Velocity :: struct {
	vec: nod.Vec2,
}

Health :: struct {
	current: int,
	max:     int,
}

// Main game struct
CapsuleGame :: struct {
	running: bool,
	player:  nod.EntityID,
}

// Systems
player_movement_system :: proc(world: ^nod.World, dt: f32) {
	input := nod.get_input(world)
	if input == nil do return

	if nod.is_key_pressed(input, .ESCAPE) {
		input.quit_request = true
		return
	}

	q := nod.query(world, {})
	defer delete(q.match_archetype)

	it := nod.iterate_query(&q)
	for entity, ok := nod.next_entity(&it); ok; entity, ok = nod.next_entity(&it) {
		if !nod.has_tag(world, entity, Player) do continue

		// Handle movement
		move_dir := nod.Vec2{}
		if nod.is_key_held(input, .W) do move_dir.y -= 1
		if nod.is_key_held(input, .S) do move_dir.y += 1
		if nod.is_key_held(input, .A) do move_dir.x -= 1
		if nod.is_key_held(input, .D) do move_dir.x += 1

		if move_dir.x != 0 || move_dir.y != 0 {
			fmt.printfln("Moving with impulse x: %v, y: %v", move_dir.x, move_dir.y)
			pos := nod.get_position(world, entity)
			nod.apply_force(
				world,
				entity,
				{move_dir.x * 200 * METERS_PER_PIXEL, move_dir.y * 200 * METERS_PER_PIXEL},
				pos,
			)
		}

		// Shoot bullets
		if nod.is_key_pressed(input, .SPACE) {
			pos := nod.get_position(world, entity)
			bullet := nod.spawn_tagged(world, Bullet)
			nod.set_position(world, bullet, {pos.x, pos.y - 20})
			nod.apply_impulse(world, bullet, {0, -400}, pos)
		}
	}
}

enemy_ai_system :: proc(world: ^nod.World, dt: f32) {
	q := nod.query(world, {})
	defer delete(q.match_archetype)

	it := nod.iterate_query(&q)
	for entity, ok := nod.next_entity(&it); ok; entity, ok = nod.next_entity(&it) {
		if !nod.has_tag(world, entity, Enemy) do continue

		pos := nod.get_position(world, entity)
		time_res, _ := nod.get_resource(world.resources, nod.TimeResource)
		new_x := 400 + math.cos_f64(f64(time_res.total_time)) * 300
		nod.set_position(world, entity, {new_x, pos.y})
	}
}

bullet_collision_system :: proc(world: ^nod.World, dt: f32) {
	q := nod.query(world, {})
	defer delete(q.match_archetype)

	it := nod.iterate_query(&q)
	for entity, ok := nod.next_entity(&it); ok; entity, ok = nod.next_entity(&it) {
		if !nod.has_tag(world, entity, Bullet) do continue

		hits := nod.get_hits(world, entity)
		defer delete(hits)

		for hit in hits {
			other_id := hit.body_a if hit.body_a != entity else hit.body_b
			if nod.has_tag(world, other_id, Enemy) {
				nod.destroy_entity(world, entity)
				nod.destroy_entity(world, other_id)
			}
		}
	}
}

init_capsule_game :: proc(game: ^CapsuleGame, nod_inst: ^nod.Nod) {
	world := nod_inst.ecs_manager.world
	game.running = true

	transform_id := nod.get_or_register_component(world, nod.Transform)
	sprite_id := nod.get_or_register_component(world, nod.SpriteComponent)
	physics_id := nod.get_or_register_component(world, nod.RigidBody)

	texture, err := nod.create_texture(&nod_inst.renderer, "./assets/Hero_01.png")
	if err != .None {
		fmt.eprintln("Error: Failed to load texture for player")
		return
	}
	// defer free(texture)

	w, h := nod.texture_get_dimensions(texture)
	fmt.println("Texture dimensions:", w, h)

	// Register tags
	nod.register_tag(world, Player, []nod.ComponentID{transform_id, sprite_id, physics_id})

	// Spawn player
	game.player = nod.spawn_tagged(world, Player)

	// Set sprite component
	if sprite, ok := nod.get_component_typed(world, game.player, sprite_id, nod.SpriteComponent);
	   ok {
		fmt.println("Setting sprite component")
		sprite.texture = texture
		sprite.rect = nod.Rect{0, 0, 96, 96}
		sprite.color = {255, 255, 255, 255} // Full white for no tinting
		sprite.z_index = 0

		// Verify sprite was set
		fmt.println("Sprite texture:", sprite.texture != nil)
		fmt.println("Sprite rect:", sprite.rect)
	} else {
		fmt.println("Failed to get sprite component")
	}

	// Set transform
	if transform, ok := nod.get_component_typed(world, game.player, transform_id, nod.Transform);
	   ok {
		transform.position = {400, 300}
		transform.scale = {1, 1}
		transform.rotation = 0

		fmt.println("Transform position:", transform.position)
	}

	// Add physics components
	nod.add_capsule_collider(world, game.player, 0, 32, 16, 0.1, 0.3, false)
	nod.set_gravity(world, {0, 0})

	// Register systems
	nod.system_add(world, "player_movement", {}, player_movement_system)
	nod.system_add(world, "enemy_ai", {}, enemy_ai_system)
	nod.system_add(world, "bullet_collision", {}, bullet_collision_system)
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer {
		for _, leak in track.allocation_map {
			fmt.eprintfln("%v leaked %v bytes", leak.location, leak.size)
		}
		mem.tracking_allocator_destroy(&track)
	}

	nod_inst, err := nod.nod_init(
		nod.NodConfig {
			window_title = "Space Shooter",
			window_width = 800,
			window_height = 600,
			target_fps = 60,
			vsync = false,
		},
	)
	if err != .None {
		fmt.println("Failed to init Nod")
		return
	}
	defer nod.nod_clean(nod_inst)

	game: CapsuleGame
	init_capsule_game(&game, nod_inst)
	nod_inst.game = &game

	fmt.println("Starting game loop")
	nod.nod_run(nod_inst)
}

