`timescale 1ns/1ps
// Two IMG_W-deep shift-register rows. Vivado infers SRL16E at small IMG_W.
// DW defaults to 4: the buffer stores quantized codes, which is the memory claim.
// DW = 8 builds the baseline for the width comparison.
module line_buffer #(
    parameter IMG_W = 8,
    parameter DW    = 4     // 4 = quantized codes (the claim), 8 = baseline
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          in_valid,
    input  wire [DW-1:0] in_pix,
    output wire [DW-1:0] row0,   // oldest  (y-2)
    output wire [DW-1:0] row1,   //         (y-1)
    output wire [DW-1:0] row2    // current (y)
);
    reg [DW-1:0] lb0 [0:IMG_W-1];   // feeds row0
    reg [DW-1:0] lb1 [0:IMG_W-1];   // feeds row1
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < IMG_W; i = i + 1) begin
                lb0[i] <= {DW{1'b0}};
                lb1[i] <= {DW{1'b0}};
            end
        end else if (in_valid) begin
            // lb1 delays the incoming pixel by one row
            lb1[0] <= in_pix;
            for (i = 1; i < IMG_W; i = i + 1)
                lb1[i] <= lb1[i-1];
            // lb0 delays lb1's output by another row
            lb0[0] <= lb1[IMG_W-1];
            for (i = 1; i < IMG_W; i = i + 1)
                lb0[i] <= lb0[i-1];
        end
    end

    assign row2 = in_pix;
    assign row1 = lb1[IMG_W-1];
    assign row0 = lb0[IMG_W-1];
endmodule
