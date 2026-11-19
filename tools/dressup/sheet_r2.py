import sys
from sheet import *
import round2, clothes
from colors import CLOTH
SP = sys.argv[1]
B = body.body_item(); U = body.underwear_item(); M = face.mouths()[1]; Cb = face.blushes()[1]; BR = face.brows()[0]
F = hair.fronts(); Bk = hair.backs()
FA = round2.faces(); NO = round2.noses(); MK = round2.makeup(); ER = round2.earrings()
paths = []
for i in range(max(len(MK), len(ER), len(FA), len(NO))):
    base = ctx(hair=HAIR[(i * 5) % len(HAIR)], skin=SKIN[i % 8])
    E = face.eyes_item('e', {})
    mk, er = MK[i % len(MK)], ER[i % len(ER)]
    lst = [(Bk[1], item_ctx(Bk[1], base)), (B, item_ctx(B, base)), (FA[i % len(FA)], item_ctx(FA[i % len(FA)], base)), (U, base), (E, item_ctx(E, base)), (M, base), (Cb, base), (BR, item_ctx(BR, base)),
           (NO[i % len(NO)], item_ctx(NO[i % len(NO)], base)), (F[1], item_ctx(F[1], base)),
           (mk, dict(base, c=CLOTH[mk['default']])), (er, dict(base, c=CLOTH[er['default']]))]
    p = f'{SP}/r{i}.png'
    png(doll_svg(lst, bg='#FFF4F8'), p)
    from PIL import Image
    Image.open(p).crop((120, 120, 480, 460)).save(p)
    paths.append(p)
grid(paths, f'{SP}/r2.png', cols=4, scale=0.7)
