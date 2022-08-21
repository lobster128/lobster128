VERILATOR := verilator
VERILATOR_FLAGS := -O3 --cc --exe --build
VERILATOR_FLAGS += --top-module lobster_CPU

GCC_CONFIG_OPT := --disable-nls \
	--enable-languages=c \
	--target=lobster128-elf \
	--disable-gcov \
	--disable-multiarch \
	--disable-threads \
	--disable-tls \
	--disable-bootstrap \
	--disable-gnu-unique-object \
	--disable-lto \
	--without-headers \
	--prefix="$(HOME)/opt/cross"

all: build build-toolchain

run: build
	cd obj_dir && ./Vlobster_CPU

build:
	$(VERILATOR) $(VERILATOR_FLAGS) \
		main.cpp rtl/lobster.sv \
		-CFLAGS "$(sdl2-config --cflags)" \
		-LDFLAGS "$(sdl2-config --libs)" || exit

.PHONY: all run build

# Toolchain
build-toolchain: build-gcc-lobster128

.PHONY: build-toolchain

vasm:
	-git clone https://github.com/mbitsnbites/vasm-mirror $@

gcc: vasm
	-git clone git://gcc.gnu.org/git/gcc.git $@

build-gcc-lobster128/Makefile: build-gcc-lobster128
	mkdir -p $@ $(HOME)/opt/cross
	cd build-gcc-lobster128 && ../$</configure $(GCC_CONFIG_OPT)

build-gcc-lobster128: gcc build-gcc-lobster128/Makefile
	$(MAKE) -C $@ all-gcc
	$(MAKE) -C $@ install-gcc

.PHONY: build-gcc-lobster128
