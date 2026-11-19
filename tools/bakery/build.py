"""Builds App/Resources/Games/Bakery/bakery.json (all the bakery art as vector paths).
Run from the repo root: python3 tools/bakery/build.py   (needs nothing but Python 3)"""
import json, os, sys
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(__file__))
import treats, props
from toppings import TOPPINGS, BITS

sprites = {}
sprites.update(treats.all_sprites())
sprites.update(props.all_sprites())
for k, (fn, _) in TOPPINGS.items():
    sprites['top_' + k] = fn()
for k, fn in BITS.items():
    sprites['bit_' + k] = fn()

out = {'sprites': sprites, 'tinted': sorted(k for k, (_, t) in TOPPINGS.items() if t), 'meta': treats.meta()}
path = 'App/Resources/Games/Bakery/bakery.json'
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w') as fh:
    json.dump(out, fh, separators=(',', ':'))
print(path, len(sprites), 'sprites', os.path.getsize(path) // 1024, 'KB')
