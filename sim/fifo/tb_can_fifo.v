`timescale 1ns / 1ps

module tb_can_fifo;

    parameter DATA_WIDTH = 64;
    parameter FIFO_DEPTH = 8;
    localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);

    reg wr_clk;
    reg rd_clk;
    reg wr_rst_n;
    reg rd_rst_n;
    reg wr_en;
    reg rd_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    wire [DATA_WIDTH-1:0] rd_data;
    wire empty;
    wire full;

    integer errors = 0;

    // Instantiate DUT
    can_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .wr_rst_n_sync(wr_rst_n),
        .rd_rst_n_sync(rd_rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .empty(empty),
        .full(full)
    );

    // Asynchronous clocks: Fast Write (100MHz / 10ns), Slower Read (40MHz / 25ns)
    always #5 wr_clk = ~wr_clk;
    always #12.5 rd_clk = ~rd_clk;

    // Task to write a single word into FIFO
    task write_word(input [DATA_WIDTH-1:0] data);
        begin
            @(posedge wr_clk);
            while (full) @(posedge wr_clk);
            wr_en   <= 1'b1;
            wr_data <= data;
            @(posedge wr_clk);
            wr_en   <= 1'b0;
            wr_data <= {DATA_WIDTH{1'bx}};
        end
    endtask

    // Task to read and verify word
    task read_and_check(input [DATA_WIDTH-1:0] exp_data);
        begin
            @(posedge rd_clk);
            while (empty) @(posedge rd_clk);
            if (rd_data !== exp_data) begin
                $display("[TB ERROR] Read data mismatch! Expected: %h, Got: %h at time %0t", exp_data, rd_data, $time);
                errors = errors + 1;
            end
            rd_en <= 1'b1;
            @(posedge rd_clk);
            rd_en <= 1'b0;
        end
    endtask

    integer i;

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_can_fifo.vcd");
`endif
        $dumpvars(0, tb_can_fifo);

        wr_clk   = 0;
        rd_clk   = 0;
        wr_rst_n = 0;
        rd_rst_n = 0;
        wr_en    = 0;
        rd_en    = 0;
        wr_data  = 0;

        // Apply Reset
        #30;
        wr_rst_n = 1;
        rd_rst_n = 1;

        // Wait a few cycles for synchronizers to propagate reset values
        repeat(4) @(posedge rd_clk);
        repeat(4) @(posedge wr_clk);

        //----------------------------------------------------------------------
        // Test 1: Reset Check
        //----------------------------------------------------------------------
        $display("[TB] Test 1: Verifying Initial Reset Status...");
        if (!empty) begin
            $display("[TB ERROR] FIFO should be empty after reset!");
            errors = errors + 1;
        end
        if (full) begin
            $display("[TB ERROR] FIFO should not be full after reset!");
            errors = errors + 1;
        end

        //----------------------------------------------------------------------
        // Test 2: Sequential Fill and Drain (Full & Empty flag test)
        //----------------------------------------------------------------------
        $display("[TB] Test 2: Sequential Fill to Full and Drain to Empty...");
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            write_word(64'hA000_0000_0000_0000 + i);
        end

        // Wait for write pointer to sync to read domain and check full flag
        @(posedge wr_clk);
        if (!full) begin
            $display("[TB ERROR] FIFO should be full after writing %0d words!", FIFO_DEPTH);
            errors = errors + 1;
        end

        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin
            read_and_check(64'hA000_0000_0000_0000 + i);
        end

        // Wait for read pointer to sync back to write domain
        repeat(5) @(posedge wr_clk);
        if (!empty) begin
            $display("[TB ERROR] FIFO should be empty after reading %0d words!", FIFO_DEPTH);
            errors = errors + 1;
        end

        //----------------------------------------------------------------------
        // Test 3: Pointer Wrap-around Test (Multiple full-drain cycles)
        //----------------------------------------------------------------------
        $display("[TB] Test 3: Pointer Wrap-around Test across MSB boundaries...");
        for (i = 0; i < FIFO_DEPTH * 3; i = i + 1) begin
            write_word(64'hB000_0000_0000_0000 + i);
            read_and_check(64'hB000_0000_0000_0000 + i);
        end

        //----------------------------------------------------------------------
        // Test 4: Concurrent Asynchronous Burst Write / Read (Stress test)
        //----------------------------------------------------------------------
        $display("[TB] Test 4: Concurrent Asynchronous Burst Write & Read...");
        fork
            begin : writer_thread
                integer w;
                for (w = 0; w < 50; w = w + 1) begin
                    write_word(64'hC000_0000_0000_0000 + w);
                end
            end
            begin : reader_thread
                integer r;
                for (r = 0; r < 50; r = r + 1) begin
                    read_and_check(64'hC000_0000_0000_0000 + r);
                end
            end
        join

        repeat(5) @(posedge wr_clk);
        repeat(5) @(posedge rd_clk);

        //----------------------------------------------------------------------
        // Summary
        //----------------------------------------------------------------------
        if (errors == 0) begin
            $display("\n=======================================================");
            $display("   ALL CAN_FIFO TESTS PASSED SUCCESSFULLY!             ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("   CAN_FIFO TESTS FAILED WITH %0d ERRORS!              ", errors);
            $display("=======================================================\n");
        end

        $finish;
    end

endmodule
