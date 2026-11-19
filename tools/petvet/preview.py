"""Contact sheets for checking the Pet Vet art: python3 tools/petvet/preview.py OUTDIR"""
import os, sys, json
sys.path.insert(0, os.path.dirname(__file__))
import cairosvg

def svg_shapes(shapes, dx=0, dy=0):
    out = []
    for s in shapes:
        fill = s.get('f', 'none')
        st = f' stroke="{s["s"]}" stroke-width="{s.get("w",4)}" stroke-linecap="round" stroke-linejoin="round"' if s.get('s') else ''
        op = f' opacity="{s["o"]}"' if 'o' in s else ''
        out.append(f'<path d="{s["d"]}" fill="{fill}"{st}{op}/>')
    return ''.join(out)

def animal_svg(a, eyes='open', mouth='smile', brows=False, extra=''):
    parts = svg_shapes(a['back']) + svg_shapes(a['body']) + extra + svg_shapes(a['front']) + svg_shapes(a['blush'])
    parts += svg_shapes(a['eyes'][eyes]) + (svg_shapes(a['brows']) if brows else '') + svg_shapes(a['mouths'][mouth])
    return parts

def sheet(cells, cols, cw, ch, path, bg='#FFF4F8', scale=0.5):
    rows = (len(cells) + cols - 1) // cols
    body = ''.join(f'<g transform="translate({(i % cols) * cw},{(i // cols) * ch})">{c}</g>' for i, c in enumerate(cells))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{cols*cw}" height="{rows*ch}"><rect width="100%" height="100%" fill="{bg}"/>{body}</svg>'
    cairosvg.svg2png(bytestring=svg.encode(), write_to=path, scale=scale)
