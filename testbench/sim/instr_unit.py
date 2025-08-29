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

class RegisterType(Enum):
    ERROR = -1
    GPR = auto()
    FPR = auto()
    VPR = auto()
    N = auto()

class ExecDataflow():
    imm = 0 # 64-bits
    rs1 = 0
    rs2 = 0
    rs3 = 0
    csr = 0
    pc = 0
    offset = 0
    rd = 0

class ExecPhysical():
    rs1 = 0
    rs2 = 0
    rs3 = 0
    rd = 0

class ExecRegEnable():
    rs1 = False
    rs2 = False
    rs3 = False

class ExecRegion():
    rs1: RegisterType = RegisterType.ERROR
    rs2: RegisterType = RegisterType.ERROR
    rs3: RegisterType = RegisterType.ERROR
    rd: RegisterType = RegisterType.ERROR
     


ALU_MASK = 0b1111
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
    BYPASS = 0b1111
    ADDW = 0b10000
    SUBW = 0b11000
    SLLW = 0b10001
    SRLW = 0b10101
    SRAW = 0b11101

class MduOpType(Enum):
    MUL = 0b000
    MULH = 0b001
    MULHSU = 0b010
    MULHU = 0b011
    DIV = 0b100
    DIVU = 0b101
    REM = 0b110
    REMU = 0b111

class FpuOpType(Enum):
    pass


class AluPortAType(Enum):
    ERROR = -1
    RS1 = auto()
    PC = auto()
    IMM = auto()

class AluPortBType(Enum):
    ERROR = -1
    EMPTY = auto()
    RS2 = auto()
    IMM = auto()

class BranchOpType(Enum):
    '''
       3   |      2      | 1 | 0
    BYPASS | EQ(0) LT(1) | U | NOT
    '''
    ERROR = -1
    EQ = 0b000
    NE = 0b001
    LT = 0b100
    GE = 0b101
    LTU = 0b110
    GEU = 0b111
    BYPASS = 0b1000

class LsuOpType(Enum):
    '''
    | 4 |     3-2     | 1 | 0 |
    | U | 1/2/4/8bits | L | S
    '''
    LB = 0b0_00_1_0
    LH = 0b0_01_1_0
    LW = 0b0_10_1_0
    LD = 0b0_11_1_0
    LBU = 0b1_00_1_0
    LHU = 0b1_01_1_0
    LWU = 0b1_10_1_0
    SB = 0b0_00_0_1
    SH = 0b0_01_0_1
    SW = 0b0_10_0_1
    SD = 0b0_11_0_1

class LsuDataflowType():
    op: LsuOpType = -1
    region: RegisterType = -1

class CsrOpType(Enum):
    ERROR = -1
    RW = 1
    RS = 2
    RC = 3
    RWI = 5
    RSI = 6
    RCI = 7

class InstrValueType():
    rs1 = 0
    rs2 = 0
    rs3 = 0
    rd = 0

class PCEffectPortAType(Enum):
    ERROR = -1
    RS1 = auto()
    PC = auto()

class PCEffectType():
    valid: bool = False
    mux_A: PCEffectPortAType = -1
    target: int = -1

class InterruptType():
    mepc = None # 指令PC
    mcause = None # 原因
    mtval = None # 额外信息

class InstrUnit():
    order: int = 0
    alu: ExecType = -1
    op: AluOpType | BranchOpType | CsrOpType = -1
    lsu_dataflow: LsuDataflowType = LsuDataflowType()
    dataflow: ExecDataflow = ExecDataflow()
    req: ExecRegEnable = ExecRegEnable()
    region: ExecRegion = ExecRegion()
    value: InstrValueType = InstrValueType()
    pc_effect: PCEffectType = PCEffectType()
    mux_A: AluPortAType = -1
    mux_B: AluPortBType = -1
    

class InstrResult():
    order: int = 0
    region: RegisterType = -1
    rd: int = -1
    value: int = -1
    pc: int = -1
    pc_effect: PCEffectType = PCEffectType()