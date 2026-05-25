/*
 * Instruction Memory with Programming Interface
 * 256-byte ROM (64 x 32-bit instructions) for 8-bit RISC-V CPU
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module instruction_memory (
    input  wire        rst_n,
    input  wire [4:0]  addr,        // Instruction address (5 bits for 32 bytes)
    input  wire        prog_mode,   // Programming mode
    input  wire [3:0]  prog_data,   // Programming data (4-bit nibbles)
    input  wire        prog_clk,    // Programming clock
    output reg  [7:0]  data_out     // 8-bit instruction data output
);

    // Memory array: 24 bytes (6 instructions x 4 bytes each)
    reg [7:0] memory [23:0];

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
                default: prog_nibble_count <= 2'b00;
            endcase
        end
    end

    // Memory initialization with a simple test program
    integer i;
    initial begin
        // Initialize all memory to zero
        for (i = 0; i < 24; i = i + 1) begin
            memory[i] = 8'h00;
        end

        // Test program: 6 instructions using x0, x1, x2, x3
        // Instruction 0: ADDI x1, x0, 1    // x1 = 1
        memory[0]  = 8'h93; memory[1]  = 8'h00; memory[2]  = 8'h10; memory[3]  = 8'h00;

        // Instruction 1: ADDI x1, x1, 1    // x1 = x1 + 1 (x1 = 2)
        memory[4]  = 8'h93; memory[5]  = 8'h80; memory[6]  = 8'h10; memory[7]  = 8'h00;

        // Instruction 2: ADDI x2, x1, 0    // x2 = x1 (x2 = 2)
        memory[8]  = 8'h13; memory[9]  = 8'h81; memory[10] = 8'h00; memory[11] = 8'h00;

        // Instruction 3: ADDI x3, x2, 1    // x3 = x2 + 1 (x3 = 3)
        memory[12] = 8'h93; memory[13] = 8'h01; memory[14] = 8'h11; memory[15] = 8'h00;

        // Instruction 4: ADD x1, x1, x2    // x1 = x1 + x2 (x1 = 4)
        memory[16] = 8'hB3; memory[17] = 8'h80; memory[18] = 8'h20; memory[19] = 8'h00;

        // Instruction 5: AND x2, x1, x3    // x2 = x1 & x3 (x2 = 4 & 3 = 0)
        memory[20] = 8'h33; memory[21] = 8'hF1; memory[22] = 8'h30; memory[23] = 8'h00;
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