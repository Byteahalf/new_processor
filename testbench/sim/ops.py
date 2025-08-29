from .instr_unit import *
from .moduleConstant import *
from .util import *
import random

class alu():
    instr: InstrUnit
    result: InstrResult

    def __init__(self):
        self.result = 0
        self.instr = None
        self.result = None

    def set_instr(self, instr: InstrUnit):
        self.instr = instr
        self.result = None
    
    def _pc_effect(self):
        if self.instr.pc_effect.mux_A == PCEffectPortAType.RS1:
            x0 = self.instr.value.rs1
        elif self.instr.pc_effect.mux_A == PCEffectPortAType.PC:
            x0 = self.instr.dataflow.pc
        else:
            raise ValueError("ALU: PC side effect Mux Error")
        return x0 + self.instr.dataflow.imm

    def _mux_A(self) -> int:
        if self.instr.mux_A == AluPortAType.ERROR:
            raise ValueError("ALU: mux_a not set")
        elif self.instr.mux_A == AluPortAType.RS1:
            return self.instr.value.rs1
        elif self.instr.mux_A == AluPortAType.IMM:
            return self.instr.dataflow.imm
        elif self.instr.mux_A == AluPortAType.PC:
            return self.instr.dataflow.pc
        else:
            raise ValueError("ALU: mux_a invalid value")
        
    def _mux_B(self) -> int:
        if self.instr.mux_B == AluPortBType.ERROR:
            raise ValueError("ALU: mux_b not set")
        elif self.instr.mux_B == AluPortBType.EMPTY:
            return 0
        elif self.instr.mux_B == AluPortBType.RS2:
            return self.instr.value.rs2
        elif self.instr.mux_B == AluPortBType.IMM:
            return self.instr.dataflow.imm
        else:
            raise ValueError("ALU: mux_b invalid value")

    def update(self) -> None:
        self.result = InstrResult()
        self.result.order = self.instr.order
        self.result.pc = self.instr.dataflow.pc
        self.result.rd = self.instr.dataflow.rd
        self.result.region = RegisterType.GPR
        self.result.pc_effect = self.instr.pc_effect
        self.result.pc_effect.target = self._pc_effect()

        x0 = self._mux_A()
        x1 = self._mux_B()
        op = AluOpType(self.instr.op & ALU_MASK)
        word = (self.instr.op & (ALU_MASK + 1) != 0)

        shamt = x1 & mask(5 if word else 6)
        
        if op == AluOpType.ADD:
            self.result.value = (x0 + x1) & REGISTER_MASK
        elif op == AluOpType.SLL :
            self.result.value = (x0 << shamt) & REGISTER_MASK
        elif op == AluOpType.SLR:
            self.result.value = ((x0 & REGISTER_MASK) >> shamt) & REGISTER_MASK
        elif op == AluOpType.SLTU:
            self.result.value = 1 if (x0 & REGISTER_MASK) < (x1 & REGISTER_MASK) else 0
        elif op == AluOpType.XOR:
            self.result.value = (x0 ^ x1) & REGISTER_MASK
        elif op == AluOpType.SRL:
            self.result.value = ((x0 & REGISTER_MASK) >> x1) & REGISTER_MASK
        elif op == AluOpType.OR:
            self.result.value = (x0 | x1) & REGISTER_MASK
        elif op == AluOpType.AND:
            self.result.value = (x0 & x1) & REGISTER_MASK
        elif op == AluOpType.SUB:
            self.result.value = (x0 - x1) & REGISTER_MASK
        elif op == AluOpType.SRA:
            self.result.value = (sext(x0) >> shamt) & REGISTER_MASK
        elif op == AluOpType.BYPASS:
            self.result.value = x0 & REGISTER_MASK

class MduInstr():
    instr: InstrUnit
    latency: int = -1

class MDU():
    result: InstrResult
    fifo: list[MduInstr]
    output_fifo: list[InstrUnit]

    def __init__(self):
        self.result = None
        self.fifo = [] # 模拟计算队列

    def _check_instr(self, instr: InstrUnit) -> str:
        if instr.op in [MduOpType.MUL, MduOpType.MULH, MduOpType.MULHSU, MduOpType.MULHU]:
            return 'MUL'
        elif instr.op in [MduOpType.DIV, MduOpType.DIVU, MduOpType.REM, MduOpType.REMU]:
            return 'DIV'
        else:
            raise ValueError("MDU: Instr OP Error")
    
    def set_instr(self, instr: InstrUnit):
        # 检查乘除法 设定不同的延迟
        op_type = self._check_instr(instr)
        mdu_instr = MduInstr()
        mdu_instr.instr = instr
        if op_type == 'MUL':
            mdu_instr.latency = 5
        elif op_type == 'DIV':
            mdu_instr.latency = random.randint(18, 45)

    def update(self, next_instr = True) -> None:
        has_output = False
        remove_k = None
        for k, i in enumerate(self.fifo):
            if i.latency > 0:
                i.latency -= 1
            
            if i.latency == 0:
                if has_output:
                    continue
                if not next_instr:
                    continue
                self.result = self._process(i)
                has_output = True
                remove_k = k

        if remove_k is not None:
            self.fifo.pop(remove_k)

    def _process(self, instr: InstrUnit) -> InstrResult:
        result = InstrResult()
        result.order = instr.order
        result.pc = instr.dataflow.pc
        result.rd = instr.dataflow.rd
        result.region = RegisterType.GPR

        x0 = instr.value.rs1
        x1 = instr.value.rs2
        op = instr.op

        if op == MduOpType.MUL:
            result.value = (x0 * x1) & REGISTER_MASK
        elif op == MduOpType.MULH:
            # 有符号 * 有符号，取高 XLEN 位
            a = sext(x0, XLEN)
            b = sext(x1, XLEN)
            prod = a * b
            result.value = (prod >> XLEN) & REGISTER_MASK
        elif op == MduOpType.MULHSU:
            # 有符号 * 无符号，取高 XLEN 位
            a = sext(x0, XLEN)
            b = x1 & REGISTER_MASK
            prod = a * b
            result.value = (prod >> XLEN) & REGISTER_MASK
        elif op == MduOpType.MULHU:
            # 无符号 * 无符号，取高 XLEN 位
            a = x0 & REGISTER_MASK
            b = x1 & REGISTER_MASK
            prod = a * b
            result.value = (prod >> XLEN) & REGISTER_MASK
        elif op == MduOpType.DIV:
            a = sext(x0, XLEN)
            b = sext(x1, XLEN)
            if b == 0:
                result.value = -1 & REGISTER_MASK
            elif a == -(1 << (XLEN - 1)) and b == -1:
                # 溢出情况，结果 = 被除数
                result.value = a & REGISTER_MASK
            else:
                result.value = (a // b) & REGISTER_MASK
        elif op == MduOpType.DIVU:
            a = x0 & REGISTER_MASK
            b = x1 & REGISTER_MASK
            if b == 0:
                result.value = REGISTER_MASK  # 全 1
            else:
                result.value = (a // b) & REGISTER_MASK
        elif op == MduOpType.REM:
            a = sext(x0, XLEN)
            b = sext(x1, XLEN)
            if b == 0:
                result.value = a & REGISTER_MASK
            elif a == -(1 << (XLEN - 1)) and b == -1:
                result.value = 0
            else:
                result.value = (a % b) & REGISTER_MASK
        elif op == MduOpType.REMU:
            a = x0 & REGISTER_MASK
            b = x1 & REGISTER_MASK
            if b == 0:
                result.value = a
            else:
                result.value = (a % b) & REGISTER_MASK
        return result
                