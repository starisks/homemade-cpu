enum PyValue {
    Str(s:String);
    Num(v:Int);
}

typedef EncodedOperand = {
    kind:String,
    value:Int
}

typedef Instruction = {
    opcode:Int,
    operands:Array<EncodedOperand>
}

typedef Decoded = {
    operation:String,
    operands:Array<PyValue>
}

enum ExecResult {
    NoResult;
    Halt;
    Jump(kind:String, target:PyValue);
}

class Main {
    // registers
    public static var reg:Map<String, Int> = [
        "a" => 0,
        "b" => 0,
        "c" => 0,
        "d" => 0,
        "e" => 0,
        "f" => 0,
        "g" => 0,
        "h" => 0
    ];

    public static var regCodes:Map<String, Int> = [
        "a" => 0,
        "b" => 1,
        "c" => 2,
        "d" => 3,
        "e" => 4,
        "f" => 5,
        "g" => 6,
        "h" => 7
    ];

    // list(reg_codes.keys()) in insertion order
    public static var regNames:Array<String> = ["a", "b", "c", "d", "e", "f", "g", "h"];

    // memory
    public static var memory:Array<Int> = [for (i in 0...256) 0];
    public static var instructionMemory:Array<Instruction> = [];

    // instruction set
    public static var isa:Map<String, Int> = [
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

    public static var diops:Array<String> = ["add", "sub", "and", "or", "xor", "<<", ">>", "rol", "ror", "uml", "udv", "sml", "sdv"];

    // ---------- helpers ----------

    public static function pyStr(v:PyValue):String {
        return switch (v) {
            case Str(s): s;
            case Num(n): Std.string(n);
        }
    }

    // Keys for the reg dictionary: register names are plain strings,
    // integer addresses are stored with a "#" prefix so they never collide.
    public static function regKey(v:PyValue):String {
        return switch (v) {
            case Str(s): s;
            case Num(n): "#" + n;
        }
    }

    // reg[key] (read): raises KeyError when the key is missing
    public static function regGet(key:PyValue):Int {
        var k = regKey(key);
        if (!reg.exists(k)) {
            throw new haxe.Exception("KeyError: " + pyStr(key));
        }
        return reg.get(k);
    }

    // reg[key] = value (write)
    public static function regSet(key:PyValue, value:Int):Void {
        reg.set(regKey(key), value);
    }

    // Emulates tuple unpacking such as "dest, = operands"
    public static function unpackOperands(operands:Array<PyValue>, count:Int):Array<PyValue> {
        if (operands.length != count) {
            throw new haxe.Exception("ValueError: wrong number of operands to unpack (expected " + count + ", got " + operands.length + ")");
        }
        return operands;
    }

    // signed integer
    public static function signed8(x:Int):Int {
        if ((x & 0x80) != 0) {
            return x - 0x100;
        }
        return x;
    }

    public static function ALU(x:Int, y:Int, operation:String):Int {
        if (operation == "add") {
            return (x + y) & 0xFF;
        } else if (operation == "sub") {
            return (x - y) & 0xFF;
        } else if (operation == "and") {
            return x & y;
        } else if (operation == "or") {
            return x | y;
        } else if (operation == "xor") {
            return x ^ y;
        } else if (operation == "not") {
            return (~x) & 0xFF;
        } else if (operation == "<<") {
            // shift counts >= 8 always yield 0 after masking (explicit to avoid Haxe's 5-bit shift masking)
            return (y >= 8) ? 0 : ((x << y) & 0xFF);
        } else if (operation == ">>") {
            // explicit guard: Haxe masks shift counts to 5 bits; Python shifts by any amount
            return (y >= 8) ? 0 : (x >> y);
        } else if (operation == "rol") {
            y = y % 8;
            return ((x << y) | (x >> (8 - y))) & 0xFF;
        } else if (operation == "ror") {
            y = y % 8;
            return ((x >> y) | (x << (8 - y))) & 0xFF;
        } else if (operation == "uml") {
            return (x * y) & 0xFF;
        } else if (operation == "udv") {
            if (y == 0) {
                throw new haxe.Exception("ZeroDivisionError: division by zero");
            }
            return Std.int(x / y);
        } else if (operation == "sml") {
            x = signed8(x);
            y = signed8(y);

            return (x * y) & 0xFF;
        } else if (operation == "sdv") {
            x = signed8(x);
            y = signed8(y);

            if (y == 0) {
                throw new haxe.Exception("ZeroDivisionError: error : division by zero");
            }

            return Std.int(x / y) & 0xFF;
        } else {
            throw new haxe.Exception("ValueError: Invalid Operation : " + operation);
        }
    }

    public static function encode(instruction:PyValue, operands:Array<PyValue>):Instruction {
        var name:String = switch (instruction) {
            case Str(s): s;
            case Num(_): null;
        };
        if (name == null || !isa.exists(name)) {
            throw new haxe.Exception("ValueError: invalid instruction " + pyStr(instruction));
        }

        var opcode = isa.get(name);
        var encodedOperands:Array<EncodedOperand> = [];

        for (operand in operands) {
            switch (operand) {
                case Str(s) if (regCodes.exists(s)):
                    encodedOperands.push({kind: "reg", value: regCodes.get(s)});
                case Num(v):
                    if (!(0 <= v && v <= 0xFF)) {
                        throw new haxe.Exception("ValueError: invalid address " + v);
                    }
                    encodedOperands.push({kind: "imm", value: v});
                default:
                    throw new haxe.Exception("ValueError: invalid operand " + pyStr(operand));
            }
        }

        return {opcode: opcode, operands: encodedOperands};
    }

    // hex comprehension
    public static function digitValue(c:String):Int {
        var code = c.charCodeAt(0);
        if (code >= 48 && code <= 57) {
            return code - 48; // '0'..'9'
        }
        if (code >= 97 && code <= 122) {
            return code - 97 + 10; // 'a'..'z'
        }
        return -1;
    }

    // Emulates Python's int(s, base); returns null where Python raises ValueError.
    // base == 0 requires a 0x / 0o / 0b prefix (the only way this program calls it).
    public static function pyInt(s:String, base:Int):Null<Int> {
        var i = 0;
        var negative = false;
        if (i < s.length && (s.charAt(i) == "+" || s.charAt(i) == "-")) {
            negative = s.charAt(i) == "-";
            i++;
        }

        var b = base;
        if (b == 0) {
            var prefix = s.substr(i, 2);
            if (prefix == "0x") {
                b = 16;
            } else if (prefix == "0o") {
                b = 8;
            } else if (prefix == "0b") {
                b = 2;
            } else {
                return null;
            }
            i += 2;
        }

        var digits = s.substr(i);
        if (digits.length == 0 || digits.charAt(0) == "_" || digits.charAt(digits.length - 1) == "_") {
            return null;
        }

        var value = 0;
        var previousUnderscore = false;
        for (k in 0...digits.length) {
            var ch = digits.charAt(k);
            if (ch == "_") {
                if (previousUnderscore) {
                    return null;
                }
                previousUnderscore = true;
                continue;
            }
            previousUnderscore = false;

            var d = digitValue(ch);
            if (d < 0 || d >= b) {
                return null;
            }
            // saturate so huge literals stay out of the valid range (Python would raise ValueError on range check)
            if (value <= 100000000) {
                value = value * b + d;
            }
        }

        return negative ? -value : value;
    }

    public static function parseOperand(token:String):PyValue {
        var x = token.toLowerCase();

        // x.lstrip("+-")
        var i = 0;
        while (i < x.length && (x.charAt(i) == "+" || x.charAt(i) == "-")) {
            i++;
        }
        var body = x.substr(i);

        var prefix = body.substr(0, 2);
        var value:Null<Int>;
        if (prefix == "0x" || prefix == "0b" || prefix == "0o") {
            value = pyInt(x, 0);
        } else {
            value = pyInt(x, 10);
        }

        if (value == null) {
            return Str(x);
        }

        if (!(-128 <= value && value <= 255)) {
            throw new haxe.Exception("ValueError: imm out of range " + value);
        }

        return Num(value & 0xFF);
    }

    // str.split() with no arguments: split on whitespace runs, drop empty pieces
    public static function splitWhitespace(s:String):Array<String> {
        var result:Array<String> = [];
        for (t in ~/\s+/g.split(s)) {
            if (t != "") {
                result.push(t);
            }
        }
        return result;
    }

    public static function decode(instruction:Instruction):Decoded {
        var opcode = instruction.opcode;
        var operands = instruction.operands;
        var operation:Null<String> = null;

        for (name in isa.keys()) {
            if (isa.get(name) == opcode) {
                operation = name;
                break;
            }
        }

        var decodedOperands:Array<PyValue> = [];

        for (encoded in operands) {
            if (encoded.kind == "reg") {
                decodedOperands.push(Str(regNames[encoded.value]));
            } else if (encoded.kind == "imm") {
                decodedOperands.push(Num(encoded.value));
            }
        }

        if (operation == null) {
            throw new haxe.Exception("ValueError: invalid opcode: " + opcode);
        }

        return {operation: operation, operands: decodedOperands};
    }

    public static function readInstruction(address:Int):Instruction {
        return instructionMemory[address];
    }

    // ---------- main ----------

    static function main():Void {
        // code
        var content = sys.io.File.getContent("/program.asm");
        // emulate Python universal newlines
        content = content.split("\r\n").join("\n").split("\r").join("\n");

        for (rawLine in content.split("\n")) {
            var line = rawLine.split("#")[0].split(";")[0];
            var parts = splitWhitespace(line.split(",").join(" "));

            if (parts.length > 0) {
                var parsed:Array<PyValue> = [for (x in parts) parseOperand(x)];
                var instruction = encode(parsed[0], parsed.slice(1));
                instructionMemory.push(instruction);
            }
        }

        // cpu instance
        var cpu = new CPU();

        cpu.run();

        Sys.println("register data:");

        for (r in "abcdefgh".split("")) {
            Sys.println(Std.string(reg.get(r)));
        }
    }
}

class CPU {
    public var pc:Int;
    public var ir:Null<Instruction>;
    public var halted:Bool;
    public var zeroFlag:Bool;
    public var stack:Array<Int>;

    public function new() {
        pc = 0;
        ir = null;
        halted = false;
        zeroFlag = false;
        stack = [];
    }

    public function execute(operation:String, operands:Array<PyValue>):ExecResult {
        if (operation == "not") {
            var dest = Main.unpackOperands(operands, 1)[0];

            Main.regSet(dest, Main.ALU(Main.regGet(dest), 0, "not"));

            zeroFlag = (Main.regGet(dest) == 0);

        } else if (operation == "clr") {
            var dest = Main.unpackOperands(operands, 1)[0];

            Main.regSet(dest, 0);

            zeroFlag = (Main.regGet(dest) == 0);

        } else if (operation == "inc") {
            var dest = Main.unpackOperands(operands, 1)[0];

            Main.regSet(dest, (Main.regGet(dest) + 1) & 0xFF);

            zeroFlag = (Main.regGet(dest) == 0);

        } else if (operation == "dec") {
            var dest = Main.unpackOperands(operands, 1)[0];

            Main.regSet(dest, (Main.regGet(dest) - 1) & 0xFF);

            zeroFlag = (Main.regGet(dest) == 0);

        } else if (operation == "nop") {
            // pass

        } else if (operation == "jmp") {
            var address = Main.unpackOperands(operands, 1)[0];
            return Jump("jump", address);

        } else if (operation == "loop") {
            var ops = Main.unpackOperands(operands, 2);
            var dest = ops[0];
            var address = ops[1];

            Main.regSet(dest, (Main.regGet(dest) - 1) & 0xFF);

            zeroFlag = (Main.regGet(dest) == 0);

            if (Main.regGet(dest) != 0) {
                return Jump("loop", address);
            }

        } else if (operation == "call") {
            var address = Main.unpackOperands(operands, 1)[0];

            stack.push(pc + 1);
            return Jump("jump", address);

        } else if (operation == "ret") {
            if (stack.length == 0) {
                throw new haxe.Exception("RuntimeError: stack is empty");
            }

            var returnAddress = stack.pop();

            return Jump("jump", Num(returnAddress));

        } else if (operation == "branch") {
            var address = Main.unpackOperands(operands, 1)[0];

            if (zeroFlag) {
                return Jump("jump", address);
            }

        } else if (operation == "neg") {
            var dest = Main.unpackOperands(operands, 1)[0];

            Main.regSet(dest, (-Main.regGet(dest)) & 0xFF);

            zeroFlag = (Main.regGet(dest) == 0);

        } else if (operation == "andn") {
            var ops = Main.unpackOperands(operands, 3);
            var dest = ops[0];
            var src = ops[1];
            var src2 = ops[2];

            Main.regSet(dest, Main.ALU(
                Main.regGet(src),
                (~Main.regGet(src2)) & 0xFF,
                "and"
            ));

            zeroFlag = (Main.regGet(dest) == 0);

        } else if (operation == "orn") {
            var ops = Main.unpackOperands(operands, 3);
            var dest = ops[0];
            var src = ops[1];
            var src2 = ops[2];

            Main.regSet(dest, Main.ALU(
                Main.regGet(src),
                (~Main.regGet(src2)) & 0xFF,
                "or"
            ));

            zeroFlag = (Main.regGet(dest) == 0);

        } else if (operation == "xnor") {
            var ops = Main.unpackOperands(operands, 3);
            var dest = ops[0];
            var src = ops[1];
            var src2 = ops[2];

            Main.regSet(dest, Main.ALU(
                Main.regGet(src),
                (~Main.regGet(src2)) & 0xFF,
                "xor"
            ));

            zeroFlag = (Main.regGet(dest) == 0);

        } else if (operation == "sh1add") {
            var ops = Main.unpackOperands(operands, 3);
            var dest = ops[0];
            var src = ops[1];
            var src2 = ops[2];

            Main.regSet(dest, (
                (Main.regGet(src) << 1) + Main.regGet(src2)
            ) & 0xFF);

            zeroFlag = (Main.regGet(dest) == 0);

        } else if (operation == "sh2add") {
            var ops = Main.unpackOperands(operands, 3);
            var dest = ops[0];
            var src = ops[1];
            var src2 = ops[2];

            Main.regSet(dest, (
                (Main.regGet(src) << 2) + Main.regGet(src2)
            ) & 0xFF);

            zeroFlag = (Main.regGet(dest) == 0);

        } else if (operation == "sh3add") {
            var ops = Main.unpackOperands(operands, 3);
            var dest = ops[0];
            var src = ops[1];
            var src2 = ops[2];

            Main.regSet(dest, (
                (Main.regGet(src) << 3) + Main.regGet(src2)
            ) & 0xFF);

            zeroFlag = (Main.regGet(dest) == 0);

        } else if (Main.diops.contains(operation)) {
            var ops = Main.unpackOperands(operands, 2);
            var dest = ops[0];
            var src = ops[1];

            Main.regSet(dest, Main.ALU(Main.regGet(dest), Main.regGet(src), operation));

            zeroFlag = Main.regGet(dest) == 0;

        } else if (operation == "halt") {
            return Halt;
        }

        return NoResult;
    }

    public function fetch():Void {
        ir = Main.readInstruction(pc);
    }

    public function step():Void {
        if (halted) {
            return;
        }

        if (!(0 <= pc && pc < Main.instructionMemory.length)) {
            halted = true;
            return;
        }

        fetch();
        var decoded = Main.decode(ir);

        var result = execute(decoded.operation, decoded.operands);

        switch (result) {
            case Halt:
                halted = true;
            case Jump(kind, target):
                switch (target) {
                    case Num(t):
                        if (!(0 <= t && t < Main.instructionMemory.length)) {
                            throw new haxe.Exception("RuntimeError: " + kind + " target is invalid " + t);
                        }
                        pc = t;
                    case Str(_):
                        // Python: comparing int with str raises TypeError
                        throw new haxe.Exception("TypeError: '<=' not supported between instances of 'int' and 'str'");
                }
            case NoResult:
                pc += 1;
        }
    }

    public function run(maxSteps:Int = 1000000):Void {
        for (_ in 0...maxSteps) {
            step();
            if (halted) {
                return;
            }
        }

        throw new haxe.Exception("RuntimeError: maximum step count exceeded: (" + maxSteps + ")");
    }
}
