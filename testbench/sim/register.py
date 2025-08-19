class register():
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