from geom import *
from body import EYE_L, MOUTH

LASH = '#3D2433'

def eye_shapes(cx, cy, flip, style):
    """One eye. flip=1 for the doll's right eye (screen right)."""
    s = -1 if flip else 1  # s=1: outer corner is to the left
    def X(x): return cx - s * (cx - x) if False else (cx + (x - cx) * (1 if not flip else -1))
    def P(pts): return [(X(x), y) for x, y in pts]
    rx, ry = style.get('rx', 35), style.get('ry', 44)
    oy = style.get('oy', 4)
    S = []
    # white of the eye peeking around the iris
    S.append({'d': ellipse(cx, cy + oy, rx + 5, ry + 2), 'f': '#FFFFFF'})
    # iris with a vertical gradient
    S.append({'d': ellipse(cx, cy + oy, rx, ry), 'g': ['c.d', 'c.l']})
    S.append({'d': ellipse(cx, cy + oy + ry * 0.12, rx * 0.72, ry * 0.7), 'f': 'c', 'o': 0.85})
    # pupil
    pr = style.get('pupil', 0.48)
    if style.get('starPupil'):
        S.append({'d': star(cx, cy + oy + 4, rx * 0.5, 0.5, round_=0.4), 'f': 'c.d'})
    elif style.get('heartPupil'):
        S.append({'d': heart(cx, cy + oy + 2, rx * 0.46), 'f': 'c.d'})
    else:
        S.append({'d': ellipse(cx, cy + oy + 2, rx * pr, ry * pr * 1.05), 'f': 'c.d'})
    # bottom glow
    S.append({'d': ellipse(cx, cy + oy + ry * 0.62, rx * 0.55, ry * 0.2), 'f': 'c.l', 'o': 0.8})
    # highlights
    S.append({'d': ellipse(X(cx - rx * 0.32), cy + oy - ry * 0.38, rx * 0.34, ry * 0.3, -20 if not flip else 20), 'f': '#FFFFFF'})
    S.append({'d': circle(X(cx + rx * 0.38), cy + oy + ry * 0.3, rx * 0.14), 'f': '#FFFFFF'})
    if style.get('sparkle'):
        S.append({'d': star(X(cx + rx * 0.3), cy + oy - ry * 0.45, rx * 0.22, 0.3, 4), 'f': '#FFFFFF'})
    # upper lash: a thick crescent over the top of the eye with a flick at the outer corner
    top = cy + oy - ry - 4
    lid = style.get('lid', 0)  # sleepy lid drop
    t = top + lid
    lash = [(X(cx - rx - 10), cy + oy - ry * 0.25 + lid * 0.4), (X(cx - rx * 0.6), t + 2), (X(cx), t - 3),
            (X(cx + rx * 0.62), t + 2), (X(cx + rx + 6), cy + oy - ry * 0.3 + lid * 0.5),
            (X(cx + rx * 0.6), t + 10), (X(cx), t + 7), (X(cx - rx * 0.6), t + 11), (X(cx - rx - 2), cy + oy - ry * 0.12 + lid * 0.4)]
    if lid:
        # cover the top of the iris with skin
        S.append({'d': smooth_closed([(X(cx - rx - 8), cy + oy - ry * 0.25 + lid * 0.4), (X(cx), t - 30), (X(cx + rx + 6), cy + oy - ry * 0.3 + lid * 0.5),
                                      (X(cx + rx * 0.6), t + 8), (X(cx), t + 6), (X(cx - rx * 0.6), t + 9)]), 'f': 'skin'})
    S.append({'d': smooth_closed(lash), 'f': LASH})
    # outer flick
    fl = style.get('flick', 1)
    if fl:
        S.append({'d': smooth_closed([(X(cx - rx - 6), cy + oy - ry * 0.35 + lid * 0.4), (X(cx - rx - 22 * fl), cy + oy - ry * 0.62 + lid * 0.4),
                                      (X(cx - rx - 3), cy + oy - ry * 0.08 + lid * 0.4)], 0.6), 'f': LASH})
    if style.get('lashes'):
        for k in (0, 1):
            S.append({'d': smooth_open([(X(cx - rx * (0.2 + 0.45 * k)), t + 2), (X(cx - rx * (0.3 + 0.5 * k)), t - 10 - 2 * k)]), 's': LASH, 'w': 4})
    # lower lash tick
    S.append({'d': smooth_open([(X(cx - rx * 0.55), cy + oy + ry + 6), (X(cx - rx * 0.2), cy + oy + ry + 8)]), 's': LASH, 'w': 3, 'o': 0.5})
    return S

def eyes_item(id_, style, name=None):
    S = eye_shapes(EYE_L[0], EYE_L[1], False, style) + eye_shapes(600 - EYE_L[0], EYE_L[1], True, style)
    return {'id': id_, 'cat': 'eyes', 'color': 'eye', 'layers': [{'z': 40, 'shapes': S}]}

def closed_eyes_item():
    S = []
    for flip in (False, True):
        cx = EYE_L[0] if not flip else 600 - EYE_L[0]
        def X(x): return cx + (x - cx) * (-1 if flip else 1)
        S.append({'d': smooth_open([(X(cx - 32), EYE_L[1] + 14), (cx, EYE_L[1] + 30), (X(cx + 30), EYE_L[1] + 16)]), 's': LASH, 'w': 6})
        S.append({'d': smooth_open([(X(cx - 32), EYE_L[1] + 14), (X(cx - 44), EYE_L[1] + 4)]), 's': LASH, 'w': 5})
    return {'id': 'eyes_closed', 'cat': 'special', 'color': None, 'layers': [{'z': 40, 'shapes': S}]}

def mouth_item(id_, shapes):
    return {'id': id_, 'cat': 'mouth', 'color': None, 'layers': [{'z': 41, 'shapes': shapes}]}

ML = '#8C3E52'; MIN = '#C24A62'; TONGUE = '#FF8A9E'

def mouths():
    mx, my = MOUTH
    out = []
    out.append(mouth_item('m_smile', [{'d': smooth_open([(mx - 13, my - 2), (mx, my + 7), (mx + 13, my - 2)]), 's': ML, 'w': 4.5}]))
    out.append(mouth_item('m_open', [
        {'d': smooth_closed([(mx - 16, my - 4), (mx, my - 2), (mx + 16, my - 4), (mx + 9, my + 12), (mx, my + 15), (mx - 9, my + 12)]), 'f': MIN, 's': ML, 'w': 3.5},
        {'d': ellipse(mx, my + 10, 8, 4.5), 'f': TONGUE}]))
    out.append(mouth_item('m_cat', [{'d': smooth_open([(mx - 15, my - 3), (mx - 8, my + 5), (mx, my - 1)]) + ' ' + smooth_open([(mx, my - 1), (mx + 8, my + 5), (mx + 15, my - 3)]), 's': ML, 'w': 4}]))
    out.append(mouth_item('m_o', [{'d': ellipse(mx, my + 3, 7, 8), 'f': MIN, 's': ML, 'w': 3.5}]))
    out.append(mouth_item('m_grin', [
        {'d': smooth_closed([(mx - 20, my - 5), (mx, my - 3), (mx + 20, my - 5), (mx + 10, my + 12), (mx, my + 14), (mx - 10, my + 12)]), 'f': MIN, 's': ML, 'w': 3.5},
        {'d': smooth_closed([(mx - 14, my - 3), (mx + 14, my - 3), (mx + 10, my + 2), (mx - 10, my + 2)]), 'f': '#FFFFFF'},
        {'d': ellipse(mx, my + 10, 9, 4), 'f': TONGUE}]))
    out.append(mouth_item('m_tongue', [
        {'d': smooth_open([(mx - 14, my - 2), (mx, my + 5), (mx + 14, my - 2)]), 's': ML, 'w': 4.5},
        {'d': smooth_closed([(mx + 1, my + 3), (mx + 12, my + 1), (mx + 13, my + 12), (mx + 7, my + 16)]), 'f': TONGUE, 's': ML, 'w': 3}]))
    out.append(mouth_item('m_fang', [
        {'d': smooth_open([(mx - 15, my - 2), (mx, my + 6), (mx + 15, my - 2)]), 's': ML, 'w': 4.5},
        {'d': poly([(mx + 4, my + 3), (mx + 11, my + 1), (mx + 8, my + 10)]), 'f': '#FFFFFF', 's': ML, 'w': 2.5}]))
    out.append(mouth_item('m_pout', [{'d': smooth_open([(mx - 9, my + 4), (mx, my), (mx + 9, my + 4)]), 's': ML, 'w': 4.5}]))
    out.append(mouth_item('m_wavy', [{'d': smooth_open([(mx - 16, my + 2), (mx - 8, my - 3), (mx, my + 3), (mx + 8, my - 3), (mx + 16, my + 2)]), 's': ML, 'w': 4}]))
    out.append(mouth_item('m_kiss', [{'d': heart(mx, my + 2, 9), 'f': '#F0607E', 's': ML, 'w': 3}]))
    out.append(mouth_item('m_big', [
        {'d': smooth_closed([(mx - 22, my - 6), (mx, my - 4), (mx + 22, my - 6), (mx + 14, my + 16), (mx, my + 20), (mx - 14, my + 16)]), 'f': MIN, 's': ML, 'w': 3.5},
        {'d': ellipse(mx, my + 14, 12, 6), 'f': TONGUE}]))
    out.append(mouth_item('m_tiny', [{'d': smooth_open([(mx - 6, my + 1), (mx, my + 4), (mx + 6, my + 1)]), 's': ML, 'w': 4}]))
    return out

def blushes():
    out = []
    L, R = (204, 374), (396, 374)
    def item(id_, S): return {'id': id_, 'cat': 'cheeks', 'color': None, 'layers': [{'z': 39, 'shapes': S}]}
    out.append(item('b_none', []))
    out.append(item('b_soft', [{'d': ellipse(*L, 26, 14) + ' ' + ellipse(*R, 26, 14), 'f': '#FF8FAA', 'o': 0.42}]))
    out.append(item('b_lines', [{'d': ellipse(*L, 26, 14) + ' ' + ellipse(*R, 26, 14), 'f': '#FF8FAA', 'o': 0.35}] +
                    [{'d': smooth_open([(x - 4 + i * 9, 368), (x - 9 + i * 9, 380)]), 's': '#F06A8C', 'w': 3} for x in (L[0], R[0]) for i in (-1, 0, 1)]))
    out.append(item('b_freckles', [{'d': ' '.join(circle(x + dx, 368 + dy, 2.6) for x in (L[0] + 6, R[0] - 6) for dx, dy in ((-10, 0), (0, -6), (10, 0), (-4, 8), (6, 7))), 'f': '#C9845F', 'o': 0.8}]))
    out.append(item('b_hearts', [{'d': heart(L[0], L[1], 11) + ' ' + heart(R[0], R[1], 11), 'f': '#FF7FA3', 'o': 0.8}]))
    out.append(item('b_stars', [{'d': star(L[0] - 4, L[1], 12, 0.5) + ' ' + star(R[0] + 4, R[1], 12, 0.5), 'f': '#FFD45E', 's': '#F0A92E', 'w': 2}]))
    out.append(item('b_rosy', [{'d': ellipse(*L, 30, 17) + ' ' + ellipse(*R, 30, 17), 'f': '#FF6F96', 'o': 0.5}]))
    return out

def brows():
    out = []
    def item(id_, d, w=5):
        return {'id': id_, 'cat': 'brows', 'color': 'hair', 'layers': [{'z': 56, 'shapes': [{'d': d, 's': 'c.o', 'w': w, 'o': 0.85}]}]}
    out.append(item('br_soft', both(smooth_open([(212, 272), (234, 266), (256, 270)]))))
    out.append(item('br_happy', both(smooth_open([(212, 268), (234, 257), (256, 262)]))))
    out.append(item('br_worried', both(smooth_open([(214, 260), (236, 262), (258, 270)]))))
    out.append(item('br_angry', both(smooth_open([(214, 260), (236, 266), (256, 274)]))))
    out.append(item('br_short', both(smooth_open([(226, 264), (242, 262)])), 7))
    out.append({'id': 'br_none', 'cat': 'brows', 'color': 'hair', 'layers': []})
    return out
