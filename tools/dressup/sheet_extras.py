import sys
from sheet import *
import clothes, extras
from colors import CLOTH
SP = sys.argv[1]
B = body.body_item(); U = body.underwear_item(); E = face.eyes_item('e', {}); M = face.mouths()[0]; C = face.blushes()[1]; BR = face.brows()[0]
F, Bk = hair.fronts(), hair.backs()
items = extras.hats() + extras.glasses() + extras.necks() + extras.backs() + extras.held()
D = clothes.dresses()
paths = []
for i, it in enumerate(items):
    base = ctx(hair=HAIR[(i * 5) % len(HAIR)], skin=SKIN[i % 8])
    ic = dict(base); ic['c'] = CLOTH[it['default']]; ic['a'] = it['accent']; ic['pattern'] = None
    d = D[i % len(D)]
    lst = [(Bk[i % len(Bk)], item_ctx(Bk[i % len(Bk)], base)), (B, item_ctx(B, base)), (U, base), (E, item_ctx(E, base)), (M, base), (C, base), (BR, item_ctx(BR, base)),
           (F[i % len(F)], item_ctx(F[i % len(F)], base)), (d, dict(base, c=CLOTH[d['default']], a=d['accent'])), (it, ic)]
    p = f'{SP}/x{i}.png'
    png(doll_svg(lst, bg='#FFF4F8'), p)
    paths.append(p)
grid(paths, f'{SP}/extras.png', cols=8, scale=0.33)
