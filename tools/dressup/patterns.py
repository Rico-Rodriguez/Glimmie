"""Fabric patterns, drawn over a garment's main fill and clipped to it. Mirrored in Swift (`Pattern`)."""
from geom import circle, star, heart, flower, f
from colors import hx, to_hex, light, mix

PATTERNS = ['none', 'dots', 'stripes', 'hearts', 'stars', 'checks', 'flowers', 'tinydots']

def pat_color(ctx):
    c = hx(ctx['c'])
    lum = 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]
    return to_hex(mix(c, (1, 1, 1), 0.7)) if lum < 0.8 else to_hex(mix(c, (0.85, 0.45, 0.65), 0.35))

def pattern_shapes(name):
    """Returns list of (d, kind) where kind is 'fill' in the pattern color."""
    out = []
    if name == 'dots':
        for row in range(0, 30):
            for col in range(0, 20):
                x = col * 36 + (18 if row % 2 else 0); y = row * 32
                out.append(circle(x, y, 6))
    elif name == 'tinydots':
        for row in range(0, 60):
            for col in range(0, 40):
                x = col * 18 + (9 if row % 2 else 0); y = row * 16
                out.append(circle(x, y, 2.6))
    elif name == 'stripes':
        for i in range(0, 40):
            x = i * 28 - 300
            out.append(f"M{f(x)} 0 L{f(x+12)} 0 L{f(x+12+600)} 900 L{f(x+600)} 900 Z")
    elif name == 'checks':
        for i in range(0, 24):
            out.append(f"M{i*30} 0 L{i*30+13} 0 L{i*30+13} 900 L{i*30} 900 Z")
        for j in range(0, 34):
            out.append(f"M0 {j*30} L600 {j*30} L600 {j*30+13} L0 {j*30+13} Z")
    elif name == 'hearts':
        for row in range(0, 22):
            for col in range(0, 13):
                x = col * 50 + (25 if row % 2 else 0); y = row * 44
                out.append(heart(x, y, 9))
    elif name == 'stars':
        for row in range(0, 22):
            for col in range(0, 13):
                x = col * 50 + (25 if row % 2 else 0); y = row * 44
                out.append(star(x, y, 10, 0.5))
    elif name == 'flowers':
        for row in range(0, 22):
            for col in range(0, 13):
                x = col * 52 + (26 if row % 2 else 0); y = row * 46
                out.append(flower(x, y, 13))
    return out

def pattern_svg(name, ctx):
    col = pat_color(ctx)
    ds = pattern_shapes(name)
    if not ds:
        return ''
    op = ' opacity="0.55"' if name == 'checks' else ''
    return f'<path d="{" ".join(ds)}" fill="{col}"{op}/>'
