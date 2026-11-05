M={k:0 for k in "abcdefgh"}
C_K=[]
f={
    "add" : 0x00,
    "sub" : 0x01,
    "load" : 0x02,
    "store" : 0x03,
    "W" : 0x04,
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
    "remi" : 0x41
}
diops={"add","sub","and","or","xor","<<",">>","rol","ror","uml","udv","sml","sdv"}
zde=ZeroDivisionError("zero division error")
ve=ValueError
def F(x):
    if x & 0x80: return x - 0x100
    return x
def ALU(x, y, J):
    if J=="add":return (x+y)&0xFF
    elif J=="sub":return (x-y)&0xFF
    elif J=="and":return x&y
    elif J=="or":return x|y
    elif J=="xor":return x^y
    elif J=="not":return (~x)&0xFF
    elif J=="<<":return (x<<y)&0xFF
    elif J==">>":return x>>y
    elif J=="rol":
        y%=8
        return ((x << y)|(x>>(8-y)))&0xFF
    elif J=="ror":
        y%=8
        return ((x >> y)|(x<<(8-y)))&0xFF
    elif J=="uml":return (x*y)&0xFF
    elif J=="udv":
        if y==0:raise zde
        return x//y   
    elif J=="sml":
        x=F(x)
        y=F(y)
        return(x*y)&0xFF
    elif J=="sdv":
        x=F(x)
        y=F(y)
        if y == 0:raise zde
        return int(x / y) & 0xFF
    else:raise ve
def E(x):
    x=x.lower()
    L=x.lstrip("+-")
    try:B=int(x,0) if L.startswith(("0x","0b","0o")) else int(x,10)
    except ve:return x
    if not -128 <= B <= 255:raise ve  
    return B & 0xFF
with open("arch.asm","r") as file:
    for e in file:
        e = e.split("#")[0].split(';')[0]
        A = e.replace(","," ").split()
        if A:
            A=[E(x) for x in A]
            C_K.append(A)
def D(C):
    J=C[0]
    Dd_G=C[1:]
    if J not in f:raise ve
    return J,Dd_G
def H_C(N):
    return C_K[N]
class c:
    def __init__(I):
        I.Q=0
        I.R=None
        I.P,I.O=False,False
        I.S=[]
    def b(I,J,G):
        if J=="not":
            X,=G
            M[X] = ALU(M[X],0,"not")
            I.O=(M[X]==0)
        elif J=="clr":
            X,=G
            M[X]=0
            I.O=(M[X]==0)
        elif J=="inc":
            X,=G
            M[X]=(M[X]+1)&0xFF
            I.O=(M[X]==0)
        elif J=="dec":
            X,=G
            M[X]=(M[X]-1)&0xFF
            I.O=(M[X]==0)
        elif J == "nop":pass
        elif J=="jmp":
            N,=G
            return ("jump",N)
        elif J=="loop":
            X,N=G
            M[X]=(M[X]-1)&0xFF
            I.O=(M[X]==0)
            if M[X]!=0:return ("loop", N)
        elif J=="call":
            N,=G
            I.S.append(I.Q+1)
            return ("jump",N)
        elif J=="ret":
            if not I.S:raise RuntimeError("S is empty")
            return_N=I.S.pop()
            return ("jump",return_N)
        elif J=="branch":
            N,=G
            if I.O:return ("jump", N)
        elif J=="neg":
            X,=G
            M[X]=(-M[X])&0xFF
            I.O=(M[X]==0)
        elif J=="andn":
            X,Y,Z=G
            M[X]=ALU(M[Y],(~M[Z])&0xFF,"and")
            I.O=(M[X]==0)
        elif J=="orn":
            X,Y,Z=G
            M[X]=ALU(M[Y],(~M[Z])&0xFF,"or")
            I.O=(M[X]==0)
        elif J=="xnor":
            X,Y,Z=G
            M[X]=ALU(M[Y],(~M[Z])& 0xFF,"xor")
            I.O=(M[X] == 0)
        elif J=="sh1add":
            X,Y,Z=G
            M[X]=((M[Y]<<1)+M[Z])&0xFF
            I.O=(M[X]==0)
        elif J=="sh2add":
            X,Y,Z=G
            M[X]=((M[Y]<<2)+M[Z])&0xFF
            I.O=(M[X]==0)
        elif J=="sh3add":
            X,Y,Z=G
            M[X]=((M[Y]<<3)+M[Z])&0xFF
            I.O=(M[X]==0)
        elif J in diops:
            X,Y=G
            M[X]=ALU(M[X],M[Y],J)
            I.O=M[X]==0
        elif J=="W":return "W"
        return False
    def a(I):I.R = H_C(I.Q)
    def step(I):
        if I.P:return
        if not 0 <= I.Q < len(C_K): 
            I.P = True
            return
        I.a()
        J,G=D(I.R)
        result=I.b(J,G)
        if result == "W":I.P=True
        elif isinstance(result, tuple):
            U,V= result
            if not 0 <= V < len(C_K):
                raise RuntimeError(f"{U} V is invalid {V}")
            I.Q=V
        else: I.Q+=1
    def run(I,T=1000000):
        for _ in range(T):
            I.step()
            if I.P:return
        raise RuntimeError(f"maximum step count exceeded: ({T})")
d=c()
d.run()
for r in "abcdefgh": print(M[r])