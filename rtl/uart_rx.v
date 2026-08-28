`timescale 1ns / 1ps
// 115200 8N1 receiver. 100 MHz / 115200 = 868 clocks per bit.
// One received byte = one 8-bit pixel.
module uart_rx #(
    parameter integer CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,          // asynchronous serial input
    output reg        byte_valid,  // 1-cycle pulse
    output reg [7:0]  byte_out
);
    localparam S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;

    reg [1:0]  state;
    reg [15:0] cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  sh;
    reg        rx_q, rx_qq;

    // two-stage synchronizer on the async pad
    always @(posedge clk) begin
        rx_q  <= rx;
        rx_qq <= rx_q;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            cnt        <= 16'd0;
            bit_idx    <= 3'd0;
            sh         <= 8'd0;
            byte_out   <= 8'd0;
            byte_valid <= 1'b0;
        end else begin
            byte_valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    cnt     <= 16'd0;
                    bit_idx <= 3'd0;
                    if (rx_qq == 1'b0) state <= S_START;   // start bit edge
                end

                S_START: begin
                    // sample at mid-bit to confirm a real start bit
                    if (cnt == (CLKS_PER_BIT-1)/2) begin
                        cnt   <= 16'd0;
                        state <= (rx_qq == 1'b0) ? S_DATA : S_IDLE;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end

                S_DATA: begin
                    if (cnt == CLKS_PER_BIT-1) begin
                        cnt <= 16'd0;
                        sh  <= {rx_qq, sh[7:1]};           // LSB first
                        if (bit_idx == 3'd7) state   <= S_STOP;
                        else                 bit_idx <= bit_idx + 3'd1;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end

                S_STOP: begin
                    if (cnt == CLKS_PER_BIT-1) begin
                        cnt        <= 16'd0;
                        byte_out   <= sh;
                        byte_valid <= 1'b1;
                        state      <= S_IDLE;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end
            endcase
        end
    end
endmodule
