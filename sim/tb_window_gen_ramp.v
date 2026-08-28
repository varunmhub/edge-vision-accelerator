`timescale 1ns/1ps
// Runs the frame twice: back-to-back, then with a stall cycle before every
// pixel and in_pix driven to x during each gap. If the DUT ever samples while
// in_valid is low, the x propagates into win and the compare fails loudly.
module tb_window_gen_ramp;

    localparam IMG_W = 10;            // PADDED width  (8 + 2)
    localparam IMG_H = 10;            // PADDED height (8 + 2)
    localparam DW    = 4;
    localparam OW    = IMG_W - 2;     // 8
    localparam OH    = IMG_H - 2;     // 8
    localparam NPIX  = IMG_W * IMG_H; // 100
    localparam NWIN  = OW * OH;       // 64

    reg             clk = 1'b0, rst_n = 1'b0, in_valid = 1'b0;
    reg  [DW-1:0]   in_pix = 0;
    wire [9*DW-1:0] win;
    wire            win_valid;

    always #5 clk = ~clk;             // 100 MHz

    window_gen #(.IMG_W(IMG_W), .IMG_H(IMG_H), .DW(DW)) dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_pix(in_pix),
        .win(win), .win_valid(win_valid)
    );

    reg [DW-1:0] frame [0:NPIX-1];
    integer n, errors, checks, total_errors;
    integer r, c, i, k, orow, ocol;
    reg [DW-1:0] exp_val, got_val;

    // ---- checker -------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n && win_valid) begin
            orow = n / OW;
            ocol = n % OW;
            for (k = 0; k < 9; k = k + 1) begin
                exp_val = frame[(orow + k/3)*IMG_W + (ocol + k%3)];
                got_val = win[k*DW +: DW];
                checks  = checks + 1;
                if (got_val !== exp_val) begin
                    errors = errors + 1;
                    if (errors <= 20)
                        $display("MISMATCH win=%0d (row=%0d col=%0d) k=%0d got=%0d exp=%0d",
                                 n, orow, ocol, k, got_val, exp_val);
                end
            end
            n = n + 1;
        end
    end

    // ---- one full frame, optionally stalled -----------------------------
    task run_frame(input integer stall_en);
        integer j;
        begin
            rst_n = 1'b0; in_valid = 1'b0; in_pix = 0;
            n = 0; errors = 0; checks = 0;
            repeat (4) @(posedge clk);
            @(negedge clk); rst_n = 1'b1;

            for (j = 0; j < NPIX; j = j + 1) begin
                if (stall_en) begin
                    @(negedge clk);
                    in_valid = 1'b0;
                    in_pix   = {DW{1'bx}};   // must never be sampled
                end
                @(negedge clk);
                in_valid = 1'b1;
                in_pix   = frame[j];
            end

            @(negedge clk);
            in_valid = 1'b0;
            in_pix   = {DW{1'bx}};
            repeat (10) @(posedge clk);      // drain the checker

            if (n !== NWIN) begin
                $display("*** FAIL (stall=%0d): got %0d windows, expected %0d ***",
                         stall_en, n, NWIN);
                total_errors = total_errors + 1;
            end else if (errors == 0) begin
                $display("*** PASS (stall=%0d): %0d windows, all %0d elements correct ***",
                         stall_en, n, checks);
            end else begin
                $display("*** FAIL (stall=%0d): %0d mismatches in %0d element checks ***",
                         stall_en, errors, checks);
                total_errors = total_errors + errors;
            end
        end
    endtask

    initial begin
        total_errors = 0;

        // padded ramp: interior 1..15 and never 0, border 0.
        // A zero anywhere inside a window therefore MUST be padding,
        // so any off-by-one row/column fails immediately.
        i = 0;
        for (r = 0; r < IMG_H; r = r + 1) begin
            for (c = 0; c < IMG_W; c = c + 1) begin
                if (r == 0 || r == IMG_H-1 || c == 0 || c == IMG_W-1) begin
                    frame[r*IMG_W + c] = 0;
                end else begin
                    frame[r*IMG_W + c] = (i % 15) + 1;
                    i = i + 1;
                end
            end
        end

        run_frame(0);   // back-to-back
        run_frame(1);   // one stall cycle before every pixel

        if (total_errors == 0) $display("*** ALL PASSES OK ***");
        else                   $display("*** %0d FAILURES ***", total_errors);
        $finish;
    end
endmodule
