# can2b CAN Controller

`can2b` is a synthesizable Verilog CAN 2.0B controller with an APB4
programming interface. The current top level implements one CAN channel and
uses separate APB and CAN engine clock domains.

## Overview

The two clock domains are:

- `s_apb_pclk`: APB interface and register file.
- `can_clk`: CAN bit timing, protocol, error management, and CAN-side FIFO
  interfaces.

The external pins are intended for a physical CAN transceiver. `can_rx` is the
transceiver receive output; `can_tx` is the controller transmit logic output.

Implemented functionality includes standard and extended CAN identifiers,
RTR frames, programmable bit timing, TX/RX asynchronous FIFOs, bit
stuffing/de-stuffing, CRC, arbitration, acceptance filtering, error counters,
interrupts, normal mode, and internal loopback. The register layout follows
the Xilinx DS791-style offsets used by `sw/can_controller.h`.

## Top-Level Interface

| Port | Width | Description |
| --- | ---: | --- |
| `s_apb_pclk` | 1 | APB clock. |
| `s_apb_presetn` | 1 | Active-low APB reset; deassertion is synchronized internally. |
| `can_clk` | 1 | CAN engine clock. |
| `can_resetn` | 1 | Active-low CAN reset; deassertion is synchronized internally. |
| `s_apb_paddr` | 12 | APB byte address. |
| `s_apb_psel`, `s_apb_penable`, `s_apb_pwrite` | 1 each | APB transfer controls. |
| `s_apb_pwdata` | 32 | APB write data. |
| `s_apb_pstrb` | 4 | APB byte strobes. |
| `s_apb_pprot` | 3 | APB protection attributes; accepted but not interpreted. |
| `s_apb_prdata` | 32 | APB read data. |
| `s_apb_pready` | 1 | Asserted during a selected access phase; no wait states. |
| `s_apb_pslverr` | 1 | Invalid or illegal register access indication. |
| `can_rx` | 1 | Asynchronous serial input from the transceiver. |
| `can_tx` | 1 | Serial output to the transceiver. |
| `can_irq` | 1 | Interrupt request, equal to `ISR & IER` reduction. |

## Register Map

All addresses are byte offsets from the controller base address. All accesses
are 32-bit. Invalid accesses and writes to read-only registers produce an APB
error. The CSV below is machine-readable.

```csv
offset,name,access,reset,description
0x000,SRR,RW,0x00000000,"SRST bit 0 is software reset; CEN bit 1 enables CAN"
0x004,MSR,RW,0x00000000,"SLEEP bit 0 and LBACK bit 1; writable only while CEN=0"
0x008,BRPR,RW,0x00000000,"BRP[7:0]; TQ period is (BRP+1) can_clk cycles"
0x00C,BTR,RW,0x00000145,"TSEG1[3:0], TSEG2[6:4], SJW[8:7], encoded as actual TQ count minus one"
0x010,ECR,RO,0x00000000,"REC[15:8] and TEC[7:0]"
0x014,ESR,RW1C,0x00000000,"ACKER[31], BERR[30], STER[29], FMER[28], CRCER[27]"
0x018,SR,RO,0x00000000,"Mode, bus, error-state, FIFO, and acceptance-filter status"
0x01C,ISR,RO,0x00000000,"Interrupt status latches"
0x020,IER,RW,0x00000000,"Interrupt enable mask"
0x024,ICR,W1C,0x00000000,"Write one to clear corresponding ISR bits"
0x030,TX_ID,WO,0x00000000,"ID[31:21], IDE[19], extended ID[18:1], RTR[0]"
0x034,TX_DLC,WO,0x00000000,"TX DLC, normally in [31:28]"
0x038,TX_DW1,WO,0x00000000,"TX data bytes 0-3"
0x03C,TX_DW2,WO,0x00000000,"TX data bytes 4-7; write triggers TX FIFO push"
0x040,TXHPB_ID,WO,0x00000000,"TX high-priority-buffer identifier/control"
0x044,TXHPB_DLC,WO,0x00000000,"TX high-priority-buffer DLC"
0x048,TXHPB_DW1,WO,0x00000000,"TX high-priority-buffer data bytes 0-3"
0x04C,TXHPB_DW2,WO,0x00000000,"TX high-priority-buffer data bytes 4-7; requests HPB push"
0x050,RX_ID,RO,0x00000000,"RX identifier/control at FIFO head"
0x054,RX_DLC,RO,0x00000000,"RX DLC in [31:28]"
0x058,RX_DW1,RO,0x00000000,"RX data bytes 0-3"
0x05C,RX_DW2,RO,0x00000000,"RX data bytes 4-7; read triggers RX FIFO pop"
0x060,AFR,RW,0x00000000,"UAF[3:0] enables filters; all zero accepts every frame"
0x064,AFMR1,RW,0x00000000,"Acceptance filter 1 mask"
0x068,AFIR1,RW,0x00000000,"Acceptance filter 1 identifier"
0x06C,AFMR2,RW,0x00000000,"Acceptance filter 2 mask"
0x070,AFIR2,RW,0x00000000,"Acceptance filter 2 identifier"
0x074,AFMR3,RW,0x00000000,"Acceptance filter 3 mask"
0x078,AFIR3,RW,0x00000000,"Acceptance filter 3 identifier"
0x07C,AFMR4,RW,0x00000000,"Acceptance filter 4 mask"
0x080,AFIR4,RW,0x00000000,"Acceptance filter 4 identifier"
```

Standard IDs use `IDR[31:21]`; extended IDs use `IDR[31:21]` for bits
28:18, `IDR[19]=IDE`, and `IDR[18:1]` for bits 17:0. Data words use DS791
big-endian byte presentation. Configure timing while `CEN=0`. ISR event bits
are 31:20 in DS791 positions; the RTL also mirrors events in bits 0:11.

## RTL Files and Compile Order

The Makefile discovers and sorts `src/**/*.v`; the following explicit order is
also suitable for deterministic compilation:

1. `src/synchronizers/reset_synchronizer.v`
2. `src/synchronizers/two_ff_synchronizer.v`
3. `src/synchronizers/pulse_synchronizer.v`
4. `src/fifo/can_fifo.v`
5. `src/apb_interface/apb_interface.v`
6. `src/can_reg_file/can_reg_file.v`
7. `src/bit_timing_engine/can_baud_gen.v`
8. `src/bit_timing_engine/can_bit_timing_logic.v`
9. `src/bit_timing_engine/can_btl_top.v`
10. `src/tx_path/tx_fifo.v`
11. `src/tx_path/bit_stuff.v`
12. `src/tx_path/crc_gen.v`
13. `src/tx_path/can_bsp.v`
14. `src/tx_path/can_tx_path_core.v`
15. `src/tx_path/tx_path_top.v`
16. `src/rx_path/rx_fifo.v`
17. `src/rx_path/bit_destuff.v`
18. `src/rx_path/crc_check.v`
19. `src/rx_path/acceptance_filter.v`
20. `src/rx_path/rx_path_top.v`
21. `src/error_management/error_management_logic.v`
22. `src/can_channel/can_channel_core.v`
23. `src/top/can_top.v`

No RTL define is required. The default Makefile uses Icarus Verilog with
`-g2012 -Wall -Wimplicit -Wportbind -Wselect-range` and adds
`-D VCD_FILE=...` for testbench waveform output. `SIM`, `VVP`, `TOP`, `TB`,
`RTL_SRCS`, `EXTRA_SRCS`, and `BUILD_DIR` are overrideable.

## Parameters

| Module | Parameter | Default | Legal range / constraint | Effect of changing |
| --- | --- | ---: | --- | --- |
| `apb_interface` | `ADDR_WIDTH` | 32 | Positive; top-level use is 12 | APB and decoded address width. |
| `apb_interface` | `DATA_WIDTH` | 32 | Positive, normally multiple of 8 | APB data width; current register wiring is 32-bit. |
| `apb_interface` | `STRB_WIDTH` | `DATA_WIDTH/8` | Positive; normally `DATA_WIDTH/8` | Byte-strobe width. |
| `can_channel_core` | `TX_FIFO_DEPTH` | 4 | Power of two, practical minimum 2 | TX frame capacity and pointer width. |
| `can_channel_core` | `RX_FIFO_DEPTH` | 4 | Power of two, practical minimum 2 | RX frame capacity and pointer width. |
| `can_reg_file` | `ADDR_WIDTH` | 12 | Positive; at least 12 for this map | Register address width. |
| `can_reg_file` | `DATA_WIDTH` | 32 | 32 for current ports | Register data width. |
| `can_fifo` | `DATA_WIDTH` | 128 | Positive; wrappers assume 128 | FIFO payload width. |
| `can_fifo` | `ADDR_WIDTH` | 4 | Integer >= 2; depth is `2**ADDR_WIDTH` | FIFO storage depth and Gray pointer width. |
| `rx_fifo` | `ADDR_WIDTH` | 4 | Integer >= 2 | RX FIFO depth; payload remains 128 bits. |
| `rx_path_top` | `FIFO_ADDR_WIDTH` | 4 | Integer >= 2 | RX FIFO pointer/depth selection. |
| `tx_fifo` | `ADDR_WIDTH` | 4 | Integer >= 2 | TX FIFO depth; payload remains 128 bits. |
| `tx_path_top` | `FIFO_ADDR_WIDTH` | 4 | Integer >= 2 | TX FIFO pointer/depth selection. |
| `can_tx_path_core` | `FIFO_ADDR_WIDTH` | 2 | Integer >= 2 | Composed TX FIFO pointer/depth; top passes 2. |
| `two_ff_synchronizer` | `WIDTH` | 1 | Positive integer | Number of synchronized bits. |
| `two_ff_synchronizer` | `INIT_VALUE` | all ones | Exactly `WIDTH` bits | Reset value of both synchronizer stages. |

The top-level fixes both channel FIFO depths at four. Timing fields are not
parameters: BRP is 0-255, TSEG1 is 0-15 (1-16 TQ), TSEG2 is 0-7 (1-8 TQ), and
SJW is 0-3 (1-4 TQ). SJW is clamped to the configured phase segments.

## Clock and Reset Requirements

The RTL does not enforce a clock frequency range or APB-to-CAN frequency
ratio. The domains are intentionally asynchronous; any positive frequencies
are structurally supported subject to FIFO throughput, pulse event rate, CAN
timing, and implementation timing closure. The checked-in collateral uses
100 MHz APB and representative 20 MHz CAN values. The XDC expects the actual
`can_clk` constraint to come from the Clocking Wizard.

```text
TQ = (BRP + 1) / f_can_clk
bit time = (1 + (TSEG1 + 1) + (TSEG2 + 1)) * TQ
```

Both clocks must be free-running during operation and APB access. `can_rx` is
asynchronous to `can_clk` and is synchronized inside the bit-timing block.

Reset sequencing:

1. Assert `s_apb_presetn` and `can_resetn` low while both clocks are running.
2. Release reset only with the clocks running; each domain uses asynchronous
   assertion and two-flop synchronous deassertion.
3. Program BRPR, BTR, mode, and filters while `CEN=0` and `SR[31]` reports
   configuration mode.
4. `SRR[0]` generates a software-reset pulse transferred APB-to-CAN through a
   toggle pulse synchronizer.
5. Set `SRR[1]` only after configuration is stable. Timing writes while CEN is
   set are rejected with `pslverr`.

## CDC Inventory

| Crossing | Direction | Synchronizing structure |
| --- | --- | --- |
| `s_apb_presetn` | external -> APB | `reset_synchronizer`; async assert, sync deassert |
| `can_resetn` | external -> CAN | `reset_synchronizer`; async assert, sync deassert |
| `SRR[0]` software reset | APB -> CAN | `pulse_synchronizer` toggle plus two destination flops |
| TX FIFO payload/pointers | APB -> CAN | Dual-clock `can_fifo`; Gray write pointer through `two_ff_synchronizer` |
| TX FIFO read pointer | CAN -> APB | Gray pointer through `two_ff_synchronizer` |
| RX FIFO payload/pointers | CAN -> APB | Dual-clock `can_fifo`; Gray pointers through `two_ff_synchronizer` |
| TX success/error/arbitration-lost | CAN -> APB | `pulse_synchronizer` per event |
| RX success/overflow | CAN -> APB | `pulse_synchronizer` per event |
| ACKER/BERR/STER/FMER/CRCER | CAN -> APB | `pulse_synchronizer` per event |
| Busy, bus idle, bus off, error warning, RX full | CAN -> APB | One-bit `two_ff_synchronizer` per status |
| ESTAT | CAN -> APB | 2-bit `two_ff_synchronizer` |
| TEC and REC | CAN -> APB | 8-bit `two_ff_synchronizer` each; not atomic snapshots |
| `can_rx` | transceiver -> CAN | Two-flop synchronizer in `can_btl_top` |
| Timing/mode configuration | APB -> CAN | Quasi-static direct signals; written only in config mode |

Synchronizer flops carry `ASYNC_REG` attributes. `cons/can_top.xdc` and
`cons/can_top.sgdc` describe first-stage false paths and Gray-pointer CDC
paths. Pulse synchronizers do not queue multiple events; source event rate
must be low enough that destination observations cannot collapse.

## Build and Simulation

```sh
make
make compile
make run
make TOP=tb_can_regfile TB=sim/can_reg_file/tb_can_regfile.v
make wave
make clean
```

Testbenches are under `sim/`; generated VVP/VCD files are under `build/`.

## Known Limitations and Deliberately Unimplemented Features

- Only one channel is instantiated in `can_top`; dual-channel support is an
  expansion point, not a current feature.
- The TX HPB registers and push pulse exist, but no independent HPB storage or
  priority path is connected; `tx_hpb_full` is tied low.
- Sleep entry, wakeup detection, and their interrupts are tied inactive in the
  current integration.
- `acfb_busy` is tied inactive; acceptance filtering is combinational.
- APB has no wait states and TX writes have no backpressure response beyond
  status reporting.
- TEC/REC/ESTAT crossings are level sampled and may be transiently skewed.
- FIFO memory is a register array; target-specific RAM inference/collision
  behavior is not guaranteed.
- CAN-FD, bit-rate switching, payloads above eight bytes, timestamps, DMA,
  and bus monitoring are intentionally not implemented.
- Timing collateral contains representative clock assumptions; integrators
  must provide actual board and Clocking Wizard constraints.

## Suggested Verification Focus Areas

1. **Bit timing:** sweep BRP/TSEG1/TSEG2/SJW extremes, sample-point placement,
   hard synchronization, late TSEG1 edges, early TSEG2 edges, and long
   dominant runs. Check that one edge cannot cause repeated resynchronization.
2. **Arbitration and errors:** collide transmitters, verify dominant-over-
   recessive arbitration and retransmission, then inject ACK, bit, stuff, form,
   and CRC errors. Check TEC/REC, error-passive, and the internal 256 bus-off
   threshold.
3. **Frame boundaries:** exhaustively exercise standard/extended IDs, RTR,
   DLC 0/8, all payload patterns, stuffing boundaries, CRC, EOF, and malformed
   frames.
4. **FIFO CDC:** vary unrelated clock frequency and phase, fill/drain at the
   same time, reset one side, test full/empty edges, and prove no duplicate or
   lost frame at pointer wrap.
5. **APB semantics:** test setup/access phases, byte strobes, invalid offsets,
   read-only writes, timing writes while enabled, W1C races, TX push ordering,
   and RX pop exactly on `RX_DW2` reads.
6. **Event delivery:** generate back-to-back TX/RX/error events and verify
   pulse delivery, ISR latching, masking, clearing, and no spurious repeats.
7. **Reset:** assert/release either reset independently, vary clock start order,
   reset during traffic, and check no stale FIFO pointer, toggle, status, or
   CAN output survives.
8. **Loopback and CDC sign-off:** verify loopback keeps `can_tx` recessive,
   normal mode uses the physical input, and XDC/SGDC synchronizer selectors
   still match after hierarchy changes.

## Repository Layout

| Directory | Contents |
| --- | --- |
| `src/` | Synthesizable RTL. |
| `sim/` | Unit, subsystem, and integration testbenches. |
| `cons/` | Vivado XDC, SpyGlass SGDC, and CDC wrappers. |
| `sw/` | C register definitions and access helpers. |
| `build/` | Generated simulation outputs and waveforms. |
| `Makefile` | Icarus/VVP build and simulation entry points. |