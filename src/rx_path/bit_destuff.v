`timescale 1ns / 1ps

module bit_destuff (
    input  wire can_clk,
    input  wire can_rst_n_sync,

    input  wire sample_point,
    input  wire destuff_en,
    input  wire destuff_reset,
    input  wire raw_bit_in,

    output reg  destuffed_bit_out,
    output reg  destuffed_bit_valid,
    output reg  stuff_bit_dropped,
    output reg  stuff_error
);

    localparam DOMINANT  = 1'b0;
    localparam RECESSIVE = 1'b1;

    reg [2:0] run_len;
    reg       last_bit;

    reg [2:0] next_run_len;
    reg       next_last_bit;
    reg       next_destuffed_bit_out;
    reg       next_destuffed_bit_valid;
    reg       next_stuff_bit_dropped;
    reg       next_stuff_error;

    always @(*) begin
        next_run_len             = run_len;
        next_last_bit            = last_bit;
        next_destuffed_bit_out   = destuffed_bit_out;
        next_destuffed_bit_valid = 1'b0;
        next_stuff_bit_dropped   = 1'b0;
        next_stuff_error         = 1'b0;

        if (sample_point) begin
            if (!destuff_en) begin
                next_destuffed_bit_out   = raw_bit_in;
                next_destuffed_bit_valid = 1'b1;
                next_run_len             = 3'd0;
                next_last_bit            = raw_bit_in;
            end else begin
                if (run_len == 3'd5) begin
                    if (raw_bit_in == ~last_bit) begin
                        // Valid complementary stuff bit -> drop it from data stream
                        next_stuff_bit_dropped = 1'b1;
                        next_run_len           = 3'd1;
                        next_last_bit          = raw_bit_in;
                    end else begin
                        // 6 consecutive identical bits during stuffed field -> Stuff Error!
                        next_stuff_error = 1'b1;
                        next_run_len     = 3'd0;
                    end
                end else begin
                    next_destuffed_bit_out   = raw_bit_in;
                    next_destuffed_bit_valid = 1'b1;

                    if (run_len != 3'd0 && raw_bit_in == last_bit) begin
                        next_run_len = run_len + 3'd1;
                    end else begin
                        next_run_len  = 3'd1;
                        next_last_bit = raw_bit_in;
                    end
                end
            end
        end
    end

    always @(posedge can_clk or negedge can_rst_n_sync) begin
        if (!can_rst_n_sync) begin
            destuffed_bit_out   <= RECESSIVE;
            destuffed_bit_valid <= 1'b0;
            stuff_bit_dropped   <= 1'b0;
            stuff_error         <= 1'b0;
            run_len             <= 3'd1;
            last_bit            <= DOMINANT;
        end else if (destuff_reset) begin
            destuffed_bit_out   <= RECESSIVE;
            destuffed_bit_valid <= 1'b0;
            stuff_bit_dropped   <= 1'b0;
            stuff_error         <= 1'b0;
            run_len             <= 3'd1;
            last_bit            <= DOMINANT;
        end else begin
            destuffed_bit_out   <= next_destuffed_bit_out;
            destuffed_bit_valid <= next_destuffed_bit_valid;
            stuff_bit_dropped   <= next_stuff_bit_dropped;
            stuff_error         <= next_stuff_error;
            run_len             <= next_run_len;
            last_bit            <= next_last_bit;
        end
    end

endmodule
