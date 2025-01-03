package nod

import "core:encoding/json" // serialize scnees to json and re construct from json
import "core:fmt"


// what's needed in a scene?
// need to be able to reconstruct a scene from the serialized information
Scene :: struct {
	entities: [dynamic]EntityID,
	systems:  [dynamic]SystemID,
}

