"""Tiny SVG helpers for Glimmie coloring pages.

Every page is drawn on a 1024x768 canvas, back to front. Shapes are filled white so that
whatever is in front hides the lines behind it, the way a real coloring book is drawn.
tools/make_coloring.py turns the black lines into the alpha of a transparent PNG.
"""
import math

W, H = 1024, 768
LINE = 7     # main outline
THIN = 4.5   # inner details


def P(d, fill="white", w=LINE, extra=""):
    return f'<path d="{d}" fill="{fill}" stroke="black" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round" {extra}/>'


def L(d, w=THIN):
    """An open detail line (no fill)."""
    return P(d, fill="none", w=w)


def C(x, y, r, fill="white", w=LINE):
    return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{fill}" stroke="black" stroke-width="{w}"/>'


def E(x, y, rx, ry, fill="white", w=LINE, rot=0):
    t = f' transform="rotate({rot} {x:.1f} {y:.1f})"' if rot else ""
    return f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}" stroke="black" stroke-width="{w}"{t}/>'


def R(x, y, w, h, r=0, fill="white", sw=LINE, rot=0):
    t = f' transform="rotate({rot} {x + w / 2:.1f} {y + h / 2:.1f})"' if rot else ""
    return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r:.1f}" fill="{fill}" stroke="black" stroke-width="{sw}" stroke-linejoin="round"{t}/>'


def G(body, x=0, y=0, s=1, rot=0, flip=False):
    sx = -s if flip else s
    return f'<g transform="translate({x:.1f} {y:.1f}) rotate({rot}) scale({sx} {s})">{body}</g>'


def poly(pts, close=True):
    d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts)
    return d + (" Z" if close else "")


# ---------- cute bits ----------

def eyes(x, y, gap=22, s=1.0, look=(0, 0)):
    out = ""
    for dx in (-gap, gap):
        ex, ey = x + dx, y
        out += E(ex, ey, 7.5 * s, 10 * s, fill="black", w=2)
        out += C(ex - 2.5 * s + look[0], ey - 3.5 * s + look[1], 3.2 * s, fill="white", w=0)
    return out


def happy_eyes(x, y, gap=22, s=1.0):
    out = ""
    for dx in (-gap, gap):
        out += L(f"M{x + dx - 9 * s} {y + 3 * s} Q{x + dx} {y - 9 * s} {x + dx + 9 * s} {y + 3 * s}", w=5)
    return out


def smile(x, y, s=1.0, open_=False):
    if open_:
        return P(f"M{x - 11 * s} {y} Q{x} {y + 2 * s} {x + 11 * s} {y} Q{x + 8 * s} {y + 15 * s} {x} {y + 15 * s} Q{x - 8 * s} {y + 15 * s} {x - 11 * s} {y} Z", w=4)
    return L(f"M{x - 9 * s} {y} Q{x} {y + 9 * s} {x + 9 * s} {y}", w=4.5)


def cat_mouth(x, y, s=1.0):
    return L(f"M{x - 10 * s} {y} Q{x - 5 * s} {y + 7 * s} {x} {y} Q{x + 5 * s} {y + 7 * s} {x + 10 * s} {y}", w=4)


def blush(x, y, gap=40, s=1.0):
    return E(x - gap, y, 9 * s, 5.5 * s, w=3) + E(x + gap, y, 9 * s, 5.5 * s, w=3)


def face(x, y, s=1.0, gap=22, mouth="smile", cheeks=True, happy=False):
    out = happy_eyes(x, y, gap * s, s) if happy else eyes(x, y, gap * s, s)
    my = y + 18 * s
    if mouth == "smile":
        out += smile(x, my, s)
    elif mouth == "open":
        out += smile(x, my - 2 * s, s, open_=True)
    elif mouth == "cat":
        out += cat_mouth(x, my - 2 * s, s)
    if cheeks:
        out += blush(x, y + 12 * s, (gap + 16) * s, s)
    return out


def star_d(x, y, r, inner=0.48, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        rr = r if i % 2 == 0 else r * inner
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    # soften the points a little with rounded joins (stroke does that)
    return poly(pts)


def star(x, y, r, w=LINE, rot=-90):
    return P(star_d(x, y, r, rot=rot), w=w)


def heart_d(x, y, s):
    # centred heart, about 2s wide
    return (f"M{x} {y + 0.9 * s} C{x - 0.2 * s} {y + 0.7 * s} {x - 1.05 * s} {y + 0.15 * s} {x - 1.05 * s} {y - 0.35 * s} "
            f"C{x - 1.05 * s} {y - 0.95 * s} {x - 0.25 * s} {y - 1.05 * s} {x} {y - 0.5 * s} "
            f"C{x + 0.25 * s} {y - 1.05 * s} {x + 1.05 * s} {y - 0.95 * s} {x + 1.05 * s} {y - 0.35 * s} "
            f"C{x + 1.05 * s} {y + 0.15 * s} {x + 0.2 * s} {y + 0.7 * s} {x} {y + 0.9 * s} Z")


def heart(x, y, s, w=LINE):
    return P(heart_d(x, y, s), w=w)


def sparkle(x, y, r, w=THIN):
    k = r * 0.22
    d = (f"M{x} {y - r} Q{x + k} {y - k} {x + r} {y} Q{x + k} {y + k} {x} {y + r} "
         f"Q{x - k} {y + k} {x - r} {y} Q{x - k} {y - k} {x} {y - r} Z")
    return P(d, w=w)


def cloud_d(x, y, s):
    return (f"M{x - 60 * s} {y + 20 * s} C{x - 95 * s} {y + 20 * s} {x - 95 * s} {y - 22 * s} {x - 60 * s} {y - 20 * s} "
            f"C{x - 55 * s} {y - 55 * s} {x - 10 * s} {y - 60 * s} {x} {y - 32 * s} "
            f"C{x + 15 * s} {y - 62 * s} {x + 62 * s} {y - 50 * s} {x + 58 * s} {y - 16 * s} "
            f"C{x + 95 * s} {y - 18 * s} {x + 95 * s} {y + 22 * s} {x + 60 * s} {y + 20 * s} Z")


def cloud(x, y, s=1.0, w=LINE):
    return P(cloud_d(x, y, s), w=w)


def sun(x, y, r=46):
    out = ""
    for i in range(10):
        a = math.radians(i * 36)
        x1, y1 = x + math.cos(a) * (r + 12), y + math.sin(a) * (r + 12)
        a2, a3 = math.radians(i * 36 - 9), math.radians(i * 36 + 9)
        tip = (x + math.cos(a) * (r + 34), y + math.sin(a) * (r + 34))
        b1 = (x + math.cos(a2) * (r + 10), y + math.sin(a2) * (r + 10))
        b2 = (x + math.cos(a3) * (r + 10), y + math.sin(a3) * (r + 10))
        out += P(poly([b1, tip, b2]), w=5)
    out += C(x, y, r)
    out += face(x, y + 2, 0.7, gap=17)
    return out


def flower(x, y, s=1.0, petals=5, stem=0, leaf=True):
    out = ""
    if stem:
        out += P(f"M{x - 4 * s} {y} Q{x - 8 * s} {y + stem / 2} {x - 4 * s} {y + stem} L{x + 4 * s} {y + stem} Q{x} {y + stem / 2} {x + 4 * s} {y} Z", w=5)
        if leaf:
            ly = y + stem * 0.6
            out += P(f"M{x} {ly} Q{x + 28 * s} {ly - 26 * s} {x + 46 * s} {ly - 14 * s} Q{x + 26 * s} {ly + 10 * s} {x} {ly} Z", w=5)
    for i in range(petals):
        a = math.radians(i * 360 / petals - 90)
        out += E(x + math.cos(a) * 17 * s, y + math.sin(a) * 17 * s, 14 * s, 10 * s, rot=math.degrees(a), w=5)
    out += C(x, y, 11 * s, w=5)
    return out


def tulip(x, y, s=1.0, stem=60):
    out = P(f"M{x - 3 * s} {y} L{x - 3 * s} {y + stem} L{x + 3 * s} {y + stem} L{x + 3 * s} {y} Z", w=5)
    out += P(f"M{x} {y + stem * 0.7} Q{x - 30 * s} {y + stem * 0.45} {x - 30 * s} {y + stem * 0.2} Q{x - 10 * s} {y + stem * 0.4} {x} {y + stem * 0.7} Z", w=5)
    out += P(f"M{x - 20 * s} {y - 30 * s} L{x - 20 * s} {y - 2 * s} Q{x} {y + 14 * s} {x + 20 * s} {y - 2 * s} L{x + 20 * s} {y - 30 * s} L{x + 10 * s} {y - 18 * s} L{x} {y - 34 * s} L{x - 10 * s} {y - 18 * s} Z", w=5)
    return out


def grass(x, y, s=1.0):
    return P(f"M{x - 16 * s} {y} Q{x - 14 * s} {y - 14 * s} {x - 22 * s} {y - 26 * s} Q{x - 6 * s} {y - 18 * s} {x - 4 * s} {y - 6 * s} "
             f"Q{x - 2 * s} {y - 24 * s} {x + 2 * s} {y - 34 * s} Q{x + 8 * s} {y - 20 * s} {x + 6 * s} {y - 6 * s} "
             f"Q{x + 12 * s} {y - 18 * s} {x + 24 * s} {y - 24 * s} Q{x + 16 * s} {y - 12 * s} {x + 16 * s} {y} Z", w=4.5)


def hills(y=600, amp=30, w=LINE):
    """A wavy ground line across the whole page; everything below it is one region."""
    return P(f"M-20 {y} C200 {y - amp} 330 {y + amp} 520 {y} C700 {y - amp} 840 {y + amp} 1044 {y - 10} L1044 790 L-20 790 Z", w=w)


def waves(y, amp=14, n=8, w=THIN):
    seg = W / n
    d = f"M-10 {y}"
    for i in range(n):
        x0 = i * seg
        d += f" Q{x0 + seg / 4} {y - amp} {x0 + seg / 2} {y} Q{x0 + 3 * seg / 4} {y + amp} {x0 + seg} {y}"
    d += " L1034 790 L-10 790 Z"
    return P(d, w=w)


def bubble(x, y, r):
    return C(x, y, r, w=4) + L(f"M{x - r * 0.55} {y - r * 0.1} Q{x - r * 0.5} {y - r * 0.5} {x - r * 0.1} {y - r * 0.6}", w=3)


def dots_ring(x, y, r, n, dot=5):
    return "".join(C(x + math.cos(2 * math.pi * i / n) * r, y + math.sin(2 * math.pi * i / n) * r, dot, w=3.5) for i in range(n))


# ---------- a chibi girl ----------

def girl(x, y, s=1.0, hair="long", dress="gown", happy=False, arms="down", crown=False, legs=True):
    """Chibi girl standing with her feet near (x, y + 300s). Head centre at (x, y)."""
    def T(d):
        return d
    o = ""
    k = s
    # long hair behind
    if hair == "long":
        o += P(f"M{x - 92 * k} {y - 10 * k} C{x - 110 * k} {y + 110 * k} {x - 100 * k} {y + 170 * k} {x - 60 * k} {y + 190 * k} "
               f"L{x + 60 * k} {y + 190 * k} C{x + 100 * k} {y + 170 * k} {x + 110 * k} {y + 110 * k} {x + 92 * k} {y - 10 * k} Z")
    elif hair == "pigtails":
        o += P(f"M{x - 80 * k} {y - 10 * k} C{x - 150 * k} {y + 10 * k} {x - 160 * k} {y + 110 * k} {x - 130 * k} {y + 140 * k} C{x - 120 * k} {y + 80 * k} {x - 90 * k} {y + 50 * k} {x - 80 * k} {y + 30 * k} Z")
        o += P(f"M{x + 80 * k} {y - 10 * k} C{x + 150 * k} {y + 10 * k} {x + 160 * k} {y + 110 * k} {x + 130 * k} {y + 140 * k} C{x + 120 * k} {y + 80 * k} {x + 90 * k} {y + 50 * k} {x + 80 * k} {y + 30 * k} Z")
    elif hair == "bun":
        o += C(x, y - 92 * k, 38 * k)
    # legs
    if legs:
        o += R(x - 30 * k, y + 220 * k, 22 * k, 70 * k, 8 * k) + R(x + 8 * k, y + 220 * k, 22 * k, 70 * k, 8 * k)
        o += E(x - 26 * k, y + 292 * k, 24 * k, 13 * k) + E(x + 26 * k, y + 292 * k, 24 * k, 13 * k)
    # dress
    if dress == "gown":
        o += P(f"M{x - 40 * k} {y + 90 * k} L{x + 40 * k} {y + 90 * k} L{x + 46 * k} {y + 150 * k} C{x + 120 * k} {y + 200 * k} {x + 130 * k} {y + 260 * k} {x + 130 * k} {y + 290 * k} "
               f"Q{x} {y + 310 * k} {x - 130 * k} {y + 290 * k} C{x - 130 * k} {y + 260 * k} {x - 120 * k} {y + 200 * k} {x - 46 * k} {y + 150 * k} Z")
        o += L(f"M{x - 46 * k} {y + 150 * k} Q{x} {y + 164 * k} {x + 46 * k} {y + 150 * k}", w=4)
        o += L(f"M{x - 60 * k} {y + 200 * k} Q{x - 74 * k} {y + 250 * k} {x - 70 * k} {y + 296 * k}", w=4) + L(f"M{x + 60 * k} {y + 200 * k} Q{x + 74 * k} {y + 250 * k} {x + 70 * k} {y + 296 * k}", w=4)
    elif dress == "tutu":
        o += P(f"M{x - 38 * k} {y + 90 * k} L{x + 38 * k} {y + 90 * k} L{x + 36 * k} {y + 170 * k} L{x - 36 * k} {y + 170 * k} Z")
        d = f"M{x - 40 * k} {y + 160 * k}"
        for i in range(7):
            xa = x - 120 * k + i * 40 * k
            d += f" Q{xa + 20 * k} {y + 240 * k} {xa + 40 * k} {y + 220 * k}" if i else f" L{xa} {y + 212 * k} Q{xa + 20 * k} {y + 240 * k} {xa + 40 * k} {y + 220 * k}"
        d += f" L{x + 40 * k} {y + 160 * k} Z"
        o += P(d)
        o += L(f"M{x - 38 * k} {y + 170 * k} Q{x} {y + 180 * k} {x + 38 * k} {y + 170 * k}", w=4)
    elif dress == "tail":  # mermaid tail
        o += P(f"M{x - 40 * k} {y + 90 * k} L{x + 40 * k} {y + 90 * k} L{x + 38 * k} {y + 150 * k} L{x - 38 * k} {y + 150 * k} Z")
        o += P(f"M{x - 46 * k} {y + 150 * k} L{x + 46 * k} {y + 150 * k} C{x + 60 * k} {y + 220 * k} {x + 30 * k} {y + 270 * k} {x + 50 * k} {y + 300 * k} "
               f"C{x + 90 * k} {y + 300 * k} {x + 120 * k} {y + 330 * k} {x + 110 * k} {y + 360 * k} C{x + 60 * k} {y + 350 * k} {x + 30 * k} {y + 340 * k} {x} {y + 310 * k} "
               f"C{x - 30 * k} {y + 340 * k} {x - 60 * k} {y + 350 * k} {x - 110 * k} {y + 360 * k} C{x - 120 * k} {y + 330 * k} {x - 90 * k} {y + 300 * k} {x - 50 * k} {y + 300 * k} "
               f"C{x - 30 * k} {y + 270 * k} {x - 60 * k} {y + 220 * k} {x - 46 * k} {y + 150 * k} Z")
        for yy in (190, 230, 265):
            o += L(f"M{x - 40 * k} {y + yy * k} Q{x - 20 * k} {y + (yy + 16) * k} {x} {y + yy * k} Q{x + 20 * k} {y + (yy + 16) * k} {x + 40 * k} {y + yy * k}", w=3.5)
    # arms
    if arms == "down":
        o += P(f"M{x - 44 * k} {y + 100 * k} Q{x - 90 * k} {y + 150 * k} {x - 84 * k} {y + 190 * k} L{x - 66 * k} {y + 190 * k} Q{x - 64 * k} {y + 150 * k} {x - 34 * k} {y + 124 * k} Z")
        o += P(f"M{x + 44 * k} {y + 100 * k} Q{x + 90 * k} {y + 150 * k} {x + 84 * k} {y + 190 * k} L{x + 66 * k} {y + 190 * k} Q{x + 64 * k} {y + 150 * k} {x + 34 * k} {y + 124 * k} Z")
        o += C(x - 76 * k, y + 196 * k, 14 * k) + C(x + 76 * k, y + 196 * k, 14 * k)
    elif arms == "up":
        o += P(f"M{x - 40 * k} {y + 104 * k} Q{x - 90 * k} {y + 80 * k} {x - 120 * k} {y + 30 * k} L{x - 104 * k} {y + 20 * k} Q{x - 80 * k} {y + 60 * k} {x - 34 * k} {y + 80 * k} Z")
        o += P(f"M{x + 40 * k} {y + 104 * k} Q{x + 90 * k} {y + 80 * k} {x + 120 * k} {y + 30 * k} L{x + 104 * k} {y + 20 * k} Q{x + 80 * k} {y + 60 * k} {x + 34 * k} {y + 80 * k} Z")
        o += C(x - 116 * k, y + 18 * k, 14 * k) + C(x + 116 * k, y + 18 * k, 14 * k)
    # neck + head
    o += R(x - 12 * k, y + 70 * k, 24 * k, 26 * k, 4 * k, sw=5)
    o += C(x, y, 90 * k)
    o += face(x, y + 22 * k, 1.5 * k, gap=26, happy=happy)
    # bangs / top hair
    o += P(f"M{x - 98 * k} {y + 20 * k} C{x - 110 * k} {y - 90 * k} {x - 30 * k} {y - 112 * k} {x} {y - 110 * k} C{x + 40 * k} {y - 112 * k} {x + 110 * k} {y - 90 * k} {x + 98 * k} {y + 20 * k} "
           f"C{x + 80 * k} {y - 20 * k} {x + 60 * k} {y - 30 * k} {x + 40 * k} {y - 36 * k} Q{x + 30 * k} {y - 10 * k} {x + 10 * k} {y - 2 * k} Q{x + 6 * k} {y - 30 * k} {x - 6 * k} {y - 44 * k} "
           f"Q{x - 30 * k} {y - 10 * k} {x - 60 * k} {y} Q{x - 64 * k} {y - 20 * k} {x - 56 * k} {y - 34 * k} C{x - 80 * k} {y - 20 * k} {x - 90 * k} {y - 6 * k} {x - 98 * k} {y + 20 * k} Z")
    if hair == "pigtails":
        o += C(x - 84 * k, y - 20 * k, 14 * k) + C(x + 84 * k, y - 20 * k, 14 * k)
    if crown:
        o += P(f"M{x - 46 * k} {y - 96 * k} L{x - 54 * k} {y - 160 * k} L{x - 24 * k} {y - 126 * k} L{x} {y - 172 * k} L{x + 24 * k} {y - 126 * k} L{x + 54 * k} {y - 160 * k} L{x + 46 * k} {y - 96 * k} Q{x} {y - 106 * k} {x - 46 * k} {y - 96 * k} Z")
        o += C(x, y - 124 * k, 9 * k, w=4)
    return o
