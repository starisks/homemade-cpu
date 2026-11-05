$reg = {
    a:0,
    b:0,
    c:0,
    d:0,
    e:0,
    f:0,
    g:0,
    h:0
} 
$reg_codes = {
    a: 0,
    b: 1,
    c: 2,
    d: 3,
    e: 4,
    f: 5,
    g: 6,
    h: 7
}
$instruction_memory = []
$isa = {
    add: 0x00,
    sub: 0x01,
    load: 0x02,
    store: 0x03,
    halt: 0x04,
    :"and"=> 0x05,
    :"or"=> 0x06,
    xor: 0x07,
    :"not"=> 0x08,
    :"<<"=> 0x09,
    :">>"=> 0x10,
    mov: 0x11,
    clr: 0x12,
    inc: 0x13,
    dec: 0x14,
    nop: 0x15,
    loadi: 0x16,
    addi: 0x17,
    subi: 0x18,
    jmp: 0x19,
    loop: 0x20,
    rol: 0x21,
    ror: 0x22,
    call: 0x23,
    ret: 0x24,
    branch: 0x25,
    uml: 0x26,
    udv: 0x27,
    sml: 0x28,
    sdv: 0x29,
    neg: 0x30,
    andi: 0x31,
    andn: 0x32,
    ori: 0x33,
    xori: 0x34,
    orn: 0x35,
    xnor: 0x36,
    sh1add: 0x37,
    sh2add: 0x38,
    sh3add: 0x39,
    rem: 0x40,
    remi: 0x41
}
$diops = [
  "add",
  "sub",
  "and",
  "or",
  "xor",
  "<<",
  ">>",
  "rol",
  "ror",
  "uml",
  "udv",
  "sml",
  "sdv"
]
def signed8(x)
  if (x & 0x80) != 0
    return x - 0x100
  end
  return x
end
def alu(x, y, operation)
  if (operation == "add")
    return (x + y) & 0xFF
  elsif (operation == "sub")
    return (x - y) & 0xFF
  elsif (operation == "and")
    return (x & y)
  elsif (operation == "xor")
    return (x ^ y)
  elsif (operation == "or")
    return (x | y)
  elsif (operation == "not")
    return (~x) & 0xFF
  elsif (operation == "<<")
    return (x << y) & 0xFF
  elsif (operation == ">>")
    return (x >> y)
  elsif (operation == "rol")
    y %= 8
    return ((x << y) | (x >> (8 - y))) & 0xFF
  elsif (operation == "ror")
    y %= 8
    return ((x >> y) | (x << (8 - y))) & 0xFF
  elsif (operation == "uml")
    return (x * y) & 0xFF
  elsif (operation == "udv")
    if y == 0
      raise ZeroDivisionError, "Zero division error" 
    end
    return (x / y) & 0xFF
  elsif (operation == "sml")
    x = signed8(x)
    y = signed8(y)
    return (x * y) & 0xFF
  elsif (operation == "sdv")
    x = signed8(x)
    y = signed8(y)
    if (y == 0)
     raise ZeroDivisionError, "Zero division error"
    end
    return (x / y)
  else
    return "invalid instruction"
  end
end
def encode(instruction, *operands)
  puts "DEBUG instruction: #{instruction.inspect}"
  puts "DEBUG class: #{instruction.class}"
  puts "DEBUG ISA keys: #{$isa.keys.inspect}"
  if !$isa.include?(instruction)
    raise ArgumentError, "instruction not in $isa"
  end
  opcode = $isa[instruction]
  encoded_operands = []
  for operand in operands
    if (operand.is_a?(Symbol)) && ($reg_codes.key?(operand))
      encoded_operands << ["reg", $reg_codes[operand]]
    elsif (operand.is_a?(Integer))
      if !(0 <= operand && operand <= 0xFF)
        raise ArgumentError, "invalid address"
      end
      encoded_operands << ["imm", operand]
    else
      puts "DEBUG operand: #{operand.inspect}"
      puts "DEBUG class: #{operand.class}"
      raise ArgumentError, "invalid operand"
    end
  end
  return [opcode, encoded_operands]
end
def parse_operand(x)
  x = x.downcase
  body = x.sub(/\A[+-]+/, '')
  begin
    if body.start_with?("0x", "0b", "0o")
      value = Integer(x, 0)
    else
      value = Integer(x, 10)
    end
  rescue ArgumentError
    return x.to_sym if $reg_codes.key?(x.to_sym)
    return x
  end
  if !(-128 <= value && value <= 255)
    raise ArgumentError, "imm out of range"
  end
  return value & 0xFF
end
File.foreach("../program.asm") do |line|
  line = line.split("#")[0].split(";")[0]
  parts = line.tr(",", ' ').split
  unless parts.empty?
    parts = parts.map {|x| parse_operand(x)}
    parts[0] = parts[0].to_sym
    $instruction_memory << encode(*parts)
  end
end
def decode(instruction)
  opcode, operands = instruction
  operation = $isa.key(opcode)
  if operation == nil
    raise ArgumentError, "invalid opcode"
  end
  decoded_operands = []
  operands.each do |operand_type, value|
    if (operand_type == "reg")
      decoded_operands << $reg_codes.key(value)
    elsif (operand_type == "imm")
      decoded_operands << value
    else
      raise ArgumentError, "invalid operand type"
    end
  end
  return operation.to_s, decoded_operands
end
def read_instruction(address)
  return $instruction_memory[address]
end
class CPU
  def initialize
    @pc = 0
    @ir = nil
    @halted = false
    @zero_flag = false
    @stack = []
  end
  def execute(operation, *operands)
    if (operation == 'not')
      dest = operands[0]
      $reg[dest] = alu(
        $reg[dest],
        0,
        'not'
      )
      @zero_flag = ($reg[dest] == 0)
    elsif (operation == 'loadi')
      dest, value = operands
      $reg[dest] = value & 0xFF
      @zero_flag = ($reg[dest] == 0)
    elsif (operation == 'clr')
      dest = operands[0]
      $reg[dest] = 0
      @zero_flag = ($reg[dest] == 0)
    elsif (operation == 'inc')
      dest = operands[0]
      $reg[dest] = ($reg[dest] + 1) & 0xff
      @zero_flag = ($reg[dest] == 0)
    elsif (operation == 'dec')
      dest = operands[0]
      $reg[dest] = ($reg[dest] - 1) & 0xff
    elsif (operation == 'nop')
    elsif (operation == 'jmp')
      address = operands[0]
      return ["jump", address]
    elsif (operation == 'loop')
      dest, address = operands
      $reg[dest] = ($reg[dest] - 1) & 0xff
      @zero_flag = ($reg[dest] == 0)
      if $reg[dest] != 0
        return ["loop", address]
      end
    elsif (operation === 'call')
      address = operands[0]
      @stack << (@pc + 1)
      return ["jump", address]
    elsif (operation == 'ret')
      if @stack.empty?
        raise RuntimeError, "stack is empty"
      end
      return_address = @stack.pop
      return ["jump", return_address]
    elsif (operation == 'branch')
      address = operands[0]
      if @zero_flag
        return ['jump', address]
      end
    elsif (operation == 'neg')
      dest = operands[0]
      $reg[dest] = (-$reg[dest]) & 0xFF
      @zero_flag = ($reg[dest] == 0)
    elsif (operation == 'andn')
      dest, src, src2 = operands
      $reg[dest] = alu(
        $reg[src],
        (~$reg[src2]) & 0xFF,
        "and"
      )
      @zero_flag = ($reg[dest] == 0)
    elsif (operation == 'orn')
      dest, src, src2 = operands
      $reg[dest] = alu(
        $reg[src],
        (~$reg[src2]) & 0xff,
        "or"
      )
      @zero_flag = ($reg[dest] == 0)
    elsif (operation == 'xnor')
      dest, src, src2 = operands
      $reg[dest] = alu(
        $reg[src],
        (~$reg[src2]) & 0xff,
        'xor'
      )
      @zero_flag = ($reg[dest] == 0)
    elsif (operation == 'sh1add')
      dest, src, src2 = operands
      $reg[dest] = (
        ($reg[src] << 1) + $reg[src2]
      ) & 0xFF
      @zero_flag = ($reg[dest] == 0)
    elsif (operation == 'sh2add')
      dest, src, src2 = operands
      $reg[dest] = (
        ($reg[src] << 2) + $reg[src2]
      ) & 0xFF
      @zero_flag = ($reg[dest] == 0)
    elsif (operation == 'sh3add')
      dest, src, src2 = operands
      $reg[dest] = (
        ($reg[src] << 3) + $reg[src2]
      ) & 0xFF
      @zero_flag = ($reg[dest] == 0)
    elsif $diops.include?(operation)
      dest, src = operands
      $reg[dest] = alu(
        $reg[dest],
        $reg[src],
        operation
      )
      @zero_flag = ($reg[dest] == 0)
    elsif (operation == "halt")
      return "halt"
    end
    return false
  end
  def fetch
    @ir = read_instruction(@pc)
  end
  def step
    if @halted
      return
    end
    if !(0 <= @pc && @pc < $instruction_memory.size)
      @halted = true
      return
    end
    fetch()
    operation, operands = decode(@ir)
    result = execute(operation, *operands)
    if (result == 'halt')
      @halted = true
    elsif (result.is_a?(Array))
      target = result

      if !(0 <= target && target < $instruction_memory.size)
        raise RuntimeError, "target is invalid"
      end
      @pc = target
    else
      @pc += 1
    end
  end
  def run(max_steps = 1000000)
    max_steps.times do
      step()
      if @halted
        return
      end
    end
    raise RuntimeError, "maximum step count exceeded"
  end
end
cpu = CPU.new
cpu.run()
puts "register data:"
$reg.each do |name, value|
  puts "#{name}: #{value}"
end