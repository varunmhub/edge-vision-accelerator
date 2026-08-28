`timescale 1ns/1ps
// SAME-padded 3x3 window generator.
// IMG_W / IMG_H are the PADDED dimensions: 10 x 10 for an 8x8 image, pad = 1.
// Host streams IMG_W*IMG_H codes row-major; this emits (IMG_W-2)*(IMG_H-2)
// windows = 64 for the current test image.
module window_gen #(
    parameter IMG_W = 10,
    parameter IMG_H = 10,
    parameter DW    = 4
)(
    input  wire            clk,
    input  wire            rst_n,
    input  wire            in_valid,
    input  wire [DW-1:0]   in_pix,
    output reg  [9*DW-1:0] win,
    output reg             win_valid
);
    // vertical: three rows at the current column
    wire [DW-1:0] row0, row1, row2;

    line_buffer #(.IMG_W(IMG_W), .DW(DW)) u_lb (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (in_valid),
        .in_pix   (in_pix),
        .row0     (row0),      // y-2
        .row1     (row1),      // y-1
        .row2     (row2)       // y   (= in_pix)
    );

    // horizontal: two taps per row (x-1, x-2); x itself is rowN directly
    reg [DW-1:0] t0a, t0b;     // y-2
    reg [DW-1:0] t1a, t1b;     // y-1
    reg [DW-1:0] t2a, t2b;     // y

    // raster position of the pixel being consumed this cycle
    reg [$clog2(IMG_W)-1:0] col_cnt;
    reg [$clog2(IMG_H)-1:0] row_cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            t0a <= 0; t0b <= 0;
            t1a <= 0; t1b <= 0;
            t2a <= 0; t2b <= 0;
            col_cnt   <= 0;
            row_cnt   <= 0;
            win       <= 0;
            win_valid <= 1'b0;
        end else begin
            win_valid <= 1'b0;
            if (in_valid) begin
                t0b <= t0a;  t0a <= row0;
                t1b <= t1a;  t1a <= row1;
                t2b <= t2a;  t2a <= row2;

                // k = 0..8 row-major; k = 8 is the current pixel
                win <= { row2, t2a, t2b,      // k = 8,7,6
                         row1, t1a, t1b,      // k = 5,4,3
                         row0, t0a, t0b };    // k = 2,1,0

                win_valid <= (row_cnt >= 2) && (col_cnt >= 2);

                if (col_cnt == IMG_W-1) begin
                    col_cnt <= 0;
                    row_cnt <= (row_cnt == IMG_H-1) ? 0 : row_cnt + 1'b1;
                end else begin
                    col_cnt <= col_cnt + 1'b1;
                end
            end
        end
    end
endmodule
