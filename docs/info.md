<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a complete 8-bit RISC-V processor that fits within a single TinyTapeout tile (167x108 μm). Despite the 8-bit datapath, it implements a subset of the RV32I base instruction set with some adaptations for the constrained environment.

### Architecture Overview

**8-bit Datapath**: All arithmetic operations work on 8-bit values, but the processor maintains RISC-V compatibility by treating these as the lower 8 bits of 32-bit registers.

**Harvard Architecture**: Separate instruction and data memories to optimize for the small form factor:
- 256-byte instruction ROM (64 x 32-bit instructions, fetched over 4 cycles)
- 64-byte data RAM for variables and stack

**Multi-cycle Execution**: Instructions execute over multiple clock cycles to reduce combinatorial complexity and save area:
- Fetch: 4 cycles (32-bit instruction fetched as 4 x 8-bit chunks)
- Decode: 1 cycle
- Execute: 1-2 cycles depending on instruction
- Writeback: 1 cycle

### Instruction Set

Implements a carefully selected subset of RV32I:

**Arithmetic**: ADD, SUB, AND, OR, XOR, SLT
**Immediate**: ADDI, ANDI, ORI, XORI, SLTI  
**Load/Store**: LB, SB (8-bit load/store only)
**Branches**: BEQ, BNE, BLT, BGE
**Jumps**: JAL, JALR
**System**: NOP (implemented as ADDI x0, x0, 0)

### Register File

- 16 general-purpose 8-bit registers (reduced from 32 to save area)
- Register x0 always reads as zero (RISC-V convention)
- Registers x1-x15 for general use
- Register x14 used as link register for function calls
- Register x15 used as stack pointer

### External Interface

The processor can be programmed via the input pins in program mode, and provides debug visibility through the output pins showing program counter and register values.

## How to test

1. **Programming Mode**: Set PROG_MODE high and use PROG_CLK to clock in 4-bit nibbles via PROG_DATA to load instructions into ROM.

2. **Execution Mode**: Set PROG_MODE low to start program execution. The processor will begin fetching from address 0.

3. **Debug Mode**: Set DEBUG_EN high to enable debug outputs on the pins showing internal processor state.

4. **Single Step**: Set STEP_MODE high to execute one instruction per manual clock cycle for debugging.

### Test Programs

The design includes several test programs:
- Fibonacci sequence calculator
- Simple arithmetic operations
- Memory load/store tests
- Branch and jump instruction tests

## External hardware

- TinyTapeout development board for power, clock, and I/O
- Optional: Logic analyzer to observe debug outputs
- Optional: External ROM programmer (for larger programs)

The processor is designed to be completely self-contained with internal ROM, making it ideal for educational use and demonstration of processor concepts in a real ASIC implementation.