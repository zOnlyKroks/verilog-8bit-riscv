/*
 * Simple Multiplier for RISC-V CPU
 * Implements basic multiplication without shared circuits for now
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module shared_multiplier (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,        // Start multiplication
    input  wire [15:0] a,           // Multiplicand
    input  wire [15:0] b,           // Multiplier
    input  wire        high_result, // 1=return high 16 bits, 0=return low 16 bits

    output reg  [15:0] result,      // Multiplication result
    output reg         done,        // Multiplication complete

    // Shared resource interfaces (unused for now)
    output wire [15:0] alu_a,       // ALU input A
    output wire [15:0] alu_b,       // ALU input B
    output wire        alu_add,     // ALU operation (1=add, 0=sub)
    input  wire [15:0] alu_result,  // ALU result

    output wire [15:0] shift_data,  // Shifter input
    output wire [3:0]  shift_amount,// Shift amount
    output wire        shift_left,  // Shift direction
    input  wire [15:0] shift_result // Shifter result
);

    // Simple 2-cycle multiplier
    reg [1:0] cycle_count;
    reg [31:0] product_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 16'h0000;
            cycle_count <= 2'b00;
            product_reg <= 32'h00000000;
        end else begin
            if (start && cycle_count == 2'b00) begin
                // Start multiplication - simple array multiplier
                product_reg <= a * b;
                cycle_count <= 2'b01;
                done <= 1'b0;
            end else if (cycle_count == 2'b01) begin
                // Complete multiplication
                result <= high_result ? product_reg[31:16] : product_reg[15:0];
                done <= 1'b1;
                cycle_count <= 2'b10;
            end else if (!start) begin
                // Reset when start released
                done <= 1'b0;
                cycle_count <= 2'b00;
            end
        end
    end

    // Tie off unused shared resource interfaces
    assign alu_a = 16'h0000;
    assign alu_b = 16'h0000;
    assign alu_add = 1'b0;
    assign shift_data = 16'h0000;
    assign shift_amount = 4'h0;
    assign shift_left = 1'b0;

endmodule