`timescale 1ns / 1ps

module tb_apb_interface;
    reg pclk, presetn, psel, penable, pwrite;
    reg [11:0] paddr;
    reg [31:0] pwdata;
    reg [3:0] pstrb;
    reg [2:0] pprot;
    wire [31:0] prdata;
    wire pready, pslverr;
    wire [11:0] reg_addr;
    wire reg_wr_en, reg_rd_en;
    wire [31:0] reg_wdata, reg_rdata;
    wire [3:0] reg_wstrb;
    wire reg_err;
    integer failures;

    assign reg_rdata = 32'hCAFE_BABE;
    assign reg_err = (reg_addr == 12'hFFF);
    always #5 pclk = ~pclk;

    apb_interface #(.ADDR_WIDTH(12), .DATA_WIDTH(32)) dut (
        .pclk(pclk), .presetn(presetn), .psel(psel), .paddr(paddr),
        .pwdata(pwdata), .pwrite(pwrite), .penable(penable), .pstrb(pstrb),
        .pprot(pprot), .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .reg_addr(reg_addr), .reg_wr_en(reg_wr_en), .reg_rd_en(reg_rd_en),
        .reg_wdata(reg_wdata), .reg_wstrb(reg_wstrb), .reg_rdata(reg_rdata),
        .reg_err(reg_err), .rx_idr(32'd0), .rx_dlcr(32'd0),
        .rx_dw1r(32'd0), .rx_dw2r(32'd0)
    );

    initial begin
        pclk = 0; presetn = 0; psel = 0; penable = 0; pwrite = 0;
        paddr = 0; pwdata = 0; pstrb = 0; pprot = 0; failures = 0;
        #12 presetn = 1;

        @(negedge pclk);
        paddr = 12'h020; pwdata = 32'h1234; pstrb = 4'h5;
        psel = 1; pwrite = 1; penable = 0;
        #4 penable = 1;
        #1;
        if (!pready || pslverr || !reg_wr_en || reg_rd_en ||
            reg_addr !== 12'h020 || reg_wdata !== 32'h1234 || reg_wstrb !== 4'h5)
            failures = failures + 1;
        @(negedge pclk); psel = 0; penable = 0;

        @(negedge pclk);
        paddr = 12'h024; pstrb = 0; psel = 1; pwrite = 0; penable = 1;
        #1;
        if (!pready || pslverr || reg_wr_en || !reg_rd_en ||
            prdata !== 32'hCAFE_BABE)
            failures = failures + 1;
        @(negedge pclk); psel = 0; penable = 0;

        @(negedge pclk);
        paddr = 12'hFFF; psel = 1; pwrite = 0; penable = 1;
        #1;
        if (!pready || !pslverr) failures = failures + 1;

        if (failures == 0) $display("APB INTERFACE TEST PASSED");
        else begin
            $display("APB INTERFACE TEST FAILED: %0d failures", failures);
            $fatal(1);
        end
        $finish;
    end
endmodule