# 8-bit RISC-V Processor Optimization Notes

## Area Optimizations Implemented

### Register File (Major Savings)
- **Reduced from 32 to 16 registers** 
  - Saves: ~128 flip-flops (16 registers × 8 bits each)
  - Address width: 4 bits instead of 5 bits
  - Impact: ~20-25% gate count reduction

### Instruction Set Optimization  
- **Focused subset of RV32I**
  - Omitted: Multiplication, division, atomic operations
  - Omitted: CSR instructions, system calls
  - Omitted: Fence instructions
  - Result: Simpler control logic

### Memory Architecture
- **Instruction ROM: 256 bytes** (64 × 32-bit instructions)
  - Sufficient for typical embedded programs
  - Fixed-size reduces control complexity
- **Data RAM: 64 bytes** 
  - Adequate for variables and small stack
  - 6-bit addressing saves logic

### Multi-cycle Design Benefits
- **6-7 cycles per instruction**
  - Fetch: 4 cycles (32-bit instruction via 8-bit bus)
  - Decode: 1 cycle
  - Execute: 1-2 cycles
  - Writeback: 1 cycle
- **Reduced combinatorial complexity**
  - Smaller critical path
  - Lower power consumption
  - Better timing closure

### Control Unit Optimization
- **Simple FSM-based design**
  - 8 states maximum
  - Minimal state encoding (3 bits)
- **Shared control signals**
  - Single ALU handles arithmetic, logic, and comparisons
  - Unified immediate handling

## Estimated Resource Usage

| Component | Gates (Est.) | Percentage |
|-----------|--------------|------------|
| Register File | ~800 | 30% |
| ALU | ~600 | 22% |
| Control Unit | ~400 | 15% |
| Instruction Memory | ~500 | 18% |
| Data Memory | ~300 | 11% |  
| Other Logic | ~100 | 4% |
| **Total** | **~2700** | **100%** |

## Additional Optimizations for Future Versions

### If More Area Needed:
1. **Reduce instruction memory to 128 bytes** (32 instructions)
2. **Implement 4-bit ALU** with serial operation  
3. **Use single-port register file** (slower but smaller)
4. **Remove branch prediction** (use simpler branching)

### If More Area Available:
1. **Add full 32 registers** for RV32I compliance
2. **Implement multiplication** using shift-add algorithm
3. **Add more instruction types** (LUI, AUIPC)
4. **Increase data memory** to 128 or 256 bytes

## Design Trade-offs Made

### Performance vs Area
- **Chose area efficiency** over raw performance
- Multi-cycle execution reduces gate count significantly
- Still achieves respectable performance at 10MHz target

### Compatibility vs Practicality  
- **Reduced to 16 registers** breaks strict RV32I compliance
- But maintains software compatibility for simple programs
- Allows real implementation in constrained area

### Features vs Simplicity
- **Focused on core instruction set**
- Omitted complex features that would explode area
- Result: Clean, understandable design

## Verification Strategy

### Functional Tests
- ✅ Basic arithmetic operations
- ✅ Memory load/store operations  
- ✅ Branch and jump instructions
- ✅ Fibonacci sequence (integration test)

### Corner Case Tests
- ✅ Register x0 always reads zero
- ✅ PC wraparound behavior
- ✅ Memory boundary checking
- ✅ Invalid instruction handling

### Performance Analysis
- Instruction throughput: ~1.4-1.7 MIPS @ 10MHz
- Memory bandwidth: 10 MB/s instruction, 1.4 MB/s data
- Power: TBD (post-silicon measurement)

## Conclusion

This 8-bit RISC-V processor successfully balances:
- **Educational value** - Complete, understandable implementation
- **Technical challenge** - Real RISC-V processor in silicon
- **Area constraints** - Fits in single TinyTapeout tile
- **Functionality** - Runs real programs (Fibonacci, arithmetic)

The design demonstrates that even complex processors can be implemented in very small silicon areas with careful optimization and intelligent trade-offs.