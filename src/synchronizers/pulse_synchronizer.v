`timescale 1ns/1ps

// Transfers isolated pulses from a source clock domain to a destination
// clock domain. Each source pulse toggles a bit; the destination detects the
// synchronized toggle change and produces one destination-clock pulse.
module pulse_synchronizer (
    input  wire src_clk,
    input  wire src_rst_n,
    input  wire src_pulse,
    input  wire dst_clk,
    input  wire dst_rst_n,
    output wire dst_pulse
);

    (* ASYNC_REG = "TRUE" *) reg dst_sync1;
    (* ASYNC_REG = "TRUE" *) reg dst_sync2;
    reg src_toggle;
    reg dst_toggle_d;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n)
            src_toggle <= 1'b0;
        else if (src_pulse)
            src_toggle <= ~src_toggle;
    end

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            dst_sync1   <= 1'b0;
            dst_sync2   <= 1'b0;
            dst_toggle_d <= 1'b0;
        end else begin
            dst_sync1    <= src_toggle;
            dst_sync2    <= dst_sync1;
            dst_toggle_d <= dst_sync2;
        end
    end

    assign dst_pulse = dst_sync2 ^ dst_toggle_d;

endmodule
