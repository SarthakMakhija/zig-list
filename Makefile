build:
	zig build

test:
	zig test src/arraylist.zig

all: build test