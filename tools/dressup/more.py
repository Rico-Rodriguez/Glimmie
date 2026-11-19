"""Second batch of content."""
import math, random
from geom import *
from body import LEG_L, LEG_W, HAND_L, LW, FEET_Y, mtube
import hair as H
import clothes as C
from clothes import item, bow, buttons, dress, top, skirt_shape, pleats, sash, legs, shorts_shape, waistband
from extras import HR
import backgrounds as BG

SHORT = [(300, 140), (214, 150), (160, 206), (146, 290), (156, 380), (196, 420), (300, 430)]

def fronts():
    out = []
    swept = [(206, 224, 8), (250, 238, 10), (298, 252, 12), (350, 266, 12), (398, 270, 6)]
    spec = [(600 - x, y, -l) for x, y, l in swept][::-1]
    out.append(H.hair_front('hf_swept_l', H.clumps([(x, 46, y, l) for x, y, l in spec])))
    out.append(H.hair_front('hf_micro', H.even_clumps(6, tip=232, sag=4), side_len=360))
    out.append(H.hair_front('hf_chunky', H.even_clumps(3, tip=266, sag=14)))
    curtain = [(190, 330), (200, 260), (232, 216), (280, 196), (300, 210), (320, 196), (368, 216), (400, 260), (410, 330)]
    out.append(H.hair_front('hf_curtain', curtain, side_len=430))
    out.append(H.hair_front('hf_wavy_long', H.even_clumps(5, tip=258), side_len=470, bulge=6))
    spikes = []
    for i in range(6):
        x = 188 + i * 37.3
        spikes += [(x, 236), (x + 20, 268)]
    spikes.append((412, 236))
    out.append(H.hair_front('hf_spiky', spikes))
    return out

def backs():
    out = []
    pony = [{'d': smooth_closed([(170, 300), (130, 340), (118, 430), (130, 540), (150, 580), (160, 500), (176, 420), (196, 340)]), 'f': 'c', 's': 'c.o', 'w': LW}] + H.scrunchie(176, 316, 18)
    out.append(H.hair_back('hb_sidepony', SHORT, extra=pony))
    puffs = []
    for x in (170, 430):
        D = ' '.join(circle(x + math.cos(a) * 40, 150 + math.sin(a) * 40, 30) for a in [k * 0.9 for k in range(7)]) + ' ' + circle(x, 150, 46)
        puffs += [{'d': D, 's': 'c.o', 'w': LW * 2}, {'d': D, 'f': 'c'}]
    puffs += H.scrunchie(196, 186, 14) + H.scrunchie(404, 186, 14)
    out.append(H.hair_back('hb_puffs', SHORT, extra=puffs))
    D = ' '.join(circle(300 + math.cos(a) * 150, 280 + math.sin(a) * 160, 56) for a in [k * 0.524 for k in range(12)]) + ' ' + ellipse(300, 280, 170, 180)
    afro = [{'d': D, 's': 'c.o', 'w': LW * 2}, {'d': D, 'f': 'c'}]
    out.append(H.hair_back('hb_afro', None, extra=afro))
    low = [{'d': H.tail(170, 380, 640, 90, curl=-20, flip=1), 'f': 'c', 's': 'c.o', 'w': LW},
           {'d': H.tail(430, 380, 640, 90, curl=-20, flip=-1), 'f': 'c', 's': 'c.o', 'w': LW}] + H.scrunchie(178, 392) + H.scrunchie(422, 392)
    out.append(H.hair_back('hb_lowtails', SHORT, extra=low))
    halfbuns = []
    for x in (200, 400):
        halfbuns += [{'d': circle(x, 140, 40), 'f': 'c', 's': 'c.o', 'w': LW}]
    out.append(H.hair_back('hb_halfbuns', [(300, 140), (210, 150), (156, 210), (140, 320), (138, 460), (144, 600), (170, 642), (206, 624), (236, 648), (270, 628), (300, 640)], extra=halfbuns))
    out.append(H.hair_back('hb_shoulder', [(300, 140), (210, 150), (156, 206), (140, 300), (142, 400), (152, 470), (196, 476), (240, 470), (300, 470)]))
    return out

def tops():
    out = []
    out.append(top('t_turtle', 'high', 534, 0.9, cuff='c', default=12, extra=[{'d': rrect(270, 426, 60, 22, 10), 'f': 'c', 's': 'c.o', 'w': 3.5}]))
    out.append(top('t_heart', 'crew', 528, 0.36, extra=[{'d': heart(300, 486, 24), 'f': 'a', 's': 'a.o', 'w': 3}], default=0, accent='#F45C9A'))
    out.append(top('t_bowblouse', 'crew', 528, 1, 'puff', extra=bow(300, 452, 0.9, 'a'), default=0, accent='#E8475A'))
    rain = []
    for i, c in enumerate(('#FF8A9E', '#FFB36B', '#FFE27A', '#9FE3A0', '#9CCBFF', '#C9AEF5')):
        rain.append({'d': rect_band(470 + i * 10), 'f': c})
    out.append(top('t_rainbow', 'crew', 528, 0.36, extra=rain, default=0))
    return out

def rect_band(y):
    return poly([(244, y), (356, y), (356, y + 10), (244, y + 10)])

def dresses():
    out = []
    star_sk = [{'d': skirt_shape(500, 630, 92), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + pleats(500, 630, 92, 6) + \
              [{'d': star(300, 580, 26, 0.5), 'f': 'a', 's': 'a.o', 'w': 3}]
    out.append(dress('d_star', 'v', 0.36, skirt=star_sk, default=17, accent='#FFE27A', extra=[{'d': both(star(262, 600, 9, 0.5)), 'f': '#FFFFFF', 'o': 0.8}]))
    tulip = [{'d': sym([(300, 500), (252, 500), (240, 530), (222, 590), (236, 616), (270, 600), (300, 620)]), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}]
    out.append(dress('d_tulip', 'square', 0, skirt=tulip, extra=sash(510, 'a'), default=3, accent='#FFFFFF'))
    leo = [{'d': shorts_shape(500, 560), 'f': 'c', 's': 'c.o', 'w': LW},
           {'d': skirt_shape(512, 576, 110, scallop=8, n=9), 'f': 'c.l', 's': 'c.o', 'w': 3.5, 'o': 0.95},
           {'d': skirt_shape(512, 566, 96, scallop=8, n=8), 'f': 'c.l', 's': 'c.o', 'w': 3.5}]
    out.append(dress('d_ballerina', 'scoop', 0, skirt=leo, default=2, extra=[{'d': both(smooth_open([(270, 442), (262, 436)])), 's': 'c.o', 'w': 12}, {'d': both(smooth_open([(270, 442), (262, 436)])), 's': 'c', 'w': 6}]))
    tiers = []
    cols = ['#C9AEF5', '#9CCBFF', '#9FE3A0', '#FFE27A', '#FFB36B', '#FF8A9E']
    for i, c in enumerate(cols):
        h = 640 - i * 22
        tiers.append({'d': skirt_shape(502, h, 110 - i * 9, scallop=8, n=7), 'f': c, 's': '#B07A9E', 'w': 3.5})
    out.append(dress('d_rainbow', 'square', 1, 'puff', skirt=tiers, default=0, extra=bow(300, 506, 0.8, '#FF8A9E')))
    heartd = [{'d': skirt_shape(500, 626, 100, scallop=10, n=7), 'f': 'c', 's': 'c.o', 'w': LW, 'pat': 1}] + \
             [{'d': ' '.join(heart(300 + dx, 600, 9) for dx in (-80, -40, 0, 40, 80)), 'f': 'a'}]
    out.append(dress('d_hearts', 'scoop', 0.36, skirt=heartd, default=5, accent='#FFFFFF', extra=[{'d': heart(300, 470, 14), 'f': 'a', 's': 'a.o', 'w': 2.5}]))
    return out

def hats():
    out = []
    def hat(id_, S, default=3, accent='#FFFFFF', back=None):
        L = [{'z': 60, 'shapes': S}]
        if back: L.append({'z': 8, 'shapes': back})
        return item(id_, 'hat', L, default=default, accent=accent, patternable=False)
    beanie = [{'d': smooth_closed([(168, 210), (190, 140), (300, 104), (410, 140), (432, 210), (300, 196)]), 'f': 'c', 's': 'c.o', 'w': LW},
              {'d': rrect(160, 192, 280, 34, 16), 'f': 'c.s', 's': 'c.o', 'w': LW},
              {'d': ' '.join(smooth_open([(180 + i * 20, 198), (180 + i * 20, 220)]) for i in range(13)), 's': 'c.o', 'w': 2.5, 'o': 0.4},
              {'d': ' '.join(circle(300 + math.cos(a) * 18, 96 + math.sin(a) * 18, 14) for a in [k * 0.9 for k in range(7)]), 'f': 'a', 's': 'a.o', 'w': 3}]
    out.append(hat('h_beanie', beanie, default=19, accent='#FFFFFF'))
    bop = [{'d': smooth_open([(200, 176), (300, 138), (400, 176)]), 's': 'c.o', 'w': 9}, {'d': smooth_open([(200, 176), (300, 138), (400, 176)]), 's': 'c', 'w': 5},
           {'d': smooth_open([(250, 150), (226, 80)]) + ' ' + smooth_open([(350, 150), (374, 80)]), 's': '#7E6A80', 'w': 3},
           {'d': heart(224, 72, 18) + ' ' + heart(376, 72, 18), 'f': 'a', 's': 'a.o', 'w': 3}]
    out.append(hat('h_boppers', bop, default=23, accent='#FF7FB0'))
    fox = [{'d': both(smooth_closed([(196, 168), (176, 80), (254, 136)], 0.5)), 'f': 'c', 's': 'c.o', 'w': LW},
           {'d': both(smooth_closed([(200, 152), (188, 104), (232, 136)], 0.5)), 'f': '#FFFFFF'}]
    out.append(hat('h_fox', [], default=8, back=fox))
    sc = []
    for i, a in enumerate(range(-160, -15, 24)):
        x = 300 + math.cos(math.radians(a)) * 130; y = 196 + math.sin(math.radians(a)) * 70
        sc.append({'d': star(x, y, 18 if i % 2 else 13, 0.5, round_=0.3), 'f': '#FFE27A' if i % 2 else 'c', 's': '#D69A2A' if i % 2 else 'c.o', 'w': 2.5})
    out.append(hat('h_starcrown', sc, default=18))
    sun = [{'d': flower(400, 168, 52, 10), 'f': '#FFD45E', 's': '#D69A2A', 'w': 3}, {'d': circle(400, 168, 18), 'f': '#9B6B52', 's': '#6B4537', 'w': 3}]
    out.append(hat('h_sunflower', sun, default=0))
    shell = [{'d': smooth_closed([(380, 200), (360, 160), (380, 140), (400, 136), (420, 140), (440, 160), (420, 200)]), 'f': 'c', 's': 'c.o', 'w': 3.5},
             {'d': ' '.join(smooth_open([(400, 198), (380 + i * 10, 146)]) for i in range(5)), 's': 'c.o', 'w': 2.5},
             {'d': ' '.join(circle(x, 214, 5) for x in (204, 220, 236)), 'f': '#FFFFFF', 's': '#C7B9C6', 'w': 1.5}]
    out.append(hat('h_shell', shell, default=11))
    return out

def held():
    out = []
    hx_, hy = HR
    hand = {'d': circle(hx_, hy, 18), 'f': 'skin', 's': 'skin.o', 'w': LW}
    def h(id_, S, default=3, accent='#FFFFFF', color='own'):
        return item(id_, 'hold', [{'z': 70, 'shapes': S}], color=color, default=default, accent=accent, patternable=False)
    cup = [{'d': poly([(hx_ - 26, 520), (hx_ + 26, 520), (hx_ + 18, 566), (hx_ - 18, 566)]), 'f': 'a', 's': 'a.o', 'w': 3.5},
           {'d': ' '.join(smooth_open([(hx_ - 18 + i * 9, 522), (hx_ - 14 + i * 7, 564)]) for i in range(5)), 's': 'a.s', 'w': 2.5},
           {'d': cloud_top(hx_, 512), 'f': 'c', 's': 'c.o', 'w': 3.5}, {'d': circle(hx_, 488, 8), 'f': '#E8475A'},
           {'d': ' '.join(rrect(hx_ + dx, 500 + dy, 6, 3, 1.5) for dx, dy in ((-14, 4), (8, -2), (-2, 10), (14, 8))), 'f': '#FFE27A'}, hand]
    out.append(h('p_cupcake', cup, default=3, accent='#9FE3CF'))
    book = [{'d': rrect(hx_ - 34, 500, 68, 80, 6), 'f': 'c', 's': 'c.o', 'w': LW}, {'d': rrect(hx_ - 28, 506, 8, 68, 3), 'f': 'c.s'},
            {'d': star(hx_ + 4, 540, 16, 0.5), 'f': '#FFE27A', 's': '#D69A2A', 'w': 2.5}, hand]
    out.append(h('p_book', book, default=19))
    fl = [{'d': smooth_open([(hx_, hy), (hx_ + 6, 470)]), 's': '#4E9A63', 'w': 5}, {'d': ellipse(hx_ + 16, 500, 12, 6, -30), 'f': '#7DCB8E', 's': '#4E9A63', 'w': 2},
          {'d': flower(hx_ + 6, 456, 34, 6), 'f': 'c', 's': 'c.o', 'w': 3}, {'d': circle(hx_ + 6, 456, 9), 'f': '#FFE27A', 's': '#D69A2A', 'w': 2}, hand]
    out.append(h('p_flower', fl, default=8))
    bub = [{'d': smooth_open([(hx_, hy + 10), (hx_ + 20, 480)]), 's': 'c', 'w': 5}, {'d': circle(hx_ + 26, 466, 16), 's': 'c', 'w': 5}]
    random.seed(3)
    bub += [{'d': circle(hx_ + 60 + random.uniform(-20, 60), 300 + random.uniform(0, 150), random.uniform(10, 26)), 'f': '#FFFFFF', 's': '#9CCBFF', 'w': 2.5, 'o': 0.75} for _ in range(6)]
    out.append(h('p_bubbles', bub + [hand], default=18))
    dx, dy = 450, 700
    duck = [{'d': ellipse(dx, dy + 22, 46, 34), 'f': '#FFE27A', 's': '#D69A2A', 'w': LW}, {'d': circle(dx - 4, dy - 30, 36), 'f': '#FFE27A', 's': '#D69A2A', 'w': LW},
            {'d': ellipse(dx + 34, dy - 22, 16, 8), 'f': '#FFA24C', 's': '#C9762A', 'w': 3}, {'d': circle(dx + 6, dy - 38, 5), 'f': '#3D2433'},
            {'d': ellipse(dx - 18, dy + 18, 22, 14, -20), 'f': '#F2C14E'}, {'d': ellipse(dx + 4, dy - 22, 8, 4), 'f': '#FF8FAA', 'o': 0.6}] + bow(dx - 8, dy - 64, 0.4, 'c')
    out.append(h('p_duck', xshapes(duck, sx=1.2, ox=dx, oy=dy + 56), default=3))
    ux, uy = 160, 640
    uni = [{'d': ellipse(ux, uy + 30, 40, 44), 'f': '#FFFFFF', 's': '#C9C3D9', 'w': LW}, {'d': circle(ux, uy - 34, 40), 'f': '#FFFFFF', 's': '#C9C3D9', 'w': LW},
           {'d': poly([(ux - 8, uy - 70), (ux, uy - 112), (ux + 8, uy - 70)]), 'f': '#FFE27A', 's': '#D69A2A', 'w': 3},
           {'d': smooth_closed([(ux - 36, uy - 60), (ux - 54, uy - 20), (ux - 46, uy + 10), (ux - 30, uy - 30)]), 'f': 'c', 's': 'c.o', 'w': 3},
           {'d': smooth_open([(ux - 20, uy - 38), (ux - 12, uy - 34)]) + ' ' + smooth_open([(ux + 12, uy - 34), (ux + 20, uy - 38)]), 's': '#3D2433', 'w': 4},
           {'d': ellipse(ux - 26, uy - 20, 8, 5) + ' ' + ellipse(ux + 26, uy - 20, 8, 5), 'f': '#FF8FAA', 'o': 0.6}]
    out.append(h('p_unicorn', xshapes(uni, sx=1.25, ox=ux, oy=uy + 74), default=18))
    return out

def cloud_top(x, y):
    return ' '.join(circle(x + dx, y + dy, r) for dx, dy, r in ((-16, 0, 14), (0, -10, 18), (16, 0, 14), (0, 4, 16)))

def bgs():
    out = []
    W, Ht = 1200, 900
    S = [{'d': BG.rect(0, 0, W, Ht), 'g': ['#1E1B4B', '#4B2E83']}] + BG.sparkles(50, 21, '#FFFFFF', (0, 0, W, Ht), (3, 10))
    S += [{'d': circle(220, 220, 90), 'f': '#FF9EC0', 's': '#D46A92', 'w': 5}, {'d': ellipse(220, 220, 150, 26, -15), 's': '#FFE27A', 'w': 10},
          {'d': circle(980, 680, 130), 'f': '#9FE3CF', 's': '#6BB8A0', 'w': 5}, {'d': ' '.join(circle(980 + x, 680 + y, r) for x, y, r in ((-50, -30, 20), (40, 40, 28), (30, -60, 14))), 'f': '#76C7AE'},
          {'d': circle(1000, 160, 40), 'f': '#FFE27A'}]
    out.append(BG.bg('bg_space', S))
    S = [{'d': BG.rect(0, 0, W, Ht), 'g': ['#FFB36B', '#FF7FB0']}, {'d': circle(600, 560, 150), 'f': '#FFE27A', 'o': 0.9},
         {'d': BG.hill(620, 30, 4), 'f': '#9B79E0'}, {'d': BG.hill(720, 30, 5), 'f': '#7A4A88'},
         {'d': BG.cloud(250, 200, 1.1) + ' ' + BG.cloud(950, 260, 0.9), 'f': '#FFD3E0', 'o': 0.9}]
    out.append(BG.bg('bg_sunset', S))
    S = [{'d': BG.rect(0, 0, W, Ht), 'g': ['#BFE8D0', '#E8F7EE']}, {'d': BG.rect(0, 640, W, 260), 'f': '#7DBE7A'}]
    for x, s in ((120, 1.4), (360, 1.0), (900, 1.2), (1100, 0.9)):
        S += BG.tree(x, 660, s, top='#5FAF6A')
    for x, y, s in ((520, 760, 1.0), (760, 800, 1.3), (250, 820, 0.8), (1000, 780, 0.9)):
        S += [{'d': rrect(x - 14 * s, y - 40 * s, 28 * s, 50 * s, 10 * s), 'f': '#FFF3DC', 's': '#C9A46A', 'w': 3},
              {'d': smooth_closed([(x - 56 * s, y - 34 * s), (x - 40 * s, y - 80 * s), (x, y - 96 * s), (x + 40 * s, y - 80 * s), (x + 56 * s, y - 34 * s)]), 'f': '#E8475A', 's': '#B22E44', 'w': 4},
              {'d': ' '.join(circle(x + dx * s, y + dy * s, 7 * s) for dx, dy in ((-24, -56), (8, -76), (26, -50))), 'f': '#FFFFFF'}]
    S += BG.sparkles(16, 22, '#FFF3B0', (0, 300, W, 700), (5, 10))
    out.append(BG.bg('bg_forest', S))
    S = [{'d': BG.rect(0, 0, W, Ht), 'f': '#FFF3DC'}, {'d': ' '.join(BG.rect(x, 0, 60, 600) for x in range(0, W, 120)), 'f': '#FFE7C2'},
         {'d': BG.rect(0, 600, W, 300), 'f': '#E8B58F'}, {'d': BG.rect(0, 600, W, 14), 'f': '#C08B66'}]
    for x in (160, 1000):
        S += [{'d': rrect(x - 90, 180, 180, 14, 6), 'f': '#C08B66'}, {'d': rrect(x - 90, 330, 180, 14, 6), 'f': '#C08B66'}]
        for i, c in enumerate(('#FF9EC0', '#9FE3CF', '#FFE27A')):
            S += [{'d': poly([(x - 70 + i * 50, 290), (x - 40 + i * 50, 290), (x - 46 + i * 50, 330), (x - 64 + i * 50, 330)]), 'f': '#E9B26A', 's': '#B07A3A', 'w': 2.5},
                  {'d': cloud_top(x - 55 + i * 50, 286), 'f': c}]
            S += [{'d': circle(x - 55 + i * 50, 160, 22), 'f': c, 's': '#B07A9E', 'w': 3}]
    out.append(BG.bg('bg_bakery', S))
    return out
