module axi_slave_test #(
    parameter ADDR_WIDTH = 40,
    parameter DATA_WIDTH = 128,
    parameter ID_WIDTH   = 4,
    parameter ADDR_LOW_BOUND = 40'h0000_0000_0000,
    parameter ADDR_HIGH_BOUND = 40'h0000_00FF_FFFF,
    parameter RANDOM_RESP_ERR_PROB = 5,
    parameter BURST_LEN_MAX = 16
)(
    input  wire                      ACLK,
    input  wire                      ARESETn,

    // Write Address Channel
    input  wire [ID_WIDTH-1:0]       AWID,
    input  wire [ADDR_WIDTH-1:0]     AWADDR,
    input  wire [7:0]                AWLEN,
    input  wire [2:0]                AWSIZE,
    input  wire [1:0]                AWBURST,
    input  wire [1:0]                AWLOCK,
    input  wire [3:0]                AWCACHE,
    input  wire [2:0]                AWPROT,
    input  wire [3:0]                AWQOS,
    input  wire [3:0]                AWREGION,
    input  wire                      AWVALID,
    output reg                       AWREADY,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]     WDATA,
    input  wire [DATA_WIDTH/8-1:0]   WSTRB,
    input  wire                      WLAST,
    input  wire                      WVALID,
    output reg                       WREADY,

    // Write Response Channel
    output reg  [ID_WIDTH-1:0]       BID,
    output reg  [1:0]                BRESP,
    output reg                       BVALID,
    input  wire                      BREADY,

    // Read Address Channel
    input  wire [ID_WIDTH-1:0]       ARID,
    input  wire [ADDR_WIDTH-1:0]     ARADDR,
    input  wire [7:0]                ARLEN,
    input  wire [2:0]                ARSIZE,
    input  wire [1:0]                ARBURST,
    input  wire [1:0]                ARLOCK,
    input  wire [3:0]                ARCACHE,
    input  wire [2:0]                ARPROT,
    input  wire [3:0]                ARQOS,
    input  wire [3:0]                ARREGION,
    input  wire                      ARVALID,
    output reg                       ARREADY,

    // Read Data Channel
    output reg  [ID_WIDTH-1:0]       RID,
    output reg  [DATA_WIDTH-1:0]     RDATA,
    output reg  [1:0]                RRESP,
    output reg                       RLAST,
    output reg                       RVALID,
    input  wire                      RREADY
);

    localparam MEM_DEPTH = (ADDR_HIGH_BOUND - ADDR_LOW_BOUND + 1) >> 4;
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    reg [15:0] rand_lfsr;
    wire [15:0] rand_next = {rand_lfsr[14:0], rand_lfsr[15] ^ rand_lfsr[13] ^ rand_lfsr[12] ^ rand_lfsr[10]};
    always @(posedge ACLK or negedge ARESETn)
        if (!ARESETn) rand_lfsr <= 16'hACE1;
        else          rand_lfsr <= rand_next;

    // Internal state
    reg [ADDR_WIDTH-1:0] araddr_reg, awaddr_reg;
    reg [7:0] arlen_reg, awlen_reg;
    reg [2:0] arsize_reg, awsize_reg;
    reg [1:0] arburst_reg, awburst_reg;
    reg [ID_WIDTH-1:0] arid_reg, awid_reg;
    reg [7:0] arcount, awcount;
    reg reading, writing;

    // Read address handling
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            ARREADY <= 1;
            reading <= 0;
        end else if (ARVALID && ARREADY) begin
            arid_reg     <= ARID;
            araddr_reg   <= ARADDR;
            arlen_reg    <= ARLEN;
            arsize_reg   <= ARSIZE;
            arburst_reg  <= ARBURST;
            arcount      <= 0;
            reading      <= 1;
            ARREADY      <= 0;
        end else if (!reading) begin
            ARREADY <= 1;
        end
    end

    wire [ADDR_WIDTH-1:0] read_addr =
        (arburst_reg == 2'b01) ? araddr_reg + (arcount << arsize_reg) :
        (arburst_reg == 2'b10) ? araddr_reg + (((arcount << arsize_reg) % (1 << (arsize_reg + arlen_reg)))) :
        araddr_reg;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            RVALID <= 0;
            RLAST  <= 0;
        end else if (reading && (!RVALID || (RVALID && RREADY))) begin
            RVALID <= 1;
            RLAST  <= (arcount == arlen_reg);
            RID    <= arid_reg;
            if (read_addr < ADDR_LOW_BOUND || read_addr > ADDR_HIGH_BOUND) begin
                RRESP <= 2'b10;
                RDATA <= 0;
            end else if (rand_lfsr[7:0] < RANDOM_RESP_ERR_PROB) begin
                RRESP <= 2'b11;
                RDATA <= {4{32'hDEADFACE}};
            end else begin
                RRESP <= 2'b00;
                RDATA <= mem[(read_addr - ADDR_LOW_BOUND) >> 4];
            end
            arcount <= arcount + 1;
            if (arcount == arlen_reg) reading <= 0;
        end else if (RVALID && !RREADY) begin
            RVALID <= RVALID;
        end else begin
            RVALID <= 0;
        end
    end

    // Write address handling
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            AWREADY <= 1;
            writing <= 0;
        end else if (AWVALID && AWREADY) begin
            awid_reg    <= AWID;
            awaddr_reg  <= AWADDR;
            awlen_reg   <= AWLEN;
            awsize_reg  <= AWSIZE;
            awburst_reg <= AWBURST;
            awcount     <= 0;
            writing     <= 1;
            AWREADY     <= 0;
        end else if (!writing) begin
            AWREADY <= 1;
        end
    end

    wire [ADDR_WIDTH-1:0] write_addr =
        (awburst_reg == 2'b01) ? awaddr_reg + (awcount << awsize_reg) :
        (awburst_reg == 2'b10) ? awaddr_reg + (((awcount << awsize_reg) % (1 << (awsize_reg + awlen_reg)))) :
        awaddr_reg;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            WREADY <= 1;
        end else if (WVALID && WREADY) begin
            if (write_addr >= ADDR_LOW_BOUND && write_addr <= ADDR_HIGH_BOUND && rand_lfsr[7:0] >= RANDOM_RESP_ERR_PROB) begin
                mem[(write_addr - ADDR_LOW_BOUND) >> 4] <= WDATA;
            end
            awcount <= awcount + 1;
            if (WLAST) writing <= 0;
        end
        WREADY <= writing;
    end

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            BVALID <= 0;
        end else if (!writing && WVALID && WLAST) begin
            BVALID <= 1;
            BRESP  <= (rand_lfsr[7:0] < RANDOM_RESP_ERR_PROB) ? 2'b11 : 2'b00;
            BID    <= awid_reg;
        end else if (BVALID && BREADY) begin
            BVALID <= 0;
        end
    end

    // Memory init
    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = {4{$random}};
    end

endmodule
