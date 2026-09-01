`timescale 1ns / 1ps

module tx_fifo #(
    parameter ADDR_WIDTH = 4
) (
    // Write Domain (e.g. APB / Register Clock Domain)
    input  wire        wr_clk,
    input  wire        wr_rst_n_sync,
    input  wire        tx_wr_en,
    input  wire [28:0] tx_wr_id,
    input  wire        tx_wr_ide,
    input  wire        tx_wr_rtr,
    input  wire [3:0]  tx_wr_dlc,
    input  wire [63:0] tx_wr_data,
    output wire        tx_fifo_full,

    // Read Domain (e.g. CAN Core Clock Domain)
    input  wire        rd_clk,
    input  wire        rd_rst_n_sync,
    input  wire        tx_rd_en,
    output wire [28:0] tx_rd_id,
    output wire        tx_rd_ide,
    output wire        tx_rd_rtr,
    output wire [3:0]  tx_rd_dlc,
    output wire [63:0] tx_rd_data,
    output wire        tx_frame_avail,
    output wire        tx_fifo_empty
);

    localparam DATA_WIDTH = 128;

    wire [DATA_WIDTH-1:0] wr_fifo_data;
    wire [DATA_WIDTH-1:0] rd_fifo_data;

    // Pack write payload into 128-bit word
    assign wr_fifo_data = {
        29'd0,
        tx_wr_id,
        tx_wr_ide,
        tx_wr_rtr,
        tx_wr_dlc,
        tx_wr_data
    };

    // Instantiate dual-clock asynchronous CAN FIFO
    can_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_can_fifo (
        .wr_clk        (wr_clk),
        .rd_clk        (rd_clk),
        .wr_rst_n_sync (wr_rst_n_sync),
        .rd_rst_n_sync (rd_rst_n_sync),
        .wr_en         (tx_wr_en),
        .rd_en         (tx_rd_en),
        .wr_data       (wr_fifo_data),
        .rd_data       (rd_fifo_data),
        .empty         (tx_fifo_empty),
        .full          (tx_fifo_full)
    );

    // Unpack read payload
    assign tx_rd_data     = rd_fifo_data[63:0];
    assign tx_rd_dlc      = rd_fifo_data[67:64];
    assign tx_rd_rtr      = rd_fifo_data[68];
    assign tx_rd_ide      = rd_fifo_data[69];
    assign tx_rd_id       = rd_fifo_data[98:70];
    assign tx_frame_avail = ~tx_fifo_empty;

endmodule
