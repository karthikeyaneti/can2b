`timescale 1ns / 1ps

module reset_synchronizer_wrapper (
    input  wire clk,
    input  wire rst_n_async,
    output wire rst_n_sync
);

    reg reset_probe;

    reset_synchronizer u_sync (
        .clk        (clk),
        .rst_n_async(rst_n_async),
        .rst_n_sync (rst_n_sync)
    );

    always @(posedge clk or negedge rst_n_sync) begin
        if (!rst_n_sync)
            reset_probe <= 1'b0;
        else
            reset_probe <= 1'b1;
    end

endmodule