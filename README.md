# lobster128

![Title](https://raw.githubusercontent.com/lobster128/lobster128/master/lobster1.png)

128-bit FPGA CPU in SystemVerilog.

* [x] 128 128-bit registers.
* [ ] Floating point.
* [ ] Vector instructions.
* [ ] Paging.
* [ ] D-cache and I-cache.
* [x] GCC backend.
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

For your sanity use `ccache` for recompilations.

First run `make gcc`, once gcc has been git cloned along with vasm, apply the `gcc-patch.diff` onto the gcc repository.
Then build gcc using `make build-toolchain` and wait, once that's done the toolchain would be hopefully built and installed on "$HOME/opt/cross".
After this run `source env.sh` to set environment variables to be able to use the toolchain.

Once the toolchain is built, run `make build` to compile the SystemVerilog into the CPU emulator.

# Examples
Bubble sort:
```x86asm
swap:
	z.ashl.dwo r6,r4,48
	z.ashr.dwo r6,r6,48
	z.mov.dwo r18,r6
	z.ashr.dwo r19,r6,63
	z.mov.dwo r16,(r18)
	z.ashl.dwo r6,r5,48
	z.ashr.dwo r6,r6,48
	z.mov.dwo r18,r6
	z.ashr.dwo r19,r6,63
	z.mov.dwo r18,(r18)
	z.ashl.dwo r4,r4,48
	z.ashr.dwo r4,r4,48
	z.mov.dwo r6,r4
	z.ashr.dwo r7,r4,63
	z.mov.dwo (r6),r18
	z.ashl.dwo r5,r5,48
	z.ashr.dwo r5,r5,48
	z.mov.dwo r6,r5
	z.mov.dwo r7,r19
	z.mov.dwo (r6),r16
	z.ret.owo
bb_sort:
	z.add.dwo r27,r5,-1
	z.mov.dwo r32,1
	z.cmp.dwo r5,r32
	z.ble L3
	z.add.hlf r35,r4,8
	z.mov.dwo r34,0
.L5:
	z.add.dwo r5,r27,1
	z.cmp.dwo r5,r32
	z.ble L15
	z.mov.hlf r18,r4
	z.mov.hlf r16,r35
	z.mov.dwo r7,0
.L7:
	z.ashl.dwo r6,r18,48
	z.ashr.dwo r26,r6,48
	z.mov.dwo r20,r26
	z.ashr.dwo r6,r6,63
	z.mov.dwo r21,r6
	z.mov.dwo r19,(r20)
	z.ashl.dwo r5,r16,48
	z.ashr.dwo r24,r5,48
	z.mov.dwo r22,r24
	z.ashr.dwo r5,r5,63
	z.mov.dwo r23,r5
	z.mov.dwo r25,(r22)
	z.cmp.dwo r19,r25
	z.ble L6
	z.mov.dwo r28,r26
	z.mov.dwo r29,r6
	z.mov.dwo (r28),r25
	z.mov.dwo r30,r24
	z.mov.dwo r31,r5
	z.mov.dwo (r30),r19
.L6:
	z.add.dwo r7,r7,1
	z.add.hlf r18,r18,8
	z.add.hlf r16,r16,8
	z.cmp.dwo r7,r27
	z.bne L7
	z.add.dwo r27,r27,-1
	z.cmp.dwo r27,r34
	z.bne L5
.L3:
	z.ret.owo
.L15:
	z.add.dwo r27,r27,-1
	z.j L5
```
