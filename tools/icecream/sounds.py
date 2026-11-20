"""Synthesizes the Ice Cream & Smoothie Shop's sound effects into App/Resources/Games/IceCream/ (16-bit mono WAV).
Run from the repo root: python3 tools/icecream/sounds.py   (needs numpy). No voices, just sounds.
scrape, soft, blend, pour, sauce and whip are seamless loops (the end is crossfaded into the start)."""
import os
import wave

import numpy as np

SR = 22050
OUT = 'App/Resources/Games/IceCream'
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(11)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def write(name, s, gain=0.8, fade=True):
    s = np.asarray(s, dtype=np.float64)
    peak = max(1e-9, np.max(np.abs(s)))
    s = s / peak * gain
    if fade:
        f = int(SR * 0.005)
        env = np.ones(len(s))
        env[:f] = np.linspace(0, 1, f)
        env[-f:] = np.linspace(1, 0, f)
        s = s * env
    data = (np.clip(s, -1, 1) * 32767).astype('<i2')
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def loop(name, s, cross=0.3, gain=0.7):
    n = int(SR * cross)
    body = s[:len(s) - n].copy()
    tail = s[len(s) - n:]
    k = np.linspace(0, 1, n)
    body[:n] = body[:n] * k + tail * (1 - k)
    write(name, body, gain, fade=False)


def lowpass(x, a):
    """One-pole low pass; a in 0..1 (bigger is brighter). a may be an array."""
    y = np.zeros_like(x)
    acc = 0.0
    aa = np.broadcast_to(a, x.shape)
    for i in range(len(x)):
        acc += aa[i] * (x[i] - acc)
        y[i] = acc
    return y


def band(x, lo, hi):
    return lowpass(x, hi) - lowpass(x, lo)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def tone(freq, dur, decay=0.1, attack=0.003, harm=((1, 1),)):
    t = t_(dur)
    f = np.broadcast_to(freq if callable(freq) is False else freq(t), t.shape)
    ph = np.cumsum(2 * np.pi * f / SR)
    x = sum(a * np.sin(ph * m) for m, a in harm)
    env = np.where(t < attack, t / attack, np.exp(-(t - attack) / decay))
    return x * env


def env_exp(dur, k):
    return np.exp(-t_(dur) * k)


def mix(*tracks):
    n = max(int(off * SR) + len(t) for t, off in tracks)
    out = np.zeros(n)
    for t, off in tracks:
        o = int(off * SR)
        out[o:o + len(t)] += t
    return out


def partials(base, ratios, dur, decay):
    t = t_(dur)
    x = np.zeros_like(t)
    for i, (r, a) in enumerate(ratios):
        x += a * np.sin(2 * np.pi * base * r * t) * np.exp(-t / (decay / (1 + i * 0.6)))
    return x


# scrape: the dipper dragging through hard ice cream, a grainy icy crackle
d = 1.6
s = band(noise(d), 0.25, 0.75) * 0.35
for _ in range(240):
    o = int(rng.uniform(0, d - 0.02) * SR)
    c = band(noise(0.012), 0.4, 0.95) * env_exp(0.012, 400) * rng.uniform(0.4, 1)
    s[o:o + len(c)] += c
s *= 0.75 + 0.25 * np.sin(t_(d) * 2 * np.pi * 3)
loop('scrape', s, 0.3, 0.5)

# plop: a heavy soft scoop landing
pl = mix((tone(lambda t: 190 - 120 * t / 0.18, 0.18, 0.05, harm=((1, 1), (2, 0.25))), 0),
         (lowpass(noise(0.12), 0.08) * env_exp(0.12, 40), 0),
         (band(noise(0.05), 0.2, 0.6) * env_exp(0.05, 90) * 0.4, 0.01))
write('plop', pl, 0.8)

# clink: steel on steel
write('clink', partials(2350, [(1, 1), (1.47, 0.6), (2.31, 0.4), (3.1, 0.2)], 0.45, 0.16), 0.55)

# lever: the soft-serve handle clunking down
write('lever', mix((tone(lambda t: 110, 0.12, 0.03, harm=((1, 1), (2, 0.4), (3, 0.2))), 0),
                   (band(noise(0.03), 0.3, 0.9) * env_exp(0.03, 160), 0),
                   (partials(1800, [(1, 1), (1.6, 0.5)], 0.08, 0.02) * 0.4, 0.005)), 0.7)

# soft: the machine humming and the soft ice cream squishing out
d = 2.0
t = t_(d)
hum = 0.25 * (np.sin(2 * np.pi * 100 * t) + 0.5 * np.sin(2 * np.pi * 200 * t) + 0.2 * np.sin(2 * np.pi * 300 * t))
squish = lowpass(noise(d), 0.05) * (0.7 + 0.3 * np.sin(2 * np.pi * 5 * t)) * 3
loop('soft', hum + squish, 0.4, 0.55)

# blend: a blender motor with chopping pulses (the app speeds it up as the fruit gets smoother)
d = 2.0
t = t_(d)
saw = sum(np.sin(2 * np.pi * 175 * k * t + k) / k for k in range(1, 9))
grind = band(noise(d), 0.1, 0.5) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 14 * t)))
loop('blend', saw * 0.45 + grind * 0.9, 0.4, 0.6)

# chop: a blade cutting through fruit
write('chop', mix((band(noise(0.07), 0.15, 0.6) * env_exp(0.07, 60), 0),
                  (tone(lambda t: 240, 0.06, 0.015), 0)), 0.6)

# plunk: fruit dropping into the jar, a hollow glassy tok
write('plunk', mix((tone(lambda t: 420 - 200 * t / 0.12, 0.12, 0.03, harm=((1, 1), (2.4, 0.3))), 0),
                   (partials(1900, [(1, 0.5), (1.5, 0.3)], 0.15, 0.04), 0.002)), 0.6)

# pour: a stream of smoothie gurgling into a glass
d = 2.4
s = lowpass(noise(d), 0.12) * 0.8
for _ in range(110):
    o = int(rng.uniform(0, d - 0.05) * SR)
    f0 = rng.uniform(380, 1100)
    b = tone(lambda t, f0=f0: f0 * (1 + 3 * t), 0.04, 0.012) * rng.uniform(0.3, 0.8)
    s[o:o + len(b)] += b
loop('pour', s, 0.4, 0.55)

# splash
sp = lowpass(noise(0.35), 0.3) * env_exp(0.35, 11)
for k in range(5):
    sp = mix((sp, 0), (tone(lambda t, f=rng.uniform(600, 1300): f * (1 + 2 * t), 0.05, 0.015) * 0.5, 0.03 + k * 0.05))
write('splash', sp, 0.6)

# shake: sprinkles rattling in the shaker
sh = np.zeros(int(SR * 0.3))
for _ in range(40):
    o = int(rng.uniform(0, 0.27) * SR)
    c = band(noise(0.01), 0.5, 0.98) * env_exp(0.01, 600) * rng.uniform(0.3, 1)
    sh[o:o + len(c)] += c
write('shake', sh, 0.5)

# sauce: a squeeze bottle, a soft wet squish
d = 1.5
t = t_(d)
sq = band(noise(d), 0.01, 0.06) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t) ** 2) * 4
loop('sauce', sq, 0.3, 0.5)

# whip: the whipped-cream can hissing
d = 1.5
t = t_(d)
hiss = (noise(d) - lowpass(noise(d), 0.3)) * (0.8 + 0.2 * np.sin(2 * np.pi * 11 * t))
loop('whip', hiss, 0.3, 0.35)

# boing: a cherry bouncing
t = t_(0.4)
write('boing', np.sin(2 * np.pi * np.cumsum(320 + 120 * np.sin(2 * np.pi * 14 * t) * np.exp(-t * 6)) / SR) * np.exp(-t * 9), 0.55)

# crunch: a wafer pushed in
cr = np.zeros(int(SR * 0.22))
for _ in range(18):
    o = int(rng.uniform(0, 0.18) * SR)
    c = band(noise(0.02), 0.2, 0.8) * env_exp(0.02, 200) * rng.uniform(0.4, 1)
    cr[o:o + len(c)] += c
write('crunch', cr, 0.6)

# bell: the counter bell
write('bell', partials(1480, [(1, 1), (2.76, 0.45), (5.4, 0.25), (8.9, 0.1)], 1.6, 0.6), 0.6)

# nom: a happy munch
write('nom', mix((lowpass(noise(0.1), 0.2) * env_exp(0.1, 30), 0), (tone(lambda t: 260 - 80 * t, 0.1, 0.03), 0),
                 (lowpass(noise(0.08), 0.2) * env_exp(0.08, 40) * 0.7, 0.14)), 0.65)

# yay: a bright little chime run
write('yay', mix(*[(tone(lambda t, f=f: f, 0.5, 0.18, harm=((1, 1), (2, 0.25), (3, 0.1))), k * 0.08)
                   for k, f in enumerate([784, 988, 1175, 1568, 1976])]), 0.5)

# slurp: through the straw
t = t_(0.6)
sl = band(noise(0.6), 0.04 + 0.2 * t, 0.5) * np.sin(np.pi * t / 0.6)
for k in range(8):
    sl = mix((sl, 0), (tone(lambda t, f=rng.uniform(500, 900): f * (1 + 2 * t), 0.03, 0.01) * 0.6, 0.05 + k * 0.06))
write('slurp', sl, 0.55)

# drip: a single drop
write('drip', tone(lambda t: 700 + 2600 * t, 0.07, 0.02), 0.5)

# tub: a cone or jar set down
write('tub', mix((tone(lambda t: 160, 0.1, 0.03, harm=((1, 1), (2.1, 0.3))), 0), (band(noise(0.03), 0.2, 0.6) * env_exp(0.03, 120), 0)), 0.6)

# glass: a glass set down
write('glass', partials(3100, [(1, 1), (1.52, 0.5), (2.2, 0.3)], 0.5, 0.18), 0.45)

# door: the shop door chime, ding-dong
write('door', mix((partials(1318, [(1, 1), (2.0, 0.3), (3.0, 0.1)], 0.9, 0.4), 0),
                  (partials(1047, [(1, 1), (2.0, 0.3), (3.0, 0.1)], 1.0, 0.45), 0.32)), 0.55)
print('ok')
