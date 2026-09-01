`timescale 1ns / 1ps

module can_baud_gen (
    input wire can_clk,
    input wire can_rst_n_sync,

    input wire config_mode,
    input wire [7:0] brp,

    output reg tq_tick
);

    reg [7:0] tq_count;

    always @(posedge can_clk) begin
        if (!can_rst_n_sync) begin
            tq_tick  <= 1'b0;
            tq_count <= 8'd0;
        end else if (config_mode) begin
            tq_tick  <= 1'b0;
            tq_count <= 8'd0;
        end else begin
            if (tq_count == brp) begin
                tq_tick  <= 1'b1;
                tq_count <= 8'd0;
            end else begin
                tq_tick  <= 1'b0;
                tq_count <= tq_count + 8'd1;
            end
        end
    end

endmodule