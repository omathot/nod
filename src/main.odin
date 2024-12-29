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


display_game :: proc(game_ptr: rawptr, engine_renderer: ^Renderer, interpolation: f32) {
	game := cast(^Game)game_ptr
	draw_sprite(engine_renderer, game.sprite.texture, game.s_rect, game.d_rect)
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
	if is_key_held(input_state, Key.ESCAPE) {
		// fmt.println("held escape")
		game.running = false
	}

}

game_should_quit :: proc(game_ptr: rawptr) -> bool {
	game := cast(^Game)game_ptr
	return !game.running
}

main :: proc() {
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

