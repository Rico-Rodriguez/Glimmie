"""Preview renderer: draws sprites the way BakeryArt.swift does (cairosvg). Used for contact sheets."""
import cairosvg
from base import hx, to_hex
from colors import role


def resolve(r, c):
    if r is None:
        return None
    if r.startswith('#'):
        return r
    base, _, suf = r.partition('.')
    return to_hex(role(hx(c), suf))


def shapes_svg(shapes, c='#FF9EC0', uid='x'):
    out, defs = [], []
    for k, s in enumerate(shapes):
        op = f' opacity="{s["o"]}"' if 'o' in s else ''
        if 'g' in s:
            gid = f'g{uid}_{k}'
            defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
                        f'<stop offset="0" stop-color="{resolve(s["g"][0], c)}"/>'
                        f'<stop offset="1" stop-color="{resolve(s["g"][1], c)}"/></linearGradient>')
            fill = f'url(#{gid})'
        else:
            fill = resolve(s.get('f'), c) or 'none'
        stroke = resolve(s.get('s'), c)
        st = (f' stroke="{stroke}" stroke-width="{s.get("w", 5)}" stroke-linecap="round" stroke-linejoin="round"'
              if stroke else '')
        rule = ' fill-rule="evenodd"' if s.get('eo') else ''
        out.append(f'<path d="{s["d"]}" fill="{fill}"{rule}{st}{op}/>')
    return ''.join(out), ''.join(defs)


def svg(parts, box, size=None, bg=None):
    """parts: list of (shapes, color, dx, dy, scale)."""
    x, y, w, h = box
    body, defs = [], []
    for i, p in enumerate(parts):
        shapes, c = p[0], p[1]
        dx, dy, sc = (p[2], p[3], p[4]) if len(p) > 2 else (0, 0, 1)
        b, d = shapes_svg(shapes, c, f'{i}')
        body.append(f'<g transform="translate({dx} {dy}) scale({sc})">{b}</g>')
        defs.append(d)
    W, H = size or (w, h)
    bgs = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{bg}"/>' if bg else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="{x} {y} {w} {h}">'
            f'<defs>{"".join(defs)}</defs>{bgs}{"".join(body)}</svg>')


def png(s, path):
    cairosvg.svg2png(bytestring=s.encode(), write_to=path)
