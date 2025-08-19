from .moduleConstant import *

class Register():
    def __init__(self, depth:int, zero = True):
        self.zero = zero
        self.mem = [0] * depth
    
    def read(self, addr: int):
        if addr == 0 and self.zero:
            return 0
        else:
            return self.mem[addr]
        
    def write(self, addr:int, data:int):
        if addr == 0 and self.zero:
            pass
        else:
            self.mem[addr] = 0

class RegisterGroup():
    def __init__(self, gpr: Register, fpr: Register, vpr: Register):
        self.gpr: Register = gpr
        self.fpr: Register = fpr
        self.vpr: Register = vpr

    def __getitem__(self, key: any):
        if isinstance(key, int):
            if key == GPR:
                return self.gpr
            elif key == FPR:
                return self.fpr
            elif key == VPR:
                return self.vpr
            