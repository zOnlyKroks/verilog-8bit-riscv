/*
 * Simple I2C Master Controller for EEPROM Interface
 * Supports basic read/write operations for 24LC512 EEPROM
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module i2c_controller #(
    parameter DEVICE_ADDR = 7'b1010_000,  // 0x50 for 24LCxxx family
    parameter CLK_DIV     = 100           // Clock divider for I2C timing
)(
    input  wire        clk,
    input  wire        rst_n,

    // Control interface
    input  wire        start,          // Start I2C transaction
    input  wire        read_write,     // 0=write, 1=read
    input  wire [15:0] address,        // EEPROM address (16-bit)
    input  wire [7:0]  write_data,     // Data to write
    output reg  [7:0]  read_data,      // Data read from EEPROM
    output reg         ready,          // Transaction complete
    output reg         error,          // Error flag

    // I2C bus
    inout  wire        sda,            // I2C data line
    output reg         scl             // I2C clock line
);

    // I2C state machine
    localparam IDLE       = 4'b0000;
    localparam START_BIT  = 4'b0001;
    localparam DEV_ADDR   = 4'b0010;
    localparam ADDR_HIGH  = 4'b0011;
    localparam ADDR_LOW   = 4'b0100;
    localparam WRITE_DATA = 4'b0101;
    localparam RESTART    = 4'b0110;
    localparam READ_ADDR  = 4'b0111;
    localparam READ_DATA  = 4'b1000;
    localparam STOP_BIT   = 4'b1001;
    localparam ACK_CHECK  = 4'b1010;

    reg [3:0] state, next_state;
    reg [7:0] shift_reg;
    reg [3:0] bit_count;
    reg [7:0] clock_div;
    reg       sda_out, sda_oe;
    reg       ack_received;

    // I2C clock generation (parameterized for different system clocks)
    wire i2c_clk = (clock_div == (CLK_DIV/2 - 1));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clock_div <= 8'd0;
        end else begin
            clock_div <= (clock_div == (CLK_DIV - 1)) ? 8'd0 : clock_div + 1;
        end
    end

    // Simplified address handling (fixed 16-bit for our use case)
    wire [7:0] addr_high = address[15:8];
    wire [7:0] addr_low = address[7:0];

    // SDA tristate control
    assign sda = sda_oe ? sda_out : 1'bz;

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            scl <= 1'b1;
            sda_out <= 1'b1;
            sda_oe <= 1'b0;
            ready <= 1'b1;
            error <= 1'b0;
            bit_count <= 4'd0;
            shift_reg <= 8'd0;
            read_data <= 8'd0;
            ack_received <= 1'b0;
        end else if (i2c_clk) begin
            state <= next_state;

            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    error <= 1'b0;
                    scl <= 1'b1;
                    sda_out <= 1'b1;
                    sda_oe <= 1'b0;
                    if (start) begin
                        ready <= 1'b0;
                    end
                end

                START_BIT: begin
                    sda_oe <= 1'b1;
                    sda_out <= 1'b0;  // START condition
                    scl <= 1'b1;
                    shift_reg <= {DEVICE_ADDR, 1'b0}; // Device addr + write
                    bit_count <= 4'd8;
                end

                DEV_ADDR: begin
                    scl <= ~scl;
                    if (!scl) begin  // Clock low, setup data
                        sda_out <= shift_reg[7];
                        shift_reg <= shift_reg << 1;
                        bit_count <= bit_count - 1;
                    end
                end

                ACK_CHECK: begin
                    scl <= ~scl;
                    if (!scl) begin
                        sda_oe <= 1'b0;  // Release SDA for ACK
                    end else begin
                        ack_received <= !sda;  // Sample ACK
                        sda_oe <= 1'b1;
                    end
                end

                ADDR_HIGH: begin
                    scl <= ~scl;
                    if (!scl) begin
                        sda_out <= shift_reg[7];
                        shift_reg <= shift_reg << 1;
                        bit_count <= bit_count - 1;
                    end
                end

                ADDR_LOW: begin
                    scl <= ~scl;
                    if (!scl) begin
                        sda_out <= shift_reg[7];
                        shift_reg <= shift_reg << 1;
                        bit_count <= bit_count - 1;
                    end
                end

                WRITE_DATA: begin
                    scl <= ~scl;
                    if (!scl) begin
                        sda_out <= shift_reg[7];
                        shift_reg <= shift_reg << 1;
                        bit_count <= bit_count - 1;
                    end
                end

                RESTART: begin
                    sda_out <= 1'b1;
                    scl <= 1'b1;
                    sda_out <= 1'b0;  // Restart condition
                    shift_reg <= {DEVICE_ADDR, 1'b1}; // Device addr + read
                    bit_count <= 4'd8;
                end

                READ_ADDR: begin
                    scl <= ~scl;
                    if (!scl) begin
                        sda_out <= shift_reg[7];
                        shift_reg <= shift_reg << 1;
                        bit_count <= bit_count - 1;
                    end
                end

                READ_DATA: begin
                    scl <= ~scl;
                    if (!scl) begin
                        sda_oe <= 1'b0;  // Release for read
                    end else begin
                        shift_reg <= {shift_reg[6:0], sda};
                        bit_count <= bit_count - 1;
                    end
                end

                STOP_BIT: begin
                    scl <= 1'b1;
                    sda_oe <= 1'b1;
                    sda_out <= 1'b1;  // STOP condition
                    read_data <= shift_reg;
                end

            endcase
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start) next_state = START_BIT;
            end

            START_BIT: next_state = DEV_ADDR;

            DEV_ADDR: begin
                if (bit_count == 0) next_state = ACK_CHECK;
            end

            ACK_CHECK: begin
                if (scl && ack_received) begin
                    if (state == DEV_ADDR) begin
                        next_state = ADDR_HIGH;
                        // Setup address high byte
                    end else begin
                        next_state = (read_write) ? READ_DATA : STOP_BIT;
                    end
                end else if (scl && !ack_received) begin
                    next_state = STOP_BIT;  // Error - no ACK
                end
            end

            ADDR_HIGH: begin
                if (bit_count == 0) next_state = ACK_CHECK;
            end

            ADDR_LOW: begin
                if (bit_count == 0) begin
                    next_state = read_write ? RESTART : WRITE_DATA;
                end
            end

            WRITE_DATA: begin
                if (bit_count == 0) next_state = ACK_CHECK;
            end

            RESTART: next_state = READ_ADDR;

            READ_ADDR: begin
                if (bit_count == 0) next_state = ACK_CHECK;
            end

            READ_DATA: begin
                if (bit_count == 0) next_state = STOP_BIT;
            end

            STOP_BIT: next_state = IDLE;

        endcase
    end

endmodule