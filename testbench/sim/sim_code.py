import os, sys
import numpy as np
from .register import Register, RegisterGroup
from . import decode
from .util import *
from .instr_unit import InstrUnit

MEM_FILE = f"{os.path.dirname(__file__)}/../binary/main.mem"

def addw(rs1: int, imm: int) -> int:
    """模拟 RISC-V ADDIW 指令"""
    # 1. 截取 rs1 低 32 位并作为有符号数
    low32 = to_signed32(rs1)
    # 2. 执行 32 位加法
    result32 = to_signed32(low32 + imm)
    # 3. 符号扩展到 64 位
    return sign_extend_32_to_64(result32)


def core(mem):
    ############
    # Register #
    ############
    gpr = Register(32, zero=True)
    fpr = Register(32, zero=False)
    vpr = Register(32, zero=False)

    regs = RegisterGroup(gpr, fpr, vpr)

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

    #######
    # RUN #
    #######

    # DECODE -> DECODE_PENDING (OPT) -> EXEC -> WRITEBACK
    # 从后往前更新

    # ALU
    # A: { RS1, PC, MEMRD, CSR_RD }
    # B: { RS2, IMM, RS1 }
    # R: { GPR, CSR_WR, PC, LSU, }

    next_addr = 0



    while(True):
        # Write Back Update
        for instr in write_back_list:
            for dst in instr.dst:
                pass

        # Exec Update
        for instr in exec_list:
            otype = instr.op.otype
            op = instr.op.op
            if otype == 'FLOAT':
                if op == 'ADD':
                    instr
            elif otype == 'INT':
                if op == 'ADD':
                     instr.write_dst(wrap(rs1 + op2, xlen))
                if op == 'ADDW':
                    instr.write_dst(addw(instr.read_reg(0) &  + instr.read_reg(1)))
                elif op == 'SUB':
                    instr.write_dst(instr.read_reg(0) - instr.read_reg(1))
                elif op == 'ADD'
            elif instr.op.otype == 'VECTOR':
                pass
            else:
                raise NotImplementedError("Execution type error.")


             
            

    
    
if __name__ == '__main__':
    mem = readmemh(MEM_FILE)
    core(mem)
    pass