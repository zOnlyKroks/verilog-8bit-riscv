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
    wire debug_en = ui_in[0];

    // Internal CPU signals
    wire [7:0] pc;
    wire [7:0] reg_out;
    wire [15:0] addr_out;
    wire cpu_halt;
    wire output_valid;

    // I2C signals
    wire scl_out;
    wire sda_io;

    // CPU reset (active low, synchronized)
    wire cpu_rst_n = rst_n & ena;

    // 8-bit RISC-V CPU with external EEPROM interface
    riscv_cpu cpu (
        .clk(clk),
        .rst_n(cpu_rst_n),
        .sda(sda_io),
        .scl(scl_out),
        .debug_en(debug_en),
        .pc_out(pc),
        .reg_out(reg_out),
        .addr_out(addr_out),
        .halt(cpu_halt),
        .valid(output_valid)
    );

    // Output assignments
    assign uo_out[3:0] = pc[3:0];           // Program Counter lower 4 bits
    assign uo_out[7:4] = addr_out[3:0];     // EEPROM address lower 4 bits

    // I2C pin assignments
    assign uio_out[0] = scl_out;            // I2C Clock (SCL)
    assign sda_io = uio_in[1];              // I2C Data (SDA) - bidirectional
    assign uio_out[1] = 1'bz;               // SDA tristated when input

    // Debug outputs
    assign uio_out[3:2] = addr_out[15:14];  // Address high bits
    assign uio_out[5:4] = pc[7:6];          // PC high bits
    assign uio_out[6] = cpu_halt;           // Halt signal
    assign uio_out[7] = output_valid;       // Valid signal

    // I/O enable configuration
    assign uio_oe[0] = 1'b1;                // SCL is output
    assign uio_oe[1] = 1'b0;                // SDA is input (tristated for bidirectional)
    assign uio_oe[7:2] = 6'b111111;         // Debug outputs are outputs

endmodule
