from .moduleblock import ModuleBlock    

# 需要实现:
# 4 ALU
# 2 MUL
# 1 LS
# 1 FPU
# 1 VPU
# 1 Branch

# 集成：寄存器数据依赖、等待 bypass路径

class ProcessUnit(ModuleBlock):
    pass

class ALU(ProcessUnit):
    def __init__(self):
        self.instr = None

    def update(self):
        self.