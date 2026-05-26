# 16-bit RISC-V Processor Technical Documentation

## Architecture

### Core Specifications
- **Datapath Width**: 16-bit
- **Architecture**: Harvard (separate instruction/data spaces in external EEPROM)
- **Execution Model**: 3-state FSM (FETCH/EXECUTE/WRITEBACK)
- **Register File**: 12 registers (x0-x11), x0 hardwired to zero
- **External Memory**: 64KB I2C EEPROM (32KB instruction + 32KB data)
- **Instruction Format**: 16-bit custom encoding with 4-bit opcodes
- **I2C Interface**: 100kHz master controller for EEPROM access

### State Machine
Processor executes through 3 states:
1. **FETCH**: Read 16-bit instruction from EEPROM (2 I2C byte reads)
2. **EXECUTE**: Decode and perform ALU/memory operations
3. **WRITEBACK**: Update register file and increment PC

### Register File
- **Size**: 12 x 16-bit registers
- **Addressing**: 4-bit register addresses (supports x0-x11)
- **x0 Behavior**: Hardwired to zero (reads return 0, writes ignored)
- **x1-x11**: General purpose registers
- **Access**: Dual read ports, single write port

### ALU Capabilities
- **16-bit arithmetic**: ADD, SUB, MUL (8x8→16-bit)
- **Logic operations**: AND, OR, XOR, NOT (bitwise)
- **Shift operations**: SLL, SRL, SRA (barrel shifter)
- **Comparisons**: SLT (signed), SLTU (unsigned)
- **Zero flag**: Generated for branch decisions

## Instruction Set Architecture

### 16-bit Instruction Format
```
[15:12] - Opcode (4 bits)
[11:8]  - rd (destination register, 4 bits)
[7:4]   - rs1 (source register 1, 4 bits)
[3:0]   - rs2 (source register 2, 4 bits)
```

### Opcode Assignments (4-bit)
- **0x0**: ADD rd, rs1, rs2
- **0x1**: SUB rd, rs1, rs2  
- **0x2**: MUL rd, rs1, rs2
- **0x3**: AND rd, rs1, rs2
- **0x4**: OR rd, rs1, rs2
- **0x5**: XOR rd, rs1, rs2
- **0x6**: NOT rd, rs1
- **0x7**: SLL rd, rs1, rs2
- **0x8**: SRL rd, rs1, rs2
- **0x9**: SRA rd, rs1, rs2
- **0xA**: SLT rd, rs1, rs2
- **0xB**: SLTU rd, rs1, rs2
- **0xC**: LOAD rd, rs1
- **0xD**: STORE rs2, rs1
- **0xE**: BRANCH rs1, rs2 (branch if equal)
- **0xF**: JAL rd (jump and link)

### Instruction Examples
```assembly
ADD x1, x2, x3     # x1 = x2 + x3
SUB x4, x1, x2     # x4 = x1 - x2
MUL x5, x3, x4     # x5 = x3 * x4 (8x8→16-bit)
AND x6, x1, x2     # x6 = x1 & x2
NOT x7, x1         # x7 = ~x1
SLL x8, x1, x2     # x8 = x1 << (x2 & 0xF)
LOAD x9, x1        # x9 = memory[0x8000 + x1]
STORE x2, x1       # memory[0x8000 + x1] = x2
BRANCH x1, x2      # if (x1 == x2) pc = pc + 1 + offset
```

## External Memory Interface

### I2C EEPROM Requirements
- **Device Address**: 0x50 (24LC512 compatible)
- **Capacity**: 64KB (512 Kbit)
- **Address Width**: 16-bit
- **Clock Speed**: 100kHz
- **Connections**: SCL (uio_out[0]), SDA (uio_in[1] bidirectional)

### Memory Organization
**Address Map**:
- **0x0000-0x7FFF**: Instruction memory (32KB)
- **0x8000-0xFFFF**: Data memory (32KB)

**Instruction Layout**:
- Each instruction: 2 bytes (16-bit)
- Little-endian byte order
- PC increments by 1 per instruction

### I2C Protocol Implementation
- **Start/Stop Conditions**: Hardware generated
- **Bidirectional SDA**: Controlled via output enable
- **Clock Generation**: Divided from system clock
- **Error Handling**: Timeout and NACK detection

## Pin Configuration

### TinyTapeout Interface

**Inputs** (`ui_in[7:0]`):
- All unused (debug interface removed for area optimization)

**Bidirectional** (`uio_in[7:0]`, `uio_out[7:0]`, `uio_oe[7:0]`):
- **uio_out[0]**: I2C Clock (SCL)
- **uio_in[1]/uio_out[1]**: I2C Data (SDA), controlled by uio_oe[1]
- **uio_out[3:2]**: EEPROM address bits [15:14] (debug)
- **uio_out[5:4]**: Program counter bits [7:6] (debug)
- **uio_out[6]**: Halt flag (processor stopped)
- **uio_out[7]**: Valid flag (instruction executed)

**Outputs** (`uo_out[7:0]`):
- **uo_out[3:0]**: Program counter [3:0]
- **uo_out[7:4]**: EEPROM address [3:0]

## Performance Characteristics

### Execution Timing
- **Instruction Fetch**: ~80μs (2 I2C byte reads)
- **Memory Operation**: ~40μs (1 I2C byte read/write)
- **ALU Operation**: 1 clock cycle
- **Total Instruction Time**: ~100μs average
- **Performance**: ~10,000 instructions/second

### Clock Domains
- **System Clock**: 10MHz target
- **I2C Clock**: 100kHz (divided from system)
- **Single Clock Domain**: No clock domain crossing

## Programming and Debug

### EEPROM Programming
Programs must be loaded into external EEPROM before execution:
1. Use Arduino or I2C programmer to write instructions
2. Connect programmed EEPROM to processor I2C pins
3. Apply power and release reset
4. Monitor execution via debug pins

### Debug Interface
- **PC Monitoring**: Current instruction address via uo_out[3:0] + uio_out[5:4]
- **Memory Address**: Current EEPROM access via uo_out[7:4] + uio_out[3:2]
- **Execution Status**: Valid instruction flag via uio_out[7]
- **Halt Detection**: Processor halt via uio_out[6]
- **I2C Activity**: SCL signal via uio_out[0]

### Example Program Structure
```assembly
# Initialize registers
ADD x1, x0, x0     # x1 = 0
ADD x2, x0, x0     # x2 = 0

# Main loop
ADD x1, x1, x2     # x1 = x1 + x2  
ADD x2, x2, x1     # x2 = x2 + x1
BRANCH x0, x0      # Infinite loop (always branch)
```

## Silicon Implementation

### Physical Specifications
- **Process**: IHP 130nm
- **Die Area**: 1x2 TinyTapeout tile (334×108 μm)  
- **Utilization**: ~54% area utilization
- **Power**: <1mW estimated @ 3.3V, 10MHz
- **I/O Count**: 8 inputs, 8 outputs, 8 bidirectional

### Design Features
- **Single Clock Domain**: Simplified timing analysis
- **Asynchronous Reset**: Standard practice for reliability
- **Static Logic**: No dynamic or domino logic
- **Standard Cells**: Compatible with OpenROAD flow

### Synthesis Configuration
- **Target Frequency**: 10MHz
- **Timing Constraints**: Single cycle paths
- **Area Optimization**: Balanced with timing requirements
- **Power Optimization**: Clock gating not used for simplicity