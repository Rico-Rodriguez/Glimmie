"""Turn raw Blender renders (art/renders) into app assets (App/Resources/Art).
- full-canvas layers are copied as L_<name>.png (all share one camera, so they stack)
- every wearable item also gets a cropped icon (I_<name>.png) and a white
  die-cut sticker border (B_<name>.png) for the sticker drawer."""
import os, glob
from PIL import Image, ImageFilter
SRC, DST = 'art/renders', 'App/Resources/Art'
os.makedirs(DST, exist_ok=True)
ITEMS = ('dress_', 'shoes_', 'hat_', 'hold_', 'wings_', 'hair_', 'glim_acc_')
for p in sorted(glob.glob(f'{SRC}/*.png')):
    name = os.path.basename(p)[:-4]
    im = Image.open(p).convert('RGBA')
    im.save(f'{DST}/L_{name}.png', optimize=True)
    if not name.startswith(ITEMS) or name.endswith('_shine'):
        continue
    a = im.getchannel('A'); bbox = a.point(lambda v: 255 if v > 20 else 0).getbbox()
    crop = im.crop(bbox)
    s = 220 / max(crop.size); crop = crop.resize((max(1, int(crop.width * s)), max(1, int(crop.height * s))), Image.LANCZOS)
    pad = 22; W, H = crop.width + pad * 2, crop.height + pad * 2
    icon = Image.new('RGBA', (W, H)); icon.alpha_composite(crop, (pad, pad))
    alpha = icon.getchannel('A').point(lambda v: 255 if v > 30 else 0)
    border_a = alpha.filter(ImageFilter.MaxFilter(17)).filter(ImageFilter.GaussianBlur(1.2))
    shadow_a = border_a.filter(ImageFilter.GaussianBlur(5)).point(lambda v: int(v * 0.25))
    border = Image.new('RGBA', (W, H + 6))
    sh = Image.new('RGBA', (W, H), (58, 35, 64, 255)); sh.putalpha(shadow_a); border.alpha_composite(sh, (0, 6))
    wb = Image.new('RGBA', (W, H), (255, 255, 255, 255)); wb.putalpha(border_a); border.alpha_composite(wb, (0, 0))
    icon_full = Image.new('RGBA', (W, H + 6)); icon_full.alpha_composite(icon, (0, 0))
    icon_full.save(f'{DST}/I_{name}.png', optimize=True)
    border.save(f'{DST}/B_{name}.png', optimize=True)
print('ok', len(os.listdir(DST)))
