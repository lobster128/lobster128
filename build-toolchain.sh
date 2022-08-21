#!/bin/sh

# clone assembler
[ -d vasm ] || git clone https://github.com/mbitsnbites/vasm-mirror vasm || exit

# clone compiler
[ -d gcc ] || git clone git://gcc.gnu.org/git/gcc.git gcc || exit
mkdir -p build-gcc-lobster128 && cd build-gcc-lobster128 || exit
mkdir -p $HOME/opt/cross
[ -f Makefile ] || ../gcc/configure \
    --disable-nls --enable-languages=c \
    --target=lobster128-elf --disable-gcov --disable-multiarch \
    --disable-threads --disable-tls --disable-bootstrap \
    --disable-gnu-unique-object --disable-lto \
    --without-headers --prefix="$HOME/opt/cross" || exit
make all-gcc -j$(nproc) || exit
make install-gcc || exit
cd .. || exit

# once everything is sucesful we can output a patch
cd gcc || exit
git add . || exit
git diff --cached >../gcc-patch.diff || exit
cd .. || exit
