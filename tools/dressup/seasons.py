"""Holiday and season pieces: Halloween, winter and birthday. Grouped into ready-made sets in the app
(DressUpSets.swift); every piece is also in the normal tray, always unlocked."""
import math
from geom import *
from body import LW
from clothes import item, bow, buttons, dress, top, skirt_shape, pleats, sash
from extras import HR


def snowflake(cx, cy, r, role='#FFFFFF', w=3.5):
    d = []
    for k in range(6):
        a = math.radians(k * 60)
        x1, y1 = cx + math.cos(a) * r, cy + math.sin(a) * r
        d.append(f"M{f(cx)} {f(cy)} L{f(x1)} {f(y1)}")
        for s in (-1, 1):
            b = a + s * math.radians(40)
            mx, my = cx + math.cos(a) * r * 0.6, cy + math.sin(a) * r * 0.6
            d.append(f"M{f(mx)} {f(my)} L{f(mx + math.cos(b) * r * 0.32)} {f(my + math.sin(b) * r * 0.32)}")
    return {'d': ' '.join(d), 's': role, 'w': w}


def dresses():
    out = []
    # pumpkin dress: a round ribbed pumpkin skirt with a leafy collar
    rib = [{'d': ellipse(300, 572, 118, 74), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}]
    for dx in (-70, -30, 30, 70):
        rib.append({'d': smooth_open([(300 + dx * 0.55, 504), (300 + dx * 1.1, 572), (300 + dx * 0.55, 642)]), 's': 'c.s', 'w': 4})
    rib.append({'d': smooth_open([(300, 500), (300, 644)]), 's': 'c.s', 'w': 4})
    leaves = [{'d': both(smooth_closed([(300, 444), (266, 432), (246, 446), (262, 462), (292, 458)], 0.9)), 'f': '#6CCB8B', 's': '#3F8A57', 'w': 3},
              {'d': smooth_open([(300, 444), (296, 424), (306, 414)]), 's': '#3F8A57', 'w': 6}]
    out.append(dress('d_pumpkin', 'scoop', 0.3, skirt=rib, extra=leaves + sash(506, 'a'), default=8, accent='#6CCB8B'))
    # witchy dress: pointed hem, stars and a little cape collar
    pts = [(300, 498), (252, 498), (244, 514)]
    hem = []
    n = 6
    for i in range(n + 1):
        x = 200 + i * (100 / n)
        hem.append((x, 640 if i % 2 == 0 else 610))
    witch = [{'d': sym(pts + [(216, 580)] + hem[:-1] + [(300, 640)]), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1},
             {'d': ' '.join(star(300 + dx, y, 9, 0.45) for dx, y in ((-60, 560), (-20, 600), (24, 548), (64, 596), (0, 520))), 'f': '#FFE27A', 'o': 0.95}]
    collar = [{'d': smooth_closed([(256, 438), (300, 470), (344, 438), (362, 452), (330, 486), (300, 478), (270, 486), (238, 452)], 0.6), 'f': 'a', 's': 'a.o', 'w': 3.5}]
    out.append(dress('d_witchy', 'v', 0.9, skirt=witch, extra=collar + sash(506, 'a'), cuff='a', default=19, accent='#FFA24C'))
    # birthday cake dress: three frosted tiers with sprinkles and a cherry
    cake = []
    tiers = [(588, 646, 124), (540, 594, 104), (502, 546, 84)]
    for k, (y0, y1, w) in enumerate(tiers):
        cake.append({'d': rrect(300 - w, y0, 2 * w, y1 - y0, 14), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1})
        drip = [(300 - w - 2, y0 + 4)]
        for i in range(9):
            x = 300 - w + (2 * w) * (i + 0.5) / 9
            drip += [(x - w / 18, y0 + 12), (x, y0 + 22 + (i % 3) * 7), (x + w / 18, y0 + 12)]
        drip += [(300 + w + 2, y0 + 4), (300 + w, y0 - 6), (300 - w, y0 - 6)]
        cake.append({'d': smooth_closed(drip, 0.5), 'f': 'a', 's': 'a.o', 'w': 3})
        cake.append({'d': ' '.join(rrect(300 + dx, y0 + 30 + (j % 2) * 8, 8, 4, 2) for j, dx in enumerate(range(-w + 16, w - 16, 26))), 'f': '#FF8FB8'})
    out.append(dress('d_cake', 'square', 1, 'puff', skirt=cake, extra=[{'d': circle(300, 492, 9), 'f': '#E8475A', 's': '#A8283A', 'w': 3}], default=3, accent='#FFFFFF'))
    return out


def tops():
    out = []
    flakes = [snowflake(300, 486, 20), snowflake(268, 462, 9, '#FFFFFF', 2.5), snowflake(334, 508, 9, '#FFFFFF', 2.5)]
    out.append(top('t_snowflake', 'high', 530, 0.92, cuff='a', extra=flakes + [{'d': rrect(244, 514, 112, 16, 7), 'f': 'a', 's': 'a.o', 'w': 3}], default=16, accent='#FFFFFF'))
    return out


def hats():
    out = []

    def hat(id_, S, default=3, accent='#FFFFFF', z=60):
        return item(id_, 'hat', [{'z': z, 'shapes': S}], color='own', default=default, accent=accent, patternable=False)
    band = [{'d': smooth_open([(166, 300), (176, 190), (240, 130), (300, 118), (360, 130), (424, 190), (434, 300)]), 's': 'c.o', 'w': 14},
            {'d': smooth_open([(166, 300), (176, 190), (240, 130), (300, 118), (360, 130), (424, 190), (434, 300)]), 's': 'c', 'w': 8}]
    muffs = [{'d': both(scallop_circle(160, 310, 40)), 'f': 'a', 's': 'a.o', 'w': 3.5}, {'d': both(circle(158, 304, 18)), 'f': 'a.l', 'o': 0.8}]
    out.append(hat('h_earmuffs', band + muffs, default=3, accent='#FFFFFF'))
    cone = smooth_closed([(250, 162), (316, 30), (350, 150)], 0.15)
    party = [{'d': cone, 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': smooth_open([(266, 128), (300, 116), (338, 128)]) + ' ' + smooth_open([(286, 88), (306, 80), (326, 88)]), 's': 'a', 'w': 9},
             {'d': ' '.join(circle(316 + dx, 30 + dy, 9) for dx, dy in ((0, -6), (-9, 4), (9, 4))), 'f': '#FFE27A', 's': '#D69A2A', 'w': 2.5}]
    out.append(hat('h_partyhat', party, default=16, accent='#FFFFFF'))
    witch_small = [{'d': ellipse(300, 150, 150, 28), 'f': 'c', 's': 'c.o', 'w': LW},
                   {'d': smooth_closed([(230, 146), (268, 60), (300, 10), (350, -6), (326, 30), (318, 80), (370, 146)], 0.7), 'f': 'c', 's': 'c.o', 'w': LW},
                   {'d': smooth_closed([(232, 140), (236, 116), (366, 116), (370, 140)], 0.3), 'f': 'a', 's': 'a.o', 'w': 3},
                   {'d': heart(330, 128, 9), 'f': '#FFE27A'}]
    out.append(hat('h_pointy', witch_small, default=19, accent='#FFA24C'))
    return out


def scallop_circle(cx, cy, r, n=10):
    pts = []
    for i in range(n * 2):
        a = math.radians(i * 180 / n)
        k = 1.0 if i % 2 == 0 else 0.86
        pts.append((cx + math.cos(a) * r * k, cy + math.sin(a) * r * k))
    return smooth_closed(pts, 1.0)


def held():
    out = []
    hx_, hy = HR
    hand = {'d': circle(hx_, hy, 18), 'f': 'skin', 's': 'skin.o', 'w': LW}

    def h(id_, S, default=3, accent='#FFFFFF'):
        return item(id_, 'hold', [{'z': 70, 'shapes': S}], color='own', default=default, accent=accent, patternable=False)
    # trick-or-treat pumpkin bucket
    by = 598
    bucket = [{'d': smooth_open([(hx_ - 30, by - 20), (hx_, hy + 6), (hx_ + 30, by - 20)]), 's': '#6B4A50', 'w': 4},
              {'d': ellipse(hx_, by, 40, 34), 'f': 'c', 's': 'c.o', 'w': LW},
              {'d': smooth_open([(hx_ - 14, by - 32), (hx_ - 20, by), (hx_ - 14, by + 32)]) + ' ' + smooth_open([(hx_ + 14, by - 32), (hx_ + 20, by), (hx_ + 14, by + 32)]), 's': 'c.s', 'w': 3},
              {'d': poly([(hx_ - 22, by - 6), (hx_ - 12, by - 18), (hx_ - 4, by - 6)]) + ' ' + poly([(hx_ + 4, by - 6), (hx_ + 12, by - 18), (hx_ + 22, by - 6)]), 'f': '#5B3A48'},
              {'d': smooth_closed([(hx_ - 20, by + 6), (hx_, by + 16), (hx_ + 20, by + 6), (hx_ + 12, by + 18), (hx_, by + 22), (hx_ - 12, by + 18)], 0.6), 'f': '#5B3A48'},
              {'d': ' '.join(circle(hx_ + dx, by - 34 + dy, 7) for dx, dy in ((-14, 0), (4, -6), (18, 2))), 'f': 'a', 's': 'a.o', 'w': 2.5}, hand]
    out.append(h('p_candy', bucket, default=8, accent='#FF8FB8'))
    # a present with a bow
    gy = 556
    gift = [{'d': rrect(hx_ - 36, gy, 72, 62, 8), 'f': 'c', 's': 'c.o', 'w': LW},
            {'d': rrect(hx_ - 6, gy, 12, 62, 2) + ' ' + rrect(hx_ - 36, gy + 24, 72, 12, 2), 'f': 'a', 's': 'a.o', 'w': 2.5}] + bow(hx_, gy - 2, 0.8, 'a') + [hand]
    out.append(h('p_present', gift, default=15, accent='#FF8FB8'))
    # a mug of cocoa with steam
    my = 556
    mug = [{'d': smooth_open([(hx_ + 30, my + 10), (hx_ + 46, my + 22), (hx_ + 30, my + 40)]), 's': 'c.o', 'w': 12}, {'d': smooth_open([(hx_ + 30, my + 10), (hx_ + 46, my + 22), (hx_ + 30, my + 40)]), 's': 'c', 'w': 6},
           {'d': rrect(hx_ - 30, my, 62, 58, 12), 'f': 'c', 's': 'c.o', 'w': LW}, {'d': ellipse(hx_ + 1, my + 4, 26, 6), 'f': '#8A5236'},
           {'d': ' '.join(circle(hx_ + dx, my + 2, 6) for dx in (-10, 4, 14)), 'f': '#FFFFFF', 's': '#E3D6DE', 'w': 2},
           {'d': smooth_open([(hx_ - 8, my - 10), (hx_ - 14, my - 26), (hx_ - 6, my - 42)]) + ' ' + smooth_open([(hx_ + 10, my - 10), (hx_ + 4, my - 28), (hx_ + 12, my - 44)]), 's': '#FFFFFF', 'w': 4, 'o': 0.8},
           {'d': heart(hx_, my + 30, 10), 'f': 'a'}, hand]
    out.append(h('p_cocoa', mug, default=5, accent='#FFFFFF'))
    return out
