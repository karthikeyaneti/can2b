`timescale 1ns/1ps

module can_tx_path_core #(
    parameter FIFO_ADDR_WIDTH = 2
) (
    input wire pclk,
    input wire presetn,
    input wire tx_wr_en,
    input wire [28:0] tx_wr_id,
    input wire tx_wr_ide,
    input wire tx_wr_rtr,
    input wire [3:0] tx_wr_dlc,
    input wire [63:0] tx_wr_data,
    output wire tx_fifo_full,
    output wire tx_fifo_empty,

    input wire can_clk,
    input wire can_rst_n_sync,
    input wire cen,
    input wire lback_mode,
    input wire sleep_mode,
    input wire sample_point,
    input wire sampled_bit,
    input wire bit_tick,
    output wire tx_active,
    output wire bus_idle,
    output wire can_tx_bit,

    output wire destuff_en,
    output wire destuff_reset,
    input wire destuffed_bit_out,
    input wire destuffed_bit_valid,
    input wire stuff_bit_dropped,
    input wire stuff_error,
    output wire rx_frame_valid,
    output wire [31:0] rx_frame_idr,
    output wire [31:0] rx_frame_dlcr,
    output wire [31:0] rx_frame_dw1r,
    output wire [31:0] rx_frame_dw2r,

    output wire tx_success_pulse,
    output wire tx_error_pulse,
    output wire tx_arblst_pulse,
    output wire rx_ok_pulse,
    output wire tx_busy,
    output wire [7:0] tec,
    output wire [7:0] rec,
    output wire [1:0] estat,
    output wire errwrn,
    output wire bus_off,
    output wire err_acker,
    output wire err_berr,
    output wire err_ster,
    output wire err_fmer,
    output wire err_crcer
);

    wire [28:0] tx_rd_id;
    wire tx_rd_ide, tx_rd_rtr, tx_frame_avail, tx_rd_en;
    wire [3:0] tx_rd_dlc;
    wire [63:0] tx_rd_data;
    wire crc_clear, crc_update_en, crc_bit_in;
    wire [14:0] crc_value;

    tx_fifo #(.ADDR_WIDTH(FIFO_ADDR_WIDTH)) u_tx_fifo (
        .wr_clk(pclk), .wr_rst_n_sync(presetn),
        .tx_wr_en(tx_wr_en), .tx_wr_id(tx_wr_id), .tx_wr_ide(tx_wr_ide),
        .tx_wr_rtr(tx_wr_rtr), .tx_wr_dlc(tx_wr_dlc), .tx_wr_data(tx_wr_data),
        .tx_fifo_full(tx_fifo_full),
        .rd_clk(can_clk), .rd_rst_n_sync(can_rst_n_sync),
        .tx_rd_en(tx_rd_en), .tx_rd_id(tx_rd_id), .tx_rd_ide(tx_rd_ide),
        .tx_rd_rtr(tx_rd_rtr), .tx_rd_dlc(tx_rd_dlc), .tx_rd_data(tx_rd_data),
        .tx_frame_avail(tx_frame_avail), .tx_fifo_empty(tx_fifo_empty)
    );

    crc_gen u_crc_gen (
        .can_clk(can_clk), .can_rst_n_sync(can_rst_n_sync),
        .bit_in(crc_bit_in), .bit_in_valid(crc_update_en), .bit_in_ready(),
        .crc_clear(crc_clear), .crc_update_en(crc_update_en), .crc_emit_en(1'b0),
        .bit_out(), .bit_out_valid(), .crc_emit_done(), .crc_value(crc_value)
    );

    can_bsp u_bsp (
        .can_clk(can_clk), .can_rst_n_sync(can_rst_n_sync),
        .sample_point(sample_point), .sampled_bit(sampled_bit), .bit_tick(bit_tick),
        .tx_active(tx_active), .bus_idle(bus_idle), .can_tx_bit(can_tx_bit),
        .cen(cen), .lback_mode(lback_mode), .sleep_mode(sleep_mode),
        .tx_frame_avail(tx_frame_avail), .tx_rd_id(tx_rd_id), .tx_rd_ide(tx_rd_ide),
        .tx_rd_rtr(tx_rd_rtr), .tx_rd_dlc(tx_rd_dlc), .tx_rd_data(tx_rd_data),
        .tx_rd_en(tx_rd_en), .crc_clear(crc_clear), .crc_update_en(crc_update_en),
        .crc_bit_in(crc_bit_in), .crc_value(crc_value),
        .destuffed_bit_out(destuffed_bit_out), .destuffed_bit_valid(destuffed_bit_valid),
        .stuff_bit_dropped(stuff_bit_dropped), .stuff_error(stuff_error),
        .destuff_en(destuff_en), .destuff_reset(destuff_reset),
        .rx_frame_valid(rx_frame_valid), .rx_frame_idr(rx_frame_idr),
        .rx_frame_dlcr(rx_frame_dlcr), .rx_frame_dw1r(rx_frame_dw1r),
        .rx_frame_dw2r(rx_frame_dw2r), .tx_success_pulse(tx_success_pulse),
        .tx_error_pulse(tx_error_pulse), .tx_arblst_pulse(tx_arblst_pulse),
        .rx_ok_pulse(rx_ok_pulse), .tx_busy(tx_busy), .tec(tec), .rec(rec),
        .estat(estat), .errwrn(errwrn), .bus_off(bus_off),
        .err_acker(err_acker), .err_berr(err_berr), .err_ster(err_ster),
        .err_fmer(err_fmer), .err_crcer(err_crcer)
    );

endmodule
