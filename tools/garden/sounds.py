"""Synthesizes the garden's sound effects into App/Resources/Games/Garden/ (16-bit mono WAV).
Run from the repo root: python3 tools/garden/sounds.py   (stdlib only). No voices, just sounds.
water, rain, wind, crickets and buzz are seamless loops (the end is crossfaded into the start)."""
import math, os, random, struct, wave

SR = 22050
OUT = 'App/Resources/Games/Garden'
os.makedirs(OUT, exist_ok=True)
random.seed(7)


def write(name, s, gain=0.8, fade=True):
    peak = max(1e-9, max(abs(x) for x in s))
    f = int(SR * 0.005)
    out = []
    for i, x in enumerate(s):
        k = min(1, i / f, (len(s) - 1 - i) / f) if fade else 1
        out.append(int(max(-1, min(1, x / peak * gain * k)) * 32767))
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(struct.pack('<%dh' % len(out), *out))


def loop(name, s, cross=0.4, gain=0.7):
    n = int(SR * cross)
    body = s[:len(s) - n]
    tail = s[len(s) - n:]
    for i in range(n):
        k = i / n
        body[i] = body[i] * k + tail[i] * (1 - k)
    write(name, body, gain, fade=False)


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


# dig: the blade crunching into soil
write('dig', mix((noise(0.18, 0.35, lambda t: math.exp(-t * 22)), 0), (noise(0.1, 0.8, lambda t: math.exp(-t * 50)), 0.02),
                 (tone(lambda t: 120 - 200 * t, 0.12, 0.002, 0.04), 0)), 0.75)
# toss: soil thrown, a swish then a patter
toss = [(noise(0.22, lambda t: 0.05 + 0.2 * t, lambda t: math.sin(math.pi * t / 0.22) ** 2), 0)]
for k in range(6):
    toss.append((noise(0.04, 0.5, lambda t: math.exp(-t * 80)), 0.26 + k * 0.045 + random.uniform(0, 0.02)))
write('toss', mix(*toss), 0.6)
# pat: patting soil down, two soft thumps
write('pat', mix((tone(lambda t: 140, 0.12, 0.002, 0.03, ((1, 1), (2, 0.3))), 0), (noise(0.08, 0.2, lambda t: math.exp(-t * 50)), 0),
                 (tone(lambda t: 130, 0.12, 0.002, 0.03, ((1, 1), (2, 0.3))), 0.16), (noise(0.08, 0.2, lambda t: math.exp(-t * 50)), 0.16)), 0.7)
# seeds: a rattle in a paper packet
sd = []
for k in range(9):
    sd.append((noise(0.025, 0.9, lambda t: math.exp(-t * 140)), k * 0.03 + random.uniform(0, 0.012)))
write('seeds', mix(*sd), 0.5)
# splash: a little water slosh
write('splash', mix((noise(0.3, 0.3, lambda t: math.exp(-t * 12)), 0),
                    (tone(lambda t: 900 + 1400 * t, 0.08, 0.002, 0.03), 0.02), (tone(lambda t: 1300 + 900 * t, 0.06, 0.002, 0.02), 0.09)), 0.6)
# pluck: a weed popping out with its roots
write('pluck', mix((tone(lambda t: 260 + 900 * t, 0.16, 0.003, 0.05, ((1, 1), (2, 0.4))), 0), (noise(0.12, 0.4, lambda t: math.exp(-t * 30)), 0.04)), 0.75)
# grow: a soft rising chime
write('grow', mix(*[(tone(lambda t, f=f: f, 0.5, 0.004, 0.18, ((1, 1), (2, 0.25), (3, 0.08))), k * 0.07)
                    for k, f in enumerate([784, 988, 1175, 1568])]), 0.5)
# basket: something landing in the basket, a wicker thump and a ding
write('basket', mix((noise(0.1, 0.25, lambda t: math.exp(-t * 40)), 0), (tone(lambda t: 180, 0.12, 0.002, 0.04), 0),
                    (tone(lambda t: 1318, 0.5, 0.003, 0.18, ((1, 1), (2.7, 0.2))), 0.05)), 0.6)
# chirp: a little bird
ch = []
for k in range(3):
    ch.append((tone(lambda t: 2600 + 1800 * math.sin(t / 0.08 * math.pi), 0.08, 0.004, 0.05), k * 0.11))
write('chirp', mix(*ch), 0.55)
# plunk: something set down on grass
write('plunk', mix((tone(lambda t: 220 - 300 * t, 0.16, 0.002, 0.05, ((1, 1), (1.5, 0.3))), 0), (noise(0.06, 0.3, lambda t: math.exp(-t * 60)), 0)), 0.65)
# squeak: the worm giggles
write('squeak', mix((tone(lambda t: 1400 + 500 * math.sin(t * 60), 0.12, 0.005, 0.06), 0),
                    (tone(lambda t: 1700 + 500 * math.sin(t * 60), 0.12, 0.005, 0.06), 0.14)), 0.5)
# flutter: wings
fl = []
for k in range(5):
    fl.append((noise(0.035, 0.15, lambda t: math.sin(math.pi * t / 0.035)), k * 0.045))
write('flutter', mix(*fl), 0.45)
# rustle: leaves brushed
write('rustle', noise(0.3, lambda t: 0.25 + 0.2 * math.sin(t * 60), lambda t: math.sin(math.pi * t / 0.3) * (0.6 + 0.4 * random.random())), 0.4)

# Loops
# water: a steady sprinkle of drops on soil
w = noise(2.4, 0.45, lambda t: 0.25)
for k in range(140):
    o = int(random.uniform(0, 2.3) * SR)
    d = tone(lambda t, f=random.uniform(700, 1600): f + 900 * t, 0.03, 0.001, 0.01)
    for i, x in enumerate(d):
        if o + i < len(w): w[o + i] += x * 0.5
loop('water', w, 0.4, 0.55)
# rain: soft steady rain with drips
r = noise(4.4, 0.25, lambda t: 0.35)
for k in range(90):
    o = int(random.uniform(0, 4.3) * SR)
    d = noise(0.02, 0.8, lambda t: math.exp(-t * 200))
    for i, x in enumerate(d):
        if o + i < len(r): r[o + i] += x * 0.6
loop('rain', r, 0.6, 0.6)
# wind: slow whooshing gusts
loop('wind', noise(6.4, lambda t: 0.01 + 0.025 * (1 + math.sin(t * 1.3)) * (1 + 0.5 * math.sin(t * 0.37)),
                   lambda t: 0.6 + 0.4 * math.sin(t * 1.3)), 0.8, 0.6)
# crickets: chirping at night
cr = [0.0] * int(SR * 4.4)
for start in [0.1, 0.9, 1.7, 2.5, 3.3, 0.5, 2.1, 3.0]:
    for p in range(4):
        d = tone(lambda t: 4200, 0.03, 0.003, 0.012, ((1, 1), (1.5, 0.2)))
        o = int((start + p * 0.05) * SR)
        for i, x in enumerate(d):
            if o + i < len(cr): cr[o + i] += x * (0.6 if start in (0.5, 2.1, 3.0) else 1)
loop('crickets', cr, 0.3, 0.45)
# buzz: a bee
loop('buzz', tone(lambda t: 210 + 12 * math.sin(t * 9), 1.6, 0.01, 1e9, ((1, 1), (2, 0.6), (3, 0.4), (4, 0.2))), 0.3, 0.4)
print('ok')
