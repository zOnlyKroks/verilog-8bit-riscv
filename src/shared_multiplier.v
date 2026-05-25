/*
 * Simple Multiplier for RISC-V CPU
 * Implements basic multiplication without shared circuits for now
 * Copyright (c) 2024 Finn Rades (zOnlyKroks)
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module shared_multiplier (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,        // Start multiplication
    input  wire [15:0] a,           // Multiplicand
    input  wire [15:0] b,           // Multiplier
    input  wire        high_result, // 1=return high 16 bits, 0=return low 16 bits

    output reg  [15:0] result,      // Multiplication result
    output reg         done,        // Multiplication complete

    // Shared resource interfaces (unused for now)
    output wire [15:0] alu_a,       // ALU input A
    output wire [15:0] alu_b,       // ALU input B
    output wire        alu_add,     // ALU operation (1=add, 0=sub)
    input  wire [15:0] alu_result,  // ALU result

    output wire [15:0] shift_data,  // Shifter input
    output wire [3:0]  shift_amount,// Shift amount
    output wire        shift_left,  // Shift direction
    input  wire [15:0] shift_result // Shifter result
);

    // Sequential multiplier state machine
    localparam IDLE = 2'b00;
    localparam MULTIPLY = 2'b01;
    localparam DONE_STATE = 2'b10;

    reg [1:0] state, next_state;
    reg [31:0] accumulator;
    reg [15:0] multiplicand, multiplier;
    reg [4:0] counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'h0000;
            accumulator <= 32'h00000000;
            multiplicand <= 16'h0000;
            multiplier <= 16'h0000;
            counter <= 5'h00;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        accumulator <= 32'h00000000;
                        multiplicand <= a;
                        multiplier <= b;
                        counter <= 5'd16;
                    end
                end

                MULTIPLY: begin
                    if (counter == 0) begin
                        result <= high_result ? accumulator[31:16] : accumulator[15:0];
                    end else begin
                        if (multiplier[0]) begin
                            accumulator <= accumulator + {16'h0000, multiplicand};
                        end
                        multiplier <= multiplier >> 1;
                        multiplicand <= multiplicand << 1;
                        counter <= counter - 1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = MULTIPLY;
            MULTIPLY: if (counter == 0) next_state = DONE_STATE;
            DONE_STATE: if (!start) next_state = IDLE;
        endcase
    end

    // Tie off unused shared resource interfaces
    assign alu_a = 16'h0000;
    assign alu_b = 16'h0000;
    assign alu_add = 1'b0;
    assign shift_data = 16'h0000;
    assign shift_amount = 4'h0;
    assign shift_left = 1'b0;

endmodule