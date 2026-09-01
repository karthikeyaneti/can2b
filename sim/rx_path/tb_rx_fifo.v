`timescale 1ns / 1ps

module tb_rx_fifo;

    reg         wr_clk;
    reg         wr_rst_n;
    reg         rx_push;
    reg  [31:0] rx_push_idr;
    reg  [31:0] rx_push_dlcr;
    reg  [31:0] rx_push_dw1r;
    reg  [31:0] rx_push_dw2r;
    wire        rx_fifo_full;
    wire        rx_overflow_pulse;

    reg         rd_clk;
    reg         rd_rst_n;
    reg         rx_pop;
    wire [31:0] rx_idr;
    wire [31:0] rx_dlcr;
    wire [31:0] rx_dw1r;
    wire [31:0] rx_dw2r;
    wire        rx_empty;
    wire        rx_not_empty;
    wire        rx_underflow_pulse;

    integer errors = 0;

    rx_fifo #(
        .ADDR_WIDTH(4)
    ) dut (
        .wr_clk             (wr_clk),
        .wr_rst_n_sync      (wr_rst_n),
        .rx_push            (rx_push),
        .rx_push_idr        (rx_push_idr),
        .rx_push_dlcr       (rx_push_dlcr),
        .rx_push_dw1r       (rx_push_dw1r),
        .rx_push_dw2r       (rx_push_dw2r),
        .rx_fifo_full       (rx_fifo_full),
        .rx_overflow_pulse  (rx_overflow_pulse),

        .rd_clk             (rd_clk),
        .rd_rst_n_sync      (rd_rst_n),
        .rx_pop             (rx_pop),
        .rx_idr             (rx_idr),
        .rx_dlcr            (rx_dlcr),
        .rx_dw1r            (rx_dw1r),
        .rx_dw2r            (rx_dw2r),
        .rx_empty           (rx_empty),
        .rx_not_empty       (rx_not_empty),
        .rx_underflow_pulse (rx_underflow_pulse)
    );

    always #6.25 wr_clk = ~wr_clk; // 80MHz CAN domain
    always #5    rd_clk = ~rd_clk; // 100MHz APB domain

    task automatic push_msg(
        input [31:0] idr,
        input [31:0] dlcr,
        input [31:0] dw1r,
        input [31:0] dw2r
    );
        begin
            @(posedge wr_clk);
            rx_push      <= 1'b1;
            rx_push_idr  <= idr;
            rx_push_dlcr <= dlcr;
            rx_push_dw1r <= dw1r;
            rx_push_dw2r <= dw2r;
            @(posedge wr_clk);
            rx_push <= 1'b0;
        end
    endtask

    task automatic read_and_pop(
        input [31:0] exp_idr,
        input [31:0] exp_dlcr,
        input [31:0] exp_dw1r,
        input [31:0] exp_dw2r,
        input [8*32-1:0] test_name
    );
        begin
            @(posedge rd_clk);
            while (rx_empty) @(posedge rd_clk);
            if (rx_idr !== exp_idr || rx_dlcr !== exp_dlcr || rx_dw1r !== exp_dw1r || rx_dw2r !== exp_dw2r) begin
                $display("[TB ERROR] %0s mismatch! Got: idr=%h dlcr=%h dw1=%h dw2=%h",
                         test_name, rx_idr, rx_dlcr, rx_dw1r, rx_dw2r);
                errors = errors + 1;
            end else begin
                $display("[TB] %0s verified successfully.", test_name);
            end
            rx_pop <= 1'b1;
            @(posedge rd_clk);
            rx_pop <= 1'b0;
        end
    endtask

    integer i;

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_rx_fifo.vcd");
`endif
        $dumpvars(0, tb_rx_fifo);

        wr_clk   = 0;
        rd_clk   = 0;
        wr_rst_n = 0;
        rd_rst_n = 0;
        rx_push  = 0;
        rx_pop   = 0;

        #20;
        wr_rst_n = 1;
        rd_rst_n = 1;
        repeat (5) @(posedge rd_clk);
        repeat (5) @(posedge wr_clk);

        //-------------------------------------------------------------
        // Test 1: Reset Status
        //-------------------------------------------------------------
        $display("[TB] Test 1: Checking Reset Status...");
        if (!rx_empty || rx_not_empty) begin
            $display("[TB ERROR] RX FIFO not empty after reset!");
            errors = errors + 1;
        end

        //-------------------------------------------------------------
        // Test 2: Push & Read Single Message
        //-------------------------------------------------------------
        $display("[TB] Test 2: Single Message Write & Read...");
        push_msg(32'h24600000, 32'h40000000, 32'hA1B2C3D4, 32'hE5F60718);
        read_and_pop(32'h24600000, 32'h40000000, 32'hA1B2C3D4, 32'hE5F60718, "Test 2 Message");

        repeat (5) @(posedge rd_clk);
        if (!rx_empty) begin
            $display("[TB ERROR] RX FIFO not empty after pop!");
            errors = errors + 1;
        end

        //-------------------------------------------------------------
        // Test 3: Multiple Messages Burst Fill & Drain
        //-------------------------------------------------------------
        $display("[TB] Test 3: Multiple Messages (8 items)...");
        for (i = 0; i < 8; i = i + 1) begin
            push_msg(32'h100 + i, 32'h10000000 + i, 32'hA0000000 + i, 32'hB0000000 + i);
        end

        for (i = 0; i < 8; i = i + 1) begin
            read_and_pop(32'h100 + i, 32'h10000000 + i, 32'hA0000000 + i, 32'hB0000000 + i, "Test 3 Item");
        end

        //-------------------------------------------------------------
        // Test 4: Underflow Test
        //-------------------------------------------------------------
        $display("[TB] Test 4: Underflow on Empty Read...");
        @(posedge rd_clk);
        rx_pop <= 1'b1;
        @(posedge rd_clk);
        rx_pop <= 1'b0;
        #1;
        if (!rx_underflow_pulse) begin
            $display("[TB ERROR] Underflow pulse not asserted!");
            errors = errors + 1;
        end else begin
            $display("[TB] Underflow detected correctly.");
        end

        //-------------------------------------------------------------
        // Summary
        //-------------------------------------------------------------
        repeat (10) @(posedge rd_clk);
        if (errors == 0) begin
            $display("\n=======================================================");
            $display("   ALL RX_FIFO TESTS PASSED SUCCESSFULLY!              ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("   RX_FIFO TESTS FAILED WITH %0d ERRORS!               ", errors);
            $display("=======================================================\n");
        end

        $finish;
    end

endmodule
