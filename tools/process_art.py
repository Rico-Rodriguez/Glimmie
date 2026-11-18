"""Turn raw Blender renders (art/renders) into app assets (App/Resources/Art).
See docs/MODEL_UPGRADE.md step 1.

- L_<name>.png  base pass of each avatar layer, cropped to its visible pixels (+4 px)
- G_<name>.png  gloss pass of each tinted layer (screened on by the app), cropped the same way
- S_<name>.png  contact shadow of each item that sits on the body, made from its own outline,
                kept only where it lands on the body (and, for hats, on the shared hair cap)
- layers.json   where each cropped L_/G_/S_ image sits in the full canvas (pixels, origin top-left)
- I_/B_<name>   sticker icon and its white die-cut border for every wearable item
Glimmie layers (glim_*) stay full-canvas: GlimmieView and Glimmie House draw them uncropped.

usage: python3 tools/process_art.py [renders_dir]"""
import os, sys, glob, json
import numpy as np
from PIL import Image, ImageFilter

SRC = sys.argv[1] if len(sys.argv) > 1 else 'art/renders'
DST = os.environ.get('ART_OUT', 'App/Resources/Art')
os.makedirs(DST, exist_ok=True)
ITEMS = ('dress_', 'shoes_', 'hat_', 'hold_', 'wings_', 'hair_', 'glim_acc_')
SHADOWED = ('dress_', 'shoes_', 'hat_', 'hold_', 'hair_')          # things that rest on the body
SHADOW = dict(drop=6, blur=6, strength=0.8)                         # px at 1x (800x1000)
NOT_SHIPPED = {'capproxy', 'preview'}


def clean(im):
    """Zero the colour of fully transparent pixels: smaller files, no fringes when scaled."""
    a = np.asarray(im).copy(); a[a[..., 3] == 0] = 0
    return Image.fromarray(a, 'RGBA')


def crop(im, pad=4):
    bbox = im.getchannel('A').point(lambda v: 255 if v > 0 else 0).getbbox()
    if not bbox: return im.crop((0, 0, 1, 1)), [0, 0, 1, 1]
    x0, y0 = max(0, bbox[0] - pad), max(0, bbox[1] - pad)
    x1, y1 = min(im.width, bbox[2] + pad), min(im.height, bbox[3] + pad)
    return im.crop((x0, y0, x1, y1)), [x0, y0, x1 - x0, y1 - y0]


def alpha(name):
    p = f'{SRC}/{name}.png'
    return np.asarray(Image.open(p).getchannel('A')).astype(np.float32) / 255 if os.path.exists(p) else None


def blur(a, r):
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), 'L').filter(ImageFilter.GaussianBlur(r))
    return np.asarray(im).astype(np.float32) / 255


def contact_shadow(item_a, on_a, scale):
    d = int(round(SHADOW['drop'] * scale))
    moved = np.zeros_like(item_a); moved[d:] = item_a[:item_a.shape[0] - d]
    return np.clip(blur(moved, SHADOW['blur'] * scale) * (1 - item_a) * on_a * SHADOW['strength'], 0, 1)


def icon(im, name):
    a = im.getchannel('A'); bbox = a.point(lambda v: 255 if v > 20 else 0).getbbox()
    c = im.crop(bbox)
    s = 220 / max(c.size); c = c.resize((max(1, int(c.width * s)), max(1, int(c.height * s))), Image.LANCZOS)
    pad = 22; W, H = c.width + pad * 2, c.height + pad * 2
    ic = Image.new('RGBA', (W, H)); ic.alpha_composite(c, (pad, pad))
    al = ic.getchannel('A').point(lambda v: 255 if v > 30 else 0)
    border_a = al.filter(ImageFilter.MaxFilter(17)).filter(ImageFilter.GaussianBlur(1.2))
    shadow_a = border_a.filter(ImageFilter.GaussianBlur(5)).point(lambda v: int(v * 0.25))
    border = Image.new('RGBA', (W, H + 6))
    sh = Image.new('RGBA', (W, H), (58, 35, 64, 255)); sh.putalpha(shadow_a); border.alpha_composite(sh, (0, 6))
    wb = Image.new('RGBA', (W, H), (255, 255, 255, 255)); wb.putalpha(border_a); border.alpha_composite(wb, (0, 0))
    full = Image.new('RGBA', (W, H + 6)); full.alpha_composite(ic, (0, 0))
    clean(full).save(f'{DST}/I_{name}.png', optimize=True)
    clean(border).save(f'{DST}/B_{name}.png', optimize=True)


def icon_source(im, name):
    """Stickers are still tinted by multiply, so a tinted item's darker base pass is lifted back to
    near-white (its 95th percentile to 1.0) with its gloss pass screened on, keeping the highlights."""
    gp = f'{SRC}/G_{name}.png'
    if not os.path.exists(gp): return im
    a = np.asarray(im).astype(np.float32) / 255
    vis = a[..., 3] > 0.5
    hi = np.percentile(a[..., :3][vis].max(1), 95) if vis.any() else 1.0
    rgb = np.clip(a[..., :3] / max(hi, 0.5), 0, 1)
    gl = np.asarray(Image.open(gp).convert('RGBA')).astype(np.float32) / 255
    rgb = 1 - (1 - rgb) * (1 - gl[..., :3] * gl[..., 3:4] * 0.6)
    out = np.concatenate([rgb, a[..., 3:4]], -1)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), 'RGBA')


# old full-canvas avatar layers would linger next to the new crops; start the avatar layers clean
for p in glob.glob(f'{DST}/[LGS]_*.png'):
    if not os.path.basename(p)[2:].startswith('glim_'): os.remove(p)

rects, canvas = {}, None
body = None
for p in sorted(glob.glob(f'{SRC}/*.png')):
    name = os.path.basename(p)[:-4]
    if name in NOT_SHIPPED: continue
    im = clean(Image.open(p).convert('RGBA'))
    gloss = name.startswith('G_')
    base = name[2:] if gloss else name
    if base.startswith('glim_'):
        im.save(f'{DST}/L_{name}.png', optimize=True)
        if name.startswith(ITEMS): icon(im, name)
        continue
    canvas = canvas or list(im.size)
    out = name if gloss else 'L_' + name
    c, r = crop(im); c.save(f'{DST}/{out}.png', optimize=True); rects[out] = r
    if gloss: continue
    if name.startswith(ITEMS) and not name.endswith('_shine'):
        icon(icon_source(im, name), name)
    if name.startswith(SHADOWED) and not name.endswith('_shine'):
        if body is None:
            body = np.maximum(alpha('skin'), alpha('under'))
            cap = alpha('capproxy')
            body_cap = np.maximum(body, cap) if cap is not None else body
        a = np.asarray(im.getchannel('A')).astype(np.float32) / 255
        s = contact_shadow(a, body_cap if name.startswith('hat_') else body, im.width / 800)
        sim = np.zeros((*s.shape, 4), np.uint8); sim[..., :3] = 255; sim[..., 3] = (s * 255).astype(np.uint8)
        c, r = crop(clean(Image.fromarray(sim, 'RGBA')))
        c.save(f'{DST}/S_{name}.png', optimize=True); rects['S_' + name] = r

json.dump({'canvas': canvas, 'rects': rects}, open(f'{DST}/layers.json', 'w'), indent=0, sort_keys=True)
mb = sum(os.path.getsize(p) for p in glob.glob(f'{DST}/*')) / 1e6
print('ok', len(os.listdir(DST)), 'files', f'{mb:.1f} MB')
