import sys
from sheet import *
import clothes, more
from colors import CLOTH
from render import shapes_svg
SP = sys.argv[1]
B = body.body_item(); U = body.underwear_item(); E = face.eyes_item('e', {}); M = face.mouths()[0]; Cb = face.blushes()[1]; BR = face.brows()[0]
F = hair.fronts() + more.fronts(); Bk = hair.backs() + more.backs()
newF, newB = more.fronts(), more.backs()
items = more.tops() + more.dresses() + more.hats() + more.held()
D = clothes.dresses()
paths = []
n = max(len(items), 0)
for i in range(n):
    base = ctx(hair=HAIR[(i * 5) % len(HAIR)], skin=SKIN[i % 8])
    it = items[i]
    ic = dict(base); ic['c'] = CLOTH[it['default']]; ic['a'] = it['accent']; ic['pattern'] = None
    hf = newF[i % len(newF)]; hb = newB[i % len(newB)]
    lst = [(hb, item_ctx(hb, base)), (B, item_ctx(B, base)), (U, base), (E, item_ctx(E, base)), (M, base), (Cb, base), (BR, item_ctx(BR, base)), (hf, item_ctx(hf, base))]
    if it['cat'] != 'dress' and it['cat'] != 'top':
        d = D[i % len(D)]; lst.append((d, dict(base, c=CLOTH[d['default']], a=d['accent'])))
    if it['cat'] == 'top':
        lst.append((clothes.bottoms()[0], dict(base, c=CLOTH[16], a='#FFFFFF', pattern=None)))
    lst.append((it, ic))
    p = f'{SP}/m{i}.png'; png(doll_svg(lst, bg='#FFF4F8'), p); paths.append(p)
grid(paths, f'{SP}/more.png', cols=7, scale=0.36)
bp = []
for i, b in enumerate(more.bgs()):
    o, d = shapes_svg(b['layers'][0]['shapes'], {}, i)
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="900" viewBox="0 0 1200 900"><defs>{"".join(d)}</defs>{"".join(o)}</svg>'
    p = f'{SP}/mb{i}.png'; png(svg, p); bp.append(p)
grid(bp, f'{SP}/morebg.png', cols=4, scale=0.25)
