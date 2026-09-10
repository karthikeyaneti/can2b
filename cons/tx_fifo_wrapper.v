`timescale 1ns / 1ps

module tx_fifo_wrapper #(
    parameter ADDR_WIDTH = 4
) (
    input  wire        wr_clk,
    input  wire        rd_clk,
    input  wire        wr_rst_n_async,
    input  wire        rd_rst_n_async,
    input  wire        tx_wr_en,
    input  wire [28:0] tx_wr_id,
    input  wire        tx_wr_ide,
    input  wire        tx_wr_rtr,
    input  wire [3:0]  tx_wr_dlc,
    input  wire [63:0] tx_wr_data,
    input  wire        tx_rd_en,
    output wire        tx_fifo_full,
    output wire [28:0] tx_rd_id,
    output wire        tx_rd_ide,
    output wire        tx_rd_rtr,
    output wire [3:0]  tx_rd_dlc,
    output wire [63:0] tx_rd_data,
    output wire        tx_frame_avail,
    output wire        tx_fifo_empty
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

    tx_fifo #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo (
        .wr_clk        (wr_clk),
        .wr_rst_n_sync (wr_rst_n_sync),
        .tx_wr_en      (tx_wr_en),
        .tx_wr_id      (tx_wr_id),
        .tx_wr_ide     (tx_wr_ide),
        .tx_wr_rtr     (tx_wr_rtr),
        .tx_wr_dlc     (tx_wr_dlc),
        .tx_wr_data    (tx_wr_data),
        .tx_fifo_full  (tx_fifo_full),
        .rd_clk        (rd_clk),
        .rd_rst_n_sync (rd_rst_n_sync),
        .tx_rd_en      (tx_rd_en),
        .tx_rd_id      (tx_rd_id),
        .tx_rd_ide     (tx_rd_ide),
        .tx_rd_rtr     (tx_rd_rtr),
        .tx_rd_dlc     (tx_rd_dlc),
        .tx_rd_data    (tx_rd_data),
        .tx_frame_avail(tx_frame_avail),
        .tx_fifo_empty (tx_fifo_empty)
    );

endmodule