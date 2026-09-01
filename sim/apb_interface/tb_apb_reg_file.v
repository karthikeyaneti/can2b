`timescale 1ns/1ps

module tb_apb_reg_file;
    localparam [11:0] CTRL = 12'h000;
    localparam [11:0] STAT = 12'h004;
    localparam [11:0] TIME = 12'h008;
    localparam [11:0] ERRC = 12'h00C;

    reg pclk, presetn, psel, penable, pwrite;
    reg [11:0] paddr;
    reg [31:0] pwdata;
    reg [3:0] pstrb;
    reg [2:0] pprot;
    wire [31:0] prdata;
    wire pready, pslverr;

    wire [11:0] reg_addr;
    wire reg_wr_en, reg_rd_en;
    wire [31:0] reg_wdata, reg_rdata;
    wire [3:0] reg_wstrb;
    wire reg_err;

    reg sync_tec_inc, sync_rec_inc, sync_tx_busy;
    wire config_mode, ctrl_start_tx;
    wire [4:0] brp;
    wire [3:0] tseg1;
    wire [2:0] tseg2;
    wire [1:0] sjw;

    integer failures;
    reg [31:0] read_data;
    reg read_error;

    always begin
        #5 pclk = 1'b1;
        #5 pclk = 1'b0;
    end

    apb_interface #(.ADDR_WIDTH(12), .DATA_WIDTH(32)) dut_apb (
        .pclk(pclk), .presetn(presetn), .psel(psel), .paddr(paddr),
        .pwdata(pwdata), .pwrite(pwrite), .penable(penable), .pstrb(pstrb),
        .pprot(pprot), .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .reg_addr(reg_addr), .reg_wr_en(reg_wr_en), .reg_rd_en(reg_rd_en),
        .reg_wdata(reg_wdata), .reg_wstrb(reg_wstrb), .reg_rdata(reg_rdata),
        .reg_err(reg_err)
    );

    can_reg_file dut_regs (
        .pclk(pclk), .presetn(presetn), .reg_addr(reg_addr),
        .reg_wr_en(reg_wr_en), .reg_rd_en(reg_rd_en), .reg_wdata(reg_wdata),
        .reg_wstrb(reg_wstrb), .reg_rdata(reg_rdata), .reg_err(reg_err),
        .config_mode(config_mode), .brp(brp), .tseg1(tseg1), .tseg2(tseg2),
        .sjw(sjw), .ctrl_start_tx(ctrl_start_tx),
        .sync_tec_inc(sync_tec_inc), .sync_rec_inc(sync_rec_inc),
        .sync_tx_busy(sync_tx_busy)
    );

    task automatic write_apb;
        input [11:0] address;
        input [31:0] data;
        input [3:0] strobes;
        begin
            @(negedge pclk);
            psel = 1'b1; penable = 1'b0; pwrite = 1'b1;
            paddr = address; pwdata = data; pstrb = strobes;
            #4;
            penable = 1'b1;
            #1;
            if (pready !== 1'b1) begin
                $display("FAIL write %h: PREADY is low", address);
                failures = failures + 1;
            end
            @(negedge pclk);
            psel = 1'b0; penable = 1'b0; pwrite = 1'b0;
            paddr = 12'b0; pwdata = 32'b0; pstrb = 4'b0;
        end
    endtask

    task automatic read_apb;
        input [11:0] address;
        output [31:0] data;
        output error;
        begin
            @(negedge pclk);
            psel = 1'b1; penable = 1'b0; pwrite = 1'b0;
            paddr = address; pwdata = 32'b0; pstrb = 4'b0;
            #4;
            penable = 1'b1;
            #1;
            if (pready !== 1'b1) begin
                $display("FAIL read %h: PREADY is low", address);
                failures = failures + 1;
            end
            data = prdata;
            error = pslverr;
            @(negedge pclk);
            psel = 1'b0; penable = 1'b0; paddr = 12'b0;
        end
    endtask

    task automatic check;
        input [31:0] actual;
        input [31:0] expected;
        input [8*32-1:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL %0s: got %h expected %h", label, actual, expected);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        pclk = 1'b0;
        presetn = 1'b0;
        psel = 1'b0;
        penable = 1'b0;
        pwrite = 1'b0;
        paddr = 12'b0;
        pwdata = 32'b0;
        pstrb = 4'b0;
        pprot = 3'b000;
        sync_tec_inc = 1'b0;
        sync_rec_inc = 1'b0;
        sync_tx_busy = 1'b0;
        failures = 0;

        $dumpfile("build/tb_apb_reg_file/tb_apb_reg_file.vcd");
        $dumpvars(0, tb_apb_reg_file);

        repeat (2) @(negedge pclk);
        presetn = 1'b1;
        repeat (2) @(negedge pclk);

        if (config_mode !== 1'b1 || brp !== 0 || tseg1 !== 5 ||
            tseg2 !== 2 || sjw !== 0) begin
            $display("FAIL reset values");
            failures = failures + 1;
        end

        read_apb(CTRL, read_data, read_error);
        check(read_data, 32'h00000000, "control reset");
        if (read_error) begin
            $display("FAIL valid control read has PSLVERR");
            failures = failures + 1;
        end

        write_apb(TIME, 32'h01030504, 4'b1111);
        if (brp !== 4 || tseg1 !== 5 || tseg2 !== 3 || sjw !== 1) begin
            $display("FAIL timing outputs");
            failures = failures + 1;
        end
        write_apb(TIME, 32'h0000001A, 4'b0001);
        if (brp !== 26 || tseg1 !== 5 || tseg2 !== 3 || sjw !== 1) begin
            $display("FAIL byte strobe behavior");
            failures = failures + 1;
        end

        write_apb(CTRL, 32'h00000002, 4'b0001);
        if (config_mode !== 1'b0) begin
            $display("FAIL CEN control");
            failures = failures + 1;
        end
        write_apb(12'h100, 32'hFFFFFFFF, 4'b1111);

        if (failures == 0) begin
            $display("APB/register-file integration test PASSED");
            $finish;
        end
        $display("APB/register-file integration test FAILED: %0d failure(s)", failures);
        $fatal(1);
    end

endmodule
