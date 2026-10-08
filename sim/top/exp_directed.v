`timescale 1ns/1ps
module exp;
  reg pclk=0, can_clk=0, rstn=0;
  always #5 pclk=~pclk;
  always #25 can_clk=~can_clk; // 20 MHz
  reg [11:0] a0,a1; reg s0=0,s1=0,e0=0,e1=0,w0=0,w1=0; reg [31:0] d0=0,d1=0;
  wire [31:0] rd0,rd1; wire pr0,pr1,er0,er1,irq0,irq1,tx0,tx1;
  wire bus = tx0 & tx1;
  can_top n0(.s_apb_pclk(pclk),.s_apb_presetn(rstn),.can_clk(can_clk),.can_resetn(rstn),
    .s_apb_paddr(a0),.s_apb_psel(s0),.s_apb_penable(e0),.s_apb_pwrite(w0),.s_apb_pwdata(d0),
    .s_apb_pstrb(4'hF),.s_apb_pprot(3'b0),.s_apb_prdata(rd0),.s_apb_pready(pr0),.s_apb_pslverr(er0),
    .can_rx(bus),.can_tx(tx0),.can_irq(irq0));
  can_top n1(.s_apb_pclk(pclk),.s_apb_presetn(rstn),.can_clk(can_clk),.can_resetn(rstn),
    .s_apb_paddr(a1),.s_apb_psel(s1),.s_apb_penable(e1),.s_apb_pwrite(w1),.s_apb_pwdata(d1),
    .s_apb_pstrb(4'hF),.s_apb_pprot(3'b0),.s_apb_prdata(rd1),.s_apb_pready(pr1),.s_apb_pslverr(er1),
    .can_rx(bus),.can_tx(tx1),.can_irq(irq1));
  reg [31:0] rv; reg errflag;
  task wr0(input [11:0] a, input [31:0] d); begin
    @(negedge pclk); a0=a; d0=d; w0=1; s0=1; e0=0; @(negedge pclk); e0=1; @(negedge pclk); errflag=er0; s0=0; e0=0; w0=0; end endtask
  task rdd0(input [11:0] a); begin
    @(negedge pclk); a0=a; w0=0; s0=1; e0=0; @(negedge pclk); e0=1; #1; rv=rd0; errflag=er0; @(negedge pclk); s0=0; e0=0; end endtask
  task wr1(input [11:0] a, input [31:0] d); begin
    @(negedge pclk); a1=a; d1=d; w1=1; s1=1; e1=0; @(negedge pclk); e1=1; @(negedge pclk); s1=0; e1=0; w1=0; end endtask
  task rdd1(input [11:0] a); begin
    @(negedge pclk); a1=a; w1=0; s1=1; e1=0; @(negedge pclk); e1=1; #1; rv=rd1; errflag=er1; @(negedge pclk); s1=0; e1=0; end endtask
  task show0(input [255:0] name, input [11:0] a); begin rdd0(a); $display("  n0 %0s [0x%03h] = 0x%08h pslverr=%0d", name, a, rv, errflag); end endtask
  task show1(input [255:0] name, input [11:0] a); begin rdd1(a); $display("  n1 %0s [0x%03h] = 0x%08h pslverr=%0d", name, a, rv, errflag); end endtask

  // probes
  wire [4:0] st0 = n0.u_can_ch0.u_tx_path_core.u_bsp.state;
  wire [4:0] rs0 = n0.u_can_ch0.u_tx_path_core.u_bsp.rx_state;
  wire [4:0] rs1 = n1.u_can_ch0.u_tx_path_core.u_bsp.rx_state;
  integer sof_cnt=0, succ_cnt=0, err_cnt=0, rd_cnt=0, ackerr_hi=0, ackerr_dst=0, arb_cnt=0;
  reg [4:0] st0_q=0;
  always @(posedge can_clk) begin
    st0_q <= st0;
    if (st0==1 && st0_q!=1) sof_cnt=sof_cnt+1;
    if (n0.u_can_ch0.u_tx_path_core.u_bsp.tx_success_pulse) succ_cnt=succ_cnt+1;
    if (n0.u_can_ch0.u_tx_path_core.u_bsp.tx_error_pulse) err_cnt=err_cnt+1;
    if (n0.u_can_ch0.u_tx_path_core.u_bsp.tx_rd_en) rd_cnt=rd_cnt+1;
    if (n0.u_can_ch0.u_tx_path_core.u_bsp.err_acker) ackerr_hi=ackerr_hi+1;
  end
  always @(posedge pclk) if (n0.u_can_ch0.sync_err_acker) ackerr_dst=ackerr_dst+1;

  integer scen=0; reg [31:0] btrv; reg [31:0] dv; integer brpv;
  integer i;
  initial begin
    if (!$value$plusargs("SCEN=%d", scen)) scen=0;
    #200; rstn=1; #500;
    if (scen==0) begin
      $display("SCEN0: register reset values (node0)");
      show0("SRR",12'h000); show0("MSR",12'h004); show0("BRPR",12'h008); show0("BTR",12'h00C);
      show0("ECR",12'h010); show0("ESR",12'h014); show0("SR",12'h018); show0("ISR",12'h01C);
      show0("IER",12'h020); show0("AFR",12'h060);
      show0("TX_ID(wo)",12'h030); show0("ICR",12'h024); show0("unmapped 0x028",12'h028);
      show0("unmapped 0x084",12'h084);
      wr0(12'h018, 32'h1); $display("  write to SR pslverr=%0d", errflag);
      wr0(12'h01C, 32'h1); $display("  write to ISR pslverr=%0d", errflag);
      wr0(12'h028, 32'h1); $display("  write to 0x028 pslverr=%0d", errflag);
      wr0(12'h000, 32'h2); $display("  SRR<=CEN pslverr=%0d", errflag);
      wr0(12'h008, 32'h3); $display("  BRPR write while CEN=1 pslverr=%0d", errflag);
      wr0(12'h004, 32'h2); $display("  MSR write while CEN=1 pslverr=%0d", errflag); show0("MSR after",12'h004);
      show0("SR (CEN=1)",12'h018);
      // BTR after SRST
      wr0(12'h000, 32'h1); show0("SRR after SRST",12'h000);
      wr0(12'h00C, 32'h155); wr0(12'h000,32'h1); show0("BTR after SRST (was 0x155)",12'h00C);
    end
    if (scen==1) begin
      $display("SCEN1: single node, NO receiver ACK, normal mode, default BTR/BRP");
      wr0(12'h020, 32'hFFFFFFFF); // IER all
      wr0(12'h000, 32'h2);
      #2000;
      wr0(12'h030, 32'h24600000); wr0(12'h034, 32'h10000000); wr0(12'h038, 32'h5A); wr0(12'h03C, 0);
      #300000;
      $display("  sof_cnt=%0d tx_error_pulses=%0d tx_success_pulses=%0d tx_rd_en=%0d err_acker_high_cycles=%0d acker_dst_pulses=%0d",
         sof_cnt, err_cnt, succ_cnt, rd_cnt, ackerr_hi, ackerr_dst);
      show0("ECR",12'h010); show0("ESR",12'h014); show0("ISR",12'h01C); show0("SR",12'h018);
      $display("  TX FIFO empty=%0d  rx_state=%0d  bsp.tec=%0d eml.tec=%0d eml.rec=%0d",
         n0.u_can_ch0.tx_fifo_empty, rs0, n0.u_can_ch0.u_tx_path_core.u_bsp.tec, n0.u_can_ch0.u_eml.tec, n0.u_can_ch0.u_eml.rec);
    end
    if (scen==2 || scen==22) begin
      $display("SCEN2: two nodes, node0 TXs, node1 ACKs. Does node0 receive its own frame?");
      wr0(12'h020, 32'hFFFFFFFF); wr1(12'h020, 32'hFFFFFFFF);
      if ($value$plusargs("BTR=%h", btrv)) begin wr0(12'h00C, btrv); wr1(12'h00C, btrv); end
      if ($value$plusargs("BRP=%d", brpv)) begin wr0(12'h008, brpv); wr1(12'h008, brpv); end
      wr0(12'h000, 32'h2); wr1(12'h000, 32'h2);
      #2000;
      wr0(12'h030, 32'h24600000); wr0(12'h034, 32'h10000000); if(!$value$plusargs("DATA=%h", dv)) dv=32'h5A; wr0(12'h038, dv); wr0(12'h03C, 0);
      #2500000; if (scen==22) $finish;
      $display("  sof_cnt=%0d tx_err=%0d tx_ok=%0d", sof_cnt, err_cnt, succ_cnt);
      show0("n0 ISR",12'h01C); show1("n1 ISR",12'h01C);
      show0("n0 RX_ID",12'h050); show1("n1 RX_ID",12'h050);
      show0("n0 ESR",12'h014); show1("n1 ESR",12'h014);
      show0("n0 ECR",12'h010); show1("n1 ECR",12'h010);
      show0("n0 SR",12'h018);
      // ISR clear then check re-set of level bits
      wr0(12'h024, 32'hFFFFFFFF); show0("n0 ISR after ICR=FFFFFFFF",12'h01C);
      show1("n1 RX_DLC",12'h054); show1("n1 RX_DW1",12'h058); show1("n1 RX_DW2 (pop)",12'h05C);
      #200; wr1(12'h024, 32'hFFFFFFFF); show1("n1 ISR after pop+ICR",12'h01C);
    end
    if (scen==3) begin
      $display("SCEN3: loopback, single node");
      wr0(12'h020, 32'hFFFFFFFF);
      wr0(12'h004, 32'h2); wr0(12'h000, 32'h2);
      #2000;
      wr0(12'h030, 32'h24600000); wr0(12'h034, 32'h10000000); wr0(12'h038, 32'h5A); wr0(12'h03C, 0);
      #60000;
      $display("  sof_cnt=%0d tx_err=%0d tx_ok=%0d can_tx pin min=%b", sof_cnt, err_cnt, succ_cnt, tx0);
      show0("ISR",12'h01C); show0("ESR",12'h014); show0("SR",12'h018);
      show0("RX_ID",12'h050); show0("RX_DLC",12'h054); show0("RX_DW1",12'h058);
    end
    $finish;
  end
  // loopback ack-slot level & can_tx pin activity
  integer pin_low=0;
  always @(posedge can_clk) if (tx0===1'b0) pin_low=pin_low+1;
  always @(posedge can_clk) if (scen==3 && n0.u_can_ch0.u_tx_path_core.u_bsp.state==12 && n0.u_can_ch0.u_tx_path_core.u_bsp.sample_point)
      $display("  [loopback] ACK slot sample: can_tx_bit=%b sampled_bit=%b rx_ack_drive=%b", n0.u_can_ch0.can_tx_bit, n0.u_can_ch0.sampled_bit_effective, n0.u_can_ch0.u_tx_path_core.u_bsp.rx_ack_drive);
  initial begin #1; end
  final if (scen==3) $display("  [loopback] can_tx pin low cycles = %0d", pin_low);
endmodule
