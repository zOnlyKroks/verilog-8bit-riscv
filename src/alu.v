/*
 * 16-bit ALU for RISC-V CPU
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module alu (
    input  wire [15:0] a,        // First operand
    input  wire [15:0] b,        // Second operand
    input  wire [4:0]  alu_op,   // ALU operation selector (expanded to 5 bits)
    output reg  [15:0] result,   // ALU result
    output wire        zero_flag // Zero flag for branches
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
    localparam ALU_MULH = 5'b01011;  // Multiplication high signed
    localparam ALU_MULHU= 5'b01100;  // Multiplication high unsigned
    localparam ALU_BEQ  = 5'b10000;  // Branch equal
    localparam ALU_BNE  = 5'b10001;  // Branch not equal
    localparam ALU_BLT  = 5'b10010;  // Branch less than
    localparam ALU_BGE  = 5'b10011;  // Branch greater/equal
    localparam ALU_BLTU = 5'b10100;  // Branch less than unsigned
    localparam ALU_BGEU = 5'b10101;  // Branch greater/equal unsigned

    // Internal signals
    wire [16:0] add_result = {1'b0, a} + {1'b0, b};
    wire [16:0] sub_result = {1'b0, a} - {1'b0, b};
    wire signed [15:0] a_signed = a;
    wire signed [15:0] b_signed = b;
    wire [3:0] shift_amount = b[3:0];  // Use lower 4 bits for shift amount

    // Multiplication logic (hardware accelerated)
    wire [31:0] mul_full = a * b;                          // Full multiplication result
    wire [15:0] mul_result = mul_full[15:0];               // Multiplication low
    wire [15:0] mulh_result = mul_full[31:16];             // Multiplication high (signed)
    wire [31:0] mulhu_full = a * b;                        // Unsigned multiplication
    wire [15:0] mulhu_result = mulhu_full[31:16];          // Multiplication high (unsigned)

    // ALU operation logic - full functionality with division
    always @(*) begin
        case (alu_op)
            // Arithmetic operations
            ALU_ADD:  result = add_result[15:0];
            ALU_SUB:  result = sub_result[15:0];
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;

            // Comparison operations
            ALU_SLT:  result = (a_signed < b_signed) ? 16'h0001 : 16'h0000;
            ALU_SLTU: result = (a < b) ? 16'h0001 : 16'h0000;

            // Shift operations
            ALU_SLL:  result = a << shift_amount;
            ALU_SRL:  result = a >> shift_amount;
            ALU_SRA:  result = $signed(a) >>> shift_amount;

            // Multiplication operations (hardware accelerated)
            ALU_MUL:  result = mul_result;
            ALU_MULH: result = mulh_result;
            ALU_MULHU:result = mulhu_result;

            // Branch operations (result indicates if branch should be taken)
            ALU_BEQ:  result = (a == b) ? 16'h0001 : 16'h0000;
            ALU_BNE:  result = (a != b) ? 16'h0001 : 16'h0000;
            ALU_BLT:  result = (a_signed < b_signed) ? 16'h0001 : 16'h0000;
            ALU_BGE:  result = (a_signed >= b_signed) ? 16'h0001 : 16'h0000;
            ALU_BLTU: result = (a < b) ? 16'h0001 : 16'h0000;
            ALU_BGEU: result = (a >= b) ? 16'h0001 : 16'h0000;

            default:  result = 16'h0000;
        endcase
    end

    // Zero flag generation
    assign zero_flag = (result == 16'h0000);

endmodule