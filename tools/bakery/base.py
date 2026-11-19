"""Shared helpers for the bakery art. Paths use only absolute M, L, C, Z (the app's PathParser)."""
import math, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'dressup'))
from geom import f, smooth_closed, smooth_open, poly, ellipse, circle, rrect, star, heart, flower  # noqa: F401
from colors import hx, to_hex, shade as _shade, light as _light, deep as _deep, outline as _outline, mix as _mix

LW = 5


def O(h):  return to_hex(_outline(hx(h)))
def SH(h): return to_hex(_shade(hx(h)))
def LT(h): return to_hex(_light(hx(h)))
def DP(h): return to_hex(_deep(hx(h)))
def MX(a, b, t): return to_hex(_mix(hx(a), hx(b), t))


def S(d, f=None, s=None, w=None, o=None, g=None, eo=None):
    out = {'d': d}
    if f: out['f'] = f
    if s: out['s'] = s
    if s: out['w'] = LW if w is None else w
    if o is not None: out['o'] = o
    if g: out['g'] = g
    if eo: out['eo'] = 1
    return out


def solid(d, col, w=None, o=None):
    """Fill in a fixed color with its own derived outline."""
    if col.startswith('#'):
        return S(d, col, O(col), w)
    return S(d, col, col + '.o', w)


def tf(d, dx=0.0, dy=0.0, s=1.0, rot=0.0, sx=None, sy=None):
    """Rotate (degrees, about 0,0), scale, then move an absolute M/L/C/Z path."""
    sx = s if sx is None else sx
    sy = s if sy is None else sy
    c, sn = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    toks = d.replace(',', ' ').split()
    out, i = [], 0
    while i < len(toks):
        t = toks[i]
        cmd, rest = t[0], t[1:]
        if rest:
            toks.insert(i + 1, rest)
        i += 1
        n = {'M': 1, 'L': 1, 'C': 3, 'Z': 0}[cmd]
        pts = []
        for _ in range(n):
            x, y = float(toks[i]), float(toks[i + 1]); i += 2
            x, y = x * c - y * sn, x * sn + y * c
            pts.append(f"{f(x * sx + dx)} {f(y * sy + dy)}")
        out.append(cmd + ' '.join(pts))
    return ' '.join(out)


def tshapes(shapes, **k):
    out = []
    for sh in shapes:
        sh = dict(sh); sh['d'] = tf(sh['d'], **k)
        if 'w' in sh:
            sc = abs(k.get('s', 1)) if k.get('sx') is None else abs(k['sx'])
            sh['w'] = round(sh['w'] * sc, 2)
        out.append(sh)
    return out


def arc_pts(cx, cy, rx, ry, a0, a1, n=12):
    return [(cx + math.cos(math.radians(a0 + (a1 - a0) * i / n)) * rx,
             cy + math.sin(math.radians(a0 + (a1 - a0) * i / n)) * ry) for i in range(n + 1)]


def line(pts, col, w):
    return {'d': smooth_open(pts), 's': col, 'w': w}


def shine(cx, cy, rx, ry, rot=-30, o=0.7):
    return S(ellipse(cx, cy, rx, ry, rot), '#FFFFFF', o=o)
