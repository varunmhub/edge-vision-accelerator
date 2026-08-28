`timescale 1ns/1ps
// Benchmark-only variant of pe_array_3x3: weights arrive at runtime.
// Not part of top_accelerator. Do not instantiate in the real design.
module pe_array_3x3_varw #(
    parameter BIAS_FILE = ""
)(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                in_valid,
    input  wire [35:0]         win,      // 9 x 4-bit activation codes
    input  wire [35:0]         wgt_in,   // 9 x 4-bit weight codes  <-- now a port
    output reg                 out_valid,
    output reg  signed [15:0]  out_data
);
    reg signed [15:0] bmem [0:0];
    initial begin
        bmem[0] = 16'sh091d;
        if (BIAS_FILE != "") $readmemh(BIAS_FILE, bmem);
    end

    wire signed [13:0] prod [0:8];
    genvar g;
    generate
        for (g = 0; g < 9; g = g + 1) begin : pe
            pe_shift_mult u_pe (
                .a_code (win   [g*4 +: 4]),
                .w_code (wgt_in[g*4 +: 4]),
                .prod   (prod[g])
            );
        end
    endgenerate

    // stage 1
    wire signed [14:0] s0 = prod[0] + prod[1];
    wire signed [14:0] s1 = prod[2] + prod[3];
    wire signed [14:0] s2 = prod[4] + prod[5];
    wire signed [14:0] s3 = prod[6] + prod[7];
    wire signed [14:0] s4 = prod[8];

    wire signed [15:0] t0 = s0 + s1;
    wire signed [15:0] t1 = s2 + s3;
    wire signed [15:0] t2 = s4;

    reg signed [15:0] t0_q, t1_q, t2_q;
    reg               valid_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            t0_q <= 16'sd0; t1_q <= 16'sd0; t2_q <= 16'sd0;
            valid_q <= 1'b0;
        end else begin
            t0_q <= t0; t1_q <= t1; t2_q <= t2;
            valid_q <= in_valid;
        end
    end

    // stage 2
    wire signed [16:0] u0     = t0_q + t1_q;
    wire signed [17:0] acc    = u0 + t2_q;
    wire signed [17:0] biased = acc + bmem[0];

    always @(posedge clk) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_data  <= 16'sd0;
        end else begin
            out_valid <= valid_q;
            out_data  <= (biased < 0) ? 16'sd0 : biased[15:0];
        end
    end
endmodule
