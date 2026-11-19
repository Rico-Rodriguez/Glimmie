"""Tops, bottoms, dresses, outerwear, socks and shoes."""
from geom import *
from body import ARM_L, ARM_W, LEG_L, LEG_W, FEET_Y, tube, mtube, LW

ARM_R = [(600 - x, y) for x, y in ARM_L]
LEG_R = [(600 - x, y) for x, y in LEG_L]

def item(id_, cat, layers, color='own', default=3, accent='#FFFFFF', patternable=True):
    return {'id': id_, 'cat': cat, 'color': color, 'default': default, 'accent': accent,
            'patternable': patternable, 'layers': layers}

NECKS = {
    'crew': [(300, 448), (284, 446), (272, 438)],
    'v': [(300, 476), (284, 456), (272, 438)],
    'square': [(300, 458), (278, 458), (272, 440)],
    'scoop': [(300, 462), (280, 456), (270, 440)],
    'high': [(300, 430), (284, 428), (272, 434)],
}

def torso_shape(neck='crew', hem=528, flare=0, shoulder=True):
    n = NECKS[neck]
    pts = list(n)
    if shoulder:
        pts += [(258, 440), (243, 452)]
    else:
        pts += [(252, 452), (244, 462)]
    pts += [(240, 476), (241, 500), (238 - flare * 0.5, hem - 16), (236 - flare, hem - 2), (262 - flare * 0.4, hem + 3), (300, hem + 4)]
    return sym(pts)

def sleeves(t1=0.4, kind='tube', w=ARM_W + 14):
    S = []
    if kind == 'puff':
        for cx in (250, 350):
            S.append({'d': ellipse(cx, 456, 26, 22, -25 if cx < 300 else 25), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1})
            S.append({'d': smooth_open([(cx - 14, 470), (cx, 476), (cx + 14, 470)]), 's': 'c.s', 'w': 4})
        return S
    for ctrl in (ARM_L, ARM_R):
        S += tube(ctrl, w, 'c', 0.0, t1, outline='c.o')
    return S

def cuffs(t1, role='a', w=ARM_W + 16):
    S = []
    for ctrl in (ARM_L, ARM_R):
        S += tube(ctrl, w, role, max(0, t1 - 0.06), t1, outline=role + '.o' if role != '#FFFFFF' else '#C9B3C2')
    return S

def chest_shade():
    return [{'d': ellipse(300, 446, 46, 12), 'f': 'c.s', 'o': 0.7}]

def top(id_, neck='crew', hem=528, sleeve=0.4, sleeve_kind='tube', flare=0, extra=None, under=None, cuff=None, default=3, accent='#FFFFFF', z=28):
    S = []
    if under:
        S += under
    if sleeve:
        S += sleeves(sleeve, sleeve_kind)
        if cuff:
            S += cuffs(sleeve, cuff)
    S.append({'d': torso_shape(neck, hem, flare), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1})
    S += chest_shade()
    if extra:
        S += extra
    return item(id_, 'top', [{'z': z, 'shapes': S}], default=default, accent=accent)

def bow(cx, cy, s=1.0, role='a'):
    o = role + '.o' if not role.startswith('#') else '#B05A7A'
    L = smooth_closed([(cx, cy), (cx - 22 * s, cy - 15 * s), (cx - 30 * s, cy), (cx - 22 * s, cy + 15 * s)], 0.9)
    R = smooth_closed([(cx, cy), (cx + 22 * s, cy - 15 * s), (cx + 30 * s, cy), (cx + 22 * s, cy + 15 * s)], 0.9)
    tails = (smooth_closed([(cx - 3 * s, cy + 2 * s), (cx - 14 * s, cy + 26 * s), (cx - 6 * s, cy + 28 * s), (cx + 1 * s, cy + 6 * s)], 0.5) + ' ' +
             smooth_closed([(cx + 3 * s, cy + 2 * s), (cx + 14 * s, cy + 26 * s), (cx + 6 * s, cy + 28 * s), (cx - 1 * s, cy + 6 * s)], 0.5))
    return [{'d': tails, 'f': role, 's': o, 'w': 3.5},
            {'d': L + ' ' + R, 'f': role, 's': o, 'w': 3.5},
            {'d': ellipse(cx, cy, 8 * s, 9 * s), 'f': role + '.s' if not role.startswith('#') else role, 's': o, 'w': 3.5}]

def buttons(x, ys, r=4.5, role='a'):
    return [{'d': ' '.join(circle(x, y, r) for y in ys), 'f': role, 's': (role + '.o') if not role.startswith('#') else '#B79AAE', 'w': 2.5}]

def tops():
    out = []
    out.append(top('t_tee', 'crew', 528, 0.36))
    out.append(top('t_tank', 'scoop', 528, 0, extra=[
        {'d': both(smooth_open([(270, 442), (262, 436)])), 's': 'c.o', 'w': 12}, {'d': both(smooth_open([(270, 442), (262, 436)])), 's': 'c', 'w': 6}], default=11))
    out.append(top('t_long', 'crew', 530, 0.9, cuff='a', default=16))
    out.append(top('t_puff', 'square', 526, 1, 'puff', extra=bow(300, 460, 0.7), default=2, accent='#F45C9A'))
    sailor = [{'d': smooth_closed([(268, 438), (300, 486), (332, 438), (350, 446), (344, 470), (300, 500), (256, 470), (250, 446)]), 'f': 'a', 's': 'a.o', 'w': 3.5},
              {'d': smooth_open([(262, 452), (300, 488), (338, 452)]), 's': '#FFFFFF', 'w': 3}]
    out.append(top('t_sailor', 'v', 530, 0.38, extra=sailor + bow(300, 486, 0.75, '#E8475A'), cuff='a', default=0, accent='#3C4A8C'))
    hood = [{'d': smooth_closed([(232, 430), (300, 402), (368, 430), (360, 450), (300, 436), (240, 450)]), 'f': 'c.s', 's': 'c.o', 'w': LW}]
    hoodie_x = [{'d': rrect(262, 488, 76, 34, 12), 'f': 'c.s', 's': 'c.o', 'w': 3.5},
                {'d': both(smooth_open([(288, 446), (286, 478)])), 's': 'a', 'w': 4}, {'d': both(circle(286, 480, 4)), 'f': 'a'}]
    out.append(top('t_hoodie', 'crew', 536, 0.92, extra=hood + hoodie_x, cuff='c', default=18, accent='#FFFFFF'))
    sweater = [{'d': heart(300, 486, 20), 'f': 'a', 's': 'a.o', 'w': 3}] + \
              [{'d': smooth_open([(244 + i * 14, 522), (244 + i * 14, 532)]), 's': 'c.s', 'w': 3} for i in range(9)]
    out.append(top('t_sweater', 'crew', 534, 0.9, extra=sweater, cuff='c', default=7, accent='#F45C9A'))
    collar = [{'d': smooth_closed([(300, 446), (276, 438), (262, 446), (272, 464), (296, 462)]), 'f': '#FFFFFF', 's': '#C9B3C2', 'w': 3.5},
              {'d': smooth_closed([(300, 446), (324, 438), (338, 446), (328, 464), (304, 462)]), 'f': '#FFFFFF', 's': '#C9B3C2', 'w': 3.5}]
    out.append(top('t_blouse', 'crew', 528, 0.4, extra=collar + buttons(300, [478, 500]), default=15, accent='#FFFFFF'))
    out.append(top('t_crop', 'scoop', 498, 0.3, default=4))
    ruffle = [{'d': smooth_closed([(238, 456), (270, 448), (300, 450), (330, 448), (362, 456), (366, 470), (348, 476), (330, 470), (316, 478), (300, 472), (284, 478), (270, 470), (252, 476), (234, 470)]), 'f': 'c.l', 's': 'c.o', 'w': 3.5}]
    out.append(top('t_ruffle', 'scoop', 526, 0, extra=ruffle, default=9))
    out.append(top('t_star', 'crew', 528, 0.36, extra=[{'d': star(300, 484, 26, 0.5), 'f': 'a', 's': 'a.o', 'w': 3}], default=17, accent='#FFE27A'))
    vest = [{'d': smooth_closed([(272, 440), (296, 490), (290, 526), (246, 526), (242, 476), (252, 448)]), 'f': 'a', 's': 'a.o', 'w': 3.5},
            {'d': smooth_closed([(328, 440), (304, 490), (310, 526), (354, 526), (358, 476), (348, 448)]), 'f': 'a', 's': 'a.o', 'w': 3.5}]
    out.append(top('t_vest', 'v', 528, 0.9, extra=vest, cuff='c', default=0, accent='#9B79E0'))
    return out

# ---------- bottoms ----------

def skirt_shape(top=510, hem=610, width=72, scallop=0, n=6, belly=0):
    pts = [(300, top - 2), (252, top - 2), (244, top + 10)]
    pts += [(244 - width * 0.35 - belly, (top + hem) / 2), (300 - width - 12, hem - 6)]
    if scallop:
        xs = [300 - width - 12 + (2 * (width + 12)) * i / (2 * n) for i in range(2 * n + 1)]
        left = xs[:n + 1]
        for i, x in enumerate(left[1:], 1):
            pts.append((x - (xs[1] - xs[0]) / 2, hem + scallop))
            pts.append((x, hem - (2 if i < n else -scallop)))
        pts = pts[:-1]
        return sym(pts + [(300, hem + scallop * (1 if n % 2 else 0) - 2)])
    pts += [(270, hem + 4), (300, hem + 5)]
    return sym(pts)

def waistband(top=510, role='c.s'):
    return [{'d': rrect(246, top - 6, 108, 16, 7), 'f': role, 's': 'c.o', 'w': 3.5}]

def bottom(id_, shapes, default=3, accent='#FFFFFF', z=26, cat='bottom', patternable=True):
    return item(id_, cat, [{'z': z, 'shapes': shapes}], default=default, accent=accent, patternable=patternable)

def pleats(top, hem, width, n=6):
    out = []
    for i in range(1, n):
        k = -1 + 2 * i / n
        out.append({'d': smooth_open([(300 + k * 50, top + 14), (300 + k * (width + 6), hem - 2)]), 's': 'c.o', 'w': 3, 'o': 0.4})
    return out

def legs(w=LEG_W + 10, t0=0.15, t1=0.96, role='c'):
    return mtube(LEG_L, w, role, t0, t1, outline=role + '.o' if not role.startswith('#') else '#9A8AA0')

def shorts_shape(top=510, bottom=590):
    return sym([(300, top - 2), (252, top - 2), (243, top + 14), (238, bottom - 20), (240, bottom), (276, bottom + 6), (298, bottom - 6), (300, bottom - 14)])

def bottoms():
    out = []
    out.append(bottom('b_skirt', [{'d': skirt_shape(510, 606, 72), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + waistband() + pleats(510, 606, 72, 4)[1:3], default=4))
    tutu = [{'d': skirt_shape(512, 596, 92, scallop=10, n=7), 'f': 'c.l', 's': 'c.o', 'w': LW},
            {'d': skirt_shape(510, 578, 78, scallop=9, n=6), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + waistband(510, 'c')
    out.append(bottom('b_tutu', tutu, default=3))
    out.append(bottom('b_pleated', [{'d': skirt_shape(510, 600, 64), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + pleats(510, 600, 64, 7) + waistband(), default=17))
    out.append(bottom('b_shorts', [{'d': shorts_shape(), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + waistband() +
                      [{'d': smooth_open([(300, 518), (300, 560)]), 's': 'c.o', 'w': 3, 'o': 0.5}], default=16))
    jeans = legs() + [{'d': shorts_shape(510, 580), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + waistband() + \
            [{'d': both(smooth_open([(264, 640), (266, 690)])), 's': 'c.o', 'w': 3, 'o': 0.35}, {'d': smooth_open([(300, 518), (300, 566)]), 's': 'c.o', 'w': 3, 'o': 0.5}]
    out.append(bottom('b_pants', jeans, default=16))
    out.append(bottom('b_leggings', mtube(LEG_L, LEG_W + 4, 'c', 0.1, 0.9, outline='c.o') +
                      [{'d': shorts_shape(510, 572), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}], default=19))
    bib = [{'d': rrect(268, 470, 64, 50, 10), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1},
           {'d': both(smooth_open([(272, 476), (262, 440)])), 's': 'c.o', 'w': 14}, {'d': both(smooth_open([(272, 476), (262, 440)])), 's': 'c', 'w': 8},
           {'d': both(circle(276, 478, 5)), 'f': '#F2C14E', 's': '#B88A2E', 'w': 2},
           {'d': rrect(286, 486, 28, 20, 6), 'f': 'c.s', 's': 'c.o', 'w': 3}]
    out.append(item('b_overalls', 'bottom', [{'z': 26, 'shapes': [{'d': shorts_shape(), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}]},
                                             {'z': 29, 'shapes': bib}], default=16))
    out.append(bottom('b_long', [{'d': skirt_shape(510, 700, 82), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + waistband() + pleats(510, 700, 82, 5)[1:4], default=20))
    tiers = [{'d': skirt_shape(510, 616, 90, scallop=8, n=8), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1},
             {'d': skirt_shape(510, 584, 74, scallop=8, n=7), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1},
             {'d': skirt_shape(510, 552, 58, scallop=7, n=6), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + waistband(510, 'a')
    out.append(bottom('b_tiered', tiers, default=9, accent='#FF9EC0'))
    bubble = [{'d': sym([(300, 508), (252, 508), (240, 524), (220, 566), (226, 590), (260, 596), (300, 592)]), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + waistband(510, 'a') + bow(330, 512, 0.6)
    out.append(bottom('b_bubble', bubble, default=18, accent='#FF9EC0'))
    return out

# ---------- dresses ----------

def dress(id_, neck='square', sleeve=0, sleeve_kind='tube', skirt=None, extra=None, default=3, accent='#FFFFFF', bodice_hem=516, cuff=None):
    S = []
    S += skirt or [{'d': skirt_shape(500, 620, 80), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}]
    if sleeve:
        S += sleeves(sleeve, sleeve_kind)
        if cuff:
            S += cuffs(sleeve, cuff)
    S.append({'d': torso_shape(neck, bodice_hem), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1})
    S += chest_shade()
    if extra:
        S += extra
    return item(id_, 'dress', [{'z': 27, 'shapes': S}], default=default, accent=accent)

def sash(y=512, role='a'):
    return [{'d': rrect(240, y - 8, 120, 18, 8), 'f': role, 's': role + '.o', 'w': 3.5}]

def dresses():
    out = []
    out.append(dress('d_aline', 'scoop', 0, skirt=[{'d': skirt_shape(500, 626, 84), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + pleats(500, 626, 84, 5)[1:4],
                     extra=[{'d': both(smooth_open([(270, 442), (262, 436)])), 's': 'c.o', 'w': 12}, {'d': both(smooth_open([(270, 442), (262, 436)])), 's': 'c', 'w': 6}], default=11))
    princess = [{'d': skirt_shape(504, 668, 118, scallop=12, n=7), 'f': 'c.l', 's': 'c.o', 'w': LW},
                {'d': skirt_shape(504, 640, 104), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + pleats(504, 640, 104, 6)
    out.append(dress('d_princess', 'square', 1, 'puff', skirt=princess, extra=sash(514) + bow(300, 514, 0.8), default=3, accent='#FFE27A'))
    gown = [{'d': skirt_shape(504, 744, 140, scallop=10, n=9), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + pleats(504, 744, 140, 7) + \
           [{'d': ' '.join(star(300 + dx, y, 7, 0.45) for dx, y in ((-90, 690), (-40, 640), (30, 700), (80, 650), (110, 715), (-120, 730), (0, 600))), 'f': '#FFFFFF', 'o': 0.85}]
    out.append(dress('d_gown', 'scoop', 0, skirt=gown, extra=sash(512, 'a'), default=18, accent='#F2C14E'))
    out.append(dress('d_sun', 'square', 0, skirt=[{'d': skirt_shape(500, 640, 96), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + pleats(500, 640, 96, 6)[1:5],
                     extra=[{'d': both(smooth_open([(274, 444), (268, 434)])), 's': 'a', 'w': 7}] + bow(270, 458, 0.4) + bow(330, 458, 0.4), default=9, accent='#FF9EC0'))
    party = [{'d': skirt_shape(506, 606, 104, scallop=10, n=8), 'f': 'c.l', 's': 'c.o', 'w': LW},
             {'d': skirt_shape(506, 588, 90, scallop=10, n=7), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}]
    out.append(dress('d_party', 'scoop', 0, skirt=party, extra=sash(512) + bow(270, 512, 0.8), default=4, accent='#FFFFFF'))
    sailor = [{'d': smooth_closed([(268, 438), (300, 486), (332, 438), (350, 446), (344, 470), (300, 500), (256, 470), (250, 446)]), 'f': 'a', 's': 'a.o', 'w': 3.5}]
    out.append(dress('d_sailor', 'v', 0.36, skirt=[{'d': skirt_shape(500, 616, 80), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + pleats(500, 616, 80, 8) +
                     [{'d': skirt_shape(600, 616, 80), 'f': 'a', 'o': 0}],
                     extra=sailor + bow(300, 486, 0.75, '#E8475A'), cuff='a', default=0, accent='#3C4A8C'))
    mermaid = [{'d': sym([(300, 500), (252, 500), (244, 540), (250, 620), (262, 690), (220, 750), (250, 760), (300, 740)]), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1},
               {'d': ' '.join(smooth_open([(258 + i * 14, 700 + (i % 2) * 6), (265 + i * 14, 712 + (i % 2) * 6), (272 + i * 14, 700 + (i % 2) * 6)]) for i in range(6)), 's': 'c.l', 'w': 3}]
    out.append(dress('d_mermaid', 'scoop', 0, skirt=mermaid, extra=[{'d': both(ellipse(276, 456, 18, 14)), 'f': 'a', 's': 'a.o', 'w': 3}], default=14, accent='#D2C0FF'))
    apron = [{'d': sym([(300, 516), (262, 516), (254, 560), (262, 600), (300, 606)]), 'f': '#FFFFFF', 's': '#C9B3C2', 'w': 3.5},
             {'d': smooth_open([(262, 590), (282, 600), (300, 596), (318, 600), (338, 590)]), 's': '#F0C9DA', 'w': 4}]
    lolita = [{'d': skirt_shape(504, 632, 104, scallop=10, n=8), 'f': '#FFFFFF', 's': '#C9B3C2', 'w': LW},
              {'d': skirt_shape(504, 612, 96), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + apron
    out.append(dress('d_frilly', 'square', 1, 'puff', skirt=lolita, extra=buttons(300, [468, 490], role='#FFFFFF') + bow(300, 446, 0.6, '#FFFFFF'), default=23, accent='#FFFFFF'))
    pin = [{'d': skirt_shape(500, 614, 80), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + pleats(500, 614, 80, 5)[1:4]
    out.append(dress('d_pinafore', 'square', 0.4, skirt=pin, cuff=None, default=5,
                     extra=[{'d': both(smooth_open([(276, 450), (268, 436)])), 's': 'c.o', 'w': 14}] + buttons(300, [474, 496], role='#FFE27A')))
    magic = [{'d': skirt_shape(502, 626, 108, scallop=14, n=5), 'f': 'a', 's': 'a.o', 'w': LW},
             {'d': skirt_shape(502, 604, 92, scallop=12, n=5), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}]
    out.append(dress('d_magic', 'v', 1, 'puff', skirt=magic, extra=sash(510, 'a') + bow(300, 470, 1.0, 'a') +
                     [{'d': star(300, 470, 10, 0.5), 'f': '#FFE27A', 's': '#E0A030', 'w': 2.5}], default=4, accent='#FFFFFF'))
    # bunny pajama onesie with a hood (ears on the hood)
    hood = [{'d': both(ellipse(236, 100, 20, 52, -12)), 'f': 'c', 's': 'c.o', 'w': LW}, {'d': both(ellipse(236, 104, 9, 36, -12)), 'f': '#FFC6D9'},
            {'d': smooth_closed([(150, 300), (156, 180), (220, 126), (300, 116), (380, 126), (444, 180), (450, 300), (440, 400), (412, 410), (420, 300), (400, 210), (300, 170), (200, 210), (180, 300), (188, 410), (160, 400)]), 'f': 'c', 's': 'c.o', 'w': LW}]
    pj = legs(LEG_W + 12, 0.05, 0.94) + [{'d': shorts_shape(500, 590), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + buttons(300, [472, 500, 528], role='a')
    d = dress('d_bunnypj', 'crew', 0.92, skirt=pj, cuff='c', default=2, accent='#FFFFFF', bodice_hem=540)
    d['layers'].append({'z': 58, 'shapes': hood})
    out.append(d)
    return out

# ---------- outerwear ----------

def outers():
    out = []
    def coat(id_, hem, sleeve, extra=None, default=3, accent='#FFFFFF', open_=True):
        S = sleeves(sleeve, w=ARM_W + 18) + cuffs(sleeve, 'c.s' if False else 'c', ARM_W + 20)
        for side in (1, -1):
            pts = [(300 - side * 4, 470), (282, 446) if side == 1 else (318, 446), (300 - side * 46, 438), (300 - side * 62, 452),
                   (300 - side * 64, 490), (300 - side * 66, hem - 6), (300 - side * 40, hem + 4), (300 - side * 8, hem + 2)]
            S.append({'d': smooth_closed(pts, 0.7), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1})
        if extra:
            S += extra
        return item(id_, 'outer', [{'z': 30, 'shapes': S}], default=default, accent=accent)
    out.append(coat('o_cardigan', 540, 0.9, buttons(286, [478, 504, 528], role='a'), default=2, accent='#FFFFFF'))
    out.append(coat('o_jacket', 548, 0.9, [{'d': both(rrect(250, 508, 30, 22, 5)), 'f': 'c.s', 's': 'c.o', 'w': 3}], default=16))
    out.append(coat('o_raincoat', 600, 0.92, buttons(286, [480, 516, 552], 6, '#FFFFFF'), default=9))
    cape = [{'d': smooth_closed([(250, 440), (300, 432), (350, 440), (400, 560), (380, 600), (300, 590), (220, 600), (200, 560)]), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1},
            {'d': smooth_closed([(256, 438), (300, 456), (344, 438), (336, 428), (300, 438), (264, 428)]), 'f': 'a', 's': 'a.o', 'w': 3}] + bow(300, 446, 0.6, 'a')
    out.append(item('o_cape', 'outer', [{'z': 30, 'shapes': cape}], default=5, accent='#F2C14E'))
    return out

# ---------- socks ----------

def socks():
    out = []
    def sock(id_, t0, extra=None, default=0, accent='#FFFFFF', role='c', patternable=False, tights=False):
        S = []
        if tights:
            S.append({'d': shorts_shape(512, 586), 'f': role, 's': role + '.o', 'w': LW})
        S += mtube(LEG_L, LEG_W + 2, role, t0, 1.0, outline=role + '.o')
        for x in (272.4, 327.6):
            S.append({'d': ellipse(x, FEET_Y, 25, 16), 'f': role, 's': role + '.o', 'w': LW})
        if extra:
            S += extra
        return item(id_, 'socks', [{'z': 22, 'shapes': S}], default=default, accent=accent, patternable=patternable)
    out.append(sock('s_ankle', 0.82, [{'d': both(smooth_open([(254, 684), (264, 690), (277, 686), (290, 690), (300, 684)])), 's': 'c.s', 'w': 5}]))
    out.append(sock('s_frilly', 0.8, [{'d': both(smooth_closed([(252, 676), (266, 668), (280, 674), (294, 668), (304, 678), (296, 690), (278, 686), (260, 692)])), 'f': 'a', 's': 'a.o', 'w': 3}], default=2, accent='#FFFFFF'))
    out.append(sock('s_knee', 0.4, [{'d': both(smooth_open([(256, 630), (300, 630)])), 's': 'c.s', 'w': 6}], default=0))
    stripes = []
    for i in range(6):
        t0 = 0.36 + i * 0.1
        stripes += mtube(LEG_L, LEG_W + 2, 'a', t0, t0 + 0.04)
    out.append(sock('s_stripes', 0.36, stripes, default=0, accent='#FF7FA8'))
    out.append(sock('s_thigh', 0.05, [{'d': both(smooth_open([(256, 578), (300, 578)])), 's': 'c.s', 'w': 6}], default=23))
    out.append(sock('s_tights', 0.0, default=18, tights=True))
    out.append(sock('s_hearts', 0.4, [{'d': both(heart(277, 652, 8) + ' ' + heart(277, 690, 7)), 'f': 'a'}], default=2, accent='#F45C9A'))
    return out

# ---------- shoes ----------

FEET = (272.4, 327.6)

def shoe_blob(x, y=FEET_Y + 2, rx=29, ry=20):
    return smooth_closed([(x, y - ry), (x + rx * 0.9, y - ry * 0.55), (x + rx, y + ry * 0.35), (x + rx * 0.6, y + ry),
                          (x, y + ry * 1.05), (x - rx * 0.6, y + ry), (x - rx, y + ry * 0.35), (x - rx * 0.9, y - ry * 0.55)])

def shoes():
    out = []
    def shoe(id_, per_foot, default=3, accent='#FFFFFF', shaft=None):
        S = []
        if shaft:
            S += mtube(LEG_L, LEG_W + 8, 'c', shaft, 0.98, outline='c.o')
        for x in FEET:
            S += per_foot(x)
        return item(id_, 'shoes', [{'z': 24, 'shapes': S}], default=default, accent=accent, patternable=False)
    def sole(x, role='a'):
        return {'d': smooth_closed([(x - 29, FEET_Y + 10), (x, FEET_Y + 16), (x + 29, FEET_Y + 10), (x + 24, FEET_Y + 24), (x, FEET_Y + 26), (x - 24, FEET_Y + 24)]), 'f': role, 's': (role.split('.')[0] + '.o') if not role.startswith('#') else '#B9A7B5', 'w': 3.5}
    def shine(x):
        return {'d': ellipse(x - 10, FEET_Y - 6, 8, 4, -15), 'f': '#FFFFFF', 'o': 0.7}
    out.append(shoe('sh_sneakers', lambda x: [{'d': shoe_blob(x), 'f': 'c', 's': 'c.o', 'w': LW}, sole(x, '#FFFFFF'),
                                             {'d': smooth_open([(x - 10, FEET_Y - 10), (x + 10, FEET_Y - 10)]) + ' ' + smooth_open([(x - 10, FEET_Y - 2), (x + 10, FEET_Y - 2)]), 's': '#FFFFFF', 'w': 3.5}], default=4))
    out.append(shoe('sh_maryjane', lambda x: [{'d': shoe_blob(x), 'f': 'c', 's': 'c.o', 'w': LW},
                                             {'d': smooth_open([(x - 22, FEET_Y - 8), (x + 22, FEET_Y - 8)]), 's': 'c.o', 'w': 8}, {'d': smooth_open([(x - 22, FEET_Y - 8), (x + 22, FEET_Y - 8)]), 's': 'c', 'w': 4},
                                             {'d': circle(x + (8 if x > 300 else -8), FEET_Y - 8, 4), 'f': '#F2C14E'}, shine(x)], default=5))
    out.append(shoe('sh_boots', lambda x: [{'d': shoe_blob(x), 'f': 'c', 's': 'c.o', 'w': LW}, sole(x, 'c.d'), shine(x),
                                          {'d': smooth_open([(x - 22, 650), (x + 22, 650)]), 's': 'c.l', 'w': 6}], default=21, shaft=0.6))
    out.append(shoe('sh_rain', lambda x: [{'d': shoe_blob(x, rx=31), 'f': 'c', 's': 'c.o', 'w': LW}, shine(x),
                                         {'d': ellipse(x - 10, 650, 5, 16), 'f': '#FFFFFF', 'o': 0.6}], default=9, shaft=0.5))
    def ballet(x):
        s = 1 if x > 300 else -1
        return [{'d': smooth_open([(x - 14, FEET_Y - 10), (x + 10, 690), (x - 10, 664), (x + 6, 640)]), 's': 'a', 'w': 4},
                {'d': shoe_blob(x, rx=27, ry=18), 'f': 'c', 's': 'c.o', 'w': LW}, {'d': ellipse(x, FEET_Y - 12, 14, 5), 'f': 'c.s'}] + bow(x, FEET_Y - 12, 0.3, 'a')
    out.append(shoe('sh_ballet', ballet, default=2, accent='#FF9EC0'))
    out.append(shoe('sh_sandals', lambda x: [{'d': smooth_closed([(x - 28, FEET_Y + 12), (x + 28, FEET_Y + 12), (x + 24, FEET_Y + 22), (x - 24, FEET_Y + 22)]), 'f': 'c.s', 's': 'c.o', 'w': 3.5},
                                            {'d': smooth_open([(x - 22, FEET_Y - 4), (x + 22, FEET_Y - 4)]), 's': 'c', 'w': 7},
                                            {'d': flower(x, FEET_Y - 6, 12), 'f': 'a', 's': 'a.o', 'w': 2}, {'d': circle(x, FEET_Y - 6, 3.5), 'f': '#FFE27A'}], default=21, accent='#FFFFFF'))
    def bunny(x):
        return [{'d': ellipse(x - 12, FEET_Y - 26, 7, 20, -15) + ' ' + ellipse(x + 12, FEET_Y - 26, 7, 20, 15), 'f': 'c', 's': 'c.o', 'w': 3.5},
                {'d': shoe_blob(x, rx=32, ry=22), 'f': 'c', 's': 'c.o', 'w': LW},
                {'d': circle(x - 9, FEET_Y - 2, 3) + ' ' + circle(x + 9, FEET_Y - 2, 3), 'f': '#4A2C40'},
                {'d': ellipse(x, FEET_Y + 6, 4, 3), 'f': '#FF8FAA'}]
    out.append(shoe('sh_bunny', bunny, default=0))
    def skate(x):
        return [{'d': rrect(x - 26, FEET_Y + 14, 52, 8, 4), 'f': '#B9B7C6', 's': '#7E7A90', 'w': 2.5},
                {'d': circle(x - 15, FEET_Y + 30, 8) + ' ' + circle(x + 15, FEET_Y + 30, 8), 'f': 'a', 's': 'a.o', 'w': 3},
                {'d': shoe_blob(x), 'f': 'c', 's': 'c.o', 'w': LW}, sole(x, '#FFFFFF'),
                {'d': star(x, FEET_Y - 4, 8, 0.5), 'f': '#FFE27A'}]
    out.append(shoe('sh_skates', skate, default=18, accent='#F45C9A', shaft=0.72))
    out.append(shoe('sh_hightops', lambda x: [{'d': shoe_blob(x), 'f': 'c', 's': 'c.o', 'w': LW}, sole(x, '#FFFFFF'),
                                             {'d': star(x, FEET_Y - 2, 9, 0.5), 'f': '#FFFFFF'}], default=5, shaft=0.78))
    out.append(shoe('sh_glitter', lambda x: [{'d': shoe_blob(x, rx=27, ry=18), 'f': 'c', 's': 'c.o', 'w': LW},
                                            {'d': ' '.join(star(x + dx, FEET_Y + dy, 3.5, 0.45) for dx, dy in ((-12, 2), (4, -6), (14, 6), (-2, 10))), 'f': '#FFFFFF'},
                                            {'d': heart(x, FEET_Y - 14, 7), 'f': 'a', 's': 'a.o', 'w': 2}], default=10, accent='#F45C9A'))
    return out
