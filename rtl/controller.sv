`timescale 1ns / 1ps

module controller (
    input  logic        clk,
    input  logic        rst,

    // Request interface
    input  logic        req_valid,
    output logic        req_ready,
    input  logic        req_write,
    input  logic [7:0]  req_addr,
    input  logic [31:0] req_wdata,

    // Response interface
    output logic        rsp_valid,
    output logic [31:0] rsp_rdata
);

    typedef enum logic [1:0] {
        IDLE,
        EXECUTE,
        RESPOND
    } state_t;

    state_t state;

    logic        saved_write;
    logic [7:0]  saved_addr;
    logic [31:0] saved_wdata;

    logic        mem_en;
    logic [31:0] mem_rdata;

    // Accept requests only when idle and out of reset.
    assign req_ready = (state == IDLE) && !rst;

    // Disable memory operations during reset.
    assign mem_en = (state == EXECUTE) && !rst;

    memory_bank u_memory_bank (
        .clk   (clk),
        .en    (mem_en),
        .we    (saved_write),
        .addr  (saved_addr),
        .wdata (saved_wdata),
        .rdata (mem_rdata)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state       <= IDLE;
            saved_write <= 1'b0;
            saved_addr  <= 8'd0;
            saved_wdata <= 32'd0;
            rsp_valid   <= 1'b0;
            rsp_rdata   <= 32'd0;
        end else begin
            // Responses last for one clock cycle.
            rsp_valid <= 1'b0;

            case (state)
                IDLE: begin
                    if (req_valid && req_ready) begin
                        saved_write <= req_write;
                        saved_addr  <= req_addr;
                        saved_wdata <= req_wdata;
                        state       <= EXECUTE;
                    end
                end

                EXECUTE: begin
                    // The memory performs its operation
                    // at this edge.
                    state <= RESPOND;
                end

                RESPOND: begin
                    rsp_valid <= 1'b1;

                    if (saved_write)
                        rsp_rdata <= 32'd0;
                    else
                        rsp_rdata <= mem_rdata;

                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule