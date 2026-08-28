`timescale 1ns/1ps
// 8-bit pixel in -> quantize -> line buffer -> 3x3 window -> PE array -> ReLU out.
// IMG_W / IMG_H are the PADDED dimensions (10 x 10 for an 8x8 image).
// Total latency is 4 cycles (quantizer 1, window gen 1, PE array 2). Nothing
// counts cycles: every stage carries its own valid.
module top_accelerator #(
    parameter IMG_W       = 10,
    parameter IMG_H       = 10,
    parameter THRESH_FILE = "",
    parameter WGT_FILE    = "",
    parameter BIAS_FILE   = ""
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               pix_valid,
    input  wire [7:0]         pix_8b,
    output wire               out_valid,
    output wire signed [15:0] out_data
);
    wire        code_valid;
    wire [3:0]  code_4b;
    wire        win_valid;
    wire [35:0] win;

    quantizer_8to4 #(
        .SIGNED_IN   (0),
        .THRESH_FILE (THRESH_FILE)
    ) u_q (
        .clk(clk), .rst_n(rst_n),
        .in_valid(pix_valid), .in_pix(pix_8b),
        .out_valid(code_valid), .out_code(code_4b)
    );

    window_gen #(
        .IMG_W (IMG_W),
        .IMG_H (IMG_H),
        .DW    (4)
    ) u_wg (
        .clk(clk), .rst_n(rst_n),
        .in_valid(code_valid), .in_pix(code_4b),
        .win(win), .win_valid(win_valid)
    );

    pe_array_3x3 #(
        .WGT_FILE  (WGT_FILE),
        .BIAS_FILE (BIAS_FILE)
    ) u_pe (
        .clk(clk), .rst_n(rst_n),
        .in_valid(win_valid), .win(win),
        .out_valid(out_valid), .out_data(out_data)
    );
endmodule
