reg = {
 "a":0,
 "b":0,
 "c":0,
 "d":0,
 "e":0,
 "f":0,
 "g":0,
 "h":0
}
reg_codes = {
    "a":0,
    "b":1,
    "c":2,
    "d":3,
    "e":4,
    "f":5,
    "g":6,
    "h":7,
}
memory = []
isa = {
    "add" : 0x00,
    "sub" : 0x01,
    "load" : 0x02,
    "store" : 0x03,
    "halt" : 0x04,
    "branch" : 0x05,
    "and" : 0x06,
    "or" : 0x07,
    "xor" : 0x08,
    "not" : 0x09
}
def ALU(x, y, operation):
    if operation == "add":return (x + y) & 0xFF
    elif operation == "sub":return (x - y) & 0xFF
    elif operation == "and":return x & y
    elif operation == "or":return x | y
    elif operation == "xor":return x ^ y
    elif operation == "not":return (~x) & 0xFF
    else:raise ValueError(f"Invalid Operation : {operation}")
def encode(instruction, *operands):
    if instruction not in isa:
        raise ValueError(f"invalid instruction {instruction}")
    opcode = isa[instruction]
    encoded_operands = []
    print(opcode)
    for operand in operands:
        if operand in reg_codes:
            print(reg_codes[operand])
            encoded_operands.append(reg_codes[operand])
        else:
            raise ValueError(f"invalid operand {operand}")
    return [opcode, encoded_operands]
memory.append(encode("add", "a", "b"))
memory.append(encode("sub", "a", "c"))
memory.append(encode("halt"))
def decode(instruction):
    opcode, operands = instruction
    operation = None
    for name, code in isa.items():
        if code == opcode:
            operation = name
            break
    reg_names = list(reg_codes.keys())
    decoded_operands = [
        reg_names[x] for x in operands
    ]
    return operation, decoded_operands
def read_instruction(address):
    return memory[address]
def execute(operation, operands):
    if operation == "add":
        dest, src = operands
        reg[dest] = ALU(
            reg[dest],
            reg[src],
            "add"
        )
    elif operation == "sub":
        dest, src = operands
        reg[dest] = ALU(
            reg[dest],
            reg[src],
            "sub"
        )
    elif operation == "and":
        dest, src = operands
        reg[dest] = ALU(
            reg[dest],
            reg[src],
            "and"
        )
    elif operation == "not":
        dest = operands
        reg[dest] = ALU(
            reg[dest],
            0,
            "not"
        )
    elif operation == "or":
        dest, src = operands
        reg[dest] = ALU(
            reg[dest],
            reg[src],
            "or"
        )
    elif operation == "xor":
        dest, src = operands
        reg[dest] = ALU(
            reg[dest],
            reg[src],
            "xor"
        )
    elif operation == "halt":
        return True
    return False
class CPU:
    def __init__(self):
        self.pc = 0
        self.ir = None
        self.halted = False
    def fetch(self):
        self.ir = read_instruction(self.pc)
    def step(self):
        if self.halted:
            return
        self.fetch()
        operation, operands = decode(self.ir)
        halted = execute(operation, operands)
        if halted:
            self.halted = True
        else:
            self.pc += 1
    def run(self):
        while not self.halted:
            self.step()
cpu = CPU()
reg["a"] = 5
reg["b"] = 3
reg["c"] = 2
cpu.run()
print(reg["a"])