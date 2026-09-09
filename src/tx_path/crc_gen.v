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

    function [14:0] crc_step;
        input [14:0] current_crc;
        input        data_bit;
        reg          feedback;
        begin
            feedback      = data_bit ^ current_crc[14];
            crc_step[0]   = feedback;
            crc_step[1]   = current_crc[0];
            crc_step[2]   = current_crc[1];
            crc_step[3]   = current_crc[2] ^ feedback;
            crc_step[4]   = current_crc[3] ^ feedback;
            crc_step[5]   = current_crc[4];
            crc_step[6]   = current_crc[5];
            crc_step[7]   = current_crc[6] ^ feedback;
            crc_step[8]   = current_crc[7] ^ feedback;
            crc_step[9]   = current_crc[8];
            crc_step[10]  = current_crc[9] ^ feedback;
            crc_step[11]  = current_crc[10];
            crc_step[12]  = current_crc[11];
            crc_step[13]  = current_crc[12];
            crc_step[14]  = current_crc[13] ^ feedback;
        end
    endfunction

    assign bit_in_ready = !emit_active && !crc_emit_en;
    assign crc_value = crc_reg;

    always @(*) begin
        next_crc = crc_step(crc_reg, bit_in);
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
                crc_reg     <= (accept_in && crc_update_en) ? crc_step(15'd0, bit_in) : 15'd0;
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