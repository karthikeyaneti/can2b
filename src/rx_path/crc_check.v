`timescale 1ns/1ps

module crc_check (
    input  wire        check_en,
    input  wire [14:0] calculated_crc,
    input  wire [14:0] received_crc,
    output wire        crc_error
);

    assign crc_error = check_en && (calculated_crc != received_crc);

endmodule
