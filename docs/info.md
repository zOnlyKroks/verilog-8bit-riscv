# 8-bit RISC-V Processor Technical Documentation

## Architecture

### Core Specifications
- **Datapath Width**: 8-bit
- **Architecture**: Harvard (separate instruction/data memory)
- **Execution Model**: Multi-cycle (7-state FSM)
- **Register File**: 4 registers (x0-x3)
- **Instruction Memory**: 24 bytes (6 instructions maximum)
- **Data Memory**: 12 bytes RAM
- **Address Space**: 8-bit (256 byte maximum)

### State Machine
Processor executes through 7 distinct states:
1. **FETCH_0**: Fetch instruction byte 0
2. **FETCH_1**: Fetch instruction byte 1  
3. **FETCH_2**: Fetch instruction byte 2
4. **FETCH_3**: Fetch instruction byte 3
5. **DECODE**: Decode instruction and generate control signals
6. **EXECUTE**: Perform ALU operation/memory access
7. **WRITEBACK**: Update register file and PC

### ALU Operations
- Addition/Subtraction with carry detection
- Bitwise AND, OR, XOR operations
- Shift left logical (variable shift amount)
- Set-less-than comparison (signed)
- Branch comparison operations (EQ, NE, LT, GE)

### Memory Architecture
**Instruction ROM (24 bytes)**:
- Addressable as bytes 0x00-0x17
- Pre-programmed via nibble interface
- Contains 32-bit RISC-V instructions
- Non-volatile storage

**Data RAM (12 bytes)**:
- Addressable as bytes 0x00-0x0B
- Read/write during execution
- Initialized to zero on reset
- Volatile storage

## Instruction Set Architecture

### Supported Instructions

**R-Type (Register-Register)**:
```
ADD  rd, rs1, rs2    # rd = rs1 + rs2
SUB  rd, rs1, rs2    # rd = rs1 - rs2  
AND  rd, rs1, rs2    # rd = rs1 & rs2
OR   rd, rs1, rs2    # rd = rs1 | rs2
XOR  rd, rs1, rs2    # rd = rs1 ^ rs2
SLT  rd, rs1, rs2    # rd = (rs1 < rs2) ? 1 : 0
SLL  rd, rs1, rs2    # rd = rs1 << (rs2 & 0x7)
```

**I-Type (Immediate)**:
```
ADDI rd, rs1, imm    # rd = rs1 + sign_extend(imm)
ANDI rd, rs1, imm    # rd = rs1 & zero_extend(imm)  
ORI  rd, rs1, imm    # rd = rs1 | zero_extend(imm)
XORI rd, rs1, imm    # rd = rs1 ^ zero_extend(imm)
SLTI rd, rs1, imm    # rd = (rs1 < sign_extend(imm)) ? 1 : 0
SLLI rd, rs1, shamt  # rd = rs1 << (shamt & 0x7)
```

**S-Type (Store)**:
```
SB   rs2, offset(rs1) # mem[rs1+offset] = rs2[7:0]
```

**B-Type (Branch)**:
```
BEQ  rs1, rs2, offset # if (rs1 == rs2) pc += offset
BNE  rs1, rs2, offset # if (rs1 != rs2) pc += offset  
BLT  rs1, rs2, offset # if (rs1 < rs2) pc += offset
BGE  rs1, rs2, offset # if (rs1 >= rs2) pc += offset
```

**U-Type (Upper Immediate)**:
```
LUI  rd, imm         # rd = imm << 12 (8-bit: rd = imm)
```

**J-Type (Jump)**:
```
JAL  rd, offset      # rd = pc+4, pc += offset
JALR rd, rs1, offset # rd = pc+4, pc = (rs1+offset) & ~1
```

### Register Constraints
- **x0**: Hardwired to zero (reads return 0, writes ignored)
- **x1-x3**: General purpose 8-bit registers
- **x4-x31**: Aliased to x0 (instruction compatibility)

### Immediate Encoding
- **12-bit immediates** truncated to 8-bit values
- **Sign extension** applied for arithmetic operations
- **Zero extension** applied for logical operations
- **Branch/Jump offsets** word-aligned for 8-bit addressing

## Programming Interface

### Pin Mapping

**Input Pins (`ui_in[7:0]`)**:
- `ui_in[0]`: Reset (active low)
- `ui_in[1]`: Programming mode enable
- `ui_in[2]`: Unused (formerly step mode)
- `ui_in[3]`: Unused  
- `ui_in[7:4]`: Programming data nibbles

**Bidirectional Pins (`uio_*[7:0]`)**:
- `uio_in[0]`: Programming clock
- `uio_out[3:0]`: Debug instruction data
- `uio_out[6]`: Halt flag
- `uio_out[7]`: Valid execution flag

**Output Pins (`uo_out[7:0]`)**:
- `uo_out[3:0]`: Program counter [3:0]
- `uo_out[7:4]`: Current opcode [6:0] lower 4 bits

### Programming Sequence

1. **Enter Programming Mode**:
   ```
   ui_in[1] = 1     // Enable programming
   ui_in[0] = 0     // Assert reset
   ui_in[0] = 1     // Release reset
   ```

2. **Load Instructions** (LSB first):
   ```
   for instruction in program:
     for nibble in range(8):  // 8 nibbles per 32-bit instruction
       ui_in[7:4] = (instruction >> (nibble * 4)) & 0xF
       uio_in[0] = 1  // Programming clock high
       uio_in[0] = 0  // Programming clock low
   ```

3. **Start Execution**:
   ```
   ui_in[1] = 0     // Disable programming mode
   ```

### Instruction Encoding Examples

**ADDI x1, x0, 5** (0x00500093):
```
Nibble 0: 0x3   Nibble 1: 0x0   Nibble 2: 0x0   Nibble 3: 0x9
Nibble 4: 0x0   Nibble 5: 0x5   Nibble 6: 0x0   Nibble 7: 0x0
```

**ADD x2, x1, x1** (0x001081B3):
```  
Nibble 0: 0x3   Nibble 1: 0x1   Nibble 2: 0x8   Nibble 3: 0xB
Nibble 4: 0x0   Nibble 5: 0x1   Nibble 6: 0x0   Nibble 7: 0x0
```

## Testing and Verification

### Built-in Test Program
Default ROM contains demonstration program:
1. Initialize x1 = 1
2. Increment x1 (x1 = 2)
3. Copy to x2 (x2 = 2)  
4. Copy to x3 (x3 = 2)
5. Add x1 + x2 → x1 (x1 = 4)
6. AND x1 & x3 → x2 (x2 = 0)

### Debug Monitoring
- **Program Counter**: Monitor via `uo_out[3:0]`
- **Opcode**: Current instruction via `uo_out[7:4]`
- **Halt Detection**: `uio_out[6]` asserted on invalid instruction
- **Execution Valid**: `uio_out[7]` during WRITEBACK state

### Performance Characteristics
- **Instruction Throughput**: 1 instruction per 7 clock cycles
- **Maximum Frequency**: 10 MHz (100ns period)
- **Program Execution Rate**: ~1.43 MHz instruction rate
- **Memory Access Time**: Single cycle (no wait states)

## Silicon Implementation

### Physical Specifications
- **Process Technology**: IHP 130nm
- **Die Area**: 1x2 TinyTapeout tile (334×108 μm)
- **Gate Count**: ~2500 equivalent gates
- **Utilization**: 80% at current configuration
- **Power**: <1mW estimated @ 3.3V, 10MHz

### Design Constraints
- **Timing**: 10MHz maximum frequency
- **Power**: Low power design, no dynamic voltage scaling
- **Area**: Optimized for 80% utilization within tile
- **Temperature**: Commercial grade (0°C to 85°C)

### Fabrication Details
- **Metal Layers**: Standard cell placement
- **I/O**: TinyTapeout standardized interface  
- **Clock**: Single clock domain, no clock gating
- **Reset**: Asynchronous assert, synchronous de-assert