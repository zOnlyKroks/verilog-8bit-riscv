# 8-bit RISC-V Processor Test Suite

Comprehensive verification environment for the 8-bit RISC-V processor using cocotb framework.

## Test Coverage

### Core Functionality Tests
- **Multi-cycle execution**: Validates 7-state FSM operation
- **Register file**: Tests 4-register read/write operations
- **ALU operations**: Verifies arithmetic, logic, and comparison operations
- **Memory access**: Tests 12-byte data memory interface
- **Programming interface**: Validates instruction loading via nibbles

### Instruction Set Tests
- **R-Type**: ADD, SUB, AND, OR, XOR, SLT, SLL
- **I-Type**: ADDI, ANDI, ORI, XORI, SLTI, SLLI
- **S-Type**: SB (store byte to data memory)
- **B-Type**: BEQ, BNE, BLT, BGE (branch operations)
- **U-Type**: LUI (load upper immediate)
- **J-Type**: JAL, JALR (jump and link)

### Integration Tests
- **Default program execution**: Built-in 6-instruction test sequence
- **Register value propagation**: End-to-end data flow verification
- **Reset behavior**: Power-on state verification
- **Halt detection**: Invalid instruction handling

## Running Tests

### RTL Simulation
```bash
cd test
make -B
```

### Gate-Level Simulation
First, generate gate-level netlist:
```bash
cd .. && tt --debug gds
cp runs/wokwi/results/final/verilog/gl/tt_um_zonlykroks_8bit_riscv.v test/gate_level_netlist.v
cd test
make -B GATES=yes
```

### Waveform Generation
VCD format (smaller file size):
```bash
make -B FST=
```

FST format (faster loading):
```bash
make -B
```

## Test Configuration

### Key Test Parameters
- **Clock Period**: 100ns (10 MHz)
- **Reset Duration**: 10 clock cycles
- **Programming Clock**: Manual control via test driver
- **Timeout**: 1000 cycles per test case

### Expected Behavior
1. **Reset Phase**: All registers cleared, PC = 0
2. **Programming Phase**: Load instructions via 4-bit nibbles
3. **Execution Phase**: Run built-in test program
4. **Verification Phase**: Check register values and debug outputs

## Test Sequence Details

### Built-in Test Program
The processor executes this sequence on power-up:
```assembly
# Instruction 0: ADDI x1, x0, 1    // x1 = 1
# Instruction 1: ADDI x1, x1, 1    // x1 = 2
# Instruction 2: ADDI x2, x1, 0    // x2 = 2  
# Instruction 3: ADDI x3, x2, 1    // x3 = 3
# Instruction 4: ADD x1, x1, x2    // x1 = 4
# Instruction 5: AND x2, x1, x3    // x2 = 0
```

### Expected Results
After execution completion:
- **x0**: 0 (hardwired)
- **x1**: 4 
- **x2**: 0
- **x3**: 3
- **PC**: 6 (next instruction address)

### Debug Signal Monitoring
- `uo_out[3:0]`: Program counter value
- `uo_out[7:4]`: Current opcode (lower 4 bits)
- `uio_out[6]`: Halt flag (invalid instruction)
- `uio_out[7]`: Valid execution flag

## Waveform Analysis

### Key Signals to Monitor
```
clk                    - System clock
rst_n                  - Reset (active low)
ui_in[1]              - Programming mode
uio_in[0]             - Programming clock
ui_in[7:4]            - Programming data nibbles
cpu.state[2:0]        - CPU state machine
cpu.pc[7:0]           - Program counter
cpu.instruction[31:0] - Current instruction
cpu.regfile.registers - Register file contents
```

### State Machine Verification
Monitor state transitions:
```
FETCH_0 (000) → FETCH_1 (001) → FETCH_2 (010) → FETCH_3 (011) →
DECODE (100) → EXECUTE (101) → WRITEBACK (110)
```

Each complete instruction should take exactly 7 clock cycles.

### Programming Interface Verification
For each 32-bit instruction:
1. Set `ui_in[1] = 1` (programming mode)
2. Send 8 nibbles via `ui_in[7:4]` (LSB first)
3. Toggle `uio_in[0]` for each nibble
4. Verify instruction appears in `cpu.instruction_memory`

## Viewing Waveforms

### GTKWave
```bash
gtkwave tb.fst tb.gtkw
```

### Surfer (Modern Viewer)
```bash
surfer tb.fst  
```

### Recommended Waveform Groups
1. **Clock/Reset**: `clk`, `rst_n`, `ui_in[0]`
2. **Programming**: `ui_in[1]`, `ui_in[7:4]`, `uio_in[0]`
3. **CPU State**: `cpu.state`, `cpu.pc`, `cpu.instruction`
4. **Registers**: `cpu.regfile.registers[0]` through `cpu.regfile.registers[3]`
5. **Debug Outputs**: `uo_out`, `uio_out`

## Test Environment Setup

### Dependencies
- **Python 3.8+**
- **cocotb**: `pip install cocotb`
- **Icarus Verilog**: System package or compile from source
- **GTKWave**: For waveform viewing

### File Structure
```
test/
├── Makefile              # Test configuration and targets
├── test.py               # Main cocotb test suite
├── tb.v                  # Verilog testbench wrapper
└── README.md            # This file
```

### Troubleshooting
- **Simulation timeout**: Increase timeout in test.py
- **X/Z propagation**: Check reset timing and initialization
- **Programming failures**: Verify nibble order (LSB first)
- **State machine stuck**: Check clock and reset connectivity
