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

    // Debug interface
    input  wire        debug_en,

    // Outputs
    output wire [15:0] pc_out,
    output wire [15:0] addr_out,      // 16-bit addressing for 64KB
    output wire        halt,
    output wire        valid
);

    // Optimized CPU state machine (fewer states)
    localparam STATE_FETCH       = 3'b000;  // Fetch instruction (combines fetch states)
    localparam STATE_DECODE      = 3'b001;  // Decode instruction
    localparam STATE_MEMORY      = 3'b010;  // Memory operation (combines mem states)
    localparam STATE_EXECUTE     = 3'b011;  // Execute instruction
    localparam STATE_WRITEBACK   = 3'b100;  // Write back results
    localparam STATE_HALT        = 3'b111;  // Halt state

    reg [2:0] state, next_state;  // Reduced from 4-bit to 3-bit

    // Internal registers and wires
    reg [15:0] pc;                    // 16-bit PC for 64KB addressing
    reg [31:0] instruction;
    reg [1:0] fetch_counter;          // Track which byte we're fetching
    reg [7:0] instruction_bytes [3:0]; // Buffer for instruction bytes
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
    wire jump_taken;

    // Optimized instruction decode (only extract needed bits)
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] rd     = instruction[9:7];    // Only 3 bits for 6 registers
    wire [2:0] funct3 = instruction[14:12];
    wire [2:0] rs1    = instruction[17:15];  // Only 3 bits for 6 registers
    wire [2:0] rs2    = instruction[22:20];  // Only 3 bits for 6 registers
    wire [6:0] funct7 = instruction[31:25];

    // Optimized shared immediate generation
    wire [11:0] imm_base = instruction[31:20];  // Base immediate bits
    wire [15:0] imm_i = {{4{instruction[31]}}, imm_base};
    wire [15:0] imm_s = {{4{instruction[31]}}, instruction[31:25], instruction[11:7]};
    wire [15:0] imm_b = {{4{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    wire [15:0] imm_j = {{4{instruction[31]}}, imm_base}; // Reuse base for J-type

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
            instruction <= 32'h0;
            fetch_counter <= 2'b00;
            i2c_start <= 1'b0;
            i2c_read_write <= 1'b1;  // Default to read
            i2c_address <= 16'h0000;
            i2c_write_data <= 8'h00;
            mem_data_out <= 16'h0000;
        end else begin
            state <= next_state;

            case (state)
                STATE_FETCH: begin
                    // Multi-byte I2C instruction fetch
                    if (!i2c_start) begin
                        // Start new I2C read for current byte
                        i2c_address <= instruction_addr;
                        i2c_read_write <= 1'b1;  // Read
                        i2c_start <= 1'b1;
                    end else begin
                        // Wait for I2C completion
                        if (i2c_ready && !i2c_error) begin
                            i2c_start <= 1'b0;
                            instruction_bytes[fetch_counter] <= i2c_read_data;

                            if (fetch_counter == 2'b11) begin
                                // Assemble complete 32-bit instruction
                                instruction <= {i2c_read_data, instruction_bytes[2],
                                              instruction_bytes[1], instruction_bytes[0]};
                                fetch_counter <= 2'b00;  // Reset for next instruction
                            end else begin
                                fetch_counter <= fetch_counter + 1;
                            end
                        end
                    end
                end

                STATE_MEMORY: begin
                    // Simplified memory access - handle load/store I2C operations
                    if (!i2c_start) begin
                        i2c_address <= data_addr;
                        i2c_read_write <= ~mem_write_en;  // 0=write, 1=read
                        i2c_write_data <= reg_data2[7:0];  // Use lower 8 bits for I2C
                        i2c_start <= 1'b1;
                    end else begin
                        i2c_start <= 1'b0;
                        if (i2c_ready && !i2c_error && mem_read_en) begin
                            mem_data_out <= {8'h00, i2c_read_data}; // Zero-extend 8-bit to 16-bit
                        end
                    end
                end

                STATE_WRITEBACK: begin
                    if (pc_sel == 2'b01 && branch_taken_alu) // Branch taken
                        pc <= pc + imm_b;
                    else if (pc_sel == 2'b10) // Jump
                        pc <= pc + imm_j;
                    else // Normal increment
                        pc <= pc + 16'd1;
                end

            endcase
        end
    end

    // Next state logic for simplified I2C memory operations
    always_comb begin
        case (state)
            STATE_FETCH: begin
                // Stay in fetch until all 4 instruction bytes are loaded
                if (fetch_counter == 2'b11 && i2c_ready && !i2c_error)
                    next_state = STATE_DECODE;
                else
                    next_state = STATE_FETCH;
            end

            STATE_DECODE: begin
                // Check if instruction needs memory access
                if ((opcode == 7'b0000011) || (opcode == 7'b0100011)) // Load/Store
                    next_state = STATE_MEMORY;
                else
                    next_state = STATE_EXECUTE;
            end

            STATE_MEMORY: begin
                // Wait for I2C memory operation to complete
                if (i2c_ready && !i2c_error)
                    next_state = STATE_EXECUTE;
                else
                    next_state = STATE_MEMORY;
            end

            STATE_EXECUTE: next_state = STATE_WRITEBACK;

            STATE_WRITEBACK: begin
                if (instruction == 32'h00000000)  // NOP instruction = halt
                    next_state = STATE_HALT;
                else
                    next_state = STATE_FETCH;
            end

            STATE_HALT: next_state = STATE_HALT;
            default: next_state = STATE_FETCH;
        endcase
    end

    // I2C controller for external EEPROM (configurable)
    i2c_controller #(
        .DEVICE_ADDR(7'b1010_000),  // 24LC512 family (0x50)
        .ADDR_BITS(16),             // 16-bit addressing for 64KB
        .CLK_DIV(100)               // 100kHz I2C from 10MHz system clock
    ) i2c_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .start(i2c_start),
        .read_write(i2c_read_write),
        .address({1'b0, i2c_address}),  // Extend to 17-bit
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

    wire mul_busy;

    alu alu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .a(rs1_data),  // Use correct source register value
        .b(alu_b),
        .alu_op(alu_op),
        .result(alu_out),
        .zero_flag(branch_taken_alu),
        .mul_busy(mul_busy)
    );

    control_unit ctrl (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .alu_op(alu_op),
        .reg_write_en(reg_write_en),
        .mem_read_en(mem_read_en),
        .mem_write_en(mem_write_en),
        .pc_sel(pc_sel),
        .reg_data_sel(reg_data_sel),
        .jump_taken(jump_taken)
    );

    // Output assignments
    assign pc_out = pc;               // Full 16-bit PC for debug
    assign addr_out = i2c_address;    // Current I2C address
    assign halt = (state == STATE_HALT);
    assign valid = (state == STATE_WRITEBACK);

endmodule