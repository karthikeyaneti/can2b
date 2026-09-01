`timescale 1ns / 1ps

// Minimal testbench for can_btl_top. No checking, no assertions -- just
// drives the pins and dumps a VCD so the bit timing behavior can be read
// off the waveform directly.
//
// brp=0 -> tq_tick every can_clk cycle, so 1 tq = 10ns. With
// tseg1=5(->6), tseg2=2(->3), sjw=1(->2) that's a 9 tq / 90ns bit.
//
// Sequence driven on rx_in:
//   1. bus sits idle (recessive) after reset
//   2. a dominant edge arrives while bus_idle=1 -> hard sync
//   3. bus_idle is dropped (BSP: frame in progress), a few clean bits
//      go by so bit_tick/sample_point can be seen on an unperturbed bit
//   4. a dominant edge arrives late inside TSEG1 -> resync (TSEG1 stretches)
//   5. a dominant edge arrives early inside TSEG2 -> resync (TSEG2 shrinks)
//   6. bus_idle is reasserted and a second dominant edge arrives -> a
//      second hard sync, proving it isn't a one-shot event
module tb_can_btl_top;

    reg can_clk = 0;
    reg can_rst_n = 0;
    reg config_mode = 1;

    reg [4:0] brp   = 5'd0;
    reg [3:0] tseg1 = 4'd5;
    reg [2:0] tseg2 = 3'd2;
    reg [1:0] sjw   = 2'd1;

    reg rx_in     = 1'b1;
    reg bus_idle  = 1'b1;
    reg tx_active = 1'b0;
    reg tx_bit    = 1'b1;

    wire hard_sync_pulse, resync_pulse, sample_point, sampled_bit, bit_tick;

    can_btl_top dut (
        .can_clk        (can_clk),
        .can_rst_n      (can_rst_n),
        .config_mode    (config_mode),
        .brp            (brp),
        .tseg1          (tseg1),
        .tseg2          (tseg2),
        .sjw            (sjw),
        .rx_in          (rx_in),
        .bus_idle       (bus_idle),
        .tx_active      (tx_active),
        .tx_bit         (tx_bit),
        .hard_sync_pulse(hard_sync_pulse),
        .resync_pulse   (resync_pulse),
        .sample_point   (sample_point),
        .sampled_bit    (sampled_bit),
        .bit_tick       (bit_tick)
    );

    always #5 can_clk = ~can_clk;   // 100 MHz

    initial begin
`ifdef VCD_FILE
        $dumpfile(`VCD_FILE);
`else
        $dumpfile("tb_can_btl_top.vcd");
`endif
        $dumpvars(0, tb_can_btl_top);
    end

    initial begin
        can_rst_n = 0;
        #23 can_rst_n = 1;
        #17 config_mode = 0;

        // bus idle for a bit, then the SOF edge
        #40;
        rx_in = 1'b0;
        #10 rx_in = 1'b1;

        // frame is now in progress as far as the BSP is concerned
        #10 bus_idle = 1'b0;

        // let two clean bits pass with no disturbance
        #180;

        // late edge inside TSEG1 (edge arrives a few tq after Sync_Seg)
        #40;
        rx_in = 1'b0;
        #10 rx_in = 1'b1;

        // let that stretched bit finish, then one more clean bit
        #180;

        // early edge inside TSEG2 (edge arrives before the bit would
        // normally have ended)
        #60;
        rx_in = 1'b0;
        #10 rx_in = 1'b1;

        // run out the rest of that shortened bit plus a clean one
        #150;

        // frame ends, bus goes idle again, next SOF arrives
        bus_idle = 1'b1;
        #40;
        rx_in = 1'b0;
        #10 rx_in = 1'b1;
        #10 bus_idle = 1'b0;

        #150;
        $finish;
    end

endmodule