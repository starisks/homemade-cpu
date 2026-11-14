reg <- {
    a = 0,
    b = 0,
    c = 0,
    d = 0,
    e = 0,
    f = 0,
    g = 0,
    h = 0
}

reg_codes <- {
    a = 0,
    b = 1,
    c = 2,
    d = 3,
    e = 4,
    f = 5,
    g = 6,
    h = 7
}

instruction_memory <- []

isa <- {
    ["add"] = 0x00,
    ["sub"] = 0x01,
    ["load"] = 0x02,
    ["store"] = 0x03,
    ["halt"] = 0x04,
    ["and"] = 0x05,
    ["or"] = 0x06,
    ["xor"]= 0x07,
    ["not"] = 0x08,
    ["<<"] = 0x09,
    [">>"] = 0x10,
    ["mov"] = 0x11,
    ["clr"] = 0x12,
    ["inc"] = 0x13,
    ["dec"] = 0x14,
    ["nop"] = 0x15,
    ["loadi"] = 0x16,
    ["addi"] = 0x17,
    ["subi"] = 0x18,
    ["jmp"] = 0x19,
    ["loop"] = 0x20,
    ["rol"] = 0x21,
    ["ror"] = 0x22,
    ["call"] = 0x23,
    ["ret"] = 0x24,
    ["branch"] = 0x25,
    ["uml"] = 0x26,
    ["udv"] = 0x27,
    ["sml"] = 0x28,
    ["sdv"] = 0x29,
    ["neg"] = 0x30,
    ["andi"] = 0x31,
    ["andn"] = 0x32,
    ["ori"] = 0x33,
    ["xori"] = 0x34,
    ["orn"] = 0x35,
    ["xnor"] = 0x36,
    ["sh1add"] = 0x37,
    ["sh2add"] = 0x38,
    ["sh3add"] = 0x39,
    ["rem"] = 0x40,
    ["remi"] = 0x41
}

diops <- {
    ["add"] = true, ["sub"] = true, ["and"] = true, ["or"] = true,
    ["xor"] = true, ["<<"] = true, [">>"] = true, ["rol"] = true,
    ["ror"] = true, ["uml"] = true, ["udv"] = true, ["sml"] = true,
    ["sdv"] = true
}

function signed8(x) {
    if (x & 0x80) {
        return x - 256
    }
    return x
}

function alu(x, y, operation) {
    if (operation == "add") {
        return (x + y) & 0xFF
    }
    else if (operation == "sub") {
        return (x - y) & 0xFF
    }
    else if (operation == "and") {
        return (x & y)
    }
    else if (operation == "or") {
        return (x | y)
    }
    else if (operation == "xor") {
        return (x ^ y)
    }
    else if (operation == "not") {
        return (~x) & 0xFF
    }
    else if (operation == "<<") {
        return (x << y) & 0xFF
    }
    else if (operation == ">>") {
        return (x >> y)
    }
    else if (operation == "rol") {
        y %= 8
        return ((x << y) | (x >> (8 - y))) & 0xFF
    }
    else if (operation == "ror") {
        y %= 8
        return ((x >> y) | (x << (8 - y))) & 0xFF
    }
    else if (operation == "uml") {
        return (x * y) & 0xFF
    }
    else if (operation == "udv") {
        if (y == 0) {
            throw "division by zero"
        }
        return (x / y)
    }
    else if (operation == "sml") {
        x = signed8(x)
        y = signed8(y)
        return (x * y) & 0xFF
    }
    else if (operation == "sdv") {
        x = signed8(x)
        y = signed8(y)
        if (y == 0) {
            throw "division by zero"
        }
        return (x / y) & 0xFF
    }
    else {
        throw "invalid operation"
    }
}

// helper function
function lstrip(x) {
    while (x.len() > 0 && (x.slice(0, 1) == "+" || x.slice(0, 1) == "-")) {
        x = x.slice(1)
    }
    return x
}

function startswith_any(s, prefixes) {
    foreach (prefix in prefixes) {
        if (s.len() >= prefix.len() &&
            s.slice(0, prefix.len()) == prefix)
            return true;
    }
    return false;
}

function parseint(x) {
    local sign = 1

    if (x.len() > 0 && (x.slice(0, 1) == "-" || x.slice(0, 1) == "+")) {
        if (x.slice(0, 1) == "-") sign = -1
        x = x.slice(1)
    }

    local base = 10

    if (x.len() >= 2 && x.slice(0, 2).tolower() == "0x") {
        base = 16;
        x = x.slice(2);
    }
    else if (x.len() >= 2 && x.slice(0, 2).tolower() == "0b") {
        base = 2;
        x = x.slice(2);
    }
    else if (x.len() >= 2 && x.slice(0, 2).tolower() == "0o") {
        base = 8;
        x = x.slice(2);
    }

    return sign * x.tointeger(base)
}

// parse operand
function parse_operand(x) {
    if (typeof(x) == "integer") {
        if (!(x >= -128 && x <= 255)) throw "imm out of range"
        return x & 0xFF
    }
    x = x.tolower()
    if (typeof(x) == "string" && x in reg_codes) return x
    local body = lstrip(x)
    local value = null
    try {
        if (startswith_any(body, ["0x", "0b", "0o"])) {
            value = parseint(x)
        }
        else {
            value = x.tointeger()
        }
    } catch (e){
        return (x)
    }
    if (!(value >= -128 && value <= 255)) {
        throw "imm out of range"
    }
    return (value & 0xFF)
}

// code
instruction_memory.append(["loadi", ["a", 15]])
instruction_memory.append(["loadi", ["b", 30]])
instruction_memory.append(["add", ["a", "b"]])

printl(instruction_memory[0][0])
printl(instruction_memory[0][1][0])
printl(instruction_memory[0][1][1])

function decode(instruction) {
    local operation = instruction[0]
    local raw = instruction[1]
    local operands = []

    if (!(operation in isa))
        throw "invalid operation"

    foreach (operand in raw) {
        operands.append(parse_operand(operand))
    }

    return [operation, operands]
}

function read_instruction(address) {
    return getroottable().instruction_memory[address]
}

class CPU {
    pc = 0
    ir = false
    halted = false
    zero_flag = false
    stack = []

    function execute(operation, operands) {
        if (operation == "not") {
            local dest = operands[0]
            reg[dest] = alu(
                reg[dest],
                0,
                "not"
            )
            this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "clr")  {
                local dest = operands[0]
                reg[dest] = 0
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "inc"){
                local dest = operands[0]
                reg[dest] = (reg[dest] + 1) & 0xFF
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "dec") {
                local dest = operands[0]
                reg[dest] = (reg[dest] - 1) & 0xFF
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "nop") {
        }
        else if (operation == "jmp") {
                local address = operands[0]
                return ["jump", address]
        }
        else if (operation == "loop") {
                local dest = operands[0]
                local address = operands[1]
                reg[dest] = (reg[dest] - 1) & 0xFF
                this.zero_flag = (reg[dest] == 0)
                if (reg[dest] != 0) { 
                    return ["loop", address]
                }
        }
        else if (operation == "call") {
                local address = operands[0]
                this.stack.append(this.pc + 1)
                return ["jump", address]
        }
        else if (operation == "ret") {
                if (this.stack.len() == 0) {
                    throw "this.stack underflow"
                }
                local return_address = this.stack.pop()
                return ["jump", return_address]
        }
        else if (operation == "branch") {
                local address = operands[0]
                if (this.zero_flag) {
                    return ["jump", address]
                }
        }
        else if (operation == "neg") {
                local dest = operands[0]
                reg[dest] = (-reg[dest]) & 0xFF
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "andn") {
                local dest = operands[0]
                local src = operands[1]
                local src2 = operands[2]
                reg[dest] = alu(
                    reg[src],
                    (~reg[src2]) & 0xFF,
                    "and"
                )
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "orn") {
                local dest = operands[0]
                local src = operands[1]
                local src2 = operands[2]
                reg[dest] = alu(
                    reg[src],
                    (~reg[src2]) & 0xFF,
                    "or"
                )
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "xnor") {
                local dest = operands[0]
                local src = operands[1]
                local src2 = operands[2]
                reg[dest] = alu(
                    reg[src],
                    (~reg[src2]) & 0xFF,
                    "xor"
                )
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "sh1add") {
                local dest = operands[0]
                local src = operands[1]
                local src2 = operands[2]
                reg[dest] = (
                    (reg[src] << 1) + reg[src2]
                ) & 0xFF
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "sh2add") {
                local dest = operands[0]
                local src = operands[1]
                local src2 = operands[2]
                reg[dest] = (
                    (reg[src] << 2) + reg[src2]
                ) & 0xFF
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "sh3add") {
                local dest = operands[0]
                local src = operands[1]
                local src2 = operands[2]
                reg[dest] = (
                    (reg[src] << 3) + reg[src2]
                ) & 0xFF
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "loadi") {
                local dest = operands[0]
                local value = operands[1]
                reg[dest] = value
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation in diops) {
                local dest = operands[0]
                local src = operands[1]
                reg[dest] = alu(reg[dest], reg[src], operation)
                this.zero_flag = (reg[dest] == 0)
        }
        else if (operation == "halt"){
                return "halt"
        }
        return null
    }
    function fetch() {
        this.ir = read_instruction(this.pc)
    }
    function step() {
        if (this.halted) {
            printl("inside the this.halted")
            return
        }
        printl("outside the this.halted")
        if (!(0 <= this.pc && this.pc < getroottable().instruction_memory.len())) {
            printl("inside the chained function")
            this.halted = true
            return
        }
        printl("step 2")
        this.fetch()
        local decoded = decode(this.ir)
        local operation = decoded[0]
        local operands = decoded[1]
        local result = this.execute(operation, operands)
        if (result == "halt") {
            this.halted = true
        }
        else if (typeof(result) == "array") {
            local kind = result[0]
            local target = result[1]
            if (!(0 <= target && target < getroottable().instruction_memory.len())) {
                throw ("target is invalid" + kind)
            }
            this.pc = target
        }
        else {
            this.pc += 1
        }
        printl("end step")
    }
    max_steps = 1000000
    function run() {
        for (local _ = 0; _ < this.max_steps; _++) {
            this.step()
            if (this.halted == true) {
                return
            }
        }
        throw "maximum step count exceeded"
    }
}
local cpu = CPU()
cpu.run()
printl("register data")
foreach (name, value in reg) {
    printl(name + ": " + value)
}