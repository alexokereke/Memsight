`timescale 1ns / 1ps

module tb_memsight_basys3;

    logic clk = 1'b0;
    logic btnC = 1'b0;
    wire [3:0] led;

    // 100 MHz clock.
    always #5 clk = ~clk;

    memsight_basys3 dut (
        .clk  (clk),
        .btnC (btnC),
        .led  (led)
    );

    task automatic wait_for_pass;
        integer cycles;
        begin
            cycles = 0;

            // Sample after sequential logic has updated.
            while ((led[0] !== 1'b1) && (cycles < 70000)) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;

                if ($isunknown(led))
                    $fatal(1, "LED outputs contain unknown values");

                if (led[1])
                    $fatal(1, "Hardware test reported FAIL");
            end

            if (led !== 4'b0001)
                $fatal(1, "Expected PASS only; LEDs=%b", led);

            // PASS must remain asserted until reset.
            repeat (10) begin
                @(posedge clk);
                #1;
                if (led !== 4'b0001)
                    $fatal(1, "PASS did not remain asserted");
            end
        end
    endtask

    initial begin
        // Check the power-up reset.
        #1;
        if (led !== 4'b1000)
            $fatal(1, "Expected startup reset; LEDs=%b", led);

        wait_for_pass();
        $display("PASS: startup memory test completed");

        // Press the center button away from a clock edge.
        @(negedge clk);
        btnC = 1'b1;

        repeat (4) @(posedge clk);
        #1;

        if (led !== 4'b1000)
            $fatal(1, "Button did not reset the test");

        @(negedge clk);
        btnC = 1'b0;

        // Allow reset to release through both synchronizer stages.
        repeat (3) @(posedge clk);
        #1;

        if (led !== 4'b0100)
            $fatal(1, "Expected BUSY after reset; LEDs=%b", led);

        wait_for_pass();
        $display("PASS: button reset restarted the memory test");
        $display("ALL HARDWARE WRAPPER TESTS PASSED");
        $finish;
    end

    // Independent timeout for the complete simulation.
    initial begin
        #2000000;
        $fatal(1, "Simulation timed out");
    end

endmodule