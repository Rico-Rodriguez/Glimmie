"""Contact sheets of the Dress Up pets and their outfits: python3 tools/dressup/sheet_pets.py OUTDIR"""
import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pets
from render import shapes_svg, png
from colors import CLOTH

def wear_transform(slot, anc):
    if slot == 'hat':
        x, y, deg, s = anc['hat']
        return f'translate({x} {y}) rotate({deg}) scale({s}) translate(-300 -134)'
    if slot == 'glasses':
        ex, ey = anc['eyes']
        s = (300 - ex) / 62
        return f'translate(300 {ey}) scale({s}) translate(-300 -270)'
    if slot in ('body', 'back'):
        return f'translate(300 0) scale({anc["wide"]} 1) translate(-300 0)'
    return ''

def pet_svg(data, k, wear=None, eyes='open', mouth='smile', uid=0):
    a = data['animals'][k]
    wear = wear or {}
    ctx0 = {'c': '#FFFFFF', 'a': '#FFFFFF', 'skin': '#FFFFFF', 'pattern': None}
    parts, defs = [], []
    n = [uid * 100]
    def add(shapes, slot=None, ctx=ctx0):
        n[0] += 1
        o, d = shapes_svg(shapes, ctx, f'{uid}_{n[0]}')
        defs.extend(d)
        t = wear_transform(slot, a['anchors']) if slot else ''
        parts.append(f'<g transform="{t}">' + ''.join(o) + '</g>')
    def w(slot):
        if slot in wear:
            id_, col, pat = wear[slot]
            it = data['wear'][id_]
            add(it['shapes'], slot, {'c': col, 'a': it['accent'], 'skin': '#FFFFFF', 'pattern': pat})
    w('back'); add(a['back']); add(a['torso']); w('body'); add(a['limbs']); add(a['head']); w('neck')
    add(a['front']); add(a['blush']); add(a['eyes'][eyes]); add(a['mouths'][mouth]); w('glasses'); w('hat')
    return f'<defs>{"".join(defs)}</defs>' + ''.join(parts)

def sheet(cells, cols, path, cw=600, ch=660, scale=0.4, bg='#FFF4F8'):
    rows = (len(cells) + cols - 1) // cols
    body = ''.join(f'<g transform="translate({(i % cols) * cw},{(i // cols) * ch})">{c}</g>' for i, c in enumerate(cells))
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{cols*cw}" height="{rows*ch}"><rect width="100%" height="100%" fill="{bg}"/>{body}</svg>'
    png(svg, path, scale)

if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    d = pets.build()
    sheet([pet_svg(d, k, uid=i) for i, k in enumerate(d['order'])], 10, os.path.join(out, 'pets-all.png'), scale=0.3)
    random.seed(4)
    by = {s: [i for i, v in d['wear'].items() if v['slot'] == s] for s in d['slots']}
    cells = []
    for i, k in enumerate(d['order']):
        wr = {}
        for s in d['slots']:
            if random.random() < 0.6:
                id_ = random.choice(by[s]); wr[s] = (id_, CLOTH[d['wear'][id_]['default']], random.choice([None, None, 'dots', 'stripes', 'hearts']))
        cells.append(pet_svg(d, k, wr, uid=i))
    sheet(cells, 10, os.path.join(out, 'pets-dressed.png'), scale=0.3)
    for s in d['slots']:
        cells = [pet_svg(d, d['order'][j % len(d['order'])], {s: (id_, CLOTH[d['wear'][id_]['default']], None)}, uid=j)
                 for j, id_ in enumerate(by[s])]
        sheet(cells, 5, os.path.join(out, f'pets-{s}.png'), scale=0.3)
    sheet([pet_svg(d, 'kitty', eyes=e, mouth=m, uid=i) for i, (e, m) in enumerate([('open', 'smile'), ('happy', 'grin'), ('blink', 'smile'), ('sparkle', 'wide'), ('happy', 'yum'), ('open', 'o')])],
          6, os.path.join(out, 'pets-faces.png'), scale=0.3)
