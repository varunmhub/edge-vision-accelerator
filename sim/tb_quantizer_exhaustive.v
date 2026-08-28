`timescale 1ns/1ps
// The input space is 8 bits wide, so do not sample it -- test all of it.
// 256 vectors is a trivial simulation and lets the quantizer be called
// exhaustively verified rather than spot-checked.
module tb_quantizer_exhaustive;

    reg        clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
    reg  [7:0] in_pix = 8'd0;
    wire       out_valid;
    wire [3:0] out_code;

    always #5 clk = ~clk;

    quantizer_8to4 #(
        .SIGNED_IN   (0),
        .THRESH_FILE ("C:/Users/varun/Desktop/proj/mem/act_thresholds.mem")
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_pix(in_pix),
        .out_valid(out_valid), .out_code(out_code)
    );

    reg [3:0] ref_code [0:255];   // host's answer for every possible pixel
    integer   i, n, errors;

    always @(posedge clk) begin
        if (rst_n && out_valid) begin
            if (out_code !== ref_code[n]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("MISMATCH pix=%0d dut=%h host=%h",
                             n, out_code, ref_code[n]);
            end
            n = n + 1;
        end
    end

    initial begin
        n = 0; errors = 0;
        $readmemh("C:/Users/varun/Desktop/proj/mem/quant_ref_256.mem", ref_code);

        // $readmemh failure is only a warning in Vivado. Catch it here.
        if (ref_code[0] === 4'bxxxx) begin
            $display("*** FAIL: quant_ref_256.mem not loaded -- check the path ***");
            $finish;
        end

        repeat (4) @(posedge clk);
        @(negedge clk); rst_n = 1'b1;

        for (i = 0; i < 256; i = i + 1) begin
            @(negedge clk);
            in_valid = 1'b1;
            in_pix   = i[7:0];
        end
        @(negedge clk); in_valid = 1'b0;
        repeat (5) @(posedge clk);

        if (n !== 256)
            $display("*** FAIL: got %0d results, expected 256 ***", n);
        else if (errors == 0)
            $display("*** PASS: quantizer exact on all 256 input values ***");
        else
            $display("*** FAIL: %0d of 256 values wrong ***", errors);
        $finish;
    end
endmodule
