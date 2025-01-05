package nod

// Resources are globally UNIQUE data
ResourceTypeInfo :: struct {
	type_id:   typeid, // odin type checking (easy safety check, <3 odin)
	size:      int,
	alignment: int,
}

ResourceStorage :: struct {
	data:        rawptr,
	type_info:   ResourceTypeInfo,
	initialized: bool,
}

Resources :: struct {
	storage: map[typeid]ResourceStorage,
}

create_resources :: proc() -> ^Resources {
	resources := new(Resources)
	resources.storage = make(map[typeid]ResourceStorage)

	return resources
}

insert_resource :: proc(resources: ^Resources, $T: typeid, data: T) -> ResourceError {
	type_info := ResourceTypeInfo {
		type_id = T,
		size    = size_of(T),
	}

	if T in resources.storage {
		return .AlreadyExists
	}

	storage := ResourceStorage {
		data        = new(T),
		type_info   = type_info,
		initialized = true,
	}

	(cast(^T)storage.data)^ = data
	resources.storage[T] = storage

	return .None
}

get_resource :: proc(resources: ^Resources, $T: typeid) -> (^T, ResourceError) {
	if storage, ok := resources.storage[T]; ok {
		if !storage.initialized {
			return nil, .NotFound
		}
		return cast(^T)storage.data, .None
	}

	return nil, .NotFound
}

remove_resource :: proc(resources: ^Resources, $T: typeid) -> ResourceError {
	if storage, ok := resources.storage[T]; ok {
		if !storage.initialized {
			return .NotFound
		}
		free(storage.data)
		storage.initialized = false
		delete_key(resources.storage, T)
		return .None
	}
	return .NotFound
}

destroy_resources :: proc(resources: ^Resources) {
	for type_id, storage in resources.storage {
		if storage.initialized {
			if type_id == typeid_of(PhysicsWorld) {
				physics_world := cast(^PhysicsWorld)storage.data
				physics_cleanup(physics_world)
			}
			free(storage.data)
		}
	}
	delete(resources.storage)
	free(resources)
}

