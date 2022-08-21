# Lobster128
A 128-bit RISC CPU.

* 64-bit instructions
* 128, 128-bit registers
* Vector instructions

# Instructions
The base formating for an instruction looks like this:
```
0                                                                    63
ppddddxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
```
* p - Prefix
    * 00 - Non-atomic (NOLOCK)
    * 01 - Atomic (LOCK)
    * 10 - Single instruction (NOREP)
    * 11 - Repeat with atomicity (REP)

* d - Delegator
    * 0000 - Arithmethic
    * 0001 - Floating point
    * 0010 - Vector
    * 0011 - Vector floating point
    * 1011 - Control
    * 1100 - Memory (Implicitly atomic)
    * 1000 - Atomic operation

The rest of the x bits correspond to delegator-specific bits. Down below
the delegator-specific instructions are described, prefix is present in all
of them and marked with a p.

## Arithmethic
```
0                                                                    63
ppppppoo oxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
```
* o - Arithmethic operator
    * 0000 - Add
    * 0001 - Subtract
    * 0010 - AND
    * 0011 - NOT
    * 0100 - Left-shift

```x86asm
rep load [r1], r1, 64 ;Load data from the memory address pointed by r1
                      ;into r1 then repeat for 64 iterations and place
                      ;subsequent QWORDs into r1 to r64, so:
                      ;r1 = [r1 + 0] (assume: 0xF000)
                      ;r2 = [r1 + 8] = [0xF008]
                      ;r3 = [r1 + 16] = [0xF010]
                      ;... and so on
```
