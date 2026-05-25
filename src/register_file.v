/*
 * 8-bit Register File for RISC-V CPU
 * 8 registers (x0-x7) - good balance of functionality and area
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  read_addr1,   // Read port 1 address (rs1) - 2 bits for 3 regs
    input  wire [1:0]  read_addr2,   // Read port 2 address (rs2) - 2 bits for 3 regs
    input  wire [1:0]  write_addr,   // Write port address (rd) - 2 bits for 3 regs
    input  wire [7:0]  write_data,   // Write data
    input  wire        write_enable, // Write enable
    output wire [7:0]  data_out1,    // Read port 1 data
    output wire [7:0]  data_out2     // Read port 2 data
);

    // Register array: 3 x 8-bit registers (x0, x1, x2)
    reg [7:0] registers [2:0];

    // Initialize registers
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 3; i = i + 1) begin
                registers[i] <= 8'h00;
            end
        end else if (write_enable && write_addr != 2'h0 && write_addr <= 2'h2) begin
            // Don't write to register x0 (always zero in RISC-V) and only write to valid registers
            registers[write_addr] <= write_data;
        end
    end

    // Read ports (combinatorial) - handle addresses > 2 as zero
    assign data_out1 = (read_addr1 == 2'h0 || read_addr1 > 2'h2) ? 8'h00 : registers[read_addr1];
    assign data_out2 = (read_addr2 == 2'h0 || read_addr2 > 2'h2) ? 8'h00 : registers[read_addr2];

endmodule