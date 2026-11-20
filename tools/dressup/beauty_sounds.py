"""Synthesize the nail and makeup studio sounds into App/Resources/Games/DressUp (16-bit mono WAV).
No voices: every sound is a tone or noise. Run from the repo root: python3 tools/dressup/beauty_sounds.py"""
import math, os, random, struct, wave

SR = 44100
OUT = 'App/Resources/Games/DressUp'
os.makedirs(OUT, exist_ok=True)
random.seed(31)


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


bell = lambda t, d: math.sin(math.pi * min(1, t / d))
# brush: a soft powder-brush swish across skin
write('b_brush', noise(0.26, lambda t: 0.18 + 0.25 * bell(t, 0.26), lambda t: bell(t, 0.26) ** 1.5), 0.32)
# sponge: a soft dab, a damp little puff
write('b_sponge', mix((noise(0.12, lambda t: 0.08 + 0.2 * t, lambda t: env(t, 0.01, 0.04)), 0),
                      (tone(lambda t: 180 + 260 * t, 0.1, 0.004, 0.03), 0)), 0.4)
# lipstick: a waxy smear with a tiny squeak
write('b_lipstick', mix((noise(0.22, lambda t: 0.1 + 0.12 * math.sin(t * 70), lambda t: bell(t, 0.22)), 0),
                        (tone(lambda t: 1500 + 300 * math.sin(t * 40), 0.16, 0.03, 0.05, ((1, 0.25), (2, 0.08))), 0.03)), 0.35)
# shake: glitter jar rattle (many tiny grains)
grains = [(noise(0.012, lambda t: 0.95, lambda t: env(t, 0.0005, 0.003)), random.uniform(0, 0.24)) for _ in range(46)]
write('b_shake', mix(*grains), 0.4)
# tinkle: glitter landing, high shimmering pings
write('b_tinkle', mix(*[(tone(lambda t, f=f: f, 0.18, 0.001, 0.05, ((1, 1), (2.76, 0.3))), i * 0.03)
                       for i, f in enumerate([3520, 4186, 3951, 4699, 5274])]), 0.3)
# wipe: a cleansing pad rubbing, soft and wet
write('b_wipe', noise(0.3, lambda t: 0.06 + 0.06 * math.sin(t * 50), lambda t: bell(t, 0.3) * (0.7 + 0.3 * math.sin(t * 140))), 0.45)
# cap: a polish bottle cap unscrewing click-click
clk = lambda f: mix((noise(0.02, lambda t: 0.9, lambda t: env(t, 0.0006, 0.004)), 0), (tone(lambda t: f, 0.04, 0.001, 0.01), 0))
write('b_cap', mix((clk(2600), 0), (clk(2300), 0.06), (clk(2000), 0.12)), 0.5)
# dip: the brush going into the bottle, a thick glug
write('b_dip', mix((tone(lambda t: 260 + 900 * min(1, t / 0.07), 0.14, 0.002, 0.05, ((1, 1), (2, 0.2))), 0),
                   (noise(0.08, lambda t: 0.25, lambda t: env(t, 0.003, 0.03)), 0.02)), 0.45)
# polish: a wet, slick brush stroke on a nail
write('b_polish', mix((noise(0.24, lambda t: 0.05 + 0.08 * bell(t, 0.24), lambda t: bell(t, 0.24)), 0),
                      (noise(0.24, lambda t: 0.5, lambda t: 0.12 * bell(t, 0.24) * (0.5 + 0.5 * math.sin(t * 260))), 0)), 0.4)
# drip: a thick polish drop plops
write('b_drip', mix((tone(lambda t: 520 - 260 * min(1, t / 0.08), 0.16, 0.002, 0.05, ((1, 1), (1.5, 0.3))), 0),
                    (noise(0.05, lambda t: 0.2, lambda t: env(t, 0.002, 0.015)), 0)), 0.45)
# dryer: a little nail fan whirring
write('b_dryer', mix((noise(0.5, lambda t: 0.35, lambda t: 0.6), 0),
                     (tone(lambda t: 240, 0.5, 0.02, 9, ((1, 1), (2, 0.5), (3, 0.25), (4, 0.1))), 0)), 0.28)
# clink: a rhinestone pressed on, a tiny glassy click
write('b_clink', mix((tone(lambda t: 5200, 0.12, 0.0005, 0.03, ((1, 1), (1.62, 0.4))), 0),
                     (noise(0.01, lambda t: 0.95, lambda t: env(t, 0.0003, 0.002)), 0)), 0.45)
# compact: a powder compact snapping open
write('b_compact', mix((tone(lambda t: 1400 - 700 * min(1, t / 0.03), 0.07, 0.001, 0.02, ((1, 1), (2.3, 0.5))), 0),
                       (noise(0.03, lambda t: 0.9, lambda t: env(t, 0.0005, 0.006)), 0)), 0.5)
# dry: the polish is set, a bright little chime
write('b_dry', mix((tone(lambda t: 2093, 0.4, 0.002, 0.14, ((1, 1), (2.76, 0.2))), 0),
                   (tone(lambda t: 2637, 0.45, 0.002, 0.16, ((1, 1), (2.76, 0.2))), 0.07)), 0.45)
