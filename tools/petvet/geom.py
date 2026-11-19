"""Path helpers for the dress-up art. Everything is in a 600x900 doll canvas, mirrored around x=300.
Paths use only absolute M, L, C, Z so the Swift parser stays tiny."""
import math

CX = 300.0

def f(v):
    s = f"{v:.1f}"
    return s[:-2] if s.endswith(".0") else s

def mirror_pts(pts):
    return [(2 * CX - x, y) for x, y in pts]

def smooth_closed(pts, tension=1.0):
    """Closed Catmull-Rom spline through pts as cubic beziers."""
    n = len(pts)
    out = [f"M{f(pts[0][0])} {f(pts[0][1])}"]
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6 * tension, p1[1] + (p2[1] - p0[1]) / 6 * tension)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6 * tension, p2[1] - (p3[1] - p1[1]) / 6 * tension)
        out.append(f"C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])}")
    return " ".join(out) + " Z"

def smooth_open(pts, tension=1.0):
    n = len(pts)
    out = [f"M{f(pts[0][0])} {f(pts[0][1])}"]
    for i in range(n - 1):
        p0 = pts[i - 1] if i > 0 else pts[i]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[i + 2] if i + 2 < n else pts[i + 1]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6 * tension, p1[1] + (p2[1] - p0[1]) / 6 * tension)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6 * tension, p2[1] - (p3[1] - p1[1]) / 6 * tension)
        out.append(f"C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])}")
    return " ".join(out)

def sym(left_pts, tension=1.0):
    """Symmetric closed shape from the left half, listed top-center -> bottom-center (x<=300)."""
    right = mirror_pts(left_pts[1:-1])[::-1]
    return smooth_closed(left_pts + right, tension)

def poly(pts, close=True):
    s = f"M{f(pts[0][0])} {f(pts[0][1])} " + " ".join(f"L{f(x)} {f(y)}" for x, y in pts[1:])
    return s + (" Z" if close else "")

def ellipse(cx, cy, rx, ry, rot=0.0):
    k = 0.5523
    pts = [(rx, 0), (rx, ry * k), (rx * k, ry), (0, ry), (-rx * k, ry), (-rx, ry * k), (-rx, 0),
           (-rx, -ry * k), (-rx * k, -ry), (0, -ry), (rx * k, -ry), (rx, -ry * k), (rx, 0)]
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    P = [(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]
    out = [f"M{f(P[0][0])} {f(P[0][1])}"]
    for i in range(1, 13, 3):
        out.append(f"C{f(P[i][0])} {f(P[i][1])} {f(P[i+1][0])} {f(P[i+1][1])} {f(P[i+2][0])} {f(P[i+2][1])}")
    return " ".join(out) + " Z"

def circle(cx, cy, r):
    return ellipse(cx, cy, r, r)

def rrect(x, y, w, h, r):
    k = 0.5523 * r
    return (f"M{f(x+r)} {f(y)} L{f(x+w-r)} {f(y)} C{f(x+w-r+k)} {f(y)} {f(x+w)} {f(y+r-k)} {f(x+w)} {f(y+r)} "
            f"L{f(x+w)} {f(y+h-r)} C{f(x+w)} {f(y+h-r+k)} {f(x+w-r+k)} {f(y+h)} {f(x+w-r)} {f(y+h)} "
            f"L{f(x+r)} {f(y+h)} C{f(x+r-k)} {f(y+h)} {f(x)} {f(y+h-r+k)} {f(x)} {f(y+h-r)} "
            f"L{f(x)} {f(y+r)} C{f(x)} {f(y+r-k)} {f(x+r-k)} {f(y)} {f(x+r)} {f(y)} Z")

def star(cx, cy, R, inner=0.48, n=5, rot=-90, round_=0.0):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        r = R if i % 2 == 0 else R * inner
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return smooth_closed(pts, round_) if round_ else poly(pts)

def heart(cx, cy, s):
    # s = half width
    return (f"M{f(cx)} {f(cy + s*0.95)} C{f(cx - s*0.2)} {f(cy + s*0.75)} {f(cx - s)} {f(cy + s*0.25)} {f(cx - s)} {f(cy - s*0.25)} "
            f"C{f(cx - s)} {f(cy - s*0.75)} {f(cx - s*0.45)} {f(cy - s*0.95)} {f(cx)} {f(cy - s*0.5)} "
            f"C{f(cx + s*0.45)} {f(cy - s*0.95)} {f(cx + s)} {f(cy - s*0.75)} {f(cx + s)} {f(cy - s*0.25)} "
            f"C{f(cx + s)} {f(cy + s*0.25)} {f(cx + s*0.2)} {f(cy + s*0.75)} {f(cx)} {f(cy + s*0.95)} Z")

def flower(cx, cy, r, petals=5, rot=-90):
    out = []
    for i in range(petals):
        a = math.radians(rot + i * 360 / petals)
        out.append(ellipse(cx + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55, r * 0.5, r * 0.36, math.degrees(a)))
    return " ".join(out)

def bez(p0, p1, p2, p3, t):
    u = 1 - t
    return (u**3*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t**3*p3[0],
            u**3*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t**3*p3[1])

def bez_seg(ctrl, t0, t1, steps=8):
    """Points along a cubic between t0 and t1."""
    return [bez(*ctrl, t0 + (t1 - t0) * i / steps) for i in range(steps + 1)]

def mirror_path(d):
    """Mirror an absolute M/L/C/Z path around x=300."""
    toks = d.replace(",", " ").split()
    out, i = [], 0
    while i < len(toks):
        t = toks[i]
        if t[0] in "MLCZ":
            cmd = t[0]; rest = t[1:]
            out.append(cmd)
            if rest:
                toks.insert(i + 1, rest)
            i += 1
            n = {"M": 1, "L": 1, "C": 3, "Z": 0}[cmd]
            for _ in range(n):
                x, y = float(toks[i]), float(toks[i + 1]); i += 2
                out.append(f"{f(2*CX - x)} {f(y)}")
        else:
            raise ValueError(t)
    s = " ".join(out)
    for c in "MLC":
        s = s.replace(c + " ", c)
    return s

def both(d):
    return d + " " + mirror_path(d)

def xform(d, sx=1.0, sy=None, ox=300.0, oy=450.0, dx=0.0, dy=0.0):
    """Scale an absolute M/L/C/Z path about (ox, oy), then move it."""
    sy = sx if sy is None else sy
    toks = d.replace(",", " ").split()
    out, i = [], 0
    while i < len(toks):
        t = toks[i]
        cmd = t[0]; rest = t[1:]
        if rest:
            toks.insert(i + 1, rest)
        i += 1
        n = {"M": 1, "L": 1, "C": 3, "Z": 0}[cmd]
        pts = []
        for _ in range(n):
            x, y = float(toks[i]), float(toks[i + 1]); i += 2
            pts.append(f"{f(ox + (x - ox) * sx + dx)} {f(oy + (y - oy) * sy + dy)}")
        out.append(cmd + " ".join(pts))
    return " ".join(out)

def xshapes(shapes, **k):
    out = []
    for s in shapes:
        s = dict(s); s['d'] = xform(s['d'], **k)
        if 'w' in s: s['w'] = round(s['w'] * (k.get('sx', 1) ** 0.5), 1)
        out.append(s)
    return out
