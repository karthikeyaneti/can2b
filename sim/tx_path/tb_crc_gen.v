`timescale 1ns / 1ps

module tb_crc_gen;

    reg         can_clk;
    reg         can_rst_n_sync;
    reg         bit_in;
    reg         bit_in_valid;
    wire        bit_in_ready;

    reg         crc_clear;
    reg         crc_update_en;
    reg         crc_emit_en;

    wire        bit_out;
    wire        bit_out_valid;
    wire        crc_emit_done;
    wire [14:0] crc_value;

    // Instantiate DUT
    crc_gen dut (
        .can_clk        (can_clk),
        .can_rst_n_sync  (can_rst_n_sync),
        .bit_in         (bit_in),
        .bit_in_valid   (bit_in_valid),
        .bit_in_ready   (bit_in_ready),
        .crc_clear      (crc_clear),
        .crc_update_en  (crc_update_en),
        .crc_emit_en    (crc_emit_en),
        .bit_out        (bit_out),
        .bit_out_valid  (bit_out_valid),
        .crc_emit_done  (crc_emit_done),
        .crc_value      (crc_value)
    );

    // 100MHz clock generation (10ns period)
    always #5 can_clk = ~can_clk;

    // Task to send a single bit to crc_gen
    task automatic send_bit(input b, input update);
        begin
            @(posedge can_clk);
            while (!bit_in_ready) begin
                @(posedge can_clk);
            end
            bit_in        <= b;
            bit_in_valid  <= 1'b1;
            crc_update_en <= update;
            @(posedge can_clk);
            bit_in_valid  <= 1'b0;
            crc_update_en <= 1'b0;
        end
    endtask

    // Task to send an N-bit vector (MSB first)
    task automatic send_vector(input [63:0] vec, input integer len, input update);
        integer i;
        begin
            for (i = len - 1; i >= 0; i = i - 1) begin
                send_bit(vec[i], update);
            end
        end
    endtask

    reg [14:0] captured_crc;
    integer emit_bit_idx;

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_crc_gen.vcd");
`endif
        $dumpvars(0, tb_crc_gen);

        // Initialize signals
        can_clk        = 0;
        can_rst_n_sync = 0;
        bit_in         = 1'b1;
        bit_in_valid   = 0;
        crc_clear      = 0;
        crc_update_en  = 0;
        crc_emit_en    = 0;

        // Reset DUT
        #20;
        @(posedge can_clk);
        can_rst_n_sync = 1;
        @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 1: Frame A - ID=0x555 (11'b10101010101), RTR=0, IDE=0, r0=0, DLC=1 (4'b0001), Data=0xAA (8'b10101010)
        // Expected CAN CRC-15 = 15'h7802
        //-------------------------------------------------------------
        $display("[TB] Test 1: Sending CAN Frame A (ID=0x555, DLC=1, Data=0xAA)...");
        @(posedge can_clk);
        crc_clear <= 1'b1;
        @(posedge can_clk);
        crc_clear <= 1'b0;

        // SOF (1 bit dominant: 0)
        send_bit(1'b0, 1);
        // ID (11 bits: 0x555)
        send_vector(64'h555, 11, 1);
        // RTR, IDE, r0 (3 bits dominant: 000)
        send_vector(64'h0, 3, 1);
        // DLC (4 bits: 0001)
        send_vector(64'h1, 4, 1);
        // Data byte 0 (8 bits: 0xAA)
        send_vector(64'hAA, 8, 1);

        @(posedge can_clk);
        $display("[TB] Test 1 calculated CRC = 15'h%04x (Expected: 15'h7802)", crc_value);
        if (crc_value !== 15'h7802) begin
            $display("[TB] ERROR: Test 1 CRC mismatch!");
        end else begin
            $display("[TB] Test 1 PASSED!");
        end

        // Test CRC Emission for Frame A
        @(posedge can_clk);
        crc_emit_en <= 1'b1;
        @(posedge can_clk);
        crc_emit_en <= 1'b0;

        // Capture CRC emission
        captured_crc = 15'd0;
        emit_bit_idx = 14;

        while (!crc_emit_done) begin
            @(posedge can_clk);
            if (bit_out_valid) begin
                captured_crc[emit_bit_idx] = bit_out;
                emit_bit_idx = emit_bit_idx - 1;
            end
        end
        if (bit_out_valid && emit_bit_idx >= 0) begin
            captured_crc[emit_bit_idx] = bit_out;
            emit_bit_idx = emit_bit_idx - 1;
        end

        $display("[TB] Emitted CRC sequence = 15'h%04x (Expected: 15'h7802)", captured_crc);
        if (captured_crc !== 15'h7802) begin
            $display("[TB] ERROR: Emitted CRC mismatch!");
        end else begin
            $display("[TB] Emitted CRC check PASSED!");
        end

        // Wait a few cycles
        repeat (5) @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 2: Frame B - ID=0x123 (11'b00100100011), RTR=0, IDE=0, r0=0, DLC=2 (4'b0010), Data=0x12, 0x34
        // Expected CAN CRC-15 = 15'h36B7
        //-------------------------------------------------------------
        $display("[TB] Test 2: Sending CAN Frame B (ID=0x123, DLC=2, Data=0x12, 0x34)...");
        @(posedge can_clk);
        crc_clear <= 1'b1;
        @(posedge can_clk);
        crc_clear <= 1'b0;

        // SOF (0)
        send_bit(1'b0, 1);
        // ID (0x123)
        send_vector(64'h123, 11, 1);
        // RTR(0), IDE(0), r0(0)
        send_vector(64'h0, 3, 1);
        // DLC (2)
        send_vector(64'h2, 4, 1);
        // Data byte 0 (0x12)
        send_vector(64'h12, 8, 1);
        // Data byte 1 (0x34)
        send_vector(64'h34, 8, 1);

        @(posedge can_clk);
        $display("[TB] Test 2 calculated CRC = 15'h%04x (Expected: 15'h36b7)", crc_value);
        if (crc_value !== 15'h36b7) begin
            $display("[TB] ERROR: Test 2 CRC mismatch!");
        end else begin
            $display("[TB] Test 2 PASSED!");
        end

        // Emit CRC for Frame B
        @(posedge can_clk);
        crc_emit_en <= 1'b1;
        @(posedge can_clk);
        crc_emit_en <= 1'b0;

        captured_crc = 15'd0;
        emit_bit_idx = 14;

        while (!crc_emit_done) begin
            @(posedge can_clk);
            if (bit_out_valid) begin
                captured_crc[emit_bit_idx] = bit_out;
                emit_bit_idx = emit_bit_idx - 1;
            end
        end
        if (bit_out_valid && emit_bit_idx >= 0) begin
            captured_crc[emit_bit_idx] = bit_out;
            emit_bit_idx = emit_bit_idx - 1;
        end

        $display("[TB] Emitted CRC sequence = 15'h%04x (Expected: 15'h36b7)", captured_crc);
        if (captured_crc !== 15'h36b7) begin
            $display("[TB] ERROR: Emitted CRC mismatch!");
        end else begin
            $display("[TB] Emitted CRC check PASSED!");
        end

        //-------------------------------------------------------------
        // Test 3: Passthrough without update (crc_update_en = 0)
        //-------------------------------------------------------------
        $display("[TB] Test 3: Verifying passthrough when crc_update_en = 0...");
        @(posedge can_clk);
        crc_clear <= 1'b1;
        @(posedge can_clk);
        crc_clear <= 1'b0;

        send_vector(64'hA5, 8, 0); // Should pass through without changing CRC (stays 0)
        @(posedge can_clk);
        if (crc_value !== 15'h0000) begin
            $display("[TB] ERROR: CRC modified when crc_update_en was 0! Value = 15'h%04x", crc_value);
        end else begin
            $display("[TB] Test 3 PASSED! CRC remained 15'h0000");
        end

        repeat (10) @(posedge can_clk);
        $display("[TB] All tests completed successfully.");
        $finish;
    end

endmodule
