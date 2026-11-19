"""Preview renderer: builds an SVG from items exactly as the app draws them, rasterizes with cairosvg."""
import cairosvg
from colors import hx, to_hex, role, light, CLOTH, SKIN, HAIR, EYES
from patterns import pattern_svg

def resolve(r, ctx):
    """r: 'c', 'c.s', 'skin.o', 'a', '#hex', 'ink'..."""
    if r is None:
        return None
    if r.startswith('#'):
        return r
    base, _, suf = r.partition('.')
    c = ctx[base]
    return to_hex(role(hx(c), suf))

def shapes_svg(shapes, ctx, uid):
    out, defs = [], []
    for k, s in enumerate(shapes):
        op = f' opacity="{s["o"]}"' if 'o' in s else ''
        if 'g' in s:
            gid = f'g{uid}_{k}'
            defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
                        f'<stop offset="0" stop-color="{resolve(s["g"][0], ctx)}"/>'
                        f'<stop offset="1" stop-color="{resolve(s["g"][1], ctx)}"/></linearGradient>')
            fill = f'url(#{gid})'
        else:
            fill = resolve(s.get('f'), ctx) or 'none'
        stroke = resolve(s.get('s'), ctx)
        st = (f' stroke="{stroke}" stroke-width="{s.get("w", 4)}" stroke-linecap="round" stroke-linejoin="round"'
              if stroke else '')
        out.append(f'<path d="{s["d"]}" fill="{fill}"{st}{op}/>')
        if s.get('pat') and ctx.get('pattern'):
            cid = f'c{uid}_{k}'
            defs.append(f'<clipPath id="{cid}"><path d="{s["d"]}"/></clipPath>')
            out.append(f'<g clip-path="url(#{cid})">{pattern_svg(ctx["pattern"], ctx)}</g>')
    return out, defs

def doll_svg(items, size=(600, 900), bg=None):
    """items: list of (item, ctx). ctx maps 'c' (own color), 'a' (accent), 'skin', 'hair', 'eye' to hex."""
    layers = []
    for n, (it, ctx) in enumerate(items):
        for L in it['layers']:
            layers.append((L['z'], n, L['shapes'], ctx))
    layers.sort(key=lambda t: (t[0], t[1]))
    body, defs = [], []
    for i, (z, n, shapes, ctx) in enumerate(layers):
        o, d = shapes_svg(shapes, ctx, i)
        body += o; defs += d
    w, h = size
    bgsvg = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 600 900">'
            f'<defs>{"".join(defs)}</defs>{bgsvg}{"".join(body)}</svg>')

def png(svg, path, scale=1):
    cairosvg.svg2png(bytestring=svg.encode(), write_to=path, scale=scale)
