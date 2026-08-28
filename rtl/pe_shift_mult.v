// PRIMARY. Both operands are power-of-two codes, so the PRODUCT is itself
// a power of two. No multiplier and no data shifter -- just an index add,
// a one-hot shift of a constant 1, and a sign XOR.
`timescale 1ns / 1ps
module pe_shift_mult (
    input  wire [3:0]         a_code,  // activation {sign, idx}
    input  wire [3:0]         w_code,  // weight     {sign, idx}
    output wire signed [13:0] prod
);
    wire       a_sgn = a_code[3];
    wire [2:0] a_idx = a_code[2:0];
    wire       w_sgn = w_code[3];
    wire [2:0] w_idx = w_code[2:0];

    // idx==0 means magnitude 0, which also absorbs the negative-zero codes
    wire        is_zero = (a_idx == 3'd0) || (w_idx == 3'd0);
    wire [3:0]  sh      = {1'b0, a_idx} + {1'b0, w_idx} - 4'd2;   // 0..12
    wire [13:0] mag     = is_zero ? 14'd0 : (14'd1 << sh);
    wire        sgn     = a_sgn ^ w_sgn;

    assign prod = sgn ? -$signed(mag) : $signed(mag);
endmodule
