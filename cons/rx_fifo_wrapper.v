`timescale 1ns / 1ps

module rx_fifo_wrapper #(
    parameter ADDR_WIDTH = 4
) (
    input  wire        wr_clk,
    input  wire        rd_clk,
    input  wire        wr_rst_n_async,
    input  wire        rd_rst_n_async,
    input  wire        rx_push,
    input  wire [31:0] rx_push_idr,
    input  wire [31:0] rx_push_dlcr,
    input  wire [31:0] rx_push_dw1r,
    input  wire [31:0] rx_push_dw2r,
    input  wire        rx_pop,
    output wire        rx_fifo_full,
    output wire        rx_overflow_pulse,
    output wire [31:0] rx_idr,
    output wire [31:0] rx_dlcr,
    output wire [31:0] rx_dw1r,
    output wire [31:0] rx_dw2r,
    output wire        rx_empty,
    output wire        rx_not_empty,
    output wire        rx_underflow_pulse
);

    wire wr_rst_n_sync;
    wire rd_rst_n_sync;

    reset_synchronizer u_wr_reset (
        .clk        (wr_clk),
        .rst_n_async(wr_rst_n_async),
        .rst_n_sync (wr_rst_n_sync)
    );

    reset_synchronizer u_rd_reset (
        .clk        (rd_clk),
        .rst_n_async(rd_rst_n_async),
        .rst_n_sync (rd_rst_n_sync)
    );

    rx_fifo #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo (
        .wr_clk          (wr_clk),
        .wr_rst_n_sync   (wr_rst_n_sync),
        .rx_push         (rx_push),
        .rx_push_idr     (rx_push_idr),
        .rx_push_dlcr    (rx_push_dlcr),
        .rx_push_dw1r    (rx_push_dw1r),
        .rx_push_dw2r    (rx_push_dw2r),
        .rx_fifo_full    (rx_fifo_full),
        .rx_overflow_pulse(rx_overflow_pulse),
        .rd_clk          (rd_clk),
        .rd_rst_n_sync   (rd_rst_n_sync),
        .rx_pop          (rx_pop),
        .rx_idr          (rx_idr),
        .rx_dlcr         (rx_dlcr),
        .rx_dw1r         (rx_dw1r),
        .rx_dw2r         (rx_dw2r),
        .rx_empty        (rx_empty),
        .rx_not_empty    (rx_not_empty),
        .rx_underflow_pulse(rx_underflow_pulse)
    );

endmodule