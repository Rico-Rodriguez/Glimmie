"""Synthesize the app's short sound effects into App/Resources/Sounds (16-bit mono WAV).
Run: python3 tools/make_sounds.py   (stdlib only)"""
import math, os, random, struct, wave

SR = 44100
OUT = 'App/Resources/Sounds'
os.makedirs(OUT, exist_ok=True)
random.seed(7)

def env(t, a, d):
    """attack/decay envelope"""
    if t < a: return t / a
    return math.exp(-(t - a) / d)

def write(name, samples, gain=0.8):
    peak = max(1e-9, max(abs(s) for s in samples))
    fade = int(SR * 0.006)
    out = []
    for i, s in enumerate(samples):
        f = min(1, i / fade, (len(samples) - 1 - i) / fade) if fade else 1
        out.append(int(max(-1, min(1, s / peak * gain * f)) * 32767))
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(struct.pack('<%dh' % len(out), *out))

def tone(freq_fn, dur, a=0.005, d=0.1, harm=((1, 1),)):
    ph = [0.0] * len(harm); out = []
    for i in range(int(SR * dur)):
        t = i / SR; f = freq_fn(t); s = 0
        for k, (mult, amp) in enumerate(harm):
            ph[k] += 2 * math.pi * f * mult / SR; s += amp * math.sin(ph[k])
        out.append(s * env(t, a, d))
    return out

def mix(*tracks):
    n = max(len(t) for t, _ in tracks); out = [0.0] * n
    for t, off in tracks:
        o = int(off * SR)
        for i, s in enumerate(t):
            if o + i < n: out[o + i] += s
            else: out.append(s)
    return out

def pad(t, total):
    return t + [0.0] * max(0, int(total * SR) - len(t))

# pop: quick upward bloop
write('pop', tone(lambda t: 420 + 900 * min(1, t / 0.05), 0.14, 0.002, 0.04, ((1, 1), (2, 0.25))))
# tap: tiny soft tick
write('tap', tone(lambda t: 1300 - 2000 * t, 0.06, 0.001, 0.015, ((1, 1), (3, 0.2))), 0.5)
# ding: bell
write('ding', tone(lambda t: 1568, 0.9, 0.002, 0.28, ((1, 1), (2.76, 0.35), (5.4, 0.12))), 0.7)
# sparkle: rising glitter of short bell blips
notes = [2093, 2637, 3136, 3520, 4186, 3136, 4699]
write('sparkle', mix(*[(tone(lambda t, f=f: f, 0.25, 0.002, 0.06, ((1, 1), (2.76, 0.2))), i * 0.045) for i, f in enumerate(notes)]), 0.55)
# boing: springy wobble down
write('boing', tone(lambda t: 260 + 140 * math.sin(t * 2 * math.pi * 14) * math.exp(-t * 6) + 120 * math.exp(-t * 8), 0.4, 0.004, 0.14, ((1, 1), (2, 0.3))), 0.6)
# whoosh: filtered noise swell
w = []; lp = 0
for i in range(int(SR * 0.45)):
    t = i / SR; cutoff = 0.04 + 0.25 * math.sin(math.pi * t / 0.45)
    lp += cutoff * (random.uniform(-1, 1) - lp); w.append(lp * math.sin(math.pi * t / 0.45) ** 2)
write('whoosh', w, 0.5)
# crack: noisy snap + knock
c = []; lp = 0
for i in range(int(SR * 0.22)):
    t = i / SR; lp += 0.5 * (random.uniform(-1, 1) - lp)
    c.append(lp * math.exp(-t * 40) + 0.6 * math.sin(2 * math.pi * 180 * t) * math.exp(-t * 30))
write('crack', c, 0.75)
# hatch: magical upward arpeggio + shimmer
arp = [523, 659, 784, 1047, 1319, 1568, 2093]
write('hatch', mix(*[(tone(lambda t, f=f: f, 0.5, 0.004, 0.18, ((1, 1), (2, 0.3), (3, 0.1))), i * 0.06) for i, f in enumerate(arp)]), 0.7)
# fanfare: ta-da chord
fan = [(523, 0), (659, 0.0), (784, 0.0), (659, 0.16), (784, 0.16), (1047, 0.16), (784, 0.32), (1047, 0.32), (1319, 0.32)]
tracks = [(tone(lambda t, f=f: f * (1 + 0.004 * math.sin(t * 30)), 0.9 if off > 0.3 else 0.22, 0.01, 0.35 if off > 0.3 else 0.08,
                ((1, 1), (2, 0.5), (3, 0.25), (4, 0.12))), off) for f, off in fan]
write('fanfare', pad(mix(*tracks), 1.3), 0.7)
print('sounds:', sorted(os.listdir(OUT)))
