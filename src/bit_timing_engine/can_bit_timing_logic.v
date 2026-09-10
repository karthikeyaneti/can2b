`timescale 1ns / 1ps

module can_bit_timing_logic (
    input  wire       can_clk,
    input  wire       can_rst_n_sync,

    input  wire       config_mode,
    input  wire       tq_tick,

    input  wire [3:0] tseg1,
    input  wire [2:0] tseg2,
    input  wire [1:0] sjw,

    input  wire       rx_sync,
    input  wire       bus_idle,     // from BSP
    input  wire       tx_active,    // from BSP
    input  wire       tx_bit,       // bit being transmitted

    output reg        hard_sync_pulse,
    output reg        resync_pulse,
    output reg        sample_point,
    output reg        sampled_bit,
    output reg        bit_tick
);

    localparam DOMINANT  = 1'b0;
    localparam RECESSIVE = 1'b1;

    localparam [1:0] SEG_IDLE  = 2'b00;
    localparam [1:0] SEG_SYNC  = 2'b01;
    localparam [1:0] SEG_TSEG1 = 2'b10;
    localparam [1:0] SEG_TSEG2 = 2'b11;

    // TSEG1: 1..16, TSEG2: 1..8, SJW: 1..4
    localparam [4:0] MAX_TSEG1 = 5'd16;

    reg [4:0] tseg1_eff;
    reg [4:0] tseg2_eff;
    reg [4:0] sjw_eff;

    wire [4:0] tseg1_calc = {1'b0, tseg1} + 5'd1;
    wire [4:0] tseg2_calc = {2'b00, tseg2} + 5'd1;
    wire [4:0] sjw_calc   = {3'b000, sjw} + 5'd1;

    always @(posedge can_clk) begin
        if (!can_rst_n_sync) begin
            tseg1_eff <= 5'd6;
            tseg2_eff <= 5'd3;
            sjw_eff   <= 5'd2;
        end else if (config_mode) begin
            tseg1_eff <= tseg1_calc;
            tseg2_eff <= tseg2_calc;

            // SJW can't exceed either phase buffer segment
            if (sjw_calc > tseg1_calc)
                sjw_eff <= tseg1_calc;
            else if (sjw_calc > tseg2_calc)
                sjw_eff <= tseg2_calc;
            else
                sjw_eff <= sjw_calc;
        end
    end

    reg rx_sync_q;
    reg edge_pending;

    wire dominant_edge = (rx_sync_q == RECESSIVE) && (rx_sync == DOMINANT);

    wire qualified_edge = dominant_edge &&
                          (sampled_bit == RECESSIVE) &&
                          !(tx_active && (tx_bit == DOMINANT));

    wire sync_edge = bus_idle ? dominant_edge : qualified_edge;

    wire new_edge = sync_edge;
    wire edge_available = edge_pending || new_edge;

    reg [1:0] present_seg;
    reg [4:0] tq_count;      // TQs already completed in this segment
    reg [4:0] cur_tseg1;
    reg [4:0] cur_tseg2;
    reg       sync_done_this_bit;

    wire [4:0] tq_elapsed = tq_count + 5'd1;

    // late edge in TSEG1
    wire [4:0] late_error = tq_elapsed;
    wire [4:0] late_delta = (late_error > sjw_eff) ? sjw_eff : late_error;

    // early edge in TSEG2
    wire [4:0] early_error = (cur_tseg2 > tq_elapsed) ? (cur_tseg2 - tq_elapsed) : 5'd0;
    wire [4:0] early_delta = (early_error > sjw_eff) ? sjw_eff : early_error;

    reg [4:0] adjusted_tseg1;
    reg [4:0] adjusted_tseg2;
    reg [5:0] tseg1_extended;

    always @* begin
        tseg1_extended = {1'b0, cur_tseg1} + {1'b0, late_delta};
        adjusted_tseg1 = (tseg1_extended > {1'b0, MAX_TSEG1}) ? MAX_TSEG1 : tseg1_extended[4:0];
        adjusted_tseg2 = (cur_tseg2 > early_delta) ? (cur_tseg2 - early_delta) : 5'd1;
    end

    wire consume_edge = tq_tick && edge_available;

    always @(posedge can_clk) begin
        if (!can_rst_n_sync || config_mode) begin
            rx_sync_q    <= RECESSIVE;
            edge_pending <= 1'b0;
        end else begin
            rx_sync_q <= rx_sync;
            if (new_edge) begin
                // if an old pending edge got consumed this same cycle,
                // this new one takes its place rather than being dropped
                edge_pending <= (consume_edge && !edge_pending) ? 1'b0 : 1'b1;
            end else if (consume_edge) begin
                edge_pending <= 1'b0;
            end
        end
    end

    // Hard synchronization: only on a Recessive→Dominant edge while bus_idle,
    // or when in SEG_IDLE waiting for first edge. ISO 11898-1 §10.3.6.
    // Do NOT trigger on rx_sync==DOMINANT level — that causes repeated re-sync
    // while a long dominant is being received.
    wire hard_sync_trigger = (bus_idle && dominant_edge) ||
                             ((present_seg == SEG_IDLE) && (dominant_edge || edge_available));

    always @(posedge can_clk) begin
        if (!can_rst_n_sync || config_mode) begin
            present_seg         <= SEG_IDLE;
            tq_count             <= 5'd0;
            cur_tseg1            <= 5'd6;
            cur_tseg2            <= 5'd3;
            sync_done_this_bit   <= 1'b0;
            sample_point         <= 1'b0;
            sampled_bit          <= RECESSIVE;
            hard_sync_pulse      <= 1'b0;
            resync_pulse         <= 1'b0;
            bit_tick             <= 1'b0;
        end else begin
            sample_point    <= 1'b0;
            hard_sync_pulse <= 1'b0;
            resync_pulse    <= 1'b0;
            bit_tick        <= 1'b0;

            if (tq_tick) begin
                if (hard_sync_trigger) begin
                    present_seg        <= SEG_SYNC;
                    tq_count            <= 5'd0;
                    cur_tseg1           <= tseg1_eff;
                    cur_tseg2           <= tseg2_eff;
                    sync_done_this_bit  <= 1'b0;
                    hard_sync_pulse     <= 1'b1;
                end else begin
                    case (present_seg)
                        SEG_IDLE: begin
                            // IDLE state -> waiting for hard synchronization
                        end

                        SEG_SYNC: begin
                            present_seg        <= SEG_TSEG1;
                            tq_count            <= 5'd0;
                            sync_done_this_bit  <= 1'b0;
                        end

                        SEG_TSEG1: begin
                            if (edge_available && !sync_done_this_bit) begin
                                cur_tseg1          <= adjusted_tseg1;
                                sync_done_this_bit <= 1'b1;
                                resync_pulse       <= 1'b1;
                                if (tq_elapsed >= adjusted_tseg1) begin
                                    sample_point <= 1'b1;
                                    sampled_bit  <= rx_sync;
                                    present_seg  <= SEG_TSEG2;
                                    tq_count     <= 5'd0;
                                end else begin
                                    tq_count <= tq_elapsed;
                                end
                            end else if (tq_elapsed >= cur_tseg1) begin
                                sample_point <= 1'b1;
                                sampled_bit  <= rx_sync;
                                present_seg  <= SEG_TSEG2;
                                tq_count     <= 5'd0;
                            end else begin
                                tq_count <= tq_elapsed;
                            end
                        end

                        SEG_TSEG2: begin
                            if (edge_available && !sync_done_this_bit) begin
                                cur_tseg2          <= adjusted_tseg2;
                                sync_done_this_bit <= 1'b1;
                                resync_pulse       <= 1'b1;
                                if (tq_elapsed >= adjusted_tseg2) begin
                                    bit_tick    <= 1'b1;
                                    present_seg <= SEG_SYNC;
                                    tq_count    <= 5'd0;
                                    cur_tseg1   <= tseg1_eff;
                                    cur_tseg2   <= tseg2_eff;
                                end else begin
                                    tq_count <= tq_elapsed;
                                end
                            end else if (tq_elapsed >= cur_tseg2) begin
                                bit_tick    <= 1'b1;
                                present_seg <= SEG_SYNC;
                                tq_count    <= 5'd0;
                                cur_tseg1   <= tseg1_eff;
                                cur_tseg2   <= tseg2_eff;
                            end else begin
                                tq_count <= tq_elapsed;
                            end
                        end

                        default: begin
                            present_seg <= SEG_IDLE;
                            tq_count    <= 5'd0;
                        end
                    endcase
                end
            end
        end
    end

endmodule