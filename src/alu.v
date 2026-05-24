/*
 * 8-bit ALU for RISC-V CPU
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module alu (
    input  wire [7:0] a,        // First operand
    input  wire [7:0] b,        // Second operand
    input  wire [4:0] alu_op,   // ALU operation selector (expanded to 5 bits)
    output reg  [7:0] result,   // ALU result
    output wire       zero_flag // Zero flag for branches
);

    // ALU operation codes - expanded to 5 bits with division
    localparam ALU_ADD  = 5'b00000;
    localparam ALU_SUB  = 5'b00001;
    localparam ALU_AND  = 5'b00010;
    localparam ALU_OR   = 5'b00011;
    localparam ALU_XOR  = 5'b00100;
    localparam ALU_SLT  = 5'b00101;  // Set less than
    localparam ALU_SLTU = 5'b00110;  // Set less than unsigned
    localparam ALU_SLL  = 5'b00111;  // Shift left logical
    // SRL and SRA removed for area optimization
    localparam ALU_BEQ  = 5'b10000;  // Branch equal
    localparam ALU_BNE  = 5'b10001;  // Branch not equal
    localparam ALU_BLT  = 5'b10010;  // Branch less than
    localparam ALU_BGE  = 5'b10011;  // Branch greater/equal
    localparam ALU_BLTU = 5'b10100;  // Branch less than unsigned
    localparam ALU_BGEU = 5'b10101;  // Branch greater/equal unsigned

    // Internal signals
    wire [8:0] add_result = {1'b0, a} + {1'b0, b};
    wire [8:0] sub_result = {1'b0, a} - {1'b0, b};
    wire signed [7:0] a_signed = a;
    wire signed [7:0] b_signed = b;

    // ALU operation logic - full functionality with division
    always @(*) begin
        case (alu_op)
            ALU_ADD:  result = add_result[7:0];
            ALU_SUB:  result = sub_result[7:0];
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLT:  result = (a_signed < b_signed) ? 8'h01 : 8'h00;
            ALU_SLTU: result = (a < b) ? 8'h01 : 8'h00;
            ALU_SLL:  result = a << (b & 8'h07); // Only use lower 3 bits for shift amount
            // SRL and SRA removed for area optimization

            // Branch operations (result indicates if branch should be taken)
            ALU_BEQ:  result = (a == b) ? 8'h01 : 8'h00;
            ALU_BNE:  result = (a != b) ? 8'h01 : 8'h00;
            ALU_BLT:  result = (a_signed < b_signed) ? 8'h01 : 8'h00;
            ALU_BGE:  result = (a_signed >= b_signed) ? 8'h01 : 8'h00;
            ALU_BLTU: result = (a < b) ? 8'h01 : 8'h00;
            ALU_BGEU: result = (a >= b) ? 8'h01 : 8'h00;

            default:  result = 8'h00;
        endcase
    end

    // Zero flag generation
    assign zero_flag = (result == 8'h00);

endmodule