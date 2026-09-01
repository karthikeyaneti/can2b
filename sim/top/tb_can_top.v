`timescale 1ns / 1ps

module tb_can_top;

    localparam ADDR_WIDTH = 12;
    localparam DATA_WIDTH = 32;
    localparam ADDR_SRR   = 12'h000;
    localparam ADDR_MSR   = 12'h004;
    localparam ADDR_BRPR  = 12'h008;
    localparam ADDR_BTR   = 12'h00C;
    localparam ADDR_ISR   = 12'h01C;
    localparam ADDR_IER   = 12'h020;
    localparam ADDR_TX_ID = 12'h030;
    localparam ADDR_TX_DLC = 12'h034;
    localparam ADDR_TX_DW1 = 12'h038;
    localparam ADDR_TX_DW2 = 12'h03C;

    reg                     s_apb_pclk;
    reg                     s_apb_presetn;
    reg                     can_clk;
    reg                     can_resetn;

    reg  [ADDR_WIDTH-1:0]  s_apb_paddr;
    reg                    s_apb_psel;
    reg                    s_apb_penable;
    reg                    s_apb_pwrite;
    reg  [DATA_WIDTH-1:0]  s_apb_pwdata;
    reg  [3:0]             s_apb_pstrb;
    reg  [2:0]             s_apb_pprot;
    wire [DATA_WIDTH-1:0]  s_apb_prdata;
    wire                   s_apb_pready;
    wire                   s_apb_pslverr;

    reg                    can_rx;
    wire                   can_tx;
    wire                   can_irq;

    integer errors = 0;

    can_top dut (
        .s_apb_pclk    (s_apb_pclk),
        .s_apb_presetn (s_apb_presetn),
        .can_clk       (can_clk),
        .can_resetn    (can_resetn),
        .s_apb_paddr   (s_apb_paddr),
        .s_apb_psel    (s_apb_psel),
        .s_apb_penable (s_apb_penable),
        .s_apb_pwrite  (s_apb_pwrite),
        .s_apb_pwdata  (s_apb_pwdata),
        .s_apb_pstrb   (s_apb_pstrb),
        .s_apb_pprot   (s_apb_pprot),
        .s_apb_prdata  (s_apb_prdata),
        .s_apb_pready  (s_apb_pready),
        .s_apb_pslverr (s_apb_pslverr),
        .can_rx        (can_rx),
        .can_tx        (can_tx),
        .can_irq       (can_irq)
    );

    always #5    s_apb_pclk = ~s_apb_pclk;
    always #6.25 can_clk    = ~can_clk;

    task automatic apb_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge s_apb_pclk);
            s_apb_psel   <= 1'b1;
            s_apb_penable <= 1'b0;
            s_apb_pwrite <= 1'b1;
            s_apb_paddr  <= addr;
            s_apb_pwdata <= data;

            @(posedge s_apb_pclk);
            s_apb_penable <= 1'b1;
            wait (s_apb_pready);

            @(posedge s_apb_pclk);
            s_apb_psel   <= 1'b0;
            s_apb_penable <= 1'b0;
            s_apb_pwrite <= 1'b0;
            s_apb_paddr  <= {ADDR_WIDTH{1'b0}};
            s_apb_pwdata <= {DATA_WIDTH{1'b0}};
        end
    endtask

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_can_top.vcd");
`endif
        $dumpvars(0, tb_can_top);

        s_apb_pclk    = 0;
        s_apb_presetn = 0;
        can_clk       = 0;
        can_resetn    = 0;
        s_apb_psel    = 0;
        s_apb_penable = 0;
        s_apb_pwrite  = 0;
        s_apb_paddr   = 0;
        s_apb_pwdata  = 0;
        s_apb_pstrb   = 4'hF;
        s_apb_pprot   = 3'b000;
        can_rx        = 1'b1;

        repeat (8) @(posedge s_apb_pclk);
        s_apb_presetn = 1'b1;
        can_resetn    = 1'b1;
        repeat (20) @(posedge can_clk);

        $display("[TB] Configuring CAN core in config mode...");
        apb_write(ADDR_MSR, 32'h00000002);     // Loopback enable
        apb_write(ADDR_BRPR, 32'h00000000);    // BRP = 0
        apb_write(ADDR_BTR, 32'h00000155);    // TSEG1=5, TSEG2=2, SJW=1
        apb_write(ADDR_SRR, 32'h00000002);    // enable CAN core (CEN)

        $display("[TB] Enabling TX interrupt...");
        apb_write(ADDR_IER, 32'h00000002);    // IER[1] = TX_OK

        $display("[TB] Writing a standard CAN frame into the TX queue...");
        apb_write(ADDR_TX_ID, 32'h55500000);  // ID=0x555
        apb_write(ADDR_TX_DLC, 32'h00000001); // DLC=1
        apb_write(ADDR_TX_DW1, 32'h00000000);
        apb_write(ADDR_TX_DW2, 32'h000000AA); // writes frame and triggers TX push

        // Wait for the TX complete interrupt or timeout.
        begin
            integer timeout;
            timeout = 0;
            while (!can_irq && timeout < 5000) begin
                @(posedge can_clk);
                timeout = timeout + 1;
            end

            if (timeout >= 5000) begin
                $display("[TB ERROR] TX interrupt timed out after %0d CAN cycles.", timeout);
                errors = errors + 1;
            end else begin
                $display("[TB] TX interrupt observed after %0d CAN cycles.", timeout);
            end
        end

        if (can_irq) begin
            $display("[TB] TX complete interrupt is asserted as expected.");
            if (errors == 0) begin
                $display("\n=======================================================");
                $display("   CAN_TOP FINAL TEST PASSED!                         ");
                $display("=======================================================\n");
            end else begin
                $display("\n=======================================================");
                $display("   CAN_TOP FINAL TEST FAILED WITH %0d ERRORS!         ", errors);
                $display("=======================================================\n");
            end
        end else begin
            $display("[TB ERROR] TX interrupt never asserted.");
            errors = errors + 1;
            $display("\n=======================================================");
            $display("   CAN_TOP FINAL TEST FAILED WITH %0d ERRORS!         ", errors);
            $display("=======================================================\n");
        end

        $finish;
    end

endmodule
