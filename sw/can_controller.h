/**
 * @file can_controller.h
 * @brief APB CAN 2.0B Controller Register Map - Xilinx DS791 Compatible
 *
 * This header provides register offsets and bit-field masks that are
 * IDENTICAL to the Xilinx AXI CAN IP (DS791) driver interface.
 * The same C code used with xcan.h / xcanps.h will work with this
 * CAN controller by substituting the base address only.
 *
 * Reference: Xilinx DS791 (AXI CAN Product Guide), PG021
 *
 * Clock domains:
 *   APB bus clock  (s_apb_pclk):  Nominally 100 MHz from Zynq PS FCLK0
 *   CAN core clock (can_clk):     Configurable (e.g. 24 MHz for 500kbps)
 *
 * Typical setup for 500 kbps @ 24 MHz can_clk:
 *   BRPR = 0  (prescaler, TQ period = 1 can_clk cycle = 41.67ns)
 *   BTR  = 0x00000155 -> TSEG1=5+1=6 TQ, TSEG2=5+1=6 TQ, SJW=1+1=2 TQ
 *   Total bit time = 1 (SYNC) + 6 (TSEG1) + 6 (TSEG2) = 13 TQ = ~541 ns
 *   (Nominal; adjust TSEG1/TSEG2 to achieve exactly 500 kbps)
 *
 * (C) 2024 - ISC License - No Warranty
 */

#ifndef CAN_CONTROLLER_H
#define CAN_CONTROLLER_H

#include <stdint.h>

/* =========================================================================
 * Register Offsets (word-aligned, APB byte address from base)
 * Identical to Xilinx AXI CAN DS791 Table 6
 * ========================================================================= */
#define XCAN_SRR_OFFSET     0x000U  /**< Software Reset Register         */
#define XCAN_MSR_OFFSET     0x004U  /**< Mode Select Register            */
#define XCAN_BRPR_OFFSET    0x008U  /**< Baud Rate Prescaler Register    */
#define XCAN_BTR_OFFSET     0x00CU  /**< Bit Timing Register             */
#define XCAN_ECR_OFFSET     0x010U  /**< Error Counter Register (RO)     */
#define XCAN_ESR_OFFSET     0x014U  /**< Error Status Register (W1C)     */
#define XCAN_SR_OFFSET      0x018U  /**< Status Register (RO)            */
#define XCAN_ISR_OFFSET     0x01CU  /**< Interrupt Status Register (RO)  */
#define XCAN_IER_OFFSET     0x020U  /**< Interrupt Enable Register       */
#define XCAN_ICR_OFFSET     0x024U  /**< Interrupt Clear Register (W1C)  */
/* 0x028–0x02F reserved */
#define XCAN_TXFIFO_ID_OFFSET   0x030U  /**< TX FIFO Frame Identifier    */
#define XCAN_TXFIFO_DLC_OFFSET  0x034U  /**< TX FIFO Frame DLC           */
#define XCAN_TXFIFO_DW1_OFFSET  0x038U  /**< TX FIFO Data Word 1         */
#define XCAN_TXFIFO_DW2_OFFSET  0x03CU  /**< TX FIFO Data Word 2 (push)  */
#define XCAN_TXHPB_ID_OFFSET    0x040U  /**< TX HPB Frame Identifier     */
#define XCAN_TXHPB_DLC_OFFSET   0x044U  /**< TX HPB Frame DLC            */
#define XCAN_TXHPB_DW1_OFFSET   0x048U  /**< TX HPB Data Word 1          */
#define XCAN_TXHPB_DW2_OFFSET   0x04CU  /**< TX HPB Data Word 2 (push)   */
#define XCAN_RXFIFO_ID_OFFSET   0x050U  /**< RX FIFO Frame Identifier    */
#define XCAN_RXFIFO_DLC_OFFSET  0x054U  /**< RX FIFO Frame DLC           */
#define XCAN_RXFIFO_DW1_OFFSET  0x058U  /**< RX FIFO Data Word 1         */
#define XCAN_RXFIFO_DW2_OFFSET  0x05CU  /**< RX FIFO Data Word 2 (pop)   */
#define XCAN_AFR_OFFSET     0x060U  /**< Acceptance Filter Register      */
#define XCAN_AFMR1_OFFSET   0x064U  /**< AF Mask Register 1              */
#define XCAN_AFIR1_OFFSET   0x068U  /**< AF ID Register 1                */
#define XCAN_AFMR2_OFFSET   0x06CU  /**< AF Mask Register 2              */
#define XCAN_AFIR2_OFFSET   0x070U  /**< AF ID Register 2                */
#define XCAN_AFMR3_OFFSET   0x074U  /**< AF Mask Register 3              */
#define XCAN_AFIR3_OFFSET   0x078U  /**< AF ID Register 3                */
#define XCAN_AFMR4_OFFSET   0x07CU  /**< AF Mask Register 4              */
#define XCAN_AFIR4_OFFSET   0x080U  /**< AF ID Register 4                */

/* =========================================================================
 * SRR — Software Reset Register (0x000)
 * ========================================================================= */
#define XCAN_SRR_SRST_MASK   0x00000001U  /**< [0] Software Reset (self-clr)   */
#define XCAN_SRR_CEN_MASK    0x00000002U  /**< [1] CAN Enable                  */

/* =========================================================================
 * MSR — Mode Select Register (0x004)
 * ========================================================================= */
#define XCAN_MSR_SLEEP_MASK  0x00000001U  /**< [0] Sleep Mode                  */
#define XCAN_MSR_LBACK_MASK  0x00000002U  /**< [1] Loopback Mode               */

/* =========================================================================
 * BRPR — Baud Rate Prescaler Register (0x008)
 * BRP value = prescaler – 1. TQ period = (BRP+1) / can_clk.
 * ========================================================================= */
#define XCAN_BRPR_BRP_MASK   0x000000FFU  /**< [7:0] Baud Rate Prescaler       */

/* =========================================================================
 * BTR — Bit Timing Register (0x00C)
 * ========================================================================= */
#define XCAN_BTR_TSEG1_MASK  0x0000000FU  /**< [3:0]  Time Segment 1 (val+1)   */
#define XCAN_BTR_TSEG2_MASK  0x00000070U  /**< [6:4]  Time Segment 2 (val+1)   */
#define XCAN_BTR_TSEG2_SHIFT 4U
#define XCAN_BTR_SJW_MASK    0x00000180U  /**< [8:7]  SJW (val+1)              */
#define XCAN_BTR_SJW_SHIFT   7U

/* =========================================================================
 * ECR — Error Counter Register (0x010, Read-Only)
 * ========================================================================= */
#define XCAN_ECR_TEC_MASK    0x000000FFU  /**< [7:0]  TX Error Counter         */
#define XCAN_ECR_REC_MASK    0x0000FF00U  /**< [15:8] RX Error Counter         */
#define XCAN_ECR_REC_SHIFT   8U

/* =========================================================================
 * ESR — Error Status Register (0x014, Write-1-to-Clear)
 * ========================================================================= */
#define XCAN_ESR_ACKER_MASK  0x80000000U  /**< [31] ACK Error                  */
#define XCAN_ESR_BERR_MASK   0x40000000U  /**< [30] Bit Error                  */
#define XCAN_ESR_STER_MASK   0x20000000U  /**< [29] Stuff Error                */
#define XCAN_ESR_FMER_MASK   0x10000000U  /**< [28] Form Error                 */
#define XCAN_ESR_CRCER_MASK  0x08000000U  /**< [27] CRC Error                  */

/* =========================================================================
 * SR — Status Register (0x018, Read-Only)
 * ========================================================================= */
#define XCAN_SR_CONFIG_MASK  0x80000000U  /**< [31] Configuration Mode         */
#define XCAN_SR_LBACK_MASK   0x40000000U  /**< [30] Loopback Mode Active       */
#define XCAN_SR_SLEEP_MASK   0x20000000U  /**< [29] Sleep Mode Active          */
#define XCAN_SR_NORMAL_MASK  0x10000000U  /**< [28] Normal Mode Active         */
#define XCAN_SR_BIDLE_MASK   0x08000000U  /**< [27] Bus Idle                   */
#define XCAN_SR_BBSY_MASK    0x04000000U  /**< [26] Bus Busy                   */
#define XCAN_SR_ERRWRN_MASK  0x02000000U  /**< [25] Error Warning              */
#define XCAN_SR_ESTAT_MASK   0x01800000U  /**< [24:23] Error State             */
#define XCAN_SR_ESTAT_SHIFT  23U
#define XCAN_SR_ESTAT_ACTIVE    0x0U      /**< Error Active                    */
#define XCAN_SR_ESTAT_PASSIVE   0x1U      /**< Error Passive                   */
#define XCAN_SR_ESTAT_BUSOFF    0x2U      /**< Bus Off                         */
#define XCAN_SR_TXBFLL_MASK  0x00400000U  /**< [22] TX HPB FIFO Full           */
#define XCAN_SR_TXFLL_MASK   0x00200000U  /**< [21] TX FIFO Full               */
#define XCAN_SR_ACFBSY_MASK  0x00100000U  /**< [20] Acceptance Filter Busy     */

/* =========================================================================
 * ISR — Interrupt Status Register (0x01C, Read-Only)
 * IER — Interrupt Enable Register  (0x020, Read/Write)
 * ICR — Interrupt Clear Register   (0x024, Write-1-to-Clear)
 * All three registers share these bit positions.
 * ========================================================================= */
#define XCAN_IXR_ARBLST_MASK 0x80000000U  /**< [31] Arbitration Lost           */
#define XCAN_IXR_TXOK_MASK   0x40000000U  /**< [30] TX Successful              */
#define XCAN_IXR_TXFLL_MASK  0x20000000U  /**< [29] TX FIFO Full               */
#define XCAN_IXR_TXBFLL_MASK 0x10000000U  /**< [28] TX HPB FIFO Full           */
#define XCAN_IXR_RXOK_MASK   0x08000000U  /**< [27] RX Frame Received          */
#define XCAN_IXR_RXUFLW_MASK 0x04000000U  /**< [26] RX FIFO Underflow          */
#define XCAN_IXR_RXOFLW_MASK 0x02000000U  /**< [25] RX FIFO Overflow           */
#define XCAN_IXR_RXNEMP_MASK 0x01000000U  /**< [24] RX FIFO Not Empty          */
#define XCAN_IXR_ERROR_MASK  0x00800000U  /**< [23] Error Interrupt            */
#define XCAN_IXR_BSOFF_MASK  0x00400000U  /**< [22] Bus Off                    */
#define XCAN_IXR_SLP_MASK    0x00200000U  /**< [21] Sleep Mode Entered         */
#define XCAN_IXR_WKUP_MASK   0x00100000U  /**< [20] Wake Up                    */
/** Mask of all interrupts supported */
#define XCAN_IXR_ALL_MASK    (XCAN_IXR_ARBLST_MASK | XCAN_IXR_TXOK_MASK    | \
                              XCAN_IXR_TXFLL_MASK  | XCAN_IXR_TXBFLL_MASK  | \
                              XCAN_IXR_RXOK_MASK   | XCAN_IXR_RXUFLW_MASK  | \
                              XCAN_IXR_RXOFLW_MASK | XCAN_IXR_RXNEMP_MASK  | \
                              XCAN_IXR_ERROR_MASK  | XCAN_IXR_BSOFF_MASK   | \
                              XCAN_IXR_SLP_MASK    | XCAN_IXR_WKUP_MASK)

/* =========================================================================
 * TX / RX Frame Format (Xilinx DS791 Frame Descriptor)
 *
 * IDR (Identifier Register):
 *   Standard frame: [31:21]=ID[10:0], [20]=SRR=0, [19]=IDE=0, [18:1]=0, [0]=RTR
 *   Extended frame: [31:21]=ID[28:18], [20]=SRR=1, [19]=IDE=1, [18:1]=ID[17:0], [0]=RTR
 *
 * DLCR (Data Length Code Register):
 *   [31:28] = DLC (0–8)
 *
 * DW1R / DW2R (Data Word Registers):
 *   Big-endian byte order: DW1R[31:24]=Byte0, DW1R[23:16]=Byte1, ...
 * ========================================================================= */
#define XCAN_IDR_ID1_MASK       0xFFE00000U  /**< [31:21] Base ID              */
#define XCAN_IDR_ID1_SHIFT      21U
#define XCAN_IDR_SRR_MASK       0x00100000U  /**< [20] SRR (EFF frames)        */
#define XCAN_IDR_IDE_MASK       0x00080000U  /**< [19] IDE=1 for Extended      */
#define XCAN_IDR_ID2_MASK       0x0007FFFEU  /**< [18:1] Extended ID[17:0]     */
#define XCAN_IDR_ID2_SHIFT      1U
#define XCAN_IDR_RTR_MASK       0x00000001U  /**< [0] Remote Transmission Req  */

#define XCAN_DLCR_DLC_MASK      0xF0000000U  /**< [31:28] Data Length Code     */
#define XCAN_DLCR_DLC_SHIFT     28U

/** Build Standard-Frame IDR word */
#define XCAN_SFF_ID(id, rtr)    (((uint32_t)(id) << XCAN_IDR_ID1_SHIFT) | \
                                  ((rtr) ? XCAN_IDR_RTR_MASK : 0U))
/** Build Extended-Frame IDR word */
#define XCAN_EFF_ID(id, rtr)    (((uint32_t)((id) >> 18U) << XCAN_IDR_ID1_SHIFT) | \
                                  XCAN_IDR_SRR_MASK | XCAN_IDR_IDE_MASK |         \
                                  (((id) & 0x3FFFFU) << XCAN_IDR_ID2_SHIFT) |     \
                                  ((rtr) ? XCAN_IDR_RTR_MASK : 0U))
/** Build DLCR word */
#define XCAN_DLCR(dlc)          ((uint32_t)(dlc) << XCAN_DLCR_DLC_SHIFT)

/* =========================================================================
 * AFR — Acceptance Filter Register (0x060)
 * ========================================================================= */
#define XCAN_AFR_UAF1_MASK      0x00000001U  /**< [0] Enable Filter 1          */
#define XCAN_AFR_UAF2_MASK      0x00000002U  /**< [1] Enable Filter 2          */
#define XCAN_AFR_UAF3_MASK      0x00000004U  /**< [2] Enable Filter 3          */
#define XCAN_AFR_UAF4_MASK      0x00000008U  /**< [3] Enable Filter 4          */

/* =========================================================================
 * Register Access Helpers
 * ========================================================================= */
/** @brief Write a 32-bit APB register */
static inline void xcan_write(uintptr_t base, uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(base + offset) = value;
}

/** @brief Read a 32-bit APB register */
static inline uint32_t xcan_read(uintptr_t base, uint32_t offset)
{
    return *(volatile uint32_t *)(base + offset);
}

/* =========================================================================
 * Driver Mode Helpers  (API compatible with Xilinx xcan.h)
 * ========================================================================= */

/** @brief Enter Configuration mode (disable CAN, required before timing regs) */
static inline void xcan_enter_config_mode(uintptr_t base)
{
    /* Assert software reset — clears CEN and returns to config mode */
    xcan_write(base, XCAN_SRR_OFFSET, XCAN_SRR_SRST_MASK);
}

/** @brief Enter Normal (operational) mode */
static inline void xcan_enter_normal_mode(uintptr_t base)
{
    xcan_write(base, XCAN_MSR_OFFSET, 0U);          /* Normal, not loopback, not sleep */
    xcan_write(base, XCAN_SRR_OFFSET, XCAN_SRR_CEN_MASK);
}

/** @brief Enter Loopback mode */
static inline void xcan_enter_loopback_mode(uintptr_t base)
{
    xcan_write(base, XCAN_MSR_OFFSET, XCAN_MSR_LBACK_MASK);
    xcan_write(base, XCAN_SRR_OFFSET, XCAN_SRR_CEN_MASK);
}

/**
 * @brief Configure CAN bit timing
 * @param base  APB base address of the CAN controller
 * @param brp   Baud rate prescaler value (0-255, actual div = brp+1)
 * @param tseg1 Time segment 1 value (0-15, actual TQs = tseg1+1)
 * @param tseg2 Time segment 2 value (0-7, actual TQs = tseg2+1)
 * @param sjw   Synchronisation jump width value (0-3, actual TQs = sjw+1)
 *
 * Must be called in configuration mode (CEN=0).
 */
static inline void xcan_set_baud_rate_prescaler(uintptr_t base, uint8_t brp)
{
    xcan_write(base, XCAN_BRPR_OFFSET, (uint32_t)brp & XCAN_BRPR_BRP_MASK);
}

static inline void xcan_set_bit_timing(uintptr_t base,
                                       uint8_t tseg1, uint8_t tseg2, uint8_t sjw)
{
    uint32_t btr = ((uint32_t)(tseg1)  & 0x0FU) |
                   (((uint32_t)(tseg2) & 0x07U) << XCAN_BTR_TSEG2_SHIFT) |
                   (((uint32_t)(sjw)   & 0x03U) << XCAN_BTR_SJW_SHIFT);
    xcan_write(base, XCAN_BTR_OFFSET, btr);
}

/**
 * @brief Transmit a CAN standard frame (blocking: waits for TX FIFO space)
 * @param base     APB base address
 * @param id11     11-bit standard ID
 * @param rtr      1 = remote frame, 0 = data frame
 * @param dlc      Data length code (0-8)
 * @param data     Pointer to up to 8 data bytes (big-endian, byte[0] = MSB)
 */
static inline void xcan_send_standard(uintptr_t base, uint16_t id11, int rtr,
                                      uint8_t dlc, const uint8_t *data)
{
    /* Spin until TX FIFO has space */
    while (xcan_read(base, XCAN_SR_OFFSET) & XCAN_SR_TXFLL_MASK) {}

    xcan_write(base, XCAN_TXFIFO_ID_OFFSET,  XCAN_SFF_ID(id11, rtr));
    xcan_write(base, XCAN_TXFIFO_DLC_OFFSET, XCAN_DLCR(dlc));

    uint32_t dw1 = 0U, dw2 = 0U;
    if (data && dlc > 0U) {
        dw1 = ((uint32_t)data[0] << 24) | ((dlc > 1U) ? (uint32_t)data[1] << 16 : 0U) |
              ((dlc > 2U) ? (uint32_t)data[2] << 8  : 0U) |
              ((dlc > 3U) ? (uint32_t)data[3]        : 0U);
    }
    if (data && dlc > 4U) {
        dw2 = ((uint32_t)data[4] << 24) | ((dlc > 5U) ? (uint32_t)data[5] << 16 : 0U) |
              ((dlc > 6U) ? (uint32_t)data[6] << 8  : 0U) |
              ((dlc > 7U) ? (uint32_t)data[7]        : 0U);
    }
    xcan_write(base, XCAN_TXFIFO_DW1_OFFSET, dw1);
    xcan_write(base, XCAN_TXFIFO_DW2_OFFSET, dw2); /* Writing DW2 pushes the frame */
}

/**
 * @brief Receive a CAN frame from the RX FIFO (non-blocking).
 * @param base     APB base address
 * @param idr      Output: raw IDR word (use XCAN_IDR_* macros to decode)
 * @param dlcr     Output: raw DLCR word
 * @param dw1      Output: raw data word 1
 * @param dw2      Output: raw data word 2 (reading DW2 pops the FIFO)
 * @return         1 if a frame was read, 0 if RX FIFO empty
 */
static inline int xcan_recv(uintptr_t base,
                             uint32_t *idr, uint32_t *dlcr,
                             uint32_t *dw1, uint32_t *dw2)
{
    if (xcan_read(base, XCAN_SR_OFFSET) & XCAN_SR_BIDLE_MASK) {
        /* Bus idle — no frame available (check RXNEMP instead) */
    }
    if (!(xcan_read(base, XCAN_ISR_OFFSET) & XCAN_IXR_RXNEMP_MASK))
        return 0;

    *idr  = xcan_read(base, XCAN_RXFIFO_ID_OFFSET);
    *dlcr = xcan_read(base, XCAN_RXFIFO_DLC_OFFSET);
    *dw1  = xcan_read(base, XCAN_RXFIFO_DW1_OFFSET);
    *dw2  = xcan_read(base, XCAN_RXFIFO_DW2_OFFSET); /* Pop */

    /* Clear RXNEMP / RXOK interrupts */
    xcan_write(base, XCAN_ICR_OFFSET,
               XCAN_IXR_RXNEMP_MASK | XCAN_IXR_RXOK_MASK);
    return 1;
}

#endif /* CAN_CONTROLLER_H */
