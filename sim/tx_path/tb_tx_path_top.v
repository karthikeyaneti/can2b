`timescale 1ns / 1ps

module tb_tx_path_top;

    // Clocks and Resets
    reg         pclk;
    reg         presetn;
    reg         can_clk;
    reg         can_rst_n;

    // APB domain TX write interface
    reg         tx_wr_en;
    reg  [28:0] tx_wr_id;
    reg         tx_wr_ide;
    reg         tx_wr_rtr;
    reg  [3:0]  tx_wr_dlc;
    reg  [63:0] tx_wr_data;
    wire        tx_fifo_full;

    // BTL interface & configuration
    reg         config_mode;
    reg  [4:0]  brp;
    reg  [3:0]  tseg1;
    reg  [2:0]  tseg2;
    reg  [1:0]  sjw;

    wire        sample_point;
    wire        sampled_bit;
    wire        bit_tick;
    wire        tx_active;
    wire        bus_idle;
    wire        can_tx;

    wire        tx_success_pulse;
    wire        tx_error_pulse;
    wire        tx_arblst_pulse;
    wire        tx_busy;
    wire        tx_fifo_empty;

    // Bus Simulation Signals
    reg         auto_ack;
    reg         inject_arblst;
    wire        can_rx_wire;

    integer errors = 0;

    // Synchronized resets
    wire pclk_rst_n_sync;
    wire can_rst_n_sync;

    reset_synchronizer u_pclk_rst_sync (
        .clk        (pclk),
        .rst_n_async(presetn),
        .rst_n_sync (pclk_rst_n_sync)
    );

    reset_synchronizer u_can_rst_sync (
        .clk        (can_clk),
        .rst_n_async(can_rst_n),
        .rst_n_sync (can_rst_n_sync)
    );

    // Instantiate Bit Timing Logic Subsystem (BTL)
    can_btl_top u_btl (
        .can_clk        (can_clk),
        .can_rst_n      (can_rst_n),
        .config_mode    (config_mode),
        .brp            (brp),
        .tseg1          (tseg1),
        .tseg2          (tseg2),
        .sjw            (sjw),
        .rx_in          (can_rx_wire),
        .bus_idle       (bus_idle),
        .tx_active      (tx_active),
        .tx_bit         (can_tx),
        .hard_sync_pulse(),
        .resync_pulse   (),
        .sample_point   (sample_point),
        .sampled_bit    (sampled_bit),
        .bit_tick       (bit_tick)
    );

    // Instantiate DUT: tx_path_top
    tx_path_top #(
        .FIFO_ADDR_WIDTH(4)
    ) dut_tx_path (
        .pclk             (pclk),
        .presetn          (pclk_rst_n_sync),
        .tx_wr_en         (tx_wr_en),
        .tx_wr_id         (tx_wr_id),
        .tx_wr_ide        (tx_wr_ide),
        .tx_wr_rtr        (tx_wr_rtr),
        .tx_wr_dlc        (tx_wr_dlc),
        .tx_wr_data       (tx_wr_data),
        .tx_fifo_full     (tx_fifo_full),

        .can_clk          (can_clk),
        .can_rst_n_sync   (can_rst_n_sync),
        .sample_point     (sample_point),
        .sampled_bit      (sampled_bit),
        .bit_tick         (bit_tick),
        .tx_active        (tx_active),
        .bus_idle         (bus_idle),
        .can_tx           (can_tx),

        .tx_success_pulse (tx_success_pulse),
        .tx_error_pulse   (tx_error_pulse),
        .tx_arblst_pulse  (tx_arblst_pulse),
        .tx_busy          (tx_busy),
        .tx_fifo_empty    (tx_fifo_empty)
    );

    // Clock Generation: pclk = 100MHz (10ns), can_clk = 80MHz (12.5ns)
    always #5    pclk    = ~pclk;
    always #6.25 can_clk = ~can_clk;

    // Bus model: In ACK slot (when dut_tx_path.u_can_bsp.state == ST_ACK_SLOT),
    // if auto_ack is 1, external nodes drive dominant 0 onto the wire.
    // If inject_arblst is 1, opponent node drives dominant 0.
    wire in_ack_slot = (dut_tx_path.u_can_bsp.state == 5'd12);
    assign can_rx_wire = inject_arblst ? 1'b0 :
                         (in_ack_slot && auto_ack) ? 1'b0 : can_tx;

    // Task to write a frame from APB / host side
    task automatic write_frame(
        input [28:0] id,
        input        ide,
        input        rtr,
        input [3:0]  dlc,
        input [63:0] data
    );
        begin
            @(posedge pclk);
            while (tx_fifo_full) @(posedge pclk);
            tx_wr_en   <= 1'b1;
            tx_wr_id   <= id;
            tx_wr_ide  <= ide;
            tx_wr_rtr  <= rtr;
            tx_wr_dlc  <= dlc;
            tx_wr_data <= data;
            @(posedge pclk);
            tx_wr_en   <= 1'b0;
            tx_wr_data <= 64'hx;
        end
    endtask

    // Task to wait for frame transmission completion
    task automatic wait_for_tx(output succ, output err, output arb, input integer max_cycles);
        integer count;
        begin
            count = 0;
            succ  = 0;
            err   = 0;
            arb   = 0;

            while (!succ && !err && !arb && count < max_cycles) begin
                @(posedge can_clk);
                if (tx_success_pulse) succ = 1;
                if (tx_error_pulse)   err  = 1;
                if (tx_arblst_pulse)  arb  = 1;
                count = count + 1;
            end

            if (count >= max_cycles) begin
                $display("[TB ERROR] Timeout (%0d cycles) waiting for TX completion!", max_cycles);
                errors = errors + 1;
            end
        end
    endtask

    reg succ_flag, err_flag, arb_flag;
    integer i;

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_tx_path_top.vcd");
`endif
        $dumpvars(0, tb_tx_path_top);

        pclk          = 0;
        presetn       = 0;
        can_clk       = 0;
        can_rst_n     = 0;
        config_mode   = 1;
        brp           = 5'd0; // 1 TQ = 1 can_clk cycle
        tseg1         = 4'd5; // TSEG1 = 6 TQ
        tseg2         = 2'd2; // TSEG2 = 3 TQ -> Bit time = 1 + 6 + 3 = 10 TQ
        sjw           = 2'd1;

        tx_wr_en      = 0;
        tx_wr_id      = 0;
        tx_wr_ide     = 0;
        tx_wr_rtr     = 0;
        tx_wr_dlc     = 0;
        tx_wr_data    = 0;

        auto_ack      = 1;
        inject_arblst = 0;

        // Reset Sequence
        #50;
        @(posedge pclk);
        presetn   <= 1'b1;
        can_rst_n <= 1'b1;
        repeat (10) @(posedge can_clk);

        // Leave config mode -> Start CAN engine
        config_mode <= 1'b0;
        repeat (20) @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 1: Standard CAN 2.0A Frame (ID=0x555, DLC=1, Data=0xAA)
        //-------------------------------------------------------------
        $display("[TB] Test 1: Transmitting Standard CAN 2.0A Frame (ID=0x555, DLC=1, Data=0xAA)...");
        write_frame(29'h555, 1'b0, 1'b0, 4'd1, 64'hAA00_0000_0000_0000);

        wait_for_tx(succ_flag, err_flag, arb_flag, 5000);
        if (succ_flag && !err_flag && !arb_flag) begin
            $display("[TB] Test 1: Standard Frame Transmitted SUCCESSFULLY!");
        end else begin
            $display("[TB ERROR] Test 1 FAILED! succ=%b err=%b arb=%b", succ_flag, err_flag, arb_flag);
            errors = errors + 1;
        end

        repeat (20) @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 2: Burst of 3 Back-to-Back Frames
        //-------------------------------------------------------------
        $display("[TB] Test 2: Writing Burst of 3 Frames into TX FIFO...");
        // Frame 1: Standard Data Frame (ID=0x123, DLC=2, Data=0x1234)
        write_frame(29'h123, 1'b0, 1'b0, 4'd2, 64'h1234_0000_0000_0000);
        // Frame 2: Extended Data Frame (ID=0x18ABCDEF, IDE=1, DLC=4, Data=0xDEADBEEF)
        write_frame(29'h18ABCDEF, 1'b1, 1'b0, 4'd4, 64'hDEAD_BEEF_0000_0000);
        // Frame 3: Standard Remote Frame (ID=0x7AA, RTR=1, DLC=8)
        write_frame(29'h7AA, 1'b0, 1'b1, 4'd8, 64'h0);

        $display("[TB] Waiting for Frame 1 completion...");
        wait_for_tx(succ_flag, err_flag, arb_flag, 5000);
        if (!succ_flag) errors = errors + 1;
        else $display("[TB] Frame 1 (Standard) finished successfully.");

        $display("[TB] Waiting for Frame 2 completion...");
        wait_for_tx(succ_flag, err_flag, arb_flag, 5000);
        if (!succ_flag) errors = errors + 1;
        else $display("[TB] Frame 2 (Extended) finished successfully.");

        $display("[TB] Waiting for Frame 3 completion...");
        wait_for_tx(succ_flag, err_flag, arb_flag, 5000);
        if (!succ_flag) errors = errors + 1;
        else $display("[TB] Frame 3 (Remote) finished successfully.");

        repeat (30) @(posedge can_clk);
        if (!tx_fifo_empty) begin
            $display("[TB ERROR] TX FIFO not empty after burst drain!");
            errors = errors + 1;
        end else begin
            $display("[TB] Test 2: Burst Transmission PASSED!");
        end

        //-------------------------------------------------------------
        // Test 3: Bit Stuffing Verification on Frame with 5 Consecutive Zeros
        //-------------------------------------------------------------
        $display("[TB] Test 3: Bit Stuffing Frame (ID=0x000, DLC=1, Data=0x00)...");
        write_frame(29'h000, 1'b0, 1'b0, 4'd1, 64'h0000_0000_0000_0000);

        wait_for_tx(succ_flag, err_flag, arb_flag, 5000);
        if (succ_flag && !err_flag) begin
            $display("[TB] Test 3: Bit Stuffing Frame PASSED!");
        end else begin
            $display("[TB ERROR] Test 3 FAILED! succ=%b err=%b", succ_flag, err_flag);
            errors = errors + 1;
        end

        repeat (20) @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 4: Arbitration Loss & Recovery
        //-------------------------------------------------------------
        $display("[TB] Test 4: Testing Arbitration Loss & Automatic Recovery...");
        inject_arblst = 1'b1; // Opponent forces dominant on ID
        write_frame(29'h7FF, 1'b0, 1'b0, 4'd1, 64'hFF00_0000_0000_0000);

        wait_for_tx(succ_flag, err_flag, arb_flag, 5000);
        if (arb_flag && !succ_flag) begin
            $display("[TB] Arbitration loss triggered as expected.");
        end else begin
            $display("[TB ERROR] Arbitration loss was not triggered! succ=%b arb=%b", succ_flag, arb_flag);
            errors = errors + 1;
        end

        // Release opponent line so node can transmit cleanly
        repeat (30) @(posedge can_clk);
        inject_arblst = 1'b0;

        // Frame should still be in FIFO and will be transmitted when bus is idle
        $display("[TB] Waiting for retransmission after arbitration yield...");
        wait_for_tx(succ_flag, err_flag, arb_flag, 5000);
        if (succ_flag && !err_flag) begin
            $display("[TB] Test 4: Retransmission after Arbitration Yield PASSED!");
        end else begin
            $display("[TB ERROR] Retransmission FAILED! succ=%b err=%b", succ_flag, err_flag);
            errors = errors + 1;
        end

        repeat (20) @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 5: Fill FIFO (Capacity Test)
        //-------------------------------------------------------------
        $display("[TB] Test 5: Full FIFO Capacity & Sequential Drain...");
        for (i = 0; i < 8; i = i + 1) begin
            write_frame(29'h200 + i, 1'b0, 1'b0, 4'd2, 64'hBEEF_0000_0000_0000 + i);
        end

        for (i = 0; i < 8; i = i + 1) begin
            wait_for_tx(succ_flag, err_flag, arb_flag, 5000);
            if (!succ_flag) begin
                $display("[TB ERROR] Frame %0d in capacity test failed!", i);
                errors = errors + 1;
            end
        end

        repeat (40) @(posedge can_clk);
        if (tx_fifo_empty) begin
            $display("[TB] Test 5: Capacity & Multi-Frame Drain PASSED!");
        end else begin
            $display("[TB ERROR] TX FIFO not empty after draining all frames!");
            errors = errors + 1;
        end

        //-------------------------------------------------------------
        // Summary
        //-------------------------------------------------------------
        repeat (20) @(posedge can_clk);
        if (errors == 0) begin
            $display("\n=======================================================");
            $display("   ALL TX_PATH_TOP TESTS PASSED SUCCESSFULLY!          ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("   TX_PATH_TOP TESTS FAILED WITH %0d ERRORS!           ", errors);
            $display("=======================================================\n");
        end

        $finish;
    end

endmodule
