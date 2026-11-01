y={k:0 for k in "abcdefgh"};S={k:i for i,k in enumerate(y)};Z=[];W={"B":0x00,"C":0x01,"D":0x03}
def U(x,y,X):return((x+y)if X=="B"else(x-y))&255
def J(L,*z):return[W[L],[S[x] for x in z]]
Z.append(J("B","a","b"));Z.append(J("C","a","c"));Z.append(J("D"))
def F(L):op,z=L;X={v:k for k,v in W.items()}[op];P=list(S.keys());O=[P[x] for x in z];return X,O
def G(I):return Z[I]
def H(X,z):
    if X in ("B","C"):d,s=z;y[d]=U(y[d],y[s],X)
    return X=="D"
class C:
    def __init__(self):self.pc=0;self.L=None;self.Y=False
    def N(self):self.L=G(self.pc)
    def M(self):
        if self.Y:return
        self.N();X,z=F(self.L);Y=H(X,z)
        if Y:self.Y=True
        else:self.pc+=1
    def run(self):
        while not self.Y:self.M()
K=C();y["a"]=5;y["b"]=3;y["c"]=2;K.run();print(y["a"])