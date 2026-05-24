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
    input  wire [7:0]  addr,        // Instruction address
    input  wire        prog_mode,   // Programming mode
    input  wire [3:0]  prog_data,   // Programming data (4-bit nibbles)
    input  wire        prog_clk,    // Programming clock
    output reg  [7:0]  data_out     // 8-bit instruction data output
);

    // Memory array: 256 bytes (64 instructions x 4 bytes each)
    reg [7:0] memory [255:0];

    // Programming interface state
    reg [7:0] prog_addr;
    reg [1:0] prog_nibble_count;
    reg [7:0] prog_byte_buffer;

    // Programming logic
    always_ff @(posedge prog_clk or negedge rst_n) begin
        if (!rst_n) begin
            prog_addr <= 8'h00;
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
        for (i = 0; i < 256; i = i + 1) begin
            memory[i] = 8'h00;
        end

        // Simple test program: Fibonacci sequence
        // Instruction 0: ADDI x1, x0, 1    // x1 = 1 (first fib number)
        memory[0]  = 8'h93; // opcode + rd[0]
        memory[1]  = 8'h00; // rd[4:1] + funct3[0]
        memory[2]  = 8'h10; // funct3[2:1] + rs1[2:0]
        memory[3]  = 8'h00; // rs1[4:3] + imm[4:0]

        // Instruction 1: ADDI x2, x0, 1    // x2 = 1 (second fib number)
        memory[4]  = 8'h13; // opcode + rd[0]
        memory[5]  = 8'h01; // rd[4:1] + funct3[0]
        memory[6]  = 8'h10; // funct3[2:1] + rs1[2:0]
        memory[7]  = 8'h00; // rs1[4:3] + imm[4:0]

        // Instruction 2: ADD x3, x1, x2    // x3 = x1 + x2 (next fib)
        memory[8]  = 8'hB3; // opcode + rd[0]
        memory[9]  = 8'h81; // rd[4:1] + funct3[0]
        memory[10] = 8'h20; // funct3[2:1] + rs1[2:0]
        memory[11] = 8'h00; // funct7[0] + rs2[0] + rs1[4:3]

        // Instruction 3: ADDI x1, x2, 0    // x1 = x2 (move x2 to x1)
        memory[12] = 8'h93; // opcode + rd[0]
        memory[13] = 8'h00; // rd[4:1] + funct3[0]
        memory[14] = 8'h00; // funct3[2:1] + rs1[2:0]
        memory[15] = 8'h00; // rs1[4:3] + imm[4:0]

        // Instruction 4: ADDI x2, x3, 0    // x2 = x3 (move x3 to x2)
        memory[16] = 8'h13; // opcode + rd[0]
        memory[17] = 8'h01; // rd[4:1] + funct3[0]
        memory[18] = 8'h80; // funct3[2:1] + rs1[2:0]
        memory[19] = 8'h00; // rs1[4:3] + imm[4:0]

        // Instruction 5: JAL x0, -12      // Jump back to instruction 2 (infinite loop)
        memory[20] = 8'h6F; // opcode
        memory[21] = 8'h00; // rd[4:0]
        memory[22] = 8'h40; // imm[8:1]
        memory[23] = 8'hFF; // imm[19:12]
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