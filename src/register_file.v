/*
 * 8-bit Register File for RISC-V CPU
 * 16 registers (x0-x15) to save area compared to full 32-register implementation
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  read_addr1,   // Read port 1 address (rs1)
    input  wire [3:0]  read_addr2,   // Read port 2 address (rs2)
    input  wire [3:0]  write_addr,   // Write port address (rd)
    input  wire [7:0]  write_data,   // Write data
    input  wire        write_enable, // Write enable
    output wire [7:0]  data_out1,    // Read port 1 data
    output wire [7:0]  data_out2     // Read port 2 data
);

    // Register array: 16 x 8-bit registers
    reg [7:0] registers [15:0];

    // Initialize registers
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                registers[i] <= 8'h00;
            end
        end else if (write_enable && write_addr != 4'h0) begin
            // Don't write to register x0 (always zero in RISC-V)
            registers[write_addr] <= write_data;
        end
    end

    // Read ports (combinatorial)
    assign data_out1 = (read_addr1 == 4'h0) ? 8'h00 : registers[read_addr1];
    assign data_out2 = (read_addr2 == 4'h0) ? 8'h00 : registers[read_addr2];

endmodule