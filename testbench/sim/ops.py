class alu():
    def __init__(self):
        self.result = 0

    def write(self, op, a, b):
        self.op = op
        self.a = a
        self.b = b

    def update(self):
        if self.op == 'ADD':
            self.result = self.a + self.b
        elif self.op == 'SUB':
            self.result = self.a - self.b
        elif self.op = 

