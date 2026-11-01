console.log("hello")

const fs = require("node:fs");

// registers
let reg = {
 "a":0,
 "b":0,
 "c":0,
 "d":0,
 "e":0,
 "f":0,
 "g":0,
 "h":0
}

let reg_codes = {
    "a":0,
    "b":1,
    "c":2,
    "d":3,
    "e":4,
    "f":5,
    "g":6,
    "h":7,
}

// mem
let memory = new Uint8Array(256);
let instruction_memory = []

// instruction set
let isa = {
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

// signed integer
function signed8(x) {
    if (x & 0x80) {
        return x - 0x100
    }
    return x
}

// alu
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
            throw "Zero Division Error"
        }
        return Math.trunc(x / y) & 0xFF
    }
    else if (operation == "sml") {
        x = signed8(x)
        y = signed8(y)
        return (x * y) & 0xFF
    }
    else if (operation === "sdv") {
        x = signed8(x)
        y = signed8(y)
        if (y == 0) {
            throw "Zero Division Error"
        }
        return Math.trunc(x / y) & 0xFF
    }
    else if (operation == "max") {
        return Math.max(x, y)
    }
    else if (operation == "min") {
        return Math.min(x, y)
    }
    else if (operation == "cmp") {
        return (x == y)
    }
    else if (operation == "rem") {
        return (x % y)
    } else {
        throw "Invalid Operation : " + operation
    }
}

// dreaded encode
function encode(instruction, ...operands) {
    if (!Object.hasOwn(isa, instruction)) {
        throw "invalid instruction" + instruction
    }
    let opcode = isa[instruction]
    let encoded_operands = []

    for (const operand of operands) {
        if (typeof operand === "string" && Object.hasOwn(reg_codes, operand)) {
            encoded_operands.push(["reg", reg_codes[operand]])
        }
        else if (Number.isInteger(operand)) {
            if (operand < 0 || operand > 0xFF) {
                throw "invalid address" + operand
            }
            encoded_operands.push(["imm", operand])
        } else {
            throw "invalid operand" + operand
        }
    }
    return [opcode, encoded_operands]
}

// lstrip
function ltrim(x, characters) {
    var start = 0;
    while (characters.indexOf(x[start]) >= 0) {
        start += 1;
    }
    return x.substr(start);
}

// hex comprehension
function parse_operand(x) {
    let body;

    x = x.toLowerCase();
    body = ltrim(x, "+-")
    
    let value = Number(x)
    
    if (!Number.isInteger(value) || value < -128 || value > 255) {
        throw "imm out of range" + value
    }

    return value & 0xFF
}

// parsing assembly
function parse_asm_operand(x) {
    x = x.toLowerCase()

    if (Object.hasOwn(reg_codes, x)) {
        return x;
    }

    return parse_operand(x)
}

// code
const source = fs.readFileSync("../program.asm", "utf-8")

for (let line of source.split(/\r?\n/)) {
    line = line.split("#")[0].split(";")[0]
    let parts = line.replaceAll(",", " ").trim().split(/\s+/);

    if (parts[0]) {
        const [instruction, ...operands] = parts;

        instruction_memory.push(encode(instruction, ...operands.map(parse_asm_operand)))
    }
}

// decode
function decode(instruction) {
    const [opcode, operands] = instruction
    let operation = null;

    for (const [name, code] of Object.entries(isa)) {
        if (code === opcode) {
            operation = name
            break
        }
    }
    let decoded_operands = []
    for (const [operand_type, value] of operands) {
        if (operand_type === "reg") {
            let reg_names = Object.keys(reg_codes)
            decoded_operands.push(reg_names[value])
        }
        else if (operand_type === "imm") {
            decoded_operands.push(value)
        }
    }
    return [operation, decoded_operands]
}

// read instruction
function read_instruction(address) {
    return instruction_memory[address]
}

// most classic CPU
class CPU {
    constructor() {
        this.pc = 0
        this.ir = null
        this.halted = false
        this.zero_flag = false
        this.stack = []
    }
    execute(operation, operands) {
        if (operation === "add") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest], 
                reg[src], 
                "add"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "sub") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "sub"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "and") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "and"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "not") {
            let [dest] = operands

            reg[dest] = alu(
                reg[dest],
                0,
                "not"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "or") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "or"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "xor") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "xor"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "<<") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "<<"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === ">>") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                ">>"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "mov") {
            let [dest, src] = operands

            reg[dest] = reg[src]

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "clr") {
            let [dest] = operands

            reg[dest] = 0

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "inc") {
            let [dest] = operands

            reg[dest] = (reg[dest] + 1) & 0xFF

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "dec") {
            let [dest] = operands

            reg[dest] = (reg[dest] - 1) & 0xFF

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "load") {
            let [dest, address] = operands

            reg[dest] = memory[address]

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "store") {
            let [src, address] = operands

            memory[reg[address]] = reg[src]
        }
        else if (operation === "nop") {
        }
        else if (operation === "loadi") {
            let [dest, value] = operands

            reg[dest] = value

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "addi") {
            let [dest, value] = operands

            reg[dest] = alu(
                reg[dest],
                value,
                "add"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "subi") {
            let [dest, value] = operands

            reg[dest] = alu(
                reg[dest],
                value,
                "sub"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "jmp") {
            let [address] = operands

            return (["jump", address])
        }
        else if (operation === "loop") {
            let [dest, address] = operands

            reg[dest] = (reg[dest] - 1) & 0xFF

            if (reg[dest] != 0) {
                return ["loop", address]
            }
        }
        else if (operation === "rol") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "rol"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "ror") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "ror"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "call") {
            let [address] = operands

            this.stack.push(this.pc + 1)
            return ["jump", address]
        }
        else if (operation === "ret") {
            if (this.stack.length === 0) {
                throw "stack is empty"
            }

            let return_address = this.stack.pop()

            return ["jump", return_address]
        }
        else if (operation === "branch") {
            let [address] = operands

            if (this.zero_flag) {
                return ["jump", address]
            }
        }
        else if (operation === "uml") {
            let [dest, src] = operands
            
            reg[dest] = alu(
                reg[dest],
                reg[src],
                "uml"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "udv") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "udv"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "sml") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "sml"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "sdv") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "sdv"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "neg") {
            let [dest] = operands

            reg[dest] = (-reg[dest]) & 0xFF

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "andi") {
            let [dest, value] = operands

            reg[dest] = alu(
                reg[dest],
                value,
                "and"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "andn") {
            let [dest, src, src2] = operands

            reg[dest] = alu(
                reg[src],
                (~reg[src2]) & 0xFF,
                "and"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "ori") {
            let [dest, value] = operands

            reg[dest] = alu(
                reg[dest],
                value,
                "or"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "xori") {
            let [dest, value] = operands

            reg[dest] = alu(
                reg[dest],
                value,
                "xor"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "orn") {
            let [dest, src, src2] = operands
            
            reg[dest] = alu(
                reg[src],
                (~reg[src2]) & 0xFF,
                "or"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "xnor") {
            let [dest, src, src2] = operands

            reg[dest] = alu(
                reg[src],
                (~reg[src2]) & 0xFF,
                "xor"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "sh1add") {
            let [dest, src, src2] = operands

            reg[dest] = (
                (reg[src] << 1) + reg[src2]
            ) & 0xFF

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "sh2add") {
            let [dest, src, src2] = operands

            reg[dest] = ( 
                (reg[src] << 2) + reg[src2]
            ) & 0xFF

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "sh3add") {
            let [dest, src, src2] = operands

            reg[dest] = (
                (reg[src] << 3) + reg[src2]
            ) & 0xFF

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "remi") {
            let [dest, value] = operands

            if (value === 0) {
                throw "division by zero"
            }

            reg[dest] = reg[dest] % value

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "tst") {
            let [dest] = operands

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "max") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "max"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "min") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "min"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "cmp") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "cmp"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "rem") {
            let [dest, src] = operands

            reg[dest] = alu(
                reg[dest],
                reg[src],
                "rem"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation === "halt") {
            return "halted"
        }
        return false
    }
    fetch() {
        this.ir = read_instruction(this.pc)
    }
    step() {
        if (this.halted) {
            return
        }
        if (this.pc < 0 || this.pc >= instruction_memory.length) {
            this.halted = true
            return
        }
        this.fetch()
        const [operation, operands] = decode(this.ir)
        let result = this.execute(operation, operands)

        if (result === "halted") {
            this.halted = true
        }
        else if (Array.isArray(result)) {
            const [kind, target] = result

            if (target < 0 || target >= instruction_memory.length) {
                throw (kind + "is invalid" + target)
            }
            this.pc = target
        } else {
            this.pc = this.pc + 1
        }
    }
    run(max_steps = 1000000) {
        for (let _ = 0; _ < max_steps; _++) {
            this.step()
            if (this.halted === true) {
                return
            } 
        }
        throw "maximum steps reached"
    }
}

// instancing cpu
const cpu = new CPU()

// running cpu
cpu.run()

// register dump
console.log("register dump: \n")

for (const [name, value] of Object.entries(reg)) {
    console.log(`${name}:${value}`)
}