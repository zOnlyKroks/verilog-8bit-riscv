/*
 * 16-bit RISC-V CPU Core
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module riscv_cpu (
    input  wire        clk,
    input  wire        rst_n,

    // I2C interface to external EEPROM
    inout  wire        sda,
    output wire        scl,

    // Debug interface (removed for area optimization)
    // input  wire        debug_en,

    // Outputs
    output wire [15:0] pc_out,
    output wire [15:0] addr_out,      // 16-bit addressing for 64KB
    output wire        halt,
    output wire        valid
);

    // Ultra-simplified CPU state machine
    localparam STATE_FETCH       = 2'b00;   // Fetch instruction
    localparam STATE_EXECUTE     = 2'b01;   // Decode + Execute + Memory
    localparam STATE_WRITEBACK   = 2'b10;   // Write back results
    localparam STATE_HALT        = 2'b11;   // Halt state

    reg [1:0] state, next_state;  // Reduced to 2-bit for ultra-simple states

    // Internal registers and wires
    reg [15:0] pc;                    // 16-bit PC for 64KB addressing
    reg [15:0] instruction;           // 16-bit instructions for area efficiency
    reg [0:0] fetch_counter;          // Track which byte (0 or 1)
    reg [7:0] instruction_bytes [1:0]; // Buffer for 2 instruction bytes
    wire [15:0] alu_out;
    wire [15:0] reg_data1, reg_data2;

    // I2C controller interface
    reg        i2c_start;
    reg        i2c_read_write;        // 0=write, 1=read
    reg [15:0] i2c_address;
    reg [7:0]  i2c_write_data;
    wire [7:0] i2c_read_data;
    wire       i2c_ready;
    wire       i2c_error;

    // Control signals
    wire [4:0] alu_op;
    wire reg_write_en;
    wire mem_read_en, mem_write_en;
    wire [1:0] pc_sel;
    wire [1:0] reg_data_sel;
    wire branch_taken_alu;
    // wire jump_taken; // Removed unused signal

    // Compact 16-bit instruction decode
    wire [3:0] opcode = instruction[15:12];  // 4-bit opcode (16 operations)
    wire [2:0] rd     = instruction[11:9];   // 3 bits for 6 registers
    wire [2:0] rs1    = instruction[8:6];    // 3 bits for 6 registers
    wire [2:0] rs2    = instruction[5:3];    // 3 bits for 6 registers
    wire [2:0] funct3 = instruction[2:0];    // 3-bit function code

    // Compact immediate generation for 16-bit instructions
    wire [5:0] imm_base = instruction[5:0];     // 6-bit immediate from rs2+funct3 fields
    wire [15:0] imm_i = {{10{imm_base[5]}}, imm_base}; // Sign-extend 6-bit immediate
    wire [15:0] imm_s = imm_i;                  // Same encoding for stores
    wire [15:0] imm_b = {{9{imm_base[5]}}, imm_base, 1'b0}; // Branch offset
    wire [15:0] imm_j = {{8{imm_base[5]}}, imm_base, 2'b00}; // Jump offset

    // Memory mapping for 64KB EEPROM
    // 0x0000-0x7FFF: Instruction memory (32KB)
    // 0x8000-0xFFFF: Data memory (32KB)
    wire [15:0] instruction_addr = (pc << 2) + {14'b0, fetch_counter};
    wire [15:0] data_addr = 16'h8000 + alu_out[15:0]; // Data in upper 32KB

    // Memory data output from I2C (16-bit value assembled from bytes)
    reg [15:0] mem_data_out;

    // State machine with I2C memory interface
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_FETCH;
            pc <= 16'h0000;
            instruction <= 16'h0000;
            fetch_counter <= 1'b0;
            i2c_start <= 1'b0;
            i2c_read_write <= 1'b1;  // Default to read
            i2c_address <= 16'h0000;
            i2c_write_data <= 8'h00;
            mem_data_out <= 16'h0000;
        end else begin
            state <= next_state;

            case (state)
                STATE_FETCH: begin
                    // Efficient 16-bit instruction fetch (2 bytes)
                    if (!i2c_start) begin
                        i2c_address <= (pc << 1) + fetch_counter;  // Byte address for 16-bit words
                        i2c_read_write <= 1'b1;    // Read
                        i2c_start <= 1'b1;
                    end else if (i2c_ready && !i2c_error) begin
                        i2c_start <= 1'b0;
                        instruction_bytes[fetch_counter] <= i2c_read_data;

                        if (fetch_counter == 1'b1) begin
                            // Assemble complete 16-bit instruction
                            instruction <= {i2c_read_data, instruction_bytes[0]};
                            fetch_counter <= 1'b0;
                        end else begin
                            fetch_counter <= fetch_counter + 1;
                        end
                    end
                end

                STATE_EXECUTE: begin
                    // Combined decode/execute/memory
                    if ((opcode == 4'b0010) && !i2c_start) begin // Load
                        i2c_address <= 16'h8000 + alu_out[15:0];
                        i2c_read_write <= 1'b1;
                        i2c_start <= 1'b1;
                    end else if (i2c_ready && !i2c_error && mem_read_en) begin
                        i2c_start <= 1'b0;
                        mem_data_out <= {8'h00, i2c_read_data};
                    end
                end

                STATE_WRITEBACK: begin
                    // Update PC
                    pc <= pc + 16'd1;  // Simple increment
                end

                default: begin
                    // Handle undefined states
                end

            endcase
        end
    end

    // Functional next state logic
    always_comb begin
        case (state)
            STATE_FETCH: begin
                if (i2c_ready && !i2c_error)
                    next_state = STATE_EXECUTE;
                else
                    next_state = STATE_FETCH;
            end

            STATE_EXECUTE: begin
                if ((opcode == 4'b0010) && !i2c_ready) // Load waiting
                    next_state = STATE_EXECUTE;
                else
                    next_state = STATE_WRITEBACK;
            end

            STATE_WRITEBACK: begin
                if (instruction == 16'h0000)  // NOP = halt
                    next_state = STATE_HALT;
                else
                    next_state = STATE_FETCH;
            end

            STATE_HALT: next_state = STATE_HALT;

            default: next_state = STATE_FETCH;
        endcase
    end

    // I2C controller for external EEPROM (simplified)
    i2c_controller #(
        .DEVICE_ADDR(7'b1010_000),  // 24LC512 family (0x50)
        .CLK_DIV(100)               // 100kHz I2C from 10MHz system clock
    ) i2c_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .start(i2c_start),
        .read_write(i2c_read_write),
        .address(i2c_address),      // Direct 16-bit address
        .write_data(i2c_write_data),
        .read_data(i2c_read_data),
        .ready(i2c_ready),
        .error(i2c_error),
        .sda(sda),
        .scl(scl)
    );

    register_file regfile (
        .clk(clk),
        .rst_n(rst_n),
        .read_addr1(rs1),      // Source register 1 (already 3-bit)
        .read_addr2(rs2),      // Source register 2 (already 3-bit)
        .write_addr(rd),       // Destination register (already 3-bit)
        .write_data(reg_data_sel == 2'b00 ? alu_out :
                   reg_data_sel == 2'b01 ? mem_data_out :
                   reg_data_sel == 2'b10 ? pc + 16'd1 :
                   reg_data_sel == 2'b11 ? imm_i : alu_out),
        .write_enable(reg_write_en && (state == STATE_WRITEBACK)),
        .data_out1(reg_data1), // rs1 data for ALU
        .data_out2(reg_data2)  // rs2 data for ALU
    );

    // ALU input mux
    reg [15:0] alu_b;
    always @(*) begin
        case (opcode)
            7'b0010011: alu_b = imm_i;        // I-type uses immediate
            7'b0000011: alu_b = imm_i;        // Load uses immediate
            7'b0100011: alu_b = imm_s;        // Store uses immediate
            default:    alu_b = reg_data2;    // R-type uses register
        endcase
    end

    // rs1 data is now available directly from register file
    wire [15:0] rs1_data = reg_data1;

    // wire mul_busy; // Removed unused signal

    alu alu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .a(rs1_data),  // Use correct source register value
        .b(alu_b),
        .alu_op(alu_op),
        .result(alu_out),
        .zero_flag(branch_taken_alu)
        // .mul_busy(mul_busy) // Removed unused signal
    );

    control_unit ctrl (
        .opcode(opcode),
        .funct3(funct3),
        .alu_op(alu_op),
        .reg_write_en(reg_write_en),
        .mem_read_en(mem_read_en),
        .mem_write_en(mem_write_en),
        .pc_sel(pc_sel),
        .reg_data_sel(reg_data_sel)
        // .jump_taken(jump_taken) // Removed unused signal
    );

    // Output assignments
    assign pc_out = pc;               // Full 16-bit PC for debug
    assign addr_out = i2c_address;    // Current I2C address
    assign halt = (state == STATE_HALT);
    assign valid = (state == STATE_WRITEBACK);

endmodule