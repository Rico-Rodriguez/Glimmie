"""Contact sheet: python3 sheet.py out.png  (edit COMBOS)."""
import sys
from PIL import Image
import body, face, hair
from render import doll_svg, png
from preview import ctx, item_ctx
from colors import HAIR, EYES, SKIN

def doll(items, base, path):
    png(doll_svg([(it, item_ctx(it, base)) for it in items], bg='#FFF4F8'), path)

def grid(paths, out, cols=6, scale=0.5):
    ims = [Image.open(p) for p in paths]
    w, h = int(ims[0].width * scale), int(ims[0].height * scale)
    rows = (len(ims) + cols - 1) // cols
    sheet = Image.new('RGB', (w * cols, h * rows), 'white')
    for i, im in enumerate(ims):
        sheet.paste(im.resize((w, h)), ((i % cols) * w, (i // cols) * h))
    sheet.save(out)
