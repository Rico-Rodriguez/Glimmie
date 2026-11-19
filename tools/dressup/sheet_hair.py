import sys, os
from sheet import *
SP = sys.argv[1]
F, Bk = hair.fronts(), hair.backs()
B = body.body_item(); U = body.underwear_item(); E = face.eyes_item('e', {}); M = face.mouths()[0]; C = face.blushes()[1]; BR = face.brows()[0]
paths = []
n = max(len(F), len(Bk))
for i in range(n):
    base = ctx(hair=HAIR[(i * 5) % len(HAIR)], skin=SKIN[i % 8], a='#FF7FB0')
    p = f'{SP}/h{i}.png'
    doll([Bk[i % len(Bk)], B, U, E, M, C, BR, F[i % len(F)]], base, p)
    paths.append(p)
grid(paths, f'{SP}/hair.png', cols=6, scale=0.42)
