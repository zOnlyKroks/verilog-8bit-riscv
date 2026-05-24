/*
 * Instruction Memory with Programming Interface
 * 256-byte ROM (64 x 32-bit instructions) for 8-bit RISC-V CPU
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module instruction_memory (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [4:0]  addr,        // Instruction address (5 bits for 32 bytes)
    input  wire        prog_mode,   // Programming mode
    input  wire [3:0]  prog_data,   // Programming data (4-bit nibbles)
    input  wire        prog_clk,    // Programming clock
    output reg  [7:0]  data_out     // 8-bit instruction data output
);

    // Memory array: 32 bytes (8 instructions x 4 bytes each)
    reg [7:0] memory [31:0];

    // Programming interface state
    reg [4:0] prog_addr;
    reg [1:0] prog_nibble_count;
    reg [7:0] prog_byte_buffer;

    // Programming logic
    always_ff @(posedge prog_clk or negedge rst_n) begin
        if (!rst_n) begin
            prog_addr <= 5'h00;
            prog_nibble_count <= 2'b00;
            prog_byte_buffer <= 8'h00;
        end else if (prog_mode) begin
            // Accumulate 4-bit nibbles into bytes
            case (prog_nibble_count)
                2'b00: begin
                    prog_byte_buffer[3:0] <= prog_data;
                    prog_nibble_count <= 2'b01;
                end
                2'b01: begin
                    prog_byte_buffer[7:4] <= prog_data;
                    prog_nibble_count <= 2'b00;
                    // Write complete byte to memory
                    memory[prog_addr] <= {prog_data, prog_byte_buffer[3:0]};
                    prog_addr <= prog_addr + 1;
                end
            endcase
        end
    end

    // Memory initialization with a simple test program
    integer i;
    initial begin
        // Initialize all memory to zero
        for (i = 0; i < 32; i = i + 1) begin
            memory[i] = 8'h00;
        end

        // Simple test program: Counter loop
        // Instruction 0: ADDI x1, x0, 1    // x1 = 1
        // 0x00100093 = ADDI x1, x0, 1
        memory[0]  = 8'h93; // [7:0]   = opcode + rd[0]
        memory[1]  = 8'h00; // [15:8]  = rd[4:1] + funct3
        memory[2]  = 8'h10; // [23:16] = imm[7:0] + rs1[0]
        memory[3]  = 8'h00; // [31:24] = imm[11:8] + rs1[4:1]

        // Instruction 1: ADDI x1, x1, 1    // x1 = x1 + 1 (increment)
        // 0x00108093 = ADDI x1, x1, 1
        memory[4]  = 8'h93; // [7:0]   = opcode + rd[0]
        memory[5]  = 8'h80; // [15:8]  = rd[4:1] + funct3
        memory[6]  = 8'h10; // [23:16] = imm[7:0] + rs1[0]
        memory[7]  = 8'h00; // [31:24] = imm[11:8] + rs1[4:1]

        // Instruction 2: ADDI x2, x1, 0    // x2 = x1 (copy for output)
        // 0x00008113 = ADDI x2, x1, 0
        memory[8]  = 8'h13; // [7:0]   = opcode + rd[0]
        memory[9]  = 8'h81; // [15:8]  = rd[4:1] + funct3
        memory[10] = 8'h00; // [23:16] = imm[7:0] + rs1[0]
        memory[11] = 8'h00; // [31:24] = imm[11:8] + rs1[4:1]

        // Instruction 3: ADDI x3, x1, 0    // x3 = x1 (copy for observation)
        // 0x00008193 = ADDI x3, x1, 0
        memory[12] = 8'h93; // [7:0]   = opcode + rd[0]
        memory[13] = 8'h81; // [15:8]  = rd[4:1] + funct3
        memory[14] = 8'h00; // [23:16] = imm[7:0] + rs1[0]
        memory[15] = 8'h00; // [31:24] = imm[11:8] + rs1[4:1]

        // Instruction 4: ADDI x4, x2, 0    // x4 = x2 (copy for observation)
        // 0x00010213 = ADDI x4, x2, 0
        memory[16] = 8'h13; // [7:0]   = opcode + rd[0]
        memory[17] = 8'h02; // [15:8]  = rd[4:1] + funct3
        memory[18] = 8'h01; // [23:16] = imm[7:0] + rs1[0]
        memory[19] = 8'h00; // [31:24] = imm[11:8] + rs1[4:1]

        // Instruction 5: ADDI x5, x3, 1    // x5 = x3 + 1
        // 0x00118293 = ADDI x5, x3, 1
        memory[20] = 8'h93; // [7:0]   = opcode + rd[0]
        memory[21] = 8'h82; // [15:8]  = rd[4:1] + funct3
        memory[22] = 8'h11; // [23:16] = imm[7:0] + rs1[0]
        memory[23] = 8'h00; // [31:24] = imm[11:8] + rs1[4:1]

        // Instruction 6-7: More ADDI instructions to see register changes
        memory[24] = 8'h13; memory[25] = 8'h03; memory[26] = 8'h11; memory[27] = 8'h00; // ADDI x6, x2, 1
        memory[28] = 8'h93; memory[29] = 8'h83; memory[30] = 8'h12; memory[31] = 8'h00; // ADDI x7, x5, 2
    end

    // Read logic
    always_comb begin
        if (prog_mode) begin
            data_out = 8'h00; // No output during programming
        end else begin
            data_out = memory[addr];
        end
    end

endmodule