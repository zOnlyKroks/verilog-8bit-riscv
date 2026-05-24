/*
 * 8-bit ALU for RISC-V CPU
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module alu (
    input  wire [7:0] a,        // First operand
    input  wire [7:0] b,        // Second operand
    input  wire [3:0] alu_op,   // ALU operation selector
    output reg  [7:0] result,   // ALU result
    output wire       zero_flag // Zero flag for branches
);

    // ALU operation codes - reduced set for area savings
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b0101;  // Set less than
    localparam ALU_BEQ  = 4'b1010;  // Branch equal
    localparam ALU_BNE  = 4'b1011;  // Branch not equal
    localparam ALU_BLT  = 4'b1100;  // Branch less than
    localparam ALU_BGE  = 4'b1101;  // Branch greater/equal
    // Removed: SLTU, SLL, SRL, SRA, BLTU, BGEU for area savings

    // Internal signals
    wire [8:0] add_result = {1'b0, a} + {1'b0, b};
    wire [8:0] sub_result = {1'b0, a} - {1'b0, b};
    wire signed [7:0] a_signed = a;
    wire signed [7:0] b_signed = b;

    // ALU operation logic - simplified for area
    always @(*) begin
        case (alu_op)
            ALU_ADD:  result = add_result[7:0];
            ALU_SUB:  result = sub_result[7:0];
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLT:  result = (a_signed < b_signed) ? 8'h01 : 8'h00;

            // Branch operations (result indicates if branch should be taken)
            ALU_BEQ:  result = (a == b) ? 8'h01 : 8'h00;
            ALU_BNE:  result = (a != b) ? 8'h01 : 8'h00;
            ALU_BLT:  result = (a_signed < b_signed) ? 8'h01 : 8'h00;
            ALU_BGE:  result = (a_signed >= b_signed) ? 8'h01 : 8'h00;

            default:  result = 8'h00;
        endcase
    end

    // Zero flag generation
    assign zero_flag = (result == 8'h00);

endmodule