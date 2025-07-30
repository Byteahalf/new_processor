`include "defs.svh"

module fetch #(
    parameter ADDR_WIDTH = `DATA_ADDR_WIDTH,
    parameter DATA_WIDTH = `FETCH_DATA_WIDTH,
    parameter BURST_LENGTH = 4,
    parameter BOOT_ADDR = 'h1000
)(
    input logic                     clk,
    input logic                     rst_n,

    output logic                    co_error, // Error occurs
    output logic                    co_reset_finish, // Reset over
    input logic                     ci_pause, // Pause pipeline
    input logic                     ci_flush, // Reset data
    input logic [ADDR_WIDTH-1:0]    ci_addr,

    //===============================
    // AXI4 Read Address Channel (AR)
    //===============================
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [7:0]              m_axi_arlen,     // Burst length (0 = 1 beat)
    output logic [2:0]              m_axi_arsize,    // 3'b100 = 16 bytes = 128 bits
    output logic [1:0]              m_axi_arburst,   // 2'b01 = INCR
    output logic [3:0]              m_axi_arcache,   // 4'b0011 = cacheable+bufferable
    output logic [2:0]              m_axi_arprot,    // 3'b100 = instruction fetch
    output logic [3:0]              m_axi_arqos,     // default = 0
    output logic [3:0]              m_axi_arregion,  // default = 0
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,

    //============================
    // AXI4 Read Data Channel (R)
    //============================
    input  logic [DATA_WIDTH-1:0]   m_axi_rdata,
    input  logic [1:0]              m_axi_rresp,
    input  logic                    m_axi_rlast,
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready,

    // FIFO output
    input  logic                   rd_en,
    output logic                   rd_valid,
    output logic [DATA_WIDTH-1:0]  instr,
    output logic [$bits(fifo_fetch_to_decode_param_t)-1:0] param,
    output logic                   empty,


);
    //============================
    //       Main Trigger
    //============================

    logic start_next_fetch;
    logic first_pack_valid, first_pack_ready;
    logic update_addr_req;
    logic [ADDR_WIDTH-1:0] next_addr;
    logic fifo_rst_n, axi_rst_n;

    //============================
    //     Address Alignment
    //============================
    int w8b = $clog2(DATA_WIDTH / 8);
    int w16b = $clog2(DATA_WIDTH / 16);

    logic [w8b-1:0] mask = {w8b{1'b1}};
    wire next_addr_is_align = (mask & next_addr == 0);
    wire next_addr_offset   = w16b - ((mask & next_addr) >> 1) - 1;
    wire error_next_addr_not_align = next_addr & 1'b1;
    //============================
    //        FIFO Defs
    //============================

    logic [DATA_WIDTH-1:0] instr_din;
    fifo_fetch_to_decode_param_t param_din;
    logic wr_en;
    logic full, instr_full, param_full;
    assign full = instr_full & param_full;
    logic instr_empty, param_empty;
    assign empty = instr_empty & param_empty;
    logic almost_empty;
    
    sync_fifo #(
        .DATA_WIDTH     (DATA_WIDTH),
        .DEPTH          (8)
    ) instr_sync_fifo (
        .clk            (clk),
        .rst_n          (fifo_rst_n),
        .wr_en          (wr_en),
        .rd_en          (rd_en),
        .rd_valid       (rd_valid),
        .din            (instr_din),
        .dout           (instr),
        .full           (instr_full),
        .empty          (instr_empty),
        .almost_empty   (almost_empty)
    );
    
    sync_fifo #(
        .DATA_WIDTH     ($bits(fifo_fetch_to_decode_param_t)),
        .DEPTH          (8)
    ) param_sync_fifo (
        .clk            (clk),
        .rst_n          (fifo_rst_n),
        .wr_en          (wr_en),
        .rd_en          (rd_en),
        .rd_valid       (rd_valid),
        .din            (param_din),
        .dout           (param),
        .full           (param_full),
        .empty          (param_empty)
    );

    //============================
    //       AXI config
    //============================

    always_comb begin
        m_axi_arburst = 2'b01;
        m_axi_arcache = 4'b0011;
        m_axi_arprot = 3'b100;
        m_axi_arqos = 4'b0;
        m_axi_arregion = 4'b0;
        m_axi_arlen = 4'h3;
    end

    //============================
    //        FSM for AXI
    //============================

    logic axi_is_running;
    logic axi_hanging;

    typedef enum logic [1:0] {
        IDLE,
        WRITE_ADDR,
        READ_DATA
    } state_t;

    state_t curr_state, next_state;

    always_ff @(posedge clk) begin
        if (!axi_rst_n)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

    always_comb begin
        next_state = curr_state;
        case(curr_state)
            IDLE: if (start_next_fetch) next_state = WRITE_ADDR;
            WRITE_ADDR: if(m_axi_arready) next_state = READ_DATA;
            READ_DATA: if (m_axi_rready & m_axi_rlast) next_state = IDLE;
        endcase
    end

    always_comb begin
        axi_is_running =1;
        m_axi_arvalid = 0;
        m_axi_araddr = 0;
        m_axi_rvalid = 0;
        wr_en = 0;
        instr_din = 0;
        first_pack_ready = 0;
        param_din = 0;

        case(curr_state)
            IDLE: begin
                axi_is_running = 0;
            end
            WRITE_ADDR: begin
                m_axi_arvalid = 1;
                m_axi_araddr = next_addr;
            end
            READ_DATA: begin
                m_axi_rvalid = ~axi_hanging & 1;
                wr_en = m_axi_rready & m_axi_rvalid;
                instr_din = m_axi_rdata;
                first_pack_ready = first_pack_valid;
                param_din.is_first = first_pack_valid;
                param_din.byte_valid = next_addr_offset;
            end
        endcase
    end

    //============================
    //    Start Triggrt
    //============================
    // Reset: Close FIFO and AXI immediately
    // Pause: Hanging AXI, Keep FIFO
    // Flush: Waiting current Trans over, Reset FIFO
    //============================

    typedef enum logic [1:0] {
        RESET,
        FLUSH
    } boot_reason_t;

    logic boot_req;
    boot_reason_t boot_reason;

    // Reset & Hang Control
    always_comb begin
        axi_rst_n = 0;
        fifo_rst_n = 0;
        if(!rst_n) begin // Reset
            axi_rst_n = 1;
            fifo_rst_n = 1;
        end
        else if (ci_pause) begin // Pause
            axi_hanging = 1;
        end
        else if (ci_flush) begin // Flush
            fifo_rst_n = 1;
            axi_rst_n = ~axi_is_running;
        end
    end

    // Restart Pipeline Control
    always_ff @(posedge clk) begin
        if (!rst_n) begin // Reset
            boot_req <= 1;
            boot_reason <= RESET;
        end
        else if (ci_pause) begin // Pause
            ;
        end
        else if (ci_flush) begin // Flush
            boot_req <= 1;
            boot_reason <= FLUSH;
        end
        else if(boot_req & start_next_fetch) begin
            boot_req <= 0;
        end
    end

    // Restart boot Control
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            start_next_fetch <= 0;
        end
        else begin
            if (boot_req) begin
                start_next_fetch <= 1;
            end
            else if (start_next_fetch & (next_state == WRITE_ADDR)) begin
                start_next_fetch <= 0;
            end
        end
    end

    // Address Control
    logic [ADDR_WIDTH-1:0] reverse_mask = mask;
    always_ff @(posedge clk) begin
        if (!rst_n)         next_addr <= BOOT_ADDR;
        else if (ci_flush)  next_addr <= ci_addr;
        else if (m_axi_rlast) next_addr <= next_addr & ~reverse_mask;
    end

endmodule