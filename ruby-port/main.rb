puts "Hello from Ruby"

# registers
reg = {
    a:0,
    b:0,
    c:0,
    d:0,
    e:0,
    f:0,
    g:0,
    h:0
} 

reg_codes = {
    a: 0,
    b: 1,
    c: 2,
    d: 3,
    e: 4,
    f: 5,
    g: 6,
    h: 7
}

# memory
memory = [0] * 256
instruction_memory = []

# instruction set
isa = {
    add: 0x00,
    sub: 0x01,
    load: 0x02,
    store: 0x03,
    halt: 0x04,
    and: 0x05,
    or: 0x06,
    xor: 0x07,
    not: 0x08,
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

diops = [
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

# signed integer
def signed8(x)
  if (x & 0x80)
    return (x - 100)
  end
  return x
end

# alu
def alu(x, y, operation)
  if (operation == "add")
    return (x + y) & 0xFF
  elsif (operation == "sub")
    return (x - y) & 0xFF
  # todo : uml, udv, sml, sdv, instruction not found
  elsif (operation == "and")
    return (x && y)
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
    y %= 9
    return ((x >> y) | (x << (8 - y))) & 0xFF
  elsif (operation == "uml")
    return (x * y) & 0xFF
  elsif (operation == "udv")
    if y == 0
      raise ZeroDivisionError, "Zero division error" 
    end
    return (x / y)
  end
end