`include "defs.svh"

module fetch #(
    parameter ADDR_WIDTH = `DATA_ADDR_WIDTH,
    parameter DATA_WIDTH = `FETCH_DATA_WIDTH,
    parameter BURST_LENGTH = 4,
    parameter BOOT_ADDR = 'h0
)(
    input logic                     clk,
    input logic                     rst_n,

    output logic                    co_error, // Error occurs
    output logic [2:0]              co_error_code, // Error Code
    output logic                    co_reset_finish, // Reset over
    input logic                     ci_pause, // Pause pipeline
    input logic                     ci_flush_request, // Reset data
    output logic                    co_flush_response,
    input logic [ADDR_WIDTH-1:0]    ci_addr,

    //===============================
    // AXI4 Read Address Channel (AR)
    //===============================
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [7:0]              m_axi_arlen,
    output logic [2:0]              m_axi_arsize,
    output logic [1:0]              m_axi_arburst,
    output logic [3:0]              m_axi_arcache,
    output logic [2:0]              m_axi_arprot,
    output logic [3:0]              m_axi_arqos,
    output logic [3:0]              m_axi_arregion,
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
    input  logic                   fetch_rd_en,
    output logic                   fetch_rd_valid,
    output logic [DATA_WIDTH-1:0]  fetch_instr,
    output logic [$bits(fifo_fetch_to_decode_param_t)-1:0] fetch_param,
    output logic                   fetch_empty
);
    //============================
    //       Main Trigger
    //============================

    logic paused;
    logic first_pack_valid, first_pack_ready;
    logic update_addr_req;
    logic [ADDR_WIDTH-1:0] next_addr;
    logic fifo_rst_n, axi_rst_n;

    //============================
    //     Address Alignment
    //============================
    localparam int w8b = $clog2(DATA_WIDTH / 8);
    localparam int w16b = $clog2(DATA_WIDTH / 16);

    localparam logic [w8b-1:0] mask = {w8b{1'b1}};
    localparam logic [ADDR_WIDTH-1:0] incr_addr = (1 << w8b);
    localparam logic [DATA_WIDTH-1:0] full_width_mask = mask;

    logic [ADDR_WIDTH-1:0] curr_addr_reg;

    wire error_next_addr_not_align = next_addr & 1'b1;
    wire error_resp_not_valid = m_axi_rresp & m_axi_rready & m_axi_rvalid;
    //============================
    //        FIFO Defs
    //============================

    localparam int FIFO_DEPTH = 16;
    localparam int FIFO_ALMOST_EMPTY_THRESOLD = 4;

    logic [DATA_WIDTH-1:0]          instr_din;
    fifo_fetch_to_decode_param_t    param_din;
    logic                           wr_en;
    logic                           full, instr_full, param_full;
    assign                   full = instr_full & param_full;
    logic                           instr_empty, param_empty;
    assign                  empty = instr_empty & param_empty;
    logic                           almost_empty;
    logic                           instr_rd_valid, param_rd_valid;
    assign         fetch_rd_valid = instr_rd_valid & param_rd_valid;
    logic [$clog2(FIFO_DEPTH): 0]   instr_data_count, param_data_count;
    wire   error_fifo_valid_error = (instr_data_count != param_data_count);
    
    sync_fifo #(
        .DATA_WIDTH     (DATA_WIDTH),
        .DEPTH          (FIFO_DEPTH),
        .AE_THRESH      (FIFO_ALMOST_EMPTY_THRESOLD)
    ) instr_sync_fifo (
        .clk            (clk),
        .rst_n          (fifo_rst_n),
        .wr_en          (wr_en),
        .rd_en          (fetch_rd_en),
        .rd_valid       (instr_rd_valid),
        .din            (instr_din),
        .dout           (fetch_instr),
        .full           (instr_full),
        .empty          (instr_empty),
        .almost_empty   (almost_empty),
        .data_count     (instr_data_count)
    );
    
    sync_fifo #(
        .DATA_WIDTH     ($bits(fifo_fetch_to_decode_param_t)),
        .DEPTH          (FIFO_DEPTH),
        .AE_THRESH      (FIFO_ALMOST_EMPTY_THRESOLD)
    ) param_sync_fifo (
        .clk            (clk),
        .rst_n          (fifo_rst_n),
        .wr_en          (wr_en),
        .rd_en          (fetch_rd_en),
        .rd_valid       (param_rd_valid),
        .din            (param_din),
        .dout           (fetch_param),
        .full           (param_full),
        .empty          (param_empty),
        .data_count     (param_data_count)
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
        m_axi_arsize = BURST_LENGTH;
    end

    //============================
    //        FSM for AXI
    //============================

    logic axi_is_first_trans;

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
            IDLE:       if (!paused & almost_empty) next_state = WRITE_ADDR;
            WRITE_ADDR: if (m_axi_arready & m_axi_arvalid) next_state = READ_DATA;
            READ_DATA:  if (m_axi_rvalid & m_axi_rlast & m_axi_rready) next_state = IDLE;
        endcase
    end

    always_comb begin
        m_axi_arvalid = 0;
        m_axi_araddr = 0;
        m_axi_rready = 0;
        wr_en = 0;
        instr_din = 0;
        first_pack_ready = 0;
        param_din = 0;
        co_flush_response = 0;

        case(curr_state)
            IDLE: begin
                co_flush_response = ci_flush_request;
            end
            WRITE_ADDR: begin
                m_axi_arvalid = 1;
                m_axi_araddr = next_addr;
            end
            READ_DATA: begin
                m_axi_rready = ~paused & 1;
                wr_en = m_axi_rready & m_axi_rvalid;
                instr_din = m_axi_rdata;
                first_pack_ready = first_pack_valid & m_axi_rready & m_axi_rvalid;
                param_din.is_first = first_pack_valid;
                param_din.base_addr = first_pack_valid ? next_addr : curr_addr_reg;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (curr_state == WRITE_ADDR & next_state == READ_DATA) begin
            curr_addr_reg <= next_addr & ~full_width_mask;
            axi_is_first_trans = 1;
        end
        else if (m_axi_rready & m_axi_rvalid) begin
            curr_addr_reg  = curr_addr_reg + incr_addr;
            axi_is_first_trans = 0;
        end
    end

    //============================
    //    Start Triggrt
    //============================
    // Reset: Close FIFO and AXI immediately
    // Pause: Hanging AXI, Keep FIFO
    // Flush: Waiting current Trans over, Reset FIFO
    //============================

    // Reset & Hang Control
    always_comb begin
        axi_rst_n = 1;
        fifo_rst_n = 1;
        paused = 0;
        if(!rst_n) begin // Reset
            axi_rst_n = 0;
            fifo_rst_n = 0;
            paused = 1;
        end
        else if (ci_pause) begin // Pause
            paused = 1;
        end
        else if (ci_flush_request) begin // Flush
            fifo_rst_n = 0;
            paused = 1;
        end
    end

    // Address Control
    logic [ADDR_WIDTH-1:0] reverse_mask = mask;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            next_addr <= BOOT_ADDR;
            first_pack_valid = 1;
        end
        else if (ci_flush_request) begin
            next_addr <= ci_addr;
            first_pack_valid = 1;
        end
        else if (m_axi_rlast & m_axi_rvalid & m_axi_rready) begin
            next_addr <= (next_addr & ~full_width_mask) + incr_addr;
        end
        else if (first_pack_ready & first_pack_valid) begin
            first_pack_valid = 0;
        end

    end

endmodule