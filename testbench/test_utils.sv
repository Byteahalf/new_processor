`timescale 1ns/10ps

module tb_sync_fifo;

    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;
    parameter ADDR_WIDTH = $clog2(DEPTH);
    parameter TEST_LENGTH = 1024;

    logic clk;
    logic rst_n;
    logic wr_en, rd_en;
    logic [DATA_WIDTH-1:0] din;
    logic [DATA_WIDTH-1:0] dout;
    logic full, empty;

    logic rd_valid;

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
        .rd_valid(rd_valid),
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty)
    );

    // Clock generation
    always #5 clk = ~clk;

    int wr_count = 0;
    int rd_count = 0;
    logic [DATA_WIDTH-1:0] test_array [0:TEST_LENGTH-1];

    initial begin
        clk = 0;
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        din = 0;

        for (int i = 0; i < TEST_LENGTH; i++) begin
            test_array[i] = $urandom;
        end

        $display("Start sync_fifo test");

        #20;
        rst_n = 1;

        fork
            // Write thread
            begin
                forever begin
                    @(posedge clk);
                    #1ns;
                    wr_en <= 0;

                    if (wr_count < TEST_LENGTH && !full) begin
                        if ($urandom_range(0, 99) < 70) begin // 70% 写入概率
                            wr_en <= 1;
                            din <= test_array[wr_count];
                            wr_count++;
                        end
                    end
                end
            end

            // Read thread
            begin
                forever begin
                    @(posedge clk);
                    #1ns;
                    rd_en <= 0;

                    if (rd_count < TEST_LENGTH && !empty) begin
                        if ($urandom_range(0, 99) < 40) begin // 40% 读取概率
                            rd_en <= 1;
                        end
                    end

                    if (rd_valid) begin
                        if (dout !== test_array[rd_count]) begin
                            $display("Mismatch at %0d: expected %h, got %h", rd_count, test_array[rd_count], dout);
                        end
                        rd_count++;
                    end
                end
            end
        join_none

        #20;
        wait (wr_count == TEST_LENGTH && rd_count == TEST_LENGTH);
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
        .XILINX_SYN(1'b1)
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

    logic [DATA_WIDTH - 1:0] test_array [0:TEST_LENGTH - 1];
    int wr_count, rd_count;

    initial begin
        wr_clk = 0;
        rd_clk = 0;
        wr_rst_n = 0;
        rd_rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        din = 0;
        wr_count = 0;
        rd_count = 0;

        for (int i = 0; i < TEST_LENGTH; i++) begin
            test_array[i] = $urandom;
        end

        $display("Start async_fifo test");

        #30;
        wr_rst_n = 1;
        rd_rst_n = 1;

        fork
            // 写入线程
            begin
                forever begin
                    @(posedge wr_clk);
                    #1ns;
                    if (wr_count < TEST_LENGTH && !full) begin
                        if ($urandom_range(0, 99) < 70) begin  // 70% 概率写入
                            wr_en <= 1;
                            din <= test_array[wr_count];
                            wr_count++;
                        end else begin
                            wr_en <= 0;
                        end
                    end else begin
                        wr_en <= 0;
                    end
                end
            end

            // 读取线程
            begin
                forever begin
                    @(posedge rd_clk);
                    #1ns;
                    if (rd_count < TEST_LENGTH && !empty) begin
                        if ($urandom_range(0, 99) < 50) begin  // 50% 概率读取
                            rd_en <= 1;
                        end else begin
                            rd_en <= 0;
                        end
                    end else begin
                        rd_en <= 0;
                    end

                    if (rd_valid) begin
                        if (dout !== test_array[rd_count]) begin
                            $display("Mismatch at %0d: expected %h, got %h", rd_count, test_array[rd_count], dout);
                        end
                        rd_count++;
                    end
                end
            end
        join_none

        // 等待仿真完成
        wait (wr_count == TEST_LENGTH && rd_count == TEST_LENGTH);
        #40;
        $display("Finished async_fifo test");
        $finish;
    end

endmodule
