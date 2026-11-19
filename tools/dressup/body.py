"""Base doll: body, head, and the anchor points every item is drawn against."""
from geom import *

LW = 4.5          # main outline width
# arm centerline (left arm); the right arm is its mirror
ARM_L = [(258, 448), (240, 478), (228, 512), (222, 542)]
ARM_W = 31
LEG_L = [(277, 556), (277, 620), (277, 670), (277, 708)]
LEG_W = 44
HAND_L = (221, 548)
HEAD_PTS = [(300, 150), (222, 160), (176, 200), (158, 262), (160, 330), (178, 378), (222, 410), (300, 424)]
TORSO_PTS = [(300, 426), (266, 430), (250, 444), (246, 474), (248, 508), (246, 540), (254, 568), (300, 576)]
EYE_L = (238, 326)
FEET_Y = 724
MOUTH = (300, 386)

def tube(ctrl, w, role, t0=0.0, t1=1.0, outline=None, lw=LW):
    pts = bez_seg(ctrl, t0, t1, 10)
    d = smooth_open(pts)
    out = []
    if outline:
        out.append({'d': d, 's': outline, 'w': w + 2 * lw})
    out.append({'d': d, 's': role, 'w': w})
    return out

def mtube(ctrl, w, role, t0=0.0, t1=1.0, outline=None, lw=LW):
    """Tube on both sides."""
    a = tube(ctrl, w, role, t0, t1, outline, lw)
    b = tube([(2 * CX - x, y) for x, y in ctrl], w, role, t0, t1, outline, lw)
    return a + b

def body_item():
    S = []
    # legs
    S += mtube(LEG_L, LEG_W, 'skin', outline='skin.o')
    # bare feet
    for x in (276, 324):
        S += [{'d': ellipse(x + (x - 300) * 0.15, FEET_Y, 25, 16), 'f': 'skin', 's': 'skin.o', 'w': LW}]
    # arms
    S += mtube(ARM_L, ARM_W, 'skin', outline='skin.o')
    for x, y in (HAND_L, (2 * CX - HAND_L[0], HAND_L[1])):
        S += [{'d': circle(x, y, 18), 'f': 'skin', 's': 'skin.o', 'w': LW}]
    # torso
    S += [{'d': sym(TORSO_PTS), 'f': 'skin', 's': 'skin.o', 'w': LW}]
    # neck shadow
    S += [{'d': rrect(284, 404, 32, 36, 12), 'f': 'skin.s'}]
    # the head and ears are the 'face' category (round2.py)
    # soft chin shade under the jaw is left out; the face reads cleaner without it.
    return {'id': 'body', 'cat': 'body', 'color': 'skin', 'layers': [{'z': 20, 'shapes': S}]}

def underwear_item():
    # simple white tank + bloomers, always worn under everything
    S = [{'d': sym([(300, 440), (276, 440), (262, 446), (250, 470), (250, 506), (247, 540), (250, 572), (262, 590), (282, 592), (300, 584)]), 'f': '#FFFFFF', 's': '#D2BCCB', 'w': 3.5}]
    S += [{'d': smooth_open([(252, 540), (300, 546), (348, 540)]), 's': '#E6D6E0', 'w': 3}]
    return {'id': 'under', 'cat': 'under', 'color': None, 'layers': [{'z': 21, 'shapes': S}]}
