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

    always @(posedge can_clk) begin
        if (!can_rst_n_sync || destuff_reset) begin
            destuffed_bit_out   <= RECESSIVE;
            destuffed_bit_valid <= 1'b0;
            stuff_bit_dropped   <= 1'b0;
            stuff_error         <= 1'b0;
            // SOF is dominant and belongs to the stuffed field.  Preserve it
            // as the first run bit so a stuff bit immediately after SOF is
            // recognized rather than delivered as frame data.
            run_len             <= 3'd1;
            last_bit            <= DOMINANT;
        end else begin
            destuffed_bit_valid <= 1'b0;
            stuff_bit_dropped   <= 1'b0;
            stuff_error         <= 1'b0;

            if (sample_point) begin
                if (!destuff_en) begin
                    destuffed_bit_out   <= raw_bit_in;
                    destuffed_bit_valid <= 1'b1;
                    run_len             <= 3'd0;
                    last_bit            <= raw_bit_in;
                end else begin
                    if (run_len == 3'd5) begin
                        if (raw_bit_in == ~last_bit) begin
                            // Valid complementary stuff bit -> drop it from data stream
                            stuff_bit_dropped <= 1'b1;
                            run_len           <= 3'd1;
                            last_bit          <= raw_bit_in;
                        end else begin
                            // 6 consecutive identical bits during stuffed field -> Stuff Error!
                            stuff_error <= 1'b1;
                            run_len     <= 3'd0;
                        end
                    end else begin
                        destuffed_bit_out   <= raw_bit_in;
                        destuffed_bit_valid <= 1'b1;

                        if (run_len != 3'd0 && raw_bit_in == last_bit) begin
                            run_len <= run_len + 3'd1;
                        end else begin
                            run_len  <= 3'd1;
                            last_bit <= raw_bit_in;
                        end
                    end
                end
            end
        end
    end

endmodule
