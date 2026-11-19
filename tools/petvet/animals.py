"""The Pet Vet patients: 16 chibi animals sitting up, in a 600x660 canvas mirrored around x=300.
Every animal shares one body plan, so problem spots (mud, thorns, bugs...) land on fur for all of them.
Each animal has layers ('back' behind the head and body, 'body', 'front' over problems) and its own
face parts per expression, so faces can react."""
import math
from geom import ellipse, circle, smooth_closed, smooth_open, sym, poly, heart, star, rrect
from base import (S, blob, flat, line, tube, mirror, move, arc, shine, scallop, wobble_circle,
                  shade, light, deep, outline, mixh)

W, H = 600, 660
HC = (300, 262)          # head center
EYE = '#3A2633'
MOUTH_IN = '#C2456A'
TONGUE = '#FF8FA8'
BLUSH = '#FF8FB0'
BEAN = '#FFB3C7'

# Problem anchors in patient coordinates. Every animal has fur under each of these.
ANCHORS = {
    'forehead': (300, 168), 'headL': (190, 205), 'headR': (410, 205),
    'cheekL': (196, 322), 'cheekR': (404, 322),
    'nose': (300, 308), 'mouth': (300, 334),
    'chest': (300, 412), 'tummy': (300, 500),
    'sideL': (200, 455), 'sideR': (400, 455),
    'pawL': (222, 505), 'pawR': (378, 505),
    'lowL': (252, 560), 'lowR': (348, 560),
    'footL': (226, 604), 'footR': (374, 604),
}


def head_path(rx=152, ry=128, cx=300, cy=262, chub=1.0):
    pts = [(cx, cy - ry), (cx - rx * 0.55, cy - ry * 0.93), (cx - rx * 0.92, cy - ry * 0.5),
           (cx - rx, cy + ry * 0.05), (cx - rx * 0.93 * chub, cy + ry * 0.55), (cx - rx * 0.6, cy + ry * 0.9),
           (cx, cy + ry)]
    return sym(pts)


def body_path(wide=1.0):
    k = wide
    pts = [(300, 350), (300 - 68 * k, 362), (300 - 108 * k, 410), (300 - 125 * k, 480), (300 - 118 * k, 545),
           (300 - 85 * k, 592), (300, 604)]
    return sym(pts)


# ---------------------------------------------------------------- faces

def eyes_set(ex, ey, r=1.0, color=EYE, lash=None):
    """Expression -> shapes for both eyes. Left eye at ex, right eye mirrored."""
    rx, ry = 21 * r, 26 * r

    def pair(fn):
        L = fn(ex, ey, 1)
        R = fn(600 - ex, ey, -1)
        return L + R

    def open_(x, y, s):
        out = [flat(ellipse(x, y, rx, ry), color),
               flat(circle(x + 7 * r, y - 9 * r, 8 * r), '#FFFFFF'),
               flat(circle(x - 6 * r, y + 10 * r, 3.8 * r), '#FFFFFF', 0.9)]
        if lash:
            out.append(line(smooth_open([(x - s * rx * 0.9, y - ry * 0.55), (x - s * rx * 1.35, y - ry * 0.85)]), color, 5))
        return out

    def sparkle(x, y, s):
        return [flat(ellipse(x, y, rx, ry), color),
                flat(star(x + 6 * r, y - 8 * r, 11 * r, 0.32, 4, -90, 0.0), '#FFFFFF'),
                flat(circle(x - 7 * r, y + 10 * r, 4 * r), '#FFFFFF', 0.9)]

    def sad(x, y, s):
        return [flat(ellipse(x, y + 2 * r, rx * 0.95, ry * 0.92), color),
                flat(circle(x + 6 * r, y - 7 * r, 9.5 * r), '#FFFFFF'),
                flat(circle(x - 6 * r, y + 9 * r, 5 * r), '#FFFFFF', 0.9),
                flat(circle(x + 9 * r, y + 7 * r, 2.6 * r), '#FFFFFF', 0.8)]

    def tired(x, y, s):
        return [flat(ellipse(x, y + 9 * r, rx * 0.95, ry * 0.55), color),
                flat(circle(x + 6 * r, y + 6 * r, 4.5 * r), '#FFFFFF'),
                line(smooth_open([(x - 24 * r, y + 3 * r), (x, y - 3 * r), (x + 24 * r, y + 3 * r)]), color, 6 * r)]

    def blink(x, y, s):
        return [line(smooth_open([(x - 20 * r, y + 2 * r), (x, y + 11 * r), (x + 20 * r, y + 2 * r)]), color, 6.5 * r)]

    def happy(x, y, s):
        return [line(smooth_open([(x - 21 * r, y + 9 * r), (x, y - 11 * r), (x + 21 * r, y + 9 * r)]), color, 7 * r)]

    def wince(x, y, s):
        return [line(poly([(x - s * 15 * r, y - 13 * r), (x + s * 13 * r, y), (x - s * 15 * r, y + 13 * r)], False), color, 7 * r)]

    return {'open': pair(open_), 'sparkle': pair(sparkle), 'sad': pair(sad), 'tired': pair(tired),
            'blink': pair(blink), 'happy': pair(happy), 'wince': pair(wince)}


def brows(ex, ey, col, r=1.0):
    L = [line(smooth_open([(ex - 18 * r, ey - 36 * r), (ex + 15 * r, ey - 47 * r)]), col, 6)]
    return L + mirror(L)


def mouth_set(mx, my, style, col, fur):
    """Expression -> mouth shapes at (mx, my)."""
    lc = col

    def smile():
        if style == 'w':
            a = smooth_open([(mx - 24, my - 4), (mx - 12, my + 9), (mx, my - 2)])
            b = smooth_open([(mx, my - 2), (mx + 12, my + 9), (mx + 24, my - 4)])
            return [line(a, lc, 5), line(b, lc, 5)]
        if style == 'y':
            a = smooth_open([(mx - 22, my - 2), (mx - 11, my + 9), (mx, my)])
            b = smooth_open([(mx, my), (mx + 11, my + 9), (mx + 22, my - 2)])
            return [line(f"M{mx} {my - 16} L{mx} {my}", lc, 5), line(a, lc, 5), line(b, lc, 5)]
        return [line(smooth_open([(mx - 20, my - 3), (mx, my + 10), (mx + 20, my - 3)]), lc, 5.5)]

    def grin():
        d = (f"M{mx - 28} {my - 4} C{mx - 14} {my - 1} {mx + 14} {my - 1} {mx + 28} {my - 4} "
             f"C{mx + 26} {my + 22} {mx + 12} {my + 32} {mx} {my + 32} C{mx - 12} {my + 32} {mx - 26} {my + 22} {mx - 28} {my - 4} Z")
        t = ellipse(mx, my + 22, 15, 9)
        return [S(d, MOUTH_IN, lc, 5), flat(t, TONGUE)]

    def frown():
        return [line(smooth_open([(mx - 17, my + 9), (mx, my - 1), (mx + 17, my + 9)]), lc, 5.5)]

    def wavy():
        pts = [(mx - 22 + i * 5.5, my + 4 + 4 * math.sin(i * 1.6)) for i in range(9)]
        return [line(smooth_open(pts), lc, 5)]

    def ouch():
        return [S(wobble_circle(mx, my + 8, 16, 9, 0.12, 3), MOUTH_IN, lc, 5),
                flat(ellipse(mx, my + 15, 9, 5), TONGUE)]

    def o():
        return [S(ellipse(mx, my + 6, 10, 12), MOUTH_IN, lc, 5)]

    def yum():
        t = S(ellipse(mx + 9, my + 12, 10, 12, -12), TONGUE, outline(TONGUE), 4)
        return [t] + smile()

    def wide():
        d = ellipse(mx, my + 14, 34, 26)
        teeth = rrect(mx - 22, my - 9, 44, 12, 5)
        return [S(d, MOUTH_IN, lc, 5), flat(ellipse(mx, my + 27, 17, 9), TONGUE),
                S(teeth, '#FFFFFF', '#E8D9E0', 2.5)]

    return {'smile': smile(), 'grin': grin(), 'frown': frown(), 'wavy': wavy(), 'ouch': ouch(),
            'o': o(), 'yum': yum(), 'wide': wide()}


def beak_set(mx, my, color, size=1.0):
    """Mouths for animals with a beak: the beak itself opens and closes."""
    oc = outline(color)
    k = size

    def upper(lift=0):
        d = (f"M{mx - 40 * k} {my - 6 * k - lift} C{mx - 30 * k} {my - 26 * k - lift} {mx + 30 * k} {my - 26 * k - lift} "
             f"{mx + 40 * k} {my - 6 * k - lift} C{mx + 28 * k} {my + 6 * k - lift} {mx - 28 * k} {my + 6 * k - lift} {mx - 40 * k} {my - 6 * k - lift} Z")
        return [blob(d, color, 5), flat(ellipse(mx - 12 * k, my - 13 * k - lift, 12 * k, 4.5 * k, -6), light(color), 0.9)]

    def lower(drop=0):
        d = (f"M{mx - 30 * k} {my + 2 * k + drop * 0.2} C{mx - 20 * k} {my + 18 * k + drop} {mx + 20 * k} {my + 18 * k + drop} "
             f"{mx + 30 * k} {my + 2 * k + drop * 0.2} Z")
        return [blob(d, shade(color), 5, oc)]

    def opened(drop, tongue=True):
        inside = (f"M{mx - 32 * k} {my} C{mx - 20 * k} {my + 22 * k + drop} {mx + 20 * k} {my + 22 * k + drop} {mx + 32 * k} {my} Z")
        out = [S(inside, MOUTH_IN, oc, 4)]
        if tongue:
            out.append(flat(ellipse(mx, my + (12 + drop * 0.55) * k, 13 * k, 6 * k), TONGUE))
        return lower(drop) + out + upper(3)

    closed = lower() + upper()
    yum = [S(ellipse(mx + 10 * k, my + 16 * k, 9 * k, 11 * k, -12), TONGUE, outline(TONGUE), 4)] + closed
    return {'smile': closed, 'frown': closed, 'wavy': closed, 'yum': yum,
            'grin': opened(16), 'ouch': opened(10), 'o': opened(7, False), 'wide': opened(24)}


def blush(ex, ey, o=0.55):
    L = [flat(ellipse(ex - 40, ey + 48, 24, 13), BLUSH, o)]
    return L + mirror(L)


# ---------------------------------------------------------------- body parts

def ears_pointy(c, inner, tilt=0, size=1.0, tip_col=None):
    pts = [(176, 192), (162 - tilt, 112 - 40 * (size - 1)), (174 - tilt, 82 - 50 * (size - 1)), (196, 96), (262, 150)]
    d = smooth_closed(pts, 0.55)
    ins = smooth_closed([(190, 178), (182 - tilt, 116 - 36 * (size - 1)), (188 - tilt, 102 - 44 * (size - 1)), (204, 110), (240, 148)], 0.55)
    L = [blob(d, c), flat(ins, inner)]
    if tip_col:
        tip = smooth_closed([(168 - tilt, 108 - 40 * (size - 1)), (174 - tilt, 82 - 50 * (size - 1)), (196, 96), (186, 112)], 0.6)
        L.insert(1, blob(tip, tip_col))
    return L + mirror(L)


def ears_round(c, inner, cx=186, cy=160, r=46, inner_r=0.55):
    L = [blob(circle(cx, cy, r), c), flat(circle(cx + r * 0.08, cy + r * 0.1, r * inner_r), inner)]
    return L + mirror(L)


def ears_long(c, inner):
    p = [(250, 150), (226, 70), (212, 10), (226, -8 + 30), (248, 22), (264, 80), (272, 148)]
    d = smooth_closed([(242, 160), (214, 90), (206, 34), (222, 14), (244, 30), (262, 92), (280, 156)], 1.0)
    ins = smooth_closed([(246, 146), (226, 92), (222, 46), (232, 34), (246, 50), (258, 96), (266, 146)], 1.0)
    L = move([blob(d, c), flat(ins, inner)], 0, 0)
    import base
    L = [dict(s, d=base.xform(s['d'], 1, 1, 0, 0)) for s in L]
    Lr = []
    for s in L:
        s = dict(s)
        pts_rot = s['d']
        Lr.append(s)
    # tilt outward a little
    out = []
    for s in Lr:
        s = dict(s)
        s['d'] = rotate_path(s['d'], 252, 150, -14)
        out.append(s)
    return out + mirror(out)


def rotate_path(d, cx, cy, deg):
    """Rotate an absolute M/L/C/Z path about (cx, cy)."""
    import re
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    toks = re.findall(r'[MLCZ]|-?\d+(?:\.\d+)?', d)
    out, i = [], 0
    from geom import f as ff
    while i < len(toks):
        t = toks[i]; i += 1
        n = {'M': 1, 'L': 1, 'C': 3, 'Z': 0}[t]
        pts = []
        for _ in range(n):
            x, y = float(toks[i]), float(toks[i + 1]); i += 2
            pts.append(f"{ff(cx + (x - cx) * c - (y - cy) * s)} {ff(cy + (x - cx) * s + (y - cy) * c)}")
        out.append(t + ' '.join(pts))
    return ' '.join(out)


def ears_floppy(c, inner=None):
    d = smooth_closed([(196, 150), (150, 160), (124, 230), (130, 320), (160, 350), (188, 320), (200, 240), (214, 170)], 1.0)
    L = [blob(d, c), flat(ellipse(160, 300, 12, 22, 10), light(c), 0.5)]
    return L + mirror(L)


def ears_side(c, inner, droop=True):
    """Lamb / fawn ears sticking out sideways."""
    if droop:
        d = smooth_closed([(176, 222), (130, 214), (96, 236), (104, 262), (150, 262), (182, 252)], 1.0)
        ins = smooth_closed([(170, 230), (132, 226), (110, 240), (118, 254), (152, 254), (174, 246)], 1.0)
    else:
        d = smooth_closed([(184, 196), (132, 156), (84, 150), (96, 188), (140, 222), (184, 230)], 1.0)
        ins = smooth_closed([(176, 202), (136, 172), (104, 166), (112, 190), (144, 212), (176, 218)], 1.0)
    L = [blob(d, c), flat(ins, inner)]
    return L + mirror(L)


def paws(c, kind='paw', tip=None):
    if kind == 'wing':
        d = smooth_closed([(196, 400), (168, 440), (160, 500), (178, 540), (204, 520), (214, 450)], 1.0)
        L = [blob(d, c), flat(ellipse(184, 470, 7, 28, 8), light(c), 0.55)]
        return L + mirror(L)
    d = ellipse(228, 505, 33, 40, 14)
    L = [blob(d, c)]
    if kind == 'hoof':
        hd = smooth_closed([(206, 522), (222, 547), (246, 545), (254, 526), (232, 532)], 1.0)
        L.append(blob(hd, tip or '#B58A78'))
    else:
        L.append(line(smooth_open([(222, 536), (224, 527)]), outline(c), 4))
        L.append(line(smooth_open([(236, 537), (238, 528)]), outline(c), 4))
    return L + mirror(L)


def feet(c, kind='foot', tip=None):
    if kind == 'webbed':
        d = smooth_closed([(196, 590), (186, 612), (204, 624), (228, 616), (252, 626), (270, 610), (262, 588), (230, 584)], 1.0)
        L = [blob(d, c), line(smooth_open([(214, 604), (210, 616)]), outline(c), 4), line(smooth_open([(244, 604), (248, 616)]), outline(c), 4)]
        return L + mirror(L)
    d = ellipse(228, 602, 50, 30)
    L = [blob(d, c)]
    if kind == 'hoof':
        L.append(blob(smooth_closed([(196, 612), (210, 628), (248, 628), (262, 612), (230, 618)], 1.0), tip or '#B58A78'))
    else:
        L += [flat(ellipse(228, 609, 21, 14), BEAN), flat(circle(206, 590, 6.5), BEAN), flat(circle(228, 584, 7), BEAN),
              flat(circle(250, 590, 6.5), BEAN)]
    return L + mirror(L)


def body_set(c, belly=None, wide=1.0, shade_col=None):
    out = [blob(body_path(wide), c)]
    out.append(flat(smooth_closed([(220, 366), (300, 392), (380, 366), (360, 392), (300, 410), (240, 392)], 1.0), shade_col or shade(c), 0.7))
    if belly:
        out.append(flat(ellipse(300, 500, 72 * wide, 74), belly))
    return out


def head_set(c, rx=152, ry=128, chub=1.0, hl=True):
    out = [blob(head_path(rx, ry, chub=chub), c)]
    if hl:
        out.append(flat(ellipse(222, 176, 30, 15, -24), light(c), 0.7))
    return out


def nose_dog(col='#5B3A48', w=24, h=16, y=306):
    d = (f"M{300 - w} {y - h * 0.5} C{300 - w} {y - h * 1.1} {300 + w} {y - h * 1.1} {300 + w} {y - h * 0.5} "
         f"C{300 + w * 0.8} {y + h * 0.4} {300 + w * 0.3} {y + h * 0.75} {300} {y + h * 0.8} "
         f"C{300 - w * 0.3} {y + h * 0.75} {300 - w * 0.8} {y + h * 0.4} {300 - w} {y - h * 0.5} Z")
    return [blob(d, col, 4), flat(ellipse(292, y - h * 0.45, w * 0.32, h * 0.18), '#FFFFFF', 0.7)]


def nose_small(col='#FF8FA8', y=304):
    d = (f"M288 {y - 5} C288 {y - 11} 312 {y - 11} 312 {y - 5} C311 {y + 1} 304 {y + 6} 300 {y + 6} "
         f"C296 {y + 6} 289 {y + 1} 288 {y - 5} Z")
    return [blob(d, col, 3.5)]


# ---------------------------------------------------------------- the animals

def animal(spec):
    """Assemble one animal. Returns its JSON dict."""
    return spec


def make_all():
    A = {}

    # Puppy: tan with floppy brown ears and an eye patch
    c, e = '#F4C996', '#B97A4E'
    body = body_set(c, '#FFF4E6') + [flat(smooth_closed([(330, 530), (350, 470), (395, 450), (405, 510), (380, 560)], 1.0), light(e), 0.0)]
    head = head_set(c) + [flat(wobble_circle(362, 262, 42, 9, 0.12, 2), e, 0.85),
                          flat(ellipse(300, 326, 58, 40), '#FFF4E6')] + nose_dog()
    tail = [blob(tube([(400, 560), (446, 540), (470, 500), (466, 470)], 30, 20), c)]
    A['puppy'] = dict(back=tail, body=body + paws(c) + feet(c) + head, front=ears_floppy(e),
                      eye=(238, 270), mouth=(300, 334), style='y', col=outline(c), fur=c)

    # Kitty: orange tabby with a curly tail
    c = '#FFB57D'
    stripes = [flat(smooth_closed([(282, 136), (300, 182), (318, 136)], 0.7), shade(c)),
               flat(smooth_closed([(248, 142), (262, 176), (276, 140)], 0.7), shade(c)),
               flat(smooth_closed([(324, 140), (338, 176), (352, 142)], 0.7), shade(c))]
    side = [flat(smooth_closed([(178, 450), (215, 455), (180, 470)], 0.8), shade(c)), flat(smooth_closed([(182, 490), (214, 495), (184, 508)], 0.8), shade(c))]
    side = side + mirror(side)
    tail = [blob(tube([(398, 570), (452, 560), (488, 516), (494, 456), (474, 420), (452, 422)], 32, 26), c),
            flat(tube([(486, 470), (480, 436), (462, 428)], 18, 14), shade(c), 0.9)]
    head = head_set(c) + stripes + [flat(ellipse(270, 330, 34, 26), '#FFF1E4'), flat(ellipse(330, 330, 34, 26), '#FFF1E4')] + nose_small('#FF8FA8', 306)
    whisk = [line(smooth_open([(214, 318), (170, 310)]), outline(c), 3.5), line(smooth_open([(216, 334), (172, 340)]), outline(c), 3.5)]
    head += whisk + mirror(whisk)
    A['kitty'] = dict(back=ears_pointy(c, '#FFC6D6') + tail, body=body_set(c, '#FFF1E4') + side + paws(c) + feet(c) + head,
                      front=[], eye=(238, 270), mouth=(300, 330), style='w', col=outline(c), fur=c)

    # Bunny: snow white with pink inner ears and a cotton tail
    c = '#FBF4F7'
    tail = [blob(scallop(430, 560, 38, 34, 8, 0.14), '#FFFFFF')]
    head = head_set(c) + nose_small('#FF9FBA', 304)
    teeth = [S(rrect(290, 338, 20, 14, 4), '#FFFFFF', '#E6D3DC', 3)]
    A['bunny'] = dict(back=ears_long(c, '#FFC2D6') + tail, body=body_set(c, '#FFFFFF') + paws(c) + feet(c) + head,
                      front=[], eye=(238, 272), mouth=(300, 326), style='w', col=outline('#F3D2DE'), fur=c, lash=True)

    # Piglet: pink with a big snout and a curly tail
    c = '#FFC4D2'
    ear = smooth_closed([(180, 176), (150, 120), (160, 96), (212, 120), (240, 150)], 0.7)
    flap = smooth_closed([(166, 118), (204, 124), (214, 152), (182, 150)], 0.8)
    earsL = [blob(ear, c), blob(flap, shade(c))]
    ears = earsL + mirror(earsL)
    snout = [blob(ellipse(300, 306, 44, 30), '#FFA7BD'), flat(ellipse(285, 308, 7, 11), outline('#FFA7BD')),
             flat(ellipse(315, 308, 7, 11), outline('#FFA7BD')), flat(ellipse(290, 294, 12, 5), '#FFFFFF', 0.6)]
    tail = [line(smooth_open([(410, 540), (446, 528), (452, 498), (430, 490), (424, 512), (448, 520), (470, 506)]), outline(c), 13),
            line(smooth_open([(410, 540), (446, 528), (452, 498), (430, 490), (424, 512), (448, 520), (470, 506)]), c, 7)]
    A['piglet'] = dict(back=tail, body=body_set(c, '#FFE1E8') + paws(c, 'hoof', '#E88FA6') + feet(c, 'hoof', '#E88FA6') + head_set(c) + snout,
                       front=ears, eye=(236, 262), mouth=(300, 350), style='u', col=outline(c), fur=c)

    # Panda: black ears, eye patches, arms and legs
    c, k = '#FBF8F6', '#4A4250'
    patches = [flat(ellipse(236, 274, 38, 46, 30), k)]
    patches += mirror(patches)
    head = head_set(c) + patches + nose_dog('#4A4250', 20, 14, 310)
    A['panda'] = dict(back=ears_round(k, '#6B6070', 184, 152, 46, 0.5), body=body_set(c) + paws(k) + feet(k) + head,
                      front=[], eye=(238, 272), mouth=(300, 334), style='y', col='#6B6070', fur=c, eyecolor='#2A1E28', eyeshine=True)

    # Fox: orange with white cheeks and a big fluffy tail
    c = '#FF9D5E'
    cheeks = sym([(300, 280), (262, 292), (200, 300), (160, 300), (180, 350), (240, 384), (300, 390)], 1.0)
    tail = [blob(smooth_closed([(396, 590), (470, 580), (520, 520), (526, 446), (500, 400), (470, 430), (440, 500), (400, 540)], 1.0), c),
            blob(smooth_closed([(500, 400), (526, 446), (520, 470), (492, 458), (478, 424)], 1.0), '#FFF6EE')]
    head = head_set(c) + [flat(cheeks, '#FFF6EE')] + nose_dog('#5B3A48', 18, 13, 308)
    A['fox'] = dict(back=ears_pointy(c, '#FFF6EE', 6, 1.1, '#6B4A50') + tail, body=body_set(c, '#FFF6EE') + paws('#6B4A50') + feet(c) + head,
                    front=[], eye=(238, 268), mouth=(300, 334), style='y', col=outline(c), fur=c, lash=True)

    # Hamster: golden with white chubby cheeks
    c = '#F7C27E'
    head = head_set(c, 160, 126, 1.12) + [flat(sym([(300, 262), (250, 270), (175, 290), (160, 330), (200, 372), (300, 388)], 1.0), '#FFF5E6')] + nose_small('#FF9FBA', 304)
    A['hamster'] = dict(back=ears_round(c, '#FFC2D2', 196, 156, 34, 0.55), body=body_set(c, '#FFF5E6', 1.06) + paws('#FFD9B8') + feet('#FFD9B8') + head,
                        front=[], eye=(236, 266), mouth=(300, 326), style='w', col=outline(c), fur=c)

    # Lamb: fluffy wool body, cream face, wool tuft
    c, wool = '#F4D9C8', '#FFFBF4'
    body = [blob(scallop(300, 482, 128, 124, 12, 0.1), wool), flat(smooth_closed([(220, 372), (300, 396), (380, 372), (360, 398), (300, 414), (240, 398)], 1.0), shade(wool), 0.6)]
    head = head_set(c, 140, 124) + nose_small('#D88B9E', 306)
    tuft = [blob(scallop(300, 156, 92, 46, 9, 0.22), wool)]
    A['lamb'] = dict(back=ears_side(c, '#FFC6D2'), body=body + paws(c, 'hoof', '#9C7A72') + feet(c, 'hoof', '#9C7A72') + head,
                     front=tuft, eye=(240, 272), mouth=(300, 326), style='w', col=outline(c), fur=c, lash=True)

    # Bear cub: brown with a light muzzle
    c = '#C08A66'
    head = head_set(c) + [flat(ellipse(300, 322, 56, 42), '#F0D3B5')] + nose_dog('#5B3A48', 22, 15, 304)
    A['bear'] = dict(back=ears_round(c, '#F0D3B5', 182, 156, 46), body=body_set(c, '#F0D3B5') + paws(c) + feet(c) + head,
                     front=[], eye=(238, 268), mouth=(300, 334), style='y', col=outline(c), fur=c)

    # Duckling: yellow with a beak, wings and webbed feet
    c, beak = '#FFE27A', '#FFA24C'
    tuft = [blob(smooth_closed([(296, 140), (282, 100), (300, 108), (306, 92), (318, 112), (312, 140)], 0.9), c)]
    A['duckling'] = dict(back=[], body=body_set(c, '#FFF3C2') + paws(c, 'wing') + feet(beak, 'webbed') + head_set(c) + tuft,
                         front=[], eye=(236, 262), mouth=(300, 320), style='beak', beak=beak, col=outline(c), fur=c)

    # Frog: green with eye bumps on top
    c = '#9EDB80'
    bumps = [blob(circle(226, 172, 54), c)]
    bumps += mirror(bumps)
    head = [blob(head_path(160, 114, cy=276), c)] + bumps + [flat(ellipse(300, 290, 150, 100), c), flat(ellipse(214, 150, 20, 10, -24), light(c), 0.7)]
    spots = [flat(circle(196, 456, 12), shade(c)), flat(circle(410, 470, 9), shade(c)), flat(circle(386, 432, 6), shade(c))]
    A['frog'] = dict(back=[], body=body_set(c, '#E9F8C9', 1.04) + spots + paws(c) + feet(c) + head,
                     front=[], eye=(226, 176), mouth=(300, 322), style='u', col=outline(c), fur=c, eyescale=1.05, cheeky=(0, 110))

    # Mouse: lilac-gray with huge round ears and a long tail
    c = '#CFC6DC'
    tail = [line(smooth_open([(400, 580), (460, 584), (500, 560), (506, 520), (486, 500)]), outline('#FFB3C7'), 12),
            line(smooth_open([(400, 580), (460, 584), (500, 560), (506, 520), (486, 500)]), '#FFC2D2', 6)]
    head = head_set(c, 146, 124) + nose_small('#FF8FA8', 304)
    whisk = [line(smooth_open([(214, 318), (168, 306)]), outline(c), 3.5), line(smooth_open([(216, 334), (170, 340)]), outline(c), 3.5)]
    head += whisk + mirror(whisk)
    A['mouse'] = dict(back=ears_round(c, '#FFC6D6', 170, 150, 68, 0.62) + tail, body=body_set(c, '#F1ECF6') + paws(c) + feet(c) + head,
                      front=[], eye=(240, 268), mouth=(300, 326), style='w', col=outline(c), fur=c, lash=True)

    # Koala: gray with fluffy ears and a big nose
    c = '#AFAEC2'
    ears = [blob(scallop(176, 176, 64, 60, 8, 0.12), c), flat(scallop(184, 182, 40, 38, 7, 0.1), '#FFFFFF')]
    ears += mirror(ears)
    nose = [blob(ellipse(300, 304, 24, 34), '#5E5468', 4), flat(ellipse(292, 286, 7, 11), '#FFFFFF', 0.6)]
    A['koala'] = dict(back=ears, body=body_set(c, '#EDECF4') + paws(c) + feet(c) + head_set(c, 150, 126) + nose,
                      front=[], eye=(232, 268), mouth=(300, 352), style='u', col=outline(c), fur=c)

    # Penguin: navy with a white face and belly
    c, beak = '#4F5E86', '#FFB04C'
    mask = sym([(300, 196), (262, 176), (210, 196), (186, 260), (206, 340), (250, 382), (300, 392)], 1.0)
    A['penguin'] = dict(back=[], body=body_set(c, '#FFFFFF', 1.02) + paws(c, 'wing') + feet(beak, 'webbed') + head_set(c) + [flat(mask, '#FFFFFF')],
                        front=[], eye=(244, 272), mouth=(300, 324), style='beak', beak=beak, beaksize=0.75, col=outline(c), fur=c)

    # Unicorn foal: lilac-white with a rainbow mane, gold horn and hooves
    c = '#FBF3FF'
    horn = [blob(smooth_closed([(282, 150), (300, 50), (318, 150)], 0.35), '#FFD86E'),
            line(smooth_open([(290, 126), (310, 118)]), outline('#FFD86E'), 3.5), line(smooth_open([(293, 100), (307, 94)]), outline('#FFD86E'), 3.5)]
    rainbow = ['#FF9EC0', '#FFC27A', '#FFE27A', '#A8E8CF', '#A9D8FF', '#D2C0FF']
    mane = []
    for i, col in enumerate(rainbow):
        a = -150 + i * 22
        x = 300 + math.cos(math.radians(a)) * 150
        y = 262 + math.sin(math.radians(a)) * 128 + 6
        mane.append(blob(circle(x, y, 34 - i * 1.5), col))
    tail = [blob(tube([(398, 580), (452, 572), (492, 530), (500, 470)], 40, 30), '#D2C0FF'),
            blob(tube([(404, 578), (450, 560), (476, 518)], 22, 16), '#FF9EC0')]
    A['unicorn'] = dict(back=ears_pointy(c, '#FFC6E0', -6, 0.9) + tail, body=body_set(c, '#FFFFFF') + paws(c, 'hoof', '#C9AEF5') + feet(c, 'hoof', '#C9AEF5') + head_set(c) + nose_small('#FFB3C7', 312),
                        front=mane + horn, eye=(238, 274), mouth=(300, 334), style='u', col=outline('#E6D6F5'), fur=c, lash=True, eyecolor='#5E3A8A')

    # Fawn: caramel with white spots and big sideways ears
    c = '#E3A574'
    spots = [flat(circle(x, y, r), '#FFF4E8') for x, y, r in [(250, 160, 9), (290, 146, 7), (338, 156, 8), (196, 420, 9), (404, 424, 8), (182, 470, 6), (416, 474, 7)]]
    head = head_set(c) + spots[:3] + [flat(ellipse(300, 322, 52, 40), '#FFF4E8')] + nose_dog('#5B3A48', 18, 13, 306)
    A['fawn'] = dict(back=ears_side(c, '#FFD3DE', False) + [blob(ellipse(430, 548, 24, 32, 30), '#FFF4E8')],
                     body=body_set(c, '#FFF4E8') + spots[3:] + paws(c, 'hoof', '#8E5B4A') + feet(c, 'hoof', '#8E5B4A') + head,
                     front=[], eye=(238, 270), mouth=(300, 334), style='y', col=outline(c), fur=c, lash=True)

    out = {}
    for k, a in A.items():
        ex, ey = a['eye']
        mx, my = a['mouth']
        sc = a.get('eyescale', 1.0)
        ecol = a.get('eyecolor', EYE)
        eyes = eyes_set(ex, ey, sc, ecol, a.get('lash'))
        if a['style'] == 'beak':
            mouths = beak_set(mx, my, a['beak'], a.get('beaksize', 1.0))
        else:
            mouths = mouth_set(mx, my, a['style'], a['col'], a['fur'])
        cheek = a.get('cheeky')
        bl = blush(ex, ey) if not cheek else blush(ex + cheek[0], ey + cheek[1] - 40)
        out[k] = {
            'back': a['back'], 'body': a['body'], 'front': a['front'],
            'eyes': eyes, 'mouths': mouths, 'brows': brows(ex, ey, a['col'], sc), 'blush': bl,
            'eye': [ex, ey], 'mouth': [mx, my], 'fur': a['fur'],
        }
    return out


ORDER = ['puppy', 'kitty', 'bunny', 'piglet', 'panda', 'fox', 'hamster', 'lamb',
         'bear', 'duckling', 'frog', 'mouse', 'koala', 'penguin', 'unicorn', 'fawn']
