module memsight_basys3 (
    input  logic       clk,
    input  logic       btnC,
    output logic [3:0] led
);

    // Start in reset after FPGA configuration.
    // Button assertion is asynchronous; release is synchronized.
    (* ASYNC_REG = "TRUE" *)
    logic [1:0] reset_pipe = 2'b11;

    always_ff @(posedge clk or posedge btnC) begin
        if (btnC)
            reset_pipe <= 2'b11;
        else
            reset_pipe <= {reset_pipe[0], 1'b0};
    end

    wire rst = reset_pipe[1];

    typedef enum logic [2:0] {
        WRITE_REQ,
        WRITE_WAIT,
        READ_REQ,
        READ_WAIT,
        PASSED,
        FAILED
    } state_t;

    state_t state;
    logic [7:0] address;
    logic [15:0] watchdog;

    logic        req_valid;
    logic        req_ready;
    logic        req_write;
    logic [31:0] req_wdata;
    logic        rsp_valid;
    logic [31:0] rsp_rdata;

    function automatic logic [31:0] test_pattern(
        input logic [7:0] addr
    );
        test_pattern = 32'hA5C3_5A3C ^ {addr, addr, addr, addr};
    endfunction

    assign req_valid = !rst &&
                       ((state == WRITE_REQ) ||
                        (state == READ_REQ));

    assign req_write = (state == WRITE_REQ);
    assign req_wdata = test_pattern(address);

    controller u_controller (
        .clk       (clk),
        .rst       (rst),
        .req_valid (req_valid),
        .req_ready (req_ready),
        .req_write (req_write),
        .req_addr  (address),
        .req_wdata (req_wdata),
        .rsp_valid (rsp_valid),
        .rsp_rdata (rsp_rdata)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state    <= WRITE_REQ;
            address  <= 8'd0;
            watchdog <= 16'd0;
        end else if ((state != PASSED) && (state != FAILED)) begin
            // Fail if the entire test takes too long.
            if (watchdog == 16'hFFFF) begin
                state <= FAILED;
            end else begin
                watchdog <= watchdog + 16'd1;

                case (state)
                    WRITE_REQ: begin
                        if (req_valid && req_ready)
                            state <= WRITE_WAIT;
                    end

                    WRITE_WAIT: begin
                        if (rsp_valid) begin
                            if (address == 8'hFF) begin
                                address <= 8'd0;
                                state   <= READ_REQ;
                            end else begin
                                address <= address + 8'd1;
                                state   <= WRITE_REQ;
                            end
                        end
                    end

                    READ_REQ: begin
                        if (req_valid && req_ready)
                            state <= READ_WAIT;
                    end

                    READ_WAIT: begin
                        if (rsp_valid) begin
                            if (rsp_rdata != test_pattern(address)) begin
                                state <= FAILED;
                            end else if (address == 8'hFF) begin
                                state <= PASSED;
                            end else begin
                                address <= address + 8'd1;
                                state   <= READ_REQ;
                            end
                        end
                    end

                    default: state <= FAILED;
                endcase
            end
        end
    end

    // Results remain visible until reset.
    assign led[0] = !rst && (state == PASSED);
    assign led[1] = !rst && (state == FAILED);
    assign led[2] = !rst && (state != PASSED) && (state != FAILED);
    assign led[3] = rst;

endmodule