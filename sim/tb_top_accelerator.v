`timescale 1ns/1ps
// Runs all ten images, reloading img and gold between frames and asserting
// reset so the line buffer starts clean each time.
//
// NOTE: this run needs 11495 ns. Raise xsim.simulate.runtime to 50us under
// Settings -> Simulation, or type `run -all` in the Tcl Console, otherwise the
// run stops one image short with no failure message.
//
// The image loads are written out one per line deliberately: dynamic filename
// construction is a SystemVerilog feature and behaves inconsistently in a .v file.
module tb_top_accelerator;

    localparam NPIX = 100;   // padded 10x10 frame
    localparam NOUT = 64;    // SAME-conv outputs per frame

    reg                clk = 1'b0, rst_n = 1'b0, pix_valid = 1'b0;
    reg  [7:0]         pix_8b = 8'd0;
    wire               out_valid;
    wire signed [15:0] out_data;

    always #5 clk = ~clk;    // 100 MHz

    top_accelerator #(
        .IMG_W       (10),
        .IMG_H       (10),
        .THRESH_FILE ("C:/Users/varun/Desktop/proj/mem/act_thresholds.mem"),
        .WGT_FILE    ("C:/Users/varun/Desktop/proj/mem/conv1_weights.mem"),
        .BIAS_FILE   ("C:/Users/varun/Desktop/proj/mem/conv1_bias.mem")
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .pix_valid(pix_valid), .pix_8b(pix_8b),
        .out_valid(out_valid), .out_data(out_data)
    );

    reg  [7:0]        img  [0:NPIX-1];   // padded 8-bit PIXELS, not codes
    reg signed [15:0] gold [0:NOUT-1];

    integer n, errors, total_errors, images_ok, j;

    // ---- checker: compare only on out_valid ----------------------------
    always @(posedge clk) begin
        if (rst_n && out_valid) begin
            if (out_data !== gold[n]) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("    MISMATCH idx=%0d dut=%0d gold=%0d",
                             n, out_data, gold[n]);
            end
            n = n + 1;
        end
    end

    // ---- one frame ------------------------------------------------------
    task run_image(input integer id);
        begin
            rst_n = 1'b0; pix_valid = 1'b0; pix_8b = 8'd0;
            n = 0; errors = 0;
            repeat (4) @(posedge clk);
            @(negedge clk); rst_n = 1'b1;

            for (j = 0; j < NPIX; j = j + 1) begin
                @(negedge clk);
                pix_valid = 1'b1;
                pix_8b    = img[j];
            end

            @(negedge clk); pix_valid = 1'b0; pix_8b = 8'd0;
            repeat (10) @(posedge clk);      // drain the 4-stage pipeline

            if (n !== NOUT) begin
                $display("*** FAIL image %0d: got %0d outputs, expected %0d ***",
                         id, n, NOUT);
                total_errors = total_errors + 1;
            end else if (errors == 0) begin
                $display("PASS image %0d: %0d/%0d outputs bit-exact", id, n, NOUT);
                images_ok = images_ok + 1;
            end else begin
                $display("*** FAIL image %0d: %0d of %0d outputs wrong ***",
                         id, errors, NOUT);
                total_errors = total_errors + errors;
            end
        end
    endtask

    initial begin
        total_errors = 0;
        images_ok    = 0;

        $readmemh("C:/Users/varun/Desktop/proj/mem/test_image_pixels.mem",   img);
        $readmemh("C:/Users/varun/Desktop/proj/mem/golden_output.mem",       gold);
        if (gold[0] === 16'bx) begin
            $display("*** FAIL: .mem files not loaded -- check the paths ***");
            $finish;
        end
        run_image(0);

        $readmemh("C:/Users/varun/Desktop/proj/mem/test_image_pixels_1.mem", img);
        $readmemh("C:/Users/varun/Desktop/proj/mem/golden_output_1.mem",     gold);
        run_image(1);

        $readmemh("C:/Users/varun/Desktop/proj/mem/test_image_pixels_2.mem", img);
        $readmemh("C:/Users/varun/Desktop/proj/mem/golden_output_2.mem",     gold);
        run_image(2);

        $readmemh("C:/Users/varun/Desktop/proj/mem/test_image_pixels_3.mem", img);
        $readmemh("C:/Users/varun/Desktop/proj/mem/golden_output_3.mem",     gold);
        run_image(3);

        $readmemh("C:/Users/varun/Desktop/proj/mem/test_image_pixels_4.mem", img);
        $readmemh("C:/Users/varun/Desktop/proj/mem/golden_output_4.mem",     gold);
        run_image(4);

        $readmemh("C:/Users/varun/Desktop/proj/mem/test_image_pixels_5.mem", img);
        $readmemh("C:/Users/varun/Desktop/proj/mem/golden_output_5.mem",     gold);
        run_image(5);

        $readmemh("C:/Users/varun/Desktop/proj/mem/test_image_pixels_6.mem", img);
        $readmemh("C:/Users/varun/Desktop/proj/mem/golden_output_6.mem",     gold);
        run_image(6);

        $readmemh("C:/Users/varun/Desktop/proj/mem/test_image_pixels_7.mem", img);
        $readmemh("C:/Users/varun/Desktop/proj/mem/golden_output_7.mem",     gold);
        run_image(7);

        $readmemh("C:/Users/varun/Desktop/proj/mem/test_image_pixels_8.mem", img);
        $readmemh("C:/Users/varun/Desktop/proj/mem/golden_output_8.mem",     gold);
        run_image(8);

        $readmemh("C:/Users/varun/Desktop/proj/mem/test_image_pixels_9.mem", img);
        $readmemh("C:/Users/varun/Desktop/proj/mem/golden_output_9.mem",     gold);
        run_image(9);

        $display("");
        if (total_errors == 0)
            $display("*** PASS: %0d/10 images, all 640 outputs bit-exact ***", images_ok);
        else
            $display("*** FAIL: %0d total errors across 10 images ***", total_errors);
        $finish;
    end
endmodule
