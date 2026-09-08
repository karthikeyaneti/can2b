`timescale 1ns / 1ps

module reset_synchronizer (
    input wire clk,
    input wire rst_n_async,
    output wire rst_n_sync
);

    (* ASYNC_REG = "TRUE" *) reg S1;
    (* ASYNC_REG = "TRUE" *) reg S2;

    always @(posedge clk or negedge rst_n_async) begin
        if (!rst_n_async) begin
            S1 <= 1'b0;
            S2 <= 1'b0;
        end else begin
            S1 <= 1'b1;
            S2 <= S1;
        end
    end

    assign rst_n_sync = S2;

endmodule