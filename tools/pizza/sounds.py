"""Synthesizes the pizza kitchen's sound effects into App/Resources/Games/Pizza/ (16-bit mono WAV).
Run from the repo root: python3 tools/pizza/sounds.py   (needs numpy). No voices, just sounds.
spread, sprinkle, fire, sizzle and roll are seamless loops (the end is crossfaded into the start)."""
import os, wave
import numpy as np

SR = 22050
OUT = 'App/Resources/Games/Pizza'
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(11)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def write(name, x, gain=0.8, fade=True):
    x = np.asarray(x, dtype=np.float64)
    x = x / max(1e-9, np.max(np.abs(x))) * gain
    if fade:
        f = int(SR * 0.004)
        x[:f] *= np.linspace(0, 1, f)
        x[-f:] *= np.linspace(1, 0, f)
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())


def loop(name, x, cross=0.3, gain=0.7):
    n = int(SR * cross)
    body = x[:len(x) - n].copy()
    tail = x[len(x) - n:]
    k = np.linspace(0, 1, n)
    body[:n] = body[:n] * k + tail * (1 - k)
    write(name, body, gain, fade=False)


def lowpass(x, a):
    """One-pole low-pass; a in (0, 1], smaller is darker. a may be an array."""
    y = np.empty_like(x)
    acc = 0.0
    a = np.broadcast_to(a, x.shape)
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, a):
    return x - lowpass(x, a)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def env(t, a, d):
    return np.where(t < a, t / a, np.exp(-(t - a) / d))


def sweep(f0, f1, dur, curve=1.0):
    t = t_(dur)
    f = f0 + (f1 - f0) * (t / dur) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def place(total, parts):
    out = np.zeros(int(SR * total))
    for x, off in parts:
        o = int(SR * off)
        n = min(len(x), len(out) - o)
        if n > 0:
            out[o:o + n] += x[:n]
    return out


# knead: a soft, floury squish into the dough
t = t_(0.22)
write('knead', sweep(110, 70, 0.22) * env(t, 0.01, 0.05) * 0.9 + lowpass(noise(0.22), 0.12) * env(t, 0.02, 0.06) * 1.4, 0.7)
# slap: dough landing flat on the board
t = t_(0.3)
write('slap', highpass(lowpass(noise(0.3), 0.5), 0.05) * env(t, 0.002, 0.035) + sweep(140, 60, 0.3) * env(t, 0.003, 0.06) * 0.8, 0.85)
# toss: a whoosh up into the air
t = t_(0.55)
write('toss', lowpass(noise(0.55), 0.04 + 0.25 * np.sin(np.pi * t / 0.55) ** 2) * np.sin(np.pi * t / 0.55) ** 1.5, 0.7)
# stretch: a soft rubbery creak
t = t_(0.3)
cr = sweep(150, 230, 0.3) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 38 * t)))
write('stretch', lowpass(cr, 0.2) * np.sin(np.pi * t / 0.3) ** 2 + lowpass(noise(0.3), 0.08) * 0.3 * np.sin(np.pi * t / 0.3), 0.45)
# glop: a thick blob of sauce
t = t_(0.32)
g = sweep(320, 110, 0.32, 0.6) * env(t, 0.004, 0.07)
g += place(0.32, [(sweep(700, 420, 0.06) * env(t_(0.06), 0.002, 0.02) * 0.5, 0.09), (sweep(560, 380, 0.05) * env(t_(0.05), 0.002, 0.015) * 0.4, 0.17)])
write('glop', lowpass(g, 0.5) + lowpass(noise(0.32), 0.15) * env(t, 0.005, 0.05) * 0.6, 0.75)
# spread (loop): the back of the ladle swishing through wet sauce
t = t_(2.3)
sw = lowpass(noise(2.3), 0.06 + 0.05 * np.sin(2 * np.pi * 1.7 * t) ** 2) * (0.6 + 0.4 * np.sin(2 * np.pi * 1.7 * t) ** 2)
squ = place(2.3, [(sweep(500 + 200 * rng.random(), 250, 0.05) * env(t_(0.05), 0.002, 0.015) * 0.25, rng.random() * 2.2) for _ in range(14)])
loop('spread', sw + squ, gain=0.6)
# sprinkle (loop): grated cheese pattering down
parts = []
for _ in range(110):
    d = 0.012 + 0.01 * rng.random()
    parts.append((highpass(noise(d), 0.3) * env(t_(d), 0.001, 0.004) * (0.3 + 0.7 * rng.random()), rng.random() * 2.1))
loop('sprinkle', lowpass(place(2.2, parts), 0.6), gain=0.5)
# plop: a topping landing
t = t_(0.16)
write('plop', sweep(420, 170, 0.16, 0.5) * env(t, 0.003, 0.035) + lowpass(noise(0.16), 0.3) * env(t, 0.001, 0.01) * 0.5, 0.75)
# oven: the peel sliding in and the fire breathing
t = t_(0.9)
o = lowpass(noise(0.9), 0.03 + 0.08 * np.sin(np.pi * t / 0.9)) * np.sin(np.pi * t / 0.9) ** 1.2
o += highpass(lowpass(noise(0.9), 0.4), 0.1) * env(t, 0.01, 0.12) * 0.35
write('oven', o, 0.75)
# fire (loop): a low roar with crackles
t = t_(3.3)
roar = lowpass(noise(3.3), 0.015) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.7 * t))
cracks = []
for _ in range(60):
    d = 0.004 + 0.012 * rng.random()
    cracks.append((highpass(noise(d), 0.25) * env(t_(d), 0.0005, d / 3) * (0.3 + 1.2 * rng.random() ** 3), rng.random() * 3.2))
loop('fire', roar * 3 + place(3.3, cracks) * 0.8, gain=0.65)
# sizzle (loop): cheese and oil hissing
t = t_(2.3)
hiss = highpass(noise(2.3), 0.5) * (0.5 + 0.5 * lowpass(np.abs(noise(2.3)), 0.003) * 3)
pops = place(2.3, [(highpass(noise(0.006), 0.3) * env(t_(0.006), 0.0005, 0.002), rng.random() * 2.25) for _ in range(90)])
loop('sizzle', lowpass(hiss, 0.7) * 0.5 + pops * 0.6, gain=0.45)
# bubble: a tiny pop in the cheese
t = t_(0.07)
write('bubble', sweep(900, 520, 0.07) * env(t, 0.001, 0.015), 0.4)
# ding: the oven timer
t = t_(1.4)
d = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, a, k in [(1568, 1, 3), (3136, 0.35, 5), (4704, 0.15, 8), (2093, 0.3, 4)])
write('ding', d * env(t, 0.002, 10), 0.7)
# crunch: the wheel cutting through the crust
parts = []
for i in range(9):
    dd = 0.015 + 0.02 * rng.random()
    parts.append((lowpass(highpass(noise(dd), 0.15), 0.5) * env(t_(dd), 0.001, dd / 3), i * 0.025 + 0.01 * rng.random()))
write('crunch', place(0.3, parts), 0.7)
# roll (loop): the wheel rolling through cheese and crust
parts = []
for _ in range(70):
    dd = 0.01 + 0.015 * rng.random()
    parts.append((lowpass(highpass(noise(dd), 0.2), 0.45) * env(t_(dd), 0.001, dd / 3) * (0.4 + 0.6 * rng.random()), rng.random() * 1.15))
loop('roll', place(1.2, parts) + lowpass(noise(1.2), 0.05) * 0.4, cross=0.15, gain=0.55)
# stretchy: cheese pulling long and thin
t = t_(0.6)
st = sweep(240, 430, 0.6, 0.7) * (1 + 0.3 * np.sin(2 * np.pi * 11 * t))
write('stretchy', lowpass(st, 0.15) * np.sin(np.pi * t / 0.6) ** 1.5 + lowpass(noise(0.6), 0.05) * 0.4 * np.sin(np.pi * t / 0.6), 0.5)
# snap: a cheese string letting go
t = t_(0.09)
write('snap', sweep(620, 300, 0.09) * env(t, 0.001, 0.02) + highpass(noise(0.09), 0.3) * env(t, 0.0005, 0.004) * 0.4, 0.45)
# nom: munch munch munch
parts = []
for i in range(3):
    dd = 0.13
    tt = t_(dd)
    parts.append((lowpass(noise(dd), 0.2) * np.sin(np.pi * tt / dd) ** 2 + sweep(180, 120, dd) * np.sin(np.pi * tt / dd) ** 2 * 0.4, i * 0.19))
write('nom', place(0.62, parts), 0.7)
# yay: a happy little chime
t = t_(0.9)
notes = [(523, 0), (659, 0.1), (784, 0.2), (1047, 0.32)]
y = place(0.9, [(np.sin(2 * np.pi * f * t_(0.5)) * env(t_(0.5), 0.004, 0.15) + 0.3 * np.sin(4 * np.pi * f * t_(0.5)) * env(t_(0.5), 0.004, 0.08), o) for f, o in notes])
write('yay', y, 0.7)
# whoosh: something swished away
t = t_(0.35)
write('whoosh', lowpass(noise(0.35), 0.05 + 0.3 * (t / 0.35)) * np.sin(np.pi * t / 0.35) ** 2, 0.6)
print('pizza sounds ->', OUT)
