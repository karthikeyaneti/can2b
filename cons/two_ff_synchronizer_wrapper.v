`timescale 1ns / 1ps

module two_ff_synchronizer_wrapper #(
    parameter WIDTH = 1
) (
    input  wire                 src_clk,
    input  wire                 dst_clk,
    input  wire                 rst_n_async,
    input  wire [WIDTH-1:0]     src_data,
    output wire [WIDTH-1:0]     sync_data
);

    reg [WIDTH-1:0] src_data_q;

    always @(posedge src_clk or negedge rst_n_async) begin
        if (!rst_n_async)
            src_data_q <= {WIDTH{1'b0}};
        else
            src_data_q <= src_data;
    end

    two_ff_synchronizer #(
        .WIDTH(WIDTH)
    ) u_sync (
        .clk       (dst_clk),
        .rst_n_sync(rst_n_async),
        .async_in  (src_data_q),
        .sync_out  (sync_data)
    );

endmodule