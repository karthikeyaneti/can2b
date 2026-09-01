`timescale 1ns / 1ps

module acceptance_filter (
    input  wire [31:0] msg_id_in,
    input  wire [3:0]  uaf,
    input  wire [31:0] afmr1,
    input  wire [31:0] afir1,
    input  wire [31:0] afmr2,
    input  wire [31:0] afir2,
    input  wire [31:0] afmr3,
    input  wire [31:0] afir3,
    input  wire [31:0] afmr4,
    input  wire [31:0] afir4,
    output wire        filter_match
);

    wire match1 = uaf[0] && ((msg_id_in & afmr1) == (afir1 & afmr1));
    wire match2 = uaf[1] && ((msg_id_in & afmr2) == (afir2 & afmr2));
    wire match3 = uaf[2] && ((msg_id_in & afmr3) == (afir3 & afmr3));
    wire match4 = uaf[3] && ((msg_id_in & afmr4) == (afir4 & afmr4));

    // If all UAF bits are 0, all messages are accepted by default per DS791 specification
    assign filter_match = (uaf == 4'b0000) ? 1'b1 : (match1 | match2 | match3 | match4);

endmodule
