.PHONY: all

all: main_v1 main_v2 main_v3 main_v4 generate_list

main_v%: main_v%.zig
	zig build-exe $@.zig

generate_list: generate_list.zig
	zig build-exe $@.zig

.PHONY: fast fast_v1 fast_v2 fast_v3

fast: fast_v1 fast_v2 fast_v3

fast_v1:
	zig build-exe -O ReleaseFast main_v1.zig

fast_v2:
	zig build-exe -O ReleaseFast main_v2.zig

fast_v3:
	zig build-exe -O ReleaseFast main_v3.zig

fast_v4:
	zig build-exe -O ReleaseFast main_v4.zig
