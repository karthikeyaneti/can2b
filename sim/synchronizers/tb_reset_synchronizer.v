`timescale 1ns / 1ps

module tb_reset_synchronizer;

    reg clk;
    reg rst_n_async;
    wire rst_n_sync;

    // Instantiate DUT
    reset_synchronizer dut (
        .clk(clk),
        .rst_n_async(rst_n_async),
        .rst_n_sync(rst_n_sync)
    );

    // 100MHz clock generation (10ns period)
    always #5 clk = ~clk;

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_reset_synchronizer.vcd");
`endif
        $dumpvars(0, tb_reset_synchronizer);

        // Initialize signals
        clk = 0;
        rst_n_async = 0;

        // Hold asynchronous reset initially
        #25;
        // Asynchronous reset de-assertion (at an arbitrary time relative to clock edge)
        #3 rst_n_async = 1;

        // Wait a few clock cycles to observe synchronized reset release
        #50;

        // Asynchronous reset assertion (should take effect immediately without waiting for clock edge)
        #7 rst_n_async = 0;
        #20;

        // De-assert reset again
        #3 rst_n_async = 1;
        #50;

        $finish;
    end

endmodule
