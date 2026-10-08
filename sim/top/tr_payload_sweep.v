`timescale 1ns/1ps
module tr5;
  integer ok1=0, st1=0, st0=0, ok0=0; reg [31:0] dv; 
  always @(posedge exp.can_clk) begin
    if (exp.n1.u_can_ch0.u_tx_path_core.u_bsp.rx_ok_pulse) ok1=ok1+1;
    if (exp.n1.u_can_ch0.u_tx_path_core.u_bsp.stuff_error) st1=st1+1;
    if (exp.n0.u_can_ch0.u_tx_path_core.u_bsp.stuff_error) st0=st0+1;
  end
  initial begin #2500000; if(!$value$plusargs("DATA=%h", dv)) dv=0;
    $display("RESULT data=%02h n1_rx_ok=%0d n1_stuff_err=%0d n0_stuff_err=%0d", dv[7:0], ok1, st1, st0); $finish; end
endmodule
