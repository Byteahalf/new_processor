from . import register




class DataFlow(): # 仅用于可能需要仿存的计算 
    def __init__(self, vtype: int, /, reg: int = None, reg_id: int = None, mem_addr: int = None, imm: int = None, csr: int = None):
        self.vtype: int = vtype
        self.reg: int = reg
        self.reg_id: int = reg_id
        self.mem_addr: int = mem_addr
        self.imm: int = imm
        self.csr: int = csr

class ALU_param():
    x = 1
    y = 2

class InstrUnit():
    def __init__(self, reg, mem):
        self.src: list[DataFlow] = []
        self.dst: list[DataFlow] = []
        self.pc_src:list[DataFlow] = []
        self.op: int = 0
        self.alu_alloc = ''
        self.init = 1
        self.instr_delay = 0
        self.delay = 0
        self.regs: register.RegisterGroup = reg
        self.pc = False
        self.order = 0

    def read_reg(self, s_index: int):
        if len(self.src) <= s_index:
            raise NotImplementedError("Read Register: Index Error")
        src = self.src[s_index]
        return self.regs[src.target]
    
    def write_dst(self, value):
        for dst in self.dst:
            dst.value = value


