"""Full-screen scenes, drawn in a 1200x900 canvas (aspect-filled behind the doll)."""
import math, random
from geom import *

W, H = 1200, 900

def bg(id_, S, sky=None):
    return {'id': id_, 'cat': 'bg', 'color': None, 'layers': [{'z': 0, 'shapes': S}]}

def rect(x, y, w, h):
    return poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)])

def cloud(cx, cy, s=1.0):
    return ' '.join(circle(cx + dx * s, cy + dy * s, r * s) for dx, dy, r in ((-50, 10, 34), (-10, -12, 46), (40, 4, 38), (78, 18, 26), (-80, 24, 22))) + ' ' + rrect(cx - 100 * s, cy + 10 * s, 200 * s, 34 * s, 17 * s)

def hill(y, amp, n, x0=-50, x1=1250):
    pts = [(x0, H + 10)]
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        pts.append((x, y - amp * math.sin(i * 1.7 + y)))
    pts.append((x1, H + 10))
    return smooth_closed(pts, 0.8)

def tree(x, y, s=1.0, top='#7DCB8E', trunk='#B98563'):
    return [{'d': rrect(x - 14 * s, y - 90 * s, 28 * s, 100 * s, 10 * s), 'f': trunk, 's': '#8C5E44', 'w': 4},
            {'d': ' '.join(circle(x + dx * s, y + dy * s, r * s) for dx, dy, r in ((0, -150, 70), (-50, -110, 50), (50, -110, 50))), 'f': top, 's': '#4E9A63', 'w': 4}]

def flower_spr(x, y, col, s=1.0):
    return [{'d': smooth_open([(x, y), (x, y + 30 * s)]), 's': '#5DAA70', 'w': 4},
            {'d': flower(x, y, 22 * s), 'f': col, 's': '#00000022' if False else '#D49AB4', 'w': 2}, {'d': circle(x, y, 5 * s), 'f': '#FFE27A'}]

def sparkles(n, seed, col='#FFFFFF', area=(0, 0, W, 500), r=(6, 14)):
    random.seed(seed)
    return [{'d': ' '.join(star(random.uniform(area[0], area[2]), random.uniform(area[1], area[3]), random.uniform(*r), 0.35, 4) for _ in range(n)), 'f': col, 'o': 0.9}]

def all_bgs():
    out = []
    # 1 bedroom
    S = [{'d': rect(0, 0, W, H), 'f': '#FFE3EE'}]
    S += [{'d': ' '.join(rect(x, 0, 40, 640) for x in range(0, W, 80)), 'f': '#FFD3E4'}]
    S += [{'d': rect(0, 640, W, 260), 'f': '#F2C9A8'}, {'d': ' '.join(rect(0, y, W, 3) for y in range(680, 900, 50)), 'f': '#DDAE8C'}]
    S += [{'d': rrect(130, 120, 260, 300, 24), 'f': '#BFE3FF', 's': '#FFFFFF', 'w': 18}, {'d': rect(255, 120, 10, 300) + ' ' + rect(130, 265, 260, 10), 'f': '#FFFFFF'},
          {'d': cloud(230, 220, 0.5), 'f': '#FFFFFF'},
          {'d': smooth_closed([(100, 100), (200, 104), (190, 300), (150, 440), (96, 440)]), 'f': '#C9AEF5', 's': '#A58AD6', 'w': 4},
          {'d': smooth_closed([(420, 100), (320, 104), (330, 300), (370, 440), (424, 440)]), 'f': '#C9AEF5', 's': '#A58AD6', 'w': 4},
          {'d': rrect(84, 86, 352, 22, 11), 'f': '#F0A6C6'}]
    S += [{'d': ellipse(600, 800, 360, 70), 'f': '#FFFFFF', 'o': 0.6}, {'d': ellipse(600, 800, 300, 52), 'f': '#C9AEF5', 'o': 0.5}]
    S += [{'d': rrect(860, 300, 220, 16, 6), 'f': '#E8B58F', 's': '#C08B66', 'w': 3},
          {'d': rrect(880, 250, 40, 50, 8), 'f': '#9FE3CF', 's': '#6BB8A0', 'w': 3}, {'d': star(960, 270, 28, 0.5), 'f': '#FFE27A', 's': '#D69A2A', 'w': 3},
          {'d': circle(1030, 274, 24), 'f': '#FF9EC0', 's': '#D46A92', 'w': 3}]
    S += [{'d': ' '.join(heart(x, y, 12) for x, y in ((640, 90), (760, 160), (560, 200), (1100, 120), (720, 300))), 'f': '#FFFFFF', 'o': 0.8}]
    out.append(bg('bg_bedroom', S))
    # 2 park
    S = [{'d': rect(0, 0, W, H), 'g': ['#9FD8FF', '#E3F4FF']}, {'d': circle(1040, 120, 60), 'f': '#FFE27A'}, {'d': circle(1040, 120, 84), 'f': '#FFE27A', 'o': 0.3},
         {'d': cloud(250, 130) + ' ' + cloud(700, 90, 0.8), 'f': '#FFFFFF'},
         {'d': hill(560, 40, 4), 'f': '#A8E39A'}, {'d': hill(650, 30, 5), 'f': '#8CD488', 's': '#6DBB6D', 'w': 4}]
    S += tree(140, 640, 1.2) + tree(1060, 660, 1.0)
    S += [{'d': smooth_closed([(480, 900), (560, 680), (640, 680), (760, 900)]), 'f': '#F3E1B8'}]
    for i, (x, y) in enumerate(((300, 760), (380, 820), (860, 770), (960, 830), (240, 850), (1000, 740))):
        S += flower_spr(x, y, ['#FF9EC0', '#FFFFFF', '#D2C0FF', '#FFE27A'][i % 4])
    out.append(bg('bg_park', S))
    # 3 beach
    S = [{'d': rect(0, 0, W, H), 'g': ['#FFC7D9', '#FFE9D6']}, {'d': circle(880, 300, 90), 'f': '#FFB36B', 'o': 0.9},
         {'d': rect(0, 380, W, 260), 'g': ['#6CC9E8', '#A8E8F0']},
         {'d': ' '.join(smooth_open([(x, y), (x + 30, y - 8), (x + 60, y)]) for x, y in ((120, 440), (420, 480), (760, 450), (980, 520), (260, 560))), 's': '#FFFFFF', 'w': 5, 'o': 0.8},
         {'d': smooth_closed([(-20, 640), (300, 600), (700, 620), (1220, 590), (1220, 910), (-20, 910)]), 'f': '#FFE2A8'},
         {'d': ' '.join(ellipse(x, y, 16, 11) for x, y in ((200, 780), (900, 820), (1040, 720))), 'f': '#FF9EC0', 's': '#E07A9E', 'w': 3},
         {'d': star(380, 830, 22, 0.5, round_=0.4), 'f': '#FFA24C', 's': '#D9762A', 'w': 3}]
    S += [{'d': smooth_open([(1080, 760), (1060, 600), (1000, 470)]), 's': '#A87650', 'w': 26}]
    S += [{'d': ' '.join(ellipse(1000 + math.cos(a) * 80, 470 + math.sin(a) * 30, 80, 20, math.degrees(a)) for a in (-2.6, -1.9, -1.2, -0.5, 0.3)), 'f': '#6CCB8B', 's': '#4E9A63', 'w': 4}]
    out.append(bg('bg_beach', S))
    # 4 castle
    S = [{'d': rect(0, 0, W, H), 'g': ['#E2CFFF', '#FFE0EE']}, {'d': cloud(200, 160, 0.9) + ' ' + cloud(980, 110, 0.7), 'f': '#FFFFFF', 'o': 0.9}]
    S += [{'d': hill(700, 30, 4), 'f': '#B9E6B0'}]
    cx = 600
    S += [{'d': rect(cx - 220, 380, 440, 330), 'f': '#FFF3F8', 's': '#D7B3CC', 'w': 5}]
    for x, h in ((cx - 250, 300), (cx + 250, 300), (cx - 110, 250), (cx + 110, 250), (cx, 180)):
        w = 100 if x in (cx - 250, cx + 250, cx) else 80
        S += [{'d': rect(x - w / 2, h, w, 710 - h), 'f': '#FFF3F8', 's': '#D7B3CC', 'w': 5},
              {'d': poly([(x - w / 2 - 14, h), (x, h - 110), (x + w / 2 + 14, h)]), 'f': '#FF9EC0', 's': '#D46A92', 'w': 5},
              {'d': rrect(x - 14, h + 50, 28, 44, 14), 'f': '#C9AEF5', 's': '#A58AD6', 'w': 3},
              {'d': poly([(x, h - 110), (x, h - 150), (x + 34, h - 138), (x, h - 126)]), 'f': '#FFE27A', 's': '#D69A2A', 'w': 2.5}]
    S += [{'d': smooth_closed([(cx - 60, 710), (cx - 60, 600), (cx, 560), (cx + 60, 600), (cx + 60, 710)]), 'f': '#C9AEF5', 's': '#A58AD6', 'w': 5}]
    S += [{'d': hill(790, 20, 5), 'f': '#9EDB95', 's': '#79C277', 'w': 4}] + sparkles(14, 4, '#FFFFFF', (0, 0, W, 360))
    out.append(bg('bg_castle', S))
    # 5 night sky
    S = [{'d': rect(0, 0, W, H), 'g': ['#2E2A6B', '#8A6BC9']}, {'d': circle(960, 180, 80), 'f': '#FFF3B0'}, {'d': circle(1000, 150, 74), 'f': '#4A3F8A'}]
    S += sparkles(40, 5, '#FFF3B0', (0, 0, W, 600), (4, 12))
    S += [{'d': hill(720, 40, 4), 'f': '#4B4290'}, {'d': hill(800, 30, 5), 'f': '#5E54A8'}]
    S += [{'d': ' '.join(circle(x, y, 4) for x, y in ((200, 700), (260, 760), (900, 720), (1000, 780), (640, 820))), 'f': '#FFE27A'},
          {'d': ' '.join(circle(x, y, 12) for x, y in ((200, 700), (260, 760), (900, 720), (1000, 780), (640, 820))), 'f': '#FFE27A', 'o': 0.25}]
    out.append(bg('bg_night', S))
    # 6 candy land
    S = [{'d': rect(0, 0, W, H), 'g': ['#FFC9E3', '#FFF0F6']}, {'d': cloud(300, 140) + ' ' + cloud(900, 180, 0.8), 'f': '#FFFFFF'},
         {'d': hill(640, 50, 3), 'f': '#C9AEF5'}, {'d': hill(720, 30, 4), 'f': '#9FE3CF', 's': '#76C7AE', 'w': 4}]
    for x, y, c in ((160, 520, '#FF7FB0'), (1040, 500, '#FFA24C'), (880, 600, '#9B79E0')):
        S += [{'d': rect(x - 6, y, 12, 240), 'f': '#FFFFFF', 's': '#E0C9D6', 'w': 3}, {'d': circle(x, y, 60), 'f': c, 's': '#FFFFFF', 'w': 8}]
        sp = [(x + math.cos(k * 0.5) * (4 + k * 1.6), y + math.sin(k * 0.5) * (4 + k * 1.6)) for k in range(32)]
        S += [{'d': smooth_open(sp), 's': '#FFFFFF', 'w': 8}]
    S += [{'d': smooth_closed([(330, 800), (350, 720), (450, 720), (470, 800)]), 'f': '#F2C14E', 's': '#C08A2A', 'w': 4},
          {'d': cloud(400, 690, 0.5), 'f': '#FFFFFF', 's': '#F0C9DA', 'w': 3}, {'d': circle(400, 660, 14), 'f': '#E8475A'}]
    S += sparkles(20, 6, '#FFFFFF', (0, 0, W, 500))
    out.append(bg('bg_candy', S))
    # 7 flower garden
    S = [{'d': rect(0, 0, W, H), 'g': ['#C9F0FF', '#F4FFF4']}, {'d': cloud(600, 120, 0.9), 'f': '#FFFFFF'}]
    S += [{'d': rect(0, 600, W, 300), 'f': '#9EDB95'}]
    S += [{'d': ' '.join(rrect(x, 470, 34, 170, 12) for x in range(10, W, 60)), 'f': '#FFFFFF', 's': '#D8D0E0', 'w': 3}, {'d': rect(0, 520, W, 22) + ' ' + rect(0, 590, W, 22), 'f': '#FFFFFF', 's': '#D8D0E0', 'w': 3}]
    random.seed(7)
    for i in range(26):
        x = random.uniform(20, 1180); y = random.uniform(640, 880)
        S += flower_spr(x, y, ['#FF9EC0', '#FFFFFF', '#D2C0FF', '#FFE27A', '#FF8A73'][i % 5], random.uniform(0.8, 1.3))
    for x, y in ((240, 300), (960, 240)):
        S += [{'d': ellipse(x - 18, y, 18, 24, -20) + ' ' + ellipse(x + 18, y, 18, 24, 20), 'f': '#FFB0D0', 's': '#D46A92', 'w': 3}, {'d': ellipse(x, y, 4, 16), 'f': '#5B3A68'}]
    out.append(bg('bg_garden', S))
    # 8 under the sea
    S = [{'d': rect(0, 0, W, H), 'g': ['#7FD6F0', '#2E7FC4']}]
    S += [{'d': ' '.join(smooth_open([(x, 0), (x + 120, 900)]) for x in range(-200, 1300, 180)), 's': '#FFFFFF', 'w': 40, 'o': 0.08}]
    S += [{'d': smooth_closed([(-20, 760), (300, 720), (700, 740), (1220, 710), (1220, 910), (-20, 910)]), 'f': '#F7DDA8'}]
    for x in (120, 200, 1000, 1100):
        S += [{'d': smooth_open([(x, 760), (x - 20, 680), (x + 16, 600), (x - 10, 520)]), 's': '#3FAF84', 'w': 18}]
    S += [{'d': ' '.join(circle(950 + dx, 720 + dy, r) for dx, dy, r in ((0, 0, 30), (30, -30, 24), (-30, -40, 20), (10, -70, 16))), 'f': '#FF8A9E', 's': '#D85E78', 'w': 4}]
    random.seed(8)
    S += [{'d': ' '.join(circle(random.uniform(0, W), random.uniform(0, 700), random.uniform(6, 16)) for _ in range(24)), 's': '#FFFFFF', 'w': 3, 'o': 0.7}]
    for x, y, c in ((260, 300, '#FFA24C'), (980, 420, '#FFE27A')):
        S += [{'d': ellipse(x, y, 40, 26), 'f': c, 's': '#C9762A', 'w': 4}, {'d': poly([(x + 36, y), (x + 70, y - 24), (x + 70, y + 24)]), 'f': c, 's': '#C9762A', 'w': 4},
              {'d': circle(x - 18, y - 4, 5), 'f': '#3D2433'}]
    out.append(bg('bg_sea', S))
    # 9 stage
    S = [{'d': rect(0, 0, W, H), 'f': '#5B2E5E'}, {'d': poly([(470, 0), (730, 0), (900, 900), (300, 900)]), 'f': '#FFF3B0', 'o': 0.22},
         {'d': ellipse(600, 800, 420, 80), 'f': '#FFF3B0', 'o': 0.3}, {'d': rect(0, 720, W, 180), 'f': '#B97A57'}, {'d': rect(0, 720, W, 12), 'f': '#8C5A3E'}]
    for side in (1, -1):
        x0 = 0 if side == 1 else W
        S += [{'d': smooth_closed([(x0, 0), (x0 + side * 300, 0), (x0 + side * 220, 300), (x0 + side * 260, 760), (x0, 760)]), 'f': '#E8475A', 's': '#B22E44', 'w': 5},
              {'d': ' '.join(smooth_open([(x0 + side * k, 20), (x0 + side * (k - 30), 740)]) for k in (70, 140, 210)), 's': '#C2364D', 'w': 5}]
    S += [{'d': smooth_closed([(0, 0), (W, 0), (W, 70), (1000, 110), (800, 80), (600, 112), (400, 80), (200, 110), (0, 70)]), 'f': '#C2364D', 's': '#8E2235', 'w': 5}]
    S += sparkles(18, 9, '#FFE27A', (200, 120, 1000, 600))
    out.append(bg('bg_stage', S))
    # 10 snow day
    S = [{'d': rect(0, 0, W, H), 'g': ['#BFD9FF', '#EEF5FF']}, {'d': hill(620, 40, 4), 'f': '#FFFFFF', 's': '#D6E2F5', 'w': 4}]
    for x, y, s in ((140, 640, 1.2), (1060, 620, 1.0), (980, 680, 0.7)):
        S += [{'d': poly([(x, y - 220 * s), (x + 80 * s, y - 60 * s), (x - 80 * s, y - 60 * s)]) + ' ' + poly([(x, y - 160 * s), (x + 100 * s, y), (x - 100 * s, y)]), 'f': '#5FAF8A', 's': '#3E8A68', 'w': 4},
              {'d': ' '.join(ellipse(x + dx * s, y + dy * s, 26 * s, 8 * s) for dx, dy in ((-30, -10), (40, -70), (-10, -150))), 'f': '#FFFFFF'}]
    S += [{'d': circle(860, 760, 60) + ' ' + circle(860, 670, 44), 'f': '#FFFFFF', 's': '#C7D5EC', 'w': 4}, {'d': poly([(860, 668), (900, 676), (860, 682)]), 'f': '#FFA24C'},
          {'d': circle(846, 656, 5) + ' ' + circle(874, 656, 5), 'f': '#3D2433'}, {'d': rrect(820, 698, 80, 16, 8), 'f': '#E8475A'}]
    random.seed(10)
    S += [{'d': ' '.join(circle(random.uniform(0, W), random.uniform(0, 860), random.uniform(4, 9)) for _ in range(60)), 'f': '#FFFFFF', 'o': 0.9}]
    out.append(bg('bg_snow', S))
    # 11 rainbow sky
    S = [{'d': rect(0, 0, W, H), 'g': ['#FFE0F0', '#E0F0FF']}]
    for i, c in enumerate(('#FF8A9E', '#FFB36B', '#FFE27A', '#9FE3A0', '#9CCBFF', '#C9AEF5')):
        r = 520 - i * 36
        S += [{'d': ellipse(600, 760, r, r * 0.9), 's': c, 'w': 36}]
    S += [{'d': rect(0, 740, W, 160), 'f': '#E6F0FF'}, {'d': cloud(120, 740, 1.4) + ' ' + cloud(1080, 740, 1.4) + ' ' + cloud(600, 860, 2.2), 'f': '#FFFFFF'}]
    S += sparkles(18, 11, '#FFFFFF', (0, 0, W, 400))
    out.append(bg('bg_rainbow', S))
    # 12 photo booth: soft dots
    S = [{'d': rect(0, 0, W, H), 'f': '#FFF0F6'}, {'d': ' '.join(circle(x + (30 if (y // 60) % 2 else 0), y, 10) for y in range(30, H, 60) for x in range(30, W + 60, 60)), 'f': '#FFD3E4'}]
    S += [{'d': ellipse(600, 860, 300, 50), 'f': '#FFD3E4'}]
    out.append(bg('bg_dots', S))
    return out
