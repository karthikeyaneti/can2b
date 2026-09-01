`timescale 1ns / 1ps

module two_ff_synchronizer #(
    parameter WIDTH = 1,
    parameter [WIDTH-1:0] INIT_VALUE = {WIDTH{1'b1}}
) (
    input wire clk,
    input wire rst_n_sync,
    input wire [WIDTH-1:0] async_in,
    output wire [WIDTH-1:0] sync_out
);

    // (* ASYNC_REG = "TRUE" DONT_TOUCH = "TRUE" *) reg [WIDTH-1:0] S1;
    // (* ASYNC_REG = "TRUE" DONT_TOUCH = "TRUE" *) reg [WIDTH-1:0] S2;
    reg [WIDTH-1:0] S1, S2;

    always @(posedge clk or negedge rst_n_sync) begin
        if (!rst_n_sync) begin
            S1 <= INIT_VALUE;
            S2 <= INIT_VALUE;
        end else begin
            S1 <= async_in;
            S2 <= S1;
        end
    end

    assign sync_out = S2;
endmodule