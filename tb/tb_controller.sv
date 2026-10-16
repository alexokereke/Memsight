`timescale 1ns / 1ps

module tb_controller;

    logic clk = 0;
    logic rst = 1;

    logic        req_valid = 0;
    logic        req_ready;
    logic        req_write = 0;
    logic [7:0]  req_addr  = 0;
    logic [31:0] req_wdata = 0;

    logic        rsp_valid;
    logic [31:0] rsp_rdata;

    // 10 ns clock period.
    always #5 clk = ~clk;

    controller dut (
        .clk       (clk),
        .rst       (rst),
        .req_valid (req_valid),
        .req_ready (req_ready),
        .req_write (req_write),
        .req_addr  (req_addr),
        .req_wdata (req_wdata),
        .rsp_valid (rsp_valid),
        .rsp_rdata (rsp_rdata)
    );

    logic [31:0] expected_mem [0:255];
    logic [31:0] expected_data;
    bit pending = 0;

    integer cycle = 0;
    integer due_cycle = 0;
    integer accepted = 0;
    integer completed = 0;
    integer canceled = 0;
    integer stalled_cycles = 0;

    // Independent checker: inspect requests at the clock edge,
    // then inspect outputs after registered signals update.
    always @(posedge clk) begin
        cycle = cycle + 1;

        if (rst) begin
            if (pending)
                canceled = canceled + 1;

            pending = 0;

            #1;
            if (rsp_valid !== 1'b0)
                $fatal(1, "Response appeared during reset");

            if (req_ready !== 1'b0)
                $fatal(1, "Controller ready during reset");
        end else begin
            if (req_valid && !req_ready)
                stalled_cycles = stalled_cycles + 1;

            if (req_valid && req_ready) begin
                if (pending)
                    $fatal(1, "Accepted too many requests");

                accepted = accepted + 1;
                pending = 1;
                due_cycle = cycle + 2;

                if (req_write) begin
                    expected_mem[req_addr] = req_wdata;
                    expected_data = 32'd0;
                end else begin
                    expected_data = expected_mem[req_addr];
                end
            end

            #1;

            if (pending && cycle == due_cycle) begin
                if (rsp_valid !== 1'b1)
                    $fatal(1, "Missing response at cycle %0d",
                           cycle);

                if (rsp_rdata !== expected_data)
                    $fatal(1,
                        "Data mismatch: expected %h, received %h",
                        expected_data, rsp_rdata);

                completed = completed + 1;
                pending = 0;
            end else begin
                if (rsp_valid !== 1'b0)
                    $fatal(1, "Unexpected or early response");
            end
        end
    end

    // Change inputs on falling edges to avoid clock-edge races.
    // Hold the request until the controller accepts it.
    task automatic send_request (
        input logic        write_enable,
        input logic [7:0]  address,
        input logic [31:0] data
    );
        @(negedge clk);
        req_valid = 1;
        req_write = write_enable;
        req_addr  = address;
        req_wdata = data;

        @(posedge clk);
        while (req_ready !== 1'b1)
            @(posedge clk);

        @(negedge clk);
        req_valid = 0;
    endtask

    task automatic wait_until_idle;
        @(negedge clk);
        while (pending)
            @(negedge clk);
    endtask

    initial begin
        // Apply the initial synchronous reset.
        repeat (3) @(negedge clk);
        rst = 0;

        // Write every address, including 0 and 255.
        // Consecutive calls deliberately present requests
        // while the previous operation is still busy.
        for (int i = 0; i < 256; i++) begin
            send_request(
                1'b1, i[7:0], 32'hA5A50000 + i
            );
        end
        wait_until_idle();
        $display("PASS: 256 writes acknowledged");

        // Read every address and check its stored value.
        for (int i = 0; i < 256; i++) begin
            send_request(1'b0, i[7:0], 32'd0);
        end
        wait_until_idle();
        $display("PASS: 256 readbacks matched");

        // Overwrite a location and verify the new value.
        send_request(1'b1, 8'd42, 32'hDEADBEEF);
        send_request(1'b0, 8'd42, 32'd0);
        wait_until_idle();
        $display("PASS: overwrite and readback");

        // Cancel a pending read before its memory operation.
        send_request(1'b0, 8'd42, 32'd0);
        rst = 1;
        repeat (2) @(negedge clk);
        rst = 0;

        // Check that no stale response appears after reset.
        repeat (4) @(negedge clk);

        // Reset should preserve previously written memory.
        send_request(1'b0, 8'd42, 32'd0);
        wait_until_idle();
        repeat (4) @(negedge clk);

        if (stalled_cycles == 0)
            $fatal(1, "Busy-request behavior was not exercised");

        if (canceled != 1)
            $fatal(1, "Expected exactly one canceled request");

        if (accepted != completed + canceled)
            $fatal(1, "Request/response count mismatch");

        $display("PASS: busy requests and reset recovery");
        $display("Accepted=%0d Completed=%0d Canceled=%0d",
                 accepted, completed, canceled);
        $display("ALL TESTS PASSED");
        $finish;
    end

    // Stop with an error if the controller gets stuck.
    initial begin
        #100000;
        $fatal(1, "Simulation timed out");
    end

endmodule