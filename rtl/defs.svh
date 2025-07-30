`define FPGA_OPTIMIZE 0

`define DATA_ADDR_WIDTH 40

`define FETCH_DATA_WIDTH 128

typedef struct packed {
    logic [2:0]   byte_valid; 
    logic         is_first;
} fifo_fetch_to_decode_param_t;