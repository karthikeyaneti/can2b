`timescale 1ns / 1ps

module pulse_synchronizer_wrapper (
    input  wire src_clk,
    input  wire src_rst_n,
    input  wire src_pulse,
    input  wire dst_clk,
    input  wire dst_rst_n,
    output wire dst_pulse
);

    pulse_synchronizer u_sync (
        .src_clk  (src_clk),
        .src_rst_n(src_rst_n),
        .src_pulse(src_pulse),
        .dst_clk  (dst_clk),
        .dst_rst_n(dst_rst_n),
        .dst_pulse(dst_pulse)
    );

endmodule