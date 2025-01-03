package nod

import "core:fmt"
import "core:mem"
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
	draw_sprite(&nod.renderer, game.sprite.texture.handle, game.s_rect, game.d_rect)
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

	if texture, ok := create_texture(renderer, "./assets/Hero_01.png"); ok == .None {
		game.sprite = create_sprite(texture)
	}
	// game.sprite = Sprite {
	// 	texture     = sdl_img.LoadTexture(renderer.handle, "./assets/Hero_01.png"),
	// 	source_rect = game.s_rect,
	// 	layer       = 0,
	// }

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
	fmt.println(get_time())
}

main :: proc() {
	args := os.args
	if len(args) > 1 {
		if args[1] == "ecs" {
			ecs_test()
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

	nod.is_running = true
	game.running = true
	fmt.println("running nod")
	nod_run(nod)
}

