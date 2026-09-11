`timescale 1ns / 1ps

// can_top: Top-level CAN Controller IP for Vivado/PYNQ-Z2
// APB4 Slave Interface -> AXI-to-APB Bridge -> Zynq PS
// Single-channel architecture, easily expandable to dual-channel

module can_top (
    // APB4 Clock & Reset Domain
    input  wire        s_apb_pclk,
    input  wire        s_apb_presetn,

    // CAN Engine Clock & Reset Domain
    input  wire        can_clk,
    input  wire        can_resetn,

    // APB4 Slave Bus Interface
    input  wire [11:0] s_apb_paddr,    // Address bus
    input  wire        s_apb_psel,     // Slave select
    input  wire        s_apb_penable,  // Enable signal
    input  wire        s_apb_pwrite,   // Write control
    input  wire [31:0] s_apb_pwdata,   // Write data bus
    input  wire [3:0]  s_apb_pstrb,    // Byte strobes (APB4)
    input  wire [2:0]  s_apb_pprot,    // Protection type (APB4)
    output wire [31:0] s_apb_prdata,   // Read data bus
    output wire        s_apb_pready,   // Slave ready response
    output wire        s_apb_pslverr,  // Bus error response

    // Physical CAN Interface
    input  wire        can_rx,         // Serial line in
    output wire        can_tx,         // Serial line out

    // System Interrupt Line
    output wire        can_irq         // CPU Interrupt Line
);

    // Synchronized pclk domain reset
    wire pclk_rst_n;
    reset_synchronizer preset_sync (
        .clk        (s_apb_pclk),
        .rst_n_async(s_apb_presetn),
        .rst_n_sync (pclk_rst_n)
    );

    // Internal APB-to-Register Bank Bus
    wire [11:0] reg_addr;
    wire        reg_wr_en;
    wire        reg_rd_en;
    wire [31:0] reg_wdata;
    wire [3:0]  reg_wstrb;
    wire [31:0] reg_rdata;
    wire        reg_err;

    // APB Slave Interface Bridge
    apb_interface #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32),
        .STRB_WIDTH(4)
    ) u_apb_interface (
        .pclk     (s_apb_pclk),
        .presetn  (pclk_rst_n),
        .psel     (s_apb_psel),
        .paddr    (s_apb_paddr),
        .pwdata   (s_apb_pwdata),
        .pwrite   (s_apb_pwrite),
        .penable  (s_apb_penable),
        .pstrb    (s_apb_pstrb),
        .pprot    (s_apb_pprot),
        .prdata   (s_apb_prdata),
        .pready   (s_apb_pready),
        .pslverr  (s_apb_pslverr),
        .reg_addr (reg_addr),
        .reg_wr_en(reg_wr_en),
        .reg_rd_en(reg_rd_en),
        .reg_wdata(reg_wdata),
        .reg_wstrb(reg_wstrb),
        .reg_rdata(reg_rdata),
        .reg_err  (reg_err)
    );

    // Channel 0 (CAN0)
    can_channel_core #(
        .TX_FIFO_DEPTH(4),
        .RX_FIFO_DEPTH(4)
    ) u_can_ch0 (
        .pclk      (s_apb_pclk),
        .presetn   (pclk_rst_n),
        .reg_addr  (reg_addr),
        .reg_wr_en (reg_wr_en),
        .reg_rd_en (reg_rd_en),
        .reg_wdata (reg_wdata),
        .reg_wstrb (reg_wstrb),
        .reg_rdata (reg_rdata),
        .reg_err   (reg_err),
        .can_clk   (can_clk),
        .can_rst_n (can_resetn),
        .can_rx    (can_rx),
        .can_tx    (can_tx),
        .can_irq   (can_irq)
    );

endmodule