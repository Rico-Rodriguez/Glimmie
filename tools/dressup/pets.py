"""The Dress Up pets: 20 chibi animals (the Pet Vet family plus four of their own), outfits that fit
every one of them, and the props used to care for them in the pet corner.

Pets live in a 600x660 canvas, mirrored around x=300, and share one sitting body plan
(tools/petvet/animals.py). Outfits are drawn once on that plan and placed on each pet with its
anchors (hat on top of the head, glasses on the eyes, collar under the chin, garments scaled to the
body's width). Animal colors are final hex; outfit colors use the Dress Up roles (c, a, .s .l .o)
so every outfit works in all 24 cloth colors."""
import math, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'petvet'))
import animals as AN
import props as VP
from geom import ellipse, circle, smooth_closed, smooth_open, sym, poly, heart, star, rrect, flower
from base import (S, blob, flat, line, tube, mirror, move, arc, shine, scallop, wobble_circle,
                  shade, light, deep, outline, mixh)

W, H = 600, 660

# ---------------------------------------------------------------- four new animals


def extra_animals():
    A = {}
    paws, feet, body_set, head_set = AN.paws, AN.feet, AN.body_set, AN.head_set

    # Baby dragon: lilac with a cream tummy, golden horns, little wings and a heart-tipped tail
    c, belly, gold = '#B9A6F0', '#FFF1CC', '#FFD86E'
    hornL = [blob(smooth_closed([(232, 162), (214, 104), (206, 84), (226, 92), (262, 150)], 0.8), gold),
             line(smooth_open([(222, 122), (238, 116)]), outline(gold), 3.5)]
    wingL = [blob(smooth_closed([(220, 420), (150, 360), (96, 352), (112, 384), (90, 404), (124, 418), (110, 446), (176, 452)], 0.7), '#DCCFFF'),
             line(smooth_open([(214, 420), (140, 372), (104, 358)]), outline('#DCCFFF'), 4)]
    tail = [blob(tube([(396, 572), (452, 566), (494, 534), (512, 486)], 34, 18), c),
            blob(heart(518, 470, 22), c), flat(heart(518, 470, 11), '#FFC6E0')]
    spikes = [blob(smooth_closed([(286, 140), (300, 112), (314, 140)], 0.4), '#D7C9FF')]
    stripes = [line(smooth_open([(250 + 6 * abs(i), 450 + i * 26), (300, 456 + i * 26), (350 - 6 * abs(i), 450 + i * 26)]), shade(belly), 4) for i in (-1, 0, 1, 2)]
    head = head_set(c) + [flat(ellipse(276, 316, 5, 4), outline(c)), flat(ellipse(324, 316, 5, 4), outline(c))]
    A['dragon'] = dict(back=hornL + mirror(hornL) + wingL + mirror(wingL) + spikes + tail,
                       torso=body_set(c, belly) + stripes, limbs=paws(c) + feet(c), head=head, front=[],
                       eye=(238, 272), mouth=(300, 336), style='u', col=outline(c), fur=c, eyecolor='#4B3577')

    # Red panda: russet with white face marks, dark legs and a ringed tail
    c, dark, white = '#DE7A4C', '#5E3934', '#FFF6EE'
    pts = [(398, 576), (446, 572), (486, 546), (506, 504), (506, 458)]
    tail = [blob(tube(pts, 46, 38), c)]
    for k in (0.32, 0.62, 0.9):
        i = int(k * (len(pts) - 1))
        a, b = pts[i], pts[min(i + 1, len(pts) - 1)]
        t = k * (len(pts) - 1) - i
        x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
        tail.append(flat(ellipse(x, y, 9, 22, ang), '#9C4A35'))
    face = [flat(ellipse(300, 326, 58, 40), white), flat(ellipse(236, 222, 22, 13, -10), white), flat(ellipse(364, 222, 22, 13, 10), white),
            flat(smooth_closed([(222, 296), (238, 300), (246, 352), (226, 346)], 0.9), '#B5563A', 0.8),
            flat(smooth_closed([(378, 296), (362, 300), (354, 352), (374, 346)], 0.9), '#B5563A', 0.8)]
    A['redpanda'] = dict(back=AN.ears_pointy(c, white, 10, 0.85) + tail, torso=body_set(c, '#F3A27A'),
                         limbs=paws(dark) + feet(dark), head=head_set(c) + face + AN.nose_dog('#3A2633', 20, 14, 310),
                         front=[], eye=(238, 270), mouth=(300, 334), style='y', col=outline(c), fur=c)

    # Owl: caramel with big eye discs, ear tufts, feathery tummy and a tiny beak
    c, belly, beak = '#C99A72', '#FFF1DC', '#FFB04C'
    tufts = [blob(smooth_closed([(176, 190), (160, 112), (176, 104), (240, 160)], 0.8), c),
             flat(smooth_closed([(184, 176), (176, 126), (186, 122), (224, 160)], 0.8), shade(c))]
    marks = []
    for row, y in enumerate((448, 482, 516)):
        for k in range(-1 - (row % 2 == 0), 2 + (row % 2 == 0)):
            x = 300 + k * 30 + (15 if row % 2 else 0)
            if abs(x - 300) < 64:
                marks.append(line(smooth_open([(x - 10, y - 4), (x, y + 5), (x + 10, y - 4)]), shade(belly), 4))
    discs = [flat(circle(238, 272, 50), '#FFF4E4'), flat(circle(362, 272, 50), '#FFF4E4'),
             flat(smooth_closed([(300, 196), (270, 210), (300, 240), (330, 210)], 0.9), shade(c), 0.7)]
    A['owl'] = dict(back=tufts + mirror(tufts), torso=body_set(c, belly) + marks, limbs=paws(c, 'wing') + feet(beak, 'webbed'),
                    head=head_set(c) + discs, front=[], eye=(238, 272), mouth=(300, 322), style='beak', beak=beak, beaksize=0.55,
                    col=outline(c), fur=c, lash=True)

    # Axolotl: bubblegum pink with frilly gills and a wide smile
    c, gill = '#FFB9D0', '#F46FA0'
    gills = []
    for (x0, y0), (x1, y1) in (((172, 236), (96, 188)), ((166, 268), (86, 262)), ((172, 300), (100, 334))):
        gills.append(blob(tube([(x0, y0), ((x0 + x1) / 2, (y0 + y1) / 2 - 6), (x1, y1)], 30, 18), gill))
        gills.append(flat(tube([(x0 - 6, y0), ((x0 + x1) / 2, (y0 + y1) / 2 - 6), (x1 + 6, y1)], 10, 6), light(gill), 0.8))
    fin = [blob(smooth_closed([(396, 560), (470, 540), (520, 486), (530, 440), (496, 470), (450, 520), (404, 536)], 1.0), '#FFD3E2')]
    spots = [flat(circle(x, y, r), shade(c)) for x, y, r in ((256, 170, 7), (338, 160, 6), (360, 186, 4))]
    A['axolotl'] = dict(back=gills + mirror(gills) + fin, torso=body_set(c, '#FFE6EF'), limbs=paws(c) + feet(c),
                        head=head_set(c, 158, 122) + spots, front=[], eye=(230, 274), mouth=(300, 334), style='u',
                        col=outline(c), fur=c, eyecolor='#3A2633')
    return AN.finish(A)


ORDER = ['kitty', 'puppy', 'bunny', 'unicorn', 'duckling', 'bear', 'dragon', 'fox', 'panda', 'hamster',
         'redpanda', 'owl', 'axolotl', 'piglet', 'lamb', 'frog', 'mouse', 'koala', 'penguin', 'fawn']

# Where outfits sit on each pet. hat: (x, y, degrees, scale) for the top of the head (canonical 300, 134).
# eyes: the left eye (canonical 238, 270). wide: body width (canonical 1). neck: chin line (canonical 390).
HAT = {'hamster': (300, 138, 0, 1.0), 'lamb': (300, 120, 0, 1.0), 'frog': (300, 172, 0, 0.95),
       'mouse': (300, 138, 0, 1.0), 'koala': (300, 136, 0, 1.0), 'unicorn': (372, 160, 24, 0.9),
       'axolotl': (300, 142, 0, 1.0), 'duckling': (300, 128, 0, 1.0), 'dragon': (300, 128, 0, 1.0)}
WIDE = {'hamster': 1.06, 'frog': 1.04, 'penguin': 1.02, 'lamb': 1.04}

# ---------------------------------------------------------------- outfits

HAT0, EYE0, NECK0 = (300, 134), (238, 270), (300, 390)
LW = 4.5


def R(d, fill=None, stroke=None, w=None, o=None, pat=False):
    s = {'d': d}
    if fill: s['f'] = fill
    if stroke:
        s['s'] = stroke
        s['w'] = LW if w is None else w
    if o is not None and o < 1: s['o'] = o
    if pat: s['pat'] = 1
    return s


def cb(d, w=None, pat=False):
    """Filled in the outfit color with its outline."""
    return R(d, 'c', 'c.o', w, pat=pat)


def ab(d, w=None):
    return R(d, 'a', 'a.o', w)


def body_hw(y, wide=1.0):
    """Half width of the shared body silhouette at height y (approximate, a touch outside it)."""
    table = [(350, 0), (356, 50), (362, 70), (380, 94), (410, 110), (440, 120), (480, 127), (520, 125), (545, 120), (570, 108), (592, 86), (604, 30)]
    for (y0, w0), (y1, w1) in zip(table, table[1:]):
        if y0 <= y <= y1:
            return (w0 + (w1 - w0) * (y - y0) / (y1 - y0)) * wide + 3
    return 3


def torso_band(y0, y1, steps=6, out=0.0):
    """Closed shape that hugs the body between heights y0 and y1."""
    L = [(300 - body_hw(y0 + (y1 - y0) * i / steps) - out, y0 + (y1 - y0) * i / steps) for i in range(steps + 1)]
    R_ = [(600 - x, y) for x, y in L][::-1]
    return smooth_closed(L + R_, 0.5)


def hats():
    x, y = HAT0
    H_ = {}
    # bow on one side of the head
    l = smooth_closed([(0, 0), (-34, -28), (-54, -10), (-52, 16), (-32, 26)], 1.0)
    bow = [cb(l), cb(mirror_d(l, 0)), R(ellipse(-30, -6, 8, 4.5, -30), 'c.l', o=0.8), R(ellipse(30, -6, 8, 4.5, 30), 'c.l', o=0.8),
           cb(ellipse(0, 0, 13, 14)), R(ellipse(-3, -4, 4, 3), 'c.l', o=0.8)]
    H_['ph_bow'] = shift(rotate(bow, 18), x + 72, y + 26)
    # crown
    pts = [(-62, 0), (-70, -58), (-36, -26), (0, -72), (36, -26), (70, -58), (62, 0)]
    crown = [cb(smooth_closed(pts, 0.25)), R(rrect(-62, -14, 124, 18, 8), 'c.s', 'c.o', 3.5),
             R(circle(0, -72, 8), 'a', 'a.o', 3), R(circle(-70, -58, 6), 'a', 'a.o', 3), R(circle(70, -58, 6), 'a', 'a.o', 3),
             R(heart(0, -24, 13), 'a', 'a.o', 3), R(ellipse(-38, -14, 10, 4, -10), 'c.l', o=0.8)]
    H_['ph_crown'] = shift(crown, x, y + 8)
    # tiara
    t = [R(smooth_open([(-74, 8), (-40, -14), (0, -22), (40, -14), (74, 8)]), None, 'c.o', 9), R(smooth_open([(-74, 8), (-40, -14), (0, -22), (40, -14), (74, 8)]), None, 'c', 5)]
    t += [cb(star(0, -44, 22, 0.5, 5, -90, 0.25), 3.5), cb(star(-40, -30, 12, 0.5, 5, -90, 0.25), 3), cb(star(40, -30, 12, 0.5, 5, -90, 0.25), 3),
          R(circle(0, -44, 6), 'a')]
    H_['ph_tiara'] = shift(t, x, y + 18)
    # party hat, a little tilted
    cone = smooth_closed([(-46, 0), (0, -120), (46, 0)], 0.15)
    party = [cb(cone)]
    for k in (0.3, 0.6):
        yy = -120 * (1 - k)
        hw = 46 * k
        party.append(R(smooth_open([(-hw + 2, yy + 6), (0, yy - 2), (hw - 2, yy + 6)]), None, 'a', 9))
    party += [R(smooth_open([(-48, 0), (0, 10), (48, 0)]), None, 'c.o', 10), R(smooth_open([(-48, 0), (0, 10), (48, 0)]), None, 'a', 6),
              ab(wobble_circle(0, -126, 17, 8, 0.15, 2)), R(ellipse(-16, -60, 6, 16, 18), 'c.l', o=0.7)]
    H_['ph_party'] = shift(rotate(party, 14), x + 14, y + 12)
    # flower crown
    fc = [R(smooth_open([(-112, 34), (-70, 4), (0, -8), (70, 4), (112, 34)]), None, '#5FA36B', 6)]
    for i, (fx, fy) in enumerate([(-104, 28), (-70, 6), (-34, -4), (0, -8), (34, -4), (70, 6), (104, 28)]):
        col = 'c' if i % 2 == 0 else 'a'
        fc += [R(flower(fx, fy, 30, 5), col, col + '.o', 2.5), R(circle(fx, fy, 6), '#FFE27A', '#D69A2A', 2)]
        if i < 6:
            fc.append(R(ellipse(fx + 18, fy + 10, 9, 5, 20), '#8ACB6A', '#4E9A63', 2))
    H_['ph_flowers'] = shift(fc, x, y + 16)
    # top hat
    top = [cb(ellipse(0, 0, 70, 16)), cb(smooth_closed([(-40, 0), (-44, -86), (44, -86), (40, 0)], 0.2)),
           R(smooth_closed([(-41, -16), (-42, -34), (42, -34), (41, -16)], 0.2), 'a', 'a.o', 3), cb(ellipse(0, -86, 44, 11)),
           R(ellipse(-24, -60, 6, 18), 'c.l', o=0.6)]
    H_['ph_tophat'] = shift(rotate(top, -8), x - 6, y + 10)
    # witch hat
    wt = [cb(ellipse(0, 0, 94, 20)), cb(smooth_closed([(-50, -4), (-14, -80), (20, -128), (50, -140), (30, -110), (22, -70), (50, -4)], 0.7)),
          R(smooth_closed([(-48, -8), (-44, -26), (46, -26), (48, -8)], 0.3), 'a', 'a.o', 3), R(star(18, -46, 12, 0.45), '#FFE27A', '#D69A2A', 2.5)]
    H_['ph_witch'] = shift(wt, x, y + 10)
    # sun hat with a ribbon
    sun = [cb(ellipse(0, 0, 118, 30)), R(ellipse(0, 4, 100, 18), 'c.s', o=0.7), cb(smooth_closed([(-56, 0), (-52, -46), (0, -64), (52, -46), (56, 0)], 0.8)),
           R(smooth_closed([(-56, -4), (-54, -22), (54, -22), (56, -4)], 0.5), 'a', 'a.o', 3),
           R(flower(46, -14, 30, 5), 'a', 'a.o', 2.5), R(circle(46, -14, 6), '#FFE27A')]
    H_['ph_sunhat'] = shift(sun, x, y + 18)
    # beret on the side
    ber = [cb(smooth_closed([(-74, 6), (-70, -28), (-20, -50), (50, -40), (80, -10), (64, 10)], 1.0)), R(smooth_open([(-66, 6), (0, 14), (66, 8)]), None, 'c.o', 9),
           R(smooth_open([(-66, 6), (0, 14), (66, 8)]), None, 'c.s', 5), R(smooth_open([(-6, -50), (0, -64)]), None, 'c.o', 6), R(ellipse(-30, -26, 16, 6, -14), 'c.l', o=0.7)]
    H_['ph_beret'] = shift(rotate(ber, -12), x - 22, y + 16)
    return {k: grow(v, 1.22, x, y) for k, v in H_.items()}


def glasses():
    lx, ey = EYE0
    rx = 600 - lx
    G = {}

    def pair(fn):
        return fn(lx) + fn(rx)

    bridge = lambda: [R(smooth_open([(lx + 34, ey - 6), (300, ey - 14), (rx - 34, ey - 6)]), None, 'c.o', 9),
                      R(smooth_open([(lx + 34, ey - 6), (300, ey - 14), (rx - 34, ey - 6)]), None, 'c', 5)]
    G['pg_heart'] = pair(lambda x: [R(heart(x, ey - 2, 44), '#FFD6E6', 'c', 9, o=None), R(heart(x, ey - 2, 44), None, 'c.o', 2.5),
                                    R(ellipse(x - 18, ey - 18, 9, 5, -30), '#FFFFFF', o=0.7)]) + bridge()
    for s in G['pg_heart']:
        if s.get('f') == '#FFD6E6': s['o'] = 0.45
    G['pg_round'] = pair(lambda x: [R(circle(x, ey, 38), '#FFFFFF', None, o=0.25), R(circle(x, ey, 38), None, 'c.o', 9), R(circle(x, ey, 38), None, 'c', 5),
                                    R(ellipse(x - 16, ey - 16, 8, 4, -35), '#FFFFFF', o=0.8)]) + bridge()
    G['pg_star'] = pair(lambda x: [R(star(x, ey, 50, 0.55, 5, -90, 0.35), 'c', 'c.o', 4), R(star(x, ey + 2, 34, 0.55, 5, -90, 0.35), '#3A3340', o=0.82),
                                   R(ellipse(x - 12, ey - 10, 8, 4, -35), '#FFFFFF', o=0.7)]) + bridge()
    G['pg_sun'] = pair(lambda x: [R(rrect(x - 44, ey - 30, 88, 62, 26), '#3A3340', 'c', 8), R(rrect(x - 44, ey - 30, 88, 62, 26), None, 'c.o', 2.5),
                                  R(smooth_open([(x - 26, ey - 12), (x - 12, ey - 20)]), None, '#FFFFFF', 5, o=0.6)]) + bridge()
    return G


def necks():
    x, y = NECK0
    N = {}
    band = smooth_closed([(218, y - 8), (300, y + 14), (382, y - 8), (384, y + 10), (300, y + 34), (216, y + 10)], 0.8)
    N['pn_collar'] = [cb(band), R(smooth_open([(226, y + 4), (300, y + 24), (374, y + 4)]), None, 'c.l', 3, o=0.7),
                      R(circle(300, y + 46, 18), '#FFD86E', '#C9962E', 4), R(heart(300, y + 46, 9), '#F2B83E'), R(ellipse(293, y + 38, 5, 3), '#FFFFFF', o=0.8)]
    N['pn_bell'] = [cb(band), R(smooth_closed([(282, y + 56), (284, y + 32), (300, y + 22), (316, y + 32), (318, y + 56)], 0.6), 'a', 'a.o', 4),
                    R(rrect(278, y + 52, 44, 9, 4), 'a.s', 'a.o', 3), R(circle(300, y + 64, 5), 'a.o'), R(ellipse(292, y + 36, 4, 7, 20), '#FFFFFF', o=0.7)]
    l = smooth_closed([(300, y + 14), (262, y - 10), (244, y + 6), (246, y + 34), (264, y + 40)], 1.0)
    N['pn_bowtie'] = [cb(l), cb(mirror_d(l)), cb(rrect(288, y + 2, 24, 26, 9)), R(ellipse(262, y + 8, 7, 4, -20), 'c.l', o=0.8)]
    N['pn_bandana'] = [cb(smooth_closed([(216, y - 6), (300, y + 10), (384, y - 6), (360, y + 30), (300, y + 82), (240, y + 30)], 0.35), pat=True),
                       R(smooth_open([(218, y - 2), (300, y + 16), (382, y - 2)]), None, 'c.o', 4), R(circle(268, y + 30, 5) + ' ' + circle(330, y + 34, 5) + ' ' + circle(300, y + 56, 5), 'c.l')]
    pearls = []
    for i in range(11):
        a = math.radians(200 - i * 22)
        px, py = 300 + math.cos(a) * 84, y + 2 - math.sin(a) * 26
        pearls += [R(circle(px, py, 10), 'c', 'c.o', 2.5), R(circle(px - 3, py - 3, 3), '#FFFFFF', o=0.85)]
    N['pn_pearls'] = pearls
    N['pn_scarf'] = [cb(smooth_closed([(208, y - 14), (300, y + 8), (392, y - 14), (398, y + 18), (300, y + 44), (202, y + 18)], 0.8), pat=True),
                     cb(smooth_closed([(330, y + 26), (376, y + 26), (384, y + 104), (344, y + 108)], 0.5), pat=True),
                     R(smooth_open([(346, y + 98), (350, y + 112)]) + ' ' + smooth_open([(362, y + 98), (366, y + 112)]) + ' ' + smooth_open([(378, y + 96), (382, y + 110)]), None, 'c.o', 4)]
    chain = smooth_open([(224, y + 2), (262, y + 22), (300, y + 30), (338, y + 22), (376, y + 2)])
    N['pn_locket'] = [R(chain, None, '#C9962E', 6), R(chain, None, '#FFD86E', 3),
                      R(heart(300, y + 52, 26), 'c', 'c.o', 4), R(heart(300, y + 52, 15), 'c.l', o=0.6),
                      R(circle(300, y + 30, 6), '#FFD86E', '#C9962E', 2.5), R(ellipse(288, y + 42, 6, 3.5, -30), '#FFFFFF', o=0.8)]
    lei = []
    for i in range(10):
        a = math.radians(205 - i * 25)
        px, py = 300 + math.cos(a) * 88, y + 4 - math.sin(a) * 30
        col = 'c' if i % 2 == 0 else 'a'
        lei += [R(flower(px, py, 30, 5, i * 17), col, col + '.o', 2.5), R(circle(px, py, 5), '#FFE27A')]
    N['pn_lei'] = lei
    return N


def bodies():
    B = {}
    sw = torso_band(360, 546, 8, 3)
    B['pb_sweater'] = [cb(sw, pat=True), R(torso_band(520, 546, 4, 4), 'c.s', 'c.o', 3.5)] + \
        [R(smooth_open([(300 + k * 18, 524), (300 + k * 18 + (2 if k > 0 else -2), 544)]), None, 'c.o', 2.5, o=0.5) for k in range(-6, 7)] + \
        [R(heart(300, 446, 26), 'a', 'a.o', 3)]
    tee = torso_band(360, 520, 7, 3)
    B['pb_tee'] = [cb(tee, pat=True), R(smooth_open([(180, 512), (300, 522), (420, 512)]), None, 'c.o', 3),
                   R(star(300, 446, 30, 0.5, 5, -90, 0.3), 'a', 'a.o', 3)]
    # dress: bodice then a flared skirt to the feet
    skirt = [(300 - body_hw(470) - 3, 470), (300 - body_hw(520) - 14, 520), (300 - 156, 588), (300, 598)]
    sk = smooth_closed(skirt + [(600 - x, y) for x, y in skirt[:-1]][::-1], 0.6)
    B['pb_dress'] = [cb(sk, pat=True), cb(torso_band(362, 480, 6, 3), pat=True),
                     R(smooth_open([(300 - body_hw(476), 476), (300, 486), (300 + body_hw(476), 476)]), None, 'a', 10),
                     R(heart(300, 482, 12), 'a', 'a.o', 2.5)] + \
                    [R(smooth_open([(300 + k * 34, 500), (300 + k * 46, 590)]), None, 'c.s', 4, o=0.8) for k in (-2, -1, 1, 2)]
    tutu = []
    for layer, (yy, spread, col) in enumerate(((560, 168, 'c.l'), (548, 150, 'c'))):
        pts = []
        n = 14
        for i in range(n + 1):
            t = i / n
            xx = 300 - spread + 2 * spread * t
            pts.append((xx, yy + (14 if i % 2 else -2) + 10 * math.sin(t * math.pi)))
        top = [(300 + body_hw(510) + 4, 504), (300 - body_hw(510) - 4, 504)]
        tutu.append(R(smooth_closed(pts + top, 0.6), col, 'c.o', 3.5))
    tutu += [R(torso_band(492, 516, 3, 5), 'a', 'a.o', 3.5)]
    B['pb_tutu'] = tutu
    # overalls: bib, straps, pants
    pants = torso_band(500, 600, 6, 4)
    B['pb_overalls'] = [cb(pants, pat=True), cb(rrect(244, 420, 112, 96, 18), pat=True),
                        R(smooth_open([(252, 428), (238, 360)]), None, 'c.o', 16), R(smooth_open([(252, 428), (238, 360)]), None, 'c', 10),
                        R(smooth_open([(348, 428), (362, 360)]), None, 'c.o', 16), R(smooth_open([(348, 428), (362, 360)]), None, 'c', 10),
                        R(circle(258, 436, 7) + ' ' + circle(342, 436, 7), 'a', 'a.o', 2.5), R(rrect(276, 448, 48, 34, 10), 'c.s', 'c.o', 3)]
    rc = torso_band(360, 580, 8, 6)
    B['pb_raincoat'] = [cb(rc), R(smooth_open([(300, 380), (300, 580)]), None, 'c.o', 4),
                        R(circle(286, 420, 6) + ' ' + circle(286, 470, 6) + ' ' + circle(286, 520, 6), 'a', 'a.o', 2.5),
                        cb(smooth_closed([(226, 364), (300, 400), (374, 364), (380, 392), (300, 430), (220, 392)], 0.8)),
                        R(ellipse(228, 460, 12, 40, 10), 'c.l', o=0.5)]
    ring = ellipse(300, 548, 168, 50)
    B['pb_floatie'] = [R(ellipse(300, 556, 172, 54), 'c', 'c.o', LW), R(ellipse(300, 540, 128, 26), 'c.s', 'c.o', 3)] + \
                      [R(ellipse(300 + dx, 556 + dy, 26, 16, rot), 'a', 'a.o', 3) for dx, dy, rot in ((-140, -4, 70), (0, 44, 0), (140, -4, -70))] + \
                      [R(ellipse(220, 530, 34, 8, -12), '#FFFFFF', o=0.6)]
    return B


def backs():
    K = {}
    fl = smooth_closed([(256, 420), (200, 330), (120, 270), (66, 268), (60, 330), (110, 400), (220, 446)], 1.0)
    fl2 = smooth_closed([(256, 450), (170, 476), (112, 540), (150, 580), (210, 556), (250, 490)], 1.0)
    vein = smooth_open([(240, 424), (150, 330), (84, 296)])
    K['pk_fairy'] = [R(fl, 'c.l', 'c', 4, o=0.9), R(fl2, 'c.l', 'c', 4, o=0.9), R(mirror_d(fl), 'c.l', 'c', 4, o=0.9), R(mirror_d(fl2), 'c.l', 'c', 4, o=0.9),
                     R(vein + ' ' + mirror_d(vein), None, 'c', 3, o=0.8),
                     R(circle(100, 310, 7) + ' ' + circle(136, 350, 5) + ' ' + circle(500, 310, 7) + ' ' + circle(464, 350, 5) + ' ' + circle(160, 530, 5) + ' ' + circle(440, 530, 5), '#FFFFFF')]
    an = []
    for i in range(5):
        tip = (70 + i * 14, 280 + i * 44)
        d = smooth_closed([(256, 410 + i * 12), (190 - i * 6, 320 + i * 34), tip, (tip[0] + 6, tip[1] + 34), (150, 420 + i * 22), (230, 450 + i * 6)], 0.9)
        an.append(d)
    an = an[::-1]
    K['pk_angel'] = [R(d, '#FFFFFF', '#C9C3D9', 3.5) for d in an] + [R(mirror_d(d), '#FFFFFF', '#C9C3D9', 3.5) for d in an] + \
                    [R(smooth_open([(200, 360), (120, 300)]) + ' ' + mirror_d(smooth_open([(200, 360), (120, 300)])), None, '#E6E1F0', 4)]
    b1 = smooth_closed([(262, 420), (210, 310), (120, 250), (56, 270), (70, 370), (180, 440)], 1.0)
    b2 = smooth_closed([(262, 446), (180, 466), (110, 540), (150, 600), (220, 580), (256, 500)], 1.0)
    K['pk_butterfly'] = [cb(b1), ab(b2), cb(mirror_d(b1)), ab(mirror_d(b2)),
                         R(circle(116, 310, 24) + ' ' + circle(484, 310, 24) + ' ' + circle(160, 550, 14) + ' ' + circle(440, 550, 14), '#FFFFFF', o=0.8),
                         R(circle(116, 310, 11) + ' ' + circle(484, 310, 11), 'a', o=0.9)]
    bt = smooth_closed([(256, 420), (200, 320), (120, 270), (60, 280), (90, 330), (52, 360), (100, 382), (80, 430), (150, 430), (190, 456)], 0.6)
    K['pk_bat'] = [cb(bt), cb(mirror_d(bt)), R(smooth_open([(246, 420), (160, 330), (76, 290)]) + ' ' + mirror_d(smooth_open([(246, 420), (160, 330), (76, 290)])), None, 'c.o', 3.5)]
    cape = smooth_closed([(220, 380), (300, 372), (380, 380), (470, 560), (500, 640), (300, 646), (100, 640), (130, 560)], 0.8)
    K['pk_cape'] = [R(cape, 'c', 'c.o', LW, pat=True), R(smooth_closed([(116, 604), (300, 624), (484, 604), (500, 638), (300, 646), (100, 638)], 0.8), 'a', 'a.o', 3)]
    return K


SLOTS = [('hat', hats), ('glasses', glasses), ('neck', necks), ('body', bodies), ('back', backs)]
DEFAULT = {'ph_bow': 3, 'ph_crown': 9, 'ph_tiara': 18, 'ph_party': 16, 'ph_flowers': 3, 'ph_tophat': 23, 'ph_witch': 19, 'ph_sunhat': 1,
           'ph_beret': 5, 'pg_heart': 4, 'pg_round': 21, 'pg_star': 9, 'pg_sun': 3, 'pn_collar': 5, 'pn_bell': 5, 'pn_bowtie': 16,
           'pn_bandana': 15, 'pn_pearls': 0, 'pn_scarf': 12, 'pn_locket': 4, 'pn_lei': 3, 'pb_sweater': 18, 'pb_tee': 15, 'pb_dress': 3,
           'pb_tutu': 3, 'pb_overalls': 16, 'pb_raincoat': 9, 'pb_floatie': 5, 'pk_fairy': 11, 'pk_angel': 0, 'pk_butterfly': 8,
           'pk_bat': 20, 'pk_cape': 5}
ACCENT = {'ph_crown': '#FF8FB8', 'ph_party': '#FFFFFF', 'ph_flowers': '#FFFFFF', 'ph_tophat': '#F45C9A', 'ph_witch': '#FFE27A',
          'ph_sunhat': '#FF9EC0', 'pn_bell': '#FFD86E', 'pn_lei': '#FFE27A', 'pb_sweater': '#FFFFFF',
          'pb_tee': '#FFE27A', 'pb_dress': '#FFFFFF', 'pb_tutu': '#FFE27A', 'pb_overalls': '#FFE27A', 'pb_raincoat': '#FFFFFF',
          'pb_floatie': '#FFFFFF', 'pk_butterfly': '#FFE27A', 'pk_cape': '#FFE27A', 'ph_tiara': '#FF8FB8'}


def wear():
    out = {}
    for slot, fn in SLOTS:
        for id_, shapes in fn().items():
            out[id_] = {'slot': slot, 'shapes': shapes, 'default': DEFAULT.get(id_, 3), 'accent': ACCENT.get(id_, '#FFFFFF')}
            if any(s.get('pat') for s in shapes): out[id_]['patternable'] = True
    return out


# Box shown in a wardrobe thumbnail for each slot, in pet coordinates (x, y, w, h).
THUMB = {'hat': [130, -10, 340, 330], 'glasses': [150, 150, 300, 260], 'neck': [160, 270, 280, 280], 'body': [110, 320, 380, 330],
         'back': [40, 200, 520, 460]}

# ---------------------------------------------------------------- care props (140 x 140 box, like the Pet Vet tools)


def foods():
    F = {}
    c = '#9CCBFF'
    fish = smooth_closed([(20, 70), (50, 44), (88, 42), (110, 62), (126, 46), (128, 94), (110, 78), (88, 98), (50, 96)], 0.9)
    F['fish'] = [blob(fish, c), flat(ellipse(70, 80, 26, 8), light(c), 0.7), flat(circle(44, 64, 6), '#3A2633'), flat(circle(42, 62, 2), '#FFFFFF'),
                 line(smooth_open([(74, 50), (80, 70), (74, 90)]), outline(c), 3.5)]
    b = '#F6E3C4'
    bone = [blob(' '.join([circle(30, 52, 18), circle(30, 86, 18), circle(110, 52, 18), circle(110, 86, 18)]), b),
            blob(rrect(28, 52, 84, 34, 14), b), flat(rrect(34, 58, 72, 22, 10), b), flat(ellipse(70, 62, 26, 5), '#FFFFFF', 0.7)]
    F['bone'] = bone
    o = '#FFA24C'
    F['carrot'] = [blob(smooth_closed([(52, 40), (90, 44), (60, 128), (54, 124)], 0.7), o),
                   line(smooth_open([(58, 62), (72, 64)]) + ' ' + smooth_open([(60, 84), (72, 86)]), outline(o), 3.5),
                   blob(smooth_closed([(68, 42), (58, 10), (74, 26), (84, 6), (88, 30), (106, 18), (90, 44)], 0.7), '#6CCB8B')]
    r = '#F2546A'
    F['berry'] = [blob(smooth_closed([(70, 128), (32, 84), (36, 50), (70, 40), (104, 50), (108, 84)], 1.0), r)] + \
                 [flat(ellipse(x, y, 2.6, 4), '#FFE27A') for x, y in ((54, 66), (86, 66), (70, 82), (52, 92), (88, 92), (70, 106), (62, 56), (78, 56))] + \
                 [blob(smooth_closed([(70, 48), (40, 34), (58, 30), (70, 14), (82, 30), (100, 34)], 0.7), '#6CCB8B'), flat(ellipse(50, 60, 6, 12, 20), '#FFFFFF', 0.5)]
    k = '#E9B27A'
    F['cookie'] = [blob(wobble_circle(70, 70, 54, 12, 0.05, 3), k), flat(ellipse(52, 50, 16, 7, -25), light(k), 0.7)] + \
                  [flat(wobble_circle(x, y, 8, 6, 0.2, x), '#6B4537') for x, y in ((50, 74), (82, 50), (90, 86), (66, 100), (60, 52))]
    p = '#FF9EC0'
    F['cupcake'] = [blob(poly([(32, 74), (108, 74), (96, 128), (44, 128)]), '#9CCBFF'),
                    line(smooth_open([(56, 78), (60, 126)]) + ' ' + smooth_open([(84, 78), (80, 126)]) + ' ' + smooth_open([(70, 78), (70, 126)]), outline('#9CCBFF'), 3),
                    blob(smooth_closed([(26, 78), (32, 52), (56, 40), (70, 22), (84, 40), (108, 52), (114, 78)], 1.0), p),
                    flat(ellipse(54, 54, 12, 6, -20), '#FFFFFF', 0.7), blob(circle(70, 18, 11), '#E8475A'), flat(circle(66, 14, 3.5), '#FFFFFF', 0.8)]
    return F


def toys():
    T = {}
    c = '#FF9EC0'
    T['ball'] = [blob(circle(70, 70, 50), c), flat(smooth_closed([(26, 52), (70, 66), (114, 52), (110, 76), (70, 88), (30, 76)], 0.8), '#FFE27A'),
                 line(smooth_open([(26, 52), (70, 66), (114, 52)]), outline(c), 3), line(smooth_open([(30, 76), (70, 88), (110, 76)]), outline(c), 3),
                 shine(48, 40, 12)]
    T['feather'] = VP.t_feather()[0]
    y = '#C9B6FF'
    yarn = [blob(circle(70, 74, 46), y)]
    for r in (14, 26, 38):
        yarn.append(line(smooth_open(arc(64, 70, r, r * 0.9, -40, 150, 8)), shade(y), 3.5))
    yarn.append(line(smooth_open(arc(80, 82, 30, 34, 170, 300, 6)), shade(y), 3.5))
    yarn += [line(smooth_open([(110, 96), (126, 118), (112, 132), (130, 138)]), outline(y), 4), shine(52, 50, 10)]
    T['yarn'] = yarn
    return T


def care():
    P = {}
    P['sponge'], _ = VP.t_sponge()
    P['shower'], _ = VP.t_shower()
    P['brush'], _ = VP.t_brush()
    P['towel'], _ = VP.t_towel()
    P.update(foods())
    P.update(toys())
    c = '#FF9EC0'
    # a pillow bed under the pet and a blanket over it (pet coordinates)
    P['bed'] = [blob(ellipse(300, 610, 230, 58), mixh(c, '#C9B6FF', 0.4)), flat(ellipse(300, 596, 196, 36), light(mixh(c, '#C9B6FF', 0.4)), 0.8)]
    blanket = smooth_closed([(150, 470), (300, 450), (450, 470), (470, 600), (440, 650), (300, 660), (160, 650), (130, 600)], 0.8)
    P['blanket'] = [blob(blanket, '#A9D8FF'), flat(smooth_closed([(150, 470), (300, 450), (450, 470), (446, 500), (300, 482), (154, 500)], 0.8), '#FFFFFF', 0.9)] + \
                   [flat(star(x, y, 13, 0.45), '#FFE27A') for x, y in ((220, 560), (320, 600), (400, 540), (260, 630), (380, 630))]
    P['foam'] = [S(wobble_circle(0, 0, 24, 8, 0.12, 1), '#FFFFFF', '#BFD9F2', 3), S(circle(-14, -14, 12), '#FFFFFF', '#BFD9F2', 3),
                 S(circle(16, -10, 10), '#FFFFFF', '#BFD9F2', 3), flat(circle(-6, -6, 4), '#E3F1FF')]
    P['bowl'] = [blob(smooth_closed([(-70, -10), (70, -10), (54, 30), (-54, 30)], 0.5), '#FF9EC0'), flat(ellipse(0, -10, 70, 14), '#C98A55'),
                 flat(ellipse(0, -12, 56, 9), '#E9B27A'), flat(rrect(-30, 4, 60, 12, 6), '#FFFFFF', 0.6)]
    return P


# ---------------------------------------------------------------- small path helpers

def mirror_d(d, cx=300):
    from geom import xform
    return xform(d, sx=-1, sy=1, ox=cx, oy=0)


def shift(shapes, dx, dy):
    from geom import xform
    out = []
    for s in shapes:
        s = dict(s)
        s['d'] = xform(s['d'], 1, 1, 0, 0, dx, dy)
        out.append(s)
    return out


def grow(shapes, k, ox, oy):
    from geom import xform
    out = []
    for s in shapes:
        s = dict(s)
        s['d'] = xform(s['d'], k, k, ox, oy)
        if 'w' in s: s['w'] = round(s['w'] * k, 2)
        out.append(s)
    return out


def rotate(shapes, deg):
    out = []
    for s in shapes:
        s = dict(s)
        s['d'] = AN.rotate_path(s['d'], 0, 0, deg)
        out.append(s)
    return out


def anchors(k, a):
    ex, ey = a['eye']
    return {'hat': list(HAT.get(k, (300, 134, 0, 1.0))), 'eyes': [ex, ey], 'wide': WIDE.get(k, 1.0)}


def build():
    vet = AN.make_all()
    more = extra_animals()
    allp = dict(vet)
    allp.update(more)
    animals = {}
    for k in ORDER:
        a = allp[k]
        animals[k] = {'back': a['back'], 'torso': a['torso'], 'limbs': a['limbs'], 'head': a['head'], 'front': a['front'],
                      'blush': a['blush'], 'brows': a['brows'], 'eyes': a['eyes'], 'mouths': a['mouths'],
                      'eye': a['eye'], 'mouth': a['mouth'], 'fur': a['fur'], 'anchors': anchors(k, a)}
    return {'size': [W, H], 'order': ORDER, 'animals': animals, 'wear': wear(), 'slots': [s for s, _ in SLOTS],
            'thumbs': THUMB, 'props': care()}
