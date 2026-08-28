`timescale 1ns/1ps
// 115200 8N1 transmitter, matching uart_rx. Idle line is high.
module uart_tx #(
    parameter integer CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       send,        // accepted only while busy == 0
    input  wire [7:0] byte_in,
    output reg        tx,
    output reg        busy
);
    localparam S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;

    reg [1:0]  state;
    reg [15:0] cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  sh;

    always @(posedge clk) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            cnt     <= 16'd0;
            bit_idx <= 3'd0;
            sh      <= 8'd0;
            tx      <= 1'b1;          // idle high
            busy    <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx  <= 1'b1;
                    cnt <= 16'd0;
                    if (send) begin
                        sh      <= byte_in;
                        bit_idx <= 3'd0;
                        busy    <= 1'b1;
                        state   <= S_START;
                    end else begin
                        busy <= 1'b0;
                    end
                end

                S_START: begin
                    tx <= 1'b0;                    // start bit
                    if (cnt < CLKS_PER_BIT-1) begin
                        cnt <= cnt + 16'd1;
                    end else begin
                        cnt   <= 16'd0;
                        state <= S_DATA;
                    end
                end

                S_DATA: begin
                    tx <= sh[0];                   // LSB first
                    if (cnt < CLKS_PER_BIT-1) begin
                        cnt <= cnt + 16'd1;
                    end else begin
                        cnt <= 16'd0;
                        sh  <= {1'b0, sh[7:1]};
                        if (bit_idx == 3'd7) state   <= S_STOP;
                        else                 bit_idx <= bit_idx + 3'd1;
                    end
                end

                S_STOP: begin
                    tx <= 1'b1;                    // stop bit
                    if (cnt < CLKS_PER_BIT-1) begin
                        cnt <= cnt + 16'd1;
                    end else begin
                        cnt   <= 16'd0;
                        busy  <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
