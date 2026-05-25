# 8-bit RISC-V Processor for TinyTapeout

Compact RISC-V processor implementation optimized for silicon fabrication via TinyTapeout IHP shuttle.

**Author**: Finn Rades (zOnlyKroks)  
**Target**: TinyTapeout 1x2 tile (334x108 μm)  
**Utilization**: 80% @ 24KB ROM configuration

## Technical Specifications

### Architecture
- **Datapath**: 8-bit Harvard architecture
- **Registers**: 4 general-purpose (x0-x3), x0 hardwired to zero
- **Instruction Memory**: 24 bytes ROM (6 instructions)
- **Data Memory**: 12 bytes RAM
- **Execution**: Multi-cycle (7 states: FETCH_0-3, DECODE, EXECUTE, WRITEBACK, HALT)

### Instruction Set (RV32I Subset)
**Arithmetic/Logic**:
- `ADD rd, rs1, rs2` - Addition
- `SUB rd, rs1, rs2` - Subtraction  
- `AND rd, rs1, rs2` - Bitwise AND
- `OR rd, rs1, rs2` - Bitwise OR
- `XOR rd, rs1, rs2` - Bitwise XOR
- `SLT rd, rs1, rs2` - Set less than (signed)
- `SLL rd, rs1, rs2` - Shift left logical

**Immediate Operations**:
- `ADDI rd, rs1, imm` - Add immediate
- `ANDI rd, rs1, imm` - AND immediate
- `ORI rd, rs1, imm` - OR immediate  
- `XORI rd, rs1, imm` - XOR immediate
- `SLTI rd, rs1, imm` - Set less than immediate
- `SLLI rd, rs1, shamt` - Shift left logical immediate

**Memory**:
- `LB rd, offset(rs1)` - Load byte
- `SB rs2, offset(rs1)` - Store byte

**Branches**:
- `BEQ rs1, rs2, offset` - Branch if equal
- `BNE rs1, rs2, offset` - Branch if not equal
- `BLT rs1, rs2, offset` - Branch if less than
- `BGE rs1, rs2, offset` - Branch if greater/equal

**Jumps**:
- `JAL rd, offset` - Jump and link
- `JALR rd, rs1, offset` - Jump and link register
- `LUI rd, imm` - Load upper immediate

### Pin Configuration

**Inputs** (`ui_in[7:0]`):
- `ui_in[0]` - Reset (active low)
- `ui_in[1]` - Programming mode enable
- `ui_in[7:4]` - Programming data (4-bit nibbles)

**Bidirectional** (`uio_in[7:0]`, `uio_out[7:0]`):
- `uio_in[0]` - Programming clock
- `uio_out[3:0]` - Instruction data debug
- `uio_out[6]` - Halt flag
- `uio_out[7]` - Valid instruction flag

**Outputs** (`uo_out[7:0]`):
- `uo_out[3:0]` - Program counter (4 LSBs)
- `uo_out[7:4]` - Opcode debug (4 LSBs)

### Fabrication Specifications
- **Process**: IHP 130nm
- **Die Area**: 1x2 TinyTapeout tile (334x108 μm)
- **Gate Count**: ~2500 gates
- **Clock Target**: 10 MHz maximum
- **Power**: <1mW estimated

## Programming the Device

### TinyTapeout Dev Board Setup

1. **Power Connection**
   - Connect 3.3V supply to VDD
   - Connect GND to VSS
   - Apply clock signal (1-10 MHz) to CLK

2. **Enter Programming Mode**
   ```
   ui_in[1] = 1    // Enable programming mode
   ui_in[0] = 0    // Hold reset
   ui_in[0] = 1    // Release reset
   ```

3. **Load Instructions**
   Each 32-bit instruction requires 8 clock cycles of 4-bit nibbles:
   ```
   for each instruction word:
     for nibble in [7:0]:  // LSB first
       uio_in[7:4] = instruction_nibbles[nibble]
       uio_in[0] = 1  // Programming clock high
       uio_in[0] = 0  // Programming clock low
   ```

4. **Start Execution**
   ```
   ui_in[1] = 0    // Disable programming mode
   ```

### Example Program Loading

Load simple counter program:
```assembly
# Instruction 0: ADDI x1, x0, 1  (0x00100093)
# Instruction 1: ADDI x1, x1, 1  (0x00108093)  
# Instruction 2: ADDI x2, x1, 0  (0x00008113)
```

Programming sequence:
```
// Instruction 0: 0x00100093
Nibble 0: 0x3, Nibble 1: 0x0, Nibble 2: 0x0, Nibble 3: 0x9
Nibble 4: 0x0, Nibble 5: 0x1, Nibble 6: 0x0, Nibble 7: 0x0

// Instruction 1: 0x00108093  
Nibble 0: 0x3, Nibble 1: 0x0, Nibble 2: 0x8, Nibble 3: 0x9
Nibble 4: 0x0, Nibble 5: 0x1, Nibble 6: 0x0, Nibble 7: 0x0

// Instruction 2: 0x00008113
Nibble 0: 0x3, Nibble 1: 0x1, Nibble 2: 0x8, Nibble 3: 0x0
Nibble 4: 0x0, Nibble 5: 0x0, Nibble 6: 0x0, Nibble 7: 0x0
```

## Debug Interface

### Runtime Monitoring
- **PC Output**: `uo_out[3:0]` shows current program counter
- **Opcode**: `uo_out[7:4]` shows current instruction opcode
- **Halt Status**: `uio_out[6]` indicates processor halt
- **Valid Flag**: `uio_out[7]` indicates valid instruction execution

### Memory Map
**Instruction Memory**: 0x00-0x17 (24 bytes)  
**Data Memory**: 0x00-0x0B (12 bytes)

### Register Constraints
Only registers x0-x3 are implemented:
- x0: Always zero (RISC-V standard)
- x1-x3: General purpose 8-bit registers

Instructions referencing x4-x31 will use x0 (reads) or be ignored (writes).

## Limitations

- **Reduced register set**: Only 4 of 32 RISC-V registers
- **Limited memory**: 24B ROM, 12B RAM
- **No interrupts**: Polling-based I/O only  
- **No multiplication/division**: Software implementation required
- **No floating point**: Integer operations only
- **8-bit addressing**: 256-byte maximum address space

## File Structure

```
src/
├── project.v           # TinyTapeout wrapper
├── riscv_cpu.v         # CPU core with state machine  
├── alu.v               # 8-bit ALU
├── register_file.v     # 4x8-bit register file
├── control_unit.v      # Instruction decoder
├── instruction_memory.v # 24-byte ROM
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

Target utilization: 80% @ 1x2 tile with 24-byte ROM configuration.
