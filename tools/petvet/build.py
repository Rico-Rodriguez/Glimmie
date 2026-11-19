"""Builds App/Resources/Games/PetVet/petvet.json. Run from the repo root: python3 tools/petvet/build.py
All colors are final hex values; paths use only absolute M/L/C/Z."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import animals, props

def r(shapes):
    out = []
    for s in shapes:
        s = dict(s)
        for k in ('w', 'o'):
            if k in s: s[k] = round(float(s[k]), 2)
        out.append(s)
    return out

def build():
    A = animals.make_all()
    data = {
        'patient': [animals.W, animals.H],
        'anchors': {k: list(v) for k, v in animals.ANCHORS.items()},
        'order': animals.ORDER,
        'animals': {k: {
            'back': r(a['back']), 'body': r(a['body']), 'front': r(a['front']), 'blush': r(a['blush']),
            'brows': r(a['brows']), 'eyes': {e: r(v) for e, v in a['eyes'].items()},
            'mouths': {m: r(v) for m, v in a['mouths'].items()}, 'eye': a['eye'], 'mouth': a['mouth'], 'fur': a['fur'],
        } for k, a in A.items()},
        'props': {k: r(fn()) for k, fn in props.PROPS.items()},
        'tools': {},
        'toolOrder': [t[0] for t in props.TOOLS],
        'rooms': {'exam': r(props.room_exam()), 'lobby': r(props.room_lobby())},
        'room': [1400, 834],
    }
    for tid, fn, tint in props.TOOLS:
        shapes, tip = fn()
        data['tools'][tid] = {'shapes': r(shapes), 'tip': list(tip), 'tint': tint}
    return data

if __name__ == '__main__':
    d = build()
    os.makedirs('App/Resources/Games/PetVet', exist_ok=True)
    with open('App/Resources/Games/PetVet/petvet.json', 'w') as fh:
        json.dump(d, fh, separators=(',', ':'))
    print('petvet.json', os.path.getsize('App/Resources/Games/PetVet/petvet.json') // 1024, 'KB')
