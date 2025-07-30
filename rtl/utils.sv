module sync_fifo #(
    parameter DATA_WIDTH     = 8,
    parameter DEPTH          = 16,
    parameter ADDR_WIDTH     = $clog2(DEPTH),
    parameter bit XILINX_SYN = 1'b0,
    parameter int AE_THRESH  = 4,           // almost_empty threshold
    parameter int AF_THRESH  = DEPTH - 4,   // almost_full threshold
    parameter FIFO_NAME = "FIFO"
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   wr_en,
    input  logic                   rd_en,
    output logic                   rd_valid,
    input  logic [DATA_WIDTH-1:0]  din,
    output logic [DATA_WIDTH-1:0]  dout,
    output logic                   full,
    output logic                   empty,
    output logic                   almost_full,
    output logic                   almost_empty,
    output logic [ADDR_WIDTH:0]    data_count   // <= 新增输出
);

generate
    if (XILINX_SYN) begin : xilinx_fifo
        // 使用 Xilinx 原语
        logic [ADDR_WIDTH:0] wr_data_count;

        xpm_fifo_sync #(
            .FIFO_MEMORY_TYPE    ("auto"),
            .ECC_MODE            ("no_ecc"),
            .FIFO_WRITE_DEPTH    (DEPTH),
            .WRITE_DATA_WIDTH    (DATA_WIDTH),
            .READ_DATA_WIDTH     (DATA_WIDTH),
            .WR_DATA_COUNT_WIDTH (ADDR_WIDTH+1),
            .RD_DATA_COUNT_WIDTH (ADDR_WIDTH+1),
            .PROG_FULL_THRESH    (AF_THRESH),
            .PROG_EMPTY_THRESH   (AE_THRESH),
            .DOUT_RESET_VALUE    ("0"),
            .FULL_RESET_VALUE    (1)
        ) xpm_sync_fifo_inst (
            .rst            (~rst_n),
            .wr_clk         (clk),
            .wr_en          (wr_en),
            .din            (din),
            .full           (full),
            .prog_full      (almost_full),
            .wr_data_count  (wr_data_count),
            .rd_en          (rd_en),
            .dout           (dout),
            .empty          (empty),
            .prog_empty     (almost_empty),
            .rd_data_count  (),  // unused
            .sleep          (1'b0)
        );

        assign data_count = wr_data_count;

        always @(posedge clk) begin
            rd_valid <= !empty & rd_en;
        end
    end else begin : std_fifo
        logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
        logic [ADDR_WIDTH:0] wr_ptr, rd_ptr;
        logic [ADDR_WIDTH:0] used;

        assign full         = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                              (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
        assign empty        = (wr_ptr == rd_ptr);
        assign used         = wr_ptr - rd_ptr;
        assign data_count   = used;
        assign almost_full  = (used >= AF_THRESH);
        assign almost_empty = (used <= AE_THRESH);

        always_ff @(posedge clk) begin
            if (!rst_n) begin
                wr_ptr <= 0;
            end else if (wr_en && !full) begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= din;
                wr_ptr <= wr_ptr + 1;
            end else if (wr_en && !full) begin
                $display("%s full, Write Failed!", FIFO_NAME);
            end
        end

        always_ff @(posedge clk) begin
            rd_valid <= 0;
            if (!rst_n) begin
                rd_ptr <= 0;
                dout <= '0;
            end else if (rd_en && !empty) begin
                dout <= mem[rd_ptr[ADDR_WIDTH-1:0]];
                rd_ptr <= rd_ptr + 1;
                rd_valid <= 1;
            end
        end
    end
endgenerate

endmodule


module async_fifo #(
    parameter DATA_WIDTH     = 8,
    parameter DEPTH          = 16,
    parameter ADDR_WIDTH     = $clog2(DEPTH),
    parameter bit XILINX_SYN = 1'b0,
    parameter int AE_THRESH  = 4,
    parameter int AF_THRESH  = DEPTH - 4
)(
    input  logic                   wr_clk,
    input  logic                   wr_rst_n,
    input  logic                   wr_en,
    input  logic [DATA_WIDTH-1:0]  din,
    output logic                   full,
    output logic                   almost_full,
    output logic [ADDR_WIDTH:0]    data_count,

    input  logic                   rd_clk,
    input  logic                   rd_rst_n,
    input  logic                   rd_en,
    output logic                   rd_valid,
    output logic [DATA_WIDTH-1:0]  dout,
    output logic                   empty,
    output logic                   almost_empty
);

generate
    if (XILINX_SYN) begin : xilinx_fifo
        logic [ADDR_WIDTH:0] wr_data_count;

        xpm_fifo_async #(
            .FIFO_MEMORY_TYPE    ("auto"),
            .ECC_MODE            ("no_ecc"),
            .FIFO_WRITE_DEPTH    (DEPTH),
            .WRITE_DATA_WIDTH    (DATA_WIDTH),
            .READ_DATA_WIDTH     (DATA_WIDTH),
            .WR_DATA_COUNT_WIDTH (ADDR_WIDTH+1),
            .RD_DATA_COUNT_WIDTH (ADDR_WIDTH+1),
            .PROG_FULL_THRESH    (AF_THRESH),
            .PROG_EMPTY_THRESH   (AE_THRESH),
            .DOUT_RESET_VALUE    ("0"),
            .FULL_RESET_VALUE    (1),
            .CDC_SYNC_STAGES     (2)
        ) xpm_async_fifo_inst (
            .rst            (~wr_rst_n),
            .wr_clk         (wr_clk),
            .wr_en          (wr_en),
            .din            (din),
            .full           (full),
            .prog_full      (almost_full),
            .wr_data_count  (wr_data_count),

            .rd_clk         (rd_clk),
            .rd_en          (rd_en),
            .dout           (dout),
            .empty          (empty),
            .prog_empty     (almost_empty),
            .rd_data_count  (),
            .sleep          (1'b0)
        );

        assign data_count = wr_data_count;

        always @(posedge rd_clk) begin
            rd_valid <= !empty & rd_en;
        end

        always @(posedge wr_clk) begin
            if (wr_en && full) begin
                $display("[%0t] WARNING: Write blocked (Xilinx FIFO full)", $time);
            end
        end

    end else begin : std_fifo
        logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

        logic [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_gray;
        logic [ADDR_WIDTH:0] rd_ptr_bin, rd_ptr_gray;
        logic [ADDR_WIDTH:0] wr_ptr_bin_next;
        logic [ADDR_WIDTH:0] rd_ptr_bin_next;

        assign wr_ptr_bin_next = wr_ptr_bin + 1;
        assign rd_ptr_bin_next = rd_ptr_bin + 1;

        logic [ADDR_WIDTH:0] rd_ptr_gray_sync_wr_1, rd_ptr_gray_sync_wr_2;
        logic [ADDR_WIDTH:0] wr_ptr_gray_sync_rd_1, wr_ptr_gray_sync_rd_2;

        // Write
        always_ff @(posedge wr_clk) begin
            if (!wr_rst_n) begin
                wr_ptr_bin  <= 0;
                wr_ptr_gray <= 0;
            end else begin
                if (wr_en && full) begin
                    $display("[%0t] WARNING: Write blocked (std FIFO full), wr_ptr = %0d", $time, wr_ptr_bin);
                end else if (wr_en && !full) begin
                    mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= din;
                    wr_ptr_bin  <= wr_ptr_bin_next;
                    wr_ptr_gray <= bin_to_gray(wr_ptr_bin_next);
                end
            end
        end

        // Read
        always_ff @(posedge rd_clk) begin
            rd_valid <= 0;
            if (!rd_rst_n) begin
                rd_ptr_bin  <= 0;
                rd_ptr_gray <= 0;
                dout <= '0;
            end else if (rd_en && !empty) begin
                dout <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
                rd_ptr_bin  <= rd_ptr_bin_next;
                rd_ptr_gray <= bin_to_gray(rd_ptr_bin_next);
                rd_valid <= 1;
            end
        end

        // Gray synchronization
        always_ff @(posedge wr_clk) begin
            if (!wr_rst_n) begin
                rd_ptr_gray_sync_wr_1 <= 0;
                rd_ptr_gray_sync_wr_2 <= 0;
            end else begin
                rd_ptr_gray_sync_wr_1 <= rd_ptr_gray;
                rd_ptr_gray_sync_wr_2 <= rd_ptr_gray_sync_wr_1;
            end
        end

        always_ff @(posedge rd_clk) begin
            if (!rd_rst_n) begin
                wr_ptr_gray_sync_rd_1 <= 0;
                wr_ptr_gray_sync_rd_2 <= 0;
            end else begin
                wr_ptr_gray_sync_rd_1 <= wr_ptr_gray;
                wr_ptr_gray_sync_rd_2 <= wr_ptr_gray_sync_rd_1;
            end
        end

        // Conversion
        function automatic logic [ADDR_WIDTH:0] bin_to_gray(input logic [ADDR_WIDTH:0] bin);
            return bin ^ (bin >> 1);
        endfunction

        function automatic logic [ADDR_WIDTH:0] gray_to_bin(input logic [ADDR_WIDTH:0] gray);
            logic [ADDR_WIDTH:0] bin;
            integer i;
            begin
                bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
                for (i = ADDR_WIDTH - 1; i >= 0; i--)
                    bin[i] = bin[i+1] ^ gray[i];
                return bin;
            end
        endfunction

        logic [ADDR_WIDTH:0] rd_ptr_bin_sync_wr;
        logic [ADDR_WIDTH:0] wr_ptr_bin_sync_rd;

        assign rd_ptr_bin_sync_wr = gray_to_bin(rd_ptr_gray_sync_wr_2);
        assign wr_ptr_bin_sync_rd = gray_to_bin(wr_ptr_gray_sync_rd_2);

        assign full         = (wr_ptr_bin_next == {~rd_ptr_bin_sync_wr[ADDR_WIDTH], rd_ptr_bin_sync_wr[ADDR_WIDTH-1:0]});
        assign empty        = (rd_ptr_bin == wr_ptr_bin_sync_rd);
        assign data_count   = wr_ptr_bin - rd_ptr_bin_sync_wr;
        assign almost_full  = (data_count >= AF_THRESH);
        assign almost_empty = (data_count <= AE_THRESH);

    end
endgenerate

endmodule
