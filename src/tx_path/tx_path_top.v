`timescale 1ns / 1ps

module tx_path_top #(
    parameter FIFO_ADDR_WIDTH = 4
) (
    // APB / Register Clock Domain
    input  wire        pclk,
    input  wire        presetn,
    input  wire        tx_wr_en,
    input  wire [28:0] tx_wr_id,
    input  wire        tx_wr_ide,
    input  wire        tx_wr_rtr,
    input  wire [3:0]  tx_wr_dlc,
    input  wire [63:0] tx_wr_data,
    output wire        tx_fifo_full,

    // CAN Clock Domain
    input  wire        can_clk,
    input  wire        can_rst_n_sync,

    // Bit Timing Engine (BTL) Interface
    input  wire        sample_point,
    input  wire        sampled_bit,
    input  wire        bit_tick,
    output wire        tx_active,
    output wire        bus_idle,
    output wire        can_tx,

    // Status & Event Signals (CAN clock domain)
    output wire        tx_success_pulse,
    output wire        tx_error_pulse,
    output wire        tx_arblst_pulse,
    output wire        tx_busy,
    output wire        tx_fifo_empty
);

    // TX FIFO read interface wires
    wire [28:0] tx_rd_id;
    wire        tx_rd_ide;
    wire        tx_rd_rtr;
    wire [3:0]  tx_rd_dlc;
    wire [63:0] tx_rd_data;
    wire        tx_frame_avail;
    wire        tx_rd_en;

    // CRC generator wires
    wire        crc_clear;
    wire        crc_update_en;
    wire        crc_bit_in;
    wire [14:0] crc_value;

    // Output bit
    wire        can_tx_bit;
    assign can_tx = can_tx_bit;

    // 1. Instantiate TX FIFO
    tx_fifo #(
        .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) u_tx_fifo (
        .wr_clk        (pclk),
        .wr_rst_n_sync (presetn),
        .tx_wr_en      (tx_wr_en),
        .tx_wr_id      (tx_wr_id),
        .tx_wr_ide     (tx_wr_ide),
        .tx_wr_rtr     (tx_wr_rtr),
        .tx_wr_dlc     (tx_wr_dlc),
        .tx_wr_data    (tx_wr_data),
        .tx_fifo_full  (tx_fifo_full),

        .rd_clk        (can_clk),
        .rd_rst_n_sync (can_rst_n_sync),
        .tx_rd_en      (tx_rd_en),
        .tx_rd_id      (tx_rd_id),
        .tx_rd_ide     (tx_rd_ide),
        .tx_rd_rtr     (tx_rd_rtr),
        .tx_rd_dlc     (tx_rd_dlc),
        .tx_rd_data    (tx_rd_data),
        .tx_frame_avail(tx_frame_avail),
        .tx_fifo_empty (tx_fifo_empty)
    );

    // 2. Instantiate CRC Generator
    crc_gen u_crc_gen (
        .can_clk        (can_clk),
        .can_rst_n_sync (can_rst_n_sync),
        .bit_in         (crc_bit_in),
        .bit_in_valid   (crc_update_en),
        .bit_in_ready   (),
        .crc_clear      (crc_clear),
        .crc_update_en  (crc_update_en),
        .crc_emit_en    (1'b0),
        .bit_out        (),
        .bit_out_valid  (),
        .crc_emit_done  (),
        .crc_value      (crc_value)
    );

    // 3. Instantiate Bit Stream Processor (BSP)
    can_bsp u_can_bsp (
        .can_clk            (can_clk),
        .can_rst_n_sync     (can_rst_n_sync),
        .sample_point       (sample_point),
        .sampled_bit        (sampled_bit),
        .bit_tick           (bit_tick),
        .tx_active          (tx_active),
        .bus_idle           (bus_idle),
        .can_tx_bit         (can_tx_bit),

        .tx_frame_avail     (tx_frame_avail),
        .tx_rd_id           (tx_rd_id),
        .tx_rd_ide          (tx_rd_ide),
        .tx_rd_rtr          (tx_rd_rtr),
        .tx_rd_dlc          (tx_rd_dlc),
        .tx_rd_data         (tx_rd_data),
        .tx_rd_en           (tx_rd_en),

        .crc_clear          (crc_clear),
        .crc_update_en      (crc_update_en),
        .crc_bit_in         (crc_bit_in),
        .crc_value          (crc_value),

        .tx_success_pulse   (tx_success_pulse),
        .tx_error_pulse     (tx_error_pulse),
        .tx_arblst_pulse    (tx_arblst_pulse),
        .tx_busy            (tx_busy)
    );

endmodule
