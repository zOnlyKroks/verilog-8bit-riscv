/*
 * 8-bit RISC-V CPU Core
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module riscv_cpu (
    input  wire        clk,
    input  wire        rst_n,

    // Programming interface
    input  wire        prog_mode,
    input  wire [3:0]  prog_data,
    input  wire        prog_clk,

    // Debug interface
    input  wire        debug_en,
    input  wire        step_mode,

    // Outputs
    output wire [7:0]  pc_out,
    output wire [7:0]  reg_out,
    output wire [7:0]  data_bus_out,
    output wire [7:0]  addr_out,
    output wire        halt,
    output wire        valid
);

    // CPU state machine states
    localparam STATE_FETCH_0   = 3'b000;
    localparam STATE_FETCH_1   = 3'b001;
    localparam STATE_FETCH_2   = 3'b010;
    localparam STATE_FETCH_3   = 3'b011;
    localparam STATE_DECODE    = 3'b100;
    localparam STATE_EXECUTE   = 3'b101;
    localparam STATE_WRITEBACK = 3'b110;
    localparam STATE_HALT      = 3'b111;

    reg [2:0] state, next_state;

    // Internal registers and wires
    reg [7:0] pc;
    reg [31:0] instruction;
    reg [31:0] instruction_next;
    reg [1:0] fetch_counter; // Track which byte we're fetching
    wire [7:0] instr_data;
    wire [7:0] alu_out;
    wire [7:0] reg_data1, reg_data2;
    wire [7:0] mem_data_out;

    // Control signals
    wire [3:0] alu_op;
    wire reg_write_en;
    wire mem_read_en, mem_write_en;
    wire [1:0] pc_sel;
    wire [1:0] reg_data_sel;
    wire branch_taken_alu;
    wire jump_taken;

    // Instruction decode
    wire [6:0] opcode = instruction[6:0];
    wire [4:0] rd     = instruction[11:7];
    wire [2:0] funct3 = instruction[14:12];
    wire [4:0] rs1    = instruction[19:15];
    wire [4:0] rs2    = instruction[24:20];
    wire [6:0] funct7 = instruction[31:25];

    // Immediate generation (simplified for 8-bit)
    wire [7:0] imm_i = instruction[19:12];  // I-type immediate (8-bit)
    wire [7:0] imm_s = {instruction[31:25], instruction[11:7]}; // S-type
    wire [7:0] imm_b = {instruction[31], instruction[7], instruction[30:25], instruction[11:8]}; // B-type
    wire [7:0] imm_j = instruction[19:12]; // J-type (simplified)

    // Data memory (simple 64-byte RAM)
    reg [7:0] data_memory [63:0];
    wire [7:0] mem_addr = alu_out & 8'h3F; // Limit to 64 bytes

    // Memory read/write logic
    assign mem_data_out = data_memory[mem_addr];

    always_ff @(posedge clk) begin
        if (mem_write_en && state == STATE_EXECUTE) begin
            data_memory[mem_addr] <= reg_data2;
        end
    end

    // Calculate effective address for instruction fetch
    wire [7:0] fetch_addr = (pc << 2) + fetch_counter;

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_FETCH_0;
            pc <= 8'h00;
            instruction <= 32'h0;
            fetch_counter <= 2'b00;
        end else if (!prog_mode) begin
            state <= next_state;

            case (state)
                STATE_FETCH_0: begin
                    fetch_counter <= 2'b00;
                    instruction_next[7:0] <= instr_data;
                end
                STATE_FETCH_1: begin
                    fetch_counter <= 2'b01;
                    instruction_next[15:8] <= instr_data;
                end
                STATE_FETCH_2: begin
                    fetch_counter <= 2'b10;
                    instruction_next[23:16] <= instr_data;
                end
                STATE_FETCH_3: begin
                    fetch_counter <= 2'b11;
                    instruction_next[31:24] <= instr_data;
                    instruction <= {instr_data, instruction_next[23:0]};
                end
                STATE_WRITEBACK: begin
                    if (pc_sel == 2'b01 && branch_taken_alu) // Branch taken
                        pc <= pc + {{4{imm_b[7]}}, imm_b[7:2]}; // Sign extend and word align
                    else if (pc_sel == 2'b10) // Jump
                        pc <= pc + {{4{imm_j[7]}}, imm_j[7:2]}; // Sign extend and word align
                    else // Normal increment
                        pc <= pc + 1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            STATE_FETCH_0: next_state = step_mode ? state : STATE_FETCH_1;
            STATE_FETCH_1: next_state = STATE_FETCH_2;
            STATE_FETCH_2: next_state = STATE_FETCH_3;
            STATE_FETCH_3: next_state = STATE_DECODE;
            STATE_DECODE:  next_state = STATE_EXECUTE;
            STATE_EXECUTE: next_state = STATE_WRITEBACK;
            STATE_WRITEBACK: begin
                // Only halt on explicit halt instruction (all zeros)
                if (instruction == 32'h00000000)
                    next_state = STATE_HALT;
                else
                    next_state = STATE_FETCH_0;
            end
            STATE_HALT: next_state = STATE_HALT;
            default: next_state = STATE_FETCH_0;
        endcase
    end

    // Component instances
    instruction_memory imem (
        .clk(clk),
        .rst_n(rst_n),
        .addr(fetch_addr),
        .prog_mode(prog_mode),
        .prog_data(prog_data),
        .prog_clk(prog_clk),
        .data_out(instr_data)
    );

    register_file regfile (
        .clk(clk),
        .rst_n(rst_n),
        .read_addr1(rs1[3:0]), // Only use lower 4 bits (16 registers)
        .read_addr2(rs2[3:0]),
        .write_addr(rd[3:0]),
        .write_data(reg_data_sel == 2'b00 ? alu_out :
                   reg_data_sel == 2'b01 ? mem_data_out :
                   reg_data_sel == 2'b10 ? (pc + 8'd1) :
                   reg_data_sel == 2'b11 ? imm_i : alu_out),
        .write_enable(reg_write_en && (state == STATE_WRITEBACK)),
        .data_out1(reg_data1),
        .data_out2(reg_data2)
    );

    // ALU input mux
    reg [7:0] alu_b;
    always @(*) begin
        case (opcode)
            7'b0010011: alu_b = imm_i;        // I-type uses immediate
            7'b0000011: alu_b = imm_i;        // Load uses immediate
            7'b0100011: alu_b = imm_s;        // Store uses immediate
            default:    alu_b = reg_data2;    // R-type uses register
        endcase
    end

    alu alu_inst (
        .a(reg_data1),
        .b(alu_b),
        .alu_op(alu_op),
        .result(alu_out),
        .zero_flag(branch_taken_alu)
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
        .branch_taken(branch_taken_alu),
        .jump_taken(jump_taken)
    );

    // Output assignments
    assign pc_out = pc;
    assign reg_out = debug_en ? reg_data1 : reg_data2;
    assign data_bus_out = reg_data2;
    assign addr_out = alu_out;
    assign halt = (state == STATE_HALT);
    assign valid = (state == STATE_WRITEBACK);

endmodule