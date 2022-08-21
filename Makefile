VERILATOR := verilator
VERILATOR_FLAGS := -O3 --cc --exe --build
VERILATOR_FLAGS += --top-module lobster_CPU

all: build

run: build
	cd obj_dir && ./Vlobster_CPU

build:
	$(VERILATOR) $(VERILATOR_FLAGS) \
		main.cpp rtl/lobster.sv \
		-CFLAGS "$(sdl2-config --cflags)" \
		-LDFLAGS "$(sdl2-config --libs)" || exit

.PHONY: all run build
