`timescale 1ns/1ps

module error_management_logic (
    input  wire       can_clk,
    input  wire       can_rst_n_sync,
    input  wire       tx_success,
    input  wire       tx_error,
    input  wire       arbitration_lost,
    input  wire       rx_success,
    input  wire       err_acker,
    input  wire       err_berr,
    input  wire       err_ster,
    input  wire       err_fmer,
    input  wire       err_crcer,
    output reg [7:0] tec,
    output reg [7:0] rec,
    output wire [1:0] estat,
    output wire       errwrn,
    output wire       bus_off
);

    reg error_seen_d;
    reg [8:0] tec_count;
    wire receive_error = err_acker | err_berr | err_ster | err_fmer | err_crcer;

    // TEC is exposed as an 8-bit saturated register, but CAN bus-off begins
    // at an internal TEC value of 256.
    assign bus_off = (tec_count >= 9'd256);
    assign estat = bus_off ? 2'b10 :
                   ((tec_count >= 9'd128) || (rec >= 8'd128)) ? 2'b01 : 2'b00;
    assign errwrn = (tec >= 8'd96) || (rec >= 8'd96);

    always @(posedge can_clk) begin
        if (!can_rst_n_sync) begin
            tec          <= 8'd0;
            tec_count    <= 9'd0;
            rec          <= 8'd0;
            error_seen_d <= 1'b0;
        end else begin
            error_seen_d <= receive_error;

            if (tx_error) begin
                // An error increment from 248 or above crosses the 256
                // threshold; retain that state internally.
                if (tec_count >= 9'd248) begin
                    tec_count <= 9'd256;
                    tec       <= 8'hFF;
                end else begin
                    tec_count <= tec_count + 9'd8;
                    tec       <= tec_count[7:0] + 8'd8;
                end
            end else if (tx_success && (tec_count != 9'd0)) begin
                tec_count <= tec_count - 9'd1;
                tec       <= (tec_count > 9'd255) ? 8'hFF : tec_count[7:0] - 8'd1;
            end

            if (receive_error && !error_seen_d)
                rec <= (rec <= 8'd247) ? rec + 8'd8 : 8'd255;
            else if (rx_success && (rec != 8'd0))
                rec <= rec - 8'd1;
        end
    end

endmodule
