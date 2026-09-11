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

    output  reg [DATA_WIDTH-1:0]   prdata,
    output  reg                    pready,
    output  reg                    pslverr,

    // Decoded Register Interface Outputs to can_reg_file
    output  reg [ADDR_WIDTH-1:0]  reg_addr,
    output  reg                   reg_wr_en,
    output  reg                   reg_rd_en,
    output  reg [DATA_WIDTH-1:0]  reg_wdata,
    output  reg [STRB_WIDTH-1:0]  reg_wstrb,
    input   wire [DATA_WIDTH-1:0] reg_rdata,
    input   wire                  reg_err
);

    // The register bank is on this clock, so every valid APB access completes
    // in its access phase without a wait state.
    always @(*) begin
        pready    = 1'b0;
        pslverr   = 1'b0;
        prdata    = {DATA_WIDTH{1'b0}};
        reg_addr  = (psel && penable) ? paddr : {ADDR_WIDTH{1'b0}};
        reg_wr_en = 1'b0;
        reg_rd_en = 1'b0;
        reg_wdata = pwdata;
        reg_wstrb = pstrb;

        if (psel && penable) begin
            pready = 1'b1;
            pslverr = reg_err;
            if (pwrite) begin
                reg_wr_en = 1'b1;
            end else begin
                reg_rd_en = 1'b1;
                prdata = reg_rdata;
            end
        end
    end

endmodule