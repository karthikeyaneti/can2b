`timescale 1ns / 1ps

module tb_two_ff_synchronizer;

    parameter WIDTH = 1;
    parameter [WIDTH-1:0] INIT_VALUE = {WIDTH{1'b1}};

    reg clk;
    reg rst_n_sync;
    reg [WIDTH-1:0] async_in;
    wire [WIDTH-1:0] sync_out;

    // Instantiate DUT
    two_ff_synchronizer #(
        .WIDTH(WIDTH),
        .INIT_VALUE(INIT_VALUE)
    ) dut (
        .clk(clk),
        .rst_n_sync(rst_n_sync),
        .async_in(async_in),
        .sync_out(sync_out)
    );

    // 100MHz clock generation (10ns period)
    always #5 clk = ~clk;

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_two_ff_synchronizer.vcd");
`endif
        $dumpvars(0, tb_two_ff_synchronizer);

        // Initialize signals
        clk = 0;
        rst_n_sync = 0;
        async_in = 1'b1;

        // Hold reset for 20ns
        #20;
        rst_n_sync = 1;

        // Apply asynchronous transitions at arbitrary times relative to clk
        #13 async_in = 1'b0;  // Asynchronous transition to 0
        #35 async_in = 1'b1;  // Asynchronous transition to 1
        #27 async_in = 1'b0;  // Asynchronous transition to 0
        #40 async_in = 1'b1;  // Return to 1

        // Test asynchronous reset during operation
        #25 rst_n_sync = 0;
        #15 rst_n_sync = 1;

        #50;
        $finish;
    end

endmodule
