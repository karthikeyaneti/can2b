`timescale 1ns/1ps

module apb_interface #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = DATA_WIDTH / 8
) (
    input   wire                    pclk,
    input   wire                    presetn,

    // APB interface
    input   wire                    psel,
    input   wire [ADDR_WIDTH-1:0]   paddr,
    input   wire [DATA_WIDTH-1:0]   pwdata,
    input   wire                    pwrite,
    input   wire                    penable,

    // APB4 Signals
    input   wire [STRB_WIDTH-1:0]   pstrb,
    input   wire [2:0]              pprot,

    output  wire [DATA_WIDTH-1:0]  prdata,
    output  wire                   pready,
    output  wire                   pslverr,

    // Decoded Register Interface Outputs to can_reg_file
    output  wire [ADDR_WIDTH-1:0] reg_addr,
    output  wire                  reg_wr_en,
    output  wire                  reg_rd_en,
    output  wire [DATA_WIDTH-1:0] reg_wdata,
    output  wire [STRB_WIDTH-1:0] reg_wstrb,
    input   wire [DATA_WIDTH-1:0] reg_rdata,
    input   wire                  reg_err
);

    // The register bank is on this clock, so every valid APB access completes
    // in its access phase without a wait state.
    assign pready    = psel && penable;
    assign pslverr   = (psel && penable) ? reg_err : 1'b0;
    assign prdata    = (psel && penable && !pwrite) ? reg_rdata : {DATA_WIDTH{1'b0}};
    assign reg_addr  = (psel && penable) ? paddr : {ADDR_WIDTH{1'b0}};
    assign reg_wr_en = psel && penable && pwrite;
    assign reg_rd_en = psel && penable && !pwrite;
    assign reg_wdata = pwdata;
    assign reg_wstrb = pstrb;

endmodule