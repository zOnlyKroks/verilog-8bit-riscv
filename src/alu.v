/*
 * 16-bit ALU for RISC-V CPU
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module alu (
    input  wire        clk,      // Clock for shared multiplier
    input  wire        rst_n,    // Reset for shared multiplier
    input  wire [15:0] a,        // First operand
    input  wire [15:0] b,        // Second operand
    input  wire [4:0]  alu_op,   // ALU operation selector (expanded to 5 bits)
    output reg  [15:0] result,   // ALU result
    output wire        zero_flag // Zero flag for branches
    // output wire        mul_busy  // Removed for area optimization
);

    // ALU operation codes - expanded to 5 bits with full instruction set
    localparam ALU_ADD  = 5'b00000;
    localparam ALU_SUB  = 5'b00001;
    localparam ALU_AND  = 5'b00010;
    localparam ALU_OR   = 5'b00011;
    localparam ALU_XOR  = 5'b00100;
    localparam ALU_SLT  = 5'b00101;  // Set less than
    localparam ALU_SLTU = 5'b00110;  // Set less than unsigned
    localparam ALU_SLL  = 5'b00111;  // Shift left logical
    localparam ALU_SRL  = 5'b01000;  // Shift right logical
    localparam ALU_SRA  = 5'b01001;  // Shift right arithmetic
    localparam ALU_MUL  = 5'b01010;  // Multiplication
    // localparam ALU_MULH = 5'b01011;  // Removed for area optimization
    localparam ALU_BEQ  = 5'b10000;  // Branch equal
    localparam ALU_BNE  = 5'b10001;  // Branch not equal
    localparam ALU_BLT  = 5'b10010;  // Branch less than
    localparam ALU_BGE  = 5'b10011;  // Branch greater/equal
    localparam ALU_BLTU = 5'b10100;  // Branch less than unsigned
    localparam ALU_BGEU = 5'b10101;  // Branch greater/equal unsigned

    // Optimized internal signals
    wire [16:0] add_sub_result = (alu_op == ALU_SUB) ? ({1'b0, a} - {1'b0, b}) : ({1'b0, a} + {1'b0, b});
    wire signed [15:0] a_signed = a;
    wire signed [15:0] b_signed = b;
    wire [3:0] shift_amount = b[3:0];

    // Shared comparison logic
    wire less_than_signed = (a_signed < b_signed);
    wire less_than_unsigned = (a < b);
    wire equal = (a == b);

    // Barrel shifter logic
    wire shift_left = (alu_op == ALU_SLL);
    wire shift_arith = (alu_op == ALU_SRA);

    // Multiplication removed for area optimization
    // wire mul_start = (alu_op == ALU_MUL || alu_op == ALU_MULH);
    // wire mul_high = (alu_op == ALU_MULH);
    // wire [15:0] mul_result;
    // wire mul_done;

    // Multiplier removed for area optimization

    // Direct barrel shifter (no multiplier arbitration)
    wire [15:0] shift_result;
    barrel_shifter shared_shifter (
        .data_in(a),
        .shift_amount(shift_amount),
        .shift_left(shift_left),
        .shift_arith(shift_arith),
        .data_out(shift_result)
    );
    // assign mul_busy = using_multiplier; // Removed for area optimization

    // ALU operation logic - full functionality with division
    always @(*) begin
        case (alu_op)
            // Arithmetic operations (shared add/sub logic)
            ALU_ADD, ALU_SUB: result = add_sub_result[15:0];

            // Bitwise operations
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;

            // Comparison operations (shared comparison logic)
            ALU_SLT:  result = less_than_signed ? 16'h0001 : 16'h0000;
            ALU_SLTU: result = less_than_unsigned ? 16'h0001 : 16'h0000;

            // Shift operations (barrel shifter)
            ALU_SLL, ALU_SRL, ALU_SRA: result = shift_result;

            // Simplified multiplication (reduce timing pressure)
            ALU_MUL: begin
                result = a[7:0] * b[7:0];  // 8x8→16 multiplication for better timing
            end

            // Branch operations (shared comparison logic)
            ALU_BEQ:  result = equal ? 16'h0001 : 16'h0000;
            ALU_BNE:  result = equal ? 16'h0000 : 16'h0001;
            ALU_BLT:  result = less_than_signed ? 16'h0001 : 16'h0000;
            ALU_BGE:  result = less_than_signed ? 16'h0000 : 16'h0001;
            ALU_BLTU: result = less_than_unsigned ? 16'h0001 : 16'h0000;
            ALU_BGEU: result = less_than_unsigned ? 16'h0000 : 16'h0001;

            default:  result = 16'h0000;
        endcase
    end

    // Zero flag generation
    assign zero_flag = (result == 16'h0000);

endmodule