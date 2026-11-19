"""Synthesizes the bakery's own sound effects into App/Resources/Games/Bakery/ (16-bit mono WAV).
Run from the repo root: python3 tools/bakery/sounds.py   (stdlib only). No voices, just sounds."""
import math, os, random, struct, wave

SR = 44100
OUT = 'App/Resources/Games/Bakery'
os.makedirs(OUT, exist_ok=True)
random.seed(11)


def write(name, s, gain=0.8):
    peak = max(1e-9, max(abs(x) for x in s))
    fade = int(SR * 0.005)
    out = []
    for i, x in enumerate(s):
        k = min(1, i / fade, (len(s) - 1 - i) / fade)
        out.append(int(max(-1, min(1, x / peak * gain * k)) * 32767))
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(struct.pack('<%dh' % len(out), *out))


def tone(fn, dur, a=0.004, d=0.1, harm=((1, 1),)):
    ph = [0.0] * len(harm); out = []
    for i in range(int(SR * dur)):
        t = i / SR; fr = fn(t); x = 0
        for k, (m, amp) in enumerate(harm):
            ph[k] += 2 * math.pi * fr * m / SR; x += amp * math.sin(ph[k])
        e = t / a if t < a else math.exp(-(t - a) / d)
        out.append(x * e)
    return out


def noise(dur, cut, env):
    lp = 0; out = []
    for i in range(int(SR * dur)):
        t = i / SR
        c = cut(t) if callable(cut) else cut
        lp += c * (random.uniform(-1, 1) - lp)
        out.append(lp * env(t))
    return out


def mix(*tracks):
    n = max(int(off * SR) + len(t) for t, off in tracks); out = [0.0] * n
    for t, off in tracks:
        o = int(off * SR)
        for i, x in enumerate(t):
            out[o + i] += x
    return out


# plop: something soft dropping into the bowl
write('plop', mix((tone(lambda t: 520 - 2600 * t if t < 0.12 else 210, 0.2, 0.002, 0.05, ((1, 1), (2, 0.2))), 0),
                  (noise(0.08, 0.3, lambda t: math.exp(-t * 60)), 0)), 0.75)
# pour: gooey glug-glug stream
g = []
for k in range(6):
    g.append((tone(lambda t, k=k: 180 + 160 * (t / 0.09) + 30 * k, 0.11, 0.004, 0.04, ((1, 1), (2, 0.3))), k * 0.12))
g.append((noise(0.8, 0.05, lambda t: 0.4 * math.sin(math.pi * t / 0.8)), 0))
write('pour', mix(*g), 0.6)
# swish: one stir of the spoon
write('swish', noise(0.28, lambda t: 0.03 + 0.12 * math.sin(math.pi * t / 0.28), lambda t: math.sin(math.pi * t / 0.28) ** 2), 0.55)
# squeeze: frosting coming out of the bag (rising squelch)
write('squeeze', mix((tone(lambda t: 160 + 500 * t + 30 * math.sin(t * 90), 0.35, 0.02, 0.2, ((1, 1), (2, 0.5), (3, 0.3))), 0),
                     (noise(0.35, 0.08, lambda t: 0.5 * math.sin(math.pi * t / 0.35)), 0)), 0.55)
# shake: sprinkles rattling in the shaker
sh = []
for k in range(7):
    sh.append((noise(0.05, 0.9, lambda t: math.exp(-t * 90)), k * 0.055 + random.uniform(0, 0.01)))
write('shake', mix(*sh), 0.55)
# nom: a crunchy bite
write('nom', mix((noise(0.12, 0.6, lambda t: math.exp(-t * 35)), 0), (noise(0.1, 0.5, lambda t: math.exp(-t * 40)), 0.07),
                 (tone(lambda t: 140, 0.12, 0.003, 0.04), 0)), 0.7)
# tick: oven timer tick
write('tick', tone(lambda t: 2400, 0.04, 0.001, 0.008, ((1, 1), (2.3, 0.3))), 0.45)
# doorbell: shop bell, two bright dings
write('doorbell', mix((tone(lambda t: 1318, 0.7, 0.002, 0.25, ((1, 1), (2.76, 0.3), (5.4, 0.1))), 0),
                      (tone(lambda t: 1046, 0.9, 0.002, 0.3, ((1, 1), (2.76, 0.3), (5.4, 0.1))), 0.16)), 0.6)
# scoop: thunk of a scoop landing
write('scoop', mix((tone(lambda t: 300 - 400 * t, 0.16, 0.002, 0.05, ((1, 1), (1.5, 0.3))), 0),
                   (noise(0.06, 0.2, lambda t: math.exp(-t * 70)), 0)), 0.75)
# drizzle: sauce zig-zag
write('drizzle', noise(0.5, lambda t: 0.04 + 0.04 * math.sin(t * 60), lambda t: math.sin(math.pi * t / 0.5)), 0.5)
# oven: warm hum while baking (short, the app loops ticks over it)
write('oven', mix((tone(lambda t: 110, 1.2, 0.2, 2.0, ((1, 1), (2, 0.4), (3, 0.2))), 0),
                  (noise(1.2, 0.02, lambda t: 0.6 * min(1, t / 0.3) * min(1, (1.2 - t) / 0.3)), 0)), 0.45)
# yay: happy little jingle when a customer loves the treat
notes = [784, 988, 1175, 1568, 1175, 1568]
write('yay', mix(*[(tone(lambda t, fr=fr: fr, 0.4, 0.003, 0.14, ((1, 1), (2, 0.3), (4, 0.1))), i * 0.08) for i, fr in enumerate(notes)]), 0.65)
# chomp-finish sparkle swirl
write('magic', mix(*[(tone(lambda t, fr=fr: fr * (1 + t), 0.3, 0.003, 0.1, ((1, 1), (2.76, 0.2))), i * 0.04)
                     for i, fr in enumerate([1568, 1760, 2093, 2349, 2637, 3136])]), 0.5)
# freeze: icy tinkle for ice cream
write('freeze', mix(*[(tone(lambda t, fr=fr: fr, 0.35, 0.002, 0.1, ((1, 1), (3.1, 0.2))), i * 0.05)
                      for i, fr in enumerate([3136, 2637, 3520, 2960, 3951])]), 0.45)

# ---- realistic kitchen sounds (added for the realistic kitchen) ----
# poof: a soft puff of flour landing
write('poof', mix((noise(0.45, lambda t: 0.02 + 0.10 * math.exp(-t * 9), lambda t: min(1, t / 0.02) * math.exp(-t * 7)), 0),
                  (noise(0.3, 0.015, lambda t: 0.8 * math.exp(-t * 10)), 0.03)), 0.5)
# grains: sugar pattering into the bowl
gr = []
for k in range(36):
    gr.append((noise(0.012, 0.95, lambda t: math.exp(-t * 400)), k * 0.026 + random.uniform(0, 0.02)))
gr.append((noise(1.0, 0.4, lambda t: 0.12 * math.sin(math.pi * t)), 0))
write('grains', mix(*gr), 0.45)
# glug: milk pouring out of the carton
gl = [(noise(1.1, lambda t: 0.03 + 0.02 * math.sin(t * 40), lambda t: 0.5 * min(1, t / 0.1) * min(1, (1.1 - t) / 0.2)), 0)]
for k in range(7):
    gl.append((tone(lambda t, k=k: 240 + 900 * t + 25 * (k % 3), 0.08, 0.004, 0.03, ((1, 1), (2, 0.25))), 0.05 + k * 0.145 + random.uniform(0, 0.03)))
write('glug', mix(*gl), 0.55)
# sizzle: the cake crackling as it bakes
sz = [(noise(1.6, 0.5, lambda t: 0.06 * min(1, t / 0.3) * min(1, (1.6 - t) / 0.3)), 0)]
for k in range(40):
    sz.append((noise(0.01, 0.9, lambda t: math.exp(-t * 500)), random.uniform(0, 1.55)))
write('sizzle', mix(*sz), 0.4)
# smear: the spatula spreading thick frosting
write('smear', mix((noise(0.32, lambda t: 0.015 + 0.04 * math.sin(math.pi * t / 0.32), lambda t: math.sin(math.pi * t / 0.32) ** 1.5), 0),
                   (tone(lambda t: 90 + 40 * math.sin(t * 30), 0.32, 0.05, 0.3, ((1, 0.3), (2, 0.1))), 0)), 0.5)
# batter: a thick ribbon of batter flopping into the pan
bt = [(noise(0.9, 0.03, lambda t: 0.5 * min(1, t / 0.1) * min(1, (0.9 - t) / 0.2)), 0)]
for k in range(4):
    bt.append((tone(lambda t: 150 - 300 * t, 0.12, 0.004, 0.05, ((1, 1), (2, 0.2))), 0.1 + k * 0.2 + random.uniform(0, 0.04)))
write('batter', mix(*bt), 0.6)
print(sorted(f for f in os.listdir(OUT) if f.endswith('.wav')))
