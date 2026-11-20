"""Synthesizes the aquarium's sound effects into App/Resources/Games/Aquarium/ (16-bit mono WAV).
Run from the repo root: python3 tools/aquarium/sounds.py   (stdlib only). No voices, just sounds.
hum (the filter's soft drone with a trickle) and pump (an air stone bubbling) are seamless loops."""
import math, os, random, struct, wave

SR = 22050
OUT = 'App/Resources/Games/Aquarium'
os.makedirs(OUT, exist_ok=True)
random.seed(11)


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


def blip(f0, rise, dur, decay):
    """An underwater bubble: a sine whose pitch sweeps up as the bubble shrinks (Minnaert resonance)."""
    return tone(lambda t: f0 * (1 + rise * t / dur), dur, 0.002, decay)


# bloop: one bubble rising and popping
write('bloop', mix((blip(380, 1.8, 0.16, 0.05), 0), (blip(620, 1.2, 0.08, 0.025), 0.07)), 0.7)
# pop: a tiny pop at the surface
write('pop', mix((blip(900, 1.5, 0.05, 0.012), 0), (noise(0.02, 0.9, lambda t: math.exp(-t * 300)), 0)), 0.55)
# plop: a flake landing on the water
write('plop', mix((blip(700, 0.9, 0.06, 0.02), 0), (noise(0.03, 0.6, lambda t: math.exp(-t * 160)), 0)), 0.45)
# splash: something dropped into the tank, a slosh and a few drips
sp = [(noise(0.45, lambda t: 0.5 - 0.8 * t, lambda t: math.exp(-t * 9)), 0), (blip(260, 2.2, 0.2, 0.08), 0.01)]
for k in range(5):
    sp.append((blip(random.uniform(700, 1300), 1.2, 0.05, 0.02), 0.12 + k * 0.06 + random.uniform(0, 0.03)))
write('splash', mix(*sp), 0.75)
# splish: a small splash from a finger in the surface
write('splish', mix((noise(0.15, 0.45, lambda t: math.exp(-t * 25)), 0), (blip(900, 1, 0.05, 0.02), 0.04)), 0.5)
# gulp: a fish snapping up food
write('gulp', mix((tone(lambda t: 240 + 500 * t, 0.07, 0.002, 0.02, ((1, 1), (2, 0.3))), 0), (blip(520, 1.5, 0.06, 0.02), 0.03)), 0.6)
# squeak: a sponge rubbing wet glass
write('squeak', mix((tone(lambda t: 1500 + 300 * math.sin(t * 40), 0.16, 0.01, 0.08, ((1, 1), (2, 0.35), (3, 0.15))), 0),
                    (noise(0.16, 0.6, lambda t: 0.15 * math.sin(math.pi * t / 0.16)), 0)), 0.45)
# tink: a fingernail on the glass
write('tink', mix((tone(lambda t: 2400, 0.35, 0.001, 0.07, ((1, 1), (2.76, 0.4), (5.4, 0.15))), 0),
                  (tone(lambda t: 3300, 0.2, 0.001, 0.04), 0)), 0.55)
# thud: a decoration landing in the sand underwater, muffled
write('thud', mix((tone(lambda t: 110 - 60 * t, 0.25, 0.003, 0.08, ((1, 1), (2, 0.25))), 0),
                  (noise(0.3, 0.06, lambda t: math.exp(-t * 14)), 0)), 0.8)
# shake: food rattling in its shaker
sh = []
for k in range(7):
    sh.append((noise(0.03, 0.85, lambda t: math.exp(-t * 120)), k * 0.028 + random.uniform(0, 0.01)))
write('shake', mix(*sh), 0.5)
# puff: the puffer gulping water to blow up
write('puff', mix((noise(0.3, lambda t: 0.08 + 0.2 * t, lambda t: math.sin(math.pi * t / 0.3)), 0),
                  (tone(lambda t: 200 + 600 * t, 0.3, 0.02, 0.2), 0)), 0.6)
# swish: something moved quickly through water
write('swish', noise(0.28, lambda t: 0.04 + 0.25 * math.sin(math.pi * t / 0.28), lambda t: math.sin(math.pi * t / 0.28) ** 2), 0.5)
# chime: the glass is sparkling clean
write('chime', mix(*[(tone(lambda t, f=f: f, 0.7, 0.003, 0.25, ((1, 1), (2, 0.2), (3, 0.06))), k * 0.08)
                     for k, f in enumerate([1047, 1319, 1568, 2093])]), 0.5)
# blub: a happy fish, two bubbly notes going up
write('blub', mix((blip(330, 0.8, 0.1, 0.04), 0), (blip(440, 0.8, 0.1, 0.04), 0.1), (blip(560, 0.9, 0.12, 0.05), 0.2)), 0.6)
# creak: the treasure chest lid
write('creak', mix((tone(lambda t: 180 + 40 * math.sin(t * 30) + 120 * t, 0.4, 0.02, 0.3, ((1, 1), (2, 0.5), (3, 0.3), (5, 0.15))), 0)), 0.45)
# bag: a plastic bag of water, crinkly
bg = []
for k in range(8):
    bg.append((noise(0.04, 0.95, lambda t: math.exp(-t * 90)), k * 0.035 + random.uniform(0, 0.015)))
bg.append((noise(0.3, 0.2, lambda t: 0.3 * math.sin(math.pi * t / 0.3)), 0))
write('bag', mix(*bg), 0.5)
# pick: picking something up
write('pick', mix((tone(lambda t: 520 + 400 * t, 0.08, 0.002, 0.03), 0), (noise(0.03, 0.4, lambda t: math.exp(-t * 100)), 0)), 0.5)
# click: the lamp switch
write('click', mix((noise(0.015, 0.95, lambda t: math.exp(-t * 400)), 0), (tone(lambda t: 1800, 0.04, 0.001, 0.01), 0),
                   (noise(0.015, 0.95, lambda t: math.exp(-t * 400)), 0.05)), 0.55)
# boing: a decoration wobbling
write('boing', tone(lambda t: 300 + 80 * math.sin(t * 40) * math.exp(-t * 6), 0.4, 0.003, 0.14, ((1, 1), (2, 0.25))), 0.5)

# Loops
# hum: the filter's soft drone and a trickle of water back into the tank
hm = tone(lambda t: 60, 4.4, 0.01, 1e9, ((1, 0.25), (2, 0.6), (3, 0.15)))
tr = noise(4.4, lambda t: 0.18 + 0.05 * math.sin(t * 7), lambda t: 0.5 + 0.15 * math.sin(t * 2.3))
hm = [a * 0.25 + b for a, b in zip(hm, tr)]
for k in range(40):
    o = int(random.uniform(0, 4.3) * SR)
    d = blip(random.uniform(500, 1100), 1, 0.04, 0.015)
    for i, x in enumerate(d):
        if o + i < len(hm): hm[o + i] += x * 0.12
loop('hum', hm, 0.6, 0.4)
# pump: an air stone bubbling steadily
pm = noise(3.4, 0.2, lambda t: 0.12)
for k in range(150):
    o = int(random.uniform(0, 3.3) * SR)
    d = blip(random.uniform(300, 900), random.uniform(0.6, 1.6), random.uniform(0.03, 0.08), 0.02)
    for i, x in enumerate(d):
        if o + i < len(pm): pm[o + i] += x * random.uniform(0.25, 0.6)
loop('pump', pm, 0.4, 0.5)
print('ok')
