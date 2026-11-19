"""Problem stickers (mud, thorns, bugs...), the vet tools, and the two rooms.
Props are drawn around (0, 0) at about 100 x 100. Tools are drawn in a 140 x 140 box; each has a
'tip', the point that touches the patient."""
import math
from geom import ellipse, circle, smooth_closed, smooth_open, sym, poly, heart, star, rrect
from base import (S, blob, flat, line, tube, mirror, move, arc, shine, scallop, wobble_circle,
                  shade, light, deep, outline, mixh, rot_pts)
from animals import rotate_path


def rot(shapes, deg, cx=0, cy=0):
    return [dict(s, d=rotate_path(s['d'], cx, cy, deg)) for s in shapes]


# ---------------------------------------------------------------- problems

def mud():
    c = '#A0704C'
    d = smooth_closed([(-40, -18), (-22, -38), (6, -34), (30, -40), (44, -14), (38, 10), (46, 30), (20, 38),
                       (4, 30), (-16, 42), (-36, 30), (-46, 6)], 1.0)
    return [blob(d, c, 4), flat(circle(30, 46, 7), c), flat(circle(-44, -32, 6), c),
            flat(ellipse(-10, 4, 14, 9), shade(c), 0.9), flat(circle(18, -8, 6), shade(c), 0.9),
            flat(ellipse(-18, -20, 12, 6, -20), light(c), 0.7)]


def bubbles():
    out = []
    for x, y, r in [(-22, 4, 22), (8, -16, 18), (22, 14, 20), (-4, 26, 14), (-30, -22, 11), (34, -14, 9)]:
        out += [S(circle(x, y, r), '#F4FBFF', '#9CCBFF', 3, 0.92), flat(ellipse(x - r * 0.35, y - r * 0.4, r * 0.3, r * 0.18, -30), '#FFFFFF')]
    return out


def thorn():
    c = '#8BAE5A'
    spike = smooth_closed([(-9, 8), (-2, -46), (4, -48), (9, 8)], 0.4)
    leaf = smooth_closed([(4, -22), (24, -36), (36, -30), (22, -18)], 1.0)
    return [flat(ellipse(0, 10, 22, 12), '#FF8FA8', 0.55), blob(spike, c, 4), blob(leaf, '#7CCB6A', 3.5),
            flat(ellipse(-2, -18, 2.5, 12), light(c), 0.8)]


def scrape():
    base = '#FF8F9E'
    return [flat(wobble_circle(0, 0, 34, 9, 0.12, 4), base, 0.85),
            line(smooth_open([(-22, -10), (-6, -16), (14, -24)]), '#E0485E', 6),
            line(smooth_open([(-22, 4), (0, -2), (22, -10)]), '#E0485E', 6),
            line(smooth_open([(-16, 18), (4, 12), (22, 6)]), '#E0485E', 6)]


def scrape_clean():
    return [flat(wobble_circle(0, 0, 28, 9, 0.1, 4), '#FFB3C2', 0.7)]


def bandage(col='#FFD3B0'):
    strip = rrect(-52, -17, 104, 34, 16)
    pad = rrect(-18, -13, 36, 26, 6)
    out = [blob(strip, col, 4), flat(pad, '#FFF1E6')]
    for x in (-38, -30, 30, 38):
        for y in (-6, 6):
            out.append(flat(circle(x, y, 2.4), shade(col)))
    out.append(flat(heart(0, 0, 8), '#FF6F96'))
    return rot(out, -20)


def bug(c='#B48CF0'):
    out = [line(smooth_open([(-8, -14), (-14, -30), (-20, -32)]), outline(c), 3.5),
           line(smooth_open([(8, -14), (14, -30), (20, -32)]), outline(c), 3.5),
           flat(circle(-20, -32, 4), outline(c)), flat(circle(20, -32, 4), outline(c))]
    for s in (-1, 1):
        for k, y in enumerate((0, 10, 20)):
            out.append(line(smooth_open([(s * 14, y), (s * 26, y + 4 + k * 2)]), outline(c), 3.5))
    out += [blob(ellipse(0, 10, 18, 20), c, 4), blob(circle(0, -10, 13), c, 4),
            line(smooth_open([(0, -2), (0, 28)]), outline(c), 3),
            flat(circle(-8, 8, 4), light(c)), flat(circle(8, 18, 3.5), light(c)),
            flat(circle(-5, -12, 3), '#3A2633'), flat(circle(5, -12, 3), '#3A2633'),
            flat(circle(-4, -13, 1.1), '#FFFFFF'), flat(circle(6, -13, 1.1), '#FFFFFF')]
    return out


def leaf(c='#8ACB6A', deg=0):
    d = smooth_closed([(-34, 6), (-10, -22), (22, -26), (38, -8), (14, 18), (-18, 20)], 1.0)
    twig = line(smooth_open([(-42, 12), (-24, 8), (-6, 0), (20, -10)]), '#9C6E4E', 5)
    out = [blob(d, c, 4), line(smooth_open([(-28, 6), (0, -4), (30, -14)]), outline(c), 3), twig,
           line(smooth_open([(-24, 8), (-30, -6)]), '#9C6E4E', 4)]
    return rot(out, deg)


def rash():
    out = []
    for x, y, r in [(-16, -10, 11), (14, -14, 9), (2, 10, 12), (-20, 18, 7), (22, 14, 8)]:
        out += [flat(circle(x, y, r + 6), '#FFB3C2', 0.6), flat(circle(x, y, r), '#FF6F8E', 0.85)]
    out += [line(smooth_open([(-36, -30), (-28, -26)]), '#E0485E', 4), line(smooth_open([(32, -32), (26, -24)]), '#E0485E', 4)]
    return out


def swelling():
    c = '#FF9DB4'
    return [blob(circle(0, 0, 40), c, 4), flat(circle(0, 0, 28), '#FF7F9E', 0.6), shine(-14, -16, 10, 0.75),
            line(smooth_open([(48, -24), (58, -34)]), '#E0485E', 5), line(smooth_open([(52, 0), (66, 0)]), '#E0485E', 5),
            line(smooth_open([(48, 24), (58, 34)]), '#E0485E', 5)]


def bump():
    c = '#FF8FA8'
    return [flat(circle(0, 0, 40), c, 0.4), blob(circle(0, 0, 24), c, 4), shine(-8, -9, 7, 0.75),
            line(smooth_open(arc(0, 0, 42, 42, -150, -100, 6)), '#E0485E', 5),
            line(smooth_open(arc(0, 0, 42, 42, -80, -30, 6)), '#E0485E', 5)]


def cast():
    c = '#FFFFFF'
    out = [blob(rrect(-46, -34, 92, 68, 30), c, 4, '#C7B9D6')]
    for x in (-24, -4, 16, 34):
        out.append(line(smooth_open([(x, -32), (x - 10, 32)]), '#E4DAEE', 4))
    out.append(flat(heart(6, 0, 12), '#FF8FB8'))
    out.append(flat(star(-24, 8, 9, 0.45), '#FFD86E'))
    return out


def swirl():
    c = '#8FCF8A'
    pts = [(math.cos(t) * (4 + t * 4.2), math.sin(t) * (4 + t * 4.2)) for t in [i * 0.35 for i in range(30)]]
    return [flat(circle(0, 0, 46), '#C9EFC2', 0.55), line(smooth_open(pts), c, 7)]


def drip():
    d = "M0 -18 C8 -4 14 6 14 14 C14 22 7 28 0 28 C-7 28 -14 22 -14 14 C-14 6 -8 -4 0 -18 Z"
    return [S(d, '#BFE4FF', '#7FB6E8', 3.5), flat(ellipse(-5, 12, 3.5, 6), '#FFFFFF', 0.8)]


def rednose():
    return [flat(circle(0, 0, 30), '#FF6F8E', 0.45)]


def chill():
    out = []
    for s in (-1, 1):
        for k in range(3):
            y = -24 + k * 24
            pts = [(s * (170 + i * 4), y + 6 * math.sin(i * 1.4)) for i in range(7)]
            out.append(line(smooth_open(pts), '#8EC5FF', 5, 0.85))
    out.append(flat(star(-150, -70, 12, 0.4, 6), '#CFE8FF'))
    out.append(flat(star(160, -60, 10, 0.4, 6), '#CFE8FF'))
    return out


def bow(c):
    l = smooth_closed([(0, 0), (-30, -24), (-46, -8), (-44, 14), (-28, 22)], 1.0)
    out = [blob(l, c, 4)]
    out += mirror(out, 0)
    out += [line(smooth_open([(-8, 6), (-18, 30)]), outline(c), 9), line(smooth_open([(-8, 6), (-18, 30)]), c, 4.5),
            line(smooth_open([(8, 6), (18, 30)]), outline(c), 9), line(smooth_open([(8, 6), (18, 30)]), c, 4.5),
            blob(ellipse(0, 0, 11, 12), shade(c), 4, outline(c)), flat(ellipse(-28, -6, 7, 4, -30), light(c), 0.8)]
    return out


def tear():
    d = "M0 -14 C6 -3 10 4 10 10 C10 16 5 20 0 20 C-5 20 -10 16 -10 10 C-10 4 -6 -3 0 -14 Z"
    return [S(d, '#BFE4FF', '#7FB6E8', 3), flat(ellipse(-3, 8, 2.5, 4), '#FFFFFF', 0.8)]


def medal():
    out = [blob(poly([(-26, -60), (-8, -60), (6, -18), (-10, -16)]), '#9CCBFF', 4),
           blob(poly([(26, -60), (8, -60), (-6, -18), (10, -16)]), '#FF9EC0', 4),
           blob(circle(0, 12, 36), '#FFD86E', 5), flat(circle(0, 12, 26), '#FFE9A6'),
           flat(heart(0, 12, 15), '#FF6F96'), shine(-14, -4, 7)]
    return out


def seat():
    """A cushion chair in the waiting room."""
    c = '#FFB8CF'
    return [blob(rrect(-130, -110, 260, 150, 50), c, 5), flat(rrect(-110, -96, 220, 34, 16), light(c), 0.6),
            blob(rrect(-150, 10, 300, 70, 32), mixh(c, '#C9B6FF', 0.4), 5),
            blob(rrect(-130, 70, 22, 60, 8), '#C9A27E', 4), blob(rrect(108, 70, 22, 60, 8), '#C9A27E', 4)]


PROPS = {
    'mud': mud, 'bubbles': bubbles, 'thorn': thorn, 'scrape': scrape, 'scrapeClean': scrape_clean,
    'bandage': bandage, 'bug': bug, 'bugGreen': lambda: bug('#8FD9A8'), 'bugPink': lambda: bug('#FF9EC0'),
    'leaf': leaf, 'leafGold': lambda: leaf('#F2C14E', 30), 'leafRed': lambda: leaf('#FF9A6E', -30),
    'rash': rash, 'swelling': swelling, 'bump': bump, 'cast': cast, 'swirl': swirl,
    'drip': drip, 'rednose': rednose, 'chill': chill, 'tear': tear, 'medal': medal, 'seat': seat,
}
BOW_COLORS = ['#FF8FB8', '#9CCBFF', '#FFD86E', '#B89CFF', '#8FE0C4', '#FF8A73']
for i, c in enumerate(BOW_COLORS):
    PROPS[f'bow{i}'] = (lambda c=c: bow(c))


# ---------------------------------------------------------------- tools (140 x 140 box)

def t_sponge():
    c = '#FFE27A'
    out = [blob(rrect(22, 40, 96, 66, 22), c), flat(rrect(30, 46, 80, 18, 9), light(c), 0.7)]
    for x, y, r in [(44, 78, 6), (66, 90, 5), (90, 76, 7), (104, 94, 4), (58, 70, 4), (80, 96, 4)]:
        out.append(flat(circle(x, y, r), shade(c)))
    out += [S(circle(36, 34, 10), '#F4FBFF', '#9CCBFF', 3), S(circle(108, 30, 8), '#F4FBFF', '#9CCBFF', 3),
            S(circle(52, 22, 6), '#F4FBFF', '#9CCBFF', 3)]
    return out, (70, 106)


def t_shower():
    c = '#9CCBFF'
    out = [line(smooth_open([(116, 128), (126, 90), (110, 50), (86, 40)]), '#B9B7C6', 12),
           line(smooth_open([(116, 128), (126, 90), (110, 50), (86, 40)]), '#E6E5EE', 6),
           blob(smooth_closed([(84, 26), (98, 44), (64, 82), (30, 70), (26, 50), (52, 40)], 1.0), c)]
    for k in range(4):
        out.append(flat(circle(36 + k * 9, 64 + k * 3, 3.2), outline(c)))
    out += [flat(ellipse(30, 100, 4, 8, 20), '#7FB6E8'), flat(ellipse(46, 112, 4, 8, 20), '#7FB6E8'),
            flat(ellipse(16, 116, 4, 8, 20), '#7FB6E8')]
    return out, (36, 96)


def t_towel():
    c = '#FF9EC0'
    out = [blob(rrect(18, 36, 104, 72, 18), c), flat(rrect(18, 58, 104, 12, 0), light(c)),
           flat(rrect(18, 80, 104, 8, 0), light(c)), blob(rrect(18, 28, 104, 24, 12), light(c), 5, outline(c))]
    for x in range(26, 122, 12):
        out.append(line(f"M{x} 108 L{x} 118", outline(c), 4))
    return out, (70, 80)


def t_tweezers():
    c = '#C9CDE0'
    a = smooth_closed([(96, 18), (108, 26), (42, 122), (36, 118)], 0.3)
    b = smooth_closed([(110, 32), (118, 42), (44, 124), (38, 120)], 0.3)
    return [blob(a, c, 4), blob(b, shade(c), 4, outline(c)), blob(circle(110, 26, 14), '#FF9EC0', 4)], (38, 122)


def t_swab():
    out = [blob(rrect(66, 40, 12, 90, 6), '#C9E8FF', 4), blob(ellipse(72, 30, 20, 24), '#FFFFFF', 4, '#C7B9D6'),
           flat(ellipse(66, 24, 6, 8, -20), '#F3EEF8')]
    out += [blob(rrect(18, 70, 36, 56, 10), '#9FE3CF'), blob(rrect(26, 58, 20, 16, 5), '#FFFFFF', 4, outline('#9FE3CF')),
            flat(rrect(32, 88, 8, 24, 2), '#FFFFFF'), flat(rrect(24, 96, 24, 8, 2), '#FFFFFF')]
    return out, (72, 14)


def t_bandage():
    out = move(bandage('#FFD3B0'), 70, 70, 1.1)
    return out, (70, 70)


def t_thermo():
    c = '#FFFFFF'
    out = [blob(rrect(60, 10, 22, 104, 11), c, 4, '#B9B7C6'), flat(rrect(66, 50, 10, 64, 5), '#FF6F8E'),
           blob(circle(71, 116, 16), '#FF6F8E', 4)]
    for y in (24, 36, 48, 60, 72):
        out.append(line(f"M84 {y} L92 {y}", '#B9B7C6', 3))
    out.append(shine(66, 110, 5))
    return out, (71, 120)


def t_syrup():
    c = '#FF8FB8'
    bottle = [blob(smooth_closed([(18, 64), (26, 50), (56, 50), (64, 64), (64, 124), (18, 124)], 0.6), '#B89CFF'),
              blob(rrect(26, 34, 30, 18, 6), '#FFFFFF', 4, outline('#B89CFF')), flat(rrect(26, 80, 38, 26, 6), '#FFFFFF'),
              flat(heart(45, 93, 9), c)]
    spoon = [blob(rrect(80, 70, 52, 12, 6), '#E6E5EE', 4, '#9C9AB0'), blob(ellipse(78, 76, 26, 18), '#E6E5EE', 4, '#9C9AB0'),
             flat(ellipse(76, 76, 18, 11), c)]
    return bottle + spoon, (66, 76)


def t_tissue():
    out = [blob(rrect(16, 66, 108, 56, 12), '#A9D8FF'), flat(rrect(16, 66, 108, 16, 0), light('#A9D8FF')),
           flat(heart(70, 102, 12), '#FFFFFF'),
           blob(smooth_closed([(46, 72), (54, 30), (70, 18), (86, 36), (100, 22), (96, 72)], 1.0), '#FFFFFF', 4, '#C7B9D6')]
    return out, (72, 22)


def t_toothbrush():
    c = '#8FE0C4'
    out = [blob(tube([(126, 126), (84, 80), (44, 40)], 16, 14), c)]
    for i in range(5):
        x, y = 30 + i * 7, 46 - i * 7
        out.append(blob(rrect(x - 12, y - 14, 10, 18, 4), '#FFFFFF', 3, '#C7B9D6'))
    out.append(S(scallop(26, 26, 18, 12, 6, 0.2), '#FFFFFF', '#9CCBFF', 3))
    return out, (30, 34)


def t_icepack():
    c = '#9CCBFF'
    out = [blob(smooth_closed([(20, 50), (70, 34), (120, 50), (122, 108), (70, 124), (18, 108)], 0.8), c),
           flat(ellipse(50, 54, 20, 8, -14), light(c), 0.8),
           line(f"M70 58 L70 104 M50 69 L90 93 M50 93 L90 69", '#FFFFFF', 6)]
    return out, (70, 82)


def t_comb():
    c = '#FFB57D'
    out = [blob(rrect(14, 40, 112, 26, 10), c)]
    for x in range(20, 124, 12):
        out.append(blob(rrect(x, 60, 7, 40, 3.5), c, 3))
    out.append(flat(rrect(20, 44, 100, 8, 4), light(c), 0.7))
    return out, (70, 96)


def t_cream():
    c = '#FFFFFF'
    out = [blob(smooth_closed([(18, 34), (98, 26), (100, 84), (18, 78)], 0.25), '#FFC2D6'),
           blob(rrect(96, 40, 22, 30, 6), '#FF8FB8'), flat(rrect(30, 42, 52, 26, 8), c),
           flat(heart(56, 55, 9), '#FF8FB8'), blob(smooth_closed([(118, 48), (134, 54), (128, 66), (118, 62)], 1.0), '#FFFFFF', 3, '#E6D3DC')]
    out = rot(out, 30, 70, 70)
    return out, (112, 78)


def t_stetho():
    c = '#B89CFF'
    tubeL = line(smooth_open([(42, 18), (36, 46), (56, 76), (78, 84)]), c, 9)
    tubeR = line(smooth_open([(98, 18), (104, 46), (84, 76), (78, 84)]), c, 9)
    out = [tubeL, tubeR, line(smooth_open([(78, 84), (80, 104)]), c, 9),
           flat(circle(42, 16, 7), '#4A4250'), flat(circle(98, 16, 7), '#4A4250'),
           blob(circle(80, 114, 18), '#E6E5EE', 4, '#9C9AB0'), flat(circle(80, 114, 10), '#FF8FB8')]
    return out, (80, 114)


def t_wrap():
    c = '#FFFFFF'
    out = [blob(smooth_closed([(60, 92), (118, 96), (126, 120), (64, 126)], 0.5), c, 4, '#C7B9D6'),
           blob(ellipse(56, 72, 40, 40), c, 4, '#C7B9D6'), flat(circle(56, 72, 26), '#F3EEF8'),
           blob(circle(56, 72, 12), '#FFD3E0', 3, '#C7B9D6'), flat(heart(98, 110, 7), '#FF8FB8')]
    return out, (60, 72)


def t_brush():
    c = '#C9B6FF'
    out = [blob(tube([(124, 126), (90, 92)], 18, 14), c), blob(ellipse(60, 58, 46, 40, -45), c),
           flat(ellipse(60, 58, 34, 28, -45), '#FFF1F8')]
    for i in range(-2, 3):
        for j in range(-2, 3):
            if abs(i) + abs(j) < 4:
                x, y = 60 + (i - j) * 8, 58 + (i + j) * 8
                out.append(flat(circle(x, y, 3), shade(c)))
    return out, (50, 48)


def t_treat():
    c = '#E9B27A'
    out = [blob(wobble_circle(70, 72, 50, 12, 0.05, 1), c), flat(wobble_circle(70, 66, 40, 12, 0.08, 2), '#FFC2D6'),
           flat(ellipse(54, 50, 14, 6, -25), '#FFFFFF', 0.6)]
    for x, y, col, a in [(56, 66, '#9CCBFF', 20), (80, 58, '#FFE27A', -30), (74, 80, '#FFFFFF', 60), (92, 74, '#9FE3CF', 10), (50, 84, '#FF8FB8', -50), (66, 50, '#C9B6FF', 40)]:
        out += rot([flat(rrect(x - 6, y - 2.5, 12, 5, 2.5), col)], a, x, y)
    return out, (70, 72)


def t_bow():
    return move(bow('#FF8FB8'), 70, 70, 1.25), (70, 70)


def t_spray():
    c = '#FFB8E0'
    out = [blob(smooth_closed([(36, 72), (56, 56), (84, 56), (104, 72), (104, 120), (36, 120)], 0.6), c),
           flat(ellipse(56, 82, 10, 18, 0), light(c), 0.8), blob(rrect(58, 34, 24, 24, 6), '#FFD86E'),
           blob(rrect(52, 20, 36, 16, 8), '#C9B6FF'), flat(star(70, 96, 10, 0.45), '#FFFFFF'),
           flat(star(24, 26, 9, 0.38, 4), '#FFD86E'), flat(star(36, 10, 6, 0.38, 4), '#FFFFFF'), flat(star(12, 44, 6, 0.38, 4), '#FF8FB8')]
    return out, (30, 30)


def t_feather():
    c = '#FF9EC0'
    d = smooth_closed([(118, 18), (92, 30), (60, 62), (40, 98), (52, 102), (88, 74), (112, 44)], 1.0)
    out = [blob(d, c), line(smooth_open([(122, 14), (90, 46), (56, 84), (26, 124)]), outline(c), 5)]
    for t in range(4):
        x, y = 104 - t * 14, 34 + t * 14
        out.append(line(smooth_open([(x, y), (x - 16, y - 2)]), light(c), 4))
    return out, (110, 26)


TOOLS = [
    # id, builder, tray tint
    ('sponge', t_sponge, '#FFF3C2'), ('shower', t_shower, '#DDEEFF'), ('towel', t_towel, '#FFE1EC'),
    ('tweezers', t_tweezers, '#EDEFF8'), ('swab', t_swab, '#DDF5EC'), ('bandage', t_bandage, '#FFEBDD'),
    ('thermometer', t_thermo, '#FFE1E8'), ('syrup', t_syrup, '#EEE6FF'), ('tissue', t_tissue, '#E3F1FF'),
    ('toothbrush', t_toothbrush, '#DDF5EC'), ('icepack', t_icepack, '#DDEEFF'), ('comb', t_comb, '#FFEBDD'),
    ('cream', t_cream, '#FFE1EC'), ('stethoscope', t_stetho, '#EEE6FF'), ('wrap', t_wrap, '#F3EEF8'),
    ('brush', t_brush, '#EEE6FF'), ('treat', t_treat, '#FFF3C2'), ('bow', t_bow, '#FFE1EC'),
    ('spray', t_spray, '#FFE1F2'), ('feather', t_feather, '#FFE1EC'),
]


# ---------------------------------------------------------------- rooms (1400 x 834)

def cloud(cx, cy, k=1.0):
    return [flat(' '.join([circle(cx - 28 * k, cy + 4 * k, 20 * k), circle(cx, cy - 8 * k, 26 * k), circle(cx + 28 * k, cy + 4 * k, 20 * k),
                          rrect(cx - 48 * k, cy, 96 * k, 24 * k, 12 * k)]), '#FFFFFF')]


def room_exam():
    out = [flat("M0 0 L1400 0 L1400 834 L0 834 Z", '#E7F7F1')]
    for x in range(0, 1400, 80):
        out.append(flat(f"M{x} 0 L{x + 40} 0 L{x + 40} 560 L{x} 560 Z", '#DDF2EA'))
    out += [flat("M0 540 L1400 540 L1400 574 L0 574 Z", '#FFFFFF'), flat("M0 574 L1400 574 L1400 834 L0 834 Z", '#F6DCC4')]
    for y in (640, 720, 800):
        out.append(line(f"M0 {y} L1400 {y}", '#E9C9AE', 4))
    # window with clouds
    out += [blob(rrect(300, 90, 220, 190, 30), '#BFE4FF', 8, '#FFFFFF'), *cloud(370, 200, 1.00),
            *cloud(460, 150, 0.78), line("M410 90 L410 280 M300 185 L520 185", '#FFFFFF', 8)]
    # heart-cross sign
    out += [blob(circle(700, 130, 62), '#FFFFFF', 6, '#FFC2D6'), flat(heart(700, 132, 40), '#FF8FB8'),
            flat(rrect(690, 104, 20, 56, 4), '#FFFFFF'), flat(rrect(672, 122, 56, 20, 4), '#FFFFFF')]
    # cabinet with jars
    out += [blob(rrect(880, 120, 220, 150, 18), '#FFFFFF', 6, '#C9B6FF'), line("M880 196 L1100 196", '#C9B6FF', 6)]
    for i, col in enumerate(['#FF9EC0', '#9CCBFF', '#FFE27A', '#9FE3CF']):
        out += [blob(rrect(898 + i * 50, 140, 34, 48, 10), col, 4), blob(rrect(898 + i * 50, 208, 34, 48, 10), ['#C9B6FF', '#FFB57D', '#9FE3CF', '#FF9EC0'][i], 4)]
    # plant
    out += [blob(ellipse(1180, 470, 40, 70, -20), '#8FD9A8'), blob(ellipse(1230, 460, 40, 70, 20), '#7CCB6A'),
            blob(rrect(1160, 500, 100, 80, 20), '#FFB57D')]
    # exam mat under the patient
    out += [flat(ellipse(700, 760, 330, 60), '#C9E8FF'), flat(ellipse(700, 752, 300, 46), '#DDF0FF'),
            line(smooth_open(arc(700, 752, 270, 38, 20, 160, 12)), '#FFFFFF', 6, 0.8)]
    return out


def room_lobby():
    out = [flat("M0 0 L1400 0 L1400 834 L0 834 Z", '#FFEFE6')]
    for y in range(40, 560, 70):
        for x in range(40 if (y // 70) % 2 else 75, 1400, 70):
            out.append(flat(heart(x, y, 9), '#FFDCE6'))
    out += [flat("M0 520 L1400 520 L1400 552 L0 552 Z", '#FFFFFF'), flat("M0 552 L1400 552 L1400 834 L0 834 Z", '#D9C9F2')]
    for x in range(0, 1400, 140):
        out.append(flat(f"M{x} 552 L{x + 70} 552 L{x + 70} 834 L{x} 834 Z", '#CFBDEB'))
    out += [blob(rrect(80, 90, 200, 170, 30), '#BFE4FF', 8, '#FFFFFF'), *cloud(150, 190, 0.87),
            line("M180 90 L180 260 M80 175 L280 175", '#FFFFFF', 8),
            blob(rrect(1100, 70, 170, 280, 24), '#FFC2D6', 6, '#FFFFFF'), flat(circle(1240, 220, 10), '#FFE27A'),
            flat(heart(1185, 150, 34), '#FFFFFF'), flat(rrect(1176, 128, 18, 46, 3), '#FF8FB8'), flat(rrect(1162, 142, 46, 18, 3), '#FF8FB8')]
    return out
