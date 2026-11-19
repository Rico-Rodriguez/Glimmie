import sys
from render import doll_svg, png
import body, face, hair
from colors import SKIN, HAIR, EYES, CLOTH

def ctx(**k):
    d = {'skin': SKIN[1], 'hair': HAIR[3], 'eye': EYES[6], 'c': CLOTH[3], 'a': '#FFFFFF', 'pattern': None}
    d.update(k)
    if 'own' in k: d['c'] = k['own']
    return d

def item_ctx(it, base):
    c = dict(base)
    if it.get('color') == 'hair': c['c'] = base['hair']
    elif it.get('color') == 'eye': c['c'] = base['eye']
    elif it.get('color') == 'skin': c['c'] = base['skin']
    return c

def compose(items, base, out, bg='#FFF4F8'):
    svg = doll_svg([(it, item_ctx(it, base) if not isinstance(it, tuple) else it[1]) for it in items], bg=bg)
    png(svg, out)

if __name__ == '__main__':
    base = ctx()
    B = body.body_item(); U = body.underwear_item()
    E = face.eyes_item('e_round', {})
    M = face.mouths()[0]; C = face.blushes()[1]; BR = face.brows()[0]
    HF = hair.fronts()[0]; HB = hair.backs()[0]
    compose([HB, B, U, E, M, C, BR, HF], base, sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/p.png')
