`timescale 1ns / 1ps

module tb_acceptance_filter;

    reg  [31:0] msg_id_in;
    reg  [3:0]  uaf;
    reg  [31:0] afmr1, afir1;
    reg  [31:0] afmr2, afir2;
    reg  [31:0] afmr3, afir3;
    reg  [31:0] afmr4, afir4;
    wire        filter_match;

    integer errors = 0;

    acceptance_filter dut (
        .msg_id_in    (msg_id_in),
        .uaf          (uaf),
        .afmr1        (afmr1),
        .afir1        (afir1),
        .afmr2        (afmr2),
        .afir2        (afir2),
        .afmr3        (afmr3),
        .afir3        (afir3),
        .afmr4        (afmr4),
        .afir4        (afir4),
        .filter_match (filter_match)
    );

    initial begin
        uaf   = 4'd0;
        afmr1 = 32'd0; afir1 = 32'd0;
        afmr2 = 32'd0; afir2 = 32'd0;
        afmr3 = 32'd0; afir3 = 32'd0;
        afmr4 = 32'd0; afir4 = 32'd0;
        msg_id_in = 32'd0;

        #10;

        //-------------------------------------------------------------
        // Test 1: Default Accept All when UAF == 0
        //-------------------------------------------------------------
        $display("[TB] Test 1: UAF = 0 -> All messages accepted...");
        msg_id_in = 32'h12345678; #1;
        if (!filter_match) begin $display("[TB ERROR] UAF=0 rejected message!"); errors = errors + 1; end
        msg_id_in = 32'hDEADBEEF; #1;
        if (!filter_match) begin $display("[TB ERROR] UAF=0 rejected message!"); errors = errors + 1; end
        $display("[TB] Test 1 PASSED!");

        //-------------------------------------------------------------
        // Test 2: Filter 1: Exact Standard ID match (0x123)
        // Standard ID in bits 31..21 (0x123 << 21 = 0x24600000), IDE=0, RTR=0
        //-------------------------------------------------------------
        $display("[TB] Test 2: Filter 1 Exact Match (ID=0x123)...");
        uaf   = 4'b0001;
        afmr1 = 32'hFFE00000; // Match top 11 bits
        afir1 = 32'h24600000; // 0x123 << 21

        msg_id_in = 32'h24600000; #1; // Matching ID
        if (!filter_match) begin $display("[TB ERROR] Filter 1 failed to match expected ID!"); errors = errors + 1; end

        msg_id_in = 32'h24800000; #1; // ID=0x124 -> should fail
        if (filter_match) begin $display("[TB ERROR] Filter 1 incorrectly accepted non-matching ID!"); errors = errors + 1; end
        $display("[TB] Test 2 PASSED!");

        //-------------------------------------------------------------
        // Test 3: Multiple Filters (Filter 1 & Filter 2)
        // Filter 2: Extended ID prefix match (0x18XXXXXX)
        //-------------------------------------------------------------
        $display("[TB] Test 3: Multiple Filters Active...");
        uaf   = 4'b0011;
        afmr2 = 32'hFF000000;
        afir2 = 32'h18000000;

        msg_id_in = 32'h24600000; #1; // Matches Filter 1
        if (!filter_match) begin $display("[TB ERROR] Multi-filter failed on Filter 1!"); errors = errors + 1; end

        msg_id_in = 32'h18ABCDEF; #1; // Matches Filter 2
        if (!filter_match) begin $display("[TB ERROR] Multi-filter failed on Filter 2!"); errors = errors + 1; end

        msg_id_in = 32'h99000000; #1; // Matches neither -> reject
        if (filter_match) begin $display("[TB ERROR] Multi-filter incorrectly accepted non-matching ID!"); errors = errors + 1; end
        $display("[TB] Test 3 PASSED!");

        //-------------------------------------------------------------
        // Summary
        //-------------------------------------------------------------
        if (errors == 0) begin
            $display("\n=======================================================");
            $display("   ALL ACCEPTANCE_FILTER TESTS PASSED SUCCESSFULLY!    ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("   ACCEPTANCE_FILTER TESTS FAILED WITH %0d ERRORS!     ", errors);
            $display("=======================================================\n");
        end

        $finish;
    end

endmodule
