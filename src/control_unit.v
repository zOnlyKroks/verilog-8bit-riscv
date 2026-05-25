/*
 * Control Unit for 16-bit RISC-V CPU with 16 registers
 * Generates control signals for all CPU components
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module control_unit (
    input  wire [3:0] opcode,      // 4-bit opcode for 16-bit instructions
    input  wire [1:0] funct2,      // 2-bit function field for operation variants
    output reg  [4:0] alu_op,      // ALU operation code (expanded to 5 bits)
    output reg        reg_write_en, // Register write enable
    output reg        mem_read_en,  // Memory read enable
    output reg        mem_write_en, // Memory write enable
    output reg  [1:0] pc_sel,      // PC source select
    output reg  [1:0] reg_data_sel // Register write data select
);

    // Simplified 4-bit opcodes for 16 registers (no funct3)
    localparam OP_ADD     = 4'b0000;  // ADD operation
    localparam OP_SUB     = 4'b0001;  // SUB operation
    localparam OP_MUL     = 4'b0010;  // MUL operation
    localparam OP_LOGIC   = 4'b0011;  // LOGIC operations: AND, OR, XOR, NOT (uses immediate field)
    localparam OP_RESERVED2 = 4'b0100; // Reserved (removed division for area)
    localparam OP_RESERVED = 4'b0101; // Reserved for future use
    localparam OP_SLL     = 4'b0110;  // Shift left logical
    localparam OP_SRL     = 4'b0111;  // Shift right logical
    localparam OP_SRA     = 4'b1000;  // Shift right arithmetic
    localparam OP_SLT     = 4'b1001;  // Set less than
    localparam OP_SLTU    = 4'b1010;  // Set less than unsigned
    localparam OP_LOAD    = 4'b1011;  // Load from memory
    localparam OP_STORE   = 4'b1100;  // Store to memory
    localparam OP_BRANCH  = 4'b1101;  // Branch (simplified)
    localparam OP_JAL     = 4'b1110;  // Jump and Link
    localparam OP_LUI     = 4'b1111;  // Load Upper Immediate

    // ALU operation mapping
    always @(*) begin
        // Default values
        alu_op = 5'b00000;
        reg_write_en = 1'b0;
        mem_read_en = 1'b0;
        mem_write_en = 1'b0;
        pc_sel = 2'b00;        // Normal PC increment
        reg_data_sel = 2'b00;  // ALU result

        case (opcode)
            OP_ADD: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                alu_op = 5'b00000;    // ADD
            end

            OP_SUB: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                alu_op = 5'b00001;    // SUB
            end

            OP_MUL: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                alu_op = 5'b01010;    // MUL
            end

            OP_LOGIC: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                case (funct2)
                    2'b00: alu_op = 5'b00010;    // AND
                    2'b01: alu_op = 5'b00011;    // OR
                    2'b10: alu_op = 5'b00100;    // XOR
                    2'b11: alu_op = 5'b01111;    // NOT (new ALU operation)
                endcase
            end

            OP_RESERVED2: begin
                // Reserved - removed division for area savings
            end

            OP_RESERVED: begin
                // Reserved - no operation
            end

            OP_SLL: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                alu_op = 5'b00111;    // SLL
            end

            OP_SRL: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                alu_op = 5'b01000;    // SRL
            end

            OP_SRA: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                alu_op = 5'b01001;    // SRA
            end

            OP_SLT: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                alu_op = 5'b00101;    // SLT
            end

            OP_SLTU: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b00; // ALU result
                alu_op = 5'b00110;    // SLTU
            end

            OP_LOAD: begin
                reg_write_en = 1'b1;
                mem_read_en = 1'b1;
                reg_data_sel = 2'b01; // Memory data
                alu_op = 5'b00000;    // ADD for address calculation
            end

            OP_STORE: begin
                mem_write_en = 1'b1;
                alu_op = 5'b00000;    // ADD for address calculation
            end

            OP_BRANCH: begin
                pc_sel = 2'b01;       // Branch
                alu_op = 5'b10000;    // BEQ (simplified)
            end

            OP_JAL: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b10; // PC + 1 (return address)
                pc_sel = 2'b10;       // Jump
            end

            OP_LUI: begin
                reg_write_en = 1'b1;
                reg_data_sel = 2'b11; // Immediate value
            end

            default: begin
                // NOP or invalid instruction
                alu_op = 5'b00000;
                reg_write_en = 1'b0;
            end
        endcase
    end

endmodule