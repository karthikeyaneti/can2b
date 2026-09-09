`timescale 1ns/1ps

module tb_error_management_logic;
    reg can_clk;
    reg can_rst_n_sync;
    reg tx_success;
    reg tx_error;
    reg arbitration_lost;
    reg rx_success;
    reg err_acker;
    reg err_berr;
    reg err_ster;
    reg err_fmer;
    reg err_crcer;
    wire [7:0] tec;
    wire [7:0] rec;
    wire [1:0] estat;
    wire errwrn;
    wire bus_off;
    integer errors;
    integer i;

    error_management_logic dut (
        .can_clk(can_clk),
        .can_rst_n_sync(can_rst_n_sync),
        .tx_success(tx_success),
        .tx_error(tx_error),
        .arbitration_lost(arbitration_lost),
        .rx_success(rx_success),
        .err_acker(err_acker),
        .err_berr(err_berr),
        .err_ster(err_ster),
        .err_fmer(err_fmer),
        .err_crcer(err_crcer),
        .tec(tec),
        .rec(rec),
        .estat(estat),
        .errwrn(errwrn),
        .bus_off(bus_off)
    );

    always #5 can_clk = ~can_clk;

    task automatic transmit_error;
        begin
            @(negedge can_clk);
            tx_error = 1'b1;
            @(negedge can_clk);
            tx_error = 1'b0;
        end
    endtask

    initial begin
        can_clk = 1'b0;
        can_rst_n_sync = 1'b0;
        tx_success = 1'b0;
        tx_error = 1'b0;
        arbitration_lost = 1'b0;
        rx_success = 1'b0;
        err_acker = 1'b0;
        err_berr = 1'b0;
        err_ster = 1'b0;
        err_fmer = 1'b0;
        err_crcer = 1'b0;
        errors = 0;

        repeat (2) @(posedge can_clk);
        can_rst_n_sync = 1'b1;

        for (i = 0; i < 31; i = i + 1)
            transmit_error();

        if (tec !== 8'd248 || bus_off !== 1'b0 || estat !== 2'b01) begin
            $display("[TB ERROR] TEC=248 boundary: tec=%0d bus_off=%b estat=%b", tec, bus_off, estat);
            errors = errors + 1;
        end

        transmit_error();
        if (tec !== 8'hFF || bus_off !== 1'b1 || estat !== 2'b10) begin
            $display("[TB ERROR] Bus-off boundary: tec=%0d bus_off=%b estat=%b internal=%0d", tec, bus_off, estat, dut.tec_count);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("ERROR MANAGEMENT LOGIC TEST PASSED");
        else
            $display("ERROR MANAGEMENT LOGIC TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
