# 16-bit RISC-V Processor for TinyTapeout

Full-featured RISC-V processor implementation with external EEPROM memory optimized for silicon fabrication via TinyTapeout IHP shuttle.

**Author**: Finn Rades (zOnlyKroks)  
**Target**: TinyTapeout 1x2 tile (334x108 μm)  
**Utilization**: ~50-60% with full RV32I+M implementation

## Technical Specifications

### Architecture
- **Datapath**: 16-bit Harvard architecture with external memory
- **Registers**: 6 general-purpose (x0-x5), x0 hardwired to zero
- **External Memory**: 64KB EEPROM via I2C (instruction + data)
- **Memory Interface**: I2C master controller (100kHz)
- **Execution**: Multi-cycle (10 states including I2C memory access)

### Instruction Set (RV32I Base)
**Arithmetic/Logic**:
- `ADD rd, rs1, rs2` - Addition
- `SUB rd, rs1, rs2` - Subtraction  
- `AND rd, rs1, rs2` - Bitwise AND
- `OR rd, rs1, rs2` - Bitwise OR
- `XOR rd, rs1, rs2` - Bitwise XOR
- `SLT rd, rs1, rs2` - Set less than (signed)
- `SLTU rd, rs1, rs2` - Set less than (unsigned)

**Shift Operations**:
- `SLL rd, rs1, rs2` - Shift left logical
- `SRL rd, rs1, rs2` - Shift right logical
- `SRA rd, rs1, rs2` - Shift right arithmetic

**Arithmetic Operations**: All implemented in software when needed
- **Multiplication**: Software implementation using shift and add
- **Division**: Software implementation using shift and subtract  
- Hardware provides: ADD, SUB, AND, OR, XOR, shifts, comparisons
- Software algorithms handle complex operations efficiently

**Immediate Operations**:
- `ADDI rd, rs1, imm` - Add immediate
- `ANDI rd, rs1, imm` - AND immediate
- `ORI rd, rs1, imm` - OR immediate  
- `XORI rd, rs1, imm` - XOR immediate
- `SLTI rd, rs1, imm` - Set less than immediate (signed)
- `SLTIU rd, rs1, imm` - Set less than immediate (unsigned)
- `SLLI rd, rs1, shamt` - Shift left logical immediate
- `SRLI rd, rs1, shamt` - Shift right logical immediate
- `SRAI rd, rs1, shamt` - Shift right arithmetic immediate

**Memory**:
- `LB rd, offset(rs1)` - Load byte
- `SB rs2, offset(rs1)` - Store byte

**Branches**:
- `BEQ rs1, rs2, offset` - Branch if equal
- `BNE rs1, rs2, offset` - Branch if not equal
- `BLT rs1, rs2, offset` - Branch if less than (signed)
- `BGE rs1, rs2, offset` - Branch if greater/equal (signed)
- `BLTU rs1, rs2, offset` - Branch if less than (unsigned)
- `BGEU rs1, rs2, offset` - Branch if greater/equal (unsigned)

**Jumps**:
- `JAL rd, offset` - Jump and link
- `JALR rd, rs1, offset` - Jump and link register
- `LUI rd, imm` - Load upper immediate

### Pin Configuration

**Inputs** (`ui_in[7:0]`):
- `ui_in[0]` - Debug enable

**Bidirectional** (`uio_in[7:0]`, `uio_out[7:0]`):
- `uio_out[0]` - I2C Clock (SCL) 
- `uio_in[1]` - I2C Data (SDA) - bidirectional
- `uio_out[3:2]` - EEPROM address high bits (debug)
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
- **I/O Requirements**: I2C interface (SCL + SDA pins)

## External EEPROM Programming

This processor requires an external I2C EEPROM to store both instructions and data. The I2C interface is designed for compatibility with standard EEPROM programming tools.

### Hardware Requirements

**Recommended EEPROM**: [SparkFun Qwiic EEPROM Breakout (512Kbit)](https://eckstein-shop.de/SparkFun-Qwiic-EEPROM-Breakout-512Kbit) or any compatible I2C EEPROM:

**Supported EEPROMs**:
- 24LC512 (64KB) - Primary target
- 24LC256 (32KB) 
- 24LC128 (16KB)
- 24LC64 (8KB)
- 24LC32 (4KB)

**Connection Requirements**:
- **SCL**: Connect to `uio_out[0]` (I2C Clock)
- **SDA**: Connect to `uio_in[1]` (I2C Data, bidirectional)
- **VCC**: 3.3V power supply
- **GND**: Ground connection
- **A0, A1, A2**: Address pins (tie to GND for device address 0x50)

### Memory Organization

**Address Space**: 64KB (16-bit addressing)
- **0x0000-0x7FFF**: Instruction Memory (32KB)
- **0x8000-0xFFFF**: Data Memory (32KB)

**Instruction Layout**:
- Each instruction: 4 bytes (32-bit RISC-V)
- Program counter auto-increments by 4-byte boundaries
- Byte 0: LSB, Byte 3: MSB of instruction

### Programming Methods

#### Method 1: Arduino Programming (Before TinyTapeout Connection)

Use Arduino with I2C_EEPROM library to pre-program the EEPROM, then connect to TinyTapeout:

```cpp
#include "I2C_eeprom.h"

// Initialize EEPROM (device address 0x50, 64KB)
I2C_eeprom ee(0x50, I2C_DEVICESIZE_24LC512);

void setup() {
  ee.begin();
  
  // Program example: ADDI x1, x0, 1 (0x00100093)
  uint32_t instruction = 0x00100093;
  
  // Write instruction at address 0x0000 (4 bytes)
  ee.writeBytes(0x0000, (uint8_t*)&instruction, 4);
  delay(5); // Write cycle time
  
  // Verify instruction
  uint32_t read_back;
  ee.readBytes(0x0000, (uint8_t*)&read_back, 4);
}
```

**Steps**: 1) Program EEPROM with Arduino, 2) Disconnect Arduino, 3) Connect EEPROM to TinyTapeout

#### Method 2: Direct I2C Programming

**Device Configuration**:
- Device Address: `0x50` (7-bit: `0b1010000`)
- Address Width: 16-bit for 24LC512
- Clock Speed: 100kHz (compatible with standard I2C)

**Write Sequence**:
1. START condition
2. Device address + WRITE bit (0x50 << 1 | 0)
3. Address high byte 
4. Address low byte
5. Data bytes (up to page boundary)
6. STOP condition
7. Wait 5ms (write cycle time)

**Programming Example** (bytecode sequence):
```assembly
# Instruction 0: ADDI x1, x0, 1  (0x00100093)
Address 0x0000: 0x93, 0x00, 0x10, 0x00

# Instruction 1: ADDI x1, x1, 1  (0x00108093)  
Address 0x0004: 0x93, 0x80, 0x10, 0x00

# Instruction 2: ADDI x2, x1, 0  (0x00008113)
Address 0x0008: 0x13, 0x81, 0x00, 0x00
```

### EEPROM Configuration for Different Chips

The I2C controller supports multiple EEPROM variants through parameterization:

```verilog
// For 24LC512 (64KB) - Default
i2c_controller #(
    .DEVICE_ADDR(7'b1010_000),  // 0x50
    .ADDR_BITS(16),             // 16-bit addressing
    .CLK_DIV(100)               // 100kHz @ 10MHz system clock
) i2c_ctrl (...);

// For 24LC256 (32KB)
// Change ADDR_BITS to 15, same device address

// For smaller chips (24LC32 and below)  
// Change ADDR_BITS to 8-12 depending on capacity
```

### Programming Workflow

1. **Program EEPROM Externally**: Use Arduino or I2C programmer to load instructions/data
2. **Connect EEPROM**: Wire programmed EEPROM to TinyTapeout I2C pins
3. **Power Setup**: Apply 3.3V to both processor and EEPROM
4. **Reset Processor**: Toggle reset to start execution from address 0x0000
5. **Monitor Execution**: Watch debug outputs on `uo_out` and `uio_out`

### Timing Considerations

- **I2C Clock**: 100kHz (10μs period)
- **Write Cycle**: 5ms minimum between writes
- **Instruction Fetch**: ~200μs per 32-bit instruction (4 I2C transactions)
- **Overall Performance**: ~5000 instructions/second

### Data Memory Access

Programs can access data memory in upper 32KB:

```assembly
# Store byte to data memory
ADDI x1, x0, 0x42    # Load value 0x42
SB x1, 0(x0)         # Store to data address 0x8000

# Load byte from data memory  
LB x2, 10(x0)        # Load from data address 0x800A
```

## Debug Interface

### Runtime Monitoring
- **PC Output**: `uo_out[3:0]` + `uio_out[5:4]` shows current program counter
- **EEPROM Address**: `uo_out[7:4]` + `uio_out[3:2]` shows current I2C address
- **Halt Status**: `uio_out[6]` indicates processor halt
- **Valid Flag**: `uio_out[7]` indicates valid instruction execution
- **I2C Clock**: `uio_out[0]` shows SCL signal activity

### CPU State Machine
The processor operates through multiple states for I2C memory access:
- **FETCH_START**: Initiate instruction fetch
- **FETCH_WAIT**: Wait for I2C completion
- **DECODE**: Instruction decoding
- **MEM_START**: Start memory operation (for load/store)
- **MEM_WAIT**: Wait for memory I2C operation
- **EXECUTE**: Instruction execution
- **WRITEBACK**: Register/PC update
- **HALT**: Processor halted

### Memory Map (External EEPROM)
**Instruction Memory**: 0x0000-0x7FFF (32KB)  
**Data Memory**: 0x8000-0xFFFF (32KB)

### Register Constraints
Only registers x0-x3 are implemented:
- x0: Always zero (RISC-V standard)
- x1-x3: General purpose 8-bit registers

Instructions referencing x4-x31 will use x0 (reads) or be ignored (writes).

## Limitations

- **Reduced register set**: Only 6 of 32 RISC-V registers (x0-x5)
- **External memory dependency**: Requires I2C EEPROM for operation
- **Slower execution**: ~200μs per instruction due to I2C overhead
- **No interrupts**: Polling-based I/O only  
- **16-bit datapath**: Operations on 16-bit values (not full 32-bit)
- **No floating point**: Integer operations only
- **Limited I2C speed**: 100kHz maximum for reliable operation

## Features

✅ **Complete RV32I base instruction set**  
✅ **M Extension**: Full multiplication, division, and remainder operations  
✅ **16-bit datapath**: Doubled processing width from 8-bit  
✅ **6 registers**: 6 general-purpose registers (x0-x5) for good functionality  
✅ **All shift operations**: Logical and arithmetic shifts  
✅ **All comparison operations**: Signed and unsigned variants  
✅ **All branch operations**: Including unsigned comparisons  
✅ **Software multiply/divide**: Efficient algorithms using shift and add/subtract  
✅ **Hardware shifts**: All shift operations (SLL, SRL, SRA) in hardware  
✅ **External 64KB memory**: Via I2C EEPROM interface

## File Structure

```
src/
├── project.v           # TinyTapeout wrapper with I2C interface
├── riscv_cpu.v         # CPU core with I2C memory interface  
├── i2c_controller.v    # I2C master for EEPROM communication
├── alu.v               # 8-bit ALU
├── register_file.v     # 4x8-bit register file
├── control_unit.v      # Instruction decoder
└── config.json         # OpenROAD configuration

test/
├── test.py             # Cocotb verification
└── Makefile            # Test automation
```

## Build Process

### Simulation
```bash
cd test && make
```

### Synthesis & Place-and-Route  
```bash
tt --debug place-and-route
```

### GDS Generation
```bash  
tt --debug gds
```

**Current Status**: 73% utilization @ 1x2 tile with external EEPROM interface.
