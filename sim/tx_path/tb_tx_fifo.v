`timescale 1ns / 1ps

module tb_tx_fifo;

    localparam ADDR_WIDTH = 4;
    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;

    reg         wr_clk;
    reg         wr_rst_n;
    reg         tx_wr_en;
    reg  [28:0] tx_wr_id;
    reg         tx_wr_ide;
    reg         tx_wr_rtr;
    reg  [3:0]  tx_wr_dlc;
    reg  [63:0] tx_wr_data;
    wire        tx_fifo_full;

    reg         rd_clk;
    reg         rd_rst_n;
    reg         tx_rd_en;
    wire [28:0] tx_rd_id;
    wire        tx_rd_ide;
    wire        tx_rd_rtr;
    wire [3:0]  tx_rd_dlc;
    wire [63:0] tx_rd_data;
    wire        tx_frame_avail;
    wire        tx_fifo_empty;

    integer errors = 0;

    // Instantiate DUT
    tx_fifo #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk        (wr_clk),
        .wr_rst_n_sync (wr_rst_n),
        .tx_wr_en      (tx_wr_en),
        .tx_wr_id      (tx_wr_id),
        .tx_wr_ide     (tx_wr_ide),
        .tx_wr_rtr     (tx_wr_rtr),
        .tx_wr_dlc     (tx_wr_dlc),
        .tx_wr_data    (tx_wr_data),
        .tx_fifo_full  (tx_fifo_full),

        .rd_clk        (rd_clk),
        .rd_rst_n_sync (rd_rst_n),
        .tx_rd_en      (tx_rd_en),
        .tx_rd_id      (tx_rd_id),
        .tx_rd_ide     (tx_rd_ide),
        .tx_rd_rtr     (tx_rd_rtr),
        .tx_rd_dlc     (tx_rd_dlc),
        .tx_rd_data    (tx_rd_data),
        .tx_frame_avail(tx_frame_avail),
        .tx_fifo_empty (tx_fifo_empty)
    );

    // Asynchronous clocks: wr_clk = 100MHz (10ns), rd_clk = 40MHz (25ns)
    always #5 wr_clk = ~wr_clk;
    always #12.5 rd_clk = ~rd_clk;

    // Task to write a frame
    task automatic write_frame(
        input [28:0] id,
        input        ide,
        input        rtr,
        input [3:0]  dlc,
        input [63:0] data
    );
        begin
            @(posedge wr_clk);
            while (tx_fifo_full) @(posedge wr_clk);
            tx_wr_en   <= 1'b1;
            tx_wr_id   <= id;
            tx_wr_ide  <= ide;
            tx_wr_rtr  <= rtr;
            tx_wr_dlc  <= dlc;
            tx_wr_data <= data;
            @(posedge wr_clk);
            tx_wr_en   <= 1'b0;
            tx_wr_data <= 64'hx;
        end
    endtask

    // Task to read and verify frame
    task automatic read_and_check(
        input [28:0] exp_id,
        input        exp_ide,
        input        exp_rtr,
        input [3:0]  exp_dlc,
        input [63:0] exp_data,
        input [8*32-1:0] test_name
    );
        begin
            @(posedge rd_clk);
            while (!tx_frame_avail) @(posedge rd_clk);
            if (tx_rd_id !== exp_id || tx_rd_ide !== exp_ide || tx_rd_rtr !== exp_rtr ||
                tx_rd_dlc !== exp_dlc || tx_rd_data !== exp_data) begin
                $display("[TB ERROR] %0s mismatch at %0t!", test_name, $time);
                $display("  Expected: id=%h ide=%b rtr=%b dlc=%d data=%h", exp_id, exp_ide, exp_rtr, exp_dlc, exp_data);
                $display("  Actual:   id=%h ide=%b rtr=%b dlc=%d data=%h", tx_rd_id, tx_rd_ide, tx_rd_rtr, tx_rd_dlc, tx_rd_data);
                errors = errors + 1;
            end else begin
                $display("[TB] %0s: Readback verified correctly.", test_name);
            end
            tx_rd_en <= 1'b1;
            @(posedge rd_clk);
            tx_rd_en <= 1'b0;
        end
    endtask

    integer i;

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_tx_fifo.vcd");
`endif
        $dumpvars(0, tb_tx_fifo);

        wr_clk     = 0;
        rd_clk     = 0;
        wr_rst_n   = 0;
        rd_rst_n   = 0;
        tx_wr_en   = 0;
        tx_wr_id   = 0;
        tx_wr_ide  = 0;
        tx_wr_rtr  = 0;
        tx_wr_dlc  = 0;
        tx_wr_data = 0;
        tx_rd_en   = 0;

        // Apply reset
        #30;
        wr_rst_n = 1;
        rd_rst_n = 1;

        repeat (4) @(posedge rd_clk);
        repeat (4) @(posedge wr_clk);

        //-------------------------------------------------------------
        // Test 1: Reset Check
        //-------------------------------------------------------------
        $display("[TB] Test 1: Checking Reset Status...");
        if (!tx_fifo_empty || tx_frame_avail) begin
            $display("[TB ERROR] tx_fifo should be empty after reset!");
            errors = errors + 1;
        end
        if (tx_fifo_full) begin
            $display("[TB ERROR] tx_fifo should not be full after reset!");
            errors = errors + 1;
        end

        //-------------------------------------------------------------
        // Test 2: Standard Frame Write & Read
        //-------------------------------------------------------------
        $display("[TB] Test 2: Standard Frame...");
        write_frame(29'h555, 1'b0, 1'b0, 4'd4, 64'h01020304_00000000);
        read_and_check(29'h555, 1'b0, 1'b0, 4'd4, 64'h01020304_00000000, "Test 2 (Standard Frame)");

        repeat (4) @(posedge rd_clk);
        if (!tx_fifo_empty) begin
            $display("[TB ERROR] FIFO not empty after popping single frame!");
            errors = errors + 1;
        end

        //-------------------------------------------------------------
        // Test 3: Extended Remote Frame Write & Read
        //-------------------------------------------------------------
        $display("[TB] Test 3: Extended Remote Frame...");
        write_frame(29'h1ABCDEF0, 1'b1, 1'b1, 4'd8, 64'hFEDCBA9876543210);
        read_and_check(29'h1ABCDEF0, 1'b1, 1'b1, 4'd8, 64'hFEDCBA9876543210, "Test 3 (Extended Remote Frame)");

        //-------------------------------------------------------------
        // Test 4: Fill and Drain FIFO (Full Flag & Capacity Test)
        //-------------------------------------------------------------
        $display("[TB] Test 4: Filling FIFO to Capacity (%0d frames)...", FIFO_DEPTH);
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            write_frame(29'h100 + i, 1'b0, 1'b0, 4'd8, 64'hA000000000000000 + i);
        end

        @(posedge wr_clk);
        if (!tx_fifo_full) begin
            $display("[TB ERROR] FIFO should be full after %0d writes!", FIFO_DEPTH);
            errors = errors + 1;
        end

        $display("[TB] Draining FIFO completely...");
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            read_and_check(29'h100 + i, 1'b0, 1'b0, 4'd8, 64'hA000000000000000 + i, "Test 4 (Drain item)");
        end

        repeat (5) @(posedge wr_clk);
        if (!tx_fifo_empty) begin
            $display("[TB ERROR] FIFO should be empty after drain!");
            errors = errors + 1;
        end

        //-------------------------------------------------------------
        // Summary
        //-------------------------------------------------------------
        repeat (10) @(posedge wr_clk);
        if (errors == 0) begin
            $display("\n=======================================================");
            $display("   ALL TX_FIFO TESTS PASSED SUCCESSFULLY!              ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("   TX_FIFO TESTS FAILED WITH %0d ERRORS!               ", errors);
            $display("=======================================================\n");
        end

        $finish;
    end

endmodule
