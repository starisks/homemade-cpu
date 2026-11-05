# registers
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
# memory
memory = [0] * 256
instruction_memory = []

# log
log_file = open("cpu.log", "w")

def log(message):
    log_file.write(str(message) + "\n")

# instruction set
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
    "remi" : 0x41,
    "tst" : 0x42,
    "cmp" : 0x43,
    "max" : 0x44,
    "min" : 0x45
}

# signed integer
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
    elif operation == "max":
        return max(x, y)
    elif operation == "min":
        return min(x, y)
    elif operation == "cmp":
        return x == y
    elif operation == "rem":
        return x % y
    else:
        raise ValueError(f"Invalid Operation : {operation}")

def encode(instruction, *operands):
    if instruction not in isa:
        raise ValueError(f"invalid instruction {instruction}")
    
    opcode = isa[instruction]
    encoded_operands = []
    log(opcode)

    # if code does not work, backup is below
    # for operand in operands:
    #     if operand in reg_codes:
    #         print(reg_codes[operand])
    #         encoded_operands.append(reg_codes[operand])
    #     else:
    #         raise ValueError(f"invalid operand {operand}")

    for operand in operands:
        if isinstance(operand, str) and operand in reg_codes:
            encoded_operands.append(("reg", reg_codes[operand]))

        elif isinstance(operand, int):
            if not 0 <= operand <= 0xFF:
                raise ValueError(f"invalid address {operand}")

            encoded_operands.append(("imm", operand))

        else:
            raise ValueError(f"invalid operand {operand}")

    log(opcode)
    log(encoded_operands)   
    return [opcode, encoded_operands]
    


# hex comprehension
def parse_operand(x):
    x = x.lower()
    body = x.lstrip("+-")

    try:
        value = int(x, 0) if body.startswith(("0x", "0b", "0o")) else int(x, 10)

    except ValueError:
        return x
    
    if not -128 <= value <= 255:
        log(f"imm out of range {value}")
        raise ValueError(f"imm out of range {value}")
    
    return value & 0xFF

    
# code
with open("../program.asm", "r") as file:
    for line in file:
        line = line.split("#")[0].split(";")[0]
        parts = line.replace(",", " ").split()

        if parts:
            parts = [parse_operand(x) for x in parts]

            instruction_memory.append(encode(*parts))

def decode(instruction):
    opcode, operands = instruction
    operation = None

    for name, code in isa.items():
        if code == opcode:
            operation = name
            break

    # if code does not work, backup is below
    # reg_names = list(reg_codes.keys())
    # decoded_operands = [
    #     reg_names[x] for x in operands
    # ]

    decoded_operands = []

    for operand_type, value in operands:
        if operand_type == "reg":
            reg_names = list(reg_codes.keys())
            decoded_operands.append(reg_names[value])

        elif operand_type == "imm":
            decoded_operands.append(value)

    log(operation)
    log(decoded_operands)
    return operation, decoded_operands

def read_instruction(address):
    return instruction_memory[address]

class CPU:
    def __init__(self):
        self.pc = 0
        self.ir = None
        self.halted = False
        self.zero_flag = False
        self.stack = []

    def execute(self, operation, operands):
        log(operation)
        log(operands)

        if operation == "add":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "add"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "sub":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "sub"
            )
            
            self.zero_flag = (reg[dest] == 0)

        elif operation == "and":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "and"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "not":
            dest, = operands

            reg[dest] = ALU(
                reg[dest],
                0,
                "not"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "or":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "or"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "xor":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "xor"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "<<":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "<<"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == ">>":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                ">>"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "mov":
            dest, src = operands

            reg[dest] = reg[src]   

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

        elif operation == "load":
            dest, address = operands

            reg[dest] = memory[address]

            self.zero_flag = (reg[dest] == 0)

        elif operation == "store":
            src, address = operands

            memory[reg[address]] = reg[src]

        elif operation == "nop":
            pass

        elif operation == "loadi":
            dest, value = operands

            reg[dest] = value

            self.zero_flag = (reg[dest] == 0)

        elif operation == "addi":
            dest, value = operands

            reg[dest] = ALU(
                reg[dest],
                value,
                "add"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "subi":
            dest, value = operands

            reg[dest] = ALU(
                reg[dest],
                value,
                "sub"
            )    

            self.zero_flag = (reg[dest] == 0)

        elif operation == "jmp":
            address, = operands
            return ("jump", address)

        elif operation == "loop":
            dest, address = operands

            reg[dest] = (reg[dest] - 1) & 0xFF

            if reg[dest] != 0:
                return ("loop", address)

        elif operation == "rol":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "rol"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "ror":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "ror"
            )       

            self.zero_flag = (reg[dest] == 0)

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

        elif operation == "uml":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "uml"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "udv":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "udv"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "sml":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "sml"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "sdv":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "sdv"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "neg":
            dest, = operands

            reg[dest] = (-reg[dest]) & 0xFF

            self.zero_flag = (reg[dest] == 0)

        elif operation == "andi":
            dest, value = operands

            reg[dest] = ALU(
                reg[dest],
                value,
                "and"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "andn":
            dest, src, src2 = operands

            reg[dest] = ALU(
                reg[src],
                (~reg[src2]) & 0xFF,
                "and"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "ori":
            dest, value = operands

            reg[dest] = ALU(
                reg[dest],
                value,
                "or"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "xori":
            dest, value = operands

            reg[dest] = ALU(
                reg[dest],
                value,
                "xor"
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

        elif operation == "remi":
            dest, value = operands

            if value == 0:
                raise ZeroDivisionError("division by zero")

            reg[dest] = reg[dest] % value

            self.zero_flag = (reg[dest] == 0)

        elif operation == "tst":
            dest, = operands

            self.zero_flag = (reg[dest] == 0)

        elif operation == "max":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "max"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "min":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "min"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "cmp":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "cmp"
            )

            self.zero_flag = (reg[dest] == 0)

        elif operation == "rem":
            dest, src = operands

            reg[dest] = ALU(
                reg[dest],
                reg[src],
                "rem"
            )

            self.zero_flag = (reg[dest] == 0)

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
        # its spooky but the code below is backup
        # halted = execute(operation, operands)

        # if halted:
        #     self.halted = True
        # else:
        #     self.pc += 1

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

        log(f"maximum step count exceeded: {max_steps}")
        raise RuntimeError(f"maximum step count exceeded: ({max_steps})")

# cpu instance
cpu = CPU()

cpu.run()

print("register data:")

for r in "abcdefgh":
    print(reg[r])