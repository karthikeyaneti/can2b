`timescale 1ns / 1ps

module pulse_synchronizer_wrapper (
    input  wire src_clk,
    input  wire src_rst_n,
    input  wire src_pulse,
    input  wire dst_clk,
    input  wire dst_rst_n,
    output wire dst_pulse
);

    wire src_rst_n_sync;
    wire dst_rst_n_sync;

    reset_synchronizer u_src_reset (
        .clk        (src_clk),
        .rst_n_async(src_rst_n),
        .rst_n_sync (src_rst_n_sync)
    );

    reset_synchronizer u_dst_reset (
        .clk        (dst_clk),
        .rst_n_async(dst_rst_n),
        .rst_n_sync (dst_rst_n_sync)
    );

    pulse_synchronizer u_sync (
        .src_clk  (src_clk),
        .src_rst_n(src_rst_n_sync),
        .src_pulse(src_pulse),
        .dst_clk  (dst_clk),
        .dst_rst_n(dst_rst_n_sync),
        .dst_pulse(dst_pulse)
    );

endmodule