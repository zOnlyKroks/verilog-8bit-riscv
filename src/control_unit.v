/*
 * Control Unit for 8-bit RISC-V CPU
 * Generates control signals for all CPU components
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module control_unit (
    input  wire [6:0] opcode,      // Instruction opcode
    input  wire [2:0] funct3,      // Function field 3
    input  wire [6:0] funct7,      // Function field 7
    output reg  [3:0] alu_op,      // ALU operation code
    output reg        reg_write_en, // Register write enable
    output reg        mem_read_en,  // Memory read enable
    output reg        mem_write_en, // Memory write enable
    output reg  [1:0] pc_sel,      // PC source select
    output reg  [1:0] reg_data_sel, // Register write data select
    output reg        jump_taken   // Jump instruction
);

    // RISC-V instruction opcodes
    localparam OP_LUI     = 7'b0110111;  // Load Upper Immediate
    localparam OP_AUIPC   = 7'b0010111;  // Add Upper Immediate to PC
    localparam OP_JAL     = 7'b1101111;  // Jump and Link
    localparam OP_JALR    = 7'b1100111;  // Jump and Link Register
    localparam OP_BRANCH  = 7'b1100011;  // Branch instructions
    localparam OP_LOAD    = 7'b0000011;  // Load instructions
    localparam OP_STORE   = 7'b0100011;  // Store instructions
    localparam OP_IMM     = 7'b0010011;  // Immediate arithmetic
    localparam OP_REG     = 7'b0110011;  // Register-register arithmetic
    localparam OP_FENCE   = 7'b0001111;  // Fence (not implemented)
    localparam OP_SYSTEM  = 7'b1110011;  // System instructions

    // ALU operation mapping
    always @(*) begin
        // Default values
        alu_op = 4'b0000;
        reg_write_en = 1'b0;
        mem_read_en = 1'b0;
        mem_write_en = 1'b0;
        pc_sel = 2'b00;        // Normal PC increment
        reg_data_sel = 2'b00;  // ALU result
        jump_taken = 1'b0;

        case (opcode)
            OP_IMM: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                case (funct3)
                    3'b000: alu_op = 4'b0000; // ADDI
                    3'b010: alu_op = 4'b0101; // SLTI
                    3'b100: alu_op = 4'b0100; // XORI
                    3'b110: alu_op = 4'b0011; // ORI
                    3'b111: alu_op = 4'b0010; // ANDI
                    // Removed shift operations for area savings
                    default: alu_op = 4'b0000;
                endcase
            end

            OP_REG: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                case (funct3)
                    3'b000: begin
                        if (funct7[5]) alu_op = 4'b0001; // SUB
                        else           alu_op = 4'b0000; // ADD
                    end
                    3'b010: alu_op = 4'b0101; // SLT
                    3'b100: alu_op = 4'b0100; // XOR
                    3'b110: alu_op = 4'b0011; // OR
                    3'b111: alu_op = 4'b0010; // AND
                    // Removed shift and unsigned operations for area savings
                    default: alu_op = 4'b0000;
                endcase
            end

            OP_LOAD: begin
                reg_write_en = 1'b1;
                mem_read_en = 1'b1;
                reg_data_sel = 2'b01; // Memory data
                alu_op = 4'b0000;     // ADD for address calculation
            end

            OP_STORE: begin
                mem_write_en = 1'b1;
                alu_op = 4'b0000;     // ADD for address calculation
            end

            OP_BRANCH: begin
                pc_sel = 2'b01; // Will use branch_taken signal from ALU
                case (funct3)
                    3'b000: alu_op = 4'b1010; // BEQ
                    3'b001: alu_op = 4'b1011; // BNE
                    3'b100: alu_op = 4'b1100; // BLT
                    3'b101: alu_op = 4'b1101; // BGE
                    // Removed unsigned branches for area savings
                    default: alu_op = 4'b1010;
                endcase
            end

            OP_JAL: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b10; // PC + 4 (return address)
                pc_sel = 2'b10;       // Jump
                jump_taken = 1'b1;
            end

            OP_JALR: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b10; // PC + 4 (return address)
                pc_sel = 2'b11;       // Jump register
                jump_taken = 1'b1;
                alu_op = 4'b0000;     // ADD for target address calculation
            end

            OP_LUI: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b11; // Immediate value
                // For 8-bit implementation, just use lower 8 bits of immediate
            end

            default: begin
                // NOP or invalid instruction
                alu_op = 4'b0000;
                reg_write_en = 1'b0;
            end
        endcase
    end

    // Branch taken signal comes from ALU directly in CPU module

endmodule