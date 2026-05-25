/*
 * 16-bit Register File for RISC-V CPU
 * 8 registers (x0-x7) - full 3-bit address space utilization
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [2:0]  read_addr1,   // Read port 1 address (rs1) - 3 bits, 6 used
    input  wire [2:0]  read_addr2,   // Read port 2 address (rs2) - 3 bits, 6 used
    input  wire [2:0]  write_addr,   // Write port address (rd) - 3 bits, 6 used
    input  wire [15:0] write_data,   // Write data
    input  wire        write_enable, // Write enable
    output wire [15:0] data_out1,    // Read port 1 data
    output wire [15:0] data_out2     // Read port 2 data
);

    // Register array: 8 x 16-bit registers (x0-x7)
    reg [15:0] registers [7:0];

    // Initialize registers
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                registers[i] <= 16'h0000;
            end
        end else if (write_enable && write_addr != 3'h0) begin
            // Don't write to register x0 (always zero in RISC-V) and only write to valid registers (x0-x7)
            registers[write_addr] <= write_data;
        end
    end

    // Read ports (combinatorial) - x0 always reads as zero
    assign data_out1 = (read_addr1 == 3'h0) ? 16'h0000 : registers[read_addr1];
    assign data_out2 = (read_addr2 == 3'h0) ? 16'h0000 : registers[read_addr2];

endmodule