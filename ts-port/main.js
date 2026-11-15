"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const reg = Object.fromEntries("abcdefgh".split("").map(k => [k, 0]));
const reg_codes = Object.fromEntries("abcdefgh".split("").map((k, i) => [k, i]));
const memory = Array(256).fill(0);
const instruction_memory = [];
const isa = {
    "add": 0x00,
    "sub": 0x01,
    "load": 0x02,
    "store": 0x03,
    "halt": 0x04,
    "and": 0x05,
    "or": 0x06,
    "xor": 0x07,
    "not": 0x08,
    "<<": 0x09,
    ">>": 0x10,
    "mov": 0x11,
    "clr": 0x12,
    "inc": 0x13,
    "dec": 0x14,
    "nop": 0x15,
    "loadi": 0x16,
    "addi": 0x17,
    "subi": 0x18,
    "jmp": 0x19,
    "loop": 0x20,
    "rol": 0x21,
    "ror": 0x22,
    "call": 0x23,
    "ret": 0x24,
    "uml": 0x26,
    "udv": 0x27,
    "sml": 0x28,
    "sdv": 0x29,
    "neg": 0x30,
    "andi": 0x31,
    "andn": 0x32,
    "ori": 0x33,
    "xori": 0x34,
    "orn": 0x35,
    "xnor": 0x36,
    "sh1add": 0x37,
    "sh2add": 0x38,
    "sh3add": 0x39,
    "rem": 0x40,
    "remi": 0x41,
    "tst": 0x42,
    "cmp": 0x43,
    "max": 0x44,
    "min": 0x45,
    "bnf": 0x46,
    "bzf": 0x47,
    "bpf": 0x48,
    "push": 0x49,
    "pop": 0x50,
    "bcf": 0x51,
    "adc": 0x52,
    "sdc": 0x53,
    "adci": 0x54,
    "sdci": 0x55,
    "clc": 0x56,
    "bof": 0x57,
    "clf": 0x58,
    "coreid": 0x59,
    "sync": 0x60
};
const diops = ["add", "sub", "and", "or", "xor", "<<", ">>", "rol", "ror", "uml", "udv", "sml", "sdv"];
function signed8(x) {
    if (x === 0x80) {
        return x - 100;
    }
    return x;
}
function alu(x, y, operation) {
    if (operation === "add") {
        return (x + y) & 0xFF;
    }
    else if (operation === "sub") {
        return (x - y) & 0xFF;
    }
    else if (operation === "and") {
        return x & y;
    }
    else if (operation === "or") {
        return x | y;
    }
    else if (operation === "xor") {
        return x ^ y;
    }
    else if (operation === "not") {
        return (~x) & 0xFF;
    }
    else if (operation === "<<") {
        return (x << y) & 0xFF;
    }
    else if (operation === ">>") {
        return (x >> y);
    }
    else if (operation === "ror") {
        y %= 8;
        return ((x >> y) | (x << (8 - y)));
    }
    else if (operation === "rol") {
        y %= 8;
        return ((x << y) | (x >> (8 - y)));
    }
    else if (operation === "uml") {
        return (x * y) & 0xFF;
    }
    else if (operation === "udv") {
        if (y === 0) {
            throw "division by zero";
        }
        return (x / y);
    }
    else if (operation === "sml") {
        return (signed8(x) * signed8(y)) & 0xFF;
    }
    else if (operation === "sdv") {
        if (y === 0) {
            throw "zero division error";
        }
        return (signed8(x) / signed8(y)) & 0xFF;
    }
    else {
        throw "invalid operation";
    }
}
function encode(instruction, ...operands) {
    if (!(instruction in isa)) {
        throw "invalid instruction";
    }
    const opcode = isa[instruction];
    const encoded_operands = [];
    for (const operand of operands) {
        if (typeof operand === "string" && operand in reg_codes) {
            encoded_operands.push(["reg", reg_codes[operand]]);
        }
        else if (typeof operand === "number") {
            if (!(0 <= operand && operand <= 0xFF)) {
                throw "invalid address";
            }
            encoded_operands.push(["imm", operand]);
        }
        else {
            throw "invalid operand";
        }
    }
    return [opcode, encoded_operands];
}
// hex comprehension
function parse_operand(x) {
    let value = 0;
    x = x.toLowerCase();
    const body = x.replace(/^[+-]+/, "");
    try {
        if (body.startsWith("0x") || body.startsWith("0b") || body.startsWith("0o")) {
            value = Number(x);
        }
        else {
            value = parseInt(x, 10);
        }
    }
    catch (e) {
        return x;
    }
    if (!(-128 <= value && value <= 255)) {
        throw "imm out of range";
    }
    return value & 0xFF;
}
//# sourceMappingURL=main.js.map