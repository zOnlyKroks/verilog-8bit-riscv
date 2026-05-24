![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# 8-bit RISC-V Processor

**An ambitious 8-bit RISC-V processor implementation for TinyTapeout**

- [Read the detailed documentation](docs/info.md)
- Author: Finn Rades (zOnlyKroks)

## What is this?

This project implements a complete 8-bit RISC-V processor designed to fit within a single TinyTapeout tile (1x1, ~167x108 μm). Despite the area constraints, it implements a substantial subset of the RV32I base instruction set adapted for 8-bit operation.

## Architecture Highlights

- **8-bit datapath** with 16 general-purpose registers (x0-x15)
- **Harvard architecture** with separate instruction ROM (256 bytes) and data RAM (64 bytes)  
- **Multi-cycle execution** (6-7 cycles per instruction) to minimize combinatorial complexity
- **Programming interface** via input pins for loading custom programs
- **Debug interface** with PC and register visibility
- **Built-in test program** implementing Fibonacci sequence

## Key Features

### Instruction Set
Supports essential RISC-V instructions adapted for 8-bit:
- **Arithmetic**: ADD, SUB, AND, OR, XOR, SLT
- **Immediate**: ADDI, ANDI, ORI, XORI, SLTI  
- **Memory**: LB, SB (8-bit load/store)
- **Branches**: BEQ, BNE, BLT, BGE
- **Jumps**: JAL, JALR

### I/O Interface
- **Programming Mode**: Load instructions via 4-bit nibbles
- **Debug Outputs**: PC and register values visible on output pins
- **Step Mode**: Single-step execution for debugging
- **Halt Detection**: Automatic halt on invalid instructions

## File Structure

```
src/
├── project.v          # TinyTapeout wrapper module
├── riscv_cpu.v        # Main CPU with state machine and datapath
├── alu.v              # 8-bit ALU supporting all operations
├── register_file.v    # 16 x 8-bit register file
├── control_unit.v     # Instruction decoder and control signal generator
└── instruction_memory.v # 256-byte ROM with programming interface

test/
├── tb.v               # Verilog testbench
├── test.py            # Comprehensive Python tests using cocotb
└── Makefile           # Test configuration
```

## How to Test

### Run the simulation
```bash
cd test
make
```

### Programming Mode
1. Set `PROG_MODE` high
2. Use `PROG_CLK` to clock in 4-bit nibbles via `PROG_DATA`
3. Each instruction requires 8 nibbles (32 bits total)

### Normal Operation  
1. Set `PROG_MODE` low to start execution
2. Enable `DEBUG_EN` to see internal state on output pins
3. Use `STEP_MODE` for single-step debugging

## Design Optimizations

This processor is optimized for area efficiency:
- **Reduced register count**: 16 instead of 32 registers saves ~128 flip-flops
- **Multi-cycle design**: Reduces combinatorial logic complexity
- **Shared ALU**: Single ALU handles all arithmetic, logic, and comparison operations
- **Compact instruction memory**: 256 bytes fits typical embedded programs
- **Minimal control logic**: Simple FSM-based control unit

## Educational Value

Perfect for learning:
- RISC-V instruction set architecture  
- Multi-cycle processor design
- ASIC design constraints and optimization
- Hardware/software co-design
- Real chip fabrication process

## Technical Specifications

- **Technology**: IHP 130nm (via TinyTapeout)
- **Die Area**: 1x1 tile (167x108 μm)
- **Clock**: Up to 10 MHz target
- **Power**: TBD (will be measured post-fabrication)
- **Gate Count**: ~2000-3000 gates (estimated)

## What's Next?

This design will be fabricated through TinyTapeout's IHP shuttle, creating a real silicon implementation of a RISC-V processor that you can hold in your hand!

## Resources

- [RISC-V Specification](https://riscv.org/technical/specifications/)
- [TinyTapeout](https://tinytapeout.com)
- [Digital Design Tutorials](https://tinytapeout.com/digital_design/)

---

*Built with passion for processor architecture and the magic of silicon! 🚀*
