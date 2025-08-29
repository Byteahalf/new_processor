import os, sys
import numpy as np
from .register import Register, RegisterGroup
from .decode import DecodeBlock
from .util import *
from .instr_unit import InstrUnit

MEM_FILE = f"{os.path.dirname(__file__)}/../binary/main.mem"

def addr2index(addr):
    return addr * 2

def index2addr(index):
    return (index >> 1)

def core(mem):
    ############
    # Register #
    ############
    gpr = Register(32, zero=True)
    fpr = Register(32, zero=False)
    vpr = Register(32, zero=False)

    decoder = DecodeBlock()

    ##############
    # DEASSEMBLY #
    ##############
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
        compress, code = decoder.decode_to_human(opcode, addr)
        opcode = opcode & 0xffff if compress else opcode
        human_code.append(f"{addr:08x}: {opcode:08x} {code[0]}")
        if compress:
            i += 1
            addr += 2
        else:
            i += 2
            addr += 4
    with open("main.asm", "w", encoding='utf-8') as f:
        f.write('\n'.join(human_code))

    next_addr = 0
    addr = 0
    # 所有的名称都是结果
    decode_fifo = []
    rob_fifo = []


    while(True):
        # [2] 分配 Rob
        for i in decode_fifo:
            if
        # [1] 译码 4发射
        for i in range(4):
            index = addr2index(next_addr)
            opcode = (mem[index + 1] << 16) | mem[index]
            compress, code = decoder.decode_to_human(opcode)
            if compress:
                next_addr += 2
            else:
                next_addr += 4
            if code[1] is None:
                raise NotImplementedError("Decode: Undecoded Instruction")
            decode_fifo.append(code[1])
        



             
            

    
    
if __name__ == '__main__':
    mem = readmemh(MEM_FILE)
    core(mem)
    pass