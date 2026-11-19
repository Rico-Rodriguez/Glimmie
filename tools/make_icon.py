"""App icon (1024x1024, no alpha): the dress-up doll's face on a pink tile.
Run: python3 tools/make_icon.py"""
import io, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'dressup'))
from PIL import Image, ImageDraw
import cairosvg
import body, face, hair, clothes, extras
from render import doll_svg
from colors import SKIN, HAIR, EYES, CLOTH

base = {'skin': SKIN[1], 'hair': HAIR[8], 'eye': EYES[8], 'a': '#FFFFFF', 'pattern': None}
def c(**k): d = dict(base); d.update(k); return d
items = [(hair.backs()[6], c(c=HAIR[8], a='#FFFFFF')), (body.body_item(), c(c=SKIN[1])), (body.underwear_item(), c()),
         ([i for i in clothes.dresses() if i['id'] == 'd_princess'][0], c(c=CLOTH[0], a='#FFE27A')),
         ([i for i in face.mouths() if i['id'] == 'm_open'][0], c()), (face.blushes()[1], c()),
         (face.eyes_item('e', {'sparkle': 1}), c(c=EYES[8])), (face.brows()[1], c(c=HAIR[8])),
         (hair.fronts()[0], c(c=HAIR[8])), ([i for i in extras.hats() if i['id'] == 'h_bigbow'][0], c(c='#FFFFFF'))]
svg = doll_svg(items).replace('viewBox="0 0 600 900"', 'viewBox="105 85 390 390"').replace('width="600" height="900"', 'width="1024" height="1024"')
doll = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode()))).convert('RGBA')
S = 1024
bg = Image.new('RGB', (S, S))
d = ImageDraw.Draw(bg)
top, bot = (255, 196, 222), (214, 190, 255)
for y in range(S):
    k = y / (S - 1); d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * k) for i in range(3)))
icon = bg.convert('RGBA'); icon.alpha_composite(doll)
icon.convert('RGB').save('App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png')
print('icon written')
