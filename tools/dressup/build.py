"""Builds App/Resources/Games/DressUp/dressup.json from the art scripts.
Run from the repo root:  python3 tools/dressup/build.py  [--sheet DIR]"""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
import body, face, hair, clothes, extras, backgrounds, patterns, more
from colors import SKIN, HAIR, EYES, CLOTH

def eye_styles():
    return [
        ('e_classic', {}), ('e_sparkle', {'sparkle': 1}), ('e_round', {'rx': 37, 'ry': 40, 'flick': 0.6}),
        ('e_tall', {'rx': 32, 'ry': 48}), ('e_sleepy', {'lid': 22}), ('e_lashes', {'lashes': 1, 'sparkle': 1}),
        ('e_star', {'starPupil': 1}), ('e_heart', {'heartPupil': 1}), ('e_small', {'rx': 27, 'ry': 34, 'oy': 8, 'flick': 0.5}),
        ('e_bigpupil', {'pupil': 0.66}), ('e_cat', {'rx': 36, 'ry': 38, 'flick': 1.6, 'lid': 6}), ('e_dreamy', {'lid': 12, 'sparkle': 1, 'lashes': 1}),
    ]

def happy_eyes():
    """Closed happy ^^ eyes, shown while she cheers."""
    S = []
    for flip in (False, True):
        cx = body.EYE_L[0] if not flip else 600 - body.EYE_L[0]
        y = body.EYE_L[1] + 8
        S.append({'d': f"M{cx-30} {y+10} C{cx-16} {y-22} {cx+16} {y-22} {cx+30} {y+10}", 's': face.LASH, 'w': 7})
    return {'id': 'eyes_happy', 'cat': 'special', 'color': None, 'layers': [{'z': 40, 'shapes': S}]}

CATS = [
    # id, group, required, palette (color slot shown in the tray), icon item
    ('skin', 'me', True, 'skin', None),
    ('hairBack', 'me', True, 'hair', 'hb_twintails'),
    ('hairFront', 'me', True, 'hair', 'hf_classic'),
    ('eyes', 'me', True, 'eye', 'e_sparkle'),
    ('brows', 'me', True, None, 'br_happy'),
    ('mouth', 'me', True, None, 'm_open'),
    ('cheeks', 'me', True, None, 'b_hearts'),
    ('dress', 'clothes', False, 'cloth', 'd_princess'),
    ('top', 'clothes', False, 'cloth', 't_puff'),
    ('bottom', 'clothes', False, 'cloth', 'b_tutu'),
    ('outer', 'clothes', False, 'cloth', 'o_cardigan'),
    ('socks', 'clothes', False, 'cloth', 's_stripes'),
    ('shoes', 'clothes', False, 'cloth', 'sh_maryjane'),
    ('hat', 'extras', False, 'cloth', 'h_crown'),
    ('glasses', 'extras', False, 'cloth', 'g_heart'),
    ('neck', 'extras', False, 'cloth', 'n_heart'),
    ('back', 'extras', False, 'cloth', 'w_butterfly'),
    ('hold', 'extras', False, 'cloth', 'p_kitty'),
    ('bg', 'scene', True, None, None),
]

NUM = re.compile(r'-?\d+(?:\.\d+)?')

def bbox(item):
    xs, ys = [], []
    for L in item['layers']:
        for s in L['shapes']:
            v = [float(n) for n in NUM.findall(s['d'])]
            pad = s.get('w', 0) / 2 if s.get('s') else 0
            xs += [x - pad for x in v[0::2]] + [x + pad for x in v[0::2]]
            ys += [y - pad for y in v[1::2]] + [y + pad for y in v[1::2]]
    if not xs:
        return [200, 300, 200, 200]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    w, h = x1 - x0, y1 - y0
    side = max(w, h) * 1.08
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return [round(cx - side / 2, 1), round(cy - side / 2, 1), round(side, 1), round(side, 1)]

FIXED_THUMB = {'eyes': [175, 250, 250, 150], 'brows': [190, 220, 220, 120], 'mouth': [240, 336, 120, 100],
               'cheeks': [160, 300, 280, 140], 'hairFront': [120, 60, 360, 420], 'glasses': [160, 240, 280, 170]}
HEAD_BASE = {'eyes', 'brows', 'mouth', 'cheeks', 'hairFront', 'glasses'}

ROLE = re.compile(r'^(#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?|(c|a|skin)(\.(s|l|d|o))?)$')
PATH = re.compile(r'^[MLCZ0-9 .\-]*$')

def check(item):
    for L in item['layers']:
        for s in L['shapes']:
            assert PATH.match(s['d']), (item['id'], s['d'][:60])
            for k in ('f', 's'):
                if s.get(k): assert ROLE.match(s[k]), (item['id'], s[k])
            for g in s.get('g', []): assert ROLE.match(g), (item['id'], g)
            if s.get('f') == '#00000022': raise ValueError

def main():
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    items = [body.body_item(), body.underwear_item(), face.closed_eyes_item(), happy_eyes()]
    items += [face.eyes_item(i, st) for i, st in eye_styles()]
    items += face.mouths() + face.blushes() + face.brows()
    items += hair.fronts() + more.fronts() + hair.backs() + more.backs()
    items += clothes.tops() + more.tops() + clothes.bottoms() + clothes.dresses() + more.dresses() + clothes.outers() + clothes.socks() + clothes.shoes()
    items += extras.hats() + more.hats() + extras.glasses() + extras.necks() + extras.backs() + extras.held() + more.held()
    bgs = backgrounds.all_bgs() + more.bgs()
    ids = [i['id'] for i in items + bgs]
    assert len(ids) == len(set(ids)), [x for x in ids if ids.count(x) > 1]
    head = {'d': body.sym(body.HEAD_PTS), 'f': 'skin', 's': 'skin.o', 'w': body.LW}
    out_items = {}
    for it in items + bgs:
        check(it)
        e = {'cat': it['cat'], 'layers': it['layers']}
        if it.get('color'): e['color'] = it['color']
        if 'default' in it: e['default'] = it['default']
        if it.get('accent'): e['accent'] = it['accent']
        if it.get('patternable'): e['patternable'] = True
        if it['cat'] != 'bg':
            e['thumb'] = FIXED_THUMB.get(it['cat']) or bbox(it)
            if it['cat'] in HEAD_BASE: e['head'] = True
        out_items[it['id']] = e
    cats = []
    for cid, group, req, pal, icon in CATS:
        members = [i['id'] for i in items + bgs if i['cat'] == cid]
        cats.append({'id': cid, 'group': group, 'required': req, 'palette': pal, 'icon': icon, 'items': members})
    data = {
        'doll': [600, 900], 'scene': [1200, 900], 'head': head,
        'palettes': {'skin': SKIN, 'hair': HAIR, 'eye': EYES, 'cloth': CLOTH},
        'patterns': {p: ' '.join(patterns.pattern_shapes(p)) for p in patterns.PATTERNS if p != 'none'},
        'categories': cats, 'items': out_items,
    }
    path = os.path.join(root, 'App/Resources/Games/DressUp/dressup.json')
    with open(path, 'w') as fh:
        json.dump(data, fh, separators=(',', ':'))
    n = sum(len(c['items']) for c in cats)
    print(f'{path}: {os.path.getsize(path) // 1024} KB, {n} pickable items in {len(cats)} categories')

if __name__ == '__main__':
    main()
