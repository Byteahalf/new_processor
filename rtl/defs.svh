`define FPGA_OPTIMIZE 0

`define DATA_ADDR_WIDTH 40

`define FETCH_DATA_WIDTH 128

`define XLEN 64

typedef struct packed {
    logic [`DATA_ADDR_WIDTH-1:0] base_addr;
    logic                        is_first;
} fifo_fetch_to_decode_param_t;

typedef enum logic [4:0] {
    OP_ILLEGAL,
    OP_LUI, OP_AUIPC,
    OP_JAL, OP_JALR,
    OP_BRANCH,
    OP_LOAD, OP_STORE,
    OP_OPIMM, OP_OP,
    OP_AMO,
    OP_FLOAD, OP_FSTORE,
    OP_FOP,
    OP_SYSTEM,     // ECALL/EBREAK/WFI/CSR*
    OP_FENCE,      // FENCE / FENCE.I (Zifencei)
    OP_VEC         // Vector category (dispatch to V-pipe)
} op_t;

typedef enum logic [3:0] {
    ALU_PASS,
    ALU_ADDSUB,
    ALU_LOGIC,
    ALU_SHIFT,
    ALU_SLT,
    ALU_MUL,
    ALU_DIVREM
} alu_kind_t;

typedef enum logic [2:0] {
    MEM_B, MEM_H, MEMW, MEM_D
} mem_size_t;

typedef struct packed {
    op_t       op;
    alu_kind_t  alu_kind;
    logic [`DATA_ADDR_WIDTH-1:0] addr;

    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [20:0] imm;

    logic [2:0] funct3;
    logic [6:0] funct7;

    // Memory info
    logic       is_load;
    logic       is_store;
    mem_size_t  mem_size;
    logic       mem_unsigned;

    // Control-flow
    logic       is_branch;
    logic       is_jump;

    // System / CSR
    logic       is_csr;
    logic [11:0] csr_addr;

    // Atomics / Fence
    logic       is_amo;
    logic       is_fence;

    // FP / Vector tags (lightweight flags for dispatch)
    logic       is_fp;
    logic       is_vec;

    // Legality
    logic       illegal;
} decode_ctrl_t;