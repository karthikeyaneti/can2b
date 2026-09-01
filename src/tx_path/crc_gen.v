`timescale 1ns/1ps

module crc_gen (
    input  wire        can_clk,
    input  wire        can_rst_n_sync,

    input  wire        bit_in,
    input  wire        bit_in_valid,
    output wire        bit_in_ready,

    input  wire        crc_clear,
    input  wire        crc_update_en,
    input  wire        crc_emit_en,

    output reg         bit_out,
    output reg         bit_out_valid,
    output reg         crc_emit_done,
    output wire [14:0] crc_value
);

    reg [14:0] crc_reg;
    reg [14:0] crc_shift;
    reg [14:0] next_crc;
    reg [3:0]  emit_count;
    reg        emit_active;
    reg        crc_emit_en_d;

    wire start_emit = crc_emit_en && !crc_emit_en_d;
    wire accept_in  = bit_in_valid && bit_in_ready;

    assign bit_in_ready = !emit_active && !crc_emit_en;
    assign crc_value = crc_reg;

    always @(*) begin
        next_crc[0]  = bit_in ^ crc_reg[14];
        next_crc[1]  = crc_reg[0];
        next_crc[2]  = crc_reg[1];
        next_crc[3]  = crc_reg[2] ^ next_crc[0];
        next_crc[4]  = crc_reg[3] ^ next_crc[0];
        next_crc[5]  = crc_reg[4];
        next_crc[6]  = crc_reg[5];
        next_crc[7]  = crc_reg[6] ^ next_crc[0];
        next_crc[8]  = crc_reg[7] ^ next_crc[0];
        next_crc[9]  = crc_reg[8];
        next_crc[10] = crc_reg[9] ^ next_crc[0];
        next_crc[11] = crc_reg[10];
        next_crc[12] = crc_reg[11];
        next_crc[13] = crc_reg[12];
        next_crc[14] = crc_reg[13] ^ next_crc[0];
    end

    always @(posedge can_clk) begin
        if (!can_rst_n_sync) begin
            crc_reg       <= 15'd0;
            crc_shift     <= 15'd0;
            emit_count    <= 4'd0;
            emit_active   <= 1'b0;
            crc_emit_en_d <= 1'b0;
            bit_out       <= 1'b1;
            bit_out_valid <= 1'b0;
            crc_emit_done <= 1'b0;
        end else begin
            crc_emit_en_d <= crc_emit_en;
            bit_out_valid <= 1'b0;
            crc_emit_done <= 1'b0;

            if (crc_clear) begin
                crc_reg     <= 15'd0;
                crc_shift   <= 15'd0;
                emit_count  <= 4'd0;
                emit_active <= 1'b0;
            end else if (start_emit) begin
                crc_shift   <= crc_reg;
                emit_count  <= 4'd15;
                emit_active <= 1'b1;
            end else if (emit_active) begin
                bit_out       <= crc_shift[14];
                bit_out_valid <= 1'b1;
                crc_shift     <= {crc_shift[13:0], 1'b0};

                if (emit_count == 4'd1) begin
                    emit_count    <= 4'd0;
                    emit_active   <= 1'b0;
                    crc_emit_done <= 1'b1;
                end else begin
                    emit_count <= emit_count - 4'd1;
                end
            end else if (accept_in) begin
                bit_out       <= bit_in;
                bit_out_valid <= 1'b1;

                if (crc_update_en) begin
                    crc_reg <= next_crc;
                end
            end
        end
    end

endmodule