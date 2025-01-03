package nod

ResourceID :: distinct u64

ResourceState :: enum {
	Unloaded,
	Loading,
	Loaded,
	Failed,
}

ResourceError :: enum {
	None,
	NotFound,
	WrongType,
	AlreadyExists,
}

// default Nod resources
WindowInfo :: struct {
	width:  int,
	height: int,
	title:  string,
}

TimeResource :: struct {
	delta_time:  f32,
	total_time:  f32,
	fixed_delta: f32,
}

