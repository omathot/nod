package game

import nod "../src"
import "core:fmt"
import "core:math"
import "core:mem"
import sdl "vendor:sdl2"

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
			pos := nod.get_position(world, entity)
			nod.apply_impulse(world, entity, {move_dir.x * 200, move_dir.y * 200}, pos)
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

	// Register components
	transform_id := nod.get_or_register_component(world, nod.Transform)
	sprite_id := nod.get_or_register_component(world, nod.SpriteComponent)
	physics_id := nod.get_or_register_component(world, nod.RigidBody)

	// Register tags first!
	nod.register_tag(world, Player, []nod.ComponentID{transform_id, sprite_id, physics_id})
	nod.register_tag(world, Enemy, []nod.ComponentID{transform_id, sprite_id, physics_id})
	nod.register_tag(world, Bullet, []nod.ComponentID{transform_id, sprite_id, physics_id})

	// Create player entity
	game.player = nod.spawn_tagged(world, Player)

	// Create and setup texture
	surface := sdl.CreateRGBSurface(0, 50, 50, 32, 0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF)
	if surface == nil do return
	defer sdl.FreeSurface(surface)

	sdl.FillRect(surface, nil, sdl.MapRGBA(surface.format, 0, 255, 0, 255))

	test_texture := new(nod.Texture)
	test_texture.handle = sdl.CreateTextureFromSurface(nod_inst.renderer.handle, surface)
	if test_texture.handle == nil {
		free(test_texture)
		return
	}

	// Set component values directly
	if sprite, ok := nod.get_component_typed(world, game.player, sprite_id, nod.SpriteComponent);
	   ok {
		sprite.texture = test_texture
		sprite.rect = nod.Rect{0, 0, 50, 50}
		sprite.color = {0, 255, 0, 255}
	}

	if transform, ok := nod.get_component_typed(world, game.player, transform_id, nod.Transform);
	   ok {
		transform.position = {400, 500}
	}

	// Add physics components
	nod.add_capsule_collider(world, game.player, 0, 32, 16, 1.0, 0.3, false)
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
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)
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

