"""Three tones (shadow, base, light) for every palette swatch, built in OKLCH, for ramp tinting.
Shadow: darker, a little more chroma, hue turned toward violet. Light: a little lighter and warmer
(the gloss pass adds the real highlights, so the light tone stays close to the base).
usage: python3 tools/make_ramps.py [--md]   (JSON by default, a Markdown table with --md)
The palette below mirrors Palette in App/Sources/Model.swift; keep them in step."""
import math, json, sys

def s2l(c): c /= 255; return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def l2s(c): c = max(0.0, min(1.0, c)); v = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055; return round(v * 255)

def to_oklab(rgb):
    r, g, b = (s2l(int(rgb[i:i + 2], 16)) for i in (0, 2, 4))
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(x) ** (1 / 3), x) for x in (l, m, s))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)

def from_oklab(L, a, b):
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return '%02X%02X%02X' % (l2s(r), l2s(g), l2s(bb))

def lch(hexc):
    L, a, b = to_oklab(hexc); return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360

def from_lch(L, C, h):
    # reduce chroma until in gamut
    for _ in range(40):
        a, b = C * math.cos(math.radians(h)), C * math.sin(math.radians(h))
        lms = [(L + 0.3963377774 * a + 0.2158037573 * b) ** 3, (L - 0.1055613458 * a - 0.0638541728 * b) ** 3,
               (L - 0.0894841775 * a - 1.2914855480 * b) ** 3]
        r = 4.0767416621 * lms[0] - 3.3077115913 * lms[1] + 0.2309699292 * lms[2]
        g = -1.2684380046 * lms[0] + 2.6097574011 * lms[1] - 0.3413193965 * lms[2]
        bb = -0.0041960863 * lms[0] - 0.7034186147 * lms[1] + 1.7076147010 * lms[2]
        if all(-0.001 <= v <= 1.001 for v in (r, g, bb)): break
        C *= 0.95
    return from_oklab(L, a, b)

def turn(h, target, amount):
    d = ((target - h + 180) % 360) - 180
    return (h + max(-amount, min(amount, d))) % 360

def ramp(hexc, dark=0.20, light=0.10):
    L, C, h = lch(hexc)
    if C < 0.02:   # white or near-grey: cool shadow, keep light neutral
        return from_lch(L - dark, 0.03, 285), hexc, from_lch(min(0.99, L + light * 0.3), 0.0, h)
    shadow = from_lch(max(0.2, L - dark), C * 1.10, turn(h, 300, 16))   # toward violet
    lit = from_lch(min(0.97, L + light), C * (0.85 if L > 0.75 else 0.95), turn(h, 85, 10))  # toward warm yellow
    return shadow, hexc, lit

PAL = {
  'clothes': ['FF8FC4', 'FF6470', 'FFB25C', 'FFE36B', '8EE08A', '7DB4FF', 'B993FF', 'FFFFFF'],
  'hair': ['FFD36E', '9A6440', '4A3A44', 'E8774E', 'FF9AD0', 'B48CFF', '79C3FF', '86E6C4'],
  'skin': ['FFE2D0', 'F6C9AE', 'E0A97F', 'B97E57', '8A5A3D'],
  'eyes': ['6FA2F0', 'B0784E', '6CCB86', 'B27CF0', 'F07CB4'],
}
AMOUNTS = {'skin': (0.16, 0.05), 'hair': (0.20, 0.07)}   # (darker, lighter); others use (0.20, 0.06)
RAMPS = {k: [ramp(c, *AMOUNTS.get(k, (0.20, 0.06))) for c in cols] for k, cols in PAL.items()}

NAMES = {
  'clothes': ['pink', 'red', 'orange', 'yellow', 'green', 'blue', 'purple', 'white'],
  'hair': ['golden', 'brown', 'black', 'red', 'pink', 'purple', 'blue', 'mint'],
  'skin': ['peach', 'rosy', 'honey', 'caramel', 'cocoa'],
  'eyes': ['blue', 'brown', 'green', 'purple', 'pink'],
}

if __name__ == '__main__':
    if '--md' in sys.argv:   # eyes keep multiply tinting, so they are left out
        print('| Group | Swatch | Shadow | Base | Light |\n|---|---|---|---|---|')
        for k in ('clothes', 'hair', 'skin'):
            for name, (s, b, l) in zip(NAMES[k], RAMPS[k]):
                print(f'| {k} | {name} | `#{s}` | `#{b}` | `#{l}` |')
    else:
        print(json.dumps(RAMPS, indent=1))
