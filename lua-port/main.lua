-- registers
reg = {
    a=0,
    b=0,
    c=0,
    d=0,
    e=0,
    f=0,
    g=0,
    h=0
}

reg_codes = {
    a=0,
    b=1,
    c=2,
    d=3,
    e=4,
    f=5,
    g=6,
    h=7,
}

-- memory
memory = {}
for i = 1, 256 do
    memory[i] = 0
end
instruction_memory = {}

-- instruction set
isa = {
    add = 0x00,
    sub = 0x01,
    halt = 0x03,
    ["and"] = 0x04,
    ["or"] = 0x05,
    xor = 0x06,
    ["not"] = 0x07,
    ["<<"] = 0x08,
    [">>"] = 0x19,
    clr = 0x10,
    inc = 0x11,
    dec = 0x12,
    nop = 0x13,
    jmp = 0x14,
    loop = 0x25,
    rol = 0x16,
    ror = 0x17,
    call = 0x18,
    ret = 0x19,
    branch = 0x20,
    uml = 0x21,
    udv = 0x22,
    sml = 0x23,
    sdv = 0x24,
    neg = 0x25,
    andn = 0x26,
    orn = 0x27,
    xnor = 0x28,
    sh1add = 0x29,
    sh2add = 0x30,
    sh3add = 0x31,
}

diops = {"add","sub","and","or","xor","<<",">>","rol","ror","uml","udv","sml","sdv"}

-- signed integer
function signed8(x)
    if (x & 0x80) ~= 0 then
        return x - 0x100
    end
    return x
end

-- diops to set
diops = {}
for _, name in ipairs({'add', 'sub', 'and', 'or', 'xor', '<<', '>>', 'rol', 'ror', 'uml', 'udv', 'sml', 'sdv'}) do
    diops[name] = true
end

-- alu
function alu(x, y, operation)
    if (operation == "add") then
        return (x + y) & 0xFF
    elseif (operation == "sub") then
        return (x - y) & 0xFF
    elseif (operation == "and") then
        return x & y
    elseif (operation == "or") then
        return x | y
    elseif (operation == "xor") then
        return x ^ y
    elseif (operation == "not") then
        return ~x & 0xFF
    elseif (operation == "<<") then
        return (x << y) & 0xFF
    elseif (operation == ">>") then
        return (x >> y)
    elseif (operation == "rol") then
        y = y % 8
        return ((x << y) | (x >> (8 - y))) & 0xFF
    elseif (operation == "ror") then
        y = y % 8
        return ((x >> y) | (x << (8 - y))) & 0xFF
    elseif (operation == "uml") then
        return (x * y) & 0xFF
    elseif (operation == "udv") then
        if (y == 0) then
            error("division by zero")
        end
        return x // y
    elseif (operation == "sml") then
        x = signed8(x)
        y = signed8(y)
        return (x * y) & 0xFF
    elseif (operation == "sdv") then
        x = signed8(x)
        y = signed8(y)
        if (y == 0) then
            error("division by zero")
        end
        return math.modf(x / y) & 0xFF
    else
        error()
    end
end

-- encode
function encode(instruction, ...)
    local operands = {...} 
    if not isa[instruction] then
        error("Invalid Instruction")
    end

    local opcode = isa[instruction]
    local encoded_operands = {}
    local operand

    for _, operand in ipairs(operands) do
        if type(operand) == "string" and reg_codes[operand] ~= nil then
            table.insert(encoded_operands, {"reg", reg_codes[operand]})

        elseif type(operand) == "number" then
            if not(0 <= operand and operand <= 0xFF) then
                error("invalid address")
            end
            table.insert(encoded_operands, {"imm", operand})
        else
            error("invalid operand")
        end
    end
    return {opcode, encoded_operands}
end

-- hex comprehension
function parse_operand(x)
    x = string.lower(x)
    local body = string.gsub(x, "^[+-]+", "")

    local sign = 1
    if string.sub(x, 1, 1) == "-" then
        sign = -1
    end

    local base = 10
    if body:match("^0x") then
        base, body = 16, string.sub(body, 3)
    elseif body:match("^0b") then
        base, body = 2, string.sub(body, 3)
    elseif body:match("^0o") then
        base, body = 8, string.sub(body, 3)
    end

    local value = tonumber(body, base)
    if value == nil then
        return x
    end

    value = value * sign

    if not(-128 <= value and value <= 255) then
        error("imm out of range")
    end

    return value % 256
end

-- read file
local file = assert(io.open("../program.asm", "r"))

for line in file:lines() do
    line = (line:match("^[^#;]*") or ""):gsub(",", " ")

    local parts = {}

    for part in line:gmatch("%S+") do
        table.insert(parts, parse_operand(part))
    end

    if #parts > 0 then
        table.insert(instruction_memory, encode(table.unpack(parts)))
    end
end

-- decode
function decode(instruction)
    local opcode, operands = instruction[1], instruction[2]
    local operation = nil

    for name, code in pairs(isa) do
        if code == opcode then
            operation = name
            break
        end
    end

    local decoded_operands = {}

    for _, operand in ipairs(operands) do
        local operand_type, value = operand[1], operand[2]
        if operand_type == "reg" then

            reg_name = nil

            for name, code in pairs(reg_codes) do
                if code == value then
                    reg_name = name
                    break
                end
            end

            table.insert(decoded_operands, reg_name)
        elseif operand_type == "imm" then
            table.insert(decoded_operands, value)
        end
    end

    if operation == nil then
        error("invalid opcode")
    end

    return operation, decoded_operands
end

-- read instruction
function read_instruction(address)
    return instruction_memory[address + 1]
end

-- cpu, lua does not have classes
CPU = {}
CPU.__index = CPU

function CPU.new()
    local self = setmetatable({}, CPU)
    self.pc = 0
    self.ir = nil
    self.halted = false
    self.zero_flag = false
    self.stack = {}

    return self
end

-- cpu execute
function CPU:execute(operation, operands)
    if operation == "not" then
        local dest = operands[1]
        
        reg[dest] = alu(
            reg[dest],
            0,
            "not"
        )

        self.zero_flag = (reg[dest] == 0)
    elseif operation == "clr" then
        local dest = operands[1]

        reg[dest] = 0

        self.zero_flag = (reg[dest] == 0)
    elseif operation == "inc" then
        local dest = operands[1]

        reg[dest] = (reg[dest] + 1) & 0xFF

        self.zero_flag = (reg[dest] == 0)
    elseif operation == "dec" then
        local dest = operands[1]

        reg[dest] = (reg[dest] - 1) & 0xFF

        self.zero_flag = (reg[dest] == 0)
    elseif operation == "nop" then

    elseif operation == "jmp" then
        local address = operands[1]
        return ({"jump", address})
    elseif operation == "loop" then
        local dest, address = operands[1], operands[2]

        reg[dest] = (reg[dest] - 1) & 0xFF

        if reg[dest] ~= 0 then
            return ({"loop", address})
        end
    elseif operation == "call" then
        local address = operands[1]

        table.insert(self.stack, self.pc + 1)
        return ({"jump", address})
    elseif operation == "ret" then
        if #self.stack == 0 then
            error("stack is empty")
        end

        local return_address = table.remove(self.stack)

        return ({"jump", return_address})
    elseif operation == "branch" then
        local address = operands[1]

        if self.zero_flag then
            return ({"jump", address})
        end
    elseif operation == "neg" then
        local dest = operands[1]

        reg[dest] = (-reg[dest]) & 0xFF

        self.zero_flag = (reg[dest] == 0)
    elseif operation == "andn" then
        local dest, src, src2 = operands[1], operands[2], operands[3]

        reg[dest] = alu(
            reg[src],
            (~reg[src2]) & 0xFF,
            "and"
        )

        self.zero_flag = (reg[dest] == 0)
    elseif operation == "orn" then
        local dest, src, src2 = operands[1], operands[2], operands[3]

        reg[dest] = alu(
            reg[src],
            (~reg[src2]) & 0xFF,
            "or"
        )

        self.zero_flag = (reg[dest] == 0)
    elseif operation == "xnor" then
        local dest, src, src2 = operands[1], operands[2], operands[3]

        reg[dest] = alu(
            reg[src],
            (~reg[src2]) & 0xFF,
            "xor"
        )

        self.zero_flag = (reg[dest] == 0)
    elseif operation == "sh1add" then
        local dest, src, src2 = operands[1], operands[2], operands[3]

        reg[dest] = (
            (reg[src] << 1) + reg[src2]
        ) & 0xFF

        self.zero_flag = (reg[dest] == 0)
    elseif operation == "sh2add" then
        local dest, src, src2 = operands[1], operands[2], operands[3]

        reg[dest] = (
            (reg[src] << 2) + reg[src2]
        ) & 0xFF

        self.zero_flag = (reg[dest] == 0)
    elseif operation == "sh3add" then
        local dest, src, src2 = operands[1], operands[2], operands[3]

        reg[dest] = (
            (reg[src] << 3) + reg[src2]
        ) & 0xFF

        self.zero_flag = (reg[dest] == 0)
    elseif diops[operation] then
        local dest, src = operands[1], operands[2]

        reg[dest] = alu(reg[dest], reg[src], operation)

        self.zero_flag = (reg[dest] == 0)
    elseif operation == "halt" then
        return "halt"
    end
end

-- cpu fetch
function CPU:fetch()
    self.ir = read_instruction(self.pc)
end

-- cpu step
function CPU:step()
    if self.halted then
        return
    end

    if not (0 <= self.pc and self.pc < #instruction_memory) then
        self.halted = true
        return
    end

    self:fetch()
    local operation, operands = decode(self.ir)

    local result = self:execute(operation, operands)

    if result == "halt" then
        self.halted = true
    elseif type(result) == "table" then
        local kind, target = result[1], result[2]

        if not (0 <= target and target < #instruction_memory) then
            error("target is invalid")
        end

        self.pc = target
    else
        self.pc = self.pc + 1
    end
end

-- max steps
max_steps = 1000000


-- cpu run
function CPU:run()
    for _ = 1, max_steps do
        self:step()
        if self.halted then
            return
        end
    end
    error("max steps reached")
end

-- cpu instance
cpu = CPU.new()

cpu:run()

print("register data")

for _, name in ipairs({"a", "b", "c", "d", "e", "f", "g", "h"}) do
    print(reg[name])
end