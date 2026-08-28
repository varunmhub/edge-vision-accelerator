`timescale 1ns / 1ps
// 115200 8N1 transmitter. Pulse `send` when `busy` is low.
module uart_tx #(
    parameter integer CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       send,
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
            tx      <= 1'b1;      // idle line is high
            busy    <= 1'b0;
            cnt     <= 16'd0;
            bit_idx <= 3'd0;
            sh      <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx      <= 1'b1;
                    busy    <= 1'b0;
                    cnt     <= 16'd0;
                    bit_idx <= 3'd0;
                    if (send) begin
                        sh    <= byte_in;
                        busy  <= 1'b1;
                        state <= S_START;
                    end
                end

                S_START: begin
                    tx <= 1'b0;
                    if (cnt == CLKS_PER_BIT-1) begin cnt <= 16'd0; state <= S_DATA; end
                    else                            cnt <= cnt + 16'd1;
                end

                S_DATA: begin
                    tx <= sh[0];                              // LSB first
                    if (cnt == CLKS_PER_BIT-1) begin
                        cnt <= 16'd0;
                        sh  <= {1'b0, sh[7:1]};
                        if (bit_idx == 3'd7) state   <= S_STOP;
                        else                 bit_idx <= bit_idx + 3'd1;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end

                S_STOP: begin
                    tx <= 1'b1;
                    if (cnt == CLKS_PER_BIT-1) begin
                        cnt   <= 16'd0;
                        busy  <= 1'b0;
                        state <= S_IDLE;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end
            endcase
        end
    end
endmodule
