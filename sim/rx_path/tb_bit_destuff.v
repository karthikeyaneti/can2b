`timescale 1ns / 1ps

module tb_bit_destuff;

    reg  can_clk;
    reg  can_rst_n_sync;
    reg  sample_point;
    reg  destuff_en;
    reg  destuff_reset;
    reg  raw_bit_in;

    wire destuffed_bit_out;
    wire destuffed_bit_valid;
    wire stuff_bit_dropped;
    wire stuff_error;

    integer errors = 0;

    // Instantiate DUT
    bit_destuff dut (
        .can_clk            (can_clk),
        .can_rst_n_sync     (can_rst_n_sync),
        .sample_point       (sample_point),
        .destuff_en         (destuff_en),
        .destuff_reset      (destuff_reset),
        .raw_bit_in         (raw_bit_in),
        .destuffed_bit_out   (destuffed_bit_out),
        .destuffed_bit_valid (destuffed_bit_valid),
        .stuff_bit_dropped   (stuff_bit_dropped),
        .stuff_error         (stuff_error)
    );

    always #5 can_clk = ~can_clk;

    // Capture buffer
    reg [255:0] captured_data;
    integer captured_cnt;
    integer dropped_cnt;
    integer error_cnt;

    always @(posedge can_clk) begin
        if (can_rst_n_sync) begin
            if (destuffed_bit_valid) begin
                captured_data[captured_cnt] <= destuffed_bit_out;
                captured_cnt                <= captured_cnt + 1;
            end
            if (stuff_bit_dropped) begin
                dropped_cnt <= dropped_cnt + 1;
            end
            if (stuff_error) begin
                error_cnt <= error_cnt + 1;
            end
        end
    end

    task automatic clear_stats;
        begin
            captured_data = 256'd0;
            captured_cnt  = 0;
            dropped_cnt   = 0;
            error_cnt     = 0;
        end
    endtask

    // Task to send a bit on sample_point
    task automatic send_bit(input b);
        begin
            @(posedge can_clk);
            raw_bit_in   <= b;
            sample_point <= 1'b1;
            @(posedge can_clk);
            sample_point <= 1'b0;
            repeat (2) @(posedge can_clk);
        end
    endtask

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_bit_destuff.vcd");
`endif
        $dumpvars(0, tb_bit_destuff);

        can_clk        = 0;
        can_rst_n_sync = 0;
        sample_point   = 0;
        destuff_en     = 1;
        destuff_reset  = 0;
        raw_bit_in     = 1;
        clear_stats();

        #20;
        @(posedge can_clk);
        can_rst_n_sync = 1;
        @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 1: 5 zeros followed by a 1 (stuff bit) -> expect 5 zeros, 1 drop
        //-------------------------------------------------------------
        $display("[TB] Test 1: 5 zeros + 1 (stuff bit)...");
        clear_stats();
        send_bit(0);
        send_bit(0);
        send_bit(0);
        send_bit(0);
        send_bit(0);
        send_bit(1); // Stuff bit
        repeat (3) @(posedge can_clk);

        if (captured_cnt !== 5 || captured_data[4:0] !== 5'b00000 || dropped_cnt !== 1 || error_cnt !== 0) begin
            $display("[TB ERROR] Test 1 failed! cnt=%0d data=%b dropped=%0d err=%0d",
                     captured_cnt, captured_data[4:0], dropped_cnt, error_cnt);
            errors = errors + 1;
        end else begin
            $display("[TB] Test 1 PASSED!");
        end

        //-------------------------------------------------------------
        // Test 2: 5 ones followed by a 0 (stuff bit) -> expect 5 ones, 1 drop
        //-------------------------------------------------------------
        $display("[TB] Test 2: 5 ones + 0 (stuff bit)...");
        clear_stats();
        destuff_reset <= 1'b1;
        @(posedge can_clk);
        destuff_reset <= 1'b0;
        @(posedge can_clk);

        send_bit(1);
        send_bit(1);
        send_bit(1);
        send_bit(1);
        send_bit(1);
        send_bit(0); // Stuff bit
        repeat (3) @(posedge can_clk);

        if (captured_cnt !== 5 || captured_data[4:0] !== 5'b11111 || dropped_cnt !== 1 || error_cnt !== 0) begin
            $display("[TB ERROR] Test 2 failed! cnt=%0d data=%b dropped=%0d err=%0d",
                     captured_cnt, captured_data[4:0], dropped_cnt, error_cnt);
            errors = errors + 1;
        end else begin
            $display("[TB] Test 2 PASSED!");
        end

        //-------------------------------------------------------------
        // Test 3: Stuff Error on 6 consecutive identical bits
        //-------------------------------------------------------------
        $display("[TB] Test 3: Stuff error (6 zeros)...");
        clear_stats();
        destuff_reset <= 1'b1;
        @(posedge can_clk);
        destuff_reset <= 1'b0;
        @(posedge can_clk);

        send_bit(0);
        send_bit(0);
        send_bit(0);
        send_bit(0);
        send_bit(0);
        send_bit(0); // 6th zero violates stuff rule!
        repeat (3) @(posedge can_clk);

        if (error_cnt === 0) begin
            $display("[TB ERROR] Test 3 failed: Stuff error not detected!");
            errors = errors + 1;
        end else begin
            $display("[TB] Test 3 PASSED! Stuff error asserted correctly.");
        end

        //-------------------------------------------------------------
        // Test 4: Stuffing disabled (destuff_en = 0)
        //-------------------------------------------------------------
        $display("[TB] Test 4: Stuffing disabled (6 zeros passthrough)...");
        clear_stats();
        destuff_en <= 1'b0;
        @(posedge can_clk);

        send_bit(0);
        send_bit(0);
        send_bit(0);
        send_bit(0);
        send_bit(0);
        send_bit(0);
        repeat (3) @(posedge can_clk);

        if (captured_cnt !== 6 || captured_data[5:0] !== 6'b000000 || error_cnt !== 0) begin
            $display("[TB ERROR] Test 4 failed! cnt=%0d err=%0d", captured_cnt, error_cnt);
            errors = errors + 1;
        end else begin
            $display("[TB] Test 4 PASSED!");
        end

        //-------------------------------------------------------------
        // Summary
        //-------------------------------------------------------------
        repeat (5) @(posedge can_clk);
        if (errors == 0) begin
            $display("\n=======================================================");
            $display("   ALL BIT_DESTUFF TESTS PASSED SUCCESSFULLY!          ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("   BIT_DESTUFF TESTS FAILED WITH %0d ERRORS!           ", errors);
            $display("=======================================================\n");
        end

        $finish;
    end

endmodule
