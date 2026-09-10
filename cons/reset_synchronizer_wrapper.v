`timescale 1ns / 1ps

module reset_synchronizer_wrapper (
    input  wire clk,
    input  wire rst_n_async,
    output wire rst_n_sync
);

    reset_synchronizer u_sync (
        .clk        (clk),
        .rst_n_async(rst_n_async),
        .rst_n_sync (rst_n_sync)
    );

endmodule