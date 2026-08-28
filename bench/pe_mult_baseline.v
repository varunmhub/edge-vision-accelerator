`timescale 1ns/1ps
// VARIANT B BASELINE -- the conventional way.
// Decode both 4-bit codes to real 8-bit signed values through the ROM,
// then perform an actual signed multiply. This is what pe_shift_mult replaces.
module pe_mult_baseline #(
    parameter LUT_FILE = ""      // decoder_lut.mem : 16 x 8-bit two's complement
)(
    input  wire [3:0]         a_code,
    input  wire [3:0]         w_code,
    output wire signed [13:0] prod
);
    reg signed [7:0] lut [0:15];

    initial begin
        // spec defaults: ladder 0,1,2,4,8,16,32,64; bit3 = sign; code 8 -> +0
        lut[0] = 8'sd0;    lut[1] = 8'sd1;    lut[2] = 8'sd2;    lut[3] = 8'sd4;
        lut[4] = 8'sd8;    lut[5] = 8'sd16;   lut[6] = 8'sd32;   lut[7] = 8'sd64;
        lut[8] = 8'sd0;    lut[9] = -8'sd1;   lut[10] = -8'sd2;  lut[11] = -8'sd4;
        lut[12] = -8'sd8;  lut[13] = -8'sd16; lut[14] = -8'sd32; lut[15] = -8'sd64;
        if (LUT_FILE != "") $readmemh(LUT_FILE, lut);
    end

    wire signed [7:0] a_val = lut[a_code];
    wire signed [7:0] w_val = lut[w_code];

    // real signed multiply: this is the line that costs DSP48s or a lot of LUTs
    assign prod = a_val * w_val;
endmodule
