package nod

import "core:fmt"
import "core:mem"

@(private)
Tag_Components :: struct {
	components: [dynamic]ComponentID,
	defaults:   map[ComponentID]rawptr,
}

@(private)
tag_registry: map[typeid]Tag_Components

init_tag_system :: proc() {
	tag_registry = make(map[typeid]Tag_Components)
}

register_tag :: proc(world: ^World, $Tag: typeid, components: []ComponentID) {
	tag := Tag_Components {
		components = make([dynamic]ComponentID),
		defaults   = make(map[ComponentID]rawptr),
	}

	append(&tag.components, ..components)
	tag_registry[typeid_of(Tag)] = tag
}

set_default :: proc(world: ^World, $Tag: typeid, component_id: ComponentID, default: rawptr) {
	if tag, ok := tag_registry[Tag]; ok {
		tag.defaults[component_id] = default
	}
}

spawn_tagged :: proc(world: ^World, $Tag: typeid) -> EntityID {
	entity := create_entity(world)

	if tag, ok := &tag_registry[typeid_of(Tag)]; ok {
		for component_id in tag.components {
			if default_value, has_default := tag.defaults[component_id]; has_default {
				type_info := world.component_types[component_id]
				data := make([]byte, type_info.size)
				defer delete(data)
				mem.copy(&data[0], default_value, type_info.size)
				add_component(world, entity, component_id, &data[0])
			} else {
				// zero init
				type_info := world.component_types[component_id]
				data := make([]byte, type_info.size)
				defer delete(data)

				add_component(world, entity, component_id, &data[0])
			}
		}
	} else {
		fmt.println("WARNING: Tag not found:", typeid_of(Tag))
	}

	return entity
}

has_tag :: proc(world: ^World, entity: EntityID, $Tag: typeid) -> bool {
	if tag, ok := tag_registry[typeid_of(Tag)]; ok {
		for component_id in tag.components {
			if _, has_component := get_component(world, entity, component_id); !has_component {
				return false
			}
		}
		return true
	}
	return false
}

cleanup_tags :: proc() {
	for _, tag in tag_registry {
		delete(tag.components)
	}
	delete(tag_registry)
}

