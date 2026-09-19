`timescale 1ns / 1ps

module can_fifo_wrapper #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 4
) (
    input  wire                  wr_clk,
    input  wire                  rd_clk,
    input  wire                  wr_rst_n_async,
    input  wire                  rd_rst_n_async,
    input  wire                  wr_en,
    input  wire                  rd_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty,
    output wire                  full
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

    can_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo (
        .wr_clk       (wr_clk),
        .rd_clk       (rd_clk),
        .wr_rst_n_sync(wr_rst_n_sync),
        .rd_rst_n_sync(rd_rst_n_sync),
        .wr_en        (wr_en),
        .rd_en        (rd_en),
        .wr_data      (wr_data),
        .rd_data      (rd_data),
        .empty        (empty),
        .full         (full)
    );

endmodule