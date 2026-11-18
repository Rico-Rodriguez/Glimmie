"""Build the app icon (1024x1024, no alpha) from the Glimmie render.
Run: python3 tools/make_icon.py"""
import json, os
from PIL import Image, ImageChops, ImageDraw, ImageFilter
A = 'App/Resources/Art/'
OUT = 'App/Resources/Assets.xcassets/AppIcon.appiconset'
os.makedirs(OUT, exist_ok=True)
S = 1024
bg = Image.new('RGB', (S, S))
top, bot = (255, 214, 236), (196, 170, 255)
d = ImageDraw.Draw(bg)
for y in range(S):
    k = y / (S - 1); d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * k) for i in range(3)))
glow = Image.new('L', (S, S)); ImageDraw.Draw(glow).ellipse([170, 190, 854, 874], fill=200)
bg = Image.composite(Image.new('RGB', (S, S), (255, 250, 253)), bg, glow.filter(ImageFilter.GaussianBlur(90)))
def tint(im, c):
    a = im.getchannel('A'); m = ImageChops.multiply(im.convert('RGB'), Image.new('RGB', im.size, c)); m.putalpha(a); return m
body = tint(Image.open(A + 'L_glim_body.png').convert('RGBA'), (255, 166, 210))
pet = Image.new('RGBA', body.size); pet.alpha_composite(body); pet.alpha_composite(Image.open(A + 'L_glim_face.png').convert('RGBA'))
pet = pet.crop(pet.getchannel('A').getbbox())
s = 820 / max(pet.size); pet = pet.resize((int(pet.width * s), int(pet.height * s)), Image.LANCZOS)
canvas = bg.convert('RGBA')
canvas.alpha_composite(pet, ((S - pet.width) // 2, (S - pet.height) // 2 + 40))
dd = ImageDraw.Draw(canvas)
def twinkle(cx, cy, r, col):
    k = r * 0.25
    dd.polygon([(cx, cy - r), (cx + k, cy - k), (cx + r, cy), (cx + k, cy + k), (cx, cy + r), (cx - k, cy + k), (cx - r, cy), (cx - k, cy - k)], fill=col)
for cx, cy, r in [(150, 170, 60), (880, 230, 44), (120, 760, 36), (900, 820, 54), (800, 120, 26)]:
    twinkle(cx, cy, r, (255, 255, 255, 255))
canvas.convert('RGB').save(f'{OUT}/icon-1024.png')
json.dump({"images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
           "info": {"author": "xcode", "version": 1}}, open(f'{OUT}/Contents.json', 'w'), indent=2)
json.dump({"info": {"author": "xcode", "version": 1}}, open('App/Resources/Assets.xcassets/Contents.json', 'w'), indent=2)
print('icon ok')
