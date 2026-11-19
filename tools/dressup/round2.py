"""Round 2: face shapes, noses, makeup, earrings."""
from geom import *
from body import LW, EYE_L
from clothes import item

FACES = {
    'face_round': [(300, 150), (222, 160), (176, 200), (158, 262), (160, 330), (178, 378), (222, 410), (300, 424)],
    'face_chubby': [(300, 150), (220, 160), (172, 200), (154, 262), (154, 332), (172, 384), (220, 414), (300, 424)],
    'face_heart': [(300, 150), (222, 160), (174, 200), (156, 262), (160, 326), (184, 372), (238, 410), (300, 430)],
    'face_oval': [(300, 150), (224, 160), (180, 200), (164, 262), (166, 334), (186, 384), (228, 414), (300, 428)],
    'face_soft': [(300, 150), (222, 160), (176, 200), (158, 262), (162, 334), (186, 388), (236, 416), (300, 422)],
}

def faces():
    out = []
    for id_, pts in FACES.items():
        S = [{'d': both(ellipse(163 + (pts[3][0] - 158), 318, 15, 22, -8)), 'f': 'skin', 's': 'skin.o', 'w': LW},
             {'d': sym(pts), 'f': 'skin', 's': 'skin.o', 'w': LW}]
        out.append({'id': id_, 'cat': 'face', 'color': 'skin', 'layers': [{'z': 20, 'shapes': S}]})
    return out

def noses():
    out = []
    x, y = 300, 362
    def n(id_, S):
        return {'id': id_, 'cat': 'nose', 'color': 'skin', 'layers': [{'z': 41, 'shapes': S}]}
    out.append(n('n_none', []))
    out.append(n('n_dot', [{'d': ellipse(x, y, 3.2, 2.6), 'f': 'skin.o', 'o': 0.6}]))
    out.append(n('n_hook', [{'d': smooth_open([(x + 2, y - 8), (x + 5, y), (x - 1, y + 3)]), 's': 'skin.o', 'w': 3, 'o': 0.7}]))
    out.append(n('n_button', [{'d': ellipse(x, y, 8, 6), 'f': 'skin.s'}, {'d': ellipse(x - 2, y - 2, 3, 2), 'f': '#FFFFFF', 'o': 0.7}]))
    out.append(n('n_cat', [{'d': smooth_closed([(x - 6, y - 3), (x + 6, y - 3), (x, y + 4)], 0.5), 'f': '#F48AA0', 's': '#C2506A', 'w': 2}]))
    out.append(n('n_blush', [{'d': ellipse(x, y, 10, 6), 'f': '#FF8FAA', 'o': 0.45}, {'d': ellipse(x, y - 1, 3, 2.2), 'f': 'skin.o', 'o': 0.5}]))
    return out

def makeup():
    out = []
    ex, ey = EYE_L
    def m(id_, S, default=19, z=39):
        return item(id_, 'makeup', [{'z': z, 'shapes': S}], default=default, patternable=False)
    lid = lambda cx, s: smooth_closed([(cx - s * 44, ey - 26), (cx - s * 20, ey - 50), (cx + s * 12, ey - 54), (cx + s * 40, ey - 36), (cx + s * 30, ey - 30), (cx, ey - 40), (cx - s * 30, ey - 26)])
    out.append(m('mk_shadow', [{'d': lid(ex, 1) + ' ' + lid(600 - ex, -1), 'f': 'c', 'o': 0.55}], z=39))
    wing = lambda cx, s: smooth_closed([(cx - s * 36, ey - 30), (cx - s * 58, ey - 46), (cx - s * 40, ey - 22)], 0.6)
    out.append(m('mk_liner', [{'d': wing(ex, 1) + ' ' + wing(600 - ex, -1), 'f': 'c'}], default=23, z=42))
    gl = []
    for cx, s in ((ex, 1), (600 - ex, -1)):
        gl += [star(cx - s * 46, ey + 10, 5, 0.4, 4), star(cx - s * 52, ey - 6, 3.5, 0.4, 4), circle(cx - s * 40, ey + 26, 2.5), circle(cx - s * 30, ey + 40, 2)]
    out.append(m('mk_glitter', [{'d': ' '.join(gl), 'f': 'c'}], default=10, z=42))
    gems = ' '.join(star(cx, ey + 58, 7, 0.45, round_=0.3) + ' ' + circle(cx + d, ey + 52, 3.5) + ' ' + circle(cx - d, ey + 52, 3.5)
                    for cx, d in ((ex - 20, 12), (600 - ex + 20, 12)))
    out.append(m('mk_gems', [{'d': gems, 'f': 'c', 's': 'c.o', 'w': 1.5}], default=15, z=42))
    out.append(m('mk_heart', [{'d': heart(206, 360, 9), 'f': 'c', 's': 'c.o', 'w': 1.5}], default=4, z=42))
    out.append(m('mk_moon', [{'d': smooth_closed([(398, 344), (414, 356), (410, 376), (396, 382), (404, 370), (406, 356)], 0.8), 'f': 'c', 's': 'c.o', 'w': 1.5},
                             {'d': star(388, 360, 5, 0.4, 4), 'f': 'c'}], default=10, z=42))
    rb = []
    for i, c in enumerate(('#FF8A9E', '#FFE27A', '#9CCBFF')):
        rb.append({'d': smooth_open([(184, 372 + i * 7), (204, 366 + i * 7), (224, 372 + i * 7)]) + ' ' + smooth_open([(376, 372 + i * 7), (396, 366 + i * 7), (416, 372 + i * 7)]), 's': c, 'w': 5, 'o': 0.85})
    out.append(m('mk_rainbow', rb, default=0, z=42))
    return out

def earrings():
    out = []
    xs = (160, 440)
    def e(id_, per, default=10):
        S = []
        for x in xs: S += per(x)
        return item(id_, 'earrings', [{'z': 52, 'shapes': S}], default=default, patternable=False)
    out.append(e('er_pearl', lambda x: [{'d': circle(x, 344, 7), 'f': '#FFFFFF', 's': '#C7B9C6', 'w': 2}, {'d': circle(x - 2, 342, 2), 'f': '#FFFFFF'}], default=0))
    out.append(e('er_hoop', lambda x: [{'d': circle(x, 360, 15), 's': 'c', 'w': 4.5}]))
    out.append(e('er_star', lambda x: [{'d': smooth_open([(x, 340), (x, 354)]), 's': 'c.o', 'w': 2}, {'d': star(x, 364, 12, 0.5), 'f': 'c', 's': 'c.o', 'w': 2}], default=9))
    out.append(e('er_heart', lambda x: [{'d': smooth_open([(x, 340), (x, 352)]), 's': 'c.o', 'w': 2}, {'d': heart(x, 362, 10), 'f': 'c', 's': 'c.o', 'w': 2}], default=4))
    out.append(e('er_cherry', lambda x: [{'d': smooth_open([(x, 340), (x - 6, 360)]) + ' ' + smooth_open([(x, 340), (x + 7, 362)]), 's': '#4E9A63', 'w': 2.5},
                                         {'d': circle(x - 7, 366, 7) + ' ' + circle(x + 8, 368, 7), 'f': 'c', 's': 'c.o', 'w': 2}], default=5))
    out.append(e('er_drop', lambda x: [{'d': circle(x, 344, 4), 'f': '#F2C14E'}, {'d': smooth_closed([(x, 350), (x + 9, 368), (x, 378), (x - 9, 368)]), 'f': 'c', 's': 'c.o', 'w': 2},
                                       {'d': ellipse(x - 3, 366, 2, 4), 'f': '#FFFFFF', 'o': 0.7}], default=15))
    out.append(e('er_flower', lambda x: [{'d': flower(x, 346, 14), 'f': 'c', 's': 'c.o', 'w': 1.5}, {'d': circle(x, 346, 3), 'f': '#FFE27A'}], default=3))
    return out
