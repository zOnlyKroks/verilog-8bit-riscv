# 16-bit RISC-V Processor for TinyTapeout

RISC-V processor implementation with external EEPROM memory optimized for silicon fabrication via TinyTapeout IHP shuttle.

**Author**: Finn Rades (zOnlyKroks)  
**Target**: TinyTapeout 1x2 tile (334x108 μm)  
**Utilization**: ~54% area utilization

## Technical Specifications

### Architecture
- **Datapath**: 16-bit with external memory
- **Registers**: 12 general-purpose (x0-x11), x0 hardwired to zero
- **External Memory**: 64KB EEPROM via I2C (instruction + data)
- **Memory Interface**: I2C master controller (100kHz)
- **Execution**: Multi-cycle state machine (FETCH/EXECUTE/WRITEBACK)
- **Instructions**: 16-bit instruction encoding with 4-bit opcodes

### Instruction Set

**Arithmetic**:
- `ADD rd, rs1, rs2` - 16-bit addition
- `SUB rd, rs1, rs2` - 16-bit subtraction  
- `MUL rd, rs1, rs2` - 8x8 to 16-bit multiplication

**Logic**:
- `AND rd, rs1, rs2` - Bitwise AND
- `OR rd, rs1, rs2` - Bitwise OR
- `XOR rd, rs1, rs2` - Bitwise XOR
- `NOT rd, rs1` - Bitwise NOT (invert)

**Shift**:
- `SLL rd, rs1, rs2` - Shift left logical
- `SRL rd, rs1, rs2` - Shift right logical
- `SRA rd, rs1, rs2` - Shift right arithmetic

**Compare**:
- `SLT rd, rs1, rs2` - Set less than (signed)
- `SLTU rd, rs1, rs2` - Set less than (unsigned)

**Memory**:
- `LOAD rd, rs1` - Load 8-bit from EEPROM data section
- `STORE rs2, rs1` - Store 8-bit to EEPROM data section

**Control Flow**:
- `BRANCH rs1, rs2` - Branch if equal (simplified)
- `JAL rd` - Jump and link

### Instruction Encoding

16-bit instruction format:
```
[15:12] - Opcode (4 bits)
[11:8]  - rd (destination register, 4 bits)
[7:4]   - rs1 (source register 1, 4 bits) 
[3:0]   - rs2 (source register 2, 4 bits)
```

4-bit opcode assignments:
- 0x0: ADD
- 0x1: SUB  
- 0x2: MUL
- 0x3: AND
- 0x4: OR
- 0x5: XOR
- 0x6: NOT
- 0x7: SLL
- 0x8: SRL
- 0x9: SRA
- 0xA: SLT
- 0xB: SLTU
- 0xC: LOAD
- 0xD: STORE
- 0xE: BRANCH
- 0xF: JAL

### Pin Configuration

**Inputs** (`ui_in[7:0]`):
- `ui_in[7:1]` - Unused
- `ui_in[0]` - Unused (debug removed for area optimization)

**Bidirectional** (`uio_in[7:0]`, `uio_out[7:0]`):
- `uio_out[0]` - I2C Clock (SCL) 
- `uio_in[1]/uio_out[1]` - I2C Data (SDA) bidirectional
- `uio_out[3:2]` - Address high bits (debug)
- `uio_out[5:4]` - Program counter high bits (debug)
- `uio_out[6]` - Halt flag
- `uio_out[7]` - Valid instruction flag

**Outputs** (`uo_out[7:0]`):
- `uo_out[3:0]` - Program counter lower 4 bits
- `uo_out[7:4]` - EEPROM address lower 4 bits

### Fabrication Specifications
- **Process**: IHP 130nm
- **Die Area**: 1x2 TinyTapeout tile (334x108 μm)
- **Clock Target**: 10 MHz maximum
- **Power**: <1mW estimated
- **Area Utilization**: ~54%

## External EEPROM Interface

Requires external I2C EEPROM for instruction and data storage.

### Hardware Requirements

**Compatible EEPROMs**:
- 24LC512 (64KB) - Primary target
- 24LC256 (32KB) 
- 24LC128 (16KB)

**Connections**:
- **SCL**: Connect to `uio_out[0]`
- **SDA**: Connect to `uio_in[1]` (bidirectional)
- **VCC**: 3.3V
- **GND**: Ground
- **A0, A1, A2**: Tie to GND (device address 0x50)

### Memory Organization

**Address Space**: 64KB (16-bit addressing)
- **0x0000-0x7FFF**: Instruction Memory (32KB)
- **0x8000-0xFFFF**: Data Memory (32KB)

**Instruction Format**:
- Each instruction: 2 bytes (16-bit)
- Program counter increments by 1
- Little-endian byte order

### I2C Protocol
- **Device Address**: 0x50 (7-bit)
- **Clock Speed**: 100kHz
- **Address Width**: 16-bit
- **Standard I2C read/write sequences**

## State Machine

**FETCH**: Read 16-bit instruction from EEPROM
- 2 I2C byte reads per instruction
- PC address calculation: `(pc << 1) + fetch_counter`

**EXECUTE**: Decode and execute instruction
- ALU operations
- Memory operations (additional I2C transactions)

**WRITEBACK**: Update registers and PC
- Register file write
- PC increment
- Stack pointer management (software)

## Register File

12 x 16-bit registers:
- **x0**: Hardwired zero
- **x1-x11**: General purpose
- 4-bit addressing
- Dual read ports, single write port

## ALU Features

**Operations**: ADD, SUB, MUL, AND, OR, XOR, NOT, SLL, SRL, SRA, SLT, SLTU
**Width**: 16-bit datapath
**Multiplication**: 8x8 to 16-bit (area optimized)
**Barrel Shifter**: Dedicated shift unit

## Control Unit

**Opcode Decoding**: 4-bit opcodes for 16 operations
**Control Signals**: ALU operation, register write, memory enable, PC control
**Simplified Design**: No funct fields or immediate decoding complexity

## Limitations

- **Instruction Set**: Subset of RISC-V, 16-bit instructions only
- **Memory**: External I2C EEPROM required
- **Performance**: ~5000 instructions/second due to I2C overhead
- **No Division**: Removed for area constraints
- **No Interrupts**: Polling only
- **No Immediate Operations**: All operations register-to-register

## File Structure

```
src/
├── project.v           # TinyTapeout wrapper
├── riscv_cpu.v         # CPU core
├── i2c_controller.v    # I2C master
├── alu.v               # 16-bit ALU
├── register_file.v     # 12x16-bit register file
├── control_unit.v      # Instruction decoder
├── barrel_shifter.v    # Shift operations
└── config.json         # Synthesis configuration

test/
├── test.py             # Comprehensive test suite
├── tb.v                # Testbench
└── Makefile            # Build automation
```

## Build and Test

### Simulation
```bash
cd test && make
```

### Synthesis
Uses TinyTapeout flow with OpenROAD backend

**Current Status**: Passes synthesis and place-and-route with 54% area utilization
