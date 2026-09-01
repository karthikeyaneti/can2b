`timescale 1ns / 1ps

module tb_can_regfile;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    reg                     pclk;
    reg                     presetn;

    reg                     reg_write;
    reg                     reg_read;
    reg  [ADDR_WIDTH-1:0]   reg_addr;
    reg  [DATA_WIDTH-1:0]   reg_wdata;
    wire [DATA_WIDTH-1:0]   reg_rdata;
    wire                    reg_err;

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
    can_regfile #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .pclk               (pclk),
        .presetn            (presetn),
        .reg_write          (reg_write),
        .reg_read           (reg_read),
        .reg_addr           (reg_addr),
        .reg_wdata          (reg_wdata),
        .reg_rdata          (reg_rdata),
        .reg_err            (reg_err),
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

    // Helper task to write a register
    task automatic write_reg(input [31:0] addr, input [31:0] data);
        begin
            @(posedge pclk);
            reg_addr  <= addr;
            reg_wdata <= data;
            reg_write <= 1'b1;
            reg_read  <= 1'b0;
            @(posedge pclk);
            reg_write <= 1'b0;
        end
    endtask

    // Helper task to read a register
    task automatic read_reg(input [31:0] addr, output [31:0] data, output err);
        begin
            @(posedge pclk);
            reg_addr  <= addr;
            reg_read  <= 1'b1;
            reg_write <= 1'b0;
            #1;
            data = reg_rdata;
            err  = reg_err;
            @(posedge pclk);
            reg_read  <= 1'b0;
        end
    endtask

    reg [31:0] rdata;
    reg        r_err;

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_can_regfile.vcd");
`endif
        $dumpvars(0, tb_can_regfile);

        pclk = 0;
        presetn = 0;
        reg_write = 0;
        reg_read = 0;
        reg_addr = 0;
        reg_wdata = 0;

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
        // Test 1: Config Mode Register Access (BRPR, BTR)
        //-------------------------------------------------------------
        $display("[TB] Test 1: Testing Config Mode Register Writes...");
        // In config mode (CEN=0), writing BRPR and BTR should succeed (reg_err = 0)
        write_reg(32'h08, 32'h00000004); // BRP = 4
        write_reg(32'h0C, 32'h000000B5); // SJW=1(2'b01), TS2=3(3'b011), TS1=5(4'b0101) -> 0x0B5

        read_reg(32'h08, rdata, r_err);
        if (rdata[7:0] !== 8'd4 || r_err !== 1'b0) begin
            $display("[TB] ERROR: BRPR readback mismatch! rdata=%h, r_err=%b", rdata, r_err);
            err_count = err_count + 1;
        end

        read_reg(32'h0C, rdata, r_err);
        if (rdata[8:0] !== 9'h0B5 || r_err !== 1'b0) begin
            $display("[TB] ERROR: BTR readback mismatch! rdata=%h, r_err=%b", rdata, r_err);
            err_count = err_count + 1;
        end

        if (brp !== 8'd4 || tseg1 !== 4'd5 || tseg2 !== 3'd3 || sjw !== 2'd1) begin
            $display("[TB] ERROR: DUT config outputs mismatch! brp=%0d tseg1=%0d tseg2=%0d sjw=%0d", brp, tseg1, tseg2, sjw);
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Test 2: Enable CAN (CEN=1) & Check Timing Register Lock
        //-------------------------------------------------------------
        $display("[TB] Test 2: Transitioning to Normal Mode and checking lock on BRPR/BTR...");
        write_reg(32'h00, 32'h00000002); // SRR[1] = CEN = 1
        @(posedge pclk);

        read_reg(32'h18, rdata, r_err); // Status Register
        // Status reg bits: [0]=CONFIG (0), [1]=LBACK(0), [2]=SLEEP(0), [3]=NORMAL(1), [4]=BIDLE(1)
        if (rdata[3:0] !== 4'b1000) begin
            $display("[TB] ERROR: Status Register mode mismatch! SR=%b", rdata[3:0]);
            err_count = err_count + 1;
        end

        // Try writing BRPR while CEN=1 -> should trigger reg_err = 1 and NOT modify BRP
        write_reg(32'h08, 32'h0000000A);
        if (brp !== 8'd4) begin
            $display("[TB] ERROR: BRPR was modified while in Normal Mode! brp=%0d", brp);
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Test 3: TX FIFO Register Writes and Signal Unpacking
        //-------------------------------------------------------------
        $display("[TB] Test 3: Writing TX FIFO registers...");
        // Standard Frame: ID=0x123 (ID[28:18] at [31:21] -> 0x123 << 21 = 0x24600000), RTR=0, IDE=0
        write_reg(32'h30, 32'h24600000);
        write_reg(32'h34, 32'h40000000); // DLC = 4 (bits [31:28])
        write_reg(32'h38, 32'hA1B2C3D4); // DW1
        write_reg(32'h3C, 32'hE5F60718); // DW2 -> triggers tx_write pulse
        #1;

        if (tx_id !== 11'h123 || tx_ide !== 1'b0 || tx_dlc !== 4'd4) begin
            $display("[TB] ERROR: TX unpacked signals mismatch! tx_id=%h tx_ide=%b tx_dlc=%d", tx_id, tx_ide, tx_dlc);
            err_count = err_count + 1;
        end

        // Verify byte ordering
        if (tx_data0 !== 32'hD4C3B2A1 || tx_data1 !== 32'h1807F6E5) begin
            $display("[TB] ERROR: TX data byte ordering mismatch! tx_data0=%h tx_data1=%h", tx_data0, tx_data1);
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Test 4: RX FIFO Register Reads
        //-------------------------------------------------------------
        $display("[TB] Test 4: Reading RX FIFO registers...");
        rx_id     = 11'h555;
        rx_ext_id = 18'h12345;
        rx_ide    = 1'b1;
        rx_rtr    = 1'b0;
        rx_dlc    = 4'd8;
        rx_data0  = 32'h11223344;
        rx_data1  = 32'h55667788;

        read_reg(32'h50, rdata, r_err); // RX_ID
        // Extended format: {rx_id[10:0], 1'b1, 1'b1, rx_ext_id[17:0], rx_rtr}
        if (rdata !== {11'h555, 1'b1, 1'b1, 18'h12345, 1'b0}) begin
            $display("[TB] ERROR: RX_ID mismatch! rdata=%h", rdata);
            err_count = err_count + 1;
        end

        read_reg(32'h54, rdata, r_err); // RX_DLC
        if (rdata[31:28] !== 4'd8) begin
            $display("[TB] ERROR: RX_DLC mismatch! rdata=%h", rdata);
            err_count = err_count + 1;
        end

        read_reg(32'h58, rdata, r_err); // RX_DW1
        if (rdata !== 32'h11223344) begin
            $display("[TB] ERROR: RX_DW1 mismatch! rdata=%h", rdata);
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Test 5: Interrupts, Error Status (ESR), and Clear (ICR/ESR)
        //-------------------------------------------------------------
        $display("[TB] Test 5: Interrupt and Error handling...");
        // Enable RXOK (bit 4) and TXOK (bit 1) interrupts in IER
        write_reg(32'h20, 32'h00000012);

        // Core events
        @(posedge pclk);
        rx_ok     <= 1'b1;
        err_crcer <= 1'b1;
        @(posedge pclk);
        rx_ok     <= 1'b0;
        err_crcer <= 1'b0;
        @(posedge pclk);

        // Verify IRQ asserted
        if (irq !== 1'b1) begin
            $display("[TB] ERROR: IRQ was not asserted when unmasked ISR bit set!");
            err_count = err_count + 1;
        end

        read_reg(32'h14, rdata, r_err); // ESR
        if (rdata[0] !== 1'b1) begin // CRCER bit
            $display("[TB] ERROR: ESR[0] (CRCER) not set! ESR=%h", rdata);
            err_count = err_count + 1;
        end

        // Clear ISR bit 4 via ICR (0x24)
        write_reg(32'h24, 32'h00000010);
        @(posedge pclk);
        if (irq !== 1'b0) begin
            $display("[TB] ERROR: IRQ was not deasserted after clearing ISR!");
            err_count = err_count + 1;
        end

        // Clear ESR bit 0 via W1C
        write_reg(32'h14, 32'h00000001);
        read_reg(32'h14, rdata, r_err);
        if (rdata[0] !== 1'b0) begin
            $display("[TB] ERROR: ESR bit was not cleared via W1C!");
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Test 6: Acceptance Filter Registers
        //-------------------------------------------------------------
        $display("[TB] Test 6: Acceptance filter registers...");
        write_reg(32'h60, 32'h0000000F); // AFR: UAF1..4 = 1
        write_reg(32'h64, 32'hAAAAAAAA); // AFMR1
        write_reg(32'h68, 32'h55555555); // AFIR1

        read_reg(32'h60, rdata, r_err);
        if (rdata[3:0] !== 4'b1111) begin
            $display("[TB] ERROR: AFR readback mismatch! rdata=%h", rdata);
            err_count = err_count + 1;
        end

        if (afmr1 !== 32'hAAAAAAAA || afir1 !== 32'h55555555) begin
            $display("[TB] ERROR: AFMR1/AFIR1 output mismatch!");
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Test 7: Software Reset (SRR[0] = 1)
        //-------------------------------------------------------------
        $display("[TB] Test 7: Software Reset...");
        write_reg(32'h00, 32'h00000001); // SRR[0] = SRST = 1
        @(posedge pclk);

        if (cen !== 1'b0) begin
            $display("[TB] ERROR: CEN was not cleared on software reset!");
            err_count = err_count + 1;
        end

        // Verify AFMR/AFIR are retained per spec
        if (afmr1 !== 32'hAAAAAAAA || afir1 !== 32'h55555555) begin
            $display("[TB] ERROR: Acceptance filters were incorrectly reset!");
            err_count = err_count + 1;
        end

        //-------------------------------------------------------------
        // Test 8: Read-Only and Invalid Register Error Detection
        //-------------------------------------------------------------
        $display("[TB] Test 8: Read-Only and Invalid Register Access Error Checking...");
        // Write to Read-Only SR (0x18)
        @(posedge pclk);
        reg_addr  <= 32'h18;
        reg_wdata <= 32'hFFFFFFFF;
        reg_write <= 1'b1;
        #1;
        if (reg_err !== 1'b1) begin
            $display("[TB] ERROR: reg_err not asserted on write to read-only register (SR)!");
            err_count = err_count + 1;
        end
        @(posedge pclk);
        reg_write <= 1'b0;

        // Read from invalid address (0x100)
        @(posedge pclk);
        reg_addr <= 32'h100;
        reg_read <= 1'b1;
        #1;
        if (reg_err !== 1'b1) begin
            $display("[TB] ERROR: reg_err not asserted on read from invalid address!");
            err_count = err_count + 1;
        end
        @(posedge pclk);
        reg_read <= 1'b0;

        //-------------------------------------------------------------
        // Summary
        //-------------------------------------------------------------
        repeat (10) @(posedge pclk);
        if (err_count == 0) begin
            $display("\n=======================================================");
            $display("   ALL CAN_REGFILE TESTS PASSED SUCCESSFULLY!          ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("   CAN_REGFILE TESTS FAILED WITH %0d ERRORS!           ", err_count);
            $display("=======================================================\n");
        end
        $finish;
    end

endmodule
