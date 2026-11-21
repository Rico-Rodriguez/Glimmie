"""Synthesize the shared coin sounds into App/Resources/Sounds (16-bit mono WAV). No voices.
Run from the repo root: python3 tools/coins/sounds.py

  coin.wav   one coin landing in the purse: a bright little two-note metal chime
  till.wav   the shop till: a soft drawer slide and a "ka-ching" bell (paying, buying)
"""
import math, random, struct, wave

SR = 44100
OUT = 'App/Resources/Sounds'
random.seed(7)


def write(name, s, gain=0.75):
    peak = max(1e-9, max(abs(v) for v in s))
    fade = int(SR * 0.004)
    out = []
    for i, v in enumerate(s):
        k = min(1, i / fade, (len(s) - 1 - i) / fade)
        out.append(int(max(-1, min(1, v / peak * gain * k)) * 32767))
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(struct.pack('<%dh' % len(out), *out))


def bell(f, t, decay):
    # metal: inharmonic partials that die away at different speeds
    parts = ((1, 1.0, 1.0), (2.76, 0.5, 0.6), (5.4, 0.25, 0.35), (8.9, 0.12, 0.2))
    v = 0
    for m, a, d in parts:
        v += a * math.sin(2 * math.pi * f * m * t) * math.exp(-t / (decay * d))
    return v * min(1, t / 0.002)


def coin():
    n = int(SR * 0.42)
    out = [0.0] * n
    for start, f in ((0.0, 1975), (0.07, 2637)):
        s0 = int(start * SR)
        for i in range(s0, n):
            out[i] += bell(f, (i - s0) / SR, 0.16)
    return out


def till():
    n = int(SR * 0.9)
    out = [0.0] * n
    lp = 0.0
    for i in range(int(SR * 0.16)):          # the drawer sliding out
        t = i / SR
        lp += (random.uniform(-1, 1) - lp) * 0.08
        out[i] += lp * 0.5 * math.sin(math.pi * t / 0.16)
    for start, f in ((0.13, 2093), (0.2, 3136)):
        s0 = int(start * SR)
        for i in range(s0, n):
            out[i] += bell(f, (i - s0) / SR, 0.28) * 0.8
    return out


if __name__ == '__main__':
    write('coin', coin())
    write('till', till())
