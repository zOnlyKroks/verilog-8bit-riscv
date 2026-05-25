/*
 * Control Unit for 8-bit RISC-V CPU
 * Generates control signals for all CPU components
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module control_unit (
    input  wire [3:0] opcode,      // 4-bit opcode for 16-bit instructions
    input  wire [2:0] funct3,      // Function field 3
    output reg  [4:0] alu_op,      // ALU operation code (expanded to 5 bits)
    output reg        reg_write_en, // Register write enable
    output reg        mem_read_en,  // Memory read enable
    output reg        mem_write_en, // Memory write enable
    output reg  [1:0] pc_sel,      // PC source select
    output reg  [1:0] reg_data_sel // Register write data select
    // output reg        jump_taken   // Removed unused signal
);

    // Compact 4-bit opcodes for 16-bit instructions
    localparam OP_IMM     = 4'b0000;  // Immediate arithmetic
    localparam OP_REG     = 4'b0001;  // Register-register arithmetic
    localparam OP_LOAD    = 4'b0010;  // Load instructions
    localparam OP_STORE   = 4'b0011;  // Store instructions
    localparam OP_BRANCH  = 4'b0100;  // Branch instructions
    localparam OP_JAL     = 4'b0101;  // Jump and Link
    localparam OP_JALR    = 4'b0110;  // Jump and Link Register
    localparam OP_LUI     = 4'b0111;  // Load Upper Immediate
    localparam OP_SHIFT   = 4'b1000;  // Shift operations

    // ALU operation mapping
    always @(*) begin
        // Default values
        alu_op = 5'b00000;
        reg_write_en = 1'b0;
        mem_read_en = 1'b0;
        mem_write_en = 1'b0;
        pc_sel = 2'b00;        // Normal PC increment
        reg_data_sel = 2'b00;  // ALU result
        // jump_taken = 1'b0;     // Removed unused signal

        case (opcode)
            OP_IMM: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                case (funct3)
                    3'b000: alu_op = 5'b00000; // ADDI
                    3'b001: alu_op = 5'b00111; // SLLI
                    3'b010: alu_op = 5'b00101; // SLTI
                    3'b011: alu_op = 5'b00110; // SLTIU
                    3'b100: alu_op = 5'b00100; // XORI
                    3'b101: alu_op = 5'b01000; // SRLI
                    3'b110: alu_op = 5'b00011; // ORI
                    3'b111: alu_op = 5'b00010; // ANDI
                    default: alu_op = 5'b00000;
                endcase
            end

            OP_REG: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                case (funct3)
                    3'b000: alu_op = 5'b00000;      // ADD
                    3'b001: alu_op = 5'b00001;      // SUB
                    3'b010: alu_op = 5'b01010;      // MUL
                    3'b011: alu_op = 5'b01011;      // MULH
                    3'b100: alu_op = 5'b00100;      // XOR
                    3'b101: alu_op = 5'b00101;      // SLT
                    3'b110: alu_op = 5'b00011;      // OR
                    3'b111: alu_op = 5'b00010;      // AND
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
                // jump_taken = 1'b1;    // Removed unused signal
            end

            OP_JALR: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b10; // PC + 4 (return address)
                pc_sel = 2'b11;       // Jump register
                // jump_taken = 1'b1;    // Removed unused signal
                alu_op = 5'b00000;     // ADD for target address calculation
            end

            OP_LUI: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b11; // Immediate value
            end

            OP_SHIFT: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                case (funct3)
                    3'b000: alu_op = 5'b00111;      // SLL
                    3'b001: alu_op = 5'b01000;      // SRL
                    3'b010: alu_op = 5'b01001;      // SRA
                    3'b011: alu_op = 5'b00110;      // SLTU
                    default: alu_op = 5'b00111;
                endcase
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