`timescale 1ns / 1ps
// Board-level wrapper. top_accelerator is instantiated UNCHANGED.
// Host sends 100 padded pixels (row-major, 1 byte each).
// FPGA buffers all 64 results, then sends 128 bytes: HIGH byte first, then LOW byte.
module top_basys3 (
    input  wire clk,     // W5, 100 MHz
    input  wire RsRx,    // B18
    output wire RsTx     // A18
);
    localparam integer CPB   = 868;   // 100 MHz / 115200 baud
    localparam integer N_OUT = 64;

    // ---- power-up reset (no button, keeps the pin count at 3) ----
    reg [7:0] rst_cnt = 8'd0;
    reg       rst_n   = 1'b0;
    always @(posedge clk) begin
        if (rst_cnt != 8'hFF) begin rst_cnt <= rst_cnt + 8'd1; rst_n <= 1'b0; end
        else                                                   rst_n <= 1'b1;
    end

    // ---- receive path: one byte = one pixel ----
    wire       rx_valid;
    wire [7:0] rx_byte;
    uart_rx #(.CLKS_PER_BIT(CPB)) u_rx (
        .clk(clk), .rst_n(rst_n), .rx(RsRx),
        .byte_valid(rx_valid), .byte_out(rx_byte)
    );

    // ---- the accelerator, exactly as verified ----
    wire               out_valid;
    wire signed [15:0] out_data;
    top_accelerator #(.IMG_W(10), .IMG_H(10)) u_acc (
        .clk(clk), .rst_n(rst_n),
        .pix_valid(rx_valid), .pix_8b(rx_byte),
        .out_valid(out_valid), .out_data(out_data)
    );

    // ---- result buffer (needed: 64 results = 128 bytes out vs only 100 bytes in) ----
    reg [15:0] res [0:N_OUT-1];
    reg [6:0]  wptr;
    reg        clr_w;

    always @(posedge clk) begin
        if (!rst_n) begin
            wptr <= 7'd0;
        end else if (clr_w) begin
            wptr <= 7'd0;
        end else if (out_valid && (wptr < N_OUT)) begin
            res[wptr] <= out_data;
            wptr      <= wptr + 7'd1;
        end
    end

    // ---- transmit path: 2 bytes per result, high byte first ----
    reg        tx_send;
    reg [7:0]  tx_byte;
    wire       tx_busy;
    uart_tx #(.CLKS_PER_BIT(CPB)) u_tx (
        .clk(clk), .rst_n(rst_n),
        .send(tx_send), .byte_in(tx_byte),
        .tx(RsTx), .busy(tx_busy)
    );

    reg [6:0] rptr;
    reg       hi_byte;
    reg       sending;

    always @(posedge clk) begin
        if (!rst_n) begin
            rptr    <= 7'd0;
            hi_byte <= 1'b1;
            sending <= 1'b0;
            tx_send <= 1'b0;
            clr_w   <= 1'b0;
            tx_byte <= 8'd0;
        end else begin
            tx_send <= 1'b0;
            clr_w   <= 1'b0;

            if (!sending) begin
                if (wptr == N_OUT) begin      // whole frame captured
                    sending <= 1'b1;
                    rptr    <= 7'd0;
                    hi_byte <= 1'b1;
                end
            end else if (!tx_busy) begin
                tx_byte <= hi_byte ? res[rptr][15:8] : res[rptr][7:0];
                tx_send <= 1'b1;
                if (hi_byte) begin
                    hi_byte <= 1'b0;
                end else begin
                    hi_byte <= 1'b1;
                    if (rptr == N_OUT-1) begin
                        sending <= 1'b0;
                        clr_w   <= 1'b1;      // arm for the next frame
                    end else begin
                        rptr <= rptr + 7'd1;
                    end
                end
            end
        end
    end
endmodule
