"""Headwear, glasses, necklaces, wings/backs and things to hold."""
import math
from geom import *
from body import HAND_L, LW, FEET_Y
from clothes import bow, item

HR = (600 - HAND_L[0], HAND_L[1])

def hats():
    out = []
    def hat(id_, S, default=3, accent='#FFFFFF', color='own', z=60, back=None):
        L = [{'z': z, 'shapes': S}]
        if back: L.append({'z': 8, 'shapes': back})
        return item(id_, 'hat', L, color=color, default=default, accent=accent, patternable=False)
    out.append(hat('h_bigbow', bow(390, 150, 1.6, 'c'), default=4))
    out.append(hat('h_twobows', bow(196, 172, 0.9, 'c') + bow(404, 172, 0.9, 'c'), default=3))
    crown = [{'d': poly([(246, 140), (250, 96), (274, 120), (300, 84), (326, 120), (350, 96), (354, 140)]) , 'f': '#FFD45E', 's': '#C08A2A', 'w': LW},
             {'d': rrect(244, 132, 112, 16, 6), 'f': '#F2B83E', 's': '#C08A2A', 'w': 3.5},
             {'d': circle(300, 120, 8), 'f': 'c', 's': 'c.o', 'w': 3}, {'d': both(circle(266, 128, 5)), 'f': 'c', 's': 'c.o', 'w': 2.5},
             {'d': both(circle(250, 94, 5)) + ' ' + circle(300, 82, 6), 'f': '#FFF3B0', 's': '#C08A2A', 'w': 2.5}]
    out.append(hat('h_crown', crown, default=4))
    tiara = [{'d': smooth_open([(214, 172), (300, 140), (386, 172)]), 's': '#C9C6D9', 'w': 7},
             {'d': poly([(270, 152), (284, 128), (300, 112), (316, 128), (330, 152), (300, 144)]), 'f': '#E8E6F2', 's': '#9E9AB4', 'w': 3},
             {'d': heart(300, 132, 9), 'f': 'c', 's': 'c.o', 'w': 2.5}, {'d': both(circle(250, 158, 5)), 'f': 'c', 's': 'c.o', 'w': 2}]
    out.append(hat('h_tiara', tiara, default=15))
    fl = []
    for i, a in enumerate(range(-160, -15, 18)):
        x = 300 + math.cos(math.radians(a)) * 132; y = 196 + math.sin(math.radians(a)) * 72
        col = ['c', 'a', '#FFFFFF'][i % 3]
        fl += [{'d': flower(x, y, 20), 'f': col, 's': (col + '.o') if not col.startswith('#') else '#D0B0C4', 'w': 2.5}, {'d': circle(x, y, 5), 'f': '#FFE27A'}]
    leaves = [{'d': ellipse(300 + math.cos(math.radians(a)) * 136, 200 + math.sin(math.radians(a)) * 74, 12, 6, a + 90), 'f': '#7DCB8E', 's': '#4E9A63', 'w': 2} for a in range(-150, -20, 18)]
    out.append(hat('h_flowers', leaves + fl, default=3, accent='#D2C0FF'))
    def ears(id_, shape, default, inner='#FFC6D9'):
        return hat(id_, shape, default=default, color='own', z=8, back=None)
    cat = [{'d': both(smooth_closed([(196, 160), (190, 92), (250, 134)], 0.4)), 'f': 'c', 's': 'c.o', 'w': LW},
           {'d': both(smooth_closed([(202, 148), (200, 112), (236, 136)], 0.4)), 'f': '#FFC6D9'}]
    out.append(hat('h_cat', [], default=23, back=cat))
    bunny = [{'d': both(ellipse(240, 80, 22, 62, -12)), 'f': 'c', 's': 'c.o', 'w': LW}, {'d': both(ellipse(240, 86, 10, 44, -12)), 'f': '#FFC6D9'}]
    out.append(hat('h_bunny', [{'d': smooth_open([(200, 176), (300, 138), (400, 176)]), 's': 'c.o', 'w': 9}, {'d': smooth_open([(200, 176), (300, 138), (400, 176)]), 's': 'c', 'w': 5}], default=0, back=bunny))
    bear = [{'d': both(circle(204, 140, 30)), 'f': 'c', 's': 'c.o', 'w': LW}, {'d': both(circle(204, 140, 15)), 'f': 'c.l'}]
    out.append(hat('h_bear', [], default=21, back=bear))
    beret = [{'d': smooth_closed([(176, 186), (210, 126), (300, 106), (410, 124), (436, 170), (420, 192), (300, 170), (200, 196)]), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': smooth_open([(300, 108), (306, 92)]), 's': 'c.o', 'w': 7}]
    out.append(hat('h_beret', beret, default=5))
    sun = [{'d': ellipse(300, 170, 200, 40), 'f': 'c', 's': 'c.o', 'w': LW},
           {'d': smooth_closed([(206, 168), (222, 104), (300, 84), (378, 104), (394, 168), (300, 178)]), 'f': 'c', 's': 'c.o', 'w': LW},
           {'d': smooth_closed([(208, 152), (300, 162), (392, 152), (394, 170), (300, 180), (206, 170)]), 'f': 'a', 's': 'a.o', 'w': 3}] + \
          [{'d': flower(370, 156, 20), 'f': '#FFFFFF', 's': '#D0B0C4', 'w': 2.5}, {'d': circle(370, 156, 6), 'f': '#FFE27A'}]
    out.append(hat('h_sunhat', sun, default=1, accent='#FF9EC0'))
    witch = [{'d': ellipse(300, 160, 170, 30), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': smooth_closed([(222, 158), (262, 80), (310, 20), (360, 30), (330, 50), (334, 100), (378, 158), (300, 168)], 0.8), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': smooth_closed([(228, 144), (300, 152), (372, 144), (376, 160), (300, 168), (224, 160)]), 'f': 'a', 's': 'a.o', 'w': 3},
             {'d': star(300, 100, 14, 0.5), 'f': '#FFE27A', 's': '#D69A2A', 'w': 2.5}]
    out.append(hat('h_witch', witch, default=19, accent='#FFE27A'))
    band = [{'d': smooth_open([(184, 200), (230, 150), (300, 136), (370, 150), (416, 200)]), 's': 'c.o', 'w': 16}, {'d': smooth_open([(184, 200), (230, 150), (300, 136), (370, 150), (416, 200)]), 's': 'c', 'w': 11}] + \
           [{'d': ' '.join(circle(300 + math.cos(math.radians(a)) * 108, 196 + math.sin(math.radians(a)) * 58, 4) for a in range(-150, -20, 14)), 'f': '#FFFFFF', 'o': 0.9}]
    out.append(hat('h_headband', band, default=4))
    clips = [{'d': star(218, 214, 18, 0.5, round_=0.3), 'f': 'c', 's': 'c.o', 'w': 3}, {'d': star(246, 186, 14, 0.5, round_=0.3), 'f': 'a', 's': 'a.o', 'w': 3},
             {'d': heart(380, 194, 14), 'f': 'c', 's': 'c.o', 'w': 3}]
    out.append(hat('h_clips', clips, default=10, accent='#FF9EC0'))
    horn = [{'d': poly([(286, 140), (300, 52), (314, 140)]), 'f': '#FFF3DC', 's': '#C9A46A', 'w': 3.5},
            {'d': smooth_open([(290, 124), (310, 116)]) + ' ' + smooth_open([(292, 104), (308, 96)]) + ' ' + smooth_open([(295, 84), (305, 78)]), 's': '#E0B86A', 'w': 3}] + \
           [{'d': flower(256, 150, 18), 'f': 'c', 's': 'c.o', 'w': 2}, {'d': flower(344, 150, 18), 'f': 'a', 's': 'a.o', 'w': 2}]
    out.append(hat('h_unicorn', horn, default=3, accent='#D2C0FF'))
    halo = [{'d': ellipse(300, 96, 74, 16), 's': '#F2C14E', 'w': 12, 'o': 0.95}, {'d': ellipse(300, 96, 74, 16), 's': '#FFF3B0', 'w': 5}]
    out.append(hat('h_halo', halo, default=10))
    cap = [{'d': smooth_closed([(170, 196), (196, 128), (300, 104), (404, 128), (430, 196), (300, 182)]), 'f': 'c', 's': 'c.o', 'w': LW},
           {'d': smooth_closed([(220, 190), (300, 176), (380, 190), (390, 214), (300, 202), (210, 214)]), 'f': 'c.s', 's': 'c.o', 'w': LW},
           {'d': star(300, 146, 16, 0.5), 'f': 'a', 's': 'a.o', 'w': 2.5}]
    out.append(hat('h_cap', cap, default=16, accent='#FFE27A'))
    return out

def glasses():
    out = []
    from body import EYE_L
    ex, ey = EYE_L[0], EYE_L[1] + 4
    def g(id_, S, default=23):
        return item(id_, 'glasses', [{'z': 45, 'shapes': S}], default=default, patternable=False)
    out.append(g('g_round', [{'d': both(circle(ex, ey, 46)), 's': 'c', 'w': 6}, {'d': smooth_open([(284, ey - 6), (300, ey - 12), (316, ey - 6)]), 's': 'c', 'w': 6}], default=21))
    out.append(g('g_heart', [{'d': both(heart(ex, ey, 48)), 'f': 'c', 'o': 0.55}, {'d': both(heart(ex, ey, 48)), 's': 'c.o', 'w': 5},
                             {'d': smooth_open([(282, ey - 14), (300, ey - 18), (318, ey - 14)]), 's': 'c.o', 'w': 5}], default=4))
    out.append(g('g_star', [{'d': both(star(ex, ey, 56, 0.6, round_=0.5)), 'f': 'c', 'o': 0.5}, {'d': both(star(ex, ey, 56, 0.6, round_=0.5)), 's': 'c.o', 'w': 5},
                            {'d': smooth_open([(286, ey - 8), (300, ey - 12), (314, ey - 8)]), 's': 'c.o', 'w': 5}], default=9))
    out.append(g('g_cateye', [{'d': both(smooth_closed([(190, ey - 26), (240, ey - 40), (288, ey - 24), (280, ey + 30), (238, ey + 44), (196, ey + 22)])), 's': 'c', 'w': 6},
                              {'d': smooth_open([(286, ey - 14), (300, ey - 18), (314, ey - 14)]), 's': 'c', 'w': 6}], default=19))
    out.append(g('g_sun', [{'d': both(rrect(ex - 46, ey - 32, 92, 70, 28)), 'f': '#3A3340', 'o': 0.85}, {'d': both(rrect(ex - 46, ey - 32, 92, 70, 28)), 's': 'c', 'w': 6},
                           {'d': both(ellipse(ex - 20, ey - 10, 12, 8, -20)), 'f': '#FFFFFF', 'o': 0.5}, {'d': smooth_open([(286, ey - 12), (300, ey - 16), (314, ey - 12)]), 's': 'c', 'w': 6}], default=4))
    return out

def necks():
    out = []
    def n(id_, S, default=0, accent='#FFFFFF'):
        return item(id_, 'neck', [{'z': 32, 'shapes': S}], default=default, accent=accent, patternable=False)
    pearls = [{'d': ' '.join(circle(300 + math.cos(math.radians(a)) * 34, 440 + math.sin(math.radians(a)) * 22, 5.5) for a in range(20, 165, 13)), 'f': '#FFFFFF', 's': '#C7B9C6', 'w': 2}]
    out.append(n('n_pearls', pearls))
    out.append(n('n_heart', [{'d': smooth_open([(270, 444), (300, 466), (330, 444)]), 's': '#F2C14E', 'w': 3}, {'d': heart(300, 474, 11), 'f': 'c', 's': 'c.o', 'w': 2.5}], default=4))
    out.append(n('n_bow', bow(300, 444, 0.75, 'c'), default=5))
    scarf = [{'d': smooth_closed([(260, 432), (300, 446), (340, 432), (346, 450), (300, 466), (254, 450)]), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': smooth_closed([(316, 452), (338, 456), (342, 510), (322, 512)]), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': smooth_open([(320, 500), (340, 498)]), 's': 'c.s', 'w': 4}]
    out.append(n('n_scarf', scarf, default=5))
    out.append(n('n_star', [{'d': smooth_open([(276, 440), (300, 450), (324, 440)]), 's': 'c', 'w': 6}, {'d': star(300, 456, 10, 0.5), 'f': '#FFE27A', 's': '#D69A2A', 'w': 2}], default=19))
    return out

def backs():
    out = []
    def b(id_, S, default=11, accent='#FFFFFF', color='own', scale=1.55):
        S = xshapes(S, sx=scale, ox=300, oy=470, dy=-20) if scale != 1 else S
        return item(id_, 'back', [{'z': 5, 'shapes': S}], color=color, default=default, accent=accent, patternable=False)
    fairy = [{'d': both(smooth_closed([(290, 470), (230, 380), (160, 360), (140, 410), (190, 470)])), 'f': 'c.l', 's': 'c', 'w': 4, 'o': 0.9},
             {'d': both(smooth_closed([(290, 480), (220, 520), (190, 570), (230, 580), (280, 520)])), 'f': 'c.l', 's': 'c', 'w': 4, 'o': 0.9},
             {'d': both(' '.join(circle(x, y, 4) for x, y in ((180, 400), (206, 428), (222, 540)))), 'f': '#FFFFFF'}]
    out.append(b('w_fairy', fairy, default=11))
    angel = []
    for i in range(4):
        angel.append({'d': both(smooth_closed([(290, 460 + i * 4), (240 - i * 6, 380 + i * 22), (176 - i * 4, 360 + i * 30), (170 - i * 2, 400 + i * 30), (230, 470 + i * 12)], 0.9)),
                      'f': '#FFFFFF', 's': '#C9C3D9', 'w': 3.5})
    out.append(b('w_angel', angel, color=None))
    bfly = [{'d': both(smooth_closed([(290, 470), (240, 370), (170, 350), (160, 420), (220, 476)])), 'f': 'c', 's': 'c.o', 'w': LW},
            {'d': both(smooth_closed([(290, 480), (230, 500), (196, 560), (240, 586), (282, 520)])), 'f': 'a', 's': 'a.o', 'w': LW},
            {'d': both(circle(200, 404, 14) + ' ' + circle(232, 540, 9)), 'f': '#FFFFFF', 'o': 0.8}]
    out.append(b('w_butterfly', bfly, default=8, accent='#FFE27A'))
    bat = [{'d': both(smooth_closed([(290, 470), (240, 400), (160, 380), (176, 420), (150, 440), (180, 456), (170, 486), (240, 484)], 0.6)), 'f': 'c', 's': 'c.o', 'w': LW}]
    out.append(b('w_bat', bat, default=20))
    bag = [{'d': rrect(220, 440, 160, 140, 40), 'f': 'c', 's': 'c.o', 'w': LW}]
    out.append(b('w_backpack', bag + [{'d': both(ellipse(222, 520, 16, 30)), 'f': 'c.s', 's': 'c.o', 'w': LW}], default=12, scale=1.0))
    cape = [{'d': smooth_closed([(236, 440), (300, 430), (364, 440), (420, 600), (430, 700), (300, 690), (170, 700), (180, 600)]), 'f': 'c', 's': 'c.o', 'w': LW}]
    out.append(b('w_cape', cape, default=5, scale=1.0))
    return out

def held():
    out = []
    hx_, hy = HR
    def h(id_, S, default=3, accent='#FFFFFF', color='own', z=70):
        return item(id_, 'hold', [{'z': z, 'shapes': S}], color=color, default=default, accent=accent, patternable=False)
    # balloon on a string from the right hand
    out.append(h('p_balloon', [{'d': smooth_open([(hx_, hy), (hx_ + 20, 450), (hx_ + 10, 360), (hx_ + 30, 300)]), 's': '#9E8AA6', 'w': 2.5},
                               {'d': heart(hx_ + 32, 250, 50), 'f': 'c', 's': 'c.o', 'w': LW}, {'d': ellipse(hx_ + 14, 232, 10, 16, 30), 'f': '#FFFFFF', 'o': 0.6}], default=4))
    out.append(h('p_wand', [{'d': smooth_open([(hx_ - 4, hy + 12), (hx_ + 30, 470)]), 's': '#C08A2A', 'w': 9}, {'d': smooth_open([(hx_ - 4, hy + 12), (hx_ + 30, 470)]), 's': '#FFE27A', 'w': 5},
                            {'d': star(hx_ + 34, 456, 30, 0.5, round_=0.3), 'f': '#FFE27A', 's': '#D69A2A', 'w': 3.5},
                            {'d': star(hx_ + 60, 420, 8, 0.4, 4) + ' ' + star(hx_ + 6, 430, 6, 0.4, 4), 'f': '#FFFFFF'},
                            {'d': circle(hx_, hy, 18), 'f': 'skin', 's': 'skin.o', 'w': LW}], color=None))
    out.append(h('p_icecream', [{'d': poly([(hx_ - 18, 520), (hx_ + 18, 520), (hx_, 572)]), 'f': '#E9B26A', 's': '#B07A3A', 'w': 3.5},
                                {'d': circle(hx_, 506, 22), 'f': 'c', 's': 'c.o', 'w': 3.5}, {'d': circle(hx_ - 4, 476, 18), 'f': 'a', 's': 'a.o', 'w': 3.5},
                                {'d': circle(hx_ + 2, 456, 7), 'f': '#E8475A'},
                                {'d': circle(hx_, hy, 18), 'f': 'skin', 's': 'skin.o', 'w': LW}], default=3, accent='#FFF3DC'))
    bq = [{'d': ' '.join(smooth_open([(hx_, hy), (hx_ + dx, 470)]) for dx in (-20, 0, 22)), 's': '#4E9A63', 'w': 4}]
    for dx, dy, col in ((-22, 466, 'c'), (2, 452, 'a'), (24, 470, 'c'), (-6, 486, '#FFFFFF'), (16, 490, 'a')):
        bq += [{'d': flower(hx_ + dx, dy, 18), 'f': col, 's': (col + '.o') if not col.startswith('#') else '#D0B0C4', 'w': 2}, {'d': circle(hx_ + dx, dy, 4), 'f': '#FFE27A'}]
    bq += [{'d': poly([(hx_ - 20, 520), (hx_ + 20, 520), (hx_ + 8, 570), (hx_ - 8, 570)]), 'f': '#FFFFFF', 's': '#D0B0C4', 'w': 3}, {'d': circle(hx_, hy, 18), 'f': 'skin', 's': 'skin.o', 'w': LW}]
    out.append(h('p_bouquet', bq, default=3, accent='#FFE27A'))
    lolly = [{'d': smooth_open([(hx_, hy + 10), (hx_ + 6, 470)]), 's': '#FFFFFF', 'w': 6},
             {'d': circle(hx_ + 6, 446, 32), 'f': 'c', 's': 'c.o', 'w': LW}]
    sp = []
    for k in range(40):
        a = k * 0.45; r = 3 + k * 0.7
        sp.append((hx_ + 6 + math.cos(a) * r, 446 + math.sin(a) * r))
    lolly += [{'d': smooth_open(sp), 's': '#FFFFFF', 'w': 5}, {'d': circle(hx_, hy, 18), 'f': 'skin', 's': 'skin.o', 'w': LW}]
    out.append(h('p_lolly', lolly, default=4))
    umb = [{'d': smooth_open([(hx_, hy + 14), (hx_ + 20, 330)]), 's': '#7E6A80', 'w': 5},
           {'d': smooth_closed([(hx_ - 110, 360), (hx_ - 70, 280), (hx_ + 20, 250), (hx_ + 110, 270), (hx_ + 150, 340), (hx_ + 110, 330), (hx_ + 70, 345), (hx_ + 20, 330), (hx_ - 30, 350), (hx_ - 70, 345)]), 'f': 'c', 's': 'c.o', 'w': LW},
           {'d': smooth_open([(hx_ + 20, 252), (hx_ - 30, 350)]) + ' ' + smooth_open([(hx_ + 20, 252), (hx_ + 70, 345)]), 's': 'c.o', 'w': 3},
           {'d': circle(hx_, hy, 18), 'f': 'skin', 's': 'skin.o', 'w': LW}]
    umb = [{'d': smooth_open([(hx_, hy + 14), (hx_ + 26, 262)]), 's': '#7E6A80', 'w': 5}] + xshapes(umb[1:-1], sx=1.15, ox=hx_ + 20, oy=330, dy=-70) + umb[-1:]
    out.append(h('p_umbrella', umb, default=3))
    purse = [{'d': smooth_open([(hx_ - 16, 556), (hx_, 540), (hx_ + 16, 556)]), 's': 'c.o', 'w': 4},
             {'d': heart(hx_, 588, 30), 'f': 'c', 's': 'c.o', 'w': LW}, {'d': circle(hx_, 576, 5), 'f': '#F2C14E'}, {'d': circle(hx_, hy, 18), 'f': 'skin', 's': 'skin.o', 'w': LW}]
    out.append(h('p_purse', purse, default=4))
    # plush teddy hugged at the left side
    tx, ty = 170, 640
    teddy = [{'d': circle(tx - 30, ty - 62, 15) + ' ' + circle(tx + 30, ty - 62, 15), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': ellipse(tx, ty + 30, 44, 48), 'f': 'c', 's': 'c.o', 'w': LW}, {'d': circle(tx, ty - 34, 42), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': ellipse(tx, ty - 22, 16, 12), 'f': 'c.l'}, {'d': circle(tx - 15, ty - 40, 4.5) + ' ' + circle(tx + 15, ty - 40, 4.5), 'f': '#3D2433'},
             {'d': ellipse(tx, ty - 27, 5, 4), 'f': '#3D2433'}, {'d': ellipse(tx, ty + 36, 22, 24), 'f': 'c.l'}] + bow(tx, ty + 2, 0.5, 'a')
    out.append(h('p_teddy', xshapes(teddy, sx=1.25, ox=tx, oy=ty + 70), default=21, accent='#F45C9A'))
    # kitty friend sitting at her feet
    kx, ky = 440, 700
    kitty = [{'d': smooth_open([(kx + 40, ky + 30), (kx + 70, ky + 10), (kx + 66, ky - 30)]), 's': 'c.o', 'w': 18}, {'d': smooth_open([(kx + 40, ky + 30), (kx + 70, ky + 10), (kx + 66, ky - 30)]), 's': 'c', 'w': 10},
             {'d': ellipse(kx, ky + 20, 42, 36), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': smooth_closed([(kx - 40, ky - 40), (kx - 36, ky - 96), (kx - 8, ky - 70)], 0.4) + ' ' + smooth_closed([(kx + 40, ky - 40), (kx + 36, ky - 96), (kx + 8, ky - 70)], 0.4), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': ellipse(kx, ky - 40, 46, 38), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': ellipse(kx - 16, ky - 42, 6, 8) + ' ' + ellipse(kx + 16, ky - 42, 6, 8), 'f': '#3D2433'},
             {'d': circle(kx - 18, ky - 45, 2.2) + ' ' + circle(kx + 14, ky - 45, 2.2), 'f': '#FFFFFF'},
             {'d': smooth_open([(kx - 7, ky - 28), (kx, ky - 24), (kx + 7, ky - 28)]), 's': '#3D2433', 'w': 3},
             {'d': ellipse(kx - 28, ky - 30, 9, 5) + ' ' + ellipse(kx + 28, ky - 30, 9, 5), 'f': '#FF8FAA', 'o': 0.6}] + bow(kx + 26, ky - 68, 0.4, 'a')
    out.append(h('p_kitty', xshapes(kitty, sx=1.3, ox=kx, oy=ky + 56, dx=10), default=0, accent='#F45C9A'))
    px, py = 440, 700
    puppy = [{'d': ellipse(px, py + 22, 44, 34), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': ellipse(px, py - 40, 48, 40), 'f': 'c', 's': 'c.o', 'w': LW},
             {'d': ellipse(px - 46, py - 32, 16, 32, 20) + ' ' + ellipse(px + 46, py - 32, 16, 32, -20), 'f': 'c.s', 's': 'c.o', 'w': LW},
             {'d': ellipse(px, py - 26, 20, 15), 'f': 'c.l'},
             {'d': ellipse(px - 17, py - 46, 6, 8) + ' ' + ellipse(px + 17, py - 46, 6, 8), 'f': '#3D2433'},
             {'d': ellipse(px, py - 32, 7, 5), 'f': '#3D2433'},
             {'d': ellipse(px + 3, py - 14, 6, 8), 'f': '#FF8FAA', 's': '#C2506A', 'w': 2},
             {'d': smooth_open([(px - 30, py - 8), (px, py - 2), (px + 30, py - 8)]), 's': 'a', 'w': 7}]
    out.append(h('p_puppy', xshapes(puppy, sx=1.3, ox=px, oy=py + 56, dx=10), default=1, accent='#E8475A'))
    bun = [{'d': ellipse(px - 16, py - 100, 12, 34, -10) + ' ' + ellipse(px + 16, py - 100, 12, 34, 10), 'f': 'c', 's': 'c.o', 'w': LW},
           {'d': ellipse(px - 16, py - 98, 5, 22, -10) + ' ' + ellipse(px + 16, py - 98, 5, 22, 10), 'f': '#FFC6D9'},
           {'d': ellipse(px, py + 22, 40, 34), 'f': 'c', 's': 'c.o', 'w': LW}, {'d': ellipse(px, py - 40, 42, 36), 'f': 'c', 's': 'c.o', 'w': LW},
           {'d': circle(px - 15, py - 42, 5) + ' ' + circle(px + 15, py - 42, 5), 'f': '#3D2433'},
           {'d': smooth_open([(px - 6, py - 28), (px, py - 25), (px + 6, py - 28)]), 's': '#3D2433', 'w': 3},
           {'d': ellipse(px - 26, py - 30, 8, 5) + ' ' + ellipse(px + 26, py - 30, 8, 5), 'f': '#FF8FAA', 'o': 0.6}]
    out.append(h('p_bunny', xshapes(bun, sx=1.3, ox=px, oy=py + 56, dx=10), default=0))
    return out
