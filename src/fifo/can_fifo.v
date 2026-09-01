`timescale 1ns / 1ps

module can_fifo #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 4
) (
    input wire wr_clk,
    input wire rd_clk,
    input wire wr_rst_n_sync,
    input wire rd_rst_n_sync,
    input wire wr_en,
    input wire rd_en,
    input wire [DATA_WIDTH-1:0] wr_data,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire empty,
    output wire full
);

    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;

    // FIFO Memory Array
    reg [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];

    // Pointers and Gray-code registers
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;
    reg [ADDR_WIDTH:0] wr_ptr_gray;
    reg [ADDR_WIDTH:0] rd_ptr_gray;

    wire [ADDR_WIDTH:0] wr_ptr_gray_sync;
    wire [ADDR_WIDTH:0] rd_ptr_gray_sync;


    // Multi-flop synchronizers for Gray pointers
    two_ff_synchronizer #(
        .WIDTH(ADDR_WIDTH + 1),
        .INIT_VALUE({(ADDR_WIDTH + 1){1'b0}})
    ) wr_ptr_sync (
        .clk(rd_clk),
        .rst_n_sync(rd_rst_n_sync),
        .async_in(wr_ptr_gray),
        .sync_out(wr_ptr_gray_sync)
    );

    two_ff_synchronizer #(
        .WIDTH(ADDR_WIDTH + 1),
        .INIT_VALUE({(ADDR_WIDTH + 1){1'b0}})
    ) rd_ptr_sync (
        .clk(wr_clk),
        .rst_n_sync(wr_rst_n_sync),
        .async_in(rd_ptr_gray),
        .sync_out(rd_ptr_gray_sync)
    );

    wire [ADDR_WIDTH:0] wr_ptr_next = wr_ptr + 1'b1;
    wire [ADDR_WIDTH:0] wr_ptr_gray_next = wr_ptr_next ^ (wr_ptr_next >> 1);

    always @(posedge wr_clk or negedge wr_rst_n_sync) begin
        if (!wr_rst_n_sync) begin
            wr_ptr      <= {(ADDR_WIDTH + 1){1'b0}};
            wr_ptr_gray <= {(ADDR_WIDTH + 1){1'b0}};
        end else if (wr_en && !full) begin
            wr_ptr      <= wr_ptr_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end
    end

    always @(posedge wr_clk) begin
        if (wr_en && !full) begin
            fifo_mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
        end
    end

    wire [ADDR_WIDTH:0] rd_ptr_next = rd_ptr + 1'b1;
    wire [ADDR_WIDTH:0] rd_ptr_gray_next = rd_ptr_next ^ (rd_ptr_next >> 1);

    always @(posedge rd_clk or negedge rd_rst_n_sync) begin
        if (!rd_rst_n_sync) begin
            rd_ptr      <= {(ADDR_WIDTH + 1){1'b0}};
            rd_ptr_gray <= {(ADDR_WIDTH + 1){1'b0}};
        end else if (rd_en && !empty) begin
            rd_ptr      <= rd_ptr_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end

    // Status flags
    assign empty   = (rd_ptr_gray == wr_ptr_gray_sync);
    assign full    = (wr_ptr_gray == {~rd_ptr_gray_sync[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr_gray_sync[ADDR_WIDTH-2:0]});
    assign rd_data = fifo_mem[rd_ptr[ADDR_WIDTH-1:0]];

endmodule