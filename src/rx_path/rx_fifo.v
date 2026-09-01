`timescale 1ns / 1ps

module rx_fifo #(
    parameter ADDR_WIDTH = 4
) (
    // Write Domain (CAN Core Clock)
    input  wire        wr_clk,
    input  wire        wr_rst_n_sync,
    input  wire        rx_push,
    input  wire [31:0] rx_push_idr,
    input  wire [31:0] rx_push_dlcr,
    input  wire [31:0] rx_push_dw1r,
    input  wire [31:0] rx_push_dw2r,
    output wire        rx_fifo_full,
    output reg         rx_overflow_pulse,

    // Read Domain (APB / Host Clock)
    input  wire        rd_clk,
    input  wire        rd_rst_n_sync,
    input  wire        rx_pop,
    output wire [31:0] rx_idr,
    output wire [31:0] rx_dlcr,
    output wire [31:0] rx_dw1r,
    output wire [31:0] rx_dw2r,
    output wire        rx_empty,
    output wire        rx_not_empty,
    output reg         rx_underflow_pulse
);

    localparam DATA_WIDTH = 128;

    wire [DATA_WIDTH-1:0] wr_data;
    wire [DATA_WIDTH-1:0] rd_data;

    assign wr_data = {rx_push_idr, rx_push_dlcr, rx_push_dw1r, rx_push_dw2r};

    // Instantiate dual-clock asynchronous CAN FIFO
    can_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_can_fifo (
        .wr_clk        (wr_clk),
        .rd_clk        (rd_clk),
        .wr_rst_n_sync (wr_rst_n_sync),
        .rd_rst_n_sync (rd_rst_n_sync),
        .wr_en         (rx_push && !rx_fifo_full),
        .rd_en         (rx_pop && !rx_empty),
        .wr_data       (wr_data),
        .rd_data       (rd_data),
        .empty         (rx_empty),
        .full          (rx_fifo_full)
    );

    // Overflow & Underflow detection
    always @(posedge wr_clk or negedge wr_rst_n_sync) begin
        if (!wr_rst_n_sync) begin
            rx_overflow_pulse <= 1'b0;
        end else begin
            rx_overflow_pulse <= rx_push && rx_fifo_full;
        end
    end

    always @(posedge rd_clk or negedge rd_rst_n_sync) begin
        if (!rd_rst_n_sync) begin
            rx_underflow_pulse <= 1'b0;
        end else begin
            rx_underflow_pulse <= rx_pop && rx_empty;
        end
    end

    // Unpack 16-byte message for host reads
    assign rx_idr       = rd_data[127:96];
    assign rx_dlcr      = rd_data[95:64];
    assign rx_dw1r      = rd_data[63:32];
    assign rx_dw2r      = rd_data[31:0];
    assign rx_not_empty = ~rx_empty;

endmodule
