`timescale 1ns/1ps
// SWEEP VARIANT -- synthesis-only, feeds the BRAM/LUT width table.
// Addressed circular buffer so the arrays can infer real memory. The read is
// registered (memory inference requires that), so row0/row1 lag row2 by one
// cycle -- do not drop this into the datapath without adding the matching delay.
// Functional verification stays on the shift version in line_buffer.v.
module line_buffer_ram #(
    parameter IMG_W = 640,
    parameter DW    = 4          // sweep 4 vs 8
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          in_valid,
    input  wire [DW-1:0] in_pix,
    output reg  [DW-1:0] row0,
    output reg  [DW-1:0] row1,
    output wire [DW-1:0] row2
);
    (* ram_style = "block" *) reg [DW-1:0] lb0 [0:IMG_W-1];
    (* ram_style = "block" *) reg [DW-1:0] lb1 [0:IMG_W-1];

    reg [$clog2(IMG_W)-1:0] ptr;

    always @(posedge clk) begin
        if (!rst_n) begin
            ptr <= 0;                 // pointer resets; the arrays never do
        end else if (in_valid) begin
            row1     <= lb1[ptr];     // written IMG_W cycles ago
            row0     <= lb0[ptr];
            lb0[ptr] <= lb1[ptr];     // read-before-write
            lb1[ptr] <= in_pix;
            ptr      <= (ptr == IMG_W-1) ? 0 : ptr + 1'b1;
        end
    end

    assign row2 = in_pix;
endmodule
