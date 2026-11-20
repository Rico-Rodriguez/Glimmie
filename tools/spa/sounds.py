"""Synthesizes the Bubble Spa's sound effects into App/Resources/Games/Spa/ (16-bit mono WAV).
Run from the repo root: python3 tools/spa/sounds.py   (needs numpy). No voices, just sounds.

Water is mostly the sound of air bubbles ringing as they form (Minnaert resonance: a bubble rings at a pitch
set by its size, rising as it nears the surface), so running water, drips, plops, splashes, gurgles and fizz
are all built from many tiny rising chirps over filtered noise, the way real water sounds are made.
running, drain, fizz, shower and scrub are seamless loops (the end is crossfaded into the start)."""
import os
import wave

import numpy as np

SR = 22050
OUT = 'App/Resources/Games/Spa'
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(11)


def write(name, s, gain=0.85, fade=True):
    s = np.asarray(s, dtype=np.float64)
    peak = max(1e-9, np.max(np.abs(s)))
    s = s / peak * gain
    if fade:
        f = int(SR * 0.006)
        ramp = np.linspace(0, 1, f)
        s[:f] *= ramp
        s[-f:] *= ramp[::-1]
    data = (np.clip(s, -1, 1) * 32767).astype('<i2').tobytes()
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def loop(name, s, cross=0.5, gain=0.7):
    n = int(SR * cross)
    s = np.asarray(s, dtype=np.float64)
    body = s[:len(s) - n].copy()
    tail = s[len(s) - n:]
    k = np.linspace(0, 1, n)
    body[:n] = body[:n] * k + tail * (1 - k)
    write(name, body, gain, fade=False)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def lowpass(x, a):
    """One-pole low-pass; a in 0..1 (bigger = brighter). a may be an array."""
    y = np.empty_like(x)
    acc = 0.0
    av = np.broadcast_to(a, x.shape)
    for i in range(len(x)):
        acc += av[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, a):
    return x - lowpass(x, a)


def bandpass(x, f, q=4.0):
    """A resonant two-pole band-pass at f Hz (f may be an array)."""
    y = np.zeros_like(x)
    fv = np.broadcast_to(f, x.shape)
    y1 = y2 = 0.0
    for i in range(len(x)):
        w = 2 * np.pi * fv[i] / SR
        r = max(0.0, 1 - w / (2 * q))
        b1 = 2 * r * np.cos(w)
        b2 = -r * r
        v = (1 - r) * x[i] + b1 * y1 + b2 * y2
        y2, y1 = y1, v
        y[i] = v
    return y


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def bubble(f0, dur=None, rise=0.6, amp=1.0, decay=None):
    """One ringing air bubble: a sine whose pitch rises as it decays."""
    d = decay if decay is not None else 0.004 + 9.0 / f0          # small bubbles ring shorter
    dur = dur if dur is not None else d * 6
    t = t_(dur)
    f = f0 * (1 + rise * t / max(d * 3, 1e-4))
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.exp(-t / d) * np.minimum(1, t / 0.0008)
    return np.sin(ph) * env * amp


def place(out, s, at):
    i = int(at * SR)
    if i >= len(out):
        return
    j = min(len(out), i + len(s))
    out[i:j] += s[:j - i]


def bubbles(dur, rate, fmin, fmax, amp=(0.2, 1.0), rise=(0.3, 1.2), wrap=False):
    """Many random bubbles over `dur` seconds."""
    out = np.zeros(int(SR * dur))
    n = int(dur * rate)
    for _ in range(n):
        f0 = float(np.exp(rng.uniform(np.log(fmin), np.log(fmax))))
        b = bubble(f0, rise=rng.uniform(*rise), amp=rng.uniform(*amp))
        at = rng.uniform(0, dur)
        if wrap:
            i = int(at * SR)
            for k, v in enumerate(b):
                out[(i + k) % len(out)] += v
        else:
            place(out, b, at)
    return out


def env(dur, attack, release):
    t = t_(dur)
    a = np.minimum(1, t / max(attack, 1e-4))
    r = np.minimum(1, (dur - t) / max(release, 1e-4))
    return a * np.clip(r, 0, 1)


# --- loops -----------------------------------------------------------------------------------------------

# running: the tap filling the tub - a rushing hiss plus a dense bed of bubbles
D = 3.0
hiss = bandpass(noise(D), 1400, 0.9) * 0.5 + lowpass(noise(D), 0.08) * 0.8
loop('running', hiss * 0.35 + bubbles(D, 320, 280, 2400, wrap=True) * 0.45 + bubbles(D, 60, 140, 400, wrap=True) * 0.4)

# drain: the plug hole gurgling - low bubbles in bursts and a sucking swirl
D = 3.0
burst = (0.5 + 0.5 * np.sin(2 * np.pi * 1.7 * t_(D))) ** 3
swirl = bandpass(noise(D), 300 + 120 * np.sin(2 * np.pi * 0.6 * t_(D)), 2.5) * 0.6
loop('drain', swirl * (0.4 + 0.6 * burst) + bubbles(D, 70, 90, 380, amp=(0.5, 1.0), rise=(0.8, 2.0), wrap=True) * burst * 1.2)

# fizz: a bath bomb - countless tiny high bubbles crackling and a soft hiss
D = 2.6
crackle = np.zeros(int(SR * D))
for _ in range(2600):
    i = int(rng.uniform(0, len(crackle) - 40))
    crackle[i:i + 30] += rng.uniform(-1, 1) * np.exp(-np.arange(30) / 5)
loop('fizz', highpass(crackle, 0.3) * 0.7 + bubbles(D, 900, 2500, 7000, amp=(0.1, 0.5), wrap=True) * 0.5
     + highpass(noise(D), 0.5) * 0.12, gain=0.6)

# shower: a spray hiss with drops pattering
D = 3.0
spray = bandpass(noise(D), 3200, 0.7) * 0.6 + highpass(noise(D), 0.2) * 0.25
pat = np.zeros(int(SR * D))
for _ in range(700):
    i = int(rng.uniform(0, len(pat) - 200))
    pat[i:i + 160] += bandpass(noise(160 / SR), rng.uniform(900, 3000), 3) * np.exp(-np.arange(160) / 25)
loop('shower', spray + pat * 0.8 + bubbles(D, 150, 800, 3000, amp=(0.1, 0.4), wrap=True), gain=0.6)

# scrub: a towel or sponge rubbing - band noise swelling with each stroke
D = 2.0
strokes = np.abs(np.sin(2 * np.pi * 3.0 * t_(D))) ** 1.5
rub = bandpass(noise(D), 900 + 500 * strokes, 1.2) * (0.3 + 0.7 * strokes)
loop('scrub', rub + lowpass(noise(D), 0.05) * strokes * 0.6, cross=0.3, gain=0.55)

# --- one-shots --------------------------------------------------------------------------------------------

# splash: something lands in the water
D = 0.9
s = bandpass(noise(D), 1100, 0.8) * np.exp(-t_(D) * 9) + lowpass(noise(D), 0.12) * np.exp(-t_(D) * 6) * 0.8
write('splash', s + bubbles(D, 120, 250, 2200) * np.exp(-t_(D) * 4) * 0.8)

# bigsplash: a cannonball - heavier, longer, with a deep plunge
D = 1.4
s = lowpass(noise(D), 0.2) * np.exp(-t_(D) * 4) + bandpass(noise(D), 700, 0.8) * np.exp(-t_(D) * 5)
plunge = np.zeros(int(SR * D))
place(plunge, bubble(130, 0.5, rise=1.8, amp=1.6, decay=0.09), 0.0)
write('bigsplash', s + plunge + bubbles(D, 160, 150, 1800) * np.exp(-t_(D) * 2.5))

# plop: a small thing dropping in (the classic water "bloop")
D = 0.35
p = np.zeros(int(SR * D))
place(p, bubble(420, 0.3, rise=1.4, amp=1.0, decay=0.045), 0.01)
place(p, lowpass(noise(0.03), 0.3) * np.exp(-t_(0.03) * 120) * 0.5, 0)
write('plop', p, 0.8)

# drip: one drop into the bath
d = np.zeros(int(SR * 0.25))
place(d, bubble(1300, 0.2, rise=0.9, amp=1, decay=0.025), 0.005)
write('drip', d, 0.55)

# pop: a soap bubble bursting - a tiny dry click and a whisper of spray
D = 0.12
c = np.zeros(int(SR * D))
c[:24] = rng.uniform(-1, 1, 24) * np.exp(-np.arange(24) / 4)
c += highpass(noise(D), 0.6) * np.exp(-t_(D) * 60) * 0.4
c += np.sin(2 * np.pi * 2600 * t_(D)) * np.exp(-t_(D) * 90) * 0.3
c[-60:] *= np.linspace(1, 0, 60)
write('pop', c, 0.7, fade=False)

# blow: the bubble wand - a soft breath and a wobble of film
D = 0.45
b = bandpass(noise(D), 600, 0.8) * env(D, 0.08, 0.3) * 0.7
b += np.sin(2 * np.pi * (260 + 60 * np.sin(2 * np.pi * 9 * t_(D))) * t_(D)) * env(D, 0.05, 0.25) * 0.15
write('blow', b, 0.45)

# squeak: a rubber duck - a buzzy reed tone sliding up and back down
for name, f0, dur in (('squeak', 1450, 0.32), ('squeak2', 1900, 0.22)):
    t = t_(dur)
    f = f0 * (1 + 0.22 * np.sin(np.pi * t / dur)) * (1 + 0.012 * np.sin(2 * np.pi * 38 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
    reed = bandpass(saw, 2400, 2.0) * 0.8 + np.sin(ph) * 0.5 + bandpass(noise(dur), 3500, 2) * 0.15
    write(name, reed * env(dur, 0.02, 0.06), 0.7)

# toot: the little boat's horn - two soft notes
D = 0.5
t = t_(D)
f = np.where(t < 0.22, 520, 660)
ph = 2 * np.pi * np.cumsum(f) / SR
tone = (np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)) * (np.minimum(1, (t % 0.25) / 0.02)) * np.exp(-(t % 0.25) * 4)
write('toot', lowpass(tone, 0.35) * env(D, 0.01, 0.06), 0.6)

# spout: the whale blowing a fountain - a whoosh up and a patter of falling water
D = 1.1
w = bandpass(noise(D), 900 + 1600 * np.minimum(1, t_(D) / 0.25), 0.9) * np.exp(-np.maximum(0, t_(D) - 0.2) * 7) * env(D, 0.03, 0.1)
write('spout', w + bubbles(D, 90, 900, 3000, amp=(0.1, 0.5)) * np.clip((t_(D) - 0.35) * 3, 0, 1) * np.exp(-t_(D) * 1.5))

# glug: bubble bath soap squirting out of its bottle
D = 0.6
g = np.zeros(int(SR * D))
for k, f0 in enumerate((210, 260, 230)):
    place(g, bubble(f0, 0.2, rise=1.3, amp=1, decay=0.05), 0.02 + k * 0.17)
write('glug', g + lowpass(noise(D), 0.06) * env(D, 0.02, 0.2) * 0.3, 0.75)

# squish: face mask cream / wet sponge squeezing
D = 0.32
q = lowpass(noise(D), np.linspace(0.05, 0.25, int(SR * D))) * env(D, 0.04, 0.12)
q += bubbles(D, 40, 300, 900, amp=(0.1, 0.4)) * 0.5
write('squish', q, 0.6)

# slosh: a hand swishing through the bath
D = 0.7
sl = lowpass(noise(D), 0.06) * np.sin(np.pi * t_(D) / D) ** 2 + bandpass(noise(D), 600, 1.2) * np.sin(np.pi * t_(D) / D) ** 3 * 0.5
write('slosh', sl + bubbles(D, 70, 200, 1400) * np.sin(np.pi * t_(D) / D) * 0.7, 0.7)

# turn: the tap handle - a little metal squeak and clunk
D = 0.3
t = t_(D)
m = np.sin(2 * np.pi * (950 + 200 * t) * t) * np.exp(-t * 12) * 0.5 + np.sin(2 * np.pi * 2310 * t) * np.exp(-t * 30) * 0.3
m += lowpass(noise(D), 0.2) * np.exp(-t * 60) * 0.6
write('turn', m, 0.55)

# plug: the stopper pulled out - a deep suction thoop
D = 0.5
pl = np.zeros(int(SR * D))
place(pl, bubble(180, 0.4, rise=2.2, amp=1, decay=0.06), 0.0)
place(pl, lowpass(noise(0.06), 0.15) * np.exp(-t_(0.06) * 60) * 0.8, 0)
write('plug', pl, 0.75)

# chime: a soft bell when she is all clean and dry
D = 1.2
t = t_(D)
ch = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * (2.5 + k)) * a
         for k, (f, a) in enumerate(((1318.5, 1), (1975.5, 0.6), (2637, 0.35), (3951, 0.15))))
place_ch = np.zeros(len(t))
place(place_ch, ch[:int(SR * 0.9)] * 0.6, 0.12)
write('chime', ch + place_ch, 0.5)

print('wrote', sorted(f for f in os.listdir(OUT) if f.endswith('.wav')))
