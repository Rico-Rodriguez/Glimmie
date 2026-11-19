"""Color roles. The same math lives in Swift (DressUpArt.swift: `Shades`). Keep them identical."""

def hx(h):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))

def to_hex(c):
    return '#' + ''.join(f"{max(0, min(255, round(v * 255))):02X}" for v in c)

INK = hx('#4A2C40')

def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def mul(a, k):
    return tuple(a[i] * k[i] for i in range(3))

def shade(c):   return mul(c, (0.86, 0.78, 0.90))
def light(c):   return mix(c, (1, 1, 1), 0.55)
def deep(c):    return mul(c, (0.62, 0.52, 0.68))
def outline(c): return mix(mul(c, (0.56, 0.42, 0.56)), INK, 0.35)

def role(c, suffix):
    return {'': c, 's': shade(c), 'l': light(c), 'd': deep(c), 'o': outline(c)}[suffix]

SKIN = ['#FFEBE1', '#FFDCCB', '#F7C6A5', '#E9AE86', '#D69468', '#B47350', '#8E563B', '#6C402E']
HAIR = ['#3B2A33', '#6B4537', '#9A5B3F', '#C98A55', '#EBC57A', '#F7E9C4', '#E57D4B', '#C8423E',
        '#FFA5C8', '#F0619A', '#C9AEF5', '#8E6BD6', '#97CDF7', '#5E86D9', '#93E2C9', '#3FAFA6',
        '#DCD9E6', '#FBF8F5']
EYES = ['#8A5236', '#B0843A', '#E39A2E', '#4CAF6E', '#2E8E7A', '#3AA6B5', '#4C8BE0', '#7EC2F2',
        '#8C6BE0', '#F06FA8', '#D64B58', '#8D93A8']
CLOTH = ['#FFFFFF', '#FFF3DC', '#FFD3E0', '#FF9EC0', '#F45C9A', '#E8475A', '#FF8A73', '#FFC2A0',
         '#FFA24C', '#FFE27A', '#F2C14E', '#A8E8CF', '#6CCB8B', '#9DBF9A', '#46B7B0', '#A9D8FF',
         '#5C9BEB', '#3C4A8C', '#D2C0FF', '#9B79E0', '#7A4A88', '#9B6B52', '#B9B7C6', '#3A3340']
