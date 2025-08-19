import os, sys
import numpy as np
from .register import register
from . import decode
from .util import *

MEM_FILE = f"{os.path.dirname(__file__)}/../binary/main.mem"

def addr_to_offset(addr:int) -> int:
    '''
    Convert address to memory offset
    '''
    return addr // 2

def offset_to_addr(offset:int) -> int:
    '''
    Convert memory offset to address
    '''
    return offset * 2

def core(mem):
    ############
    # Register #
    ############
    gpr = register(32, zero=True)
    fpr = register(32, zero=False)
    vpr = register(32, zero=False)

    ################
    # Read Program #
    ################
    i = 0
    addr = 0
    human_code = []

    # ASM
    # Debug Only
    while(i < len(mem)):
        if i == len(mem) - 1:
            opcode = mem[i]
        else:
            opcode = (mem[i+1] << 16) + mem[i]
        compress, code = decode.decode_to_human(opcode)
        opcode = opcode & 0xffff if compress else opcode
        human_code.append(f"{addr:08x}: {opcode:08x} {code}")
        if compress:
            i += 1
            addr += 2
        else:
            i += 2
            addr += 4
    with open("main.asm", "w", encoding='utf-8') as f:
        f.write('\n'.join(human_code))

    next_addr = 0
    decode_list = []
    exec_list = []
    pending_list = []
    while(True):
        next_addr_t = next_addr
        next_addr_l = []
        for i in range(4):
            if mem[next_addr_t] & 0b11 == 3:
                decode_list.append(decode_full((mem[next_addr_t+1] << 16) + mem[next_addr_t]))
                next_addr_t += 2
                next_addr_l.append(next_addr_t)
            else:
                decode_list.append(decode_c(mem[next_addr_t]))
                next_addr_t += 1
                next_addr_l.append(next_addr_t)
        
        for command in decode_list:
            # Check source usage
            if reg_flag[command.src].busy:
                continue
             
            

    
    
if __name__ == '__main__':
    mem = readmemh(MEM_FILE)
    core(mem)
    pass