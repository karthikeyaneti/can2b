## can_top.xdc  -  Vivado Timing Constraints for the packaged can_top IP
##
## Supported Boards:
##   - Real Digital Blackboard (Zynq-7007S, xc7z007sclg225)
##   - PYNQ-Z2              (Zynq-7020, xc7z020clg400)
##
## Topology in Block Design (BD):
##   PS FCLK0 (100 MHz) -> AXI-to-APB bridge -> can_top.s_apb_pclk
##   PS FCLK0            -> Clocking Wizard   -> can_top.can_clk  (configurable)
##
## Because can_clk is a *generated* clock from the Clocking Wizard IP whose
## XDC already defines it, this file must NOT re-create it as a primary clock.
## Doing so would produce two independent clocks on the same net and cause
## set_clock_groups -asynchronous to suppress all inter-domain analysis.
##
## ============================================================================
## PART 1 — Input port false paths
## ============================================================================

## can_rx is an asynchronous physical signal driven by the CAN bus transceiver.
## It enters the design through a two_ff_synchronizer inside can_btl_top, so
## there is no valid external launch clock.  A false path prevents misleading
## input-delay violations; the synchronizer itself ensures metastability safety.
if {[llength [get_ports -quiet can_rx]]} {
    set_false_path -from [get_ports can_rx]
}

## ============================================================================
## PART 2 — ASYNC_REG attributes on all synchronizer flip-flop chains
## ============================================================================
## ASYNC_REG instructs Vivado to:
##   (a) prevent re-timing / logic re-ordering across the two-flop boundary
##   (b) place the two flops in the same clock region slice
##
## The RTL already has (* ASYNC_REG = "TRUE" *) attributes, but specifying
## them here ensures coverage for out-of-context (OOC) synthesis flows that
## may strip RTL attributes.

set can_sync_cells [get_cells -quiet -hier -regexp \
    {.*(S1_reg|S2_reg|dst_sync1_reg|dst_sync2_reg)$}]
if {[llength $can_sync_cells]} {
    set_property ASYNC_REG TRUE $can_sync_cells
}

## ============================================================================
## PART 3 — False paths to the first stage of every CDC synchronizer
## ============================================================================
## The first destination flop (S1 / dst_sync1) in every synchronizer sees
## metastable data from the opposite clock domain.  Vivado must not time this
## path as a regular register-to-register timing arc.
##
## Level synchronizers (two_ff_synchronizer): first stage is S1_reg
## ─────────────────────────────────────────────────────────────────
set level_sync_d_pins [get_pins -quiet -hier -regexp \
    {.*two_ff_synchronizer.*/S1_reg/D$}]
if {[llength $level_sync_d_pins]} {
    set_false_path -to $level_sync_d_pins
}

## Reset synchronizers (reset_synchronizer): first stage is S1_reg
## ────────────────────────────────────────────────────────────────
set reset_sync_d_pins [get_pins -quiet -hier -regexp \
    {.*reset_synchronizer.*/S1_reg/D$}]
if {[llength $reset_sync_d_pins]} {
    set_false_path -to $reset_sync_d_pins
}

## Pulse synchronizers (pulse_synchronizer): first stage is dst_sync1_reg
## The toggle flip-flop (src_toggle_reg) is the source; dst_sync1 is the first
## destination flop.
## ────────────────────────────────────────────────────────────────
set pulse_sync_d_pins [get_pins -quiet -hier -regexp \
    {.*pulse_synchronizer.*/dst_sync1_reg/D$}]
if {[llength $pulse_sync_d_pins]} {
    set_false_path -to $pulse_sync_d_pins
}

## ============================================================================
## PART 4 — FIFO Gray-pointer synchronizer false paths
## ============================================================================
## Gray-coded read and write pointers cross clock domains through
## two_ff_synchronizer instances (wr_ptr_sync and rd_ptr_sync) inside can_fifo.
## Only one bit changes per cycle, so metastability never propagates.
## The path to the first capture flop must not be timed.

set fifo_gray_d_pins [get_pins -quiet -hier -regexp \
    {.*(wr_ptr_sync|rd_ptr_sync).*/S1_reg/D$}]
if {[llength $fifo_gray_d_pins]} {
    set_false_path -to $fifo_gray_d_pins
}

## Diagnostic: warn loudly when the selector matched nothing (e.g. hierarchy
## changed after a rename), so the engineer knows to update this XDC.
if {[llength [get_pins -quiet -hier -regexp \
        {.*(wr_ptr_sync|rd_ptr_sync).*/S1_reg/D$}]] == 0} {
    puts "WARNING: can_top.xdc — FIFO Gray-pointer synchronizer pins not found.\
 Update the regexp if FIFO hierarchy changed."
}

## ============================================================================
## PART 5 — Quasi-static configuration registers
## ============================================================================
## brp, tseg1, tseg2, sjw, cen_reg, lback_reg, sleep_reg are written only
## in config_mode (CAN disabled).  When the CAN engine is enabled the registers
## are stable; Vivado may treat these paths as false.

set cfg_reg_q_pins [get_pins -quiet -hier -regexp \
    {.*u_reg_file/(brp|tseg1|tseg2|sjw|cen_reg|lback_reg|sleep_reg)_reg.*/Q$}]
if {[llength $cfg_reg_q_pins]} {
    set_false_path -from $cfg_reg_q_pins
}

## ============================================================================
## PART 6 — Notes on clock creation (DO NOT add create_clock here)
## ============================================================================
## When this file is attached to a block-design (BD) project:
##   - s_apb_pclk is an internal net driven by the PS or AXI-to-APB bridge.
##     Vivado propagates its clock constraint from the PS7/BUFG automatically.
##   - can_clk is an output of the Clocking Wizard IP whose generated-clock
##     constraint lives in the Clocking Wizard XDC stub.
##
## Adding create_clock for either net here would create a duplicate or
## conflicting primary clock and break the Clocking Wizard timing model.
## DO NOT add create_clock or create_generated_clock here.