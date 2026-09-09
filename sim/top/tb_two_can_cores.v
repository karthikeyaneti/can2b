`timescale 1ns / 1ps

module tb_two_can_cores;

    localparam [11:0] ADDR_MSR    = 12'h004;
    localparam [11:0] ADDR_BRPR   = 12'h008;
    localparam [11:0] ADDR_BTR    = 12'h00C;
    localparam [11:0] ADDR_SRR    = 12'h000;
    localparam [11:0] ADDR_ISR    = 12'h01C;
    localparam [11:0] ADDR_IER    = 12'h020;
    localparam [11:0] ADDR_TX_ID  = 12'h030;
    localparam [11:0] ADDR_TX_DLC = 12'h034;
    localparam [11:0] ADDR_TX_DW1 = 12'h038;
    localparam [11:0] ADDR_TX_DW2 = 12'h03C;
    localparam [11:0] ADDR_RX_ID  = 12'h050;

    reg pclk;
    reg can_clk;
    reg presetn;
    reg can_resetn;

    reg [11:0] paddr0, paddr1;
    reg psel0, psel1;
    reg penable0, penable1;
    reg pwrite0, pwrite1;
    reg [31:0] pwdata0, pwdata1;
    reg [3:0] pstrb0, pstrb1;
    reg [2:0] pprot0, pprot1;
    wire [31:0] prdata0, prdata1;
    wire pready0, pready1;
    wire pslverr0, pslverr1;
    wire tx0, tx1;
    wire irq0, irq1;

    wire bus_level = tx0 & tx1;

    integer errors;

    can_top node0 (
        .s_apb_pclk(pclk), .s_apb_presetn(presetn),
        .can_clk(can_clk), .can_resetn(can_resetn),
        .s_apb_paddr(paddr0), .s_apb_psel(psel0), .s_apb_penable(penable0),
        .s_apb_pwrite(pwrite0), .s_apb_pwdata(pwdata0), .s_apb_pstrb(pstrb0),
        .s_apb_pprot(pprot0), .s_apb_prdata(prdata0), .s_apb_pready(pready0),
        .s_apb_pslverr(pslverr0), .can_rx(bus_level), .can_tx(tx0), .can_irq(irq0)
    );

    can_top node1 (
        .s_apb_pclk(pclk), .s_apb_presetn(presetn),
        .can_clk(can_clk), .can_resetn(can_resetn),
        .s_apb_paddr(paddr1), .s_apb_psel(psel1), .s_apb_penable(penable1),
        .s_apb_pwrite(pwrite1), .s_apb_pwdata(pwdata1), .s_apb_pstrb(pstrb1),
        .s_apb_pprot(pprot1), .s_apb_prdata(prdata1), .s_apb_pready(pready1),
        .s_apb_pslverr(pslverr1), .can_rx(bus_level), .can_tx(tx1), .can_irq(irq1)
    );

    always #5 pclk = ~pclk;
    always #6.25 can_clk = ~can_clk;
    task automatic apb_write0;
        input [11:0] addr;
        input [31:0] data;
        begin
            @(posedge pclk);
            paddr0 <= addr; pwdata0 <= data; pwrite0 <= 1'b1; psel0 <= 1'b1;
            penable0 <= 1'b0;
            @(posedge pclk);
            penable0 <= 1'b1;
            wait (pready0);
            @(posedge pclk);
            psel0 <= 1'b0; penable0 <= 1'b0; pwrite0 <= 1'b0;
        end
    endtask

    task automatic apb_write1;
        input [11:0] addr;
        input [31:0] data;
        begin
            @(posedge pclk);
            paddr1 <= addr; pwdata1 <= data; pwrite1 <= 1'b1; psel1 <= 1'b1;
            penable1 <= 1'b0;
            @(posedge pclk);
            penable1 <= 1'b1;
            wait (pready1);
            @(posedge pclk);
            psel1 <= 1'b0; penable1 <= 1'b0; pwrite1 <= 1'b0;
        end
    endtask

    task automatic apb_read1;
        input [11:0] addr;
        output [31:0] data;
        begin
            @(posedge pclk);
            paddr1 <= addr; pwrite1 <= 1'b0; psel1 <= 1'b1; penable1 <= 1'b0;
            @(posedge pclk);
            penable1 <= 1'b1;
            wait (pready1);
            #1 data = prdata1;
            @(posedge pclk);
            psel1 <= 1'b0; penable1 <= 1'b0;
        end
    endtask

    reg [31:0] rx_id;
    integer timeout;
    initial begin
        $dumpfile("build/tb_two_can_cores/tb_two_can_cores.vcd");
        $dumpvars(0, tb_two_can_cores);

        pclk = 1'b0;
        can_clk = 1'b0;
        presetn = 1'b0;
        can_resetn = 1'b0;
        paddr0 = 0; paddr1 = 0;
        psel0 = 0; psel1 = 0;
        penable0 = 0; penable1 = 0;
        pwrite0 = 0; pwrite1 = 0;
        pwdata0 = 0; pwdata1 = 0;
        pstrb0 = 4'hF; pstrb1 = 4'hF;
        pprot0 = 0; pprot1 = 0;
        errors = 0;

        repeat (8) @(posedge pclk);
        presetn = 1'b1;
        can_resetn = 1'b1;
        repeat (20) @(posedge can_clk);

        // Both nodes use the same bit timing and remain in normal bus mode.
        apb_write0(ADDR_MSR, 32'h0);
        apb_write1(ADDR_MSR, 32'h0);
        apb_write0(ADDR_BRPR, 32'h0);
        apb_write1(ADDR_BRPR, 32'h0);
        apb_write0(ADDR_BTR, 32'h00000155);
        apb_write1(ADDR_BTR, 32'h00000155);
        apb_write1(ADDR_IER, 32'h00000010);
        apb_write0(ADDR_SRR, 32'h2);
        apb_write1(ADDR_SRR, 32'h2);

        // ID 0x123 is stored in TX_ID[31:21], one data byte 0x5A.
        apb_write0(ADDR_TX_ID, 32'h24600000);
        apb_write0(ADDR_TX_DLC, 32'h1);
        apb_write0(ADDR_TX_DW1, 32'h0);
        apb_write0(ADDR_TX_DW2, 32'h0000005A);

        timeout = 0;
        while (!irq1 && timeout < 10000) begin
            @(posedge can_clk);
            timeout = timeout + 1;
        end

        if (!irq1) begin
            $display("[TB ERROR] Node 1 did not report RX completion.");
            $display("[TB DEBUG] rx_state=%0d tx_state=%0d rec=%0d crc=%b form=%b stuff=%b bit=%b rx_crc=%h calc=%h base=%h dlc=%h",
                     node1.u_can_ch0.u_tx_path_core.u_bsp.rx_state,
                     node0.u_can_ch0.u_tx_path_core.u_bsp.state,
                     node1.u_can_ch0.u_tx_path_core.u_bsp.rec,
                     node1.u_can_ch0.u_tx_path_core.u_bsp.err_crcer,
                     node1.u_can_ch0.u_tx_path_core.u_bsp.err_fmer,
                     node1.u_can_ch0.u_tx_path_core.u_bsp.err_ster,
                     node1.u_can_ch0.u_tx_path_core.u_bsp.err_berr,
                     node1.u_can_ch0.u_tx_path_core.u_bsp.rx_crc_received,
                     node1.u_can_ch0.u_tx_path_core.u_bsp.rx_crc_calc,
                     node1.u_can_ch0.u_tx_path_core.u_bsp.rx_base_id,
                     node1.u_can_ch0.u_tx_path_core.u_bsp.rx_dlc_reg);
            errors = errors + 1;
        end else begin
            apb_read1(ADDR_RX_ID, rx_id);
            if (rx_id[31:21] !== 11'h123) begin
                $display("[TB ERROR] RX ID mismatch: got %h", rx_id);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("TWO CAN CORE TEST PASSED");
        else
            $display("TWO CAN CORE TEST FAILED: %0d errors", errors);
        $finish;
    end

endmodule