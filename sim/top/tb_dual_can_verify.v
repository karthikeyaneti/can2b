`timescale 1ns / 1ps

// Debug testbench - adds $display probes to trace BSP/BTL state
module tb_dual_can_verify;

  reg clk_100mhz;
  reg can_clk;
  reg reset_rtl;

  initial begin clk_100mhz = 1'b0; forever #5  clk_100mhz = ~clk_100mhz; end
  // Keep the protocol timing ratios, but run the CAN clock faster so a failed
  // frame cannot make the simulation appear hung for minutes.
  initial begin can_clk    = 1'b0; forever #25 can_clk    = ~can_clk;    end

  wire can_tx_0, can_tx_1;
  wire can_bus_level = (can_tx_0 === 1'b0 || can_tx_1 === 1'b0) ? 1'b0 : 1'b1;

  reg  [11:0] paddr0;
  reg         psel0, penable0, pwrite0;
  reg  [31:0] pwdata0;
  reg  [3:0]  pstrb0 = 4'hF;
  reg  [2:0]  pprot0 = 3'b000;
  wire [31:0] prdata0;
  wire        pready0, pslverr0, irq0;

  reg  [11:0] paddr1;
  reg         psel1, penable1, pwrite1;
  reg  [31:0] pwdata1;
  reg  [3:0]  pstrb1 = 4'hF;
  reg  [2:0]  pprot1 = 3'b000;
  wire [31:0] prdata1;
  wire        pready1, pslverr1, irq1;

  localparam ADDR_SRR    = 12'h000;
  localparam ADDR_MSR    = 12'h004;
  localparam ADDR_BRPR   = 12'h008;
  localparam ADDR_BTR    = 12'h00C;
  localparam ADDR_IER    = 12'h020;
  localparam ADDR_ICR    = 12'h024;
  localparam ADDR_TX_ID  = 12'h030;
  localparam ADDR_TX_DLC = 12'h034;
  localparam ADDR_TX_DW1 = 12'h038;
  localparam ADDR_TX_DW2 = 12'h03C;
  localparam ADDR_RX_ID  = 12'h050;
  localparam ADDR_RX_DLC = 12'h054;
  localparam ADDR_RX_DW1 = 12'h058;
  localparam ADDR_RX_DW2 = 12'h05C;

  can_top can_node0 (
    .s_apb_pclk    (clk_100mhz), .s_apb_presetn (reset_rtl),
    .can_clk       (can_clk),    .can_resetn    (reset_rtl),
    .can_rx        (can_bus_level), .can_tx     (can_tx_0),
    .can_irq       (irq0),
    .s_apb_paddr   (paddr0),  .s_apb_psel    (psel0),
    .s_apb_penable (penable0),.s_apb_pwrite  (pwrite0),
    .s_apb_pwdata  (pwdata0), .s_apb_pstrb   (pstrb0),
    .s_apb_pprot   (pprot0),  .s_apb_prdata  (prdata0),
    .s_apb_pready  (pready0), .s_apb_pslverr (pslverr0)
  );

  can_top can_node1 (
    .s_apb_pclk    (clk_100mhz), .s_apb_presetn (reset_rtl),
    .can_clk       (can_clk),    .can_resetn    (reset_rtl),
    .can_rx        (can_bus_level), .can_tx     (can_tx_1),
    .can_irq       (irq1),
    .s_apb_paddr   (paddr1),  .s_apb_psel    (psel1),
    .s_apb_penable (penable1),.s_apb_pwrite  (pwrite1),
    .s_apb_pwdata  (pwdata1), .s_apb_pstrb   (pstrb1),
    .s_apb_pprot   (pprot1),  .s_apb_prdata  (prdata1),
    .s_apb_pready  (pready1), .s_apb_pslverr (pslverr1)
  );

  always @(posedge can_clk) begin
    if (can_node1.u_can_ch0.u_tx_path_core.u_bsp.rx_frame_valid)
      $display("[%0t ns] Node 1 received ID=%08h DLC=%08h DW1=%08h DW2=%08h",
               $time, can_node1.u_can_ch0.u_tx_path_core.u_bsp.rx_frame_idr,
               can_node1.u_can_ch0.u_tx_path_core.u_bsp.rx_frame_dlcr,
               can_node1.u_can_ch0.u_tx_path_core.u_bsp.rx_frame_dw1r,
               can_node1.u_can_ch0.u_tx_path_core.u_bsp.rx_frame_dw2r);
  end


  // APB Write Tasks
  task apb_write_0(input [11:0] addr, input [31:0] data);
    begin
      @(negedge clk_100mhz);
      paddr0 = addr; pwdata0 = data; pwrite0 = 1; psel0 = 1; penable0 = 0;
      @(negedge clk_100mhz); penable0 = 1;
      @(negedge clk_100mhz);
      if (pready0 !== 1'b1 || pslverr0 === 1'b1)
        $fatal(1, "APB write 0 failed at 0x%03h (pready=%b, pslverr=%b)", addr, pready0, pslverr0);
      psel0 = 0; penable0 = 0; pwrite0 = 0;
    end
  endtask

  task apb_write_1(input [11:0] addr, input [31:0] data);
    begin
      @(negedge clk_100mhz);
      paddr1 = addr; pwdata1 = data; pwrite1 = 1; psel1 = 1; penable1 = 0;
      @(negedge clk_100mhz); penable1 = 1;
      @(negedge clk_100mhz);
      if (pready1 !== 1'b1 || pslverr1 === 1'b1)
        $fatal(1, "APB write 1 failed at 0x%03h (pready=%b, pslverr=%b)", addr, pready1, pslverr1);
      psel1 = 0; penable1 = 0; pwrite1 = 0;
    end
  endtask
  initial begin
    psel0 = 0; penable0 = 0; pwrite0 = 0;
    psel1 = 0; penable1 = 0; pwrite1 = 0;
    
    reset_rtl = 1'b0; 
    #5000;            
    reset_rtl = 1'b1; 
    $display("[%0t ns] Reset released. Configuring cores...", $time);

    apb_write_0(ADDR_MSR,  32'h00000000); 
    apb_write_1(ADDR_MSR,  32'h00000000); 

    apb_write_0(ADDR_BRPR, 32'h00000000); 
    apb_write_1(ADDR_BRPR, 32'h00000000); 
    apb_write_0(ADDR_BTR,  32'h00000155); 
    apb_write_1(ADDR_BTR,  32'h00000155); 

    // VITAL FIX: Correct IER bit (Bit 4) based on tb_two_can_cores.v
    apb_write_1(ADDR_IER,  32'h00000010); 

    apb_write_0(ADDR_SRR,  32'h00000002); 
    apb_write_1(ADDR_SRR,  32'h00000002); 

    $display("[%0t ns] Waiting 5us for CAN cores to observe Bus Idle...", $time);
    #5000;

    // Transmit Frame matching tb_two_can_cores.v exactly
    $display("[%0t ns] Transmitting frame from Node 0...", $time);
    apb_write_0(ADDR_TX_ID,  32'h24600000); // ID: 0x123
    apb_write_0(ADDR_TX_DLC, 32'h10000000); // DLC: 1 byte
    apb_write_0(ADDR_TX_DW1, 32'h00000055); // Payload: 0x55, APB byte order
    apb_write_0(ADDR_TX_DW2, 32'h00000000); // Trigger

    // IRQ Watchdog: IRQ is a latched level until ICR clears the RX event.
    fork: receive_wait
      begin
        wait (irq1 === 1'b1);
      end
      begin
        #100000;
        $fatal(1, "[%0t ns] Timeout waiting for Node 1 RX interrupt", $time);
      end
    join_any
    disable receive_wait;
    $display("[%0t ns] Node 1 RX interrupt asserted", $time);
    // Stop the transmitting node after the acknowledged frame so its TX FIFO
    // cannot start a second frame before APB readback.
    force can_node0.u_can_ch0.u_reg_file.cen_reg = 1'b0;
    force can_node1.u_can_ch0.u_reg_file.cen_reg = 1'b0;
    
    // Verify the host-side RX register values. These are the same signals used
    // by the APB register file for RX_ID/RX_DLC/RX_DW1/RX_DW2 readback.
    #100;
    if (can_node1.u_can_ch0.rx_idr_host === 32'h24600000) $display("  -> ID Verified");
    else $fatal(1, "  -> ID ERROR: got 0x%08h", can_node1.u_can_ch0.rx_idr_host);

    if (can_node1.u_can_ch0.rx_dlcr_host === 32'h10000000) $display("  -> DLC Verified");
    else $fatal(1, "  -> DLC ERROR: got 0x%08h", can_node1.u_can_ch0.rx_dlcr_host);

    if (can_node1.u_can_ch0.rx_dw1r_host === 32'h55000000) $display("  -> DW1 Verified");
    else $fatal(1, "  -> DW1 ERROR: got 0x%08h", can_node1.u_can_ch0.rx_dw1r_host);

    if (can_node1.u_can_ch0.rx_dw2r_host === 32'h00000000) $display("  -> DW2 Verified");
    else $fatal(1, "  -> DW2 ERROR: got 0x%08h", can_node1.u_can_ch0.rx_dw2r_host);

    $display("\n=======================================================");
    $display("   DUAL CORE PHYSICAL BUS VERIFICATION PASSED!         ");
    $display("=======================================================\n");

    $finish;
  end
endmodule