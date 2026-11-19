"""Hair: back pieces (behind the body) and front pieces (bangs and crown, over the face)."""
import math
from geom import *

LW = 4.5

def clumps(spec, y_notch=232):
    """spec: list of (x_center, width, tip_y, lean). Builds the fringe's bottom edge left->right with
    rounded clump tips. lean>0 tips point right, <0 left."""
    pts = []
    for i, (cx, w, ty, lean) in enumerate(spec):
        x0, x1 = cx - w / 2, cx + w / 2
        ny = y_notch if not (0 < i) else y_notch
        if i == 0:
            pts.append((x0, ty - 18))
        pts += [(cx - w * 0.28 + lean * 0.4, ty - 4), (cx + lean, ty + 3), (cx + w * 0.3 + lean * 0.6, ty - 6)]
        if i < len(spec) - 1:
            nx = x1
            pts.append((nx, min(ty, spec[i + 1][2]) - 22 - spec[i][1] * 0.08))
        else:
            pts.append((x1, ty - 18))
    return pts

def even_clumps(n=5, x0=186, x1=414, tip=262, sag=10, lean=0):
    w = (x1 - x0) / n
    spec = []
    for i in range(n):
        cx = x0 + w * (i + 0.5)
        k = (cx - 300) / 114
        l = lean if lean else (-7 * k)
        spec.append((cx, w, tip + sag * (1 - k * k) - sag, l))
    return clumps(spec)

def hair_front(id_, bangs, side_len=388, side_out=146, side_in=188, crown=124, ring=True, strands=True,
               extra=None, extra_back=None, locks=True, bulge=0):
    """bangs: bottom edge of the fringe, left to right. side_len: how far down the face-framing locks go."""
    if locks:
        left_lock = [(side_in - 4, side_len - 34), (side_in - 14, side_len - 4), (side_out + 6, side_len - 14), (side_out - 4 - bulge, 312)]
    else:
        left_lock = [(side_out + 6, 300), (side_out - 2 - bulge, 270)]
    crown_l = [(side_out - 6 - bulge, 236), (176 - bulge * 0.5, 168), (234, 134), (300, crown)]
    crown_r = mirror_pts(crown_l)[::-1]
    right_lock = mirror_pts(left_lock)[::-1]
    pts = left_lock + crown_l + crown_r[1:] + right_lock
    if locks:
        pts += [(600 - side_in + 2, 302), (bangs[-1][0] - 2, bangs[-1][1] + 14)]
    pts += list(reversed(bangs))
    if locks:
        pts += [(bangs[0][0] + 2, bangs[0][1] + 14), (side_in - 2, 302)]
    S = [{'d': smooth_closed(pts), 'f': 'c', 's': 'c.o', 'w': LW}]
    # shading inside the fringe, following its edge
    if locks:
        for sx in (1, -1):
            S.append({'d': smooth_open([(300 + sx * (300 - side_out - 4), 300), (300 + sx * (300 - side_out - 2), side_len - 24)]), 's': 'c.s', 'w': 9, 'o': 0.5})
    if ring:
        for a0, a1 in ((-158, -122), (-112, -80), (-70, -42), (-32, -18)):
            pts2 = [(300 + math.cos(math.radians(a)) * 116, 200 + math.sin(math.radians(a)) * 50) for a in range(a0, a1 + 1, 4)]
            S.append({'d': smooth_open(pts2), 's': 'c.l', 'w': 10, 'o': 0.95})
    if strands:
        for x0, x1 in ((240, 226), (280, 274), (322, 328), (360, 374)):
            S.append({'d': smooth_open([(x0, 168), (x1, 226)]), 's': 'c.o', 'w': 3, 'o': 0.35})
    if extra:
        S += extra
    sh = [(x, y + 12) for x, y in bangs]
    shadow = {'d': smooth_closed([(bangs[0][0], 210)] + sh + [(bangs[-1][0], 210)]), 'f': 'skin.s', 'o': 0.75}
    layers = [{'z': 38, 'shapes': [shadow]}, {'z': 50, 'shapes': S}]
    if extra_back:
        layers.append({'z': 9, 'shapes': extra_back})
    return {'id': id_, 'cat': 'hairFront', 'color': 'hair', 'layers': layers}

def ahoge():
    return [{'d': smooth_closed([(296, 128), (288, 96), (306, 70), (330, 74), (310, 84), (302, 104), (308, 128)], 0.8), 'f': 'c', 's': 'c.o', 'w': LW}]

def fronts():
    out = []
    out.append(hair_front('hf_classic', even_clumps(5)))
    out.append(hair_front('hf_wispy', even_clumps(7, tip=266, sag=8)))
    # side-swept: tips get lower toward the right
    spec = [(206, 44, 224, 8), (250, 48, 238, 10), (298, 54, 252, 12), (350, 56, 266, 12), (398, 40, 270, 6)]
    out.append(hair_front('hf_swept', clumps(spec)))
    # blunt straight fringe (hime cut) with long locks
    blunt = [(188, 246), (190, 256), (230, 258), (300, 260), (370, 258), (410, 256), (412, 246)]
    out.append(hair_front('hf_blunt', blunt, side_len=420, strands=True))
    # center part, forehead showing
    part = [(190, 300), (204, 250), (240, 206), (288, 186), (300, 196), (312, 186), (360, 206), (396, 250), (410, 300)]
    out.append(hair_front('hf_part', part, side_len=400))
    # curly bubbly fringe
    curly = []
    for i in range(7):
        x = 188 + i * 37.3
        curly += [(x, 236), (x + 10, 256), (x + 27, 256)]
    curly.append((414, 236))
    out.append(hair_front('hf_curly', curly, side_len=360, bulge=10))
    out.append(hair_front('hf_ahoge', even_clumps(5), extra=ahoge()))
    # short pixie with short locks
    out.append(hair_front('hf_pixie', even_clumps(4, tip=250), side_len=330, side_in=182))
    # big swoop to one side
    swoop = [(188, 268), (200, 236), (240, 228), (290, 230), (336, 240), (370, 262), (392, 286), (410, 290), (414, 260)]
    out.append(hair_front('hf_swoop', swoop))
    # little heart-shaped split in the middle
    heart_b = [(188, 248), (214, 262), (240, 256), (264, 262), (288, 248), (300, 236), (312, 248), (336, 262), (360, 256), (386, 262), (412, 248)]
    out.append(hair_front('hf_heart', heart_b))
    return out

def hair_back(id_, pts_left, extra=None, z=10, shadow=True, front=None):
    """pts_left: left half outline from top center down to bottom center (mirrored)."""
    S = []
    if pts_left:
        S.append({'d': sym(pts_left), 'f': 'c', 's': 'c.o', 'w': LW})
    if extra:
        S += extra
    if shadow:
        S.append({'d': ellipse(300, 330, 128, 110), 'f': 'c.s'})
    layers = [{'z': z, 'shapes': S}]
    if front:
        layers.append({'z': 33, 'shapes': front})
    return {'id': id_, 'cat': 'hairBack', 'color': 'hair', 'layers': layers}

def strand_lines(xs, y0, y1, w=3):
    return [{'d': smooth_open([(x, y0), (x + (x - 300) * 0.04, y1)]), 's': 'c.o', 'w': w, 'o': 0.4} for x in xs]

def tail(cx, top, bottom, width, curl=0, flip=1):
    """A hanging tail of hair (for twin tails), as a closed shape."""
    w = width
    pts = [(cx, top), (cx - flip * w * 0.55, top + 40), (cx - flip * w * 0.6, (top + bottom) / 2),
           (cx - flip * w * 0.3 + curl * flip, bottom - 30), (cx + flip * curl, bottom),
           (cx + flip * w * 0.25, bottom - 40), (cx + flip * w * 0.45, (top + bottom) / 2), (cx + flip * w * 0.35, top + 30)]
    return smooth_closed(pts)

def scrunchie(cx, cy, r=16):
    return [{'d': ellipse(cx, cy, r * 1.1, r * 0.8), 'f': 'a', 's': 'a.o', 'w': 3.5},
            {'d': smooth_open([(cx - r * 0.6, cy - 2), (cx, cy + 3), (cx + r * 0.6, cy - 2)]), 's': 'a.s', 'w': 3}]

def braid(cx, top, bottom, w=34, flip=1):
    S = []
    n = int((bottom - top) / (w * 0.8))
    for i in range(n):
        y = top + i * w * 0.8
        S.append({'d': ellipse(cx + (6 if i % 2 else -6) * flip, y + w * 0.45, w * 0.55, w * 0.5, 20 if i % 2 else -20), 'f': 'c', 's': 'c.o', 'w': 4})
    y = top + n * w * 0.8
    S.append({'d': tail(cx, y, y + 46, 26), 'f': 'c', 's': 'c.o', 'w': 4})
    S += scrunchie(cx, y + 4, 12)
    return S

def backs():
    out = []
    out.append(hair_back('hb_short', [(300, 140), (214, 150), (160, 206), (146, 290), (156, 380), (196, 420), (300, 430)]))
    out.append(hair_back('hb_bob', [(300, 140), (212, 150), (156, 206), (140, 300), (138, 400), (160, 452), (210, 456), (300, 446)]))
    out.append(hair_back('hb_long', [(300, 140), (210, 150), (156, 210), (140, 320), (138, 460), (144, 600), (170, 642), (206, 624), (236, 648), (270, 628), (300, 640)],
                         extra=strand_lines([176, 214], 430, 610)))
    wavy = [(300, 140), (210, 150), (156, 210), (138, 320)]
    for i, y in enumerate(range(360, 640, 40)):
        wavy.append((128 if i % 2 else 146, y))
    wavy += [(160, 650), (196, 630), (226, 652), (262, 632), (300, 648)]
    out.append(hair_back('hb_wavy', wavy))
    out.append(hair_back('hb_medium', [(300, 140), (210, 150), (156, 206), (140, 300), (138, 420), (122, 500), (150, 512), (190, 498), (230, 510), (300, 500)]))
    # big curly cloud
    cloud = [(300, 120), (240, 118), (196, 128), (164, 156), (140, 194), (124, 240), (118, 290), (120, 340),
             (112, 390), (118, 440), (136, 482), (170, 500), (210, 506), (250, 492), (300, 500)]
    out.append(hair_back('hb_curly', cloud,
                         extra=[{'d': both(circle(x, y, r)), 's': 'c.o', 'w': 3, 'o': 0.35, 'f': None} for x, y, r in ((150, 330, 16), (140, 420, 18), (186, 470, 14))]))
    # twin tails
    tl = [{'d': tail(140, 230, 600, 110, curl=-30, flip=1), 'f': 'c', 's': 'c.o', 'w': LW},
          {'d': tail(460, 230, 600, 110, curl=-30, flip=-1), 'f': 'c', 's': 'c.o', 'w': LW}]
    tl += strand_lines([126, 474], 300, 520)
    tl += scrunchie(156, 236) + scrunchie(444, 236)
    out.append(hair_back('hb_twintails', [(300, 140), (214, 150), (160, 206), (146, 290), (156, 380), (196, 420), (300, 430)], extra=tl))
    # buns on top
    buns = []
    for x in (186, 414):
        buns += [{'d': circle(x, 150, 52), 'f': 'c', 's': 'c.o', 'w': LW},
                 {'d': smooth_open([(x - 30, 140), (x, 118), (x + 30, 140)]), 's': 'c.l', 'w': 8, 'o': 0.9}]
    out.append(hair_back('hb_buns', [(300, 140), (214, 150), (160, 206), (146, 290), (156, 380), (196, 420), (300, 430)], extra=buns))
    # high ponytail swinging out to the right
    pony = [{'d': smooth_closed([(390, 140), (452, 150), (490, 220), (494, 320), (470, 420), (446, 470), (452, 400), (448, 300), (420, 210)]), 'f': 'c', 's': 'c.o', 'w': LW}]
    pony += scrunchie(398, 146, 18)
    out.append(hair_back('hb_pony', [(300, 140), (214, 150), (160, 206), (146, 290), (156, 380), (196, 420), (300, 430)], extra=pony))
    # braids in front of the shoulders
    out.append(hair_back('hb_braids', [(300, 140), (214, 150), (160, 206), (146, 290), (156, 380), (196, 420), (300, 430)],
                         front=braid(196, 390, 600, flip=1) + braid(404, 390, 600, flip=-1)))
    # ringlet drills
    drills = []
    for cx, fl in ((150, 1), (450, -1)):
        for i in range(5):
            y = 280 + i * 52
            drills.append({'d': ellipse(cx, y, 44 - i * 3, 30, 14 * fl), 'f': 'c', 's': 'c.o', 'w': 4})
            drills.append({'d': smooth_open([(cx - 30 + i * 2, y + 4), (cx, y + 14), (cx + 30 - i * 2, y + 4)]), 's': 'c.s', 'w': 6, 'o': 0.6})
    out.append(hair_back('hb_drills', [(300, 140), (214, 150), (160, 206), (146, 290), (156, 380), (196, 420), (300, 430)], extra=drills))
    # long + side bow-less half up
    out.append(hair_back('hb_xlong', [(300, 140), (210, 150), (152, 210), (132, 320), (128, 480), (126, 640), (134, 740), (180, 770), (230, 750), (300, 770)],
                         extra=strand_lines([168, 206], 440, 740)))
    return out
