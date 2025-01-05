package nod

import "core:fmt"
import "core:mem"
import "core:os"

import imgui "lib:odin-imgui"
import sdl "vendor:sdl2"
import sdl_img "vendor:sdl2/image"

main :: proc() {
	args := os.args
	if len(args) > 1 {
		if args[1] == "ecs" {
			ecs_test()
			return
		}
	}
}

