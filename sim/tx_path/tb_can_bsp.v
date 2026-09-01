`timescale 1ns / 1ps

module tb_can_bsp;

    reg         can_clk;
    reg         can_rst_n_sync;

    wire        sample_point;
    wire        sampled_bit_wire;
    wire        bit_tick;
    wire        tx_active;
    wire        bus_idle;
    wire        can_tx_bit;

    reg         tx_frame_avail;
    reg  [28:0] tx_rd_id;
    reg         tx_rd_ide;
    reg         tx_rd_rtr;
    reg  [3:0]  tx_rd_dlc;
    reg  [63:0] tx_rd_data;
    wire        tx_rd_en;

    wire        crc_clear;
    wire        crc_update_en;
    wire        crc_bit_in;
    wire [14:0] crc_value;

    wire        tx_success_pulse;
    wire        tx_error_pulse;
    wire        tx_arblst_pulse;
    wire        rx_ok_pulse;
    wire        tx_busy;

    wire [7:0]  tec;
    wire [7:0]  rec;
    wire [1:0]  estat;
    wire        errwrn;
    wire        bus_off_w;
    wire        err_acker;
    wire        err_berr;
    wire        err_ster;
    wire        err_fmer;
    wire        err_crcer;

    wire        destuff_en;
    wire        destuff_reset;
    wire        rx_frame_valid;
    wire [31:0] rx_frame_idr;
    wire [31:0] rx_frame_dlcr;
    wire [31:0] rx_frame_dw1r;
    wire [31:0] rx_frame_dw2r;

    integer errors = 0;

    // RX path connections
    wire destuffed_bit_out;
    wire destuffed_bit_valid;
    wire stuff_bit_dropped;
    wire stuff_error;

    // Instantiate DUT (can_bsp)
    can_bsp u_bsp (
        .can_clk            (can_clk),
        .can_rst_n_sync     (can_rst_n_sync),
        .sample_point       (sample_point),
        .sampled_bit        (sampled_bit_wire),
        .bit_tick           (bit_tick),
        .tx_active          (tx_active),
        .bus_idle           (bus_idle),
        .can_tx_bit         (can_tx_bit),

        .cen                (1'b1),
        .lback_mode         (1'b0),
        .sleep_mode         (1'b0),

        .tx_frame_avail     (tx_frame_avail),
        .tx_rd_id           (tx_rd_id),
        .tx_rd_ide          (tx_rd_ide),
        .tx_rd_rtr          (tx_rd_rtr),
        .tx_rd_dlc          (tx_rd_dlc),
        .tx_rd_data         (tx_rd_data),
        .tx_rd_en           (tx_rd_en),

        .crc_clear          (crc_clear),
        .crc_update_en      (crc_update_en),
        .crc_bit_in         (crc_bit_in),
        .crc_value          (crc_value),

        .destuffed_bit_out  (destuffed_bit_out),
        .destuffed_bit_valid(destuffed_bit_valid),
        .stuff_bit_dropped  (stuff_bit_dropped),
        .stuff_error        (stuff_error),
        .destuff_en         (destuff_en),
        .destuff_reset      (destuff_reset),

        .rx_frame_valid     (rx_frame_valid),
        .rx_frame_idr       (rx_frame_idr),
        .rx_frame_dlcr      (rx_frame_dlcr),
        .rx_frame_dw1r      (rx_frame_dw1r),
        .rx_frame_dw2r      (rx_frame_dw2r),

        .tx_success_pulse   (tx_success_pulse),
        .tx_error_pulse     (tx_error_pulse),
        .tx_arblst_pulse    (tx_arblst_pulse),
        .rx_ok_pulse        (rx_ok_pulse),
        .tx_busy            (tx_busy),

        .tec                (tec),
        .rec                (rec),
        .estat              (estat),
        .errwrn             (errwrn),
        .bus_off            (bus_off_w),

        .err_acker          (err_acker),
        .err_berr           (err_berr),
        .err_ster           (err_ster),
        .err_fmer           (err_fmer),
        .err_crcer          (err_crcer)
    );

    // Instantiate CRC Generator
    crc_gen u_crc_gen (
        .can_clk        (can_clk),
        .can_rst_n_sync (can_rst_n_sync),
        .bit_in         (crc_bit_in),
        .bit_in_valid   (crc_update_en),
        .bit_in_ready   (),
        .crc_clear      (crc_clear),
        .crc_update_en  (crc_update_en),
        .crc_emit_en    (1'b0),
        .bit_out        (),
        .bit_out_valid  (),
        .crc_emit_done  (),
        .crc_value      (crc_value)
    );

    // Bit De-stuffer for RX engine
    bit_destuff u_destuff (
        .can_clk            (can_clk),
        .can_rst_n_sync     (can_rst_n_sync),
        .sample_point       (sample_point),
        .destuff_en         (destuff_en),
        .destuff_reset      (destuff_reset),
        .raw_bit_in         (sampled_bit_wire),
        .destuffed_bit_out   (destuffed_bit_out),
        .destuffed_bit_valid (destuffed_bit_valid),
        .stuff_bit_dropped   (stuff_bit_dropped),
        .stuff_error         (stuff_error)
    );

    // 100MHz clock (10ns period)
    always #5 can_clk = ~can_clk;

    // Bit timing generator: 1 bit = 10 clock cycles (100ns)
    reg [3:0] tq_counter;
    reg       sample_point_reg;
    reg       bit_tick_reg;
    reg       auto_ack;
    reg       force_arblst;
    reg       force_bit_err;

    assign sample_point = sample_point_reg;
    assign bit_tick     = bit_tick_reg;

    always @(posedge can_clk) begin
        if (!can_rst_n_sync) begin
            tq_counter       <= 4'd0;
            sample_point_reg <= 1'b0;
            bit_tick_reg     <= 1'b0;
        end else begin
            sample_point_reg <= 1'b0;
            bit_tick_reg     <= 1'b0;

            if (tq_counter == 4'd6) begin
                sample_point_reg <= 1'b1;
                tq_counter       <= tq_counter + 4'd1;
            end else if (tq_counter == 4'd9) begin
                bit_tick_reg <= 1'b1;
                tq_counter   <= 4'd0;
            end else begin
                tq_counter <= tq_counter + 4'd1;
            end
        end
    end

    // Physical CAN Bus Transceiver wire model
    wire bus_ack_slot = (u_bsp.state == 5'd12); // ST_ACK_SLOT
    assign sampled_bit_wire = force_arblst   ? 1'b0 :
                              force_bit_err  ? ~can_tx_bit :
                              bus_ack_slot   ? (auto_ack ? 1'b0 : 1'b1) :
                                               can_tx_bit;

    // Helper task to wait for frame transmission completion
    task automatic wait_for_completion(output success, output error, output arblst);
        integer timeout;
        begin
            timeout = 0;
            success = 0;
            error   = 0;
            arblst  = 0;

            while (!success && !error && !arblst && timeout < 20000) begin
                @(posedge can_clk);
                if (tx_success_pulse) success = 1;
                if (tx_error_pulse)   error   = 1;
                if (tx_arblst_pulse)  arblst  = 1;
                timeout = timeout + 1;
            end

            if (timeout >= 20000) begin
                $display("[TB ERROR] Timeout waiting for frame completion!");
                errors = errors + 1;
            end
        end
    endtask

    reg done_succ, done_err, done_arb;

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_can_bsp.vcd");
`endif
        $dumpvars(0, tb_can_bsp);

        can_clk        = 0;
        can_rst_n_sync = 0;
        tx_frame_avail = 0;
        tx_rd_id       = 0;
        tx_rd_ide      = 0;
        tx_rd_rtr      = 0;
        tx_rd_dlc      = 0;
        tx_rd_data     = 0;
        auto_ack       = 1;
        force_arblst   = 0;
        force_bit_err  = 0;

        // Reset
        #30;
        @(posedge can_clk);
        can_rst_n_sync = 1;
        @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 1: Standard CAN 2.0A Frame (ID=0x555, DLC=1, Data=0xAA)
        //-------------------------------------------------------------
        $display("[TB] Test 1: Transmitting Standard CAN 2.0A Frame (ID=0x555, DLC=1, Data=0xAA)...");
        @(posedge can_clk);
        tx_rd_id       <= 29'h555;
        tx_rd_ide      <= 1'b0;
        tx_rd_rtr      <= 1'b0;
        tx_rd_dlc      <= 4'd1;
        tx_rd_data     <= 64'hAA00_0000_0000_0000;
        tx_frame_avail <= 1'b1;

        wait_for_completion(done_succ, done_err, done_arb);
        if (done_succ && !done_err && !done_arb) begin
            $display("[TB] Test 1: Standard Frame Transmitted SUCCESSFULLY!");
        end else begin
            $display("[TB ERROR] Test 1 FAILED! succ=%b err=%b arb=%b", done_succ, done_err, done_arb);
            errors = errors + 1;
        end

        tx_frame_avail <= 1'b0;
        repeat (20) @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 2: Standard CAN Frame with Stuffing (ID=0x000)
        //-------------------------------------------------------------
        $display("[TB] Test 2: Transmitting Standard CAN Frame with Bit Stuffing (ID=0x000)...");
        @(posedge can_clk);
        tx_rd_id       <= 29'h000;
        tx_rd_ide      <= 1'b0;
        tx_rd_rtr      <= 1'b0;
        tx_rd_dlc      <= 4'd1;
        tx_rd_data     <= 64'h0000_0000_0000_0000;
        tx_frame_avail <= 1'b1;

        wait_for_completion(done_succ, done_err, done_arb);
        if (done_succ && !done_err && !done_arb) begin
            $display("[TB] Test 2: Stuffed Frame Transmitted SUCCESSFULLY!");
        end else begin
            $display("[TB ERROR] Test 2 FAILED! succ=%b err=%b arb=%b", done_succ, done_err, done_arb);
            errors = errors + 1;
        end

        tx_frame_avail <= 1'b0;
        repeat (20) @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 3: Extended CAN 2.0B Frame
        //-------------------------------------------------------------
        $display("[TB] Test 3: Transmitting Extended CAN 2.0B Frame (ID=0x1234567, DLC=2)...");
        @(posedge can_clk);
        tx_rd_id       <= 29'h01234567;
        tx_rd_ide      <= 1'b1;
        tx_rd_rtr      <= 1'b0;
        tx_rd_dlc      <= 4'd2;
        tx_rd_data     <= 64'h1234_0000_0000_0000;
        tx_frame_avail <= 1'b1;

        wait_for_completion(done_succ, done_err, done_arb);
        if (done_succ && !done_err && !done_arb) begin
            $display("[TB] Test 3: Extended Frame Transmitted SUCCESSFULLY!");
        end else begin
            $display("[TB ERROR] Test 3 FAILED! succ=%b err=%b arb=%b", done_succ, done_err, done_arb);
            errors = errors + 1;
        end

        tx_frame_avail <= 1'b0;
        repeat (20) @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 4: Remote Frame (RTR=1, DLC=4)
        //-------------------------------------------------------------
        $display("[TB] Test 4: Transmitting Remote Frame (RTR=1, DLC=4)...");
        @(posedge can_clk);
        tx_rd_id       <= 29'h321;
        tx_rd_ide      <= 1'b0;
        tx_rd_rtr      <= 1'b1;
        tx_rd_dlc      <= 4'd4;
        tx_rd_data     <= 64'h0;
        tx_frame_avail <= 1'b1;

        wait_for_completion(done_succ, done_err, done_arb);
        if (done_succ && !done_err && !done_arb) begin
            $display("[TB] Test 4: Remote Frame Transmitted SUCCESSFULLY!");
        end else begin
            $display("[TB ERROR] Test 4 FAILED! succ=%b err=%b arb=%b", done_succ, done_err, done_arb);
            errors = errors + 1;
        end

        tx_frame_avail <= 1'b0;
        repeat (20) @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 5: Arbitration Loss Detection
        //-------------------------------------------------------------
        $display("[TB] Test 5: Testing Arbitration Loss Detection...");
        @(posedge can_clk);
        tx_rd_id       <= 29'h7FF;
        tx_rd_ide      <= 1'b0;
        tx_rd_rtr      <= 1'b0;
        tx_rd_dlc      <= 4'd1;
        tx_rd_data     <= 64'hFF00_0000_0000_0000;
        tx_frame_avail <= 1'b1;
        force_arblst   <= 1'b1;

        wait_for_completion(done_succ, done_err, done_arb);
        if (done_arb && !done_succ) begin
            $display("[TB] Test 5: Arbitration Loss Detected as Expected!");
        end else begin
            $display("[TB ERROR] Test 5 FAILED! succ=%b err=%b arb=%b", done_succ, done_err, done_arb);
            errors = errors + 1;
        end

        force_arblst   <= 1'b0;
        tx_frame_avail <= 1'b0;
        repeat (20) @(posedge can_clk);

        //-------------------------------------------------------------
        // Test 6: ACK Error Detection
        //-------------------------------------------------------------
        $display("[TB] Test 6: Testing ACK Error Detection (No ACK on bus)...");
        auto_ack       <= 1'b0;
        @(posedge can_clk);
        tx_rd_id       <= 29'h123;
        tx_rd_ide      <= 1'b0;
        tx_rd_rtr      <= 1'b0;
        tx_rd_dlc      <= 4'd1;
        tx_rd_data     <= 64'h5500_0000_0000_0000;
        tx_frame_avail <= 1'b1;

        wait_for_completion(done_succ, done_err, done_arb);
        if (done_err && !done_succ) begin
            $display("[TB] Test 6: ACK Error Detected & Error Flag Generated as Expected!");
        end else begin
            $display("[TB ERROR] Test 6 FAILED! succ=%b err=%b arb=%b", done_succ, done_err, done_arb);
            errors = errors + 1;
        end

        auto_ack       <= 1'b1;
        tx_frame_avail <= 1'b0;
        repeat (30) @(posedge can_clk);

        //-------------------------------------------------------------
        // Summary
        //-------------------------------------------------------------
        repeat (10) @(posedge can_clk);
        if (errors == 0) begin
            $display("\n=======================================================");
            $display("   ALL CAN_BSP TESTS PASSED SUCCESSFULLY!              ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("   CAN_BSP TESTS FAILED WITH %0d ERRORS!               ", errors);
            $display("=======================================================\n");
        end

        $finish;
    end

endmodule
