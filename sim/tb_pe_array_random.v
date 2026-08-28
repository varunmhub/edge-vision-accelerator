`timescale 1ns/1ps
// 256 pairs was exhaustive for one PE; the array's input space is 16^9, so
// exhaustion is impossible and random vectors against an independent reference
// are the right tool. The reference decodes through decoder_lut.mem and does a
// real signed multiply-accumulate, so this checks the adder tree, the bias add
// and the ReLU as a unit -- not the PE, which is already proven.
module tb_pe_array_random;

    localparam NTEST = 500;      // 500 x 10 ns fits inside the 10 us runtime

    reg                clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
    reg  [35:0]        win = 36'd0;
    wire               out_valid;
    wire signed [15:0] out_data;

    always #5 clk = ~clk;

    pe_array_3x3 #(
        .WGT_FILE  ("C:/Users/varun/Desktop/proj/mem/conv1_weights.mem"),
        .BIAS_FILE ("C:/Users/varun/Desktop/proj/mem/conv1_bias.mem")
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .win(win),
        .out_valid(out_valid), .out_data(out_data)
    );

    reg signed [7:0]  lut  [0:15];
    reg  [3:0]        wgt  [0:8];
    reg signed [15:0] bmem [0:0];
    reg signed [15:0] expq [0:NTEST-1];
    reg  [3:0]        c    [0:8];

    integer i, k, n, errors, sum;

    always @(posedge clk) begin
        if (rst_n && out_valid) begin
            if (out_data !== expq[n]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("MISMATCH i=%0d dut=%0d exp=%0d", n, out_data, expq[n]);
            end
            n = n + 1;
        end
    end

    initial begin
        n = 0; errors = 0;
        $readmemh("C:/Users/varun/Desktop/proj/mem/decoder_lut.mem",   lut);
        $readmemh("C:/Users/varun/Desktop/proj/mem/conv1_weights.mem", wgt);
        $readmemh("C:/Users/varun/Desktop/proj/mem/conv1_bias.mem",    bmem);

        if (lut[1] === 8'bxxxxxxxx || wgt[0] === 4'hx) begin
            $display("*** FAIL: .mem files not loaded -- check the paths ***");
            $finish;
        end

        repeat (4) @(posedge clk);
        @(negedge clk); rst_n = 1'b1;

        for (i = 0; i < NTEST; i = i + 1) begin
            // independent reference: decode both operands, real signed MAC
            sum = bmem[0];
            for (k = 0; k < 9; k = k + 1) begin
                c[k] = $random;
                sum  = sum + lut[c[k]] * lut[wgt[k]];
            end
            if (sum < 0) sum = 0;               // ReLU
            expq[i] = sum;

            @(negedge clk);
            in_valid = 1'b1;
            for (k = 0; k < 9; k = k + 1)
                win[k*4 +: 4] = c[k];
        end

        @(negedge clk); in_valid = 1'b0;
        repeat (5) @(posedge clk);

        if (n !== NTEST)
            $display("*** FAIL: got %0d outputs, expected %0d ***", n, NTEST);
        else if (errors == 0)
            $display("*** PASS: PE array + bias + ReLU exact on %0d random windows ***", NTEST);
        else
            $display("*** FAIL: %0d of %0d windows wrong ***", errors, NTEST);
        $finish;
    end
endmodule
