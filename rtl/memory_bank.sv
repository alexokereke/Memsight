`timescale 1ns / 1ps

module memory_bank (
    input  logic        clk,
    input  logic        en,
    input  logic        we,
    input  logic [7:0]  addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata
);

    // 256 words x 32 bits = 1 KiB of storage.
    logic [31:0] mem [0:255];

    // Memory operations happen on the rising clock edge.
    always_ff @(posedge clk) begin
        if (en) begin
            if (we)
                mem[addr] <= wdata;
            else
                rdata <= mem[addr];
        end
    end

endmodule