`timescale 1ns/1ps

module bit_stuff (
    input  wire can_clk,
    input  wire can_rst_n_sync,

    input  wire stuff_en,
    input  wire stuff_reset,
    input  wire tx_bit_in,
    input  wire tx_bit_in_valid,
    
    output reg  tx_bit_out,
    output reg  tx_bit_out_valid,
    output reg  tx_bit_in_ready,
    output reg  stuff_inserted
);

    localparam  DOMINANT  = 1'b0;
    localparam  RECESSIVE = 1'b1;

    reg         last_bit;
    reg [2:0]   run_len;
    reg         insert_pending;
    reg         stuffed_bit;

    always @(posedge can_clk) begin
        if (!can_rst_n_sync) begin
            tx_bit_out        <= RECESSIVE;
            tx_bit_out_valid  <= 1'b0;
            tx_bit_in_ready   <= 1'b1;
            stuff_inserted    <= 1'b0;
            last_bit          <= RECESSIVE;
            run_len           <= 3'd0;
            insert_pending    <= 1'b0;
            stuffed_bit       <= RECESSIVE;
        end else if (stuff_reset) begin
            tx_bit_out        <= RECESSIVE;
            tx_bit_out_valid  <= 1'b0;
            tx_bit_in_ready   <= 1'b1;
            stuff_inserted    <= 1'b0;
            last_bit          <= RECESSIVE;
            run_len           <= 3'd0;
            insert_pending    <= 1'b0;
            stuffed_bit       <= RECESSIVE;
        end else begin
            tx_bit_out_valid <= 1'b0;
            stuff_inserted   <= 1'b0;

            if (insert_pending) begin
                tx_bit_out       <= stuffed_bit;
                tx_bit_out_valid <= 1'b1;
                stuff_inserted   <= 1'b1;
                tx_bit_in_ready  <= 1'b1;
                insert_pending   <= 1'b0;
                last_bit         <= stuffed_bit;
                run_len          <= 3'd1;
            end else if (tx_bit_in_valid && tx_bit_in_ready) begin
                tx_bit_out       <= tx_bit_in;
                tx_bit_out_valid <= 1'b1;

                if (!stuff_en) begin
                    last_bit        <= tx_bit_in;
                    run_len         <= 3'd0;
                    tx_bit_in_ready <= 1'b1;
                    insert_pending  <= 1'b0;
                end else begin
                    if (run_len != 3'd0 && tx_bit_in == last_bit) begin
                        if (run_len == 3'd4) begin
                            // This is the 5th consecutive identical bit!
                            // Output it now, and schedule complementary stuff bit next cycle
                            stuffed_bit     <= ~tx_bit_in;
                            insert_pending  <= 1'b1;
                            tx_bit_in_ready <= 1'b0;
                            last_bit        <= tx_bit_in;
                            run_len         <= 3'd5;
                        end else begin
                            run_len         <= run_len + 3'd1;
                            tx_bit_in_ready <= 1'b1;
                        end
                    end else begin
                        // First bit or changed polarity
                        last_bit        <= tx_bit_in;
                        run_len         <= 3'd1;
                        tx_bit_in_ready <= 1'b1;
                    end
                end
            end else begin
                if (!insert_pending) begin
                    tx_bit_in_ready <= 1'b1;
                end
            end
        end
    end

endmodule