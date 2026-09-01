`timescale 1ns / 1ps

module tb_bit_stuff;

    reg  can_clk;
    reg  can_rst_n_sync;
    reg  stuff_en;
    reg  stuff_reset;
    reg  tx_bit_in;
    reg  tx_bit_in_valid;

    wire tx_bit_out;
    wire tx_bit_out_valid;
    wire tx_bit_in_ready;
    wire stuff_inserted;

    integer errors = 0;

    // Instantiate DUT
    bit_stuff dut (
        .can_clk          (can_clk),
        .can_rst_n_sync   (can_rst_n_sync),
        .stuff_en         (stuff_en),
        .stuff_reset       (stuff_reset),
        .tx_bit_in        (tx_bit_in),
        .tx_bit_in_valid  (tx_bit_in_valid),
        .tx_bit_out       (tx_bit_out),
        .tx_bit_out_valid (tx_bit_out_valid),
        .tx_bit_in_ready  (tx_bit_in_ready),
        .stuff_inserted   (stuff_inserted)
    );

    // 100MHz clock generation (10ns period)
    always #5 can_clk = ~can_clk;

    // Buffer to capture outputs
    reg [255:0] captured_bits;
    reg [255:0] captured_stuffed;
    integer out_bit_count;

    always @(posedge can_clk) begin
        if (can_rst_n_sync && tx_bit_out_valid) begin
            captured_bits[out_bit_count]    <= tx_bit_out;
            captured_stuffed[out_bit_count] <= stuff_inserted;
            out_bit_count                   <= out_bit_count + 1;
        end
    end

    task automatic clear_capture;
        begin
            captured_bits    = 256'd0;
            captured_stuffed = 256'd0;
            out_bit_count    = 0;
        end
    endtask

    // Task to send a single bit respecting the ready/valid handshake
    task automatic send_bit(input bit_val);
        begin
            @(posedge can_clk);
            while (!tx_bit_in_ready) begin
                @(posedge can_clk);
            end
            tx_bit_in       <= bit_val;
            tx_bit_in_valid <= 1'b1;
            @(posedge can_clk);
            tx_bit_in_valid <= 1'b0;
        end
    endtask

    // Task to send multiple identical bits
    task automatic send_run(input bit_val, input integer count);
        integer i;
        begin
            for (i = 0; i < count; i = i + 1) begin
                send_bit(bit_val);
            end
        end
    endtask

    // Task to verify captured bits
    task automatic check_sequence(
        input [63:0] expected_bits,
        input [63:0] expected_stuff,
        input integer expected_len,
        input [8*32-1:0] test_name
    );
        integer k;
        reg fail;
        begin
            fail = 0;
            if (out_bit_count !== expected_len) begin
                $display("[TB ERROR] %0s: Length mismatch! Expected %0d bits, got %0d bits",
                         test_name, expected_len, out_bit_count);
                fail = 1;
            end else begin
                for (k = 0; k < expected_len; k = k + 1) begin
                    if (captured_bits[k] !== expected_bits[k]) begin
                        $display("[TB ERROR] %0s: Bit[%0d] mismatch! Expected %b, got %b",
                                 test_name, k, expected_bits[k], captured_bits[k]);
                        fail = 1;
                    end
                    if (captured_stuffed[k] !== expected_stuff[k]) begin
                        $display("[TB ERROR] %0s: StuffFlag[%0d] mismatch! Expected %b, got %b",
                                 test_name, k, expected_stuff[k], captured_stuffed[k]);
                        fail = 1;
                    end
                end
            end

            if (fail) begin
                errors = errors + 1;
            end else begin
                $display("[TB] %0s: PASSED (%0d bits verified)", test_name, expected_len);
            end
        end
    endtask

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_bit_stuff.vcd");
`endif
        $dumpvars(0, tb_bit_stuff);

        // Initialize signals
        can_clk         = 0;
        can_rst_n_sync  = 0;
        stuff_en        = 1;
        stuff_reset     = 0;
        tx_bit_in       = 1'b1;
        tx_bit_in_valid = 0;
        clear_capture();

        // Reset DUT
        #20;
        @(posedge can_clk);
        can_rst_n_sync = 1;
        @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 1: Send 5 zeros with stuffing enabled -> expect 0,0,0,0,0,1(stuff)
        //-------------------------------------------------------------
        $display("[TB] Running Test 1: 5 dominant bits -> stuffed recessive bit...");
        clear_capture();
        send_run(1'b0, 5);
        repeat (3) @(posedge can_clk);
        // Expected bits: bit0=0, bit1=0, bit2=0, bit3=0, bit4=0, bit5=1
        // Expected stuff flags: bit0=0, bit1=0, bit2=0, bit3=0, bit4=0, bit5=1
        check_sequence(64'b100000, 64'b100000, 6, "Test 1 (5 zeros + stuff 1)");

        //-------------------------------------------------------------
        // Test 2: Send 5 ones with stuffing enabled -> expect 1,1,1,1,1,0(stuff)
        //-------------------------------------------------------------
        $display("[TB] Running Test 2: 5 recessive bits -> stuffed dominant bit...");
        clear_capture();
        stuff_reset <= 1'b1;
        @(posedge can_clk);
        stuff_reset <= 1'b0;
        @(posedge can_clk);

        send_run(1'b1, 5);
        repeat (3) @(posedge can_clk);
        // Expected bits: 1,1,1,1,1,0(stuff) -> 6'b011111
        // Expected stuff: 0,0,0,0,0,1 -> 6'b100000
        check_sequence(64'b011111, 64'b100000, 6, "Test 2 (5 ones + stuff 0)");

        //-------------------------------------------------------------
        // Test 3: Send 10 zeros -> expect 00000 1(stuff) 00000 1(stuff) = 12 bits
        //-------------------------------------------------------------
        $display("[TB] Running Test 3: 10 consecutive zeros...");
        clear_capture();
        stuff_reset <= 1'b1;
        @(posedge can_clk);
        stuff_reset <= 1'b0;
        @(posedge can_clk);

        send_run(1'b0, 10);
        repeat (3) @(posedge can_clk);
        // Bit index 0..5:  0,0,0,0,0, 1(stuff)
        // Bit index 6..11: 0,0,0,0,0, 1(stuff)
        // Binary representation (MSB at index 11): 12'b100000_100000
        check_sequence(64'b100000_100000, 64'b100000_100000, 12, "Test 3 (10 zeros -> two stuff bits)");

        //-------------------------------------------------------------
        // Test 4: Disable stuffing (stuff_en = 0) and send 6 zeros
        //-------------------------------------------------------------
        $display("[TB] Running Test 4: Stuffing disabled (6 zeros)...");
        clear_capture();
        stuff_en <= 1'b0;
        @(posedge can_clk);

        send_run(1'b0, 6);
        repeat (3) @(posedge can_clk);
        check_sequence(64'b000000, 64'b000000, 6, "Test 4 (Stuffing disabled)");

        //-------------------------------------------------------------
        // Test 5: Re-enable stuffing and send alternating bits (01010101)
        //-------------------------------------------------------------
        $display("[TB] Running Test 5: Alternating bits (01010101)...");
        clear_capture();
        stuff_en <= 1'b1;
        stuff_reset <= 1'b1;
        @(posedge can_clk);
        stuff_reset <= 1'b0;
        @(posedge can_clk);

        send_bit(1'b0);
        send_bit(1'b1);
        send_bit(1'b0);
        send_bit(1'b1);
        send_bit(1'b0);
        send_bit(1'b1);
        send_bit(1'b0);
        send_bit(1'b1);
        repeat (3) @(posedge can_clk);
        // Bit 0=0, 1=1, 2=0, 3=1, 4=0, 5=1, 6=0, 7=1 -> 8'b10101010
        check_sequence(64'b10101010, 64'b00000000, 8, "Test 5 (Alternating bits)");

        //-------------------------------------------------------------
        // Summary
        //-------------------------------------------------------------
        repeat (5) @(posedge can_clk);
        if (errors == 0) begin
            $display("\n=======================================================");
            $display("   ALL BIT_STUFF TESTS PASSED SUCCESSFULLY!           ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("   BIT_STUFF TESTS FAILED WITH %0d ERRORS!             ", errors);
            $display("=======================================================\n");
        end

        $finish;
    end

endmodule
