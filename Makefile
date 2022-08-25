VERILATOR := verilator
VERILATOR_FLAGS := -O3 --cc --exe --build

PREFIX := $(HOME)/opt/cross

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
	--disable-plugin \
	--prefix="$(PREFIX)"

BINUTILS_CONFIG_OPT := --disable-nls \
	--target=lobster128-elf \
	--disable-werror \
	--with-sysroot \
	--prefix="$(PREFIX)"

################################################################################
#
# Simulator
#
################################################################################
all: build build-toolchain

run: build
	cd obj_dir && ./Vlobster_CPU

build: obj_dir/Vlobster_CPU

obj_dir/Vlobster_CPU: rtl/lobster.sv main.cpp rtl/cache.sv
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module lobster_CPU \
		main.cpp $< \
		-CFLAGS "$(sdl2-config --cflags)" \
		-LDFLAGS "$(sdl2-config --libs)" || exit

clean:
	$(RM) -r obj_dir

.PHONY: all run build clean

################################################################################
#
# Toolchain
#
################################################################################
build-toolchain: build-gcc

.PHONY: build-toolchain

# GCC toolchain
gcc:
	-git clone git://gcc.gnu.org/git/gcc.git $@
	cd $@ && git apply ../gcc-patch.diff

build-gcc-lobster128/Makefile: build-gcc-lobster128
	mkdir -p build-gcc-lobster128 $(PREFIX)
	cd build-gcc-lobster128 && ../gcc/configure $(GCC_CONFIG_OPT)

build-gcc-lobster128: build-gcc-lobster128/Makefile gcc
	$(MAKE) -C $@ all-gcc
	$(MAKE) -C $@ install-gcc

build-gcc: build-gcc-lobster128
.PHONY: build-gcc build-gcc-lobster128

# binutils
binutils:
# Sourceware is awfuly slow, use github mirror
#	-git clone git://sourceware.org/git/binutils-gdb.git $@
	-git clone https://github.com/bminor/binutils-gdb $@

build-binutils-lobster128/Makefile: build-binutils-lobster128
	mkdir -p build-binutils-lobster128 $(PREFIX)
	cd build-binutils-lobster128 && ../binutils/configure $(BINUTILS_CONFIG_OPT)

build-binutils-lobster128: build-binutils-lobster128/Makefile binutils
	$(MAKE) -C $@
	$(MAKE) -C $@ install

build-binutils: build-binutils-lobster128
.PHONY: build-binutils
