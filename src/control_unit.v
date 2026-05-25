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
    output reg  [4:0] alu_op,      // ALU operation code (expanded to 5 bits)
    output reg        reg_write_en, // Register write enable
    output reg        mem_read_en,  // Memory read enable
    output reg        mem_write_en, // Memory write enable
    output reg  [1:0] pc_sel,      // PC source select
    output reg  [1:0] reg_data_sel, // Register write data select
    output reg        jump_taken   // Jump instruction
);

    // RISC-V instruction opcodes (only implemented ones)
    localparam OP_LUI     = 7'b0110111;  // Load Upper Immediate
    localparam OP_JAL     = 7'b1101111;  // Jump and Link
    localparam OP_JALR    = 7'b1100111;  // Jump and Link Register
    localparam OP_BRANCH  = 7'b1100011;  // Branch instructions
    localparam OP_LOAD    = 7'b0000011;  // Load instructions
    localparam OP_STORE   = 7'b0100011;  // Store instructions
    localparam OP_IMM     = 7'b0010011;  // Immediate arithmetic
    localparam OP_REG     = 7'b0110011;  // Register-register arithmetic

    // ALU operation mapping
    always @(*) begin
        // Default values
        alu_op = 5'b00000;
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
                    3'b000: alu_op = 5'b00000; // ADDI
                    3'b010: alu_op = 5'b00101; // SLTI
                    3'b011: alu_op = 5'b00110; // SLTIU
                    3'b100: alu_op = 5'b00100; // XORI
                    3'b110: alu_op = 5'b00011; // ORI
                    3'b111: alu_op = 5'b00010; // ANDI
                    3'b001: alu_op = 5'b00111; // SLLI
                    3'b101: begin
                        if (funct7[5]) alu_op = 5'b01001; // SRAI
                        else           alu_op = 5'b01000; // SRLI
                    end
                    default: alu_op = 5'b00000;
                endcase
            end

            OP_REG: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                case (funct3)
                    3'b000: begin
                        if (funct7[5])       alu_op = 5'b00001;      // SUB
                        else                 alu_op = 5'b00000;      // ADD (multiplication removed)
                    end
                    3'b001: alu_op = 5'b00111;      // SLL (multiplication removed)
                    3'b010: alu_op = 5'b00101;      // SLT (multiplication removed)
                    3'b011: alu_op = 5'b00110;      // SLTU (multiplication removed)
                    3'b100: alu_op = 5'b00100;      // XOR (division removed)
                    3'b101: begin
                        if (funct7[5])       alu_op = 5'b01001;      // SRA
                        else                 alu_op = 5'b01000;      // SRL
                    end
                    3'b110: alu_op = 5'b00011;      // OR (division removed)
                    3'b111: alu_op = 5'b00010;      // AND (division removed)
                    default: alu_op = 5'b00000;
                endcase
            end

            OP_LOAD: begin
                reg_write_en = 1'b1;
                mem_read_en = 1'b1;
                reg_data_sel = 2'b01; // Memory data
                alu_op = 5'b00000;     // ADD for address calculation
            end

            OP_STORE: begin
                mem_write_en = 1'b1;
                alu_op = 5'b00000;     // ADD for address calculation
            end

            OP_BRANCH: begin
                pc_sel = 2'b01; // Will use branch_taken signal from ALU
                case (funct3)
                    3'b000: alu_op = 5'b10000; // BEQ
                    3'b001: alu_op = 5'b10001; // BNE
                    3'b100: alu_op = 5'b10010; // BLT
                    3'b101: alu_op = 5'b10011; // BGE
                    3'b110: alu_op = 5'b10100; // BLTU
                    3'b111: alu_op = 5'b10101; // BGEU
                    default: alu_op = 5'b10000;
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
                alu_op = 5'b00000;     // ADD for target address calculation
            end

            OP_LUI: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b11; // Immediate value
                // For 8-bit implementation, just use lower 8 bits of immediate
            end

            default: begin
                // NOP or invalid instruction
                alu_op = 5'b00000;
                reg_write_en = 1'b0;
            end
        endcase
    end

    // Branch taken signal comes from ALU directly in CPU module

endmodule