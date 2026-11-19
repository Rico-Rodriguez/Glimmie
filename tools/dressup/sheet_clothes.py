import sys
from sheet import *
import clothes
from colors import CLOTH
SP = sys.argv[1]; which = sys.argv[2]
B = body.body_item(); U = body.underwear_item(); E = face.eyes_item('e', {}); M = face.mouths()[0]; C = face.blushes()[1]; BR = face.brows()[0]
F, Bk = hair.fronts(), hair.backs()
groups = {'tops': clothes.tops(), 'bottoms': clothes.bottoms(), 'dresses': clothes.dresses(), 'outer': clothes.outers(),
          'socks': clothes.socks(), 'shoes': clothes.shoes()}
items = groups[which]
paths = []
pats = [None, None, 'dots', None, 'stripes', 'hearts', None, 'stars', 'checks', 'flowers', None, 'tinydots']
for i, it in enumerate(items):
    base = ctx(hair=HAIR[(i * 5) % len(HAIR)], skin=SKIN[i % 8])
    ic = dict(base); ic['c'] = CLOTH[it['default']]; ic['a'] = it['accent']; ic['pattern'] = pats[i % len(pats)] if it.get('patternable') else None
    extra = []
    if which in ('bottoms',): extra = [(clothes.tops()[0], dict(base, c='#FFFFFF', a='#FFFFFF', pattern=None))]
    if which in ('tops', 'outer'): extra = [(clothes.bottoms()[0], dict(base, c=CLOTH[16], a='#FFFFFF', pattern=None))]
    lst = [(Bk[i % len(Bk)], item_ctx(Bk[i % len(Bk)], base)), (B, item_ctx(B, base)), (U, base), (E, item_ctx(E, base)), (M, base), (C, base), (BR, item_ctx(BR, base)),
           (F[i % len(F)], item_ctx(F[i % len(F)], base)), (it, ic)] + extra
    if which == 'outer': lst.append((clothes.tops()[0], dict(base, c='#FFFFFF', a='#FFFFFF', pattern=None)))
    p = f'{SP}/{which}{i}.png'
    png(doll_svg(lst, bg='#FFF4F8'), p)
    paths.append(p)
grid(paths, f'{SP}/{which}.png', cols=6, scale=0.42)
