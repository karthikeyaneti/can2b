`timescale 1ns / 1ps

// Compatibility target for the APB/register-file regression name.
`include "sim/can_reg_file/tb_can_regfile.v"

module tb_apb_reg_file;
    tb_can_regfile smoke_test();
endmodule