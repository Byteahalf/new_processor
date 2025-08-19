`include "defs.svh"

//============================
//       Decode Module
//============================
// 1. FIFO Combination
// 2. Chain Decode
// 3. Output
//============================

module decode#(    
    parameter DATA_WIDTH = `FETCH_DATA_WIDTH,
    parameter DATA_ADDR_WIDTH = `DATA_ADDR_WIDTH,
    parameter DECODE_ISSUE_WIDTH = 4 // Fixed value, DO NOT CHANGE
)(
    //============================
    //        Global Signal
    //============================
    input logic                                             clk,
    input logic                                             rst_n,

    //============================
    //       Control Port
    //============================
    input logic                                             ci_flush,

    //============================
    //        From fetch
    //============================
    output logic                                            fetch_rd_en,
    input logic                                             fetch_rd_valid,
    input logic [DATA_WIDTH-1:0]                            fetch_instr,
    input logic [$bits(fifo_fetch_to_decode_param_t)-1:0]   fetch_param,
    input logic                                             fetch_empty,

    //============================
    //       ALU Channel 0
    //============================
    output logic                                            decode_c0_valid,
    input logic                                             decode_c0_next,
    output logic                                            decode_c0_data,

    //============================
    //       ALU Channel 1
    //============================
    output logic                                            decode_c1_valid,
    input logic                                             decode_c1_next,
    output logic                                            decode_c1_data,

    //============================
    //       ALU Channel 2
    //============================
    output logic                                            decode_c2_valid,
    input logic                                             decode_c2_next,
    output logic                                            decode_c2_data,

    //============================
    //       ALU Channel 3
    //============================
    output logic                                            decode_c3_valid,
    input logic                                             decode_c3_next,
    output logic                                            decode_c3_data,



);
    //============================
    //        Global Defs
    //============================
    localparam MAX_INSTR_BUFFER_WIDTH = 32 * DECODE_ISSUE_WIDTH;
    localparam INSTR_BUFFER_WIDTH = 1 << $clog2(MAX_INSTR_BUFFER_WIDTH + (| (MAX_INSTR_BUFFER_WIDTH & (MAX_INSTR_BUFFER_WIDTH-1))));
    localparam INSTR_SECTION_WIDTH = (INSTR_BUFFER_WIDTH * 2) / 16;
    localparam INSTR_SECTION_WIDTH_WIDTH = $clog2(INSTR_SECTION_WIDTH);

    wire fifo_fetch_to_decode_param_t fetch_fifo_param = fetch_param;
    logic fetch_rd_en_init, fetch_rd_en_load;
    logic decode_running_state;
    logic system_paused;
    logic system_reset;

    genvar gi;

    always_comb begin
        system_paused = ~rst_n | ci_flush;
        system_reset = ~rst_n | ci_flush;
    end

    always_comb begin
        fetch_rd_en = fetch_rd_en_init || fetch_rd_en_load;
    end

    
    //============================
    //        Main Init FSM
    //============================

    typedef enum logic[1:0] { 
        IDLE,
        LOAD0,
        LOAD1,
        RUNNING
    } state_t;
    state_t curr_state, next_state;

    always_ff @(posedge clk) begin
        if(system_reset) begin
            curr_state <= IDLE;
        end
        else begin
            curr_state <= next_state;
        end
    end

    always_comb begin
        next_state = curr_state;
        case(curr_state)
            IDLE: next_state = LOAD0;
            LOAD0: if(fetch_rd_en & fetch_rd_valid) begin
                next_state = LOAD1;
            end
            LOAD1: if(fetch_rd_en & fetch_rd_valid) begin
                next_state = RUNNING;
            end
            RUNNING: next_state = RUNNING;
        endcase
    end

    always_comb begin
        fetch_rd_en_init = ((curr_state == LOAD0) || (curr_state == LOAD1));
        decode_running_state = (curr_state == RUNNING);
    end


    //============================
    //     FIFO Defs
    //============================
    logic [INSTR_BUFFER_WIDTH * 2 - 1:0] instr_fifo; // Main FIFO
    logic [31:0] instr_fifo_mem [0:INSTR_SECTION_WIDTH-2];
    logic instr_fifo_valid; // FIFO Full Valid
    logic [INSTR_SECTION_WIDTH_WIDTH-1:0] instr_fifo_addr [0:DECODE_ISSUE_WIDTH]; // Address Chain (0-15)
    logic [$clog2(DECODE_ISSUE_WIDTH)-1:0] instr_fifo_read_addr; // Address's Address (The order of Chain)
    logic instr_fifo_compressed [0:INSTR_SECTION_WIDTH - 1]; // Compressed instruction Flag
    logic [DATA_ADDR_WIDTH-1:0] instr_fifo_base_addr, instr_fifo_next_base_addr;

    generate for(gi = 0; gi < INSTR_SECTION_WIDTH - 1; gi++)
        always_comb begin
            instr_fifo_mem[gi] = instr_fifo[gi * 16 + 31: gi * 16];
        end
    endgenerate
    

    //----------------------------
    //     COMPRESS CALC
    //----------------------------
    generate for(gi = 0; gi < INSTR_SECTION_WIDTH; gi++)
        always_comb begin
            instr_fifo_compressed[gi] = ~&{instr_fifo[16 * gi + 1: 16 * gi]};
        end
    endgenerate
    
    
    //============================
    //     STAGE1: FIFO MOVE
    //============================
    logic instr_fifo_update_request;
    logic [INSTR_SECTION_WIDTH_WIDTH-1:0] next_addr;
    logic instr_fifo_address_overflow, instr_fifo_address_overflow_reg;
    logic [INSTR_SECTION_WIDTH_WIDTH-1:0] real_next_addr;

    // Decide Flip & Next Address
    always_comb begin
        real_next_addr = instr_fifo_addr[instr_fifo_read_addr];
        instr_fifo_address_overflow = real_next_addr[INSTR_SECTION_WIDTH_WIDTH-1];
        next_addr = real_next_addr & ~4'('b1 << (INSTR_SECTION_WIDTH_WIDTH - 1));
        fetch_rd_en_load = instr_fifo_address_overflow || instr_fifo_address_overflow_reg;
    end

    // FIFO Manage
    always_ff @(posedge clk) begin
        if(system_reset) begin
            instr_fifo_valid <= 0;
            instr_fifo_address_overflow_reg <= 0;
        end
        else begin
            case(curr_state)
                RUNNING: begin
                    if(curr_state == RUNNING) begin // lut6, OK
                        if(instr_fifo_address_overflow || instr_fifo_address_overflow_reg) begin
                            if(fetch_rd_valid) begin
                                instr_fifo[INSTR_BUFFER_WIDTH - 1:0] <= instr_fifo[INSTR_BUFFER_WIDTH * 2 - 1:INSTR_BUFFER_WIDTH];
                                instr_fifo[INSTR_BUFFER_WIDTH * 2 - 1:INSTR_BUFFER_WIDTH] <= fetch_instr;
                                instr_fifo_valid <= 1;
                                instr_fifo_address_overflow_reg <= 0;
                            end
                            else begin
                                instr_fifo_address_overflow_reg <= instr_fifo_address_overflow;
                                instr_fifo_valid <= 0;
                            end
                        end
                    end
                end
                LOAD0: begin
                    if(fetch_rd_valid) begin
                        instr_fifo[INSTR_BUFFER_WIDTH - 1:0] <= fetch_instr;
                        instr_fifo_valid <= 0;
                        instr_fifo_address_overflow_reg <= 0;
                    end
                end
                LOAD1: begin
                    if(fetch_rd_valid) begin
                        instr_fifo[INSTR_BUFFER_WIDTH * 2 - 1:INSTR_BUFFER_WIDTH] <= fetch_instr;
                        instr_fifo_valid <= 1;
                        instr_fifo_address_overflow_reg <= 0;
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if(system_reset) begin
            instr_fifo_base_addr <= '0;
            instr_fifo_next_base_addr <= '0;
        end
        else begin
            if(fetch_rd_en & fetch_rd_valid) begin
                instr_fifo_base_addr <= instr_fifo_next_base_addr;
                instr_fifo_next_base_addr <= {fetch_fifo_param.base_addr[DATA_ADDR_WIDTH-1:4], 4'b0};
            end
        end
    end

    // Address Calc
    always_comb begin
        for(integer i = 0; i < DECODE_ISSUE_WIDTH; i++) begin
            logic compressed = instr_fifo_compressed[instr_fifo_addr[i]];
            if(compressed) begin
                instr_fifo_addr[i + 1] <= instr_fifo_addr[i] + 1;
            end
            else begin
                instr_fifo_addr[i + 1] <= instr_fifo_addr[i] + 2;
            end
            
        end
    end

    // Address Update
    always @(posedge clk) begin
        if(system_reset) begin
            instr_fifo_addr[0] <= 0;
        end
        else if(curr_state == LOAD0 && fetch_rd_valid && instr_fifo_valid) begin
            instr_fifo_addr[0] <= fetch_fifo_param.base_addr[3:1];
        end
        else if(curr_state == RUNNING && instr_fifo_valid) begin
            instr_fifo_addr[0] <= next_addr;
        end
    end

    //============================
    //DECODE COMPRESSED & DISPATCH
    //============================
    typedef struct {
        logic [31:0] op;
        logic [DATA_ADDR_WIDTH-1:0] addr;
        logic compressed;
        logic valid;
    } decode_section_t;
    decode_section_t decode_section [0:DECODE_ISSUE_WIDTH-1];

    decode_ctrl_t decode_ctrl [0:DECODE_ISSUE_WIDTH-1];

    generate for(gi = 0; gi < DECODE_ISSUE_WIDTH; gi++)
        always_ff @(posedge clk) begin
            logic [INSTR_SECTION_WIDTH_WIDTH-1:0] addr = instr_fifo_addr[gi];
            if(!rst_n) begin
                decode_section[gi].op <= '0;
                decode_section[gi].addr <= '0;
                decode_section[gi].compressed <= '0;
                decode_section[gi].valid <= '0;
            end
            else begin
                decode_section[gi].op <= instr_fifo_mem[addr];
                decode_section[gi].addr <= instr_fifo_base_addr + (addr << 1);
                decode_section[gi].compressed <= instr_fifo_compressed[addr];
                decode_section[gi].valid <= instr_fifo_valid;
            end
        end
    endgenerate

    generate for(i = 0;i < DECODE_ISSUE_WIDTH; i++)
        always_comb begin
            logic [31:0] raw = decode_section[i].op;
            decode_ctrl_t new_data = '0;
            new_data.op = OP_ILLEGAL;
            new_data.rd = raw[11:7];
            new_data.rs1 = raw[19:15];
            new_data.rs2 = raw[24:20];
            new_data.is_un

            if(decode_section[i].compressed) begin

            end
            else begin
                case(raw[6:2])
                    5'b01101: begin

                    end
                endcase
            end

            decode_ctrl[i] = new_data;
        end
    endgenerate

    
endmodule