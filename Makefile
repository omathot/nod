all : default

default :
	@mkdir -p bin
	odin run src -collection:lib=lib -out:bin/nod

build :
	@mkdir -p bin
	odin build src -collection:lib=lib -out:bin/nod

test :
	@mkdir -p bin
	odin build test/ -collection:nod=src -out:bin/test
