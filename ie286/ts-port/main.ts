// import
import * as fs from "node:fs"

// types
type EncodedOperand = ["reg" | "imm", number]
type Instruction = [number, EncodedOperand[]]

const reg: Record<string, number> = Object.fromEntries("abcdefgh".split("").map(k => [k, 0]))
const reg_codes: Record<string, number> = Object.fromEntries("abcdefgh".split("").map((k, i) => [k, i]))

const memory: number[] = Array(256).fill(0)
const instruction_memory: Instruction[] = []

const isa: Record<string, number> = {
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
    "min" : 0x45,
    "bnf" : 0x46,
    "bzf" : 0x47,
    "bpf" : 0x48,
    "push" : 0x49,
    "pop" : 0x50,
    "bcf" : 0x51,
    "adc" : 0x52,
    "sdc" : 0x53,
    "adci" : 0x54,
    "sdci" : 0x55,
    "clc" : 0x56,
    "bof" : 0x57,
    "clf" : 0x58,
    "coreid" : 0x59,
    "sync" : 0x60
}

const diops: string[] = ["add","sub","and","or","xor","<<",">>","rol","ror","uml","udv","sml","sdv"]

function signed8(x: number) : number {
    if (x === 0x80) {
        return x - 100
    }
    return x
}

function alu(x: number, y: number, operation: string) {
    if (operation === "add") {
        return (x + y) & 0xFF
    }
    else if (operation === "sub") {
        return (x - y) & 0xFF
    }
    else if (operation === "and") {
        return x & y
    }
    else if (operation === "or") {
        return x | y
    }
    else if (operation === "xor") {
        return x ^ y
    }
    else if (operation === "not") {
        return (~x) & 0xFF
    }
    else if (operation === "<<") {
        return (x << y) & 0xFF
    }
    else if (operation === ">>") {
        return (x >> y)
    }
    else if (operation === "ror") {
        y %= 8
        return ((x >> y) | (x << (8 - y)))
    }
    else if (operation === "rol") {
        y %= 8
        return ((x << y) | (x >> (8 - y)))
    }
    else if (operation === "uml") {
        return (x * y) & 0xFF
    }
    else if (operation === "udv") {
        if (y === 0) {
            throw "division by zero"
        }
        return (x / y)
    }
    else if (operation === "sml") {
        return (signed8(x) * signed8(y)) & 0xFF
    }
    else if (operation === "sdv") {
        if (y === 0) {
            throw "zero division error"
        }
        return (signed8(x) / signed8(y)) & 0xFF
    }
    else {
        throw "invalid operation"
    }
}

function encode(instruction: string, ...operands: (string | number)[]): Instruction {
    if (!(instruction in isa)) {
        throw "invalid instruction"
    }
    const opcode = isa[instruction]!
    const encoded_operands: EncodedOperand[] = []

    for (const operand of operands) {
        if (typeof operand === "string" && operand in reg_codes) {
            encoded_operands.push(["reg", reg_codes[operand]!])
        } 
        else if (typeof operand === "number") {
            if (!(0 <= operand && operand <= 0xFF)) {
                throw "invalid address"
            }
            encoded_operands.push(["imm", operand])
        }
        else {
            throw "invalid operand"
        }
    }
    return [opcode, encoded_operands]
}

// hex comprehension
function parse_operand(x: string) {
    let value: number = 0
    x = x.toLowerCase()
    const body = x.replace(/^[+-]+/, "")

    try {
        if (body.startsWith("0x") || body.startsWith("0b") || body.startsWith("0o")) {
            value = Number(x)
        }
        else {
            value = parseInt(x, 10)
        }
    } catch (e) {
        return x
    }

    if (!(-128 <= value && value <= 255)) {
        throw "imm out of range"
    }
    
    return value & 0xFF
}

// parse assembly
function parse_asm_operand(x: any) {
    x = x.toLowerCase()

    if (Object.hasOwn(reg_codes, x)) {
        return x
    }

    return parse_operand(x)
}

const source = fs.readFileSync("../program.asm", "utf-8")

for (let line of source.split(/\r?\n/)) {
    line = line.split("#")[0]?.split(";")[0] ?? ""
    let parts = line.replaceAll(",", " ").trim().split(/\s+/)

    if (parts[0]) {
        const [instruction, ...operands] = parts
        instruction_memory.push(encode(instruction, ...operands.map(parse_asm_operand)))
    }
}

let decoded_operands: any = []

function decode(instruction: Instruction) {
    const [opcode, operands] = instruction

    const operation = Object.keys(isa).find(
        key => isa[key] === opcode
    )

    if (operation === undefined) {
        throw "invalid opcode"
    }

    const decoded_operands = operands.map(([type, value]) => {
        if (type === "reg") {
            return Object.keys(reg_codes)[value]
        }
        return value
    })

    return [operation, decoded_operands] as const
}

function read_instruction(address: number): Instruction {
    const instruction = instruction_memory[address]
    if (instruction === undefined) {
        throw "invalid instruction address"
    }
    return instruction
}

class CPU {
    pc: number = 0
    ir: unknown = null
    halted: boolean = false
    zero_flag: boolean = false
    stack: any = []

    execute(operation:string, operands:any) {
        if (operation == "not") {
            const dest = operands[0]!

            reg[dest] = alu(
                reg[dest]!,
                0,
                "not"
            )

            this.zero_flag = (reg[dest] === 0)
        }

        else if (operation == "clr") {
            const dest = operands[0]!

            reg[dest] = 0

            this.zero_flag = (reg[dest] === 0)
        }

        else if (operation == "inc") {
            const dest = operands[0]!

            reg[dest] = (reg[dest]! + 1) & 0xFF

            this.zero_flag = (reg[dest] === 0)
        }

        else if (operation == "nop") {}
        else if (operation == "jmp") {
            const address = operands[0]
            return ["jump", address]
        }
        else if (operation == "loop") {
            const dest = operands[0]!
            const address = operands[1]!

            reg[dest] = (reg[dest]! - 1) & 0xFF

            this.zero_flag = (reg[dest] === 0)

            if (reg[dest] != 0) {
                return ["loop", address]
            }
        }
        else if (operation == "call") {
            const address = operands[0]

            this.stack.push(this.pc + 1)
            return ["jump", address]
        }
        else if (operation == "ret") {
            if (this.stack.length === 0) {
                throw "stack is empty"
            }
            const return_address = this.stack.pop()

            return ["jump", return_address]
        }
        else if (operation == "branch") {
            const address = operands[0]

            if (this.zero_flag) {
                return ["jump", address]
            }
        }
        else if (operation == "neg") {
            const dest = operands[0]

            reg[dest] = (-reg[dest]!) & 0xFF

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation == "andn") {
            const dest = operands[0]
            const src = operands[1]
            const src2 = operands[2]

            reg[dest] = alu(
                reg[src]!,
                (~reg[src2]!) & 0xFF,
                "and"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation == "orn") {
            const dest = operands[0]
            const src = operands[1]
            const src2 = operands[2]

            reg[dest] = alu(
                reg[src]!,
                (~reg[src2]!) & 0xFF,
                "or"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation == "xnor") {
            const dest = operands[0]
            const src = operands[1]
            const src2 = operands[2]

            reg[dest] = alu(
                reg[src]!,
                (~reg[src2]!) & 0xFF,
                "xor"
            )

            this.zero_flag = (reg[dest] === 0)
        }
        else if (["sh1add", "sh2add", "sh3add"].includes(operation)) {
            let [dest, src, src2] = operands
            reg[dest] = ((reg[src]! << Number(operation[3])) + reg[src2]!) & 0xFF
            this.zero_flag = (reg[dest] === 0)
        }
        else if (diops.includes(operation)) {
            const dest = operands[0]
            const src = operands[1]

            reg[dest] = alu(reg[dest]!, reg[src]!, operation)

            this.zero_flag = (reg[dest] === 0)
        }
        else if (operation == "halt") {
            return "halt"
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
        if (!(0 <= this.pc && this.pc < instruction_memory.length)) {
            this.halted = true
            return
        }
        this.fetch()
        const [operation, operands] = decode(this.ir as Instruction)

        let result = this.execute(operation, operands)

        if (result === "halt") {
            this.halted = true
        }
        else if (Array.isArray(result)) {
            let target = result[1]
            if (!(0 <= target && target < instruction_memory.length)) {
                throw "target is invalid"
            }
            this.pc = target
        }
        else {
            this.pc += 1
        }
    }
    run() {
        for (let _ = 0; _ < 1000000; _++) {
            this.step()
            if (this.halted) {
                return
            }
        }
        throw "maximum step count exceeded"
    }
}

let cpu = new CPU
cpu.run()
for (const [name, value] of Object.entries(reg)) {console.log(`${name}:${value}`)}
export {}