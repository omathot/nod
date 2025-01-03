package game

import nod "../src"
import "core:fmt"
import "core:math"
import "core:mem"

// / Global component IDs
transform_id: nod.ComponentID
sprite_id: nod.ComponentID
rigidbody_id: nod.ComponentID

CapsuleGame :: struct {
	game:         nod.Game,
	entity_id:    nod.EntityID,
	sprite_id:    nod.ComponentID,
	transform_id: nod.ComponentID,
	rigidbody_id: nod.ComponentID,
	running:      bool,
}

// Components
SpriteComponent :: struct {
	sprite: nod.Sprite,
	layer:  int,
}

// System that uses TimeResource
update_capsule_system :: proc(world: ^nod.World, dt: f32) {
	// Get TimeResource
	time_res, time_err := nod.get_resource(world.resources, nod.TimeResource)
	if time_err != .None {
		return
	}
	fmt.printf("Total time: %.2f, Delta: %.2f\n", time_res.total_time, time_res.delta_time)

	// Query for entities with both Transform and Sprite components
	required := bit_set[0 ..= nod.MAX_COMPONENTS]{}
	required += {int(transform_id), int(sprite_id)}

	q := nod.query(world, required)
	defer delete(q.match_archetype)

	it := nod.iterate_query(&q)
	for entity, ok := nod.next_entity(&it); ok; entity, ok = nod.next_entity(&it) {
		if transform, ok := nod.get_component_typed(world, entity, transform_id, nod.Transform);
		   ok {
			// Update transform based on time
			transform.position.y = 400 + 100 * math.sin_f64(f64(time_res.total_time))
		}
	}
}

init_capsule_game :: proc(game: ^CapsuleGame, nod_inst: ^nod.Nod) {
	game.running = true

	// Register components
	game.transform_id = nod.register_component(nod_inst.ecs_manager.world, nod.Transform)
	game.sprite_id = nod.register_component(nod_inst.ecs_manager.world, SpriteComponent)
	game.rigidbody_id = nod.register_component(nod_inst.ecs_manager.world, nod.RigidBody)

	// Create entity
	game.entity_id = nod.create_entity(nod_inst.ecs_manager.world)

	// Add transform component
	transform := nod.Transform {
		position = {400, 400},
		rotation = 0,
		scale    = {1, 1},
	}
	nod.add_component(nod_inst.ecs_manager.world, game.entity_id, game.transform_id, &transform)

	// Create and add sprite component
	if texture, ok := nod.create_texture(&nod_inst.renderer, "./assets/Hero_01.png"); ok == .None {
		sprite := nod.create_sprite(texture)
		sprite_comp := SpriteComponent {
			sprite = sprite,
			layer  = 0,
		}
		nod.add_component(nod_inst.ecs_manager.world, game.entity_id, game.sprite_id, &sprite_comp)
	}

	// Add physics body and capsule collider
	physics_body := nod.add_rigid_body(nod_inst, game.entity_id, .Dynamic, {400, 400})
	nod.add_capsule_collider(nod_inst, game.entity_id, 0, 32, 16, 1.0, 0.3, false)

	// Add update system
	required := bit_set[0 ..= nod.MAX_COMPONENTS]{}
	required += {int(game.transform_id), int(game.sprite_id)}
	nod.system_add(nod_inst.ecs_manager.world, "capsule_update", required, update_capsule_system)
}

game_update :: proc(game_ptr: rawptr, input_state: ^nod.InputState) {
	game := cast(^CapsuleGame)game_ptr
	if nod.is_key_pressed(input_state, .ESCAPE) {
		game.running = false
	}
}

display_game :: proc(game_ptr: rawptr, nod_inst: ^nod.Nod, interpolation: f32) {
	game := cast(^CapsuleGame)game_ptr
	if sprite_comp, ok := nod.get_component_typed(
		nod_inst.ecs_manager.world,
		game.entity_id,
		game.sprite_id,
		SpriteComponent,
	); ok {
		if transform, ok := nod.get_component_typed(
			nod_inst.ecs_manager.world,
			game.entity_id,
			game.transform_id,
			nod.Transform,
		); ok {
			dest_rect := nod.Rect {
				x = int(transform.position.x) - 16,
				y = int(transform.position.y) - 32,
				w = 32,
				h = 64,
			}
			nod.draw_sprite(
				&nod_inst.renderer,
				sprite_comp.sprite.texture.handle,
				sprite_comp.sprite.source_rect,
				dest_rect,
			)
		}
	}
}

game_should_quit :: proc(game_ptr: rawptr) -> bool {
	game := cast(^CapsuleGame)game_ptr
	return !game.running
}

main :: proc() {
	// memory sanity check
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
			window_title = "Capsule Test",
			window_width = 1200,
			window_height = 800,
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
	nod_inst.fixed_update_game = game_update
	nod_inst.frame_update_game = game_update
	nod_inst.render_game = display_game
	nod_inst.should_quit = game_should_quit

	fmt.println("Starting game loop")
	nod.nod_run(nod_inst)
}

