"""Synthesize the Pet Vet sound effects into App/Resources/Games/PetVet (16-bit mono WAV).
No voices: every sound is a tone or noise. Run from the repo root: python3 tools/petvet/make_sounds.py"""
import math, os, random, struct, wave

SR = 44100
OUT = 'App/Resources/Games/PetVet'
os.makedirs(OUT, exist_ok=True)
random.seed(11)


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


# scrub: soft bristly swish
write('scrub', noise(0.22, lambda t: 0.25 + 0.2 * math.sin(t * 90), lambda t: math.sin(math.pi * t / 0.22) * (0.6 + 0.4 * math.sin(t * 160))), 0.45)
# splash: water spray
write('splash', mix((noise(0.6, lambda t: 0.6, lambda t: env(t, 0.03, 0.18)), 0),
                    *[(tone(lambda t, f=f: f + 1500 * t, 0.08, 0.002, 0.03), o) for f, o in [(900, 0.05), (1300, 0.12), (1100, 0.2), (1500, 0.28)]]), 0.5)
# pluck: springy plink when a thorn comes out
write('pluck', tone(lambda t: 700 + 900 * math.exp(-t * 30), 0.3, 0.002, 0.08, ((1, 1), (2, 0.35), (3, 0.15))), 0.7)
# squeak: rubber-toy squeak
write('squeak', tone(lambda t: 1500 + 700 * math.sin(math.pi * min(1, t / 0.16)), 0.18, 0.01, 0.12, ((1, 1), (2, 0.5), (3, 0.2))), 0.5)
# heartbeat: two soft thumps
thump = tone(lambda t: 70 - 20 * t, 0.16, 0.004, 0.05, ((1, 1), (2, 0.3)))
write('heartbeat', mix((thump, 0), (thump, 0.2)), 0.9)
# sneeze: breathy rise then a burst of air (no voice)
write('sneeze', mix((noise(0.35, lambda t: 0.05 + 0.2 * t, lambda t: (t / 0.35) ** 2 * 0.5), 0),
                    (noise(0.3, lambda t: 0.7, lambda t: env(t, 0.005, 0.07)), 0.35)), 0.6)
# nom: two little bloops (crunch-munch)
bl = tone(lambda t: 260 + 200 * math.exp(-t * 25), 0.1, 0.003, 0.04, ((1, 1), (2, 0.3)))
write('nom', mix((bl, 0), (noise(0.06, lambda t: 0.5, lambda t: env(t, 0.002, 0.02)), 0.02), (bl, 0.17), (noise(0.06, lambda t: 0.5, lambda t: env(t, 0.002, 0.02)), 0.19)), 0.7)
# giggle: quick bouncing high trill
write('giggle', mix(*[(tone(lambda t, f=f: f * (1 - 0.6 * t), 0.09, 0.004, 0.03, ((1, 1), (2, 0.3))), i * 0.075)
                       for i, f in enumerate([1180, 1320, 1180, 1400, 1250, 1500])]), 0.5)
# spray: pssst
write('spray', noise(0.35, lambda t: 0.85, lambda t: env(t, 0.02, 0.12)), 0.35)
# sticker: soft pat + sparkle
write('sticker', mix((tone(lambda t: 520 - 300 * t, 0.1, 0.002, 0.03), 0), (tone(lambda t: 2637, 0.25, 0.002, 0.07, ((1, 1), (2.76, 0.2))), 0.05)), 0.6)
# zip: wrapping a bandage round
write('zip', tone(lambda t: 300 + 1600 * (t / 0.3), 0.3, 0.01, 0.2, ((1, 1), (3, 0.3), (5, 0.1))), 0.35)
# brr: shivery wobble
write('brr', tone(lambda t: 220 + 40 * math.sin(t * 2 * math.pi * 26), 0.4, 0.01, 0.2, ((1, 1), (2, 0.5), (3, 0.3))), 0.4)
# beep: thermometer done
write('beep', mix((tone(lambda t: 2200, 0.09, 0.002, 0.05), 0), (tone(lambda t: 2200, 0.09, 0.002, 0.05), 0.13)), 0.45)
# healed: bright glockenspiel run up
write('healed', mix(*[(tone(lambda t, f=f: f, 0.6, 0.002, 0.22, ((1, 1), (2.76, 0.25), (5.4, 0.08))), i * 0.07)
                       for i, f in enumerate([1047, 1319, 1568, 2093, 2637])]), 0.6)
# hop: little jump
write('hop', tone(lambda t: 300 + 500 * math.sin(math.pi * min(1, t / 0.16)), 0.2, 0.004, 0.08, ((1, 1), (2, 0.2))), 0.55)
# ouch: short descending wobble (a toy, not a voice)
write('ouch', tone(lambda t: 900 - 500 * t / 0.25 + 60 * math.sin(t * 2 * math.pi * 18), 0.25, 0.004, 0.12, ((1, 1), (2, 0.4))), 0.5)
# swish: towel / comb rush
write('swish', noise(0.2, lambda t: 0.1 + 0.6 * t / 0.2, lambda t: math.sin(math.pi * t / 0.2) ** 2), 0.45)
# bugjump: boing as a bug hops away
write('bugjump', tone(lambda t: 500 + 1200 * t / 0.22 + 150 * math.sin(t * 2 * math.pi * 30) * math.exp(-t * 8), 0.22, 0.003, 0.1), 0.45)
print('sounds:', sorted(f for f in os.listdir(OUT) if f.endswith('.wav')))
