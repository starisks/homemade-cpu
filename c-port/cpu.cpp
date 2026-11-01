#include <iostream>
#include <unordered_map>
#include <string>
#include <array>
#include <cstdint>
#include <vector>

// something ig
enum class OperandType {
    REGISTER, 
    IMMEDIATE,
    INT
};

struct EncodedOperand {
    std::string type;
    int value;
};

struct Operand {
    OperandType type;
    std::string value;

    Operand(OperandType type, std::string value)
        : type(type), value(value) {}
};

struct Instruction {
    int opcode;
    std::vector<EncodedOperand> operands;
};

struct DecodedOperand {
    std::string operation;
    std::vector<std::string> operands;
};

enum class ResultType {
    BOOL,
    STRING,
    TUPLE,
    ENCODED
};

struct ExecuteResult {
    ResultType type;
    bool bool_value;
    std::string string_value;
    std::vector<int> tuple_value;
    std::string kind;
    int target;
};

std::array<int, 8> reg{};

std::array<std::string, 8> reg_names = {
    "a", "b", "c", "d", "e", "f", "g", "h"
};

std::unordered_map<std::string, int> reg_codes = {
    {"a", 0},
    {"b", 1},
    {"c", 2},
    {"d", 3},
    {"e", 4},
    {"f", 5},
    {"g", 6},
    {"h", 7}
};

// mem
std::array<uint8_t, 256> memory{};
std::vector<Instruction> instruction_memory;


// instruction set
std::unordered_map<std::string, int> isa = {
    {"add", 0x00},
    {"sub", 0x01},
    {"halt", 0x02},
    {"and", 0x03},
    {"or", 0x04},
    {"nop", 0x05},
    {"inc", 0x06},
    {"dec", 0x07},
    {"uml", 0x08},
    {"udv", 0x09},
    {"sml", 0x10},
    {"sdv", 0x11},
    {"xor", 0x12},
    {"not", 0x13},
    {"clr", 0x14},
    {"neg", 0x15},
    {"branch", 0x16},
    {"jmp", 0x17}
};

// alu
int ALU(int x, int y, int operation) {
    switch (operation) {
        case 0x00:
            return (x + y) & 0xFF;
        case 0x01:
            return (x - y) & 0xFF;
        case 0x03:
            return (x & y);
        case 0x04:
            return (x | y);
        case 0x08:
            return (x * y);
        case 0x09:
            if (y == 0) {
                throw std::invalid_argument("division by zero");
            }
            else {
                return (x / y);
            }
        case 0x10:
            return (x * y) & 0xFF;
        case 0x11:
            if (y == 0) {
                throw std::invalid_argument("division by zero");
            }
            else {
                return (x / y) & 0xFF;
            }
        case 0x12:
            return (x ^ y);
        default:
            return 0;
        
    }
};

// dreaded encode
Instruction encode(
    const std::string& instruction,
    const std::initializer_list<Operand>& operands
) {
    Instruction result;
    result.opcode = isa.at(instruction);

    for (const Operand& operand : operands) {

        if (operand.type == OperandType::REGISTER) {

            if (reg_codes.contains(operand.value)) {

                EncodedOperand encoded_operands;
                encoded_operands.type = "reg";
                encoded_operands.value = reg_codes.at(operand.value);

                result.operands.push_back(encoded_operands);
            }
        }
        else if (operand.type == OperandType::INT) {
            int value = std::stoi(operand.value);

            if (!(0 <= value && value <= 0xFF)) {
                throw std::invalid_argument("invalid address");
            }

            EncodedOperand encoded_operand;
            encoded_operand.type = "imm";
            encoded_operand.value = std::stoi(operand.value);

            result.operands.push_back(encoded_operand);
        }
        else {
            throw std::invalid_argument("invalid operand");
        }
    }
    return result;
}

// encode is done. hex comprehension is not needed
// cuz we are hardcoding instructions
// decode
DecodedOperand decode(const Instruction& instruction) {
    int opcode = instruction.opcode;
    const auto& operands = instruction.operands;
    std::string operation;
    std::vector<std::string> keys;

    for (const auto& [name, code] : isa) {
        if (code == opcode) {
            operation = name;
            break;
        }
    }
    std::vector<std::string> decoded_operands;

    for (const auto& [operand_type, value] : operands) {
        if (operand_type == "reg") {
            std::vector<std::string> reg_names;
            for (const auto& [key, value] : reg_codes) {
                reg_names.push_back(key);
            }
            decoded_operands.push_back(reg_names[value]);
        }
        else if (operand_type == "imm") {
            decoded_operands.push_back(std::to_string(value));
        }   
    }
    return {operation, decoded_operands};
}

// read instruction
Instruction read_instruction(const int address) {
    return instruction_memory[address];
}

int main() {
    std::cout << "Hello C++!";

    // code. append to instruction_memory. dont forget to encode
    instruction_memory.push_back(
        encode("add", {
            {OperandType::REGISTER, "a"},
            {OperandType::REGISTER, "b"}
        })
    );

    int pc = 0;
    Instruction ir{};
    bool halted = false;
    bool zero_flag = false;
    std::vector<std::string> stack;

    auto execute = [&](const std::string& operation, std::vector<EncodedOperand>& operands) ->  ExecuteResult {
        if (operation == "add") {
            EncodedOperand dest = operands[0];
            EncodedOperand src = operands[1];
            
            reg[dest.value] = ALU(
                reg[dest.value],
                reg[src.value],
                0x00);

            zero_flag = (reg[dest.value] == 0);
        }

        else if (operation == "sub") {
            EncodedOperand dest = operands[0];
            EncodedOperand src = operands[1];

            reg[dest.value] = ALU(
                reg[dest.value],
                reg[src.value],
                0x01);

            zero_flag = (reg[dest.value] == 0);
        }

        else if (operation == "halt") {
            return {
                ResultType::STRING,
                false,
                "halt"
            };
        }

        else if (operation == "and") {
            EncodedOperand dest = operands[0];
            EncodedOperand src = operands[1];

            reg[dest.value] = ALU(
                reg[dest.value],
                reg[src.value],
                0x03
            );

            zero_flag = (reg[dest.value] == 0);
        }

        else if (operation == "or") {
            EncodedOperand dest = operands[0];
            EncodedOperand src = operands[1];

            reg[dest.value] = ALU(
                reg[dest.value],
                reg[src.value],
                0x04
            );

            zero_flag = (reg[dest.value] == 0);
        }

        else if (operation == "nop") {
            ;
        }

        // todo :shit i forgot zero_flag

        else if (operation == "inc") {
            EncodedOperand dest = operands[0];

            reg[dest.value] = reg[dest.value] + 1;

            zero_flag = (reg[dest.value] == 0);
        }

        else if (operation == "dec") {
            EncodedOperand dest = operands[0];

            reg[dest.value] = reg[dest.value] -1;

            zero_flag = (reg[dest.value] == 0);
        }
        // todo sdv : all implemented in ALU  
        else if (operation == "uml") {
            EncodedOperand dest = operands[0];
            EncodedOperand src = operands[1];

            reg[dest.value] = ALU(
                reg[dest.value],
                reg[src.value],
                0x08
            );

            zero_flag = (reg[dest.value] == 0);
        }

        else if (operation == "udv") {
            EncodedOperand dest = operands[0];
            EncodedOperand src = operands[1];

            reg[dest.value] = ALU(
                reg[dest.value],
                reg[src.value],
                0x09
            );

            zero_flag = (reg[dest.value] == 0);
        }

        else if (operation == "sml") {
            EncodedOperand dest = operands[0];
            EncodedOperand src = operands[1];

            reg[dest.value] = ALU(
                reg[dest.value],
                reg[src.value],
                0x10
            );

            zero_flag = (reg[dest.value] == 0);
        }

        else if (operation == "sdv") {
            EncodedOperand dest = operands[0];
            EncodedOperand src = operands[1];

            reg[dest.value] = ALU(
                reg[dest.value],
                reg[src.value],
                0x11
            );

            zero_flag = (reg[dest.value] == 0);
        } 

        else if (operation == "xor") {
            EncodedOperand dest = operands[0];
            EncodedOperand src = operands[1];

            reg[dest.value] = ALU(
                reg[dest.value],
                reg[src.value],
                0x12
            );

            zero_flag = (reg[dest.value] == 0);
        }

        else if (operation == "not") {
            EncodedOperand dest = operands[0];

            reg[dest.value] = (~reg[dest.value]);

            zero_flag = (reg[dest.value] == 0);
        }

        else if (operation == "clr") {
            EncodedOperand dest = operands[0];

            reg[dest.value] = 0;

            zero_flag = (reg[dest.value] == 0);
        }

        else if (operation == "neg") {
            EncodedOperand dest = operands[0];

            reg[dest.value] = (-(reg[dest.value])) & 0xFF;

            zero_flag = (reg[dest.value] == 0);
        }

        return {
            ResultType::BOOL,
            false,
            ""
        };
    };

    auto fetch = [&](){
        ir = read_instruction(pc);
    };

    auto step = [&](){
        if (halted) {
            return;
        };

        if (pc < 0 || pc >= static_cast<int>(instruction_memory.size())) {
            halted = true;
            return;
        };

        fetch();

        DecodedOperand decoded = decode(ir);

        ExecuteResult result = execute(decoded.operation, ir.operands);
        if (result.type == ResultType::STRING &&  result.string_value == "halt") {
            halted = true;
        }

        else if (result.type == ResultType::TUPLE) {
            std::string kind = result.kind;
            int target = result.target;

            if (target < 0 || target >= static_cast<int>(instruction_memory.size())) {
                throw std::invalid_argument("target is invalid");
            }

            pc = target;
        }
        else {
            pc++;
        }
    };

    auto run = [&](int max_steps = 1000000) {
        for (int i = 0; i < max_steps; i++) {
            step();
        };
        if (halted) {
            return;
        };

        throw std::invalid_argument("maximum step count exceeded");
    };

    reg[0] = 2;
    reg[1] = 1;
    run();

    std::cout << "register data: \n";

    for (int i = 0; i < 8; i++) {
        std::cout << reg_names[i] << ":" << reg[i] << '\n';
    }
}