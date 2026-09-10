`timescale 1ns / 1ps

module can_bsp (
    input  wire        can_clk,
    input  wire        can_rst_n_sync,

    // Timing Engine (BTL) Interface
    input  wire        sample_point,
    input  wire        sampled_bit,
    input  wire        bit_tick,
    output reg         tx_active,
    output reg         bus_idle,
    output wire        can_tx_bit,

    // Mode Controls
    input  wire        cen,            // CAN Enable (from SRR)
    input  wire        lback_mode,     // Loopback mode (from MSR)
    input  wire        sleep_mode,     // Sleep mode (from MSR)

    // TX FIFO Interface
    input  wire        tx_frame_avail,
    input  wire [28:0] tx_rd_id,
    input  wire        tx_rd_ide,
    input  wire        tx_rd_rtr,
    input  wire [3:0]  tx_rd_dlc,
    input  wire [63:0] tx_rd_data,
    output reg         tx_rd_en,

    // TX CRC Interface
    output reg         crc_clear,
    output reg         crc_update_en,
    output reg         crc_bit_in,
    input  wire [14:0] crc_value,

    // RX Path Interface
    input  wire        destuffed_bit_out,
    input  wire        destuffed_bit_valid,
    input  wire        stuff_bit_dropped,
    input  wire        stuff_error,
    output reg         destuff_en,
    output reg         destuff_reset,

    // Output to RX FIFO & Acceptance Filter
    output reg         rx_frame_valid,
    output reg  [31:0] rx_frame_idr,
    output reg  [31:0] rx_frame_dlcr,
    output reg  [31:0] rx_frame_dw1r,
    output reg  [31:0] rx_frame_dw2r,

    // Status & Error Flags (for Register File)
    output reg         tx_success_pulse,
    output reg         tx_error_pulse,
    output reg         tx_arblst_pulse,
    output reg         rx_ok_pulse,
    output reg         tx_busy,

    output reg  [7:0]  tec,
    output reg  [7:0]  rec,
    output wire [1:0]  estat,          // 00: Active, 01: Passive, 10: Bus-Off
    output wire        errwrn,         // TEC >= 96 || REC >= 96
    output wire        bus_off,

    output reg         err_acker,
    output reg         err_berr,
    output reg         err_ster,
    output reg         err_fmer,
    output reg         err_crcer
);

    localparam DOMINANT  = 1'b0;
    localparam RECESSIVE = 1'b1;

    // FSM States
    localparam [4:0]
        ST_IDLE        = 5'd0,
        ST_SOF         = 5'd1,
        ST_BASE_ID     = 5'd2,
        ST_RTR_SRR     = 5'd3,
        ST_IDE         = 5'd4,
        ST_EXT_ID      = 5'd5,
        ST_EXT_RTR     = 5'd6,
        ST_RESERVED    = 5'd7,
        ST_DLC         = 5'd8,
        ST_DATA        = 5'd9,
        ST_CRC_SEQ     = 5'd10,
        ST_CRC_DELIM   = 5'd11,
        ST_ACK_SLOT    = 5'd12,
        ST_ACK_DELIM   = 5'd13,
        ST_EOF         = 5'd14,
        ST_IFS         = 5'd15,
        ST_ERROR_FLAG  = 5'd16,
        ST_ERROR_DELIM = 5'd17;

    // RX FSM States
    localparam [4:0]
        RX_IDLE        = 5'd0,
        RX_SOF         = 5'd1,
        RX_BASE_ID     = 5'd2,
        RX_RTR_SRR     = 5'd3,
        RX_IDE         = 5'd4,
        RX_EXT_ID      = 5'd5,
        RX_EXT_RTR     = 5'd6,
        RX_RESERVED    = 5'd7,
        RX_DLC         = 5'd8,
        RX_DATA        = 5'd9,
        RX_CRC_SEQ     = 5'd10,
        RX_CRC_DELIM   = 5'd11,
        RX_ACK_SLOT    = 5'd12,
        RX_ACK_DELIM   = 5'd13,
        RX_EOF         = 5'd14;

    reg [4:0] state;
    reg [5:0] bit_cnt;

    // Latched TX frame registers
    reg [28:0] frame_id;
    reg        frame_ide;
    reg        frame_rtr;
    reg [3:0]  frame_dlc;
    reg [63:0] frame_data;

    wire [3:0] eff_dlc = (frame_dlc > 4'd8) ? 4'd8 : frame_dlc;
    wire [6:0] total_data_bits = {eff_dlc, 3'b000}; // eff_dlc * 8

    // TX Bit Stuffing Control
    reg       stuff_en;
    reg [2:0] stuff_count;
    reg       last_stuff_bit;
    reg       insert_stuff;

    // Raw TX bit selection
    reg raw_bit;
    reg in_arbitration;
    reg check_bit_error;
    reg check_ack;

    wire arbitration_lost_event = sample_point && tx_active && in_arbitration &&
                                  (can_tx_bit == RECESSIVE) &&
                                  (sampled_bit == DOMINANT);

    // RX Engine Registers
    reg [4:0]  rx_state;
    reg [5:0]  rx_bit_cnt;
    reg [10:0] rx_base_id;
    reg        rx_srr_rtr;
    reg        rx_ide_bit;
    reg [17:0] rx_ext_id;
    reg        rx_ext_rtr;
    reg [3:0]  rx_dlc_reg;
    reg [63:0] rx_data_reg;
    reg [14:0] rx_crc_received;
    reg [14:0] rx_crc_calc;
    reg        rx_ack_drive;
    reg        rx_has_error;

    wire [3:0] rx_eff_dlc = (rx_dlc_reg > 4'd8) ? 4'd8 : rx_dlc_reg;
    wire [6:0] rx_total_data_bits = {rx_eff_dlc, 3'b000};

    wire rx_crc_error;
    crc_check u_crc_check (
        .check_en       (sample_point && (rx_state == RX_CRC_DELIM)),
        .calculated_crc (rx_crc_calc),
        .received_crc   (rx_crc_received),
        .crc_error      (rx_crc_error)
    );

    // Calculate next RX CRC incrementally
    function [14:0] next_crc15(input b, input [14:0] current_crc);
        reg d;
        begin
            d = b ^ current_crc[14];
            next_crc15[0]  = d;
            next_crc15[1]  = current_crc[0];
            next_crc15[2]  = current_crc[1];
            next_crc15[3]  = current_crc[2] ^ d;
            next_crc15[4]  = current_crc[3] ^ d;
            next_crc15[5]  = current_crc[4];
            next_crc15[6]  = current_crc[5];
            next_crc15[7]  = current_crc[6] ^ d;
            next_crc15[8]  = current_crc[7] ^ d;
            next_crc15[9]  = current_crc[8];
            next_crc15[10] = current_crc[9] ^ d;
            next_crc15[11] = current_crc[10];
            next_crc15[12] = current_crc[11];
            next_crc15[13] = current_crc[12];
            next_crc15[14] = current_crc[13] ^ d;
        end
    endfunction

    // Error status definitions (ISO 11898-1)
    assign bus_off = (tec >= 8'd255); // or 8'hFF in 8-bit clamp
    assign estat   = (tec >= 8'd255) ? 2'b10 : // Bus-Off
                     (tec >= 8'd128 || rec >= 8'd128) ? 2'b01 : // Error Passive
                     2'b00; // Error Active
    assign errwrn  = (tec >= 8'd96 || rec >= 8'd96);

    // TX Bit Driven to Physical Bus (or ACK driven if receiving)
    wire tx_out_bit = (state != ST_IDLE) ? (insert_stuff ? ~last_stuff_bit : raw_bit) :
                      (rx_ack_drive)     ? DOMINANT : RECESSIVE;
    assign can_tx_bit = tx_out_bit;

    // Combinational multiplexer for TX raw_bit
    always @(*) begin
        raw_bit         = RECESSIVE;
        in_arbitration  = 1'b0;
        check_bit_error = 1'b0;
        check_ack       = 1'b0;

        case (state)
            ST_IDLE: begin
                raw_bit = RECESSIVE;
            end

            ST_SOF: begin
                raw_bit         = DOMINANT;
                check_bit_error = 1'b1;
            end

            ST_BASE_ID: begin
                raw_bit = frame_ide ? frame_id[18 + bit_cnt] : frame_id[bit_cnt];
                in_arbitration = 1'b1;
            end

            ST_RTR_SRR: begin
                raw_bit = frame_ide ? RECESSIVE : frame_rtr;
                in_arbitration = 1'b1;
            end

            ST_IDE: begin
                raw_bit = frame_ide ? RECESSIVE : DOMINANT;
                in_arbitration = 1'b1;
            end

            ST_EXT_ID: begin
                raw_bit        = frame_id[bit_cnt];
                in_arbitration = 1'b1;
            end

            ST_EXT_RTR: begin
                raw_bit        = frame_rtr;
                in_arbitration = 1'b1;
            end

            ST_RESERVED: begin
                raw_bit         = DOMINANT;
                check_bit_error = 1'b1;
            end

            ST_DLC: begin
                raw_bit         = frame_dlc[bit_cnt];
                check_bit_error = 1'b1;
            end

            ST_DATA: begin
                raw_bit         = frame_data[63 - bit_cnt];
                check_bit_error = 1'b1;
            end

            ST_CRC_SEQ: begin
                raw_bit         = crc_value[bit_cnt];
                check_bit_error = 1'b1;
            end

            ST_CRC_DELIM: begin
                raw_bit         = RECESSIVE;
                check_bit_error = 1'b1;
            end

            ST_ACK_SLOT: begin
                raw_bit   = RECESSIVE;
                check_ack = 1'b1;
            end

            ST_ACK_DELIM: begin
                raw_bit         = RECESSIVE;
                check_bit_error = 1'b1;
            end

            ST_EOF: begin
                raw_bit         = RECESSIVE;
                check_bit_error = 1'b1;
            end

            ST_IFS: begin
                raw_bit = RECESSIVE;
            end

            ST_ERROR_FLAG: begin
                raw_bit = DOMINANT;
            end

            ST_ERROR_DELIM: begin
                raw_bit = RECESSIVE;
            end

            default: begin
                raw_bit = RECESSIVE;
            end
        endcase
    end

    // --- Main Protocol Engine ---
    always @(posedge can_clk) begin
        if (!can_rst_n_sync || !cen) begin
            state            <= ST_IDLE;
            bit_cnt          <= 6'd0;
            tx_active        <= 1'b0;
            bus_idle         <= 1'b1;
            tx_busy          <= 1'b0;
            tx_rd_en         <= 1'b0;
            tx_success_pulse <= 1'b0;
            tx_error_pulse   <= 1'b0;
            tx_arblst_pulse  <= 1'b0;
            rx_ok_pulse      <= 1'b0;
            rx_frame_valid   <= 1'b0;

            crc_clear     <= 1'b0;
            crc_update_en <= 1'b0;
            crc_bit_in    <= 1'b0;

            stuff_en       <= 1'b0;
            stuff_count    <= 3'd0;
            last_stuff_bit <= RECESSIVE;
            insert_stuff   <= 1'b0;

            destuff_en    <= 1'b0;
            destuff_reset <= 1'b1;

            rx_state        <= RX_IDLE;
            rx_bit_cnt      <= 6'd0;
            rx_ack_drive    <= 1'b0;
            rx_has_error    <= 1'b0;
            rx_crc_calc     <= 15'd0;
            rx_crc_received <= 15'd0;

            tec <= 8'd0;
            rec <= 8'd0;

            err_acker <= 1'b0;
            err_berr  <= 1'b0;
            err_ster  <= 1'b0;
            err_fmer  <= 1'b0;
            err_crcer <= 1'b0;

            frame_id   <= 29'd0;
            frame_ide  <= 1'b0;
            frame_rtr  <= 1'b0;
            frame_dlc  <= 4'd0;
            frame_data <= 64'd0;
        end else begin
            tx_rd_en         <= 1'b0;
            tx_success_pulse <= 1'b0;
            tx_error_pulse   <= 1'b0;
            tx_arblst_pulse  <= 1'b0;
            rx_ok_pulse      <= 1'b0;
            rx_frame_valid   <= 1'b0;
            crc_clear        <= 1'b0;
            crc_update_en    <= 1'b0;
            destuff_reset    <= 1'b0;
            // -------------------------------------------------------------
            // A. TRANSMIT VERIFICATION AT sample_point
            // -------------------------------------------------------------
            if (sample_point && tx_active) begin
                if (in_arbitration) begin
                    if (can_tx_bit == RECESSIVE && sampled_bit == DOMINANT) begin
                        // Arbitration Lost
                        tx_arblst_pulse <= 1'b1;
                        tx_active       <= 1'b0;
                        tx_busy         <= 1'b0;
                        stuff_en        <= 1'b0;
                        insert_stuff    <= 1'b0;
                        state           <= ST_IDLE;
                        bus_idle        <= 1'b0;
                        rx_state        <= RX_IDLE;
                        rx_has_error    <= 1'b0;
                        rx_ack_drive    <= 1'b0;
                        destuff_reset   <= 1'b1;
                    end
                end else if (check_ack) begin
                    if (sampled_bit == RECESSIVE && !lback_mode) begin
                        // ACK Error
                        tx_error_pulse <= 1'b1;
                        err_acker      <= 1'b1;
                        stuff_en       <= 1'b0;
                        insert_stuff   <= 1'b0;
                        state          <= ST_ERROR_FLAG;
                        bit_cnt        <= 6'd0;
                        tec            <= (tec <= 8'd247) ? tec + 8'd8 : 8'd255;
                    end
                end else if (check_bit_error) begin
                    if (can_tx_bit != sampled_bit) begin
                        // Bit Error
                        tx_error_pulse <= 1'b1;
                        err_berr       <= 1'b1;
                        stuff_en       <= 1'b0;
                        insert_stuff   <= 1'b0;
                        state          <= ST_ERROR_FLAG;
                        bit_cnt        <= 6'd0;
                        tec            <= (tec <= 8'd247) ? tec + 8'd8 : 8'd255;
                    end
                end
            end

            // -------------------------------------------------------------
            // B. TRANSMIT FSM (Advanced on bit_tick or started from Idle)
            // -------------------------------------------------------------
            case (state)
                ST_IDLE: begin
                    bus_idle     <= (rx_state == RX_IDLE);
                    tx_active    <= 1'b0;
                    tx_busy      <= 1'b0;
                    stuff_en     <= 1'b0;
                    insert_stuff <= 1'b0;

                    if (tx_frame_avail && (bus_idle || lback_mode)) begin
                        frame_id   <= tx_rd_id;
                        frame_ide  <= tx_rd_ide;
                        frame_rtr  <= tx_rd_rtr;
                        frame_dlc  <= tx_rd_dlc;
                        frame_data <= tx_rd_data;

                        tx_active      <= 1'b1;
                        bus_idle       <= 1'b0;
                        tx_busy        <= 1'b1;
                        crc_clear      <= 1'b1;
                        stuff_en       <= 1'b1;
                        stuff_count    <= 3'd1;
                        last_stuff_bit <= DOMINANT;
                        insert_stuff   <= 1'b0;
                        state          <= ST_SOF;
                        bit_cnt        <= 6'd0;

                        crc_bit_in    <= DOMINANT;
                        crc_update_en <= 1'b1;
                    end
                end

                ST_SOF, ST_BASE_ID, ST_RTR_SRR, ST_IDE, ST_EXT_ID, ST_EXT_RTR, ST_RESERVED, ST_DLC, ST_DATA, ST_CRC_SEQ: begin
                    if (bit_tick) begin
                        if (insert_stuff) begin
                            insert_stuff <= 1'b0;
                            // The stuffed bit is the complement of the last
                            // transmitted data bit. The next data bit is
                            // selected by the normal FSM below.
                            stuff_count    <= 3'd1;
                            last_stuff_bit <= ~last_stuff_bit;
                        end else begin
                            case (state)
                                ST_SOF: begin
                                    state         <= ST_BASE_ID;
                                    bit_cnt       <= 6'd10;
                                    crc_bit_in    <= frame_ide ? frame_id[28] : frame_id[10];
                                    crc_update_en <= 1'b1;
                                    if ((frame_ide ? frame_id[28] : frame_id[10]) == last_stuff_bit)
                                        stuff_count <= stuff_count + 3'd1;
                                    else begin
                                        stuff_count    <= 3'd1;
                                        last_stuff_bit <= frame_ide ? frame_id[28] : frame_id[10];
                                    end
                                end

                                ST_BASE_ID: begin
                                    if (bit_cnt == 6'd0) begin
                                        state         <= ST_RTR_SRR;
                                        bit_cnt       <= 6'd0;
                                        crc_bit_in    <= frame_ide ? RECESSIVE : frame_rtr;
                                        crc_update_en <= 1'b1;
                                        if ((frame_ide ? RECESSIVE : frame_rtr) == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= frame_ide ? RECESSIVE : frame_rtr;
                                        end
                                    end else begin
                                        bit_cnt       <= bit_cnt - 6'd1;
                                        crc_bit_in    <= frame_ide ? frame_id[18 + (bit_cnt - 6'd1)] : frame_id[bit_cnt - 6'd1];
                                        crc_update_en <= 1'b1;
                                        if ((frame_ide ? frame_id[18 + (bit_cnt - 6'd1)] : frame_id[bit_cnt - 6'd1]) == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= frame_ide ? frame_id[18 + (bit_cnt - 6'd1)] : frame_id[bit_cnt - 6'd1];
                                        end
                                    end
                                end

                                ST_RTR_SRR: begin
                                    state         <= ST_IDE;
                                    bit_cnt       <= 6'd0;
                                    crc_bit_in    <= frame_ide ? RECESSIVE : DOMINANT;
                                    crc_update_en <= 1'b1;
                                    if ((frame_ide ? RECESSIVE : DOMINANT) == last_stuff_bit)
                                        stuff_count <= stuff_count + 3'd1;
                                    else begin
                                        stuff_count    <= 3'd1;
                                        last_stuff_bit <= frame_ide ? RECESSIVE : DOMINANT;
                                    end
                                end

                                ST_IDE: begin
                                    if (frame_ide) begin
                                        state         <= ST_EXT_ID;
                                        bit_cnt       <= 6'd17;
                                        crc_bit_in    <= frame_id[17];
                                        crc_update_en <= 1'b1;
                                        if (frame_id[17] == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= frame_id[17];
                                        end
                                    end else begin
                                        state         <= ST_RESERVED;
                                        bit_cnt       <= 6'd0;
                                        crc_bit_in    <= DOMINANT;
                                        crc_update_en <= 1'b1;
                                        if (DOMINANT == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= DOMINANT;
                                        end
                                    end
                                end

                                ST_EXT_ID: begin
                                    if (bit_cnt == 6'd0) begin
                                        state         <= ST_EXT_RTR;
                                        bit_cnt       <= 6'd0;
                                        crc_bit_in    <= frame_rtr;
                                        crc_update_en <= 1'b1;
                                        if (frame_rtr == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= frame_rtr;
                                        end
                                    end else begin
                                        bit_cnt       <= bit_cnt - 6'd1;
                                        crc_bit_in    <= frame_id[bit_cnt - 6'd1];
                                        crc_update_en <= 1'b1;
                                        if (frame_id[bit_cnt - 6'd1] == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= frame_id[bit_cnt - 6'd1];
                                        end
                                    end
                                end

                                ST_EXT_RTR: begin
                                    state         <= ST_RESERVED;
                                    bit_cnt       <= 6'd1;
                                    crc_bit_in    <= DOMINANT;
                                    crc_update_en <= 1'b1;
                                    if (DOMINANT == last_stuff_bit)
                                        stuff_count <= stuff_count + 3'd1;
                                    else begin
                                        stuff_count    <= 3'd1;
                                        last_stuff_bit <= DOMINANT;
                                    end
                                end

                                ST_RESERVED: begin
                                    if (bit_cnt == 6'd0) begin
                                        state         <= ST_DLC;
                                        bit_cnt       <= 6'd3;
                                        crc_bit_in    <= frame_dlc[3];
                                        crc_update_en <= 1'b1;
                                        if (frame_dlc[3] == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= frame_dlc[3];
                                        end
                                    end else begin
                                        bit_cnt       <= bit_cnt - 6'd1;
                                        crc_bit_in    <= DOMINANT;
                                        crc_update_en <= 1'b1;
                                        if (DOMINANT == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= DOMINANT;
                                        end
                                    end
                                end

                                ST_DLC: begin
                                    if (bit_cnt == 6'd0) begin
                                        if (!frame_rtr && (eff_dlc > 4'd0)) begin
                                            state         <= ST_DATA;
                                            bit_cnt       <= 6'd0;
                                            crc_bit_in    <= frame_data[63];
                                            crc_update_en <= 1'b1;
                                            if (frame_data[63] == last_stuff_bit)
                                                stuff_count <= stuff_count + 3'd1;
                                            else begin
                                                stuff_count    <= 3'd1;
                                                last_stuff_bit <= frame_data[63];
                                            end
                                        end else begin
                                            state   <= ST_CRC_SEQ;
                                            bit_cnt <= 6'd14;
                                            if (crc_value[14] == last_stuff_bit)
                                                stuff_count <= stuff_count + 3'd1;
                                            else begin
                                                stuff_count    <= 3'd1;
                                                last_stuff_bit <= crc_value[14];
                                            end
                                        end
                                    end else begin
                                        bit_cnt       <= bit_cnt - 6'd1;
                                        crc_bit_in    <= frame_dlc[bit_cnt - 6'd1];
                                        crc_update_en <= 1'b1;
                                        if (frame_dlc[bit_cnt - 6'd1] == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= frame_dlc[bit_cnt - 6'd1];
                                        end
                                    end
                                end

                                ST_DATA: begin
                                    if (bit_cnt + 6'd1 >= total_data_bits[5:0]) begin
                                        state   <= ST_CRC_SEQ;
                                        bit_cnt <= 6'd14;
                                        if (crc_value[14] == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= crc_value[14];
                                        end
                                    end else begin
                                        bit_cnt       <= bit_cnt + 6'd1;
                                        crc_bit_in    <= frame_data[63 - (bit_cnt + 6'd1)];
                                        crc_update_en <= 1'b1;
                                        if (frame_data[63 - (bit_cnt + 6'd1)] == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= frame_data[63 - (bit_cnt + 6'd1)];
                                        end
                                    end
                                end

                                ST_CRC_SEQ: begin
                                    if (bit_cnt == 6'd0) begin
                                        state        <= ST_CRC_DELIM;
                                        bit_cnt      <= 6'd0;
                                        stuff_en     <= 1'b0;
                                        insert_stuff <= 1'b0;
                                    end else begin
                                        bit_cnt <= bit_cnt - 6'd1;
                                        if (crc_value[bit_cnt - 6'd1] == last_stuff_bit)
                                            stuff_count <= stuff_count + 3'd1;
                                        else begin
                                            stuff_count    <= 3'd1;
                                            last_stuff_bit <= crc_value[bit_cnt - 6'd1];
                                        end
                                    end
                                end
                                default: ;
                            endcase

                            if (stuff_en && (stuff_count == 3'd5) &&
                                (raw_bit == last_stuff_bit))
                                insert_stuff <= 1'b1;

                        end
                    end
                end

                ST_CRC_DELIM: begin
                    stuff_en     <= 1'b0;
                    insert_stuff <= 1'b0;
                    if (bit_tick) begin
                        state   <= ST_ACK_SLOT;
                        bit_cnt <= 6'd0;
                    end
                end

                ST_ACK_SLOT: begin
                    stuff_en     <= 1'b0;
                    insert_stuff <= 1'b0;
                    if (bit_tick) begin
                        state   <= ST_ACK_DELIM;
                        bit_cnt <= 6'd0;
                    end
                end

                ST_ACK_DELIM: begin
                    stuff_en     <= 1'b0;
                    insert_stuff <= 1'b0;
                    if (bit_tick) begin
                        state   <= ST_EOF;
                        bit_cnt <= 6'd6;
                    end
                end

                ST_EOF: begin
                    stuff_en     <= 1'b0;
                    insert_stuff <= 1'b0;
                    if (bit_tick) begin
                        if (bit_cnt == 6'd0) begin
                            state   <= ST_IFS;
                            bit_cnt <= 6'd2;
                        end else begin
                            bit_cnt <= bit_cnt - 6'd1;
                        end
                    end
                end

                ST_IFS: begin
                    stuff_en     <= 1'b0;
                    insert_stuff <= 1'b0;
                    if (bit_tick) begin
                        if (bit_cnt == 6'd0) begin
                            tx_success_pulse <= 1'b1;
                            tx_rd_en         <= 1'b1;
                            tx_active        <= 1'b0;
                            bus_idle         <= 1'b1;
                            tx_busy          <= 1'b0;
                            state            <= ST_IDLE;
                            bit_cnt          <= 6'd0;
                            if (tec > 8'd0) tec <= tec - 8'd1;
                        end else begin
                            bit_cnt <= bit_cnt - 6'd1;
                        end
                    end
                end

                ST_ERROR_FLAG: begin
                    stuff_en     <= 1'b0;
                    insert_stuff <= 1'b0;
                    if (bit_tick) begin
                        if (bit_cnt == 6'd5) begin
                            state   <= ST_ERROR_DELIM;
                            bit_cnt <= 6'd7;
                        end else begin
                            bit_cnt <= bit_cnt + 6'd1;
                        end
                    end
                end

                ST_ERROR_DELIM: begin
                    stuff_en     <= 1'b0;
                    insert_stuff <= 1'b0;
                    if (bit_tick) begin
                        if (bit_cnt == 6'd0) begin
                            state     <= ST_IFS;
                            bit_cnt   <= 6'd2;
                            tx_active <= 1'b0;
                        end else begin
                            bit_cnt <= bit_cnt - 6'd1;
                        end
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase

            // -------------------------------------------------------------
            // C. RECEIVE FSM (Bit-by-bit parsing on destuffed valid bits)
            // -------------------------------------------------------------
            if (stuff_error) begin
                err_ster     <= 1'b1;
                rx_has_error <= 1'b1;
                rec          <= (rec <= 8'd247) ? rec + 8'd8 : 8'd255;
            end

            case (rx_state)
                RX_IDLE: begin
                    destuff_en   <= 1'b0;
                    rx_ack_drive <= 1'b0;
                    rx_has_error <= 1'b0;

                    // Detect SOF from bus (dominant 0)
                    if (sample_point && sampled_bit == DOMINANT) begin
                        rx_state      <= RX_BASE_ID;
                        rx_bit_cnt    <= 6'd10;
                        destuff_en    <= 1'b1;
                        destuff_reset <= 1'b1;
                        rx_crc_calc   <= next_crc15(DOMINANT, 15'd0);
                    end else if (lback_mode && state == ST_SOF && sample_point) begin
                        // In loopback mode, receive own SOF
                        rx_state      <= RX_BASE_ID;
                        rx_bit_cnt    <= 6'd10;
                        destuff_en    <= 1'b1;
                        destuff_reset <= 1'b1;
                        rx_crc_calc   <= next_crc15(DOMINANT, 15'd0);
                    end
                end

                RX_BASE_ID: begin
                    destuff_en <= 1'b1;
                    if (destuffed_bit_valid && !destuff_reset) begin
                        rx_base_id[rx_bit_cnt] <= destuffed_bit_out;
                        rx_crc_calc            <= next_crc15(destuffed_bit_out, rx_crc_calc);

                        if (rx_bit_cnt == 6'd0) begin
                            rx_state   <= RX_RTR_SRR;
                            rx_bit_cnt <= 6'd0;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt - 6'd1;
                        end
                    end
                end

                RX_RTR_SRR: begin
                    destuff_en <= 1'b1;
                    if (destuffed_bit_valid && !destuff_reset) begin
                        rx_srr_rtr  <= destuffed_bit_out;
                        rx_crc_calc <= next_crc15(destuffed_bit_out, rx_crc_calc);
                        rx_state    <= RX_IDE;
                        rx_bit_cnt  <= 6'd0;
                    end
                end

                RX_IDE: begin
                    destuff_en <= 1'b1;
                    if (destuffed_bit_valid && !destuff_reset) begin
                        rx_ide_bit  <= destuffed_bit_out;
                        rx_crc_calc <= next_crc15(destuffed_bit_out, rx_crc_calc);

                        if (destuffed_bit_out == 1'b1) begin
                            // Extended frame -> receive 18 bits of Extended ID
                            rx_state   <= RX_EXT_ID;
                            rx_bit_cnt <= 6'd17;
                        end else begin
                            // Standard frame -> 1 reserved bit (r0)
                            rx_state   <= RX_RESERVED;
                            rx_bit_cnt <= 6'd0;
                        end
                    end
                end

                RX_EXT_ID: begin
                    destuff_en <= 1'b1;
                    if (destuffed_bit_valid && !destuff_reset) begin
                        rx_ext_id[rx_bit_cnt] <= destuffed_bit_out;
                        rx_crc_calc           <= next_crc15(destuffed_bit_out, rx_crc_calc);

                        if (rx_bit_cnt == 6'd0) begin
                            rx_state   <= RX_EXT_RTR;
                            rx_bit_cnt <= 6'd0;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt - 6'd1;
                        end
                    end
                end

                RX_EXT_RTR: begin
                    destuff_en <= 1'b1;
                    if (destuffed_bit_valid && !destuff_reset) begin
                        rx_ext_rtr  <= destuffed_bit_out;
                        rx_crc_calc <= next_crc15(destuffed_bit_out, rx_crc_calc);
                        rx_state    <= RX_RESERVED;
                        rx_bit_cnt  <= 6'd1; // 2 reserved bits (r1, r0)
                    end
                end

                RX_RESERVED: begin
                    destuff_en <= 1'b1;
                    if (destuffed_bit_valid && !destuff_reset) begin
                        rx_crc_calc <= next_crc15(destuffed_bit_out, rx_crc_calc);
                        if (rx_bit_cnt == 6'd0) begin
                            rx_state   <= RX_DLC;
                            rx_bit_cnt <= 6'd3;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt - 6'd1;
                        end
                    end
                end

                RX_DLC: begin
                    destuff_en <= 1'b1;
                    if (destuffed_bit_valid && !destuff_reset) begin
                        rx_dlc_reg[rx_bit_cnt] <= destuffed_bit_out;
                        rx_crc_calc            <= next_crc15(destuffed_bit_out, rx_crc_calc);

                        if (rx_bit_cnt == 6'd0) begin
                            // Check if frame has data
                            if (!(rx_ide_bit ? rx_ext_rtr : rx_srr_rtr) &&
                                (({rx_dlc_reg[3:1], destuffed_bit_out}) > 4'd0)) begin
                                rx_state    <= RX_DATA;
                                rx_bit_cnt  <= 6'd0;
                                rx_data_reg <= 64'd0;
                            end else begin
                                rx_state   <= RX_CRC_SEQ;
                                rx_bit_cnt <= 6'd14;
                            end
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt - 6'd1;
                        end
                    end
                end

                RX_DATA: begin
                    destuff_en <= 1'b1;
                    if (destuffed_bit_valid && !destuff_reset) begin
                        rx_data_reg[63 - rx_bit_cnt] <= destuffed_bit_out;
                        rx_crc_calc                  <= next_crc15(destuffed_bit_out, rx_crc_calc);

                        if (rx_bit_cnt + 6'd1 >= rx_total_data_bits[5:0]) begin
                            rx_state   <= RX_CRC_SEQ;
                            rx_bit_cnt <= 6'd14;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt + 6'd1;
                        end
                    end
                end

                RX_CRC_SEQ: begin
                    destuff_en <= 1'b1;
                    if (destuffed_bit_valid) begin
                        rx_crc_received[rx_bit_cnt] <= destuffed_bit_out;

                        if (rx_bit_cnt == 6'd0) begin
                            rx_state   <= RX_CRC_DELIM;
                            destuff_en <= 1'b0; // Disable de-stuffing
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt - 6'd1;
                        end
                    end
                end

                RX_CRC_DELIM: begin
                    destuff_en <= 1'b0;
                    if (sample_point) begin
                        if (sampled_bit != RECESSIVE)
                            err_fmer <= 1'b1;
                        if (rx_crc_error)
                            err_crcer    <= 1'b1;

                        if ((sampled_bit == RECESSIVE) && !rx_crc_error)
                            rx_ack_drive <= 1'b1;
                        else
                            rx_has_error <= 1'b1;
                        rx_state <= RX_ACK_SLOT;
                    end
                end

                RX_ACK_SLOT: begin
                    destuff_en <= 1'b0;
                    if (sample_point) begin
                        rx_ack_drive <= 1'b0;
                        rx_state     <= RX_ACK_DELIM;
                    end
                end

                RX_ACK_DELIM: begin
                    destuff_en   <= 1'b0;
                    rx_ack_drive <= 1'b0;
                    if (sample_point) begin
                        if (sampled_bit != RECESSIVE) begin
                            err_fmer     <= 1'b1;
                            rx_has_error <= 1'b1;
                        end
                        rx_state   <= RX_EOF;
                        rx_bit_cnt <= 6'd6;
                    end
                end

                RX_EOF: begin
                    destuff_en <= 1'b0;
                    if (sample_point && sampled_bit != RECESSIVE) begin
                        err_fmer     <= 1'b1;
                        rx_has_error <= 1'b1;
                    end

                    if (bit_tick) begin
                        if (rx_bit_cnt == 6'd0) begin
                            // End of valid frame reception!
                            if (!rx_has_error) begin
                                rx_frame_valid <= 1'b1;
                                rx_ok_pulse    <= 1'b1;

                                // Pack IDR according to Xilinx DS791 specification
                                if (rx_ide_bit) begin
                                    // Extended: {ID[28:18], SRR(1), IDE(1), ID[17:0], RTR}
                                    rx_frame_idr <= {rx_base_id, 1'b1, 1'b1, rx_ext_id, rx_ext_rtr};
                                end else begin
                                    // Standard: {ID[28:18], RTR, IDE(0), 18'd0, 1'b0}
                                    rx_frame_idr <= {rx_base_id, rx_srr_rtr, 1'b0, 19'd0};
                                end

                                // Pack DLCR, DW1R, DW2R
                                rx_frame_dlcr <= {rx_dlc_reg, 28'd0};
                                rx_frame_dw1r <= rx_data_reg[63:32];
                                rx_frame_dw2r <= rx_data_reg[31:0];

                                if (rec > 8'd0) rec <= rec - 8'd1;
                            end else begin
                                rec <= (rec <= 8'd247) ? rec + 8'd8 : 8'd255;
                            end

                            rx_state <= RX_IDLE;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt - 6'd1;
                        end
                    end
                end

                default: begin
                    rx_state <= RX_IDLE;
                end
            endcase

            // Keep error indications asserted while either protocol engine is
            // handling the error, then clear them at the next fully idle point.
            if ((state == ST_IDLE) && (rx_state == RX_IDLE) && !tx_frame_avail) begin
                err_acker <= 1'b0;
                err_berr  <= 1'b0;
                err_ster  <= 1'b0;
                err_fmer  <= 1'b0;
                err_crcer <= 1'b0;
            end

            // Arbitration loss aborts any receive parse of the competing frame.
            if (arbitration_lost_event) begin
                rx_state     <= RX_IDLE;
                rx_has_error <= 1'b0;
                rx_ack_drive <= 1'b0;
                destuff_reset <= 1'b1;
            end
        end
    end

endmodule
