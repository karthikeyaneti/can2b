`timescale 1ns / 1ps

// can_channel_core: Encapsulates one complete CAN channel.
// Designed for easy dual-channel expansion: instantiate two of these
// in can_top with separate address offsets and physical pins.

module can_channel_core #(
    parameter TX_FIFO_DEPTH = 4,
    parameter RX_FIFO_DEPTH = 4
) (
    // APB / Host Clock Domain
    input  wire        pclk,
    input  wire        presetn,

    // Register Bus Interface (from APB bridge)
    input  wire [11:0] reg_addr,
    input  wire        reg_wr_en,
    input  wire        reg_rd_en,
    input  wire [31:0] reg_wdata,
    input  wire [3:0]  reg_wstrb,
    output wire [31:0] reg_rdata,
    output wire        reg_err,
    output wire [31:0] rx_idr_apb,
    output wire [31:0] rx_dlcr_apb,
    output wire [31:0] rx_dw1r_apb,
    output wire [31:0] rx_dw2r_apb,

    // CAN Engine Clock
    input  wire        can_clk,
    input  wire        can_rst_n,

    // Physical CAN Interface
    input  wire        can_rx,
    output wire        can_tx,

    // Interrupt
    output wire        can_irq
);

    // =========================================================================
    //  Synchronized CAN-Domain Reset
    // =========================================================================
    wire can_clk_rst_n;
    wire srst;
    reset_synchronizer can_reset_sync (
        .clk        (can_clk),
        .rst_n_async(can_rst_n),
        .rst_n_sync (can_clk_rst_n)
    );

    wire srst_can;
    wire can_engine_rst_n = can_clk_rst_n && !srst_can;
    pulse_synchronizer srst_sync (
        .src_clk  (pclk),
        .src_rst_n(presetn),
        .src_pulse(srst),
        .dst_clk  (can_clk),
        .dst_rst_n(can_clk_rst_n),
        .dst_pulse(srst_can)
    );

    // =========================================================================
    //  Register File Outputs
    // =========================================================================
    wire        cen;
    wire        lback;
    wire        sleep_mode;
    wire [7:0]  brp;
    wire [3:0]  tseg1;
    wire [2:0]  tseg2;
    wire [1:0]  sjw;
    wire        config_mode;

    // TX FIFO push (from register file, pclk domain)
    wire        tx_wr_en;
    wire [10:0] tx_id;
    wire [17:0] tx_ext_id;
    wire        tx_ide;
    wire        tx_rtr;
    wire [3:0]  tx_dlc;
    wire [31:0] tx_data0;
    wire [31:0] tx_data1;

    // TX HPB push (from register file, pclk domain)
    wire        tx_hpb_wr_en;
    wire [10:0] tx_hpb_id;
    wire [17:0] tx_hpb_ext_id;
    wire        tx_hpb_ide;
    wire        tx_hpb_rtr;
    wire [3:0]  tx_hpb_dlc;
    wire [31:0] tx_hpb_data0;
    wire [31:0] tx_hpb_data1;

    // RX FIFO pop interface
    wire        rx_pop;
    wire [31:0] rx_idr_host;
    wire [31:0] rx_dlcr_host;
    wire [31:0] rx_dw1r_host;
    wire [31:0] rx_dw2r_host;

    // Acceptance filter registers
    wire [3:0]  afr_uaf;
    wire [31:0] afmr1, afir1;
    wire [31:0] afmr2, afir2;
    wire [31:0] afmr3, afir3;
    wire [31:0] afmr4, afir4;

    // =========================================================================
    //  Status signals from CAN engine -> Register File (need CDC)
    // =========================================================================
    wire        bsp_tx_busy;
    wire        bsp_tx_active;
    wire        bsp_bus_idle;
    wire        bsp_tx_success;
    wire        bsp_tx_error;
    wire        bsp_tx_arblst;
    wire        bsp_rx_ok;
    wire [7:0]  bsp_tec;
    wire [7:0]  bsp_rec;
    wire [1:0]  bsp_estat;
    wire        bsp_errwrn;
    wire        bsp_bus_off;
    wire        bsp_err_acker;
    wire        bsp_err_berr;
    wire        bsp_err_ster;
    wire        bsp_err_fmer;
    wire        bsp_err_crcer;

    wire [7:0]  eml_tec;
    wire [7:0]  eml_rec;
    wire [1:0]  eml_estat;
    wire        eml_errwrn;
    wire        eml_bus_off;

    // TX FIFO status
    wire        tx_fifo_full;
    wire        tx_fifo_empty;

    // RX FIFO status
    wire        rx_empty;
    wire        rx_not_empty;
    wire        rx_underflow;
    wire        rx_overflow;
    wire        rx_fifo_full;

    localparam TX_FIFO_ADDR_WIDTH = $clog2(TX_FIFO_DEPTH);
    localparam RX_FIFO_ADDR_WIDTH = $clog2(RX_FIFO_DEPTH);

    // BTL outputs
    wire        sample_point;
    wire        sampled_bit;
    wire        bit_tick;

    // BSP <-> RX Path connections
    wire        destuff_en;
    wire        destuff_reset;
    wire        destuffed_bit_out;
    wire        destuffed_bit_valid;
    wire        stuff_bit_dropped;
    wire        stuff_error;

    // BSP -> RX FIFO
    wire        rx_frame_valid;
    wire [31:0] rx_frame_idr;
    wire [31:0] rx_frame_dlcr;
    wire [31:0] rx_frame_dw1r;
    wire [31:0] rx_frame_dw2r;
    wire        rx_frame_accepted;

    // BSP CRC interface
    wire        crc_clear;
    wire        crc_update_en;
    wire        crc_bit_in;
    wire [14:0] crc_value;

    // BSP TX bit output
    wire        can_tx_bit;

    // TX FIFO read interface (can_clk domain)
    wire [28:0] tx_rd_id;
    wire        tx_rd_ide;
    wire        tx_rd_rtr;
    wire [3:0]  tx_rd_dlc;
    wire [63:0] tx_rd_data;
    wire        tx_frame_avail;
    wire        tx_rd_en;

    // =========================================================================
    //  CDC: Pulse synchronizers for CAN->pclk event pulses
    // =========================================================================
    wire sync_tx_ok, sync_tx_err, sync_arblst, sync_rx_ok;

    pulse_synchronizer tx_ok_sync (
        .src_clk(can_clk), .src_rst_n(can_engine_rst_n), .src_pulse(bsp_tx_success),
        .dst_clk(pclk),    .dst_rst_n(presetn),        .dst_pulse(sync_tx_ok)
    );

    pulse_synchronizer tx_err_sync (
        .src_clk(can_clk), .src_rst_n(can_engine_rst_n), .src_pulse(bsp_tx_error),
        .dst_clk(pclk),    .dst_rst_n(presetn),        .dst_pulse(sync_tx_err)
    );

    pulse_synchronizer arblst_sync (
        .src_clk(can_clk), .src_rst_n(can_engine_rst_n), .src_pulse(bsp_tx_arblst),
        .dst_clk(pclk),    .dst_rst_n(presetn),        .dst_pulse(sync_arblst)
    );

    pulse_synchronizer rx_ok_sync (
        .src_clk(can_clk), .src_rst_n(can_engine_rst_n), .src_pulse(bsp_rx_ok),
        .dst_clk(pclk),    .dst_rst_n(presetn),        .dst_pulse(sync_rx_ok)
    );

    wire sync_rx_oflw;
    pulse_synchronizer rx_oflw_sync (
        .src_clk(can_clk), .src_rst_n(can_engine_rst_n), .src_pulse(rx_overflow),
        .dst_clk(pclk),    .dst_rst_n(presetn),        .dst_pulse(sync_rx_oflw)
    );

    // CDC: Level synchronizers for CAN->pclk status signals
    wire sync_tx_busy, sync_bus_idle, sync_bus_off, sync_errwrn;
    wire sync_rx_fifo_full;
    wire [1:0] sync_estat;
    wire [7:0] sync_tec, sync_rec;
    wire sync_err_acker, sync_err_berr, sync_err_ster, sync_err_fmer, sync_err_crcer;

    two_ff_synchronizer #(.WIDTH(1), .INIT_VALUE(1'b0)) tx_busy_sync (
        .clk(pclk), .rst_n_sync(presetn), .async_in(bsp_tx_busy), .sync_out(sync_tx_busy)
    );
    two_ff_synchronizer #(.WIDTH(1), .INIT_VALUE(1'b1)) bus_idle_sync (
        .clk(pclk), .rst_n_sync(presetn), .async_in(bsp_bus_idle), .sync_out(sync_bus_idle)
    );
    two_ff_synchronizer #(.WIDTH(1), .INIT_VALUE(1'b0)) bus_off_sync_inst (
        .clk(pclk), .rst_n_sync(presetn), .async_in(eml_bus_off), .sync_out(sync_bus_off)
    );
    two_ff_synchronizer #(.WIDTH(1), .INIT_VALUE(1'b0)) errwrn_sync (
        .clk(pclk), .rst_n_sync(presetn), .async_in(eml_errwrn), .sync_out(sync_errwrn)
    );
    two_ff_synchronizer #(.WIDTH(1), .INIT_VALUE(1'b0)) rx_fifo_full_sync (
        .clk(pclk), .rst_n_sync(presetn), .async_in(rx_fifo_full), .sync_out(sync_rx_fifo_full)
    );
    two_ff_synchronizer #(.WIDTH(2), .INIT_VALUE(2'b00)) estat_sync (
        .clk(pclk), .rst_n_sync(presetn), .async_in(eml_estat), .sync_out(sync_estat)
    );
    two_ff_synchronizer #(.WIDTH(8), .INIT_VALUE(8'd0)) tec_sync (
        .clk(pclk), .rst_n_sync(presetn), .async_in(eml_tec), .sync_out(sync_tec)
    );
    two_ff_synchronizer #(.WIDTH(8), .INIT_VALUE(8'd0)) rec_sync (
        .clk(pclk), .rst_n_sync(presetn), .async_in(eml_rec), .sync_out(sync_rec)
    );
    // Error event signals are one-cycle pulses from can_bsp; use pulse_synchronizer
    // for proper CDC from CAN clock domain to APB clock domain.
    pulse_synchronizer acker_sync (
        .src_clk(can_clk), .src_rst_n(can_engine_rst_n), .src_pulse(bsp_err_acker),
        .dst_clk(pclk),    .dst_rst_n(presetn),           .dst_pulse(sync_err_acker)
    );
    pulse_synchronizer berr_sync (
        .src_clk(can_clk), .src_rst_n(can_engine_rst_n), .src_pulse(bsp_err_berr),
        .dst_clk(pclk),    .dst_rst_n(presetn),           .dst_pulse(sync_err_berr)
    );
    pulse_synchronizer ster_sync (
        .src_clk(can_clk), .src_rst_n(can_engine_rst_n), .src_pulse(bsp_err_ster),
        .dst_clk(pclk),    .dst_rst_n(presetn),           .dst_pulse(sync_err_ster)
    );
    pulse_synchronizer fmer_sync (
        .src_clk(can_clk), .src_rst_n(can_engine_rst_n), .src_pulse(bsp_err_fmer),
        .dst_clk(pclk),    .dst_rst_n(presetn),           .dst_pulse(sync_err_fmer)
    );
    pulse_synchronizer crcer_sync (
        .src_clk(can_clk), .src_rst_n(can_engine_rst_n), .src_pulse(bsp_err_crcer),
        .dst_clk(pclk),    .dst_rst_n(presetn),           .dst_pulse(sync_err_crcer)
    );

    // =========================================================================
    //  Register File (pclk domain)
    // =========================================================================
    can_reg_file u_reg_file (
        .pclk            (pclk),
        .presetn         (presetn),
        .reg_addr        (reg_addr),
        .reg_wr_en       (reg_wr_en),
        .reg_rd_en       (reg_rd_en),
        .reg_wdata       (reg_wdata),
        .reg_wstrb       (reg_wstrb),
        .reg_rdata       (reg_rdata),
        .reg_err         (reg_err),
        .srst            (srst),
        .cen             (cen),
        .lback           (lback),
        .sleep           (sleep_mode),
        .brp             (brp),
        .tseg1           (tseg1),
        .tseg2           (tseg2),
        .sjw             (sjw),
        .config_mode     (config_mode),
        .irq             (can_irq),
        .tx_wr_en        (tx_wr_en),
        .tx_id           (tx_id),
        .tx_ext_id       (tx_ext_id),
        .tx_ide          (tx_ide),
        .tx_rtr          (tx_rtr),
        .tx_dlc          (tx_dlc),
        .tx_data0        (tx_data0),
        .tx_data1        (tx_data1),
        .tx_hpb_wr_en    (tx_hpb_wr_en),
        .tx_hpb_id       (tx_hpb_id),
        .tx_hpb_ext_id   (tx_hpb_ext_id),
        .tx_hpb_ide      (tx_hpb_ide),
        .tx_hpb_rtr      (tx_hpb_rtr),
        .tx_hpb_dlc      (tx_hpb_dlc),
        .tx_hpb_data0    (tx_hpb_data0),
        .tx_hpb_data1    (tx_hpb_data1),
        .rx_pop          (rx_pop),
        .rx_idr          (rx_idr_host),
        .rx_dlcr         (rx_dlcr_host),
        .rx_dw1r         (rx_dw1r_host),
        .rx_dw2r         (rx_dw2r_host),
        .afr_uaf         (afr_uaf),
        .afmr1           (afmr1),
        .afir1           (afir1),
        .afmr2           (afmr2),
        .afir2           (afir2),
        .afmr3           (afmr3),
        .afir3           (afir3),
        .afmr4           (afmr4),
        .afir4           (afir4),
        .tx_busy         (sync_tx_busy),
        .tx_fifo_full    (tx_fifo_full),
        .tx_hpb_full     (1'b0),
        .rx_not_empty    (rx_not_empty),
        .rx_fifo_full    (sync_rx_fifo_full),
        .rx_underflow    (rx_underflow),
        .rx_ok           (sync_rx_ok),
        .tx_ok           (sync_tx_ok),
        .arblst          (sync_arblst),
        .bus_off         (sync_bus_off),
        .error_status    (sync_tx_err),
        .sleep_mode_entered(1'b0),
        .wakeup_event    (1'b0),
        .error_warning   (sync_errwrn),
        .estat           (sync_estat),
        .tec             (sync_tec),
        .rec             (sync_rec),
        .bus_idle        (sync_bus_idle),
        .bus_busy        (~sync_bus_idle),
        .acfb_busy       (1'b0),
        .err_acker       (sync_err_acker),
        .err_berr        (sync_err_berr),
        .err_ster        (sync_err_ster),
        .err_fmer        (sync_err_fmer),
        .err_crcer       (sync_err_crcer)
    );

    // =========================================================================
    //  Pack register fields into TX FIFO write word
    // =========================================================================
    wire [28:0] tx_wr_id_packed = tx_ide ? {tx_id, tx_ext_id} : {18'd0, tx_id};
    wire [63:0] tx_wr_data_packed = {tx_data0, tx_data1};

    // TX path owns the TX FIFO, CRC generator, and protocol BSP.

    // =========================================================================
    //  Loopback Mux: In loopback mode, TX bit feeds back to RX input
    // =========================================================================
    wire        rx_in_muxed = lback ? can_tx_bit : can_rx;
    wire        sampled_bit_raw;

    // In loopback mode, sample_point reads back from can_tx_bit directly
    // (no BTL delay needed for loopback self-test)
    wire        sampled_bit_effective = lback ? can_tx_bit : sampled_bit_raw;

    // =========================================================================
    //  Bit Timing Logic (BTL) Subsystem
    // =========================================================================
    can_btl_top u_btl (
        .can_clk        (can_clk),
        .can_rst_n      (can_engine_rst_n),
        .config_mode    (config_mode),
        .brp            (brp),
        .tseg1          (tseg1),
        .tseg2          (tseg2),
        .sjw            (sjw),
        .rx_in          (rx_in_muxed),
        .bus_idle       (bsp_bus_idle),
        .tx_active      (bsp_tx_active),
        .tx_bit         (can_tx_bit),
        .hard_sync_pulse(),
        .resync_pulse   (),
        .sample_point   (sample_point),
        .sampled_bit    (sampled_bit_raw),
        .bit_tick       (bit_tick)
    );

    can_tx_path_core #(.FIFO_ADDR_WIDTH(TX_FIFO_ADDR_WIDTH)) u_tx_path_core (
        .pclk(pclk), .presetn(presetn), .tx_wr_en(tx_wr_en),
        .tx_wr_id(tx_wr_id_packed), .tx_wr_ide(tx_ide), .tx_wr_rtr(tx_rtr),
        .tx_wr_dlc(tx_dlc), .tx_wr_data(tx_wr_data_packed),
        .tx_fifo_full(tx_fifo_full), .tx_fifo_empty(tx_fifo_empty),
        .can_clk(can_clk), .can_rst_n_sync(can_engine_rst_n), .cen(cen),
        .lback_mode(lback), .sleep_mode(sleep_mode), .sample_point(sample_point),
        .sampled_bit(sampled_bit_effective), .bit_tick(bit_tick),
        .tx_active(bsp_tx_active), .bus_idle(bsp_bus_idle), .can_tx_bit(can_tx_bit),
        .destuff_en(destuff_en), .destuff_reset(destuff_reset),
        .destuffed_bit_out(destuffed_bit_out), .destuffed_bit_valid(destuffed_bit_valid),
        .stuff_bit_dropped(stuff_bit_dropped), .stuff_error(stuff_error),
        .rx_frame_valid(rx_frame_valid), .rx_frame_idr(rx_frame_idr),
        .rx_frame_dlcr(rx_frame_dlcr), .rx_frame_dw1r(rx_frame_dw1r),
        .rx_frame_dw2r(rx_frame_dw2r), .tx_success_pulse(bsp_tx_success),
        .tx_error_pulse(bsp_tx_error), .tx_arblst_pulse(bsp_tx_arblst),
        .rx_ok_pulse(bsp_rx_ok), .tx_busy(bsp_tx_busy), .tec(bsp_tec),
        .rec(bsp_rec), .estat(bsp_estat), .errwrn(bsp_errwrn),
        .bus_off(bsp_bus_off), .err_acker(bsp_err_acker), .err_berr(bsp_err_berr),
        .err_ster(bsp_err_ster), .err_fmer(bsp_err_fmer), .err_crcer(bsp_err_crcer)
    );

    error_management_logic u_eml (
        .can_clk         (can_clk),
        .can_rst_n_sync  (can_engine_rst_n),
        .tx_success      (bsp_tx_success),
        .tx_error        (bsp_tx_error),
        .arbitration_lost(bsp_tx_arblst),
        .rx_success      (bsp_rx_ok),
        .err_acker       (bsp_err_acker),
        .err_berr        (bsp_err_berr),
        .err_ster        (bsp_err_ster),
        .err_fmer        (bsp_err_fmer),
        .err_crcer       (bsp_err_crcer),
        .tec             (eml_tec),
        .rec             (eml_rec),
        .estat           (eml_estat),
        .errwrn          (eml_errwrn),
        .bus_off         (eml_bus_off)
    );

    // =========================================================================
    //  RX Path (Bit De-stuffing, Acceptance Filtering, RX FIFO)
    // =========================================================================
    rx_path_top #(
        .FIFO_ADDR_WIDTH(RX_FIFO_ADDR_WIDTH)
    ) u_rx_path (
        .pclk               (pclk),
        .presetn            (presetn),
        .rx_pop             (rx_pop),
        .rx_idr             (rx_idr_host),
        .rx_dlcr            (rx_dlcr_host),
        .rx_dw1r            (rx_dw1r_host),
        .rx_dw2r            (rx_dw2r_host),
        .rx_empty           (rx_empty),
        .rx_not_empty       (rx_not_empty),
        .rx_fifo_full       (rx_fifo_full),
        .rx_underflow_pulse (rx_underflow),
        .uaf                (afr_uaf),
        .afmr1              (afmr1),
        .afir1              (afir1),
        .afmr2              (afmr2),
        .afir2              (afir2),
        .afmr3              (afmr3),
        .afir3              (afir3),
        .afmr4              (afmr4),
        .afir4              (afir4),
        .can_clk            (can_clk),
        .can_rst_n_sync     (can_engine_rst_n),
        .sample_point       (sample_point),
        .sampled_bit        (sampled_bit_effective),
        .destuff_en         (destuff_en),
        .destuff_reset      (destuff_reset),
        .destuffed_bit_out  (destuffed_bit_out),
        .destuffed_bit_valid(destuffed_bit_valid),
        .stuff_bit_dropped  (stuff_bit_dropped),
        .stuff_error        (stuff_error),
        .rx_frame_valid     (rx_frame_valid),
        .rx_frame_idr       (rx_frame_idr),
        .rx_frame_dlcr      (rx_frame_dlcr),
        .rx_frame_dw1r      (rx_frame_dw1r),
        .rx_frame_dw2r      (rx_frame_dw2r),
        .rx_frame_accepted  (rx_frame_accepted),
        .rx_overflow_pulse  (rx_overflow)
    );

    // =========================================================================
    //  Physical CAN TX output
    // =========================================================================
    assign can_tx = lback ? 1'b1 : can_tx_bit; // In loopback, don't drive bus

    assign rx_idr_apb  = rx_idr_host;
    assign rx_dlcr_apb = rx_dlcr_host;
    assign rx_dw1r_apb = rx_dw1r_host;
    assign rx_dw2r_apb = rx_dw2r_host;

endmodule
