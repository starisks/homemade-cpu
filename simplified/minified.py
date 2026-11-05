r='sh3add'
q='sh2add'
p='sh1add'
o='xnor'
n='orn'
m='andn'
l='neg'
k='branch'
j='ret'
i='call'
h='jmp'
g='nop'
f='dec'
e='inc'
d='clr'
c='abcdefgh'
b=print
a=ZeroDivisionError
Z=False
Y='sdv'
X='sml'
W='udv'
V='uml'
U='ror'
T='rol'
S='loop'
R='>>'
Q='<<'
O='sub'
H='add'
P=RuntimeError
G=int
N='not'
M='xor'
L='or'
K='and'
J='halt'
E=ValueError
A={A:0 for A in c}
A1={B:A for(A,B)in enumerate(A)}
B=[]
s={H:0,O:1,'load':2,'store':3,J:4,K:5,L:6,M:7,N:8,Q:9,R:16,'mov':17,d:18,e:19,f:20,g:21,'loadi':22,'addi':23,'subi':24,h:25,S:32,T:33,U:34,i:35,j:36,k:37,V:38,W:39,X:40,Y:41,l:48,'andi':49,m:50,'ori':51,'xori':52,n:53,o:54,p:55,q:56,r:57,'rem':64,'remi':65}
t={H,O,K,L,M,Q,R,T,U,V,W,X,Y}
def C(x):
	if x&128:return x-256
	return x
def I(x,y,operation):
	A=operation
	if A==H:return x+y&255
	elif A==O:return x-y&255
	elif A==K:return x&y
	elif A==L:return x|y
	elif A==M:return x^y
	elif A==N:return~x&255
	elif A==Q:return x<<y&255
	elif A==R:return x>>y
	elif A==T:y%=8;return(x<<y|x>>8-y)&255
	elif A==U:y%=8;return(x>>y|x<<8-y)&255
	elif A==V:return x*y&255
	elif A==W:
		if y==0:raise a('division by zero')
		return x//y
	elif A==X:x=C(x);y=C(y);return x*y&255
	elif A==Y:
		x=C(x);y=C(y)
		if y==0:raise a('error : division by zero')
		return G(x/y)&255
	else:raise E(f"Invalid Operation : {A}")
def u(x):
	x=x.lower();B=x.lstrip('+-')
	try:A=G(x,0)if B.startswith(('0x','0b','0o'))else G(x,10)
	except E:return x
	if not-128<=A<=255:raise E(f"imm out of range {A}")
	return A&255
with open('arch.asm','r')as v:
	for F in v:
		F=F.split('#')[0].split(';')[0];D=F.replace(',',' ').split()
		if D:D=[u(A)for A in D];B.append(D)
def w(instruction):
	B=instruction;A=B[0];C=B[1:]
	if A not in s:raise E(f"invalid operation: {A}")
	return A,C
def x(address):return B[address]
class y:
	def __init__(A):A.pc=0;A.ir=None;A.halted,A.zero_flag=Z,Z;A.stack=[]
	def execute(D,operation,operands):
		O='jump';E=operands;C=operation
		if C==N:B,=E;A[B]=I(A[B],0,N);D.zero_flag=A[B]==0
		elif C==d:B,=E;A[B]=0;D.zero_flag=A[B]==0
		elif C==e:B,=E;A[B]=A[B]+1&255;D.zero_flag=A[B]==0
		elif C==f:B,=E;A[B]=A[B]-1&255;D.zero_flag=A[B]==0
		elif C==g:0
		elif C==h:H,=E;return O,H
		elif C==S:
			B,H=E;A[B]=A[B]-1&255;D.zero_flag=A[B]==0
			if A[B]!=0:return S,H
		elif C==i:H,=E;D.stack.append(D.pc+1);return O,H
		elif C==j:
			if not D.stack:raise P('stack is empty')
			Q=D.stack.pop();return O,Q
		elif C==k:
			H,=E
			if D.zero_flag:return O,H
		elif C==l:B,=E;A[B]=-A[B]&255;D.zero_flag=A[B]==0
		elif C==m:B,F,G=E;A[B]=I(A[F],~A[G]&255,K);D.zero_flag=A[B]==0
		elif C==n:B,F,G=E;A[B]=I(A[F],~A[G]&255,L);D.zero_flag=A[B]==0
		elif C==o:B,F,G=E;A[B]=I(A[F],~A[G]&255,M);D.zero_flag=A[B]==0
		elif C==p:B,F,G=E;A[B]=(A[F]<<1)+A[G]&255;D.zero_flag=A[B]==0
		elif C==q:B,F,G=E;A[B]=(A[F]<<2)+A[G]&255;D.zero_flag=A[B]==0
		elif C==r:B,F,G=E;A[B]=(A[F]<<3)+A[G]&255;D.zero_flag=A[B]==0
		elif C in t:B,F=E;A[B]=I(A[B],A[F],C);D.zero_flag=A[B]==0
		elif C==J:return J
		return Z
	def fetch(A):A.ir=x(A.pc)
	def step(A):
		if A.halted:return
		if not 0<=A.pc<len(B):A.halted=True;return
		A.fetch();E,F=w(A.ir);C=A.execute(E,F)
		if C==J:A.halted=True
		elif isinstance(C,tuple):
			G,D=C
			if not 0<=D<len(B):raise P(f"{G} target is invalid {D}")
			A.pc=D
		else:A.pc+=1
	def run(A,max_steps=1000000):
		B=max_steps
		for C in range(B):
			A.step()
			if A.halted:return
		raise P(f"maximum step count exceeded: ({B})")
z=y()
z.run()
b('register data:')
for A0 in c:b(A[A0])