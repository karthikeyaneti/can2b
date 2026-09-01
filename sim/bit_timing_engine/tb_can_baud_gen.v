module tb_can_baud_gen;
    reg can_clk;
    reg can_rst_n_sync;
    reg config_mode;
    reg [4:0] brp;
    wire tq_tick4, tq_tick0, tq_tick31;

    can_baud_gen uut (
        .can_clk(can_clk),
        .can_rst_n_sync(can_rst_n_sync),
        .config_mode(config_mode),
        .brp(brp),
        .tq_tick(tq_tick4)
    );

    can_baud_gen uut0 (
        .can_clk(can_clk),
        .can_rst_n_sync(can_rst_n_sync),
        .config_mode(config_mode),
        .brp(5'd0),
        .tq_tick(tq_tick0)
    );

    can_baud_gen uut31 (
        .can_clk(can_clk),
        .can_rst_n_sync(can_rst_n_sync),
        .config_mode(config_mode),
        .brp(5'h1f),
        .tq_tick(tq_tick31)
    );

    always #5 can_clk = ~can_clk; // 100 MHz clock

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_can_baud_gen.vcd");
`endif
        $dumpvars(0, tb_can_baud_gen);
    end
    
    initial begin
        can_clk = 0;
        can_rst_n_sync = 0;
        config_mode = 0;
        brp = 5'd4; // Set BRP to 4 for testing
        #20;
        can_rst_n_sync = 1;
        #20;
        config_mode = 1;
        #50;
        config_mode = 0;
        // Run the simulation for a certain period
        #2000;

        $finish;
    end  
endmodule