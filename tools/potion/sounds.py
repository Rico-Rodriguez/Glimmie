"""Synthesizes the Potion Lab's sound effects into App/Resources/Games/PotionLab/ (16-bit mono WAV).
Run from the repo root: python3 tools/potion/sounds.py   (numpy). No voices, just sounds.
boil, sizzle, fire and stir are seamless loops."""
import os
import wave

import numpy as np

SR = 22050
OUT = 'App/Resources/Games/PotionLab'
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


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


def loop(name, s, cross=0.35, gain=0.7):
    n = int(SR * cross)
    body = s[:len(s) - n].copy()
    tail = s[len(s) - n:]
    k = np.linspace(0, 1, n)
    body[:n] = body[:n] * k + tail * (1 - k)
    write(name, body, gain, fade=False)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def lowpass(x, a):
    """One-pole low-pass; a may be an array (0..1, higher is brighter)."""
    y = np.zeros_like(x)
    acc = 0.0
    a = np.broadcast_to(a, x.shape)
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def blip(f0, rise, dur, decay):
    """A bubble: a sine whose pitch sweeps up as it closes (Minnaert resonance)."""
    t = t_(dur)
    f = f0 * (1 + rise * t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t / decay) * np.minimum(1, t / 0.002)


def place(n, *parts):
    out = np.zeros(int(SR * n))
    for s, off in parts:
        o = int(off * SR)
        e = min(len(out), o + len(s))
        out[o:e] += s[:e - o]
    return out


def chime(freqs, dur=1.2, decay=0.5, gap=0.07):
    out = np.zeros(int(SR * (dur + gap * len(freqs))))
    for i, f in enumerate(freqs):
        t = t_(dur)
        s = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.01 * t) + 0.15 * np.sin(2 * np.pi * f * 3.98 * t))
        s *= np.exp(-t / decay) * np.minimum(1, t / 0.003)
        o = int(i * gap * SR)
        out[o:o + len(s)] += s
    return out


# glug: liquid leaving a bottle, a couple of hollow gulps
g = place(0.3, (blip(180, 1.4, 0.12, 0.05), 0), (blip(240, 1.2, 0.1, 0.04), 0.11),
          (lowpass(noise(0.25), 0.15) * np.exp(-t_(0.25) * 12) * 0.4, 0))
write('glug', g, 0.75)
# splash: a stream landing in the potion
sp = [(lowpass(noise(0.35), 0.35) * np.exp(-t_(0.35) * 10), 0), (blip(300, 2, 0.15, 0.06), 0.01)]
for k in range(4):
    sp.append((blip(rng.uniform(700, 1300), 1.2, 0.05, 0.02) * 0.5, 0.08 + k * 0.05))
write('splash', place(0.4, *sp), 0.7)
write('plop', place(0.12, (blip(520, 1.0, 0.08, 0.025), 0), (lowpass(noise(0.03), 0.6) * np.exp(-t_(0.03) * 150) * 0.4, 0)), 0.55)
write('drip', blip(1100, 0.8, 0.06, 0.018), 0.45)
write('pop', place(0.06, (blip(950, 1.5, 0.05, 0.012), 0), (lowpass(noise(0.02), 0.9) * np.exp(-t_(0.02) * 300), 0)), 0.5)
write('bloop', place(0.25, (blip(360, 1.8, 0.16, 0.05), 0), (blip(640, 1.2, 0.08, 0.025), 0.08)), 0.7)


def glassy(f, dur=0.5, decay=0.12):
    t = t_(dur)
    return (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t) + 0.3 * np.sin(2 * np.pi * f * 5.4 * t)) * np.exp(-t / decay) * np.minimum(1, t / 0.001)


write('tink', glassy(2600, 0.3, 0.06), 0.5)
write('clink', place(0.6, (glassy(1850, 0.5, 0.14), 0), (glassy(2300, 0.4, 0.1) * 0.5, 0.05)), 0.6)
# cork: a squeak in, then a soft pop
t = t_(0.12)
squeak = np.sin(2 * np.pi * np.cumsum(700 + 500 * t / 0.12) / SR) * np.exp(-t * 20) * 0.4
write('cork', place(0.3, (squeak, 0), (blip(420, 0.6, 0.08, 0.02) + lowpass(noise(0.08), 0.5) * np.exp(-t_(0.08) * 80), 0.1)), 0.7)
# fizz: a short hiss of tiny bubbles
fz = noise(0.6) * np.exp(-t_(0.6) * 4)
fz = fz - lowpass(fz, 0.5)
for k in range(10):
    fz = fz + place(0.6, (blip(rng.uniform(1500, 3000), 1, 0.03, 0.008) * 0.3, rng.uniform(0, 0.5)))
write('fizz', fz, 0.45)
# frost: crackly, icy tinkles
fr = place(0.8, *[(glassy(rng.uniform(3000, 4800), 0.2, 0.03) * 0.6, k * 0.06 + rng.uniform(0, 0.03)) for k in range(10)])
write('frost', fr, 0.5)
write('chime', chime([1046, 1318, 1568], 1.0, 0.35), 0.55)
write('magic', chime([784, 988, 1175, 1568, 1976, 2349], 1.4, 0.45, 0.06), 0.6)
# poof: a puff of air with sparkles
pf = lowpass(noise(0.5), np.linspace(0.6, 0.05, int(SR * 0.5))) * np.exp(-t_(0.5) * 6)
write('poof', place(0.8, (pf, 0), (chime([1568, 2093], 0.6, 0.2, 0.05) * 0.25, 0.08)), 0.6)
write('heart', chime([880, 1318], 0.8, 0.3, 0.12), 0.5)
# boing: a springy hop
t = t_(0.35)
write('boing', np.sin(2 * np.pi * np.cumsum(220 + 260 * np.exp(-t * 9) * (1 + 0.3 * np.sin(t * 60))) / SR) * np.exp(-t * 7), 0.55)
# hiccup: a tiny squeaky hic and a puff
t = t_(0.14)
hic = np.sin(2 * np.pi * np.cumsum(900 - 300 * t / 0.14) / SR) * np.exp(-t * 30)
write('hiccup', place(0.3, (hic, 0), (lowpass(noise(0.15), 0.3) * np.exp(-t_(0.15) * 20) * 0.5, 0.03)), 0.55)
# shakeOff: a quick brrr of drops flying off
so = place(0.6, *[(blip(rng.uniform(900, 1600), 0.8, 0.05, 0.015) * 0.6, rng.uniform(0, 0.45)) for _ in range(14)])
so += lowpass(noise(0.6), 0.25) * np.exp(-t_(0.6) * 5) * 0.4 * (0.6 + 0.4 * np.sin(t_(0.6) * 2 * np.pi * 16))
write('shakeOff', so, 0.55)
# yawn: a soft, slow falling hum (an instrument, not a voice)
t = t_(1.0)
write('yawn', np.sin(2 * np.pi * np.cumsum(520 - 220 * t) / SR) * np.sin(np.pi * t) ** 2 * 0.7, 0.4)
# shake: a jar of little things rattling
sh = place(0.35, *[(glassy(rng.uniform(2000, 3500), 0.05, 0.01) * rng.uniform(0.3, 1), rng.uniform(0, 0.3)) for _ in range(12)])
write('shake', sh, 0.5)
# knob: a click of a turning knob
write('knob', place(0.1, (glassy(1400, 0.05, 0.006), 0), (glassy(900, 0.05, 0.008) * 0.6, 0.03)), 0.6)
write('click', glassy(1200, 0.06, 0.008), 0.5)
write('tap', glassy(1600, 0.05, 0.006), 0.35)
# whoosh: the fire catching
wh = lowpass(noise(0.6), np.linspace(0.05, 0.5, int(SR * 0.6))) * np.sin(np.pi * t_(0.6) / 0.6) ** 1.5
write('whoosh', wh, 0.55)
# gurgle: liquid going down the drain
gu = place(1.2, *[(blip(rng.uniform(140, 260), 1.6, 0.12, 0.05), k * 0.09 + rng.uniform(0, 0.04)) for k in range(12)])
write('gurgle', gu, 0.6)
# fill: a bottle filling up, its glug rising in pitch
fi = place(0.5, *[(blip(300 + k * 60, 1.2, 0.08, 0.03), k * 0.08) for k in range(6)])
write('fill', fi, 0.6)

# Loops
# boil: a rolling boil, lots of bubbles of all sizes
dur = 4.0
bo = lowpass(noise(dur), 0.08) * 0.5
for _ in range(220):
    f = rng.uniform(140, 520)
    bo += place(dur, (blip(f, 1.6, 0.1, 0.04) * rng.uniform(0.3, 1), rng.uniform(0, dur - 0.1)))
loop('boil', bo, 0.4, 0.6)
# sizzle: steady fizz
dur = 3.0
sz = noise(dur)
sz = sz - lowpass(sz, 0.45)
for _ in range(160):
    sz += place(dur, (blip(rng.uniform(1600, 3600), 1, 0.03, 0.007) * 0.4, rng.uniform(0, dur - 0.05)))
loop('sizzle', sz * 0.6, 0.3, 0.5)
# fire: a soft roar with crackles
dur = 4.0
fl = lowpass(noise(dur), 0.06) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.7 * t_(dur)))
for _ in range(40):
    fl += place(dur, (lowpass(noise(0.02), 0.9) * np.exp(-t_(0.02) * 200) * rng.uniform(0.3, 1), rng.uniform(0, dur - 0.03)))
loop('fire', fl, 0.4, 0.55)
# stir: liquid sloshing around the glass
dur = 3.0
t = t_(dur)
st = lowpass(noise(dur), 0.12) * (0.55 + 0.45 * np.sin(2 * np.pi * 1.0 * t) ** 2)
for _ in range(30):
    st += place(dur, (blip(rng.uniform(250, 600), 1.2, 0.08, 0.03) * 0.5, rng.uniform(0, dur - 0.1)))
loop('stir', st, 0.35, 0.55)
print('ok')
