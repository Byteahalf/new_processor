`timescale 1ns/10ps
//`include "defs.svh"

module tb_fetch_axi;

    // Parameters
    localparam ADDR_WIDTH = 40;
    localparam DATA_WIDTH = 128;
    localparam ID_WIDTH   = 4;

    // Clock & Reset
    logic clk;
    logic rst_n;

    // Instantiate AXI signal wires
    logic [ID_WIDTH-1:0]       arid;
    logic [ADDR_WIDTH-1:0]     araddr;
    logic [7:0]                arlen;
    logic [2:0]                arsize;
    logic [1:0]                arburst;
    logic [3:0]                arcache;
    logic [2:0]                arprot;
    logic [3:0]                arqos;
    logic [3:0]                arregion;
    logic                      arvalid;
    logic                      arready;

    logic [DATA_WIDTH-1:0]     rdata;
    logic [1:0]                rresp;
    logic                      rlast;
    logic                      rvalid;
    logic                      rready;

    // Fetch control signals
    logic                     co_error;
    logic                     co_reset_finish;
    logic                     ci_pause;
    logic                     ci_flush_request;
    logic                     co_flush_response;
    logic [ADDR_WIDTH-1:0]    ci_addr;

    // FIFO interface
    logic                    fetch_rd_en;
    logic                    fetch_rd_valid;
    logic [DATA_WIDTH-1:0]   fetch_instr;
    logic                    fetch_empty;
    logic [$bits(fifo_fetch_to_decode_param_t)-1:0] fetch_param;

    // Clock generation
    always #5 clk = ~clk;

    //==============================
    // Main Testbench
    //==============================

    typedef enum int {
        RESET,
        NORMAL,
        PAUSE,
        FLUSH,
        FINAL
    } test_stage_t;

    test_stage_t test_stage;

    initial begin

        test_stage = RESET;
        clk = 0;
        rst_n = 0;
        ci_pause = 0;
        ci_flush_request = 0;
        ci_addr = 40'h0000_0001_0002;
        fetch_rd_en = 0;

        #20 rst_n = 1;

        test_stage = NORMAL;
        #1000;

        // 启动读使能
        fetch_rd_en = 1;

        #60 
        test_stage = PAUSE;
        ci_pause = 1;
        fetch_rd_en = 0;
        #100 
        ci_pause = 0;
        fetch_rd_en = 1;
        #100
        fetch_rd_en = 0;
        #200

        test_stage = FLUSH;
        #10 ci_flush_request = 1;
        #10 ci_flush_request = 0;
        #400

        test_stage = FINAL;
        rst_n = 0;
        #20 rst_n = 1;

        // 等待一段时间观察行为
        #1000;

        $stop;
    end

    //==============================
    // DUT: axi_slave_test (slave)
    //==============================
    axi_slave_test #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .MEM_FILE("C:/Users/Lost/Desktop/new_processor/testbench/binary/mixed_instr_128B.mem")
    ) u_axi_slave (
        .ACLK(clk),
        .ARESETn(rst_n),

        .AWID(),
        .AWADDR(),
        .AWLEN(),
        .AWSIZE(),
        .AWBURST(),
        .AWLOCK(),
        .AWCACHE(),
        .AWPROT(),
        .AWQOS(),
        .AWREGION(),
        .AWVALID(1'b0),
        .AWREADY(),

        .WDATA(),
        .WSTRB(),
        .WLAST(),
        .WVALID(1'b0),
        .WREADY(),

        .BID(),
        .BRESP(),
        .BVALID(),
        .BREADY(1'b0),

        .ARID(arid),
        .ARADDR(araddr),
        .ARLEN(arlen),
        .ARSIZE(arsize),
        .ARBURST(arburst),
        .ARLOCK(2'b00),
        .ARCACHE(arcache),
        .ARPROT(arprot),
        .ARQOS(arqos),
        .ARREGION(arregion),
        .ARVALID(arvalid),
        .ARREADY(arready),

        .RID(arid),
        .RDATA(rdata),
        .RRESP(rresp),
        .RLAST(rlast),
        .RVALID(rvalid),
        .RREADY(rready)
    );

    //==============================
    // DUT: fetch (master)
    //==============================
    fetch #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BURST_LENGTH(4),
        .BOOT_ADDR(40'h0000_0001_0002)
    ) u_fetch (
        .clk(clk),
        .rst_n(rst_n),

        .co_error(co_error),
        .co_reset_finish(co_reset_finish),
        .ci_pause(ci_pause),
        .ci_flush_request(ci_flush_request),
        .co_flush_response(co_flush_response),
        .ci_addr(ci_addr),

        .m_axi_araddr(araddr),
        .m_axi_arlen(arlen),
        .m_axi_arsize(arsize),
        .m_axi_arburst(arburst),
        .m_axi_arcache(arcache),
        .m_axi_arprot(arprot),
        .m_axi_arqos(arqos),
        .m_axi_arregion(arregion),
        .m_axi_arvalid(arvalid),
        .m_axi_arready(arready),

        .m_axi_rdata(rdata),
        .m_axi_rresp(rresp),
        .m_axi_rlast(rlast),
        .m_axi_rvalid(rvalid),
        .m_axi_rready(rready),

        .fetch_rd_en(fetch_rd_en),
        .fetch_rd_valid(fetch_rd_valid),
        .fetch_instr(fetch_instr),
        .fetch_param(fetch_param),
        .fetch_empty(fetch_empty)
    );

endmodule