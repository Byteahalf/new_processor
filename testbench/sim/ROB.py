# Reordered Buffer 寄存器重命名技术

from .moduleConstant import *

class RobRegisterBase():
    def __init__(self, open_reg = 32, phy_reg = 128, /, zero = False):
        self.zero = zero
        self.mem = [0] * phy_reg
        self.map = list(range(open_reg))
        self.busy = [False] * phy_reg
        self.avaliable_phy_reg = list(range(open_reg, phy_reg))

    def read(self):
        raise NotImplementedError("Method not implemented")
    
    def write(self):
        raise NotImplementedError("Method not implemented")

    def set_busy(self, phy_reg: int):
        self.busy[phy_reg] = True

    def release_busy(self, phy_reg: int):
        self.busy[phy_reg] = False

    def read_busy(self, phy_reg: int):
        return self.busy[phy_reg]
    
    def next_rat(self):
        return self.avaliable_phy_reg.pop(0)
    
    def update_rat(self, reg: int, phy_reg: int):
        self.avaliable_phy_reg.append(self.map[reg])
        self.map[reg] = phy_reg

class RobGPR(RobRegisterBase):
    

class RobRegisterGroup():
    pass