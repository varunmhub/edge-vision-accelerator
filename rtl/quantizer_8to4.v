`timescale 1ns/1ps
// 8-bit sensor pixel -> 4-bit sign-magnitude power-of-two code.
// Ladder: idx 0..7 -> magnitude 0,1,2,4,8,16,32,64  (same as the weights)
// Pure comparator ladder: no multiplier, no DSP, one cycle of latency.
module quantizer_8to4 #(
    parameter SIGNED_IN   = 0,   // 0 = unsigned camera pixel 0..255
                                 // 1 = signed 8-bit two's complement
    parameter THRESH_FILE = ""   // 7 thresholds exported by Phase 1
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    output reg        out_valid,
    output reg  [3:0] out_code
);
    // t[q] = boundary between ladder idx q and idx q+1
    reg [8:0] t [0:6];

    initial begin
        // geometric (sqrt-2) midpoints, 4 pixel LSBs per activation unit
        t[0] = 9'd2;   t[1] = 9'd6;   t[2] = 9'd11;  t[3] = 9'd23;
        t[4] = 9'd45;  t[5] = 9'd91;  t[6] = 9'd181;
        // host file wins whenever it is supplied
        if (THRESH_FILE != "") $readmemh(THRESH_FILE, t);
    end

    wire       sgn = SIGNED_IN ? in_pix[7] : 1'b0;
    wire [8:0] mag = (SIGNED_IN && in_pix[7]) ? (9'd256 - {1'b0, in_pix})
                                              : {1'b0, in_pix};

    // thresholds ascend, so the last match wins -> highest valid index
    reg [2:0] idx;
    integer   q;
    always @(*) begin
        idx = 3'd0;
        for (q = 0; q < 7; q = q + 1)
            if (mag >= t[q]) idx = q[2:0] + 3'd1;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            out_code  <= 4'd0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= in_valid;
            // canonical zero: magnitude 0 always emits 0, never negative-zero 8
            out_code  <= (idx == 3'd0) ? 4'd0 : {sgn, idx};
        end
    end
endmodule
