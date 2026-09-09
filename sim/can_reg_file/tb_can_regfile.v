`timescale 1ns / 1ps

module tb_can_regfile;
    reg pclk, presetn;
    reg [11:0] reg_addr;
    reg reg_wr_en, reg_rd_en;
    reg [31:0] reg_wdata;
    reg [3:0] reg_wstrb;
    wire [31:0] reg_rdata;
    wire reg_err, srst, cen, lback, sleep, config_mode, irq;
    wire [7:0] brp;
    wire [3:0] tseg1;
    wire [2:0] tseg2;
    wire [1:0] sjw;
    integer failures;

    always #5 pclk = ~pclk;

    can_reg_file dut (
        .pclk(pclk), .presetn(presetn), .reg_addr(reg_addr),
        .reg_wr_en(reg_wr_en), .reg_rd_en(reg_rd_en), .reg_wdata(reg_wdata),
        .reg_wstrb(reg_wstrb), .reg_rdata(reg_rdata), .reg_err(reg_err),
        .srst(srst), .cen(cen), .lback(lback), .sleep(sleep), .brp(brp),
        .tseg1(tseg1), .tseg2(tseg2), .sjw(sjw), .config_mode(config_mode),
        .irq(irq), .tx_wr_en(), .tx_id(), .tx_ext_id(), .tx_ide(), .tx_rtr(),
        .tx_dlc(), .tx_data0(), .tx_data1(), .tx_hpb_wr_en(), .tx_hpb_id(),
        .tx_hpb_ext_id(), .tx_hpb_ide(), .tx_hpb_rtr(), .tx_hpb_dlc(),
        .tx_hpb_data0(), .tx_hpb_data1(), .rx_pop(), .rx_idr(32'd0),
        .rx_dlcr(32'd0), .rx_dw1r(32'd0), .rx_dw2r(32'd0), .afr_uaf(),
        .afmr1(), .afir1(), .afmr2(), .afir2(), .afmr3(), .afir3(),
        .afmr4(), .afir4(), .tx_busy(1'b0), .tx_fifo_full(1'b0),
        .tx_hpb_full(1'b0), .rx_not_empty(1'b0), .rx_fifo_full(1'b0),
        .rx_underflow(1'b0), .rx_ok(1'b0), .tx_ok(1'b0), .arblst(1'b0),
        .bus_off(1'b0), .error_status(1'b0), .sleep_mode_entered(1'b0),
        .wakeup_event(1'b0), .error_warning(1'b0), .estat(2'b0), .tec(8'd0),
        .rec(8'd0), .bus_idle(1'b1), .bus_busy(1'b0), .acfb_busy(1'b0),
        .err_acker(1'b0), .err_berr(1'b0), .err_ster(1'b0), .err_fmer(1'b0),
        .err_crcer(1'b0)
    );

    task automatic write_reg(input [11:0] address, input [31:0] data,
                             input [3:0] strobes);
        begin
            @(negedge pclk);
            reg_addr = address; reg_wdata = data; reg_wstrb = strobes;
            reg_wr_en = 1'b1; reg_rd_en = 1'b0;
            @(negedge pclk);
            reg_wr_en = 1'b0; reg_wstrb = 4'b0;
        end
    endtask

    initial begin
        pclk = 1'b0; presetn = 1'b0; reg_addr = 12'd0; reg_wr_en = 1'b0;
        reg_rd_en = 1'b0; reg_wdata = 32'd0; reg_wstrb = 4'b0; failures = 0;
        repeat (2) @(negedge pclk);
        presetn = 1'b1;

        write_reg(12'h008, 32'h00000004, 4'b0001);
        if (brp !== 8'd4) failures = failures + 1;
        write_reg(12'h008, 32'h00001A00, 4'b0010);
        if (brp !== 8'd4) failures = failures + 1;
        write_reg(12'h000, 32'h00000002, 4'b0001);
        if (cen !== 1'b1 || config_mode !== 1'b0) failures = failures + 1;
        write_reg(12'h000, 32'h00000001, 4'b0001);
        if (srst !== 1'b1 || cen !== 1'b0) failures = failures + 1;
        @(negedge pclk);
        if (srst !== 1'b0) failures = failures + 1;

        if (failures == 0)
            $display("CAN REG FILE TEST PASSED");
        else begin
            $display("CAN REG FILE TEST FAILED: %0d failures", failures);
            $fatal(1);
        end
        $finish;
    end
endmodule