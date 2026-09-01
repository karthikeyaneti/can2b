`timescale 1ns / 1ps

module tb_apb_interface;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    reg                     pclk;
    reg                     presetn;

    // APB interface signals
    reg                     psel;
    reg  [ADDR_WIDTH-1:0]   paddr;
    reg  [DATA_WIDTH-1:0]   pwdata;
    reg                     pwrite;
    reg                     penable;

    wire [DATA_WIDTH-1:0]   prdata;
    wire                    pready;
    wire                    pslverr;

    // Status inputs from CAN core
    reg                     tx_busy;
    reg                     tx_fifo_full;
    reg                     tx_hpb_full;
    reg                     rx_not_empty;
    reg                     rx_fifo_full;
    reg                     rx_underflow;
    reg                     rx_ok;
    reg                     tx_ok;
    reg                     arblst;
    reg                     bus_off;
    reg                     error_status;
    reg                     sleep_mode_entered;
    reg                     wakeup_event;
    reg                     error_warning;
    reg  [1:0]              estat;
    reg  [7:0]              tec;
    reg  [7:0]              rec;
    reg                     bus_idle;
    reg                     bus_busy;
    reg                     acfb_busy;

    // Error flags
    reg                     err_acker;
    reg                     err_berr;
    reg                     err_ster;
    reg                     err_fmer;
    reg                     err_crcer;

    // RX FIFO data
    reg  [10:0]             rx_id;
    reg  [17:0]             rx_ext_id;
    reg                     rx_ide;
    reg                     rx_rtr;
    reg  [3:0]              rx_dlc;
    reg  [31:0]             rx_data0;
    reg  [31:0]             rx_data1;

    // Config outputs
    wire                    srst;
    wire                    cen;
    wire                    lback;
    wire                    sleep;
    wire [7:0]              brp;
    wire [3:0]              tseg1;
    wire [2:0]              tseg2;
    wire [1:0]              sjw;
    wire                    irq;

    // TX FIFO outputs
    wire                    tx_write;
    wire                    tx_hpb_write;
    wire [10:0]             tx_id;
    wire [17:0]             tx_ext_id;
    wire                    tx_ide;
    wire                    tx_rtr;
    wire [3:0]              tx_dlc;
    wire [31:0]             tx_data0;
    wire [31:0]             tx_data1;

    // TX HPB outputs
    wire [10:0]             tx_hpb_id;
    wire [17:0]             tx_hpb_ext_id;
    wire                    tx_hpb_ide;
    wire                    tx_hpb_rtr;
    wire [3:0]              tx_hpb_dlc;
    wire [31:0]             tx_hpb_data0;
    wire [31:0]             tx_hpb_data1;

    // Acceptance filter outputs
    wire [3:0]              afr_uaf;
    wire [31:0]             afmr1, afir1;
    wire [31:0]             afmr2, afir2;
    wire [31:0]             afmr3, afir3;
    wire [31:0]             afmr4, afir4;

    // Instantiate DUT
    apb_interface #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .pclk               (pclk),
        .presetn            (presetn),
        .psel               (psel),
        .paddr              (paddr),
        .pwdata             (pwdata),
        .pwrite             (pwrite),
        .penable            (penable),
        .prdata             (prdata),
        .pready             (pready),
        .pslverr            (pslverr),
        .tx_busy            (tx_busy),
        .tx_fifo_full       (tx_fifo_full),
        .tx_hpb_full        (tx_hpb_full),
        .rx_not_empty       (rx_not_empty),
        .rx_fifo_full       (rx_fifo_full),
        .rx_underflow       (rx_underflow),
        .rx_ok              (rx_ok),
        .tx_ok              (tx_ok),
        .arblst             (arblst),
        .bus_off            (bus_off),
        .error_status       (error_status),
        .sleep_mode_entered (sleep_mode_entered),
        .wakeup_event       (wakeup_event),
        .error_warning      (error_warning),
        .estat              (estat),
        .tec                (tec),
        .rec                (rec),
        .bus_idle           (bus_idle),
        .bus_busy           (bus_busy),
        .acfb_busy          (acfb_busy),
        .err_acker          (err_acker),
        .err_berr           (err_berr),
        .err_ster           (err_ster),
        .err_fmer           (err_fmer),
        .err_crcer          (err_crcer),
        .rx_id              (rx_id),
        .rx_ext_id          (rx_ext_id),
        .rx_ide             (rx_ide),
        .rx_rtr             (rx_rtr),
        .rx_dlc             (rx_dlc),
        .rx_data0           (rx_data0),
        .rx_data1           (rx_data1),
        .srst               (srst),
        .cen                (cen),
        .lback              (lback),
        .sleep              (sleep),
        .brp                (brp),
        .tseg1              (tseg1),
        .tseg2              (tseg2),
        .sjw                (sjw),
        .irq                (irq),
        .tx_write           (tx_write),
        .tx_hpb_write       (tx_hpb_write),
        .tx_id              (tx_id),
        .tx_ext_id          (tx_ext_id),
        .tx_ide             (tx_ide),
        .tx_rtr             (tx_rtr),
        .tx_dlc             (tx_dlc),
        .tx_data0           (tx_data0),
        .tx_data1           (tx_data1),
        .tx_hpb_id          (tx_hpb_id),
        .tx_hpb_ext_id      (tx_hpb_ext_id),
        .tx_hpb_ide         (tx_hpb_ide),
        .tx_hpb_rtr         (tx_hpb_rtr),
        .tx_hpb_dlc         (tx_hpb_dlc),
        .tx_hpb_data0       (tx_hpb_data0),
        .tx_hpb_data1       (tx_hpb_data1),
        .afr_uaf            (afr_uaf),
        .afmr1              (afmr1),
        .afir1              (afir1),
        .afmr2              (afmr2),
        .afir2              (afir2),
        .afmr3              (afmr3),
        .afir3              (afir3),
        .afmr4              (afmr4),
        .afir4              (afir4)
    );

    // 100MHz clock
    always #5 pclk = ~pclk;

    integer err_count = 0;

    // APB standard 2-cycle write task
    task automatic apb_write(
        input  [31:0] addr,
        input  [31:0] data,
        output        error
    );
        begin
            // Setup Phase (T1)
            @(posedge pclk);
            psel    <= 1'b1;
            penable <= 1'b0;
            paddr   <= addr;
            pwrite  <= 1'b1;
            pwdata  <= data;

            // Access Phase (T2)
            @(posedge pclk);
            penable <= 1'b1;
            #1;
            if (!pready) begin
                $display("[TB] ERROR: PREADY not asserted during APB Access phase!");
                err_count = err_count + 1;
            end
            error = pslverr;

            // Complete Phase (T3)
            @(posedge pclk);
            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
        end
    endtask

    // APB standard 2-cycle read task
    task automatic apb_read(
        input  [31:0] addr,
        output [31:0] data,
        output        error
    );
        begin
            // Setup Phase (T1)
            @(posedge pclk);
            psel    <= 1'b1;
            penable <= 1'b0;
            paddr   <= addr;
            pwrite  <= 1'b0;

            // Access Phase (T2)
            @(posedge pclk);
            penable <= 1'b1;
            #1;
            if (!pready) begin
                $display("[TB] ERROR: PREADY not asserted during APB Access phase!");
                err_count = err_count + 1;
            end
            data  = prdata;
            error = pslverr;

            // Complete Phase (T3)
            @(posedge pclk);
            psel    <= 1'b0;
            penable <= 1'b0;
        end
    endtask

    reg [31:0] rdata;
    reg        r_err;

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_apb_interface.vcd");
`endif
        $dumpvars(0, tb_apb_interface);

        pclk    = 0;
        presetn = 0;
        psel    = 0;
        paddr   = 0;
        pwdata  = 0;
        pwrite  = 0;
        penable = 0;

        tx_busy = 0; tx_fifo_full = 0; tx_hpb_full = 0;
        rx_not_empty = 0; rx_fifo_full = 0; rx_underflow = 0;
        rx_ok = 0; tx_ok = 0; arblst = 0; bus_off = 0;
        error_status = 0; sleep_mode_entered = 0; wakeup_event = 0;
        error_warning = 0; estat = 2'b00; tec = 8'd0; rec = 8'd0;
        bus_idle = 1; bus_busy = 0; acfb_busy = 0;

        err_acker = 0; err_berr = 0; err_ster = 0; err_fmer = 0; err_crcer = 0;
        rx_id = 0; rx_ext_id = 0; rx_ide = 0; rx_rtr = 0; rx_dlc = 0;
        rx_data0 = 0; rx_data1 = 0;

        // Reset sequence
        #20;
        @(posedge pclk);
        presetn <= 1;
        @(posedge pclk);

        //-------------------------------------------------------------
        // Test 1: APB Write & Read Transactions in Config Mode
        //-------------------------------------------------------------
        $display("[TB] Test 1: APB Write & Read to BRPR and BTR in Config Mode...");
        apb_write(32'h08, 32'h00000007, r_err); // BRP = 7
        if (r_err !== 1'b0) begin
            $display("[TB] ERROR: Unexpected PSLVERR on writing BRPR in Config Mode!");
            err_count = err_count + 1;
        end

        apb_write(32'h0C, 32'h00000094, r_err); // SJW=1, TS2=1, TS1=4 -> 0x094
        if (r_err !== 1'b0) begin
            $display("[TB] ERROR: Unexpected PSLVERR on writing BTR in Config Mode!");
            err_count = err_count + 1;
        end

        apb_read(32'h08, rdata, r_err);
        if (rdata[7:0] !== 8'd7 || r_err !== 1'b0) begin
            $display("[TB] ERROR: BRPR readback mismatch! rdata=%h, r_err=%b", rdata, r_err);
            err_count = err_count + 1;
        end

        apb_read(32'h0C, rdata, r_err);
        if (rdata[8:0] !== 9'h094 || r_err !== 1'b0) begin
            $display("[TB] ERROR: BTR readback mismatch! rdata=%h, r_err=%b", rdata, r_err);
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Test 2: APB Slave Error (PSLVERR) on Restricted Writes in Normal Mode
        //-------------------------------------------------------------
        $display("[TB] Test 2: Transition to Normal Mode and verify PSLVERR on restricted writes...");
        apb_write(32'h00, 32'h00000002, r_err); // CEN = 1
        @(posedge pclk);

        // Attempt write to BRPR while in Normal Mode -> Expect PSLVERR = 1
        apb_write(32'h08, 32'h00000002, r_err);
        if (r_err !== 1'b1) begin
            $display("[TB] ERROR: Expected PSLVERR when writing BRPR in Normal Mode, got PSLVERR=0!");
            err_count = err_count + 1;
        end

        // Attempt write to Read-Only ECR (0x10) -> Expect PSLVERR = 1
        apb_write(32'h10, 32'hFFFFFFFF, r_err);
        if (r_err !== 1'b1) begin
            $display("[TB] ERROR: Expected PSLVERR on write to Read-Only ECR!");
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Test 3: Full TX FIFO Frame Transmission via APB
        //-------------------------------------------------------------
        $display("[TB] Test 3: Writing TX FIFO frame via APB bus...");
        apb_write(32'h30, 32'h55500000, r_err); // Standard ID = 0x2AA
        apb_write(32'h34, 32'h80000000, r_err); // DLC = 8
        apb_write(32'h38, 32'h12345678, r_err); // DW1
        apb_write(32'h3C, 32'h9ABCDEF0, r_err); // DW2 -> Triggers tx_write
        #1;

        if (tx_id !== 11'h2AA || tx_dlc !== 4'd8 || tx_data0 !== 32'h78563412) begin
            $display("[TB] ERROR: TX signals mismatch after APB write! tx_id=%h tx_dlc=%d tx_data0=%h", tx_id, tx_dlc, tx_data0);
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Test 4: RX FIFO Read via APB
        //-------------------------------------------------------------
        $display("[TB] Test 4: Reading RX FIFO registers via APB bus...");
        rx_id    = 11'h7FF;
        rx_ide   = 1'b0;
        rx_rtr   = 1'b0;
        rx_dlc   = 4'd2;
        rx_data0 = 32'hDEADBEEF;

        apb_read(32'h50, rdata, r_err);
        if (rdata[31:21] !== 11'h7FF || r_err !== 1'b0) begin
            $display("[TB] ERROR: RX_ID APB read mismatch! rdata=%h", rdata);
            err_count = err_count + 1;
        end

        apb_read(32'h58, rdata, r_err);
        if (rdata !== 32'hDEADBEEF || r_err !== 1'b0) begin
            $display("[TB] ERROR: RX_DW1 APB read mismatch! rdata=%h", rdata);
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Test 5: Core Interrupt and ICR Clear via APB
        //-------------------------------------------------------------
        $display("[TB] Test 5: Interrupt Enable and Clear via APB...");
        // Enable TXOK interrupt (bit 1)
        apb_write(32'h20, 32'h00000002, r_err);

        // Simulate core TX OK event
        @(posedge pclk);
        tx_ok <= 1'b1;
        @(posedge pclk);
        tx_ok <= 1'b0;
        @(posedge pclk);

        if (irq !== 1'b1) begin
            $display("[TB] ERROR: IRQ not asserted after TX OK event!");
            err_count = err_count + 1;
        end

        // Clear interrupt via APB write to ICR (0x24)
        apb_write(32'h24, 32'h00000002, r_err);
        @(posedge pclk);

        if (irq !== 1'b0) begin
            $display("[TB] ERROR: IRQ did not clear after APB write to ICR!");
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Summary
        //-------------------------------------------------------------
        repeat (10) @(posedge pclk);
        if (err_count == 0) begin
            $display("\n=======================================================");
            $display("   ALL APB_INTERFACE TESTS PASSED SUCCESSFULLY!        ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("   APB_INTERFACE TESTS FAILED WITH %0d ERRORS!         ", err_count);
            $display("=======================================================\n");
        end
        $finish;
    end

endmodule
