`timescale 1ns/1ps
// The PE has only 16 x 16 = 256 possible input pairs, so test all of them
// against a decode-and-multiply reference. The DUT is combinational, so no
// clock is needed. This proves the shift-and-index trick is exactly equal to a
// real signed multiply over the whole input space, including every negative
// code on both operands and both zero encodings (0 and negative-zero 8).
module tb_pe_shift_mult_exhaustive;

    reg  [3:0] a_code, w_code;
    wire signed [13:0] prod;

    pe_shift_mult dut (.a_code(a_code), .w_code(w_code), .prod(prod));

    reg signed [7:0]  lut [0:15];   // decoder_lut.mem, 8-bit two's complement
    reg signed [13:0] ref;
    integer a, w, errors;

    initial begin
        errors = 0;
        $readmemh("C:/Users/varun/Desktop/proj/mem/decoder_lut.mem", lut);
        if (lut[1] === 8'bxxxxxxxx) begin
            $display("*** FAIL: decoder_lut.mem not loaded -- check the path ***");
            $finish;
        end

        for (a = 0; a < 16; a = a + 1) begin
            for (w = 0; w < 16; w = w + 1) begin
                a_code = a[3:0];
                w_code = w[3:0];
                #1;
                ref = lut[a] * lut[w];      // signed 8x8 reference multiply
                if (prod !== ref) begin
                    errors = errors + 1;
                    if (errors <= 20)
                        $display("MISMATCH a=%h w=%h dut=%0d ref=%0d",
                                 a[3:0], w[3:0], prod, ref);
                end
            end
        end

        if (errors == 0)
            $display("*** PASS: shift-PE exact on all 256 code pairs ***");
        else
            $display("*** FAIL: %0d of 256 pairs wrong ***", errors);
        $finish;
    end
endmodule
