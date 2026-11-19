"""Toppings: each is drawn centered on (0, 0), about 90 units across. 'c' = the topping's candy color."""
import math
from base import *

GREEN, GREEN_O = '#7DCB6E', '#4E8F45'


def leaf(cx, cy, rx, ry, rot, col=GREEN):
    return [S(ellipse(cx, cy, rx, ry, rot), col, O(col), 3),
            line([(cx - math.cos(math.radians(rot)) * rx * 0.7, cy - math.sin(math.radians(rot)) * rx * 0.7),
                  (cx + math.cos(math.radians(rot)) * rx * 0.7, cy + math.sin(math.radians(rot)) * rx * 0.7)], O(col), 2)]


def strawberry():
    red = '#FF5A70'
    body = smooth_closed([(0, 44), (-24, 26), (-36, 2), (-34, -18), (-18, -30), (0, -27), (18, -30), (34, -18), (36, 2), (24, 26)])
    out = [S(body, red, O(red)), S(smooth_closed([(-26, -14), (-12, -24), (-6, -6), (-20, 10)]), LT(red), o=0.55)]
    for x, y in [(-18, -6), (0, -10), (18, -6), (-10, 10), (10, 10), (0, 26), (-22, 12), (22, 12)]:
        out.append(S(ellipse(x, y, 2.6, 4), '#FFE79A'))
    cal = star(0, -30, 22, 0.42, 5, -90, 0.35)
    out += [S(cal, GREEN, GREEN_O, 3), S(rrect(-3, -50, 6, 18, 3), '#5DA84F', GREEN_O, 2.5)]
    return out


def cherry():
    red = '#E8384F'
    return [line([(4, -10), (8, -32), (22, -46)], '#5D8F3A', 5),
            *leaf(28, -40, 14, 7, -20),
            S(circle(0, 12, 28), red, O(red)),
            S(ellipse(-10, 0, 9, 6, -35), '#FFFFFF', o=0.75),
            S(circle(8, 24, 4), '#FFFFFF', o=0.4)]


def blueberry():
    b = '#5C7BD9'
    out = []
    for x, y, r in [(-16, 8, 20), (16, 8, 20), (0, -12, 20)]:
        out += [S(circle(x, y, r), b, O(b)), S(star(x, y - r * 0.55, r * 0.32, 0.45, 5), DP(b)),
                S(ellipse(x - r * 0.4, y - r * 0.05, r * 0.22, r * 0.14, -40), '#FFFFFF', o=0.7)]
    return out


def raspberry():
    r_ = '#EC4D78'
    out = [S(smooth_closed([(0, -34), (-30, -16), (-34, 14), (-16, 36), (16, 36), (34, 14), (30, -16)]), SH(r_), O(r_))]
    for row, (y, n, w) in enumerate([(-22, 3, 18), (-4, 4, 20), (14, 4, 19), (30, 3, 14)]):
        for i in range(n):
            x = (i - (n - 1) / 2) * w
            out += [S(circle(x, y, 10), r_, O(r_), 2.5), S(circle(x - 3, y - 3, 3), '#FFFFFF', o=0.6)]
    out += leaf(-8, -38, 10, 5, -30) + leaf(8, -38, 10, 5, 30)
    return out


def banana():
    y_, rim = '#FFF3B8', '#F2D36B'
    out = [S(circle(0, 0, 34), rim, O(rim)), S(circle(0, 0, 27), y_), S(circle(0, 0, 11), '#FFF9DC')]
    for i in range(6):
        a = math.radians(i * 60 + 30)
        out.append(S(ellipse(math.cos(a) * 9, math.sin(a) * 9, 2.5, 4, i * 60 + 30), '#B88A4A'))
    return out


def kiwi():
    out = [S(circle(0, 0, 36), '#A4794C', '#6E4E32'), S(circle(0, 0, 30), '#8ACB52'),
           S(circle(0, 0, 21), '#A6DA6E'), S(circle(0, 0, 10), '#F3F7D6')]
    for i in range(12):
        a = math.radians(i * 30)
        out.append(S(ellipse(math.cos(a) * 16, math.sin(a) * 16, 4, 2, i * 30), '#2E2A26'))
    return out


def orange():
    o_ = '#FF9F3D'
    out = [S(circle(0, 0, 36), o_, O(o_)), S(circle(0, 0, 30), '#FFF4E0')]
    for i in range(8):
        a0 = i * 45 + 4; a1 = a0 + 37
        pts = [(0, 0)] + arc_pts(0, 0, 27, 27, a0, a1, 4)
        out.append(S(smooth_closed(pts, 0.3), '#FFB860'))
    out.append(S(circle(0, 0, 3), '#FFF4E0'))
    return out


def grapes():
    p = '#9B6BD6'
    out = [line([(0, -30), (6, -44)], '#7A5A3A', 5)] + leaf(16, -40, 14, 8, -25)
    for x, y in [(-20, -18), (0, -20), (20, -18), (-10, 0), (10, 0), (-20, 16) , (20, 16), (0, 18), (-8, 34), (8, 34)]:
        out += [S(circle(x, y, 12), p, O(p), 3), S(circle(x - 4, y - 4, 3.5), '#FFFFFF', o=0.6)]
    return out


def heart_candy():
    return [S(heart(0, 2, 40), 'c', 'c.o'), S(heart(0, 2, 28), 'c.l', o=0.35),
            S(ellipse(-16, -12, 9, 6, -40), '#FFFFFF', o=0.8)]


def star_candy():
    return [S(star(0, 4, 44, 0.52, 5, -90, 0.35), 'c', 'c.o'), S(star(0, 4, 26, 0.52, 5, -90, 0.35), 'c.l', o=0.4),
            S(ellipse(-12, -10, 7, 5, -40), '#FFFFFF', o=0.8)]


def gumdrop():
    d = smooth_closed([(0, -36), (-24, -26), (-36, 6), (-38, 30), (0, 36), (38, 30), (36, 6), (24, -26)])
    out = [S(d, 'c', 'c.o'), S(smooth_closed([(-22, -18), (-8, -28), (-6, -12), (-20, 4)]), '#FFFFFF', o=0.45)]
    for x, y in [(-18, 14), (2, -6), (16, 18), (-4, 24), (20, -6), (-24, -4), (6, 8)]:
        out.append(S(rrect(x - 2.5, y - 2.5, 5, 5, 1.5), '#FFFFFF', o=0.85))
    return out


def gummy_bear():
    parts = [circle(-16, -30, 9), circle(16, -30, 9), ellipse(-24, 34, 11, 9), ellipse(24, 34, 11, 9),
             ellipse(-26, 4, 9, 13, 25), ellipse(26, 4, 9, 13, -25), ellipse(0, 14, 24, 26), circle(0, -18, 21)]
    out = [S(p, 'c', 'c.o', 4) for p in parts]
    out += [S(ellipse(0, 16, 12, 14), 'c.l', o=0.45), S(ellipse(-8, -26, 6, 4, -30), '#FFFFFF', o=0.8),
            S(circle(-7, -18, 2.6), 'c.d'), S(circle(7, -18, 2.6), 'c.d'), S(ellipse(0, -11, 4, 3), 'c.d')]
    return out


def macaron():
    out = [S(rrect(-38, 4, 76, 26, 13), 'c', 'c.o'), S(rrect(-38, 2, 76, 6, 3), 'c.s'),
           S(rrect(-40, -6, 80, 14, 7), '#FFF8EE', '#E5CDBA', 3),
           S(rrect(-38, -32, 76, 28, 14), 'c', 'c.o'), S(rrect(-38, -10, 76, 6, 3), 'c.s'),
           S(ellipse(-16, -22, 12, 4, -6), '#FFFFFF', o=0.6)]
    return out


def candle():
    out = [S(rrect(-11, -22, 22, 66, 6), 'c', 'c.o')]
    for y in (-12, 6, 24):
        out.append(S(poly([(-11, y), (11, y - 10), (11, y - 2), (-11, y + 8)]), 'c.l', o=0.8))
    out += [line([(0, -22), (0, -30)], '#5B3A3A', 3),
            S(smooth_closed([(0, -60), (-11, -40), (-8, -30), (0, -27), (8, -30), (11, -40)], 0.9), '#FFC94A', '#F08A3A', 2.5),
            S(smooth_closed([(0, -48), (-5, -38), (0, -31), (5, -38)], 0.9), '#FFF6C8')]
    return out


def lollipop():
    out = [S(rrect(-4, 0, 8, 46, 4), '#FFFFFF', '#D8C8D0', 3), S(circle(0, -14, 30), 'c', 'c.o')]
    pts = [(math.cos(t * 0.5) * t * 1.0, -14 + math.sin(t * 0.5) * t * 1.0) for t in range(2, 28)]
    out += [line(pts, '#FFFFFF', 6), S(ellipse(-12, -26, 7, 5, -40), '#FFFFFF', o=0.7)]
    return out


def candy_cane():
    pts = [(10, 44), (10, 0), (10, -20), (4, -38), (-12, -44), (-26, -34), (-28, -20)]
    out = [line(pts, '#D8AEB8', 20), line(pts, '#FFFFFF', 14)]
    # sample the cane evenly, then lay short tilted red bands across it
    dense = []
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        for k in range(20):
            t = k / 20
            dense.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    acc, last, marks = 0.0, dense[0], []
    for p in dense[1:]:
        acc += math.hypot(p[0] - last[0], p[1] - last[1]); last = p
        if acc >= 13:
            acc = 0; marks.append(p)
    for i, p in enumerate(marks[:-1]):
        q = marks[i + 1]
        tx, ty = q[0] - p[0], q[1] - p[1]; L = math.hypot(tx, ty) or 1; tx, ty = tx / L, ty / L
        nx, ny = -ty, tx
        quad = [(p[0] + nx * 7 - tx * 2, p[1] + ny * 7 - ty * 2), (p[0] + nx * 7 + tx * 3, p[1] + ny * 7 + ty * 3),
                (p[0] - nx * 7 + tx * 7, p[1] - ny * 7 + ty * 7), (p[0] - nx * 7 + tx * 2, p[1] - ny * 7 + ty * 2)]
        out.append(S(poly(quad), '#F0475E'))
    return out


def donut():
    d = '#E9B07A'
    ring = circle(0, 0, 38) + ' ' + circle(0, 0, 13)
    icing = smooth_closed([(0, -33), (-20, -28), (-33, -14), (-31, 6), (-34, 18), (-20, 28), (-4, 30), (14, 32), (28, 20), (33, 4), (31, -14), (20, -28)])
    out = [S(ring, d, O(d), eo=1), S(icing + ' ' + circle(0, 0, 16), 'c', 'c.o', 3, eo=1),
           S(ellipse(-16, -18, 9, 5, -40), '#FFFFFF', o=0.6)]
    cols = ['#FFFFFF', '#FFE27A', '#7EC2F2', '#FF7AAE', '#9FE3CF']
    for i, (x, y, r) in enumerate([(-22, -6, 30), (-8, -24, 80), (18, -18, 140), (24, 8, 20), (6, 24, 100), (-18, 18, 60), (-26, 4, 120)]):
        out.append(S(tf(rrect(-6, -2, 12, 4, 2), x, y, rot=r), cols[i % len(cols)]))
    return out


def marshmallow():
    return [S(rrect(-30, -24, 60, 52, 18), 'c', 'c.o'), S(ellipse(0, -18, 28, 11), 'c.l'),
            S(ellipse(-10, -20, 8, 3), '#FFFFFF', o=0.8)]


def cream():
    out = []
    for cy, R, r, n in [(18, 24, 15, 9), (0, 15, 12, 7)]:
        for i in range(n):
            a = math.radians(i * 360 / n - 90)
            out.append(S(ellipse(math.cos(a) * R, cy + math.sin(a) * R * 0.55, r, r * 0.8), 'c', 'c.o', 3.5))
        out.append(S(ellipse(0, cy, R, R * 0.5), 'c'))
    out += [S(smooth_closed([(0, -30), (-13, -12), (0, -4), (13, -12)], 0.8), 'c', 'c.o', 3.5),
            S(ellipse(-6, -14, 4, 6, 20), '#FFFFFF', o=0.75), S(ellipse(-16, 8, 7, 4, -20), '#FFFFFF', o=0.6)]
    return out


def choc_chip():
    c = '#6E4330'
    return [S(smooth_closed([(0, -30), (-24, 10), (-20, 24), (0, 28), (20, 24), (24, 10)], 0.8), c, O(c)),
            S(ellipse(-8, 4, 5, 9, 20), '#FFFFFF', o=0.3)]


def cookie():
    t = '#E3A960'
    out = [S(smooth_closed([(0, -36), (-26, -26), (-37, -2), (-30, 24), (-6, 37), (20, 32), (36, 12), (34, -16), (18, -32)]), t, O(t)),
           S(ellipse(-8, -10, 20, 12, -20), LT(t), o=0.4)]
    for x, y in [(-14, -14), (12, -18), (-18, 12), (8, 6), (18, 22), (-2, 24)]:
        out.append(S(smooth_closed([(x, y - 6), (x - 6, y + 3), (x + 2, y + 6), (x + 7, y + 1)]), '#6E4330'))
    return out


def wafer():
    t = '#F2C98A'
    out = [S(tf(rrect(-10, -46, 20, 92, 6), rot=18), t, O(t))]
    for k in range(-3, 4):
        out.append(S(tf(rrect(-10, k * 12 - 1.5, 20, 3, 1.5), rot=18), SH(t)))
    return out


def chocolate():
    c = '#7A4A36'
    out = [S(rrect(-34, -28, 68, 56, 8), c, O(c))]
    for x in (-30, 1):
        for y in (-24, 1):
            out += [S(rrect(x, y, 29, 23, 5), MX(c, '#FFFFFF', 0.12))]
    out.append(S(ellipse(-18, -18, 8, 3, -20), '#FFFFFF', o=0.4))
    return out


def flower_top():
    return [S(flower(0, 0, 40, 5), 'c', 'c.o', 3.5), S(circle(0, 0, 12), '#FFD45E', '#D69A2A', 3),
            S(circle(-3, -3, 4), '#FFFFFF', o=0.7)]


def mint():
    return leaf(-14, 4, 26, 13, -30, '#5FC77E') + leaf(14, 4, 26, 13, 30, '#79D894')


def pearl():
    return [S(circle(0, 0, 20), 'c', 'c.o', 3.5), S(ellipse(-7, -7, 6, 4, -40), '#FFFFFF', o=0.85)]


def unicorn_horn():
    out = [S(smooth_closed([(0, -50), (-18, 34), (0, 42), (18, 34)], 0.25), '#FFE9A8', '#D6A84A')]
    for y, w in [(18, 16), (0, 12), (-18, 8)]:
        out.append(line([(-w, y + 6), (w, y - 6)], '#F2C15A', 4))
    out += [S(ellipse(0, 40, 22, 8), '#FFB3CC', '#E07AA0', 3)]
    return out


def crown():
    g = '#FFD45E'
    out = [S(poly([(-40, 24), (-44, -22), (-22, 0), (0, -32), (22, 0), (44, -22), (40, 24)]), g, '#C08A2A'),
           S(rrect(-42, 16, 84, 16, 6), '#F2B83E', '#C08A2A', 3.5),
           S(circle(0, 4, 8), 'c', 'c.o', 3), S(circle(-24, 12, 5), 'c', 'c.o', 2.5), S(circle(24, 12, 5), 'c', 'c.o', 2.5)]
    for x, y in [(-44, -24), (0, -34), (44, -24)]:
        out.append(S(circle(x, y, 6), '#FFF3B0', '#C08A2A', 2.5))
    return out


def butterfly():
    out = []
    for sx in (-1, 1):
        out += [S(ellipse(sx * 22, -12, 22, 18, sx * 25), 'c', 'c.o', 3.5),
                S(ellipse(sx * 18, 16, 15, 12, -sx * 20), 'c', 'c.o', 3.5),
                S(circle(sx * 24, -14, 7), 'c.l'), S(circle(sx * 17, 16, 4), 'c.l')]
    out += [S(ellipse(0, 2, 6, 24), '#6A4A5A', '#4A2C40', 2),
            line([(-2, -20), (-10, -36)], '#6A4A5A', 3), line([(2, -20), (10, -36)], '#6A4A5A', 3)]
    return out


def rainbow():
    out = []
    for r, c in [(40, '#FF8AA8'), (32, '#FFC46B'), (24, '#FFE98A'), (16, '#9FE3B8'), (8, '#9CCBFF')]:
        out.append(line(arc_pts(0, 14, r, r, 180, 360, 16), c, 9))
    for x in (-40, 40):
        out.append(S(flower(x, 16, 18, 5, -90), '#FFFFFF', '#D8C8E0', 3))
    return out


def cloud():
    d = smooth_closed([(-40, 14), (-42, -4), (-26, -16), (-14, -30), (8, -32), (22, -18), (38, -16), (44, 2), (36, 18), (0, 22)])
    return [S(d, '#FFFFFF', '#C9C2E0'), S(ellipse(-10, -10, 16, 8, -10), '#F2F0FF', o=0.9),
            S(circle(-12, 4, 3), '#5B3A68'), S(circle(12, 4, 3), '#5B3A68'),
            S(ellipse(-22, 10, 6, 3.5), '#FFB3CC', o=0.8), S(ellipse(22, 10, 6, 3.5), '#FFB3CC', o=0.8),
            line([(-5, 10), (0, 13), (5, 10)], '#5B3A68', 2.5)]


def sparkle():
    def tw(cx, cy, R):
        k = R * 0.22
        return (f"M{f(cx)} {f(cy - R)} C{f(cx + k)} {f(cy - k)} {f(cx + k)} {f(cy - k)} {f(cx + R)} {f(cy)} "
                f"C{f(cx + k)} {f(cy + k)} {f(cx + k)} {f(cy + k)} {f(cx)} {f(cy + R)} "
                f"C{f(cx - k)} {f(cy + k)} {f(cx - k)} {f(cy + k)} {f(cx - R)} {f(cy)} "
                f"C{f(cx - k)} {f(cy - k)} {f(cx - k)} {f(cy - k)} {f(cx)} {f(cy - R)} Z")
    return [S(tw(0, 0, 42), '#FFE27A', '#E0A63A', 3.5), S(tw(0, 0, 18), '#FFF8D6'), S(tw(30, -28, 12), '#FFE27A', '#E0A63A', 2.5)]


def bow():
    out = [S(smooth_closed([(0, 0), (-20, -22), (-42, -18), (-44, 10), (-24, 18)], 0.6), 'c', 'c.o', 4),
           S(smooth_closed([(0, 0), (20, -22), (42, -18), (44, 10), (24, 18)], 0.6), 'c', 'c.o', 4),
           S(smooth_closed([(-6, 6), (-20, 36), (-8, 40), (2, 10)], 0.4), 'c', 'c.o', 3.5),
           S(smooth_closed([(6, 6), (20, 36), (8, 40), (-2, 10)], 0.4), 'c', 'c.o', 3.5),
           S(ellipse(0, 0, 11, 12), 'c', 'c.o', 4),
           S(ellipse(-26, -8, 8, 5, -20), 'c.l', o=0.8), S(ellipse(26, -8, 8, 5, 20), 'c.l', o=0.8)]
    return out


def gummy_worm():
    pts = [(-40, 10), (-26, -12), (-6, 6), (12, -14), (30, 2), (42, -10)]
    return [line(pts, '#C8507A', 20), line(pts, '#FF7AA2', 15),
            line([(x, y + 3) for x, y in pts[:3]], '#8EDB8A', 9),
            line([(x, y + 3) for x, y in pts[3:]], '#FFE27A', 9),
            S(circle(42, -10, 3), '#4A2C40')]


def pretzel():
    t = '#B8743A'
    p = [(0, 30), (-24, 6), (-30, -16), (-16, -30), (0, -14), (16, -30), (30, -16), (24, 6), (0, 30)]
    out = [line(p, O(t), 17), line(p, t, 12), line([(-14, 20), (14, -6)], t, 12), line([(14, 20), (-14, -6)], t, 12)]
    for x, y in [(-22, -20), (20, -22), (-8, 16), (12, 10), (-26, 0), (26, 2)]:
        out.append(S(rrect(x - 3, y - 1.5, 6, 3, 1.5), '#FFFFFF'))
    return out


def mochi():
    return [S(smooth_closed([(0, -26), (-30, -16), (-38, 10), (-20, 28), (20, 28), (38, 10), (30, -16)]), 'c', 'c.o'),
            S(ellipse(-12, -12, 10, 6, -20), '#FFFFFF', o=0.6),
            S(circle(-11, 6, 3), '#5B3A68'), S(circle(11, 6, 3), '#5B3A68'),
            line([(-5, 12), (0, 15), (5, 12)], '#5B3A68', 2.5),
            S(ellipse(-20, 14, 5, 3), '#FF8FB8', o=0.6), S(ellipse(20, 14, 5, 3), '#FF8FB8', o=0.6)]


def heart_choc():
    c = '#7A4A36'
    return [S(heart(0, 2, 38), c, O(c)), S(heart(0, 2, 30), MX(c, '#FFFFFF', 0.12)),
            S(smooth_open([(-18, -4), (-8, 6), (2, -4), (12, 6), (20, -4)]), None, '#FFFFFF', 3)]


def cherry_pair():
    return tshapes(cherry(), dx=-12, s=0.8) + tshapes(cherry(), dx=14, dy=4, s=0.8)


# Scatter bits (drawn tiny and rotated by the app)
def sprinkle():
    return [S(rrect(-10, -3.5, 20, 7, 3.5), 'c', 'c.o', 1.5)]

def nonpareil():
    return [S(circle(0, 0, 5), 'c', 'c.o', 1.2)]

def confetti_heart():
    return [S(heart(0, 1, 9), 'c', 'c.o', 1.5)]

def confetti_star():
    return [S(star(0, 1, 10, 0.5, 5, -90, 0.3), 'c', 'c.o', 1.5)]

def choc_curl():
    return [line([(-10, 0), (-4, -5), (4, 4), (10, 0)], '#6E4330', 5)]


TOPPINGS = {
    # fruit
    'strawberry': (strawberry, False), 'cherry': (cherry, False), 'cherries': (cherry_pair, False),
    'blueberry': (blueberry, False), 'raspberry': (raspberry, False), 'banana': (banana, False),
    'kiwi': (kiwi, False), 'orange': (orange, False), 'grapes': (grapes, False), 'mint': (mint, False),
    # candy
    'heart': (heart_candy, True), 'star': (star_candy, True), 'gumdrop': (gumdrop, True), 'gummy': (gummy_bear, True),
    'lollipop': (lollipop, True), 'cane': (candy_cane, False), 'worm': (gummy_worm, False), 'pearl': (pearl, True),
    # bakery sweets
    'macaron': (macaron, True), 'donut': (donut, True), 'marshmallow': (marshmallow, True), 'cream': (cream, True),
    'cookie': (cookie, False), 'wafer': (wafer, False), 'chocolate': (chocolate, False), 'chocheart': (heart_choc, False),
    'chip': (choc_chip, False), 'mochi': (mochi, True),
    # party
    'candle': (candle, True), 'crown': (crown, True), 'horn': (unicorn_horn, False), 'butterfly': (butterfly, True),
    'flower': (flower_top, True), 'bow': (bow, True), 'rainbow': (rainbow, False), 'cloud': (cloud, False),
    'sparkle': (sparkle, False),
}

BITS = {'sprinkle': sprinkle, 'nonpareil': nonpareil, 'confheart': confetti_heart, 'confstar': confetti_star, 'curl': choc_curl}
