from . import register
from enum import Enum, auto

class ExecType(Enum):
    ERROR = -1
    ALU = auto()
    BRANCH = auto()
    AGU = auto() # PC 更新用
    LSU = auto() # LD, ST
    MDU = auto() # MUL, DIV
    CSR = auto()
    FPU = auto()
    VEC = auto()

class ExecDataflow():
    imm = 0 # 64-bits
    rs1 = 0
    rs2 = 0
    csr = 0
    pc = 0
    offset = 0
    rd = 0


class AluOpType(Enum):
    '''
    SRA 特殊值1 算术右移补符号位 
    SUB 特殊值1 
    | 4 |    3    | 2-0 |
    | W | SUB/SRA |  OP |
    '''
    ERROR = -1
    
    ADD = 0b000
    SLL = 0b001
    SLR = 0b010
    SLTU = 0b011
    XOR = 0b100
    SRL = 0b101
    OR = 0b110
    AND = 0b111
    SUB = 0b1000
    SRA = 0b1101
    ADDW = 0b10000
    SUBW = 0b11000
    SLLW = 0b10001
    SRLW = 0b10101
    SRAW = 0b11101

class AluPortAType():
    RS1 = auto()
    PC = auto()

class PortXType(Enum):
    RD = auto()
    


class AluPortBType():
    RS2 = auto()
    IMM = auto()

class BranchOpType(Enum):
    '''
          2     | 1 | 0
    EQ(0) LT(1) | U | NOT
    '''
    EQ = 0b000
    NE = 0b001
    LT = 0b100
    GE = 0b101
    LTU = 0b110
    GEU = 0b111

class LsuOpType(Enum):
    '''
    | 4 |     3-2     | 1 | 0 |
    | U | 1/2/4/8bits | L | S
    '''
    pass

class PCEffectPortAType(Enum):
    RS1 = auto()
    PC = auto()

class PCEffectType():
    valid: bool = False
    mux_A: PCEffectPortAType

class InstrUnit():
    order: int = 0
    sub_order: int = 0
    alu: ExecType = -1
    op: AluOpType | BranchOpType = -1
    lsu_op: LsuOpType = -1
    dataflow: ExecDataflow = ExecDataflow()
    pc_effect: PCEffectType = PCEffectPortAType()
    mux_A: AluPortAType = -1
    mux_B: AluPortBType = -1
    mux_X: PortXType = -1
    

