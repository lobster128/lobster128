# lobster128

![Title](https://raw.githubusercontent.com/lobster128/lobster128/master/lobster1.png)

128-bit FPGA CPU in SystemVerilog.

* [x] 128 128-bit registers.
* [ ] Floating point.
* [ ] Vector instructions.
* [ ] Paging.
* [ ] D-cache and I-cache.
* [ ] GCC backend.
* [ ] vasm backend.
* [ ] Fully pipelined with minimal stalls.
* [ ] Hardware task switch.
* [ ] VLIW instructions (aka. not RISC).

# Building
Pre-requirements:
* Verilator - for simulating & converting the SystemVerilog into the emulator
* Yosys (optional) - to synthetize into a real FPGA
* Make - as a build system
* GCC (optional) - for building the cross compiler toolchain
* Patience - quite a bit of it :D

First run `make gcc`, once gcc has been git cloned along with vasm, apply the `gcc-patch.diff` onto the gcc repository.
Then build gcc using `make build-toolchain` and wait, once that's done the toolchain would be hopefully built and installed on "$HOME/opt/cross".
After this run `source env.sh` to set environment variables to be able to use the toolchain.

Once the toolchain is built, run `make build` to compile the SystemVerilog into the CPU emulator.
