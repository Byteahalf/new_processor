module axi_slave_test #(
    parameter ADDR_WIDTH = 40,
    parameter DATA_WIDTH = 128,
    parameter ID_WIDTH   = 4,
    parameter ADDR_LOW_BOUND = 40'h0000_0001_0000,
    parameter ADDR_HIGH_BOUND = 40'h0000_001_FFFF,
    parameter RANDOM_RESP_ERR_PROB = 5,
    parameter BURST_LEN_MAX = 16,
    parameter MEM_FILE = ""
)(
    input  logic                        ACLK,
    input  logic                        ARESETn,

    //============================
    // Write Address Channel (AW)
    //============================
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWID" *)
    input  logic [ID_WIDTH-1:0]         AWID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWADDR" *)
    input  logic [ADDR_WIDTH-1:0]       AWADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWLEN" *)
    input  logic [7:0]                  AWLEN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWSIZE" *)
    input  logic [2:0]                  AWSIZE,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWBURST" *)
    input  logic [1:0]                  AWBURST,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWLOCK" *)
    input  logic [1:0]                  AWLOCK,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWCACHE" *)
    input  logic [3:0]                  AWCACHE,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWPROT" *)
    input  logic [2:0]                  AWPROT,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWQOS" *)
    input  logic [3:0]                  AWQOS,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWREGION" *)
    input  logic [3:0]                  AWREGION,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWVALID" *)
    input  logic                        AWVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST AWREADY" *)
    output logic                        AWREADY,

    //=======================
    // Write Data Channel (W)
    //=======================
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST WDATA" *)
    input  logic [DATA_WIDTH-1:0]       WDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST WSTRB" *)
    input  logic [DATA_WIDTH/8-1:0]     WSTRB,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST WLAST" *)
    input  logic                        WLAST,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST WVALID" *)
    input  logic                        WVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST WREADY" *)
    output logic                        WREADY,

    //==========================
    // Write Response Channel (B)
    //==========================
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST BID" *)
    output logic [ID_WIDTH-1:0]         BID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST BRESP" *)
    output logic [1:0]                  BRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST BVALID" *)
    output logic                        BVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST BREADY" *)
    input  logic                        BREADY,

    //============================
    // Read Address Channel (AR)
    //============================
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARID" *)
    input  logic [ID_WIDTH-1:0]         ARID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARADDR" *)
    input  logic [ADDR_WIDTH-1:0]       ARADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARLEN" *)
    input  logic [7:0]                  ARLEN,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARSIZE" *)
    input  logic [2:0]                  ARSIZE,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARBURST" *)
    input  logic [1:0]                  ARBURST,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARLOCK" *)
    input  logic [1:0]                  ARLOCK,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARCACHE" *)
    input  logic [3:0]                  ARCACHE,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARPROT" *)
    input  logic [2:0]                  ARPROT,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARQOS" *)
    input  logic [3:0]                  ARQOS,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARREGION" *)
    input  logic [3:0]                  ARREGION,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARVALID" *)
    input  logic                        ARVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST ARREADY" *)
    output logic                        ARREADY,

    //========================
    // Read Data Channel (R)
    //========================
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST RID" *)
    output logic [ID_WIDTH-1:0]         RID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST RDATA" *)
    output logic [DATA_WIDTH-1:0]       RDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST RRESP" *)
    output logic [1:0]                  RRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST RLAST" *)
    output logic                        RLAST,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST RVALID" *)
    output logic                        RVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_TEST RREADY" *)
    input  logic                        RREADY
);

    localparam MEM_DEPTH = (ADDR_HIGH_BOUND - ADDR_LOW_BOUND + 1) >> 4;
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    initial begin
        if (MEM_FILE == "") begin
            foreach (mem[i]) begin
                mem[i] = $urandom;
            end
        end
        else begin
            $readmemh(MEM_FILE, mem);
        end
        
    end

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

endmodule
