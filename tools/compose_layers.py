"""Side-by-side composite: the shipped layers (multiply tint, as DollView draws them today) next to
new renders (ramp tint, tinted gloss with screen blend, contact shadows), in DollView's draw order.
Every step is one SwiftUI operation, so the right-hand side is what the app would draw:
  ramp tint       CIColorMap with a 4-stop gradient           ramp()
  gloss           .colorMultiply(light tone halfway to white).blendMode(.screen).opacity(k)   screen()
  contact shadow  S_ image, template + tone, .blendMode(.multiply), drawn just under its item
usage: python3 tools/compose_layers.py ART_DIR NEW_DIR OUT_PREFIX [look]
  ART_DIR  App/Resources/Art (L_<name>.png)      NEW_DIR  renders from model_v2_proto.py
  env SCALE=2 renders the sheet at 1600x2000 per side, CROP=x0,y0,x1,y1 crops it (1x coordinates),
  ONLY=after writes just the new side"""
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_ramps import PAL, RAMPS  # noqa: E402

LOOKS = {
    'a': dict(skin=1, eyes=0, hair=('hair_long', 1), items=[('shoes_mary', 1), ('dress_aline', 0), ('hat_bow', 0)]),
}

# Where each tone sits on the base pass's brightness (0..1): deep shadow, shadow, base, light. The base
# stop is near the 85th percentile of a base pass at the new exposure, so the colour the player picked
# is the colour of the lit front of the item, as it is today, and the light tone only reaches the brightest parts.
STOPS = (0.0, 0.45, 0.86, 1.0)
GLOSS = {'skin': 0.35, 'hair': 0.9, 'clothes': 0.6}      # gloss strength per group (the layer's opacity)
SHADOW_TONE = 'B9788C'     # warm mauve: multiplied onto whatever the shadow falls on
SHADOW = dict(drop=6, blur=6, strength=0.8)   # px at 1x (800x1000): offset down, blur radius, opacity


def load(path, size=None):
    im = Image.open(path).convert('RGBA')
    if size and im.size != size: im = im.resize(size, Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255


def hexrgb(h): return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def multiply(layer, hexc):
    out = layer.copy(); out[..., :3] *= hexrgb(hexc); return out


def ramp(layer, trio, stops):
    """Brightness of the near-white render picks a colour on deep shadow, shadow, base, light."""
    sh, base, li = (hexrgb(h) for h in trio)
    cols = [sh * 0.62, sh, base, li]
    lum = layer[..., 0] * 0.2126 + layer[..., 1] * 0.7152 + layer[..., 2] * 0.0722
    out = layer.copy()
    for c in range(3):
        out[..., c] = np.interp(lum, stops, [col[c] for col in cols])
    return out


def screen(layer, gloss, tone, k):
    """Gloss in the light tone mixed halfway to white: light on the surface, not a white sticker."""
    c = gloss[..., :3] * gloss[..., 3:4] * (hexrgb(tone) + 1) / 2 * k
    out = layer.copy(); out[..., :3] = 1 - (1 - layer[..., :3]) * (1 - c); return out


def over(dst, src):
    a = src[..., 3:4]; da = dst[..., 3:4]
    oa = a + da * (1 - a)
    rgb = (src[..., :3] * a + dst[..., :3] * da * (1 - a)) / np.maximum(oa, 1e-6)
    return np.concatenate([rgb, oa], -1)


def blur(a, r):
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), 'L').filter(ImageFilter.GaussianBlur(r))
    return np.asarray(im).astype(np.float32) / 255


def contact_shadow(item_alpha, under_alpha, scale=1, drop=SHADOW['drop'], r=SHADOW['blur'], strength=SHADOW['strength']):
    """The item's outline, moved down a little and blurred, kept only where it lands on `under_alpha`
    (the body, plus the hair cap for hats) and outside the item itself. Returns the S_ layer's alpha."""
    d = int(round(drop * scale))
    moved = np.zeros_like(item_alpha); moved[d:] = item_alpha[:item_alpha.shape[0] - d]
    s = blur(moved, r * scale) * (1 - item_alpha) * under_alpha
    return np.clip(s * strength, 0, 1)


def multiply_shadow(dst, s, tone=SHADOW_TONE):
    out = dst.copy(); t = hexrgb(tone)
    out[..., :3] *= 1 - s[..., None] * (1 - t); return out


def stack(kind, look, size, art, new):
    L = LOOKS[look]; scale = size[0] / 800
    bg = np.zeros((size[1], size[0], 4), np.float32); bg[...] = (*hexrgb('FFE6F1'), 1)
    def path(name): return os.path.join(art, 'L_' + name + '.png') if kind == 'before' else os.path.join(new, name + '.png')
    def get(name): return load(path(name), size)
    def tinted(name, group, idx):
        lay = get(name)
        if kind == 'before': return multiply(lay, PAL[group][idx])
        sh, base, li = RAMPS[group][idx]
        out = ramp(lay, (sh, base, li), STOPS)
        gp = os.path.join(new, 'G_' + name + '.png')
        return screen(out, load(gp, size), li, GLOSS[group]) if os.path.exists(gp) else out
    skin = get('skin'); under = get('under')
    body = np.maximum(skin[..., 3], under[..., 3])
    cap = None
    def put(out, name, group, idx, on=None):
        lay = tinted(name, group, idx)
        if kind == 'after':
            out = multiply_shadow(out, contact_shadow(lay[..., 3], body if on is None else on, scale))
        return over(out, lay)
    out = bg
    out = over(out, tinted('skin', 'skin', L['skin']))
    out = over(out, under)
    out = over(out, multiply(get('eyes'), PAL['eyes'][L['eyes']]))
    out = over(out, get('eyeshine'))
    out = over(out, get('face'))
    for name, c in L['items'][:2]:                              # shoes, dress
        out = put(out, name, 'clothes', c)
    out = put(out, L['hair'][0], 'hair', L['hair'][1])
    shine = L['hair'][0] + '_shine'                             # painted glints, untinted, when the layer exists
    if os.path.exists(path(shine)):
        out = over(out, get(shine))
    if kind == 'after':                                          # hats rest on the cap every hair style shares
        cp = os.path.join(new, 'capproxy.png')
        cap = np.maximum(body, (load(cp, size) if os.path.exists(cp) else get(L['hair'][0]))[..., 3])
    for name, c in L['items'][2:]:                              # hat
        out = put(out, name, 'clothes', c, on=cap)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), 'RGBA').convert('RGB')


def label(im, text):
    d = ImageDraw.Draw(im)
    try: f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 30)
    except OSError: f = ImageFont.load_default()
    d.rounded_rectangle((16, 14, 30 + d.textlength(text, font=f), 58), 10, fill=(255, 255, 255))
    d.text((23, 18), text, fill=(90, 50, 90), font=f)
    return im


if __name__ == '__main__':
    ART, NEW, OUT = sys.argv[1:4]
    LOOK = sys.argv[4] if len(sys.argv) > 4 else 'a'
    scale = int(os.environ.get('SCALE', '1'))
    size = (800 * scale, 1000 * scale)
    a = stack('after', LOOK, size, ART, NEW)
    b = None if os.environ.get('ONLY') == 'after' else stack('before', LOOK, size, ART, NEW)
    crop = os.environ.get('CROP')
    if crop:
        box = tuple(int(v) * scale for v in crop.split(','))
        a = a.crop(box); b = b.crop(box) if b else None
    if b is None:
        a.save(OUT + '.png'); print('wrote', OUT + '.png', a.size); sys.exit()
    sheet = Image.new('RGB', (b.width * 2 + 12, b.height), (255, 255, 255))
    sheet.paste(label(b, 'Now'), (0, 0)); sheet.paste(label(a, 'Upgrade prototype'), (b.width + 12, 0))
    sheet.save(OUT + '.png')
    print('wrote', OUT + '.png', sheet.size)
