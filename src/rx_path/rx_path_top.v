`timescale 1ns / 1ps

module rx_path_top #(
    parameter FIFO_ADDR_WIDTH = 4
) (
    // Host / APB Clock Domain
    input  wire        pclk,
    input  wire        presetn,
    input  wire        rx_pop,
    output wire [31:0] rx_idr,
    output wire [31:0] rx_dlcr,
    output wire [31:0] rx_dw1r,
    output wire [31:0] rx_dw2r,
    output wire        rx_empty,
    output wire        rx_not_empty,
    output wire        rx_underflow_pulse,

    // Acceptance Filter Registers (pclk domain)
    input  wire [3:0]  uaf,
    input  wire [31:0] afmr1,
    input  wire [31:0] afir1,
    input  wire [31:0] afmr2,
    input  wire [31:0] afir2,
    input  wire [31:0] afmr3,
    input  wire [31:0] afir3,
    input  wire [31:0] afmr4,
    input  wire [31:0] afir4,

    // CAN Clock Domain
    input  wire        can_clk,
    input  wire        can_rst_n_sync,
    input  wire        sample_point,
    input  wire        sampled_bit,
    input  wire        destuff_en,
    input  wire        destuff_reset,

    output wire        destuffed_bit_out,
    output wire        destuffed_bit_valid,
    output wire        stuff_bit_dropped,
    output wire        stuff_error,

    // Interface from BSP (when a valid frame is received)
    input  wire        rx_frame_valid,
    input  wire [31:0] rx_frame_idr,
    input  wire [31:0] rx_frame_dlcr,
    input  wire [31:0] rx_frame_dw1r,
    input  wire [31:0] rx_frame_dw2r,
    output wire        rx_frame_accepted,
    output wire        rx_overflow_pulse
);

    // 1. Bit De-stuffing
    bit_destuff u_destuff (
        .can_clk            (can_clk),
        .can_rst_n_sync     (can_rst_n_sync),
        .sample_point       (sample_point),
        .destuff_en         (destuff_en),
        .destuff_reset      (destuff_reset),
        .raw_bit_in         (sampled_bit),
        .destuffed_bit_out   (destuffed_bit_out),
        .destuffed_bit_valid (destuffed_bit_valid),
        .stuff_bit_dropped   (stuff_bit_dropped),
        .stuff_error         (stuff_error)
    );

    // 2. Acceptance Filtering
    wire filter_match;
    acceptance_filter u_acc_filter (
        .msg_id_in    (rx_frame_idr),
        .uaf          (uaf),
        .afmr1        (afmr1),
        .afir1        (afir1),
        .afmr2        (afmr2),
        .afir2        (afir2),
        .afmr3        (afmr3),
        .afir3        (afir3),
        .afmr4        (afmr4),
        .afir4        (afir4),
        .filter_match (filter_match)
    );

    assign rx_frame_accepted = rx_frame_valid && filter_match;

    // 3. Receive FIFO
    wire rx_fifo_full;
    rx_fifo #(
        .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) u_rx_fifo (
        .wr_clk             (can_clk),
        .wr_rst_n_sync      (can_rst_n_sync),
        .rx_push            (rx_frame_accepted),
        .rx_push_idr        (rx_frame_idr),
        .rx_push_dlcr       (rx_frame_dlcr),
        .rx_push_dw1r       (rx_frame_dw1r),
        .rx_push_dw2r       (rx_frame_dw2r),
        .rx_fifo_full       (rx_fifo_full),
        .rx_overflow_pulse  (rx_overflow_pulse),

        .rd_clk             (pclk),
        .rd_rst_n_sync      (presetn),
        .rx_pop             (rx_pop),
        .rx_idr             (rx_idr),
        .rx_dlcr            (rx_dlcr),
        .rx_dw1r            (rx_dw1r),
        .rx_dw2r            (rx_dw2r),
        .rx_empty           (rx_empty),
        .rx_not_empty       (rx_not_empty),
        .rx_underflow_pulse (rx_underflow_pulse)
    );

endmodule
