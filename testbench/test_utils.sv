`timescale 1ns/10ps

module tb_sync_fifo;

    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;
    parameter ADDR_WIDTH = $clog2(DEPTH);

    logic clk, rst_n;
    logic wr_en, rd_en;
    logic [DATA_WIDTH-1:0] din;
    logic [DATA_WIDTH-1:0] dout;
    logic full, empty;

    // DUT
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .XILINX_SYN(1'b0)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        $display("Start sync_fifo test");
        clk = 0;
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        din = 0;

        #20;
        rst_n = 1;

        // Write to FIFO
        repeat (DEPTH) begin
            @(posedge clk);
            if (!full) begin
                wr_en <= 1;
                din <= $random;
            end
        end
        wr_en <= 0;

        // Read from FIFO
        repeat (DEPTH) begin
            @(posedge clk);
            if (!empty) begin
                rd_en <= 1;
            end
        end
        rd_en <= 0;

        #20;
        $display("Finished sync_fifo test");
        $finish;
    end

endmodule


module tb_async_fifo;

    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;
    parameter ADDR_WIDTH = $clog2(DEPTH);
    parameter TEST_LENGTH = 1024;

    logic wr_clk, rd_clk;
    logic wr_rst_n, rd_rst_n;
    logic wr_en, rd_en;
    logic [DATA_WIDTH-1:0] din;
    logic [DATA_WIDTH-1:0] dout;
    logic full, empty;
    logic rd_valid;

    // DUT
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .XILINX_SYN(1'b0)
    ) dut (
        .wr_clk(wr_clk),
        .wr_rst_n(wr_rst_n),
        .wr_en(wr_en),
        .din(din),
        .full(full),
        .rd_clk(rd_clk),
        .rd_rst_n(rd_rst_n),
        .rd_en(rd_en),
        .rd_valid(rd_valid),
        .dout(dout),
        .empty(empty)
    );

    // Clock generation
    always #4 wr_clk = ~wr_clk;
    always #7 rd_clk = ~rd_clk;

    int wr_count;
    logic [DATA_WIDTH - 1:0] din_i;
    logic [DATA_WIDTH - 1:0] test_array [0:TEST_LENGTH - 1];

    initial begin
        wr_clk = 0;
        rd_clk = 0;
        wr_rst_n = 0;
        rd_rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        din = 0;

        for(integer i = 0; i < TEST_LENGTH; i++) begin
            test_array[i] = $urandom;
        end

        $display("Start async_fifo test");

        #30;
        wr_rst_n = 1;
        rd_rst_n = 1;

        fork
            // Write
            begin
                wr_count = 0;
                forever begin
                    @(posedge wr_clk);
                    #1ns
                    if (wr_count == TEST_LENGTH) begin
                        break;
                    end
                    if (!full) begin
                        wr_en <= 1;
                        din <= test_array[wr_count];
                        wr_count++;
                        // $display("Write %0d: %h", wr_count, din_i);
                    end else begin
                        wr_en <= 0;
                        $display("Write blocked: FIFO full #%0d", wr_count);
                    end
                end
                wr_en <= 0;
            end

            // 读取线程
            begin
                int rd_count = 0;
                forever begin
                    @(posedge rd_clk);
                    #1ns

                    if (rd_count == TEST_LENGTH) begin
                        break;
                    end
                    if (!empty) begin
                        rd_en <= 1;
                    end else begin
                        rd_en <= 0;
                    end
                    if (rd_valid) begin
                        if (dout != test_array[rd_count]) begin
                            $display("Read %0d: %h", rd_count, dout);
                        end
                        rd_count++;
                    end
                end
                rd_en <= 0;
            end
        join

        #40;
        $display("Finished async_fifo test");
        $finish;
    end

endmodule
