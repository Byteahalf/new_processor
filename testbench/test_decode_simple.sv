`timescale 1ns/1ps

module tb_decode_simple;

    // Parameters
    parameter DATA_WIDTH = 128;
    parameter DECODE_ISSUE_WIDTH = 4;
    parameter FILE = "C:/Users/Lost/Desktop/new_processor/testbench/binary/main.mem";

    // DUT signals
    logic clk;
    logic rst_n;
    logic fetch_rd_en;
    logic fetch_rd_valid;
    logic [DATA_WIDTH-1:0] fetch_instr;
    logic [$bits(fifo_fetch_to_decode_param_t)-1:0] fetch_param;
    logic fetch_empty;

    // Clock generation
    always #5 clk = ~clk;

    // Instantiate DUT
    decode #(
        .DATA_WIDTH(DATA_WIDTH),
        .DECODE_ISSUE_WIDTH(DECODE_ISSUE_WIDTH)
    ) u_decode (
        .clk(clk),
        .rst_n(rst_n),
        .fetch_rd_en(fetch_rd_en),
        .fetch_rd_valid(fetch_rd_valid),
        .fetch_instr(fetch_instr),
        .fetch_param(fetch_param),
        .fetch_empty(fetch_empty),
        .ci_flush   ('0)
    );

    // Instruction memory (128 bits * 8)
    logic [DATA_WIDTH-1:0] instr_mem [0:511];
    int instr_index = 0;
    
    initial begin
        $readmemh(FILE, instr_mem);
    end
    
    always_comb begin
        fetch_instr = instr_mem[instr_index];
        fetch_param = {40'('h1_0000 + instr_index * 16), 1'b0};
    end

    initial begin
        // Initialize clock and reset
        clk = 0;
        rst_n = 0;
        fetch_rd_valid = 1;
        fetch_empty = 0;
        #20;
        rst_n = 1;

        repeat (8) begin
            @(posedge clk);
            
            if(fetch_rd_en & rst_n) begin
                instr_index++;
            end
        end

        #100;
        $finish;
    end

endmodule
