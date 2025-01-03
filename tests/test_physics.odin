package tests

import nod "../src"
import test "core:testing"

/*
	can't really test physics as a user importing my package because they're part of the engine.
	Need to make functions not private and phsyics_init_world() assumes there's a physics world to pass.
	Would need to init a Nod instance to test physics.
*/

// @(test)
// phsyics_world :: proc(t: ^test.T) {
// world := nod.create_world()
// nod.physics_init_world(world)
// }

