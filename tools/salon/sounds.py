"""Synthesize the Salon sound effects into App/Resources/Games/Salon (16-bit mono WAV).
No voices: every sound is a tone or noise. Run from the repo root: python3 tools/salon/sounds.py"""
import math, os, random, struct, wave

SR = 44100
OUT = 'App/Resources/Games/Salon'
os.makedirs(OUT, exist_ok=True)
random.seed(23)


def env(t, a, d):
    return t / a if t < a else math.exp(-(t - a) / d)


def write(name, s, gain=0.8):
    peak = max(1e-9, max(abs(v) for v in s))
    fade = int(SR * 0.006)
    out = []
    for i, v in enumerate(s):
        k = min(1, i / fade, (len(s) - 1 - i) / fade)
        out.append(int(max(-1, min(1, v / peak * gain * k)) * 32767))
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(struct.pack('<%dh' % len(out), *out))


def tone(fn, dur, a=0.005, d=0.1, harm=((1, 1),)):
    ph = [0.0] * len(harm); out = []
    for i in range(int(SR * dur)):
        t = i / SR; f = fn(t); v = 0
        for k, (m, amp) in enumerate(harm):
            ph[k] += 2 * math.pi * f * m / SR; v += amp * math.sin(ph[k])
        out.append(v * env(t, a, d))
    return out


def noise(dur, cut_fn, amp_fn):
    out, lp = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        lp += cut_fn(t) * (random.uniform(-1, 1) - lp)
        out.append(lp * amp_fn(t))
    return out


def mix(*tracks):
    n = max(int(off * SR) + len(t) for t, off in tracks); out = [0.0] * n
    for t, off in tracks:
        o = int(off * SR)
        for i, v in enumerate(t): out[o + i] += v
    return out


# snip: two crisp metal clicks
clk = lambda: mix((noise(0.03, lambda t: 0.95, lambda t: env(t, 0.0008, 0.008)), 0), (tone(lambda t: 4200, 0.05, 0.001, 0.012), 0))
write('snip', mix((clk(), 0), (clk(), 0.045)), 0.6)
# water: a short shower rush (played back to back while the shower runs)
write('water', noise(0.5, lambda t: 0.55 + 0.1 * math.sin(t * 40), lambda t: 0.8 + 0.2 * math.sin(t * 23)), 0.32)
# squish: soapy squelch
write('squish', mix((noise(0.18, lambda t: 0.12 + 0.3 * t, lambda t: math.sin(math.pi * t / 0.18)), 0),
                    (tone(lambda t: 320 + 500 * t, 0.15, 0.01, 0.06), 0.02)), 0.5)
# dryer: whirring fan and air
write('dryer', mix((noise(0.55, lambda t: 0.4, lambda t: 0.7), 0),
                   (tone(lambda t: 180, 0.55, 0.02, 9, ((1, 1), (2, 0.4), (3, 0.2))), 0)), 0.3)
# sizzle: hot iron hiss
write('sizzle', noise(0.45, lambda t: 0.9, lambda t: env(t, 0.03, 0.2) * (0.6 + 0.4 * math.sin(t * 300))), 0.25)
# comb: soft brushing scratch
write('comb', noise(0.2, lambda t: 0.3 + 0.3 * math.sin(t * 120), lambda t: math.sin(math.pi * t / 0.2) * (0.5 + 0.5 * math.sin(t * 380))), 0.35)
# spray: glitter psst
write('spray', noise(0.3, lambda t: 0.85, lambda t: env(t, 0.02, 0.1)), 0.3)
# magic: rising shimmer
write('magic', mix(*[(tone(lambda t, f=f: f, 0.35, 0.003, 0.12, ((1, 1), (2.76, 0.2))), i * 0.06)
                     for i, f in enumerate([1047, 1319, 1568, 2093, 2637, 3136])]), 0.45)
# clip: plastic snap
write('clip', mix((tone(lambda t: 1800 - 1200 * t, 0.06, 0.001, 0.015, ((1, 1), (2.4, 0.4))), 0),
                  (noise(0.02, lambda t: 0.9, lambda t: env(t, 0.0008, 0.006)), 0)), 0.55)
# shutter: camera click-clack
write('shutter', mix((noise(0.05, lambda t: 0.8, lambda t: env(t, 0.001, 0.015)), 0),
                     (noise(0.07, lambda t: 0.6, lambda t: env(t, 0.001, 0.025)), 0.09),
                     (tone(lambda t: 2637, 0.35, 0.002, 0.1, ((1, 1), (2.76, 0.2))), 0.12)), 0.6)
# rub: towel fluff
write('rub', noise(0.3, lambda t: 0.08, lambda t: math.sin(math.pi * t / 0.3)), 0.45)
# drip: water drop plink
write('drip', tone(lambda t: 900 + 1400 * min(1, t / 0.04), 0.12, 0.001, 0.035), 0.4)
# giggle: bouncing trill (no voice)
write('giggle', mix(*[(tone(lambda t, f=f: f * (1 - 0.6 * t), 0.09, 0.004, 0.03, ((1, 1), (2, 0.3))), i * 0.075)
                       for i, f in enumerate([1250, 1400, 1250, 1500, 1320, 1600])]), 0.45)
# bloop: a bubble pops
write('bloop', tone(lambda t: 500 + 1500 * min(1, t / 0.03), 0.07, 0.001, 0.02), 0.35)
# chime: new client / photo bell
write('chime', mix((tone(lambda t: 1319, 0.6, 0.002, 0.25, ((1, 1), (2.76, 0.25))), 0),
                   (tone(lambda t: 1760, 0.7, 0.002, 0.3, ((1, 1), (2.76, 0.25))), 0.12)), 0.55)
