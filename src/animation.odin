package nod

// import "core:strings"

// import sdl "vendor:sdl2"
// // import sdl_img "vendor:sdl2/image"

// // TextureAtlasLayout :: struct {
// // 	size: [2]int,	// represent a Rect with x, y. Where x is min(min, min) and Y is max (max, max)
// // 	textures: [dynamic][2]int
// // }

// // TextureAtlasLayouts :: struct {
// // 	list: [dynamic]TextureAtlasLayout
// // }

// Animations :: struct {
// 	list: map[string]^Animation,
// 	len:  u32,
// }

// Animation :: struct {
// 	sprite: Sprite,
// 	count:  u8,
// 	index:  u8,
// 	flip:   bool,
// }

// make_animation :: proc(
// 	game: ^Game,
// 	path: string,
// 	count: u8,
// 	sprite_size: u32,
// 	s_rect: Rect,
// ) -> Animation {
// 	texture := sdl_img.LoadTexture(game.renderer, strings.clone_to_cstring(path))
// 	sprite := Sprite{texture, s_rect, 0}
// 	animation := Animation {
// 		sprite = sprite,
// 		count  = count,
// 		index  = 0,
// 		flip   = false,
// 	}
// 	return animation
// }

// insert_animation :: proc(list: ^map[string]Animation, name: string, animation: Animation) {
// 	map_insert(list, name, animation)
// }

