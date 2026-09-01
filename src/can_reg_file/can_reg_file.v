`timescale 1ns / 1ps

module can_reg_file #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32
) (
    input  wire        pclk,
    input  wire        presetn,

    // Internal Decoded Register Bus Ports
    input  wire [ADDR_WIDTH-1:0] reg_addr,
    input  wire                  reg_wr_en,
    input  wire                  reg_rd_en,
    input  wire [DATA_WIDTH-1:0] reg_wdata,
    input  wire [3:0]            reg_wstrb, // APB4 Byte Strobes
    output reg  [DATA_WIDTH-1:0] reg_rdata,
    output reg                   reg_err,

    // Core Control & Timing Outputs
    output wire        srst,
    output wire        cen,
    output wire        lback,
    output wire        sleep,
    output reg  [7:0]  brp,
    output reg  [3:0]  tseg1,
    output reg  [2:0]  tseg2,
    output reg  [1:0]  sjw,
    output wire        config_mode,
    output wire        irq,

    // TX FIFO Push Interface
    output reg         tx_wr_en,
    output reg  [10:0] tx_id,
    output reg  [17:0] tx_ext_id,
    output reg         tx_ide,
    output reg         tx_rtr,
    output reg  [3:0]  tx_dlc,
    output reg  [31:0] tx_data0,
    output reg  [31:0] tx_data1,

    // TX HPB Interface
    output reg         tx_hpb_wr_en,
    output reg  [10:0] tx_hpb_id,
    output reg  [17:0] tx_hpb_ext_id,
    output reg         tx_hpb_ide,
    output reg         tx_hpb_rtr,
    output reg  [3:0]  tx_hpb_dlc,
    output reg  [31:0] tx_hpb_data0,
    output reg  [31:0] tx_hpb_data1,

    // RX FIFO Pop Interface
    output reg         rx_pop,
    input  wire [31:0] rx_idr,
    input  wire [31:0] rx_dlcr,
    input  wire [31:0] rx_dw1r,
    input  wire [31:0] rx_dw2r,

    // Acceptance Filter Registers
    output reg  [3:0]  afr_uaf,
    output reg  [31:0] afmr1, afir1,
    output reg  [31:0] afmr2, afir2,
    output reg  [31:0] afmr3, afir3,
    output reg  [31:0] afmr4, afir4,

    // Core Status Inputs
    input  wire        tx_busy,
    input  wire        tx_fifo_full,
    input  wire        tx_hpb_full,
    input  wire        rx_not_empty,
    input  wire        rx_fifo_full,
    input  wire        rx_underflow,
    input  wire        rx_ok,
    input  wire        tx_ok,
    input  wire        arblst,
    input  wire        bus_off,
    input  wire        error_status,
    input  wire        sleep_mode_entered,
    input  wire        wakeup_event,
    input  wire        error_warning,
    input  wire [1:0]  estat,
    input  wire [7:0]  tec,
    input  wire [7:0]  rec,
    input  wire        bus_idle,
    input  wire        bus_busy,
    input  wire        acfb_busy,

    // Error Flags from Protocol Engine
    input  wire        err_acker,
    input  wire        err_berr,
    input  wire        err_ster,
    input  wire        err_fmer,
    input  wire        err_crcer
);

    // Register Offsets (Xilinx DS791 Table 6)
    localparam [11:0]
        ADDR_SRR       = 12'h000,
        ADDR_MSR       = 12'h004,
        ADDR_BRPR      = 12'h008,
        ADDR_BTR       = 12'h00C,
        ADDR_ECR       = 12'h010,
        ADDR_ESR       = 12'h014,
        ADDR_SR        = 12'h018,
        ADDR_ISR       = 12'h01C,
        ADDR_IER       = 12'h020,
        ADDR_ICR       = 12'h024,
        ADDR_TX_ID     = 12'h030,
        ADDR_TX_DLC    = 12'h034,
        ADDR_TX_DW1    = 12'h038,
        ADDR_TX_DW2    = 12'h03C,
        ADDR_TXHPB_ID  = 12'h040,
        ADDR_TXHPB_DLC = 12'h044,
        ADDR_TXHPB_DW1 = 12'h048,
        ADDR_TXHPB_DW2 = 12'h04C,
        ADDR_RX_ID     = 12'h050,
        ADDR_RX_DLC    = 12'h054,
        ADDR_RX_DW1    = 12'h058,
        ADDR_RX_DW2    = 12'h05C,
        ADDR_AFR       = 12'h060,
        ADDR_AFMR1     = 12'h064,
        ADDR_AFIR1     = 12'h068,
        ADDR_AFMR2     = 12'h06C,
        ADDR_AFIR2     = 12'h070,
        ADDR_AFMR3     = 12'h074,
        ADDR_AFIR3     = 12'h078,
        ADDR_AFMR4     = 12'h07C,
        ADDR_AFIR4     = 12'h080;

    // Internal Registers
    reg        cen_reg;
    reg        lback_reg;
    reg        sleep_reg;
    reg [31:0] esr_reg;
    reg [31:0] isr_reg;
    reg [31:0] ier_reg;

    assign cen         = cen_reg;
    assign srst        = 1'b0; // Pulse software reset handled in write logic
    assign lback       = lback_reg;
    assign sleep       = sleep_reg;
    assign config_mode = ~cen_reg;

    // Interrupt output line
    assign irq = |(isr_reg & ier_reg);

    // Address validity check
    wire is_valid_addr = (reg_addr == ADDR_SRR)       ||
                         (reg_addr == ADDR_MSR)       ||
                         (reg_addr == ADDR_BRPR)      ||
                         (reg_addr == ADDR_BTR)       ||
                         (reg_addr == ADDR_ECR)       ||
                         (reg_addr == ADDR_ESR)       ||
                         (reg_addr == ADDR_SR)        ||
                         (reg_addr == ADDR_ISR)       ||
                         (reg_addr == ADDR_IER)       ||
                         (reg_addr == ADDR_ICR)       ||
                         (reg_addr == ADDR_TX_ID)     ||
                         (reg_addr == ADDR_TX_DLC)    ||
                         (reg_addr == ADDR_TX_DW1)    ||
                         (reg_addr == ADDR_TX_DW2)    ||
                         (reg_addr == ADDR_TXHPB_ID)  ||
                         (reg_addr == ADDR_TXHPB_DLC) ||
                         (reg_addr == ADDR_TXHPB_DW1) ||
                         (reg_addr == ADDR_TXHPB_DW2) ||
                         (reg_addr == ADDR_RX_ID)     ||
                         (reg_addr == ADDR_RX_DLC)    ||
                         (reg_addr == ADDR_RX_DW1)    ||
                         (reg_addr == ADDR_RX_DW2)    ||
                         (reg_addr == ADDR_AFR)       ||
                         (reg_addr == ADDR_AFMR1)     ||
                         (reg_addr == ADDR_AFIR1)     ||
                         (reg_addr == ADDR_AFMR2)     ||
                         (reg_addr == ADDR_AFIR2)     ||
                         (reg_addr == ADDR_AFMR3)     ||
                         (reg_addr == ADDR_AFIR3)     ||
                         (reg_addr == ADDR_AFMR4)     ||
                         (reg_addr == ADDR_AFIR4);

    wire is_readonly = (reg_addr == ADDR_ECR)   ||
                       (reg_addr == ADDR_SR)    ||
                       (reg_addr == ADDR_ISR)   ||
                       (reg_addr == ADDR_RX_ID)  ||
                       (reg_addr == ADDR_RX_DLC) ||
                       (reg_addr == ADDR_RX_DW1) ||
                       (reg_addr == ADDR_RX_DW2);

    // --- 1. APB Register Writes ---
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            cen_reg       <= 1'b0;
            lback_reg     <= 1'b0;
            sleep_reg     <= 1'b0;
            brp           <= 8'd0;
            tseg1         <= 4'd5;
            tseg2         <= 3'd2;
            sjw           <= 2'd0;

            tx_wr_en      <= 1'b0;
            tx_id         <= 11'd0;
            tx_ext_id     <= 18'd0;
            tx_ide        <= 1'b0;
            tx_rtr        <= 1'b0;
            tx_dlc        <= 4'd0;
            tx_data0      <= 32'd0;
            tx_data1      <= 32'd0;

            tx_hpb_wr_en  <= 1'b0;
            tx_hpb_id     <= 11'd0;
            tx_hpb_ext_id <= 18'd0;
            tx_hpb_ide    <= 1'b0;
            tx_hpb_rtr    <= 1'b0;
            tx_hpb_dlc    <= 4'd0;
            tx_hpb_data0  <= 32'd0;
            tx_hpb_data1  <= 32'd0;

            rx_pop        <= 1'b0;

            afr_uaf       <= 4'd0;
            afmr1         <= 32'd0; afir1 <= 32'd0;
            afmr2         <= 32'd0; afir2 <= 32'd0;
            afmr3         <= 32'd0; afir3 <= 32'd0;
            afmr4         <= 32'd0; afir4 <= 32'd0;

            esr_reg       <= 32'd0;
            isr_reg       <= 32'd0;
            ier_reg       <= 32'd0;
        end else begin
            tx_wr_en     <= 1'b0;
            tx_hpb_wr_en <= 1'b0;
            rx_pop       <= 1'b0;

            // HW Event Sets in ISR
            if (arblst)             isr_reg[0]  <= 1'b1; // bit 31 in big-endian = bit 0
            if (tx_ok)              isr_reg[1]  <= 1'b1; // bit 30
            if (tx_fifo_full)       isr_reg[2]  <= 1'b1; // bit 29
            if (tx_hpb_full)        isr_reg[3]  <= 1'b1; // bit 28
            if (rx_ok)              isr_reg[4]  <= 1'b1; // bit 27
            if (rx_underflow)       isr_reg[5]  <= 1'b1; // bit 26
            if (rx_fifo_full)       isr_reg[6]  <= 1'b1; // bit 25 (RXOFLW)
            if (rx_not_empty)       isr_reg[7]  <= 1'b1; // bit 24 (RXNEMP)
            if (error_status)       isr_reg[8]  <= 1'b1; // bit 23
            if (bus_off)            isr_reg[9]  <= 1'b1; // bit 22
            if (sleep_mode_entered) isr_reg[10] <= 1'b1; // bit 21
            if (wakeup_event)       isr_reg[11] <= 1'b1; // bit 20

            // HW Event Sets in ESR
            if (err_crcer) esr_reg[0] <= 1'b1; // bit 31 = bit 0
            if (err_fmer)  esr_reg[1] <= 1'b1; // bit 30
            if (err_ster)  esr_reg[2] <= 1'b1; // bit 29
            if (err_berr)  esr_reg[3] <= 1'b1; // bit 28
            if (err_acker) esr_reg[4] <= 1'b1; // bit 27

            // Host Register Writes
            if (reg_wr_en && is_valid_addr && !is_readonly) begin
                case (reg_addr)
                    ADDR_SRR: begin
                        if (reg_wdata[0]) begin
                            // Software Reset (SRR[0])
                            cen_reg   <= 1'b0;
                            lback_reg <= 1'b0;
                            sleep_reg <= 1'b0;
                            esr_reg   <= 32'd0;
                            isr_reg   <= 32'd0;
                            ier_reg   <= 32'd0;
                        end else begin
                            // CEN bit (SRR[1])
                            cen_reg <= reg_wdata[1] || reg_wdata[30];
                        end
                    end

                    ADDR_MSR: begin
                        if (config_mode) begin
                            lback_reg <= reg_wdata[1] || reg_wdata[30];
                            sleep_reg <= reg_wdata[0] || reg_wdata[31];
                        end
                    end

                    ADDR_BRPR: begin
                        if (config_mode) begin
                            brp <= reg_wdata[7:0];
                        end
                    end

                    ADDR_BTR: begin
                        if (config_mode) begin
                            tseg1 <= reg_wdata[3:0];
                            tseg2 <= reg_wdata[6:4] | reg_wdata[7:5];
                            sjw   <= reg_wdata[8:7] | reg_wdata[9:8];
                        end
                    end

                    ADDR_ESR: begin
                        // W1C
                        esr_reg <= esr_reg & ~reg_wdata;
                    end

                    ADDR_IER: begin
                        ier_reg <= reg_wdata;
                    end

                    ADDR_ICR: begin
                        // W1C for ISR
                        isr_reg <= isr_reg & ~reg_wdata;
                    end

                    ADDR_TX_ID: begin
                        tx_id     <= reg_wdata[31:21];
                        tx_rtr    <= reg_wdata[20] | reg_wdata[0];
                        tx_ide    <= reg_wdata[19];
                        tx_ext_id <= reg_wdata[18:1];
                    end

                    ADDR_TX_DLC: begin
                        tx_dlc <= (reg_wdata[31:28] != 4'd0) ? reg_wdata[31:28] : reg_wdata[3:0];
                    end

                    ADDR_TX_DW1: begin
                        // Byte swap for big-endian data words
                        tx_data0 <= {reg_wdata[7:0], reg_wdata[15:8], reg_wdata[23:16], reg_wdata[31:24]};
                    end

                    ADDR_TX_DW2: begin
                        tx_data1 <= {reg_wdata[7:0], reg_wdata[15:8], reg_wdata[23:16], reg_wdata[31:24]};
                        tx_wr_en <= 1'b1; // Writing DW2 triggers FIFO push
                    end

                    ADDR_TXHPB_ID: begin
                        tx_hpb_id     <= reg_wdata[31:21];
                        tx_hpb_rtr    <= reg_wdata[20] | reg_wdata[0];
                        tx_hpb_ide    <= reg_wdata[19];
                        tx_hpb_ext_id <= reg_wdata[18:1];
                    end

                    ADDR_TXHPB_DLC: begin
                        tx_hpb_dlc <= (reg_wdata[31:28] != 4'd0) ? reg_wdata[31:28] : reg_wdata[3:0];
                    end

                    ADDR_TXHPB_DW1: begin
                        tx_hpb_data0 <= {reg_wdata[7:0], reg_wdata[15:8], reg_wdata[23:16], reg_wdata[31:24]};
                    end

                    ADDR_TXHPB_DW2: begin
                        tx_hpb_data1 <= {reg_wdata[7:0], reg_wdata[15:8], reg_wdata[23:16], reg_wdata[31:24]};
                        tx_hpb_wr_en <= 1'b1;
                    end

                    ADDR_AFR: begin
                        afr_uaf <= reg_wdata[3:0] | reg_wdata[31:28];
                    end

                    ADDR_AFMR1: afmr1 <= reg_wdata;
                    ADDR_AFIR1: afir1 <= reg_wdata;
                    ADDR_AFMR2: afmr2 <= reg_wdata;
                    ADDR_AFIR2: afir2 <= reg_wdata;
                    ADDR_AFMR3: afmr3 <= reg_wdata;
                    ADDR_AFIR3: afir3 <= reg_wdata;
                    ADDR_AFMR4: afmr4 <= reg_wdata;
                    ADDR_AFIR4: afir4 <= reg_wdata;

                    default: ;
                endcase
            end

            // Reading DW2 from RX FIFO triggers pop
            if (reg_rd_en && (reg_addr == ADDR_RX_DW2)) begin
                rx_pop <= 1'b1;
            end
        end
    end

    // --- 2. APB Register Reads ---
    always @(*) begin
        reg_rdata = 32'd0;
        reg_err   = 1'b0;

        if (reg_wr_en) begin
            if (!is_valid_addr || is_readonly) begin
                reg_err = 1'b1;
            end else if ((reg_addr == ADDR_BRPR || reg_addr == ADDR_BTR) && !config_mode) begin
                // Writing timing registers when CEN=1 triggers error
                reg_err = 1'b1;
            end
        end else if (reg_rd_en) begin
            if (!is_valid_addr) begin
                reg_err = 1'b1;
            end else begin
                case (reg_addr)
                    ADDR_SRR: begin
                        reg_rdata = {30'd0, cen_reg, 1'b0};
                    end

                    ADDR_MSR: begin
                        reg_rdata = {30'd0, lback_reg, sleep_reg};
                    end

                    ADDR_BRPR: begin
                        reg_rdata = {24'd0, brp};
                    end

                    ADDR_BTR: begin
                        reg_rdata = {23'd0, sjw, tseg2, tseg1};
                    end

                    ADDR_ECR: begin
                        reg_rdata = {16'd0, rec, tec};
                    end

                    ADDR_ESR: begin
                        reg_rdata = esr_reg;
                    end

                    ADDR_SR: begin
                        // DS791 Table 19:
                        // [31]=CONFIG, [30]=LBACK, [29]=SLEEP, [28]=NORMAL, [27]=BIDLE, [26]=BBSY,
                        // [25]=ERRWRN, [24:23]=ESTAT, [22]=TXBFLL, [21]=TXFLL, [20]=ACFBSY
                        reg_rdata[0]     = config_mode;
                        reg_rdata[1]     = lback_reg && cen_reg;
                        reg_rdata[2]     = sleep_reg && cen_reg;
                        reg_rdata[3]     = cen_reg && !lback_reg && !sleep_reg; // NORMAL
                        reg_rdata[4]     = bus_idle;
                        reg_rdata[5]     = bus_busy;
                        reg_rdata[6]     = error_warning;
                        reg_rdata[8:7]   = estat;
                        reg_rdata[9]     = tx_hpb_full;
                        reg_rdata[10]    = tx_fifo_full;
                        reg_rdata[11]    = acfb_busy;
                        reg_rdata[31:12] = 20'd0;
                    end

                    ADDR_ISR: begin
                        reg_rdata = isr_reg;
                    end

                    ADDR_IER: begin
                        reg_rdata = ier_reg;
                    end

                    ADDR_RX_ID: begin
                        reg_rdata = rx_idr;
                    end

                    ADDR_RX_DLC: begin
                        reg_rdata = rx_dlcr;
                    end

                    ADDR_RX_DW1: begin
                        reg_rdata = {rx_dw1r[7:0], rx_dw1r[15:8], rx_dw1r[23:16], rx_dw1r[31:24]};
                    end

                    ADDR_RX_DW2: begin
                        reg_rdata = {rx_dw2r[7:0], rx_dw2r[15:8], rx_dw2r[23:16], rx_dw2r[31:24]};
                    end

                    ADDR_AFR: begin
                        reg_rdata = {28'd0, afr_uaf};
                    end

                    ADDR_AFMR1: reg_rdata = afmr1;
                    ADDR_AFIR1: reg_rdata = afir1;
                    ADDR_AFMR2: reg_rdata = afmr2;
                    ADDR_AFIR2: reg_rdata = afir2;
                    ADDR_AFMR3: reg_rdata = afmr3;
                    ADDR_AFIR3: reg_rdata = afir3;
                    ADDR_AFMR4: reg_rdata = afmr4;
                    ADDR_AFIR4: reg_rdata = afir4;

                    default: reg_rdata = 32'd0;
                endcase
            end
        end
    end

endmodule