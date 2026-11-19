"""Customers and kitchen things."""
import math
from base import *
from toppings import TOPPINGS

INK = '#4A2C40'
CHEEK = '#FF9EB8'

# ---------- customers: 400 x 440, head centered at (200, 190) ----------
HX, HY = 200, 196


def _head(col, rx=124, ry=110):
    return [S(ellipse(HX, HY, rx, ry), col, O(col))]


def _shirt(col):
    d = smooth_closed([(200, 284), (120, 296), (74, 340), (60, 440), (340, 440), (326, 340), (280, 296)])
    return [S(d, col, O(col)), S(smooth_open([(160, 296), (200, 322), (240, 296)]), None, O(col), 4),
            S(smooth_closed([(150, 300), (200, 334), (250, 300), (200, 312)], 0.6), '#FFFFFF', o=0.9)]


def _ear(cx, cy, rx, ry, rot, col, inner=None):
    out = [S(ellipse(cx, cy, rx, ry, rot), col, O(col))]
    if inner:
        out.append(S(ellipse(cx, cy + ry * 0.1, rx * 0.55, ry * 0.6, rot), inner))
    return out


def _tri_ear(pts, col, inner):
    cx = sum(p[0] for p in pts) / 3; cy = sum(p[1] for p in pts) / 3
    ip = [(cx + (x - cx) * 0.55, cy + (y - cy) * 0.55 + 6) for x, y in pts]
    return [S(smooth_closed(pts, 0.35), col, O(col)), S(smooth_closed(ip, 0.35), inner)]


def _nose(col='#6A4050', y=228, w=11):
    return [S(ellipse(HX, y, w, w * 0.72), col), S(ellipse(HX - 3, y - 3, 3, 2), '#FFFFFF', o=0.6)]


def _muzzle(col, y=236, rx=46, ry=32):
    return [S(ellipse(HX, y, rx, ry), col, O(col), 3.5)]


def customer(kind):
    if kind == 'bunny':
        c = '#FFFFFF'
        return (_ear(150, 70, 26, 70, -10, c, '#FFC6D9') + _ear(250, 70, 26, 70, 10, c, '#FFC6D9') + _shirt('#9CCBFF') + _head(c) +
                _nose('#FF8FB8', 226, 9))
    if kind == 'kitty':
        c = '#FFC27A'
        out = (_tri_ear([(96, 140), (112, 52), (176, 104)], c, '#FFD6E2') + _tri_ear([(304, 140), (288, 52), (224, 104)], c, '#FFD6E2') +
               _shirt('#C9B6FF') + _head(c))
        for y in (112, 132):
            out.append(line([(200, y - 20), (200, y)], SH(c), 7))
        out += [line([(180, 96), (184, 120)], SH(c), 7), line([(220, 96), (216, 120)], SH(c), 7)]
        out += _nose('#FF8FB8', 226, 9)
        for s_ in (-1, 1):
            out += [line([(200 + s_ * 50, 230), (200 + s_ * 96, 222)], O(c), 3), line([(200 + s_ * 50, 240), (200 + s_ * 96, 246)], O(c), 3)]
        return out
    if kind == 'bear':
        c = '#C08A62'
        return (_ear(104, 104, 36, 36, 0, c, '#E8B994') + _ear(296, 104, 36, 36, 0, c, '#E8B994') + _shirt('#FFB3CC') + _head(c) +
                _muzzle('#F1D2B0') + _nose('#5A3A32', 222, 13))
    if kind == 'puppy':
        c = '#FFF0D8'
        e = '#B9845A'
        return (_shirt('#9FE3CF') + _head(c) + [S(ellipse(250, 160, 40, 36, 20), '#F2D9B8')] +
                [S(smooth_closed([(92, 120), (60, 160), (64, 250), (100, 268), (124, 200), (128, 124)], 0.8), e, O(e)),
                 S(smooth_closed([(308, 120), (340, 160), (336, 250), (300, 268), (276, 200), (272, 124)], 0.8), e, O(e))] +
                _muzzle('#FFFFFF', 238, 44, 30) + _nose('#5A3A32', 224, 14))
    if kind == 'panda':
        c = '#FFFFFF'; k = '#4E4452'
        return (_ear(106, 100, 34, 32, 0, k) + _ear(294, 100, 34, 32, 0, k) + _shirt('#FFE27A') + _head(c) +
                [S(ellipse(152, 196, 34, 42, 30), k), S(ellipse(248, 196, 34, 42, -30), k)] + _nose(k, 228, 11))
    if kind == 'fox':
        c = '#FF9A5A'
        out = (_tri_ear([(90, 150), (98, 44), (172, 104)], c, '#FFF0E4') + _tri_ear([(310, 150), (302, 44), (228, 104)], c, '#FFF0E4') +
               _shirt('#A9D8FF') + _head(c))
        out += [S(smooth_closed([(200, 180), (120, 210), (96, 260), (150, 296), (200, 300), (250, 296), (304, 260), (280, 210)], 0.8), '#FFF6EC')]
        out += _nose('#4A2C40', 226, 11)
        return out
    if kind == 'piggy':
        c = '#FFC2CF'
        return (_tri_ear([(100, 130), (106, 70), (164, 104)], c, '#FF9EB5') + _tri_ear([(300, 130), (294, 70), (236, 104)], c, '#FF9EB5') +
                _shirt('#B9E6A8') + _head(c) +
                [S(ellipse(HX, 236, 34, 24), '#FFA6BA', O('#FFA6BA'), 3.5), S(ellipse(188, 236, 6, 9), '#D0607E'), S(ellipse(212, 236, 6, 9), '#D0607E')])
    if kind == 'frog':
        c = '#93DB7A'
        return (_shirt('#FFB3CC') + [S(circle(140, 110, 46), c, O(c)), S(circle(260, 110, 46), c, O(c))] + _head(c, 132, 100) +
                [S(ellipse(HX, 250, 80, 30), LT(c), o=0.6)])
    raise ValueError(kind)


CUSTOMERS = ['bunny', 'kitty', 'bear', 'puppy', 'panda', 'fox', 'piggy', 'frog']


def eyes(kind):
    out = []
    for x in (152, 248):
        if kind == 'open':
            out += [S(ellipse(x, 192, 17, 21), INK), S(circle(x - 6, 184, 7), '#FFFFFF'), S(circle(x + 6, 200, 3.2), '#FFFFFF')]
        elif kind == 'blink':
            out.append(line([(x - 16, 194), (x, 200), (x + 16, 194)], INK, 6))
        elif kind == 'happy':
            out.append(line([(x - 17, 200), (x, 184), (x + 17, 200)], INK, 7))
        elif kind == 'star':
            out += [S(star(x, 192, 22, 0.5, 5, -90, 0.3), '#FFE27A', '#D69A2A', 3)]
    for x in (128, 272):
        out.append(S(ellipse(x, 228, 18, 11), CHEEK, o=0.8))
    return out


def mouth(kind):
    if kind == 'smile':
        return [line([(184, 248), (200, 258), (216, 248)], INK, 5)]
    if kind == 'open':
        d = smooth_closed([(178, 244), (222, 244), (214, 266), (200, 272), (186, 266)], 0.7)
        return [S(d, '#9C3A55', INK, 4), S(ellipse(200, 264, 9, 5), '#FF8FA8')]
    if kind == 'chew':
        return [S(ellipse(200, 254, 12, 10), '#9C3A55', INK, 4)]
    raise ValueError(kind)


# ---------- kitchen things ----------
def bowl_back():
    c = '#9CCBFF'
    return [S(ellipse(200, 112, 172, 44), c, O(c)), S(ellipse(200, 116, 158, 36), DP(c), o=0.55)]


def bowl_front():
    c = '#9CCBFF'
    pts = arc_pts(200, 112, 172, 44, 180, 0, 18) + [(366, 140), (330, 236), (260, 278), (200, 284), (140, 278), (70, 236), (34, 140)]
    d = smooth_closed(pts, 0.5)
    out = [S(d, c, O(c)), S(smooth_open(arc_pts(200, 112, 172, 44, 180, 0, 18)), None, O(c), 6)]
    for x, y in [(110, 200), (200, 220), (290, 200), (155, 250), (245, 250)]:
        out.append(S(heart(x, y, 14), '#FFFFFF', o=0.75))
    out += [S(smooth_closed([(60, 160), (90, 170), (110, 236), (86, 226)], 0.7), '#FFFFFF', o=0.4),
            S(rrect(150, 278, 100, 18, 8), SH(c), O(c), 4)]
    return out


def batter():
    return [S(ellipse(200, 120, 152, 32), 'c', 'c.o', 3), S(ellipse(170, 112, 60, 10, -4), 'c.l', o=0.7)]


def lumps():
    return {
        'lump_flour': [S(smooth_closed([(110, 132), (130, 98), (160, 92), (184, 120), (176, 136)], 0.8), '#FFFFFF', '#D8CCD8', 3)],
        'lump_sugar': [S(smooth_closed([(220, 130), (236, 102), (260, 98), (282, 124), (270, 136)], 0.8), '#FFFDF6', '#D8CCD8', 3)] +
                      [S(rrect(230 + i * 11, 108 + (i % 2) * 10, 5, 5, 1), '#E6DDF0') for i in range(4)],
        'lump_egg': [S(ellipse(156, 118, 26, 14), '#FFFFFF', '#E0D4D4', 3), S(circle(156, 116, 10), '#FFC93C', '#E59A2A', 2.5),
                     S(ellipse(252, 124, 26, 14), '#FFFFFF', '#E0D4D4', 3), S(circle(252, 122, 10), '#FFC93C', '#E59A2A', 2.5)],
        'lump_milk': [S(ellipse(200, 128, 92, 18), '#FFFFFF', '#DCD6EC', 3), S(ellipse(176, 124, 30, 5), '#F2F0FF')],
        'lump_butter': [S(tf(rrect(-24, -14, 48, 28, 6), 300, 116, rot=-8), '#FFE27A', '#D6A84A', 3), S(tf(rrect(-20, -12, 40, 8, 4), 300, 112, rot=-8), '#FFF4B8')],
    }


def flour_bag():
    c = '#F6EADF'
    out = [S(smooth_closed([(40, 40), (120, 40), (130, 150), (30, 150)], 0.15), c, O(c)),
           S(poly([(40, 40), (54, 24), (68, 40), (82, 24), (96, 40), (110, 24), (120, 40)]), c, O(c), 4),
           S(circle(80, 98, 30), '#FFFFFF', '#E2C9B8', 3)]
    # wheat on the label
    for k in range(4):
        out.append(S(ellipse(80 - 6 + (k % 2) * 12, 84 + k * 8, 6, 9, 30 if k % 2 else -30), '#F2C14E'))
    out.append(line([(80, 82), (80, 120)], '#C99A3A', 3))
    return out


def sugar_jar():
    g = '#DFF2FF'
    return [S(rrect(34, 50, 92, 104, 22), g, O(g)), S(rrect(42, 74, 76, 74, 16), '#FFFFFF'),
            *[S(rrect(48 + (i * 17) % 64, 82 + (i * 23) % 56, 7, 7, 2), '#E8E0F0') for i in range(10)],
            S(rrect(28, 30, 104, 26, 10), '#FF9EC0', O('#FF9EC0')), S(circle(80, 26, 9), '#FF9EC0', O('#FF9EC0'), 4),
            S(rrect(46, 62, 14, 60, 7), '#FFFFFF', o=0.7)]


def eggs():
    out = [S(rrect(20, 104, 120, 46, 14), '#E9C7A3', O('#E9C7A3'))]
    for x in (48, 80, 112):
        out += [S(ellipse(x, 92, 22, 30), '#FFFDF6', '#D9C6B4'), S(ellipse(x - 7, 82, 6, 9, -20), '#FFFFFF')]
    out += [S(rrect(20, 104, 120, 46, 14), '#E9C7A3', O('#E9C7A3')),
            *[S(ellipse(x, 104, 14, 6), SH('#E9C7A3')) for x in (48, 80, 112)]]
    return out


def milk():
    w = '#FFFFFF'; b = '#7FB0F0'
    return [S(poly([(44, 60), (116, 60), (116, 154), (44, 154)]), w, '#C9D2EA'),
            S(poly([(44, 60), (62, 30), (98, 30), (116, 60)]), b, O(b)), S(rrect(70, 16, 20, 16, 4), b, O(b), 4),
            S(rrect(44, 92, 72, 40, 6), b, O(b), 3.5), S(heart(80, 112, 13), '#FFFFFF'),
            S(rrect(52, 66, 10, 22, 5), '#EEF2FF')]


def butter():
    y = '#FFE27A'
    return [S(ellipse(80, 132, 66, 18), '#FFFFFF', '#D8CCD8'), S(rrect(30, 84, 100, 46, 10), y, O(y)),
            S(rrect(30, 84, 100, 14, 7), '#FFF4B8'), S(rrect(40, 104, 30, 6, 3), '#FFFFFF', o=0.6)]


def bottle():
    out = [S(rrect(62, 14, 36, 20, 6), '#FFFFFF', '#D8CCD8', 4),
           S(smooth_closed([(62, 30), (98, 30), (100, 50), (128, 74), (128, 146), (32, 146), (32, 74), (60, 50)], 0.4), 'c', 'c.o'),
           S(circle(80, 104, 32), '#FFFFFF', 'c.o', 3.5), S(rrect(42, 70, 10, 50, 5), '#FFFFFF', o=0.5)]
    return out


def tub():
    out = [S(smooth_closed([(18, 70), (40, 40), (80, 30), (120, 40), (142, 70)], 0.9), 'c', 'c.o'),
           S(ellipse(60, 54, 14, 7, -20), '#FFFFFF', o=0.6),
           S(poly([(14, 70), (146, 70), (134, 150), (26, 150)]), '#FFFFFF', '#CDB9D0'),
           S(rrect(10, 62, 140, 18, 8), 'c.l', 'c.o', 4), S(heart(80, 112, 16), 'c')]
    return out


def sauce_bottle():
    return [S(poly([(72, 8), (88, 8), (84, 30), (76, 30)]), 'c', 'c.o', 3.5),
            S(rrect(54, 26, 52, 20, 6), '#FFFFFF', '#D8CCD8', 4),
            S(rrect(44, 42, 72, 110, 22), 'c', 'c.o'), S(circle(80, 98, 22), '#FFFFFF', 'c.o', 3),
            S(heart(80, 99, 12), 'c'), S(rrect(52, 56, 10, 60, 5), '#FFFFFF', o=0.5)]


def piping_bag():
    return [S(smooth_closed([(30, 30), (130, 30), (88, 136), (72, 136)], 0.3), '#FFFFFF', '#CDB9D0'),
            S(smooth_closed([(40, 56), (120, 56), (88, 132), (72, 132)], 0.3), 'c', 'c.o', 4),
            S(poly([(70, 130), (90, 130), (86, 152), (74, 152)]), '#C9C6D9', '#9E9AB4', 3),
            S(rrect(24, 22, 112, 16, 8), '#FFFFFF', '#CDB9D0', 4)]


def shaker():
    return [S(rrect(40, 50, 80, 100, 18), '#FFFFFF', '#CDB9D0'),
            *[S(tf(rrect(-6, -2, 12, 4, 2), 56 + (i * 13) % 50, 74 + (i * 17) % 64, rot=i * 37), ['#FF7AAE', '#FFE27A', '#7EC2F2', '#9FE3CF', '#C9B6FF'][i % 5]) for i in range(18)],
            S(smooth_closed([(36, 52), (50, 24), (110, 24), (124, 52)], 0.4), 'c', 'c.o'),
            *[S(circle(x, 36, 3), 'c.d') for x in (66, 80, 94)], S(rrect(48, 62, 10, 60, 5), '#FFFFFF', o=0.5)]


def pan():
    m = '#C9C6D9'
    return [S(ellipse(150, 70, 140, 30), DP(m), O(m)),
            S(smooth_closed([(10, 70), (290, 70), (276, 130), (150, 142), (24, 130)], 0.4), m, O(m)),
            S(smooth_open(arc_pts(150, 70, 140, 30, 180, 0, 14)), None, O(m), 6),
            S(rrect(40, 90, 60, 8, 4), '#FFFFFF', o=0.6)]


def oven():
    b = '#FF9EC0'
    out = [S(rrect(20, 20, 440, 420, 40), b, O(b)), S(rrect(20, 20, 440, 92, 40), SH(b)), S(rrect(20, 80, 440, 32, 0), SH(b)),
           S(rrect(20, 20, 440, 420, 40), None, O(b))]
    for x in (90, 170, 310, 390):
        out += [S(circle(x, 64, 20), '#FFFFFF', O(b), 4), line([(x, 52), (x, 64)], O(b), 5)]
    out += [S(circle(240, 64, 30), '#FFF6EC', O(b), 4)]
    out += [S(rrect(50, 136, 380, 284, 30), LT(b), O(b)), S(rrect(80, 170, 320, 200, 22), '#5B3A68', O(b))]
    out += [S(rrect(120, 132, 240, 22, 11), '#FFFFFF', O(b), 4)]
    return out


def oven_glass():
    return [S(smooth_closed([(100, 186), (180, 186), (110, 300)], 0.2), '#FFFFFF', o=0.22),
            S(smooth_closed([(200, 186), (230, 186), (130, 350), (110, 350)], 0.2), '#FFFFFF', o=0.15),
            S(rrect(80, 170, 320, 200, 22), None, O('#FF9EC0'), 6)]


def dial_hand():
    return [line([(240, 64), (240, 42)], '#FF6F9F', 6), S(circle(240, 64, 6), '#FF6F9F')]


def counter():
    """Shop counter front, 1200 x 260. Drawn in tiles by the app."""
    w = '#FFFFFF'
    out = [S(rrect(0, 0, 1200, 44, 14), '#FFF6EC', '#E3C8B8'), S(rrect(0, 44, 1200, 216, 0), '#FFD3E0')]
    for x in range(0, 1200, 100):
        out.append(S(rrect(x + 14, 66, 72, 170, 26), '#FFE3EC', '#F0B8CB', 4))
    out.append(S(rrect(0, 44, 1200, 16, 0), '#F2B8CB'))
    return out


def awning():
    out = []
    for k in range(12):
        col = '#FF9EC0' if k % 2 == 0 else '#FFFFFF'
        x = k * 100
        out.append(S(smooth_closed([(x, 0), (x + 100, 0), (x + 100, 80), (x + 50, 108), (x, 80)], 0.25), col, '#E98AAE', 4))
    return out


def window():
    f_ = '#FFFFFF'
    out = [S(rrect(0, 0, 320, 260, 24), f_, '#E0C2D2'), S(rrect(18, 18, 284, 224, 16), '#BFE4FF')]
    out += [S(circle(240, 76, 30), '#FFF4B0'), S(smooth_closed([(40, 200), (70, 170), (110, 176), (140, 150), (190, 160), (220, 140), (284, 170), (284, 230), (40, 230)], 0.6), '#B9E6A8')]
    out += [S(ellipse(90, 80, 36, 16), '#FFFFFF'), S(ellipse(120, 70, 30, 16), '#FFFFFF')]
    out += [S(rrect(154, 18, 12, 224, 4), f_), S(rrect(18, 124, 284, 12, 4), f_), S(rrect(0, 0, 320, 260, 24), None, '#E0C2D2', 6)]
    return out


def bell():
    g = '#FFD45E'
    return [S(ellipse(80, 132, 70, 14), '#C9C6D9', '#9E9AB4', 4),
            S(smooth_closed([(26, 126), (34, 80), (80, 48), (126, 80), (134, 126)], 0.6), g, '#C08A2A'),
            S(circle(80, 42, 10), g, '#C08A2A', 4), S(ellipse(56, 86, 10, 18, 30), '#FFF6C8', o=0.8)]


def heart_jar():
    return [S(rrect(24, 40, 112, 112, 30), '#EAF6FF', '#B9C9E6'), S(rrect(34, 24, 92, 24, 10), '#FF9EC0', O('#FF9EC0'), 4),
            S(heart(80, 104, 30), '#FF7AAE', O('#FF7AAE'), 4), S(rrect(36, 56, 10, 70, 5), '#FFFFFF', o=0.7)]


def thought():
    return [S(circle(40, 260, 12), '#FFFFFF', '#D8C8E0', 4), S(circle(70, 230, 18), '#FFFFFF', '#D8C8E0', 4),
            S(smooth_closed([(90, 120), (100, 50), (160, 14), (240, 20), (290, 60), (296, 140), (250, 196), (170, 204), (110, 180)], 0.8), '#FFFFFF', '#D8C8E0', 5)]


def all_sprites():
    sp = {f'cust_{k}': customer(k) for k in CUSTOMERS}
    for k in ('open', 'blink', 'happy', 'star'):
        sp[f'eyes_{k}'] = eyes(k)
    for k in ('smile', 'open', 'chew'):
        sp[f'mouth_{k}'] = mouth(k)
    sp.update({'bowl_back': bowl_back(), 'bowl_front': bowl_front(), 'batter': batter(), 'flour': flour_bag(), 'sugar': sugar_jar(),
               'eggs': eggs(), 'milk': milk(), 'butter': butter(), 'bottle': bottle(), 'tub': tub(), 'saucebottle': sauce_bottle(),
               'pipingbag': piping_bag(), 'shaker': shaker(), 'pan': pan(), 'oven': oven(), 'oven_glass': oven_glass(), 'dial': dial_hand(),
               'counter': counter(), 'awning': awning(), 'window': window(), 'bell': bell(), 'heartjar': heart_jar(), 'thought': thought()})
    sp.update(lumps())
    return sp
