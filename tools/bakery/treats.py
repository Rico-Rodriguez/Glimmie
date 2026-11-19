"""Cakes, cupcakes and ice cream, all in one 600x600 stage. 'c' is the color of the part being drawn."""
import math
from base import *

CX = 300
PLATE_Y = 532

# cake tiers: half width, height; tier 0 is the bottom one
TIER_HW = [170, 128, 92]
TIER_H = [118, 100, 84]


def tier_geom(i):
    b = 518
    for k in range(i):
        b = b - TIER_H[k]
    hw = TIER_HW[i]
    return dict(hw=hw, b=b, t=b - TIER_H[i], ry=hw * 0.26)


def plate():
    w = '#FFFFFF'
    return [S(ellipse(CX, PLATE_Y + 14, 236, 40), '#E9DDEA'),
            S(ellipse(CX, PLATE_Y, 236, 40), w, '#CDB9D0'),
            S(ellipse(CX, PLATE_Y - 4, 190, 28), '#F6EEF6'),
            S(ellipse(CX - 120, PLATE_Y - 12, 40, 7, -6), '#FFFFFF', o=0.9)]


def cake_body(i):
    g = tier_geom(i); hw, b, t, ry = g['hw'], g['b'], g['t'], g['ry']
    side = ([(CX - hw, t), (CX - hw, b)] + arc_pts(CX, b, hw, ry, 180, 0, 16)[1:] +
            [(CX + hw, t)] + arc_pts(CX, t, hw, ry, 0, -180, 16)[1:-1])
    d = ' '.join([f"M{f(side[0][0])} {f(side[0][1])}"] + [f"L{f(x)} {f(y)}" for x, y in side[1:]]) + ' Z'
    mid = (t + b) / 2 + 6
    band_top = arc_pts(CX, mid - 7, hw, ry, 180, 0, 16)
    band_bot = arc_pts(CX, mid + 7, hw, ry, 0, 180, 16)
    band = poly(band_top + band_bot)
    out = [S(d, None, None), {'d': d, 'g': ['c', 'c.s']},
           S(band, '#FFF6EC'),
           S(smooth_open(arc_pts(CX, mid + 7, hw, ry, 180, 0, 16)), None, 'c.s', 2.5, o=0.6),
           S(d, None, 'c.o'),
           S(ellipse(CX, t, hw, ry), 'c.l', 'c.o'),
           S(ellipse(CX - hw * 0.35, t - ry * 0.2, hw * 0.3, ry * 0.25, -4), '#FFFFFF', o=0.35),
           S(rrect(CX - hw + 12, t + 12, 12, b - t - 24, 6), '#FFFFFF', o=0.3)]
    return [x for x in out if x.get('f') or x.get('s') or x.get('g')]


def cake_frost(i, seed=0):
    g = tier_geom(i); hw, b, t, ry = g['hw'] + 5, g['b'], g['t'], g['ry'] + 2
    H = b - t
    drips = [(-0.78, 0.42), (-0.45, 0.62), (-0.12, 0.38), (0.2, 0.7), (0.52, 0.45), (0.82, 0.55)]
    front = []
    n = 48
    for k in range(n + 1):
        u = -1 + 2 * k / n
        x = CX + u * hw
        y = t + ry * math.sqrt(max(0, 1 - u * u)) + H * 0.12
        for du, L in drips:
            y += H * L * 0.55 * math.exp(-((u - du) / 0.07) ** 2)
        front.append((x, y))
    back = arc_pts(CX, t, hw, ry, 0, -180, 16)[1:-1]
    pts = [(CX - hw, t)] + front + [(CX + hw, t)] + back
    d = smooth_closed(pts, 0.9)
    out = [S(d, 'c', 'c.o'), S(ellipse(CX, t, hw - 10, ry - 6), 'c.l', o=0.55),
           S(ellipse(CX - hw * 0.4, t - ry * 0.25, hw * 0.25, ry * 0.18, -4), '#FFFFFF', o=0.6)]
    for du, L in drips:
        x = CX + du * hw
        y = t + ry * math.sqrt(max(0, 1 - du * du)) + H * 0.12 + H * L * 0.55 - 10
        out.append(S(ellipse(x - 2, y, 2.5, 5), '#FFFFFF', o=0.6))
    # piped pearls along the bottom of the tier
    gb = tier_geom(i)
    for k in range(13):
        u = -0.96 + 1.92 * k / 12
        x = CX + u * gb['hw']; y = gb['b'] + gb['ry'] * math.sqrt(max(0, 1 - u * u)) - 4
        out += [S(circle(x, y, 11), 'c', 'c.o', 3), S(circle(x - 3, y - 4, 3.5), '#FFFFFF', o=0.7)]
    return out


# --- cupcake ---
LINER_T, LINER_B = 418, 532


def liner():
    t, b = LINER_T, LINER_B
    out = [S(poly([(CX - 128, t), (CX + 128, t), (CX + 96, b), (CX - 96, b)]), 'c', 'c.o')]
    for k in range(-5, 6):
        x0 = CX + k * 23; x1 = CX + k * 17.4
        out.append(S(poly([(x0 - 6, t + 4), (x0 + 6, t + 4), (x1 + 4, b - 3), (x1 - 4, b - 3)]), 'c.s' if k % 2 else 'c.l', o=0.7))
    out.append(S(poly([(CX - 128, t), (CX + 128, t), (CX + 96, b), (CX - 96, b)]), None, 'c.o'))
    out.append(S(smooth_open([(CX - 132, t), (CX, t + 10), (CX + 132, t)]), None, 'c.o', 7))
    return out


def cupcake_top():
    d = smooth_closed([(CX - 132, LINER_T + 6), (CX - 128, 380), (CX - 84, 340), (CX, 326), (CX + 84, 340), (CX + 128, 380), (CX + 132, LINER_T + 6), (CX, LINER_T + 14)])
    return [S(d, 'c', 'c.o'), S(ellipse(CX - 52, 360, 34, 12, -14), 'c.l', o=0.7)]


def _ring(cy, hw, h, tip=False):
    pts = [(CX - hw, cy + h * 0.15), (CX - hw * 0.88, cy - h * 0.45), (CX - hw * 0.4, cy - h * 0.7), (CX, cy - h * 0.72),
           (CX + hw * 0.4, cy - h * 0.7), (CX + hw * 0.88, cy - h * 0.45), (CX + hw, cy + h * 0.15),
           (CX + hw * 0.7, cy + h * 0.5), (CX, cy + h * 0.58), (CX - hw * 0.7, cy + h * 0.5)]
    return [S(smooth_closed(pts), 'c', 'c.o'),
            S(smooth_open([(CX - hw * 0.8, cy + h * 0.1), (CX - hw * 0.2, cy + h * 0.35), (CX + hw * 0.5, cy + h * 0.25)]), None, 'c.s', 4),
            S(ellipse(CX - hw * 0.45, cy - h * 0.3, hw * 0.22, h * 0.12, -10), '#FFFFFF', o=0.6)]


def frost_swirl(stage):
    out = []
    rings = [(392, 140, 70), (336, 108, 62), (286, 72, 54)]
    for k in range(stage):
        out += _ring(*rings[k])
    if stage == 3:
        out += [S(smooth_closed([(CX, 216), (CX - 30, 254), (CX - 8, 266), (CX + 26, 258)], 0.8), 'c', 'c.o'),
                S(ellipse(CX - 8, 244, 5, 9, 20), '#FFFFFF', o=0.6)]
    return out


def frost_cloud(stage):
    rows = [[(-104, 398, 42), (-52, 384, 46), (0, 380, 48), (52, 384, 46), (104, 398, 42)],
            [(-70, 336, 40), (-24, 324, 42), (24, 324, 42), (70, 336, 40)],
            [(-28, 278, 38), (28, 278, 38), (0, 236, 34)]]
    out = []
    for k in range(stage):
        for dx, y, r in rows[k]:
            out += [S(circle(CX + dx, y, r), 'c', 'c.o'), S(ellipse(CX + dx - r * 0.35, y - r * 0.4, r * 0.3, r * 0.18, -25), '#FFFFFF', o=0.6)]
    return out


def frost_dome(stage):
    h = [52, 84, 112][stage - 1]
    top = 410 - h
    pts = [(CX - 142, 404), (CX - 132, top + h * 0.45), (CX - 90, top + h * 0.08), (CX, top), (CX + 90, top + h * 0.08),
           (CX + 132, top + h * 0.45), (CX + 142, 404), (CX + 120, 424), (CX + 100, 446), (CX + 84, 426), (CX + 40, 430),
           (CX + 20, 456), (CX, 432), (CX - 50, 430), (CX - 70, 450), (CX - 92, 424), (CX - 124, 422)]
    out = [S(smooth_closed(pts, 0.8), 'c', 'c.o'),
           S(ellipse(CX - 60, top + h * 0.3, 34, 14, -20), '#FFFFFF', o=0.55), S(circle(CX + 70, top + h * 0.35, 6), '#FFFFFF', o=0.5)]
    if stage == 3:
        out += [S(smooth_closed([(CX, top - 44), (CX - 24, top - 10), (CX, top + 2), (CX + 24, top - 10)], 0.8), 'c', 'c.o'),
                S(ellipse(CX - 6, top - 22, 4, 8, 20), '#FFFFFF', o=0.6)]
    return out


FROST_STYLES = {'swirl': frost_swirl, 'cloud': frost_cloud, 'dome': frost_dome}


# --- ice cream ---
CONE_T = 412
SCOOP_Y0, SCOOP_DY = 372, 80


def _waffle_lines(top_l, top_r, tip, col, n=6):
    out = []
    def lerp(a, b, t): return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
    for k in range(1, n + 2):
        t0 = (k - 2) / n; t1 = k / n
        if t0 >= 0:
            out.append(line([lerp(top_l, tip, t0), lerp(top_r, tip, min(1, t1))], col, 3.5))
            out.append(line([lerp(top_r, tip, t0), lerp(top_l, tip, min(1, t1))], col, 3.5))
    out.append(line([lerp(top_l, tip, 0), lerp(top_r, tip, 1 / n * 2 if False else 0.34)], col, 3.5))
    out.append(line([lerp(top_r, tip, 0), lerp(top_l, tip, 0.34)], col, 3.5))
    return out


def cone_waffle(dip=None):
    tl, tr, tip = (CX - 100, CONE_T), (CX + 100, CONE_T), (CX, 590)
    c = '#F2C27A'
    out = [S(smooth_closed([tl, tr, (CX + 8, 582), tip, (CX - 8, 582)], 0.15), c, O(c))]
    out += _waffle_lines(tl, tr, tip, SH(c))
    out.append(S(smooth_closed([tl, tr, (CX + 8, 582), tip, (CX - 8, 582)], 0.15), None, O(c)))
    out.append(S(rrect(CX - 110, CONE_T - 14, 220, 34, 14), LT(c), O(c)))
    out.append(S(rrect(CX - 98, CONE_T - 6, 60, 8, 4), '#FFFFFF', o=0.5))
    if dip:
        pts = [(CX - 112, CONE_T - 16), (CX + 112, CONE_T - 16), (CX + 104, CONE_T + 30), (CX + 74, CONE_T + 40), (CX + 60, CONE_T + 70),
               (CX + 46, CONE_T + 42), (CX + 10, CONE_T + 46), (CX - 6, CONE_T + 84), (CX - 22, CONE_T + 46), (CX - 58, CONE_T + 44),
               (CX - 74, CONE_T + 62), (CX - 88, CONE_T + 38), (CX - 106, CONE_T + 30)]
        out += [S(smooth_closed(pts, 0.6), dip, O(dip)), S(rrect(CX - 96, CONE_T - 8, 50, 8, 4), '#FFFFFF', o=0.4)]
        if dip != '#6B3A2E':
            cols = ['#FFFFFF', '#FFE27A', '#7EC2F2', '#9FE3CF', '#C9B6FF']
            for i, (x, y, r) in enumerate([(-80, 4, 20), (-50, 20, 120), (-20, 6, 60), (14, 24, 150), (44, 8, 30), (74, 18, 100), (-64, 34, 80), (30, 36, 10), (88, 30, 40), (0, 40, 70)]):
                out.append(S(tf(rrect(-7, -2.5, 14, 5, 2.5), CX + x, CONE_T + y, rot=r), cols[i % 5]))
    return out


def cone_sugar():
    c = '#D6914E'
    tl, tr, tip = (CX - 96, CONE_T), (CX + 96, CONE_T), (CX, 596)
    out = [S(smooth_closed([tl, tr, (CX + 6, 590), tip, (CX - 6, 590)], 0.12), c, O(c))]
    for y in range(444, 580, 22):
        k = (y - CONE_T) / (596 - CONE_T)
        hw = 96 * (1 - k)
        out.append(S(smooth_open([(CX - hw + 6, y), (CX, y + 6), (CX + hw - 6, y)]), None, SH(c), 4))
    out += [S(rrect(CX - 108, CONE_T - 14, 216, 32, 12), LT(c), O(c)), S(rrect(CX - 96, CONE_T - 6, 56, 8, 4), '#FFFFFF', o=0.5)]
    return out


def cup():
    t, b = CONE_T, 556
    pts = [(CX - 120, t), (CX + 120, t), (CX + 88, b), (CX - 88, b)]
    out = [S(poly(pts), 'c', 'c.o')]
    for k, x in enumerate(range(-90, 100, 30)):
        y = t + 40 + (k % 2) * 34
        xx = CX + x * (1 - (y - t) / (b - t) * 0.27)
        out.append(S(heart(xx, y, 10) if k % 2 else star(xx, y, 11, 0.5, 5, -90, 0.3), 'c.l', o=0.9))
    out += [S(poly(pts), None, 'c.o'), S(rrect(CX - 128, t - 14, 256, 28, 12), 'c.l', 'c.o'),
            S(rrect(CX - 116, t - 7, 60, 8, 4), '#FFFFFF', o=0.6)]
    return out


CONES = {'waffle': lambda: cone_waffle(), 'sugar': cone_sugar, 'choco': lambda: cone_waffle('#6B3A2E'),
         'pinkdip': lambda: cone_waffle('#FF9EC0'), 'cup': cup}


def scoop():
    """One scoop centered at (0, 0)."""
    top = [(-96, 10), (-92, -36), (-60, -78), (0, -92), (60, -78), (92, -36), (96, 10)]
    rim = []
    n = 9
    for k in range(n + 1):
        x = 104 - 208 * k / n
        rim.append((x, 34 + (10 if k % 2 else -2)))
    d = smooth_closed(top + rim, 0.9)
    return [S(d, 'c', 'c.o'),
            S(smooth_open([(-90, 16), (-40, 30), (40, 30), (90, 16)]), None, 'c.s', 5),
            S(smooth_closed([(-70, -40), (-48, -70), (-14, -78), (-30, -56), (-56, -30)], 0.8), '#FFFFFF', o=0.45),
            S(circle(56, -50, 6), '#FFFFFF', o=0.5)]


def scoop_chips(col):
    out = []
    for x, y, r in [(-52, -20, 20), (-10, -52, 70), (30, -18, 130), (62, 0, 40), (-30, 12, 100), (10, 8, 10), (46, -54, 160), (-64, 12, 60)]:
        out.append(S(tf(smooth_closed([(-6, -5), (7, -4), (5, 6), (-5, 5)], 0.6), x, y, rot=r), col))
    return out


def sauce():
    pts = [(-98, -6), (-90, -46), (-58, -82), (0, -96), (58, -82), (90, -46), (98, -6), (86, 8), (74, 4), (66, 40), (54, 6),
           (30, 10), (16, 52), (2, 14), (-24, 12), (-36, 34), (-50, 8), (-72, 10), (-82, 30), (-90, 6)]
    return [S(smooth_closed(pts, 0.7), 'c', 'c.o'), S(smooth_closed([(-62, -52), (-36, -76), (-8, -80), (-28, -62)], 0.8), '#FFFFFF', o=0.5),
            S(circle(66, 34, 4), '#FFFFFF', o=0.5)]


def all_sprites():
    sp = {'plate': plate(), 'liner': liner(), 'cupcake_top': cupcake_top(), 'scoop': scoop(),
          'scoop_chips': scoop_chips('#5A3426'), 'scoop_bits': scoop_chips('#3A3036'), 'sauce': sauce()}
    for i in range(3):
        sp[f'cake_body{i}'] = cake_body(i)
        sp[f'cake_frost{i}'] = cake_frost(i)
    for name, fn in FROST_STYLES.items():
        for st in (1, 2, 3):
            sp[f'frost_{name}{st}'] = fn(st)
    for name, fn in CONES.items():
        sp[f'cone_{name}'] = fn()
    return sp


def meta():
    return {'tiers': [tier_geom(i) for i in range(3)], 'scoopY0': SCOOP_Y0, 'scoopDY': SCOOP_DY}
