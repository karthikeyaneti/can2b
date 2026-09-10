`timescale 1ns / 1ps

module can_btl_top (
    input  wire       can_clk,
    input  wire       can_rst_n,

    input  wire       config_mode,

    input  wire [7:0] brp,
    input  wire [3:0] tseg1,
    input  wire [2:0] tseg2,
    input  wire [1:0] sjw,

    input  wire       rx_in,

    input  wire       bus_idle,
    input  wire       tx_active,
    input  wire       tx_bit,

    output wire       hard_sync_pulse,
    output wire       resync_pulse,
    output wire       sample_point,
    output wire       sampled_bit,
    output wire       bit_tick
);

    // can_rst_n is already synchronized by the caller (can_channel_core).
    // Using it directly avoids adding an extra pipeline stage that would skew
    // the BTL reset relative to the rest of the CAN engine.
    wire can_rst_n_sync = can_rst_n;

    wire rx_sync;
    two_ff_synchronizer #(
        .WIDTH     (1),
        .INIT_VALUE(1'b1)
    ) rx_synchronizer (
        .clk       (can_clk),
        .rst_n_sync(can_rst_n_sync),
        .async_in  (rx_in),
        .sync_out  (rx_sync)
    );


    wire tq_tick;
    can_baud_gen tq_tick_generator (
        .can_clk        (can_clk),
        .can_rst_n_sync (can_rst_n_sync),
        .config_mode    (config_mode),
        .brp            (brp),
        .tq_tick        (tq_tick)
    );

    can_bit_timing_logic bit_timing_logic (
        .can_clk         (can_clk),
        .can_rst_n_sync  (can_rst_n_sync),
        .config_mode     (config_mode),

        .tq_tick         (tq_tick),

        .tseg1           (tseg1),
        .tseg2           (tseg2),
        .sjw             (sjw),

        .rx_sync         (rx_sync),

        .bus_idle        (bus_idle),

        .tx_active       (tx_active),
        .tx_bit          (tx_bit),

        .hard_sync_pulse (hard_sync_pulse),
        .resync_pulse    (resync_pulse),
        .sample_point    (sample_point),
        .sampled_bit     (sampled_bit),
        .bit_tick        (bit_tick)
    );

endmodule