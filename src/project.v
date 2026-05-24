/*
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// TinyTapeout wrapper for 8-bit RISC-V processor
module tt_um_zonlykroks_8bit_riscv (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Input signal assignments
    wire prog_mode = ui_in[0];
    wire debug_en  = ui_in[1];
    wire step_mode = ui_in[2];
    wire [3:0] prog_data = ui_in[6:3];
    wire prog_clk = ui_in[7];

    // Internal CPU signals
    wire [7:0] pc;
    wire [7:0] reg_out;
    wire [7:0] data_bus_out;
    wire [7:0] addr_out;
    wire cpu_halt;
    wire output_valid;

    // CPU reset (active low, synchronized)
    wire cpu_rst_n = rst_n & ena;

    // 8-bit RISC-V CPU instance
    riscv_cpu cpu (
        .clk(clk),
        .rst_n(cpu_rst_n),
        .prog_mode(prog_mode),
        .prog_data(prog_data),
        .prog_clk(prog_clk),
        .debug_en(debug_en),
        .pc_out(pc),
        .reg_out(reg_out),
        .data_bus_out(data_bus_out),
        .addr_out(addr_out),
        .halt(cpu_halt),
        .valid(output_valid)
    );

    // Output assignments
    assign uo_out[3:0] = pc[3:0];           // Program Counter lower 4 bits
    assign uo_out[7:4] = reg_out[3:0];      // Register output lower 4 bits

    // Bidirectional I/O assignments
    assign uio_out[3:0] = data_bus_out[3:0]; // Data bus output
    assign uio_out[5:4] = addr_out[1:0];     // Address output (2 bits)
    assign uio_out[6] = cpu_halt;            // Halt signal
    assign uio_out[7] = output_valid;        // Valid signal

    // I/O enable - all bidirectional pins are outputs
    assign uio_oe = 8'hFF;

endmodule
