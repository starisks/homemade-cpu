reg = {k:0 for k in "abcdefgh"}
reg_codes = {k:i for i, k in enumerate(reg)}
instruction_memory = []
isa = {
    "add" : 0x00,
    "sub" : 0x01,
    "load" : 0x02,
    "store" : 0x03,
    "halt" : 0x04,
    "and" : 0x05,
    "or" : 0x06,
    "xor" : 0x07,
    "not" : 0x08,
    "<<" : 0x09,
    ">>" : 0x10,
    "mov" : 0x11,
    "clr" : 0x12,
    "inc" : 0x13,
    "dec" : 0x14,
    "nop" : 0x15,
    "loadi" : 0x16,
    "addi" : 0x17,
    "subi" : 0x18,
    "jmp" : 0x19,
    "loop" : 0x20,
    "rol" : 0x21,
    "ror" : 0x22,
    "call" : 0x23,
    "ret" : 0x24,
    "branch" : 0x25,
    "uml" : 0x26,
    "udv" : 0x27,
    "sml" : 0x28,
    "sdv" : 0x29,
    "neg" : 0x30,
    "andi" : 0x31,
    "andn" : 0x32,
    "ori" : 0x33,
    "xori" : 0x34,
    "orn" : 0x35,
    "xnor" : 0x36,
    "sh1add" : 0x37,
    "sh2add" : 0x38,
    "sh3add" : 0x39,
    "rem" : 0x40,
    "remi" : 0x41
}
diops = {"add","sub","and","or","xor","<<",">>","rol","ror","uml","udv","sml","sdv"}
def signed8(x):
    if x & 0x80:
        return x - 0x100
    return x
def ALU(x, y, operation):
    if operation == "add":
        return (x + y) & 0xFF
    elif operation == "sub":
        return (x - y) & 0xFF
    elif operation == "and":
        return x & y
    elif operation == "or":
        return x | y
    elif operation == "xor":
        return x ^ y
    elif operation == "not":
        return (~x) & 0xFF
    elif operation == "<<":
        return (x << y) & 0xFF
    elif operation == ">>":
        return x >> y
    elif operation == "rol":
        y %= 8
        return ((x << y) | (x >> (8 - y))) & 0xFF
    elif operation == "ror":
        y %= 8
        return ((x >> y) | (x << (8 - y))) & 0xFF
    elif operation == "uml":
        return (x * y) & 0xFF
    elif operation == "udv":
        if y == 0:
            raise ZeroDivisionError("division by zero")
        return x // y   
    elif operation == "sml":
        x = signed8(x)
        y = signed8(y)
        return (x * y) & 0xFF
    elif operation == "sdv":
        x = signed8(x)
        y = signed8(y)
        if y == 0:
            raise ZeroDivisionError("error : division by zero")
        return int(x / y) & 0xFF
    else:
        raise ValueError(f"Invalid Operation : {operation}")
def parse_operand(x):
    x = x.lower()
    body = x.lstrip("+-")
    try:
        value = int(x, 0) if body.startswith(("0x", "0b", "0o")) else int(x, 10)
    except ValueError:
        return x
    if not -128 <= value <= 255:
        raise ValueError(f"imm out of range {value}")    
    return value & 0xFF
with open("arch.asm", "r") as file:
    for line in file:
        line = line.split("#")[0].split(';')[0]
        parts = line.replace(",", " ").split()
        if parts:
            parts = [parse_operand(x) for x in parts]
            instruction_memory.append(parts)
def decode(instruction):
    operation = instruction[0]
    decoded_operands = instruction[1:]
    if operation not in isa:
        raise ValueError(f"invalid operation: {operation}")
    return operation, decoded_operands
def read_instruction(address):
    return instruction_memory[address]
class CPU:
    def __init__(self):
        self.pc = 0
        self.ir = None
        self.halted, self.zero_flag = False,False
        self.stack = []
    def execute(self, operation, operands):
        if operation == "not":
            dest, = operands
            reg[dest] = ALU(
                reg[dest],
                0,
                "not"
            )
            self.zero_flag = (reg[dest] == 0)
        elif operation == "clr":
            dest, = operands
            reg[dest] = 0
            self.zero_flag = (reg[dest] == 0)
        elif operation == "inc":
            dest, = operands
            reg[dest] = (reg[dest] + 1) & 0xFF
            self.zero_flag = (reg[dest] == 0)
        elif operation == "dec":
            dest, = operands
            reg[dest] = (reg[dest] - 1) & 0xFF
            self.zero_flag = (reg[dest] == 0)
        elif operation == "nop":
            pass
        elif operation == "jmp":
            address, = operands
            return ("jump", address)
        elif operation == "loop":
            dest, address = operands
            reg[dest] = (reg[dest] - 1) & 0xFF
            self.zero_flag = (reg[dest] == 0)
            if reg[dest] != 0:
                return ("loop", address)
        elif operation == "call":
            address, = operands
            self.stack.append(self.pc + 1)
            return ("jump", address)
        elif operation == "ret":
            if not self.stack:
                raise RuntimeError("stack is empty")
            return_address = self.stack.pop()
            return ("jump", return_address)
        elif operation == "branch":
            address, = operands
            if self.zero_flag:
                return ("jump", address)
        elif operation == "neg":
            dest, = operands
            reg[dest] = (-reg[dest]) & 0xFF
            self.zero_flag = (reg[dest] == 0)
        elif operation == "andn":
            dest, src, src2 = operands
            reg[dest] = ALU(
                reg[src],
                (~reg[src2]) & 0xFF,
                "and"
            )
            self.zero_flag = (reg[dest] == 0)
        elif operation == "orn":
            dest, src, src2 = operands
            reg[dest] = ALU(
                reg[src],
                (~reg[src2]) & 0xFF,
                "or"
            )
            self.zero_flag = (reg[dest] == 0)
        elif operation == "xnor":
            dest, src, src2 = operands
            reg[dest] = ALU(
                reg[src],
                (~reg[src2]) & 0xFF,
                "xor"
            )
            self.zero_flag = (reg[dest] == 0)
        elif operation == "sh1add":
            dest, src, src2 = operands
            reg[dest] = (
                (reg[src] << 1) + reg[src2]
            ) & 0xFF
            self.zero_flag = (reg[dest] == 0)
        elif operation == "sh2add":
            dest, src ,src2 = operands
            reg[dest] = (
                (reg[src] << 2) + reg[src2]
            ) & 0xFF
            self.zero_flag = (reg[dest] == 0)
        elif operation == "sh3add":
            dest, src, src2 = operands
            reg[dest] = (
                (reg[src] << 3) + reg[src2]
            ) & 0xFF
            self.zero_flag = (reg[dest] == 0)
        elif operation in diops:
            dest, src = operands
            reg[dest] = ALU(reg[dest], reg[src], operation)
            self.zero_flag = reg[dest] == 0
        elif operation == "halt":
            return "halt"
        return False
    def fetch(self):
        self.ir = read_instruction(self.pc)
    def step(self):
        if self.halted:
            return
        if not 0 <= self.pc < len(instruction_memory):
            self.halted = True
            return
        self.fetch()
        operation, operands = decode(self.ir)
        result = self.execute(operation, operands)
        if result == "halt":
            self.halted = True
        elif isinstance(result, tuple):
            kind, target = result
            if not 0 <= target < len(instruction_memory):
                raise RuntimeError(f"{kind} target is invalid {target}")
            self.pc = target
        else:
            self.pc += 1
    def run(self, max_steps = 1000000):
        for _ in range(max_steps):
            self.step()
            if self.halted:
                return
        raise RuntimeError(f"maximum step count exceeded: ({max_steps})")
cpu = CPU()
cpu.run()
print("register data:")
for r in "abcdefgh": print(reg[r])