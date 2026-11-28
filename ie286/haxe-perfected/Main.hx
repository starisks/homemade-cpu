/**
 * Haxe port of the Python 16-bit CPU simulator / assembler.
 *
 * Structure mirrors the original Python module:
 *   - Isa        : register names, opcode table, diops set, signed8 and ALU
 *   - Assembler  : operand parsing, encode / decode, /program.asm loader
 *   - Cpu        : register file, execution, fetch / step / run
 *   - Main       : assembles the program, runs the CPU, prints registers a..h
 *
 * Build / run (sys target required because the program is read from disk):
 *   haxe -cp src -main Main -python out/main.py && python3 out/main.py
 *   (any sys target works: -neko, -hl, -cpp, -java, -cs)
 */

import sys.io.File;

// ---------------------------------------------------------------------------
// Shared types
// ---------------------------------------------------------------------------

/** Result of parse_operand(): either a raw word (str in Python) or an int. */
enum Token {
    Word(s:String);
    Num(v:Int);
}

/** Encoded operand: ("reg", index) or ("imm", value) in Python. */
enum Encoded {
    EReg(index:Int);
    EImm(value:Int);
}

/** Decoded operand: register name (str) or immediate (int) in Python. */
enum Decoded {
    DReg(name:String);
    DImm(value:Int);
}

/** Return value of execute(): False, "halt", or ("jump"/"loop", target). */
enum Flow {
    Continue;
    Halt;
    Jump(kind:String, target:Decoded);
}

/** Encoded instruction: [opcode, encoded_operands] in Python. */
typedef Instr = {
    var opcode:Int;
    var operands:Array<Encoded>;
}

/** Decoded instruction: (operation, decoded_operands) in Python. */
typedef DecodedInstr = {
    var op:String;
    var operands:Array<Decoded>;
}

// ---------------------------------------------------------------------------
// Isa: register layout, opcode table, diops and ALU
// ---------------------------------------------------------------------------

class Isa {
    public static final MASK:Int = 0xFFFF;

    /** Register names in index order (reg / reg_codes in Python). */
    public static final REG_NAMES:String = "abcdefghijklmnop";

    /** name -> name-to-code mapping (isa dict in Python). */
    public static final OPCODES:Map<String, Int> = [
        "add" => 0x00,
        "sub" => 0x01,
        "load" => 0x02,
        "store" => 0x03,
        "halt" => 0x04,
        "and" => 0x05,
        "or" => 0x06,
        "xor" => 0x07,
        "not" => 0x08,
        "<<" => 0x09,
        ">>" => 0x10,
        "mov" => 0x11,
        "clr" => 0x12,
        "inc" => 0x13,
        "dec" => 0x14,
        "nop" => 0x15,
        "loadi" => 0x16,
        "addi" => 0x17,
        "subi" => 0x18,
        "jmp" => 0x19,
        "loop" => 0x20,
        "rol" => 0x21,
        "ror" => 0x22,
        "call" => 0x23,
        "ret" => 0x24,
        "branch" => 0x25,
        "uml" => 0x26,
        "udv" => 0x27,
        "sml" => 0x28,
        "sdv" => 0x29,
        "neg" => 0x30,
        "andi" => 0x31,
        "andn" => 0x32,
        "ori" => 0x33,
        "xori" => 0x34,
        "orn" => 0x35,
        "xnor" => 0x36,
        "sh1add" => 0x37,
        "sh2add" => 0x38,
        "sh3add" => 0x39,
        "rem" => 0x40,
        "remi" => 0x41
    ];

    /** Operations that take two register operands (diops set in Python). */
    public static final DIOPS:Array<String> = [
        "add", "sub", "and", "or", "xor", "<<", ">>", "rol", "ror",
        "uml", "udv", "sml", "sdv"
    ];

    /**
     * Note: the original names this helper signed8 but it interprets the
     * value as a 16-bit two's-complement number (sign bit 0x8000). The
     * behaviour is preserved exactly.
     */
    public static function signed8(x:Int):Int {
        return (x & 0x8000) != 0 ? x - 0x10000 : x;
    }

    public static function alu(x:Int, y:Int, operation:String):Int {
        return switch (operation) {
            case "add": (x + y) & MASK;
            case "sub": (x - y) & MASK;
            case "and": x & y;
            case "or": x | y;
            case "xor": x ^ y;
            case "not": (~x) & MASK;
            // Shifting by >= 16 always yields 0 once masked to 16 bits.
            // Guarding avoids relying on target-specific shift semantics.
            case "<<": y >= 16 ? 0 : (x << y) & MASK;
            case ">>": y >= 16 ? 0 : x >> y;
            case "rol": {
                var s = y % 16;
                ((x << s) | (x >> (16 - s))) & MASK;
            }
            case "ror": {
                var s = y % 16;
                ((x >> s) | (x << (16 - s))) & MASK;
            }
            case "uml": (x * y) & MASK;
            case "udv": {
                if (y == 0) throw "ZeroDivisionError: division by zero";
                // operands are non-negative, so truncation == floor division
                Std.int(x / y);
            }
            case "sml": {
                var sx = signed8(x);
                var sy = signed8(y);
                (sx * sy) & MASK;
            }
            case "sdv": {
                var sx = signed8(x);
                var sy = signed8(y);
                if (sy == 0) throw "ZeroDivisionError: error : division by zero";
                // int(x / y) in Python truncates toward zero; so does Std.int
                Std.int(sx / sy) & MASK;
            }
            default:
                throw 'ValueError: Invalid Operation : $operation';
        };
    }

    /** Builds reg_codes: register name -> index. */
    public static function buildRegCodes():Map<String, Int> {
        var m = new Map<String, Int>();
        for (i in 0...REG_NAMES.length) m.set(REG_NAMES.charAt(i), i);
        return m;
    }

    public static final REG_CODES:Map<String, Int> = buildRegCodes();
}

// ---------------------------------------------------------------------------
// Assembler: parsing, encoding, decoding, program loading
// ---------------------------------------------------------------------------

class Assembler {
    /** str.split() with no arguments: split on runs of whitespace, dropping empties. */
    static function splitWords(s:String):Array<String> {
        var words:Array<String> = [];
        var current = new StringBuf();
        for (i in 0...s.length) {
            var c = s.charCodeAt(i);
            // space, \t, \n, \v, \f, \r
            var isSpace = c == 32 || (c >= 9 && c <= 13);
            if (isSpace) {
                if (current.length > 0) {
                    words.push(current.toString());
                    current = new StringBuf();
                }
            } else {
                current.addChar(c);
            }
        }
        if (current.length > 0) words.push(current.toString());
        return words;
    }

    /** Mirrors int(s, base) for the cases used here. Returns null on ValueError. */
    static function pyInt(s:String, base:Int):Null<Float> {
        var i = 0;
        var negative = false;
        if (i < s.length && (s.charAt(i) == "+" || s.charAt(i) == "-")) {
            negative = s.charAt(i) == "-";
            i++;
        }

        var b = base;
        if (base == 0) {
            var prefix = s.substr(i, 2);
            if (prefix == "0x") b = 16;
            else if (prefix == "0b") b = 2;
            else if (prefix == "0o") b = 8;
            else return null;
            i += 2;
            // Python accepts a single underscore right after the base prefix
            if (i < s.length && s.charAt(i) == "_") i++;
        }

        var digits = s.substr(i);
        if (digits.length == 0
            || digits.charAt(0) == "_"
            || digits.charAt(digits.length - 1) == "_"
            || digits.indexOf("__") >= 0)
            return null;

        var v:Float = 0;
        for (c in 0...digits.length) {
            var ch = digits.charAt(c);
            if (ch == "_") continue;
            var d = digitValue(ch);
            if (d < 0 || d >= b) return null;
            v = v * b + d;
        }
        return negative ? -v : v;
    }

    static function digitValue(ch:String):Int {
        var c:Int = ch.charCodeAt(0);
        if (c >= 48 && c <= 57) return c - 48;        // '0'..'9'
        if (c >= 97 && c <= 122) return c - 97 + 10;  // 'a'..'z'
        return -1;
    }

    /** parse_operand(): lowercase, parse as int (with 0x/0b/0o prefixes) or keep the word. */
    public static function parseOperand(raw:String):Token {
        var x = raw.toLowerCase();

        // body = x.lstrip("+-")
        var body = x;
        while (body.length > 0 && (body.charAt(0) == "+" || body.charAt(0) == "-"))
            body = body.substr(1);

        var hasPrefix = body.length >= 2
            && body.charAt(0) == "0"
            && (body.charAt(1) == "x" || body.charAt(1) == "b" || body.charAt(1) == "o");

        var value:Null<Float> = hasPrefix ? pyInt(x, 0) : pyInt(x, 10);
        if (value == null) return Word(x);

        if (value < -32768 || value > 65535)
            throw 'ValueError: imm out of range ${Std.int(value)}';

        return Num(Std.int(value) & Isa.MASK);
    }

    static function tokenText(t:Token):String {
        return switch (t) {
            case Word(s): s;
            case Num(v): Std.string(v);
        };
    }

    /** encode(instruction, *operands) */
    public static function encode(tokens:Array<Token>):Instr {
        var name:Null<String> = switch (tokens[0]) {
            case Word(s): s;
            case Num(_): null;
        };
        if (name == null || !Isa.OPCODES.exists(name))
            throw 'ValueError: invalid instruction ${tokenText(tokens[0])}';

        var operands:Array<Encoded> = [];
        for (i in 1...tokens.length) {
            switch (tokens[i]) {
                case Word(s) if (Isa.REG_CODES.exists(s)):
                    operands.push(EReg(Isa.REG_CODES.get(s)));
                case Num(v):
                    if (v < 0 || v > 0xFFFF) throw 'ValueError: invalid address $v';
                    operands.push(EImm(v));
                default:
                    throw 'ValueError: invalid operand ${tokenText(tokens[i])}';
            }
        }

        return { opcode: Isa.OPCODES.get(name), operands: operands };
    }

    /** decode(instruction) */
    public static function decode(instruction:Instr):DecodedInstr {
        var operation:Null<String> = null;
        for (name => code in Isa.OPCODES) {
            if (code == instruction.opcode) {
                operation = name;
                break;
            }
        }

        var decoded:Array<Decoded> = [];
        for (o in instruction.operands) {
            switch (o) {
                case EReg(index): decoded.push(DReg(Isa.REG_NAMES.charAt(index)));
                case EImm(value): decoded.push(DImm(value));
            }
        }

        if (operation == null)
            throw 'ValueError: invalid opcode: ${instruction.opcode}';

        return { op: operation, operands: decoded };
    }

    /** Reads the program file and builds instruction memory (module-level code in Python). */
    public static function assemble(path:String):Array<Instr> {
        var instructionMemory:Array<Instr> = [];
        var content = File.getContent(path);

        for (line in content.split("\n")) {
            var code = line.split("#")[0].split(";")[0];
            var words = splitWords(StringTools.replace(code, ",", " "));
            if (words.length == 0) continue;

            var tokens = [for (w in words) parseOperand(w)];
            instructionMemory.push(encode(tokens));
        }
        return instructionMemory;
    }
}

// ---------------------------------------------------------------------------
// CPU
// ---------------------------------------------------------------------------

class Cpu {
    public var reg:Map<String, Int>;
    public var pc:Int = 0;
    public var ir:Null<Instr> = null;
    public var halted:Bool = false;
    public var zeroFlag:Bool = false;
    public var stack:Array<Int> = [];

    final instructionMemory:Array<Instr>;

    public function new(instructionMemory:Array<Instr>) {
        this.instructionMemory = instructionMemory;
        reg = new Map<String, Int>();
        for (i in 0...Isa.REG_NAMES.length) reg.set(Isa.REG_NAMES.charAt(i), 0);
    }

    // --- operand helpers (reg[dest] in Python; an immediate index raises KeyError) ---

    function regName(o:Decoded):String {
        return switch (o) {
            case DReg(n): n;
            case DImm(v): throw 'KeyError: $v';
        };
    }

    function getReg(o:Decoded):Int {
        return reg.get(regName(o));
    }

    function setReg(o:Decoded, v:Int):Void {
        reg.set(regName(o), v);
    }

    /** Tuple unpacking: `a, b = operands` raises ValueError on mismatch. */
    static function expect(operands:Array<Decoded>, n:Int):Array<Decoded> {
        if (operands.length != n)
            throw 'ValueError: expected $n operand(s), got ${operands.length}';
        return operands;
    }

    function execute(operation:String, operands:Array<Decoded>):Flow {
        switch (operation) {
            case "not": {
                var d = expect(operands, 1)[0];
                setReg(d, Isa.alu(getReg(d), 0, "not"));
                zeroFlag = getReg(d) == 0;
                return Continue;
            }

            case "clr": {
                var d = expect(operands, 1)[0];
                setReg(d, 0);
                zeroFlag = getReg(d) == 0;
                return Continue;
            }

            case "inc": {
                var d = expect(operands, 1)[0];
                setReg(d, (getReg(d) + 1) & Isa.MASK);
                zeroFlag = getReg(d) == 0;
                return Continue;
            }

            case "dec": {
                var d = expect(operands, 1)[0];
                setReg(d, (getReg(d) - 1) & Isa.MASK);
                zeroFlag = getReg(d) == 0;
                return Continue;
            }

            case "jmp": {
                var address = expect(operands, 1)[0];
                return Jump("jump", address);
            }

            case "loop": {
                var ops = expect(operands, 2);
                var dest = ops[0];
                var address = ops[1];
                setReg(dest, (getReg(dest) - 1) & Isa.MASK);
                zeroFlag = getReg(dest) == 0;
                if (getReg(dest) != 0) return Jump("loop", address);
                return Continue;
            }

            case "call": {
                var address = expect(operands, 1)[0];
                stack.push(pc + 1);
                return Jump("jump", address);
            }

            case "ret": {
                if (stack.length == 0) throw "RuntimeError: stack is empty";
                var returnAddress = stack.pop();
                return Jump("jump", DImm(returnAddress));
            }

            case "branch": {
                var address = expect(operands, 1)[0];
                if (zeroFlag) return Jump("jump", address);
                return Continue;
            }

            case "neg": {
                var d = expect(operands, 1)[0];
                setReg(d, (-getReg(d)) & Isa.MASK);
                zeroFlag = getReg(d) == 0;
                return Continue;
            }

            case "andn": {
                var ops = expect(operands, 3);
                var dest = ops[0];
                var src = ops[1];
                var src2 = ops[2];
                setReg(dest, Isa.alu(getReg(src), (~getReg(src2)) & Isa.MASK, "and"));
                zeroFlag = getReg(dest) == 0;
                return Continue;
            }

            case "orn": {
                var ops = expect(operands, 3);
                var dest = ops[0];
                var src = ops[1];
                var src2 = ops[2];
                setReg(dest, Isa.alu(getReg(src), (~getReg(src2)) & Isa.MASK, "or"));
                zeroFlag = getReg(dest) == 0;
                return Continue;
            }

            case "xnor": {
                var ops = expect(operands, 3);
                var dest = ops[0];
                var src = ops[1];
                var src2 = ops[2];
                setReg(dest, Isa.alu(getReg(src), (~getReg(src2)) & Isa.MASK, "xor"));
                zeroFlag = getReg(dest) == 0;
                return Continue;
            }

            case "sh1add": {
                var ops = expect(operands, 3);
                var dest = ops[0];
                var src = ops[1];
                var src2 = ops[2];
                setReg(dest, ((getReg(src) << 1) + getReg(src2)) & Isa.MASK);
                zeroFlag = getReg(dest) == 0;
                return Continue;
            }

            case "sh2add": {
                var ops = expect(operands, 3);
                var dest = ops[0];
                var src = ops[1];
                var src2 = ops[2];
                setReg(dest, ((getReg(src) << 2) + getReg(src2)) & Isa.MASK);
                zeroFlag = getReg(dest) == 0;
                return Continue;
            }

            case "sh3add": {
                var ops = expect(operands, 3);
                var dest = ops[0];
                var src = ops[1];
                var src2 = ops[2];
                setReg(dest, ((getReg(src) << 3) + getReg(src2)) & Isa.MASK);
                zeroFlag = getReg(dest) == 0;
                return Continue;
            }

            case "halt":
                return Halt;

            default: {
                // Two-register ALU operations (diops). Every other mnemonic
                // (mov, load, store, loadi, addi, subi, andi, ori, xori, rem,
                // remi, nop, ...) is a no-op here, exactly as in the original.
                if (Isa.DIOPS.contains(operation)) {
                    var ops = expect(operands, 2);
                    var dest = ops[0];
                    var src = ops[1];
                    setReg(dest, Isa.alu(getReg(dest), getReg(src), operation));
                    zeroFlag = getReg(dest) == 0;
                }
                return Continue;
            }
        }
    }

    function fetch():Void {
        ir = instructionMemory[pc];
    }

    public function step():Void {
        if (halted) return;

        if (pc < 0 || pc >= instructionMemory.length) {
            halted = true;
            return;
        }

        fetch();
        var decoded = Assembler.decode(ir);
        var result = execute(decoded.op, decoded.operands);

        switch (result) {
            case Halt:
                halted = true;
            case Jump(kind, target):
                var t = switch (target) {
                    case DImm(v): v;
                    case DReg(_): throw '$kind target must be an integer';
                };
                if (t < 0 || t >= instructionMemory.length)
                    throw 'RuntimeError: $kind target is invalid $t';
                pc = t;
            case Continue:
                pc++;
        }
    }

    public function run(maxSteps:Int = 1000000):Void {
        for (i in 0...maxSteps) {
            step();
            if (halted) return;
        }
        throw 'RuntimeError: maximum step count exceeded: ($maxSteps)';
    }
}

// ---------------------------------------------------------------------------
// Entry point (module-level code in the Python original)
// ---------------------------------------------------------------------------

class Main {
    static function main():Void {
        var program = Assembler.assemble("/program.asm");

        var cpu = new Cpu(program);
        cpu.run();

        Sys.println("register data:");
        for (i in 0...8) {
            Sys.println(Std.string(cpu.reg.get(Isa.REG_NAMES.charAt(i))));
        }
    }
}
