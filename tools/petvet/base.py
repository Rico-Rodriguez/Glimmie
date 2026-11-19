"""Shared helpers for the Pet Vet art. Colors use the same shade math as the Dress Up art
(tools/dressup/colors.py) so the games look like one family: color-derived outlines (never black),
one shade and one light per color."""
import math
from geom import f, ellipse, circle, smooth_closed, smooth_open, sym, poly, heart, star, rrect, xform

INK = (0x4A / 255, 0x2C / 255, 0x40 / 255)


def hx(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def to_hex(c):
    return '#' + ''.join(f"{max(0, min(255, round(v * 255))):02X}" for v in c)


def _mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _mul(a, k):
    return tuple(a[i] * k[i] for i in range(3))


def shade(h):   return to_hex(_mul(hx(h), (0.86, 0.78, 0.90)))
def light(h):   return to_hex(_mix(hx(h), (1, 1, 1), 0.55))
def deep(h):    return to_hex(_mul(hx(h), (0.62, 0.52, 0.68)))
def outline(h): return to_hex(_mix(_mul(hx(h), (0.56, 0.42, 0.56)), INK, 0.35))
def mixh(a, b, t): return to_hex(_mix(hx(a), hx(b), t))


def S(d, fill=None, stroke=None, w=None, o=None):
    """One shape. fill/stroke are '#RRGGBB'."""
    s = {'d': d}
    if fill: s['f'] = fill
    if stroke:
        s['s'] = stroke
        s['w'] = 5 if w is None else w
    if o is not None and o < 1: s['o'] = o
    return s


def blob(d, color, w=5, line=None):
    """A filled shape with its color-derived outline."""
    return S(d, color, line or outline(color), w)


def flat(d, color, o=None):
    return S(d, color, o=o)


def line(d, color, w=5, o=None):
    return S(d, None, color, w, o)


def tube(pts, w0, w1=None, cap=True):
    """A closed outline around a polyline that tapers from width w0 to w1."""
    w1 = w0 if w1 is None else w1
    n = len(pts)
    L, R = [], []
    for i, (x, y) in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        w = (w0 + (w1 - w0) * i / (n - 1)) / 2
        L.append((x + nx * w, y + ny * w))
        R.append((x - nx * w, y - ny * w))
    return smooth_closed(L + R[::-1], 1.0)


def rot_pts(pts, cx, cy, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


def mirror(shapes, cx=300):
    """Mirror shapes around x=cx."""
    out = []
    for s in shapes:
        s = dict(s)
        s['d'] = xform(s['d'], sx=-1, sy=1, ox=cx, oy=0)
        out.append(s)
    return out


def move(shapes, dx=0, dy=0, sc=1.0, ox=0, oy=0):
    out = []
    for s in shapes:
        s = dict(s)
        s['d'] = xform(s['d'], sx=sc, sy=sc, ox=ox, oy=oy, dx=dx, dy=dy)
        if 'w' in s: s['w'] = round(s['w'] * sc, 2)
        out.append(s)
    return out


def arc(cx, cy, rx, ry, a0, a1, steps=10):
    """Points along an ellipse arc, angles in degrees (0 = right, 90 = down)."""
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / steps)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / steps))) for i in range(steps + 1)]


def wobble_circle(cx, cy, r, n=10, amp=0.12, seed=0, rot=0):
    """A soft irregular blob."""
    pts = []
    for i in range(n):
        a = math.radians(rot + i * 360 / n)
        k = 1 + amp * math.sin(i * 2.7 + seed * 1.9) * math.cos(i * 1.3 + seed)
        pts.append((cx + math.cos(a) * r * k, cy + math.sin(a) * r * k))
    return smooth_closed(pts, 1.0)


def scallop(cx, cy, rx, ry, n=14, bump=0.16):
    """A cloud/wool outline: an ellipse made of round bumps."""
    pts = []
    for i in range(n * 2):
        a = math.radians(-90 + i * 180 / n)
        k = 1 + (bump if i % 2 == 0 else -bump * 0.25)
        pts.append((cx + math.cos(a) * rx * k, cy + math.sin(a) * ry * k))
    return smooth_closed(pts, 1.25)


def shine(cx, cy, r, o=0.85):
    return flat(ellipse(cx, cy, r, r * 0.62, -30), '#FFFFFF', o)
