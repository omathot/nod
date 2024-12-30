all : default

default :
	@mkdir -p bin
	odin run src -collection:lib=lib -out:bin/nod

build :
	@mkdir -p bin
	odin build src -collection:lib=lib -out:bin/nod

physics :
	@mkdir -p bin
	odin run src/ -collection:lib=lib -out:bin/physics -- physics

# ASAN_OPTIONS=detect_leaks=1
ecs :
	@mkdir -p bin
	odin run src/ -collection:lib=lib -out:bin/ecs -debug -sanitize:address -- ecs
