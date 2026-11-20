"""Synthesizes Tidy Up's sound effects and its calm background music into App/Resources/Games/Tidy/.
Run from the repo root: python3 tools/tidy/sounds.py   (needs numpy; ffmpeg for the music's .m4a).
No voices. Effects are 16-bit mono WAV; the music is one seamless loop (AAC in .m4a)."""
import os
import subprocess
import wave

import numpy as np

SR = 44100
OUT = 'App/Resources/Games/Tidy'
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def env(t, a, d):
    """Fast attack, exponential decay."""
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-np.maximum(0, t - a) / d)


def partials(t, f, parts):
    """Sum of (ratio, amp, decay) partials."""
    out = np.zeros_like(t)
    for ratio, amp, dec in parts:
        out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / dec)
    return out


def lowpass(x, a):
    y = np.empty_like(x)
    s = 0.0
    for i, v in enumerate(x):
        s += a * (v - s)
        y[i] = s
    return y


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def write(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    x = x / max(1e-9, np.abs(x).max()) * gain
    fade = int(SR * 0.004)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def sweep(t, f0, f1, dur):
    f = f0 + (f1 - f0) * np.minimum(1, t / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


# --- Effects ---------------------------------------------------------------------------------------
t = t_(0.16)
write('pickup', sweep(t, 420, 760, 0.1) * env(t, 0.01, 0.05), 0.55)
t = t_(0.22)
write('boop', sweep(t, 760, 420, 0.16) * env(t, 0.005, 0.07), 0.5)
t = t_(0.12)
write('pop', sweep(t, 950, 260, 0.06) * env(t, 0.002, 0.03) + 0.4 * lowpass(noise(0.12), 0.5) * env(t, 0.001, 0.012), 0.6)
t = t_(0.32)
n = lowpass(noise(0.32), 0.12)
write('whoosh', n * np.sin(np.pi * t / 0.32) ** 2, 0.45)

# Landing sounds, one per material.
t = t_(0.4)
write('clink', partials(t, 2093, [(1, 1, 0.09), (1.51, 0.6, 0.06), (2.74, 0.35, 0.04), (4.1, 0.2, 0.02)]) * env(t, 0.001, 1)
      + 0.25 * noise(0.4) * env(t, 0.0005, 0.004), 0.6)
t = t_(0.55)
write('tink', partials(t, 2637, [(1, 1, 0.18), (1.34, 0.5, 0.12), (2.21, 0.4, 0.08), (3.9, 0.2, 0.05)]) * env(t, 0.001, 1), 0.5)
t = t_(0.14)
write('tok', partials(t, 820, [(1, 1, 0.035), (2.3, 0.5, 0.02), (3.9, 0.2, 0.01)]) + 0.3 * noise(0.14) * env(t, 0.0005, 0.005), 0.75)
t = t_(0.18)
write('thud', partials(t, 150, [(1, 1, 0.05), (2, 0.3, 0.03)]) + 0.6 * lowpass(noise(0.18), 0.06) * env(t, 0.004, 0.04), 0.8)
t = t_(0.09)
write('click', partials(t, 1760, [(1, 1, 0.018), (2.6, 0.5, 0.01)]) + 0.5 * noise(0.09) * env(t, 0.0005, 0.004), 0.6)
t = t_(0.12)
write('pat', 0.8 * lowpass(noise(0.12), 0.35) * env(t, 0.001, 0.025) + partials(t, 330, [(1, 0.5, 0.03)]), 0.6)
t = t_(0.2)
write('plunk', sweep(t, 330, 210, 0.1) * env(t, 0.003, 0.06) + 0.25 * lowpass(noise(0.2), 0.2) * env(t, 0.001, 0.01), 0.75)

# All done: a little rising music-box arpeggio with a shimmer.
t = t_(2.2)
out = np.zeros_like(t)
for k, f in enumerate([659.25, 783.99, 1046.5, 1318.5, 1568.0]):
    o = int(k * 0.11 * SR)
    tt = t[:len(t) - o]
    out[o:] += partials(tt, f, [(1, 1, 0.7), (2, 0.25, 0.3), (3, 0.1, 0.15)]) * env(tt, 0.003, 1)
sh = np.zeros_like(t)
for k in range(14):
    o = int((0.35 + k * 0.07) * SR)
    tt = t[:len(t) - o]
    sh[o:] += 0.18 * np.sin(2 * np.pi * (2800 + 180 * (k % 5)) * tt) * env(tt, 0.002, 0.08)
write('chime', out + sh, 0.75)


# --- Music -----------------------------------------------------------------------------------------
# A slow, warm loop in F major: soft pad chords, a round bass and a music-box melody. Every note and
# the reverb tail wrap around the end, so the loop has no seam.
BPM = 72
BEAT = 60 / BPM
BARS = 16
L = int(round(BARS * 4 * BEAT * SR))
mix = np.zeros(L)


def midi(n):
    return 440 * 2 ** ((n - 69) / 12)


def add(x, start):
    o = int(start * SR) % L
    n = len(x)
    end = o + n
    if end <= L:
        mix[o:end] += x
    else:
        first = L - o
        mix[o:] += x[:first]
        rest = x[first:]
        while len(rest) > 0:
            k = min(L, len(rest))
            mix[:k] += rest[:k]
            rest = rest[k:]


def pad_note(f, dur, amp):
    t = t_(dur + 1.5)
    a = np.minimum(1, t / 0.9) * np.where(t < dur, 1, np.exp(-(t - dur) / 0.5))
    x = np.zeros_like(t)
    for det in (-0.12, 0.0, 0.11):
        ff = f * 2 ** (det / 12)
        x += np.sin(2 * np.pi * ff * t) + 0.3 * np.sin(2 * np.pi * 2 * ff * t) + 0.08 * np.sin(2 * np.pi * 3 * ff * t)
    trem = 1 + 0.08 * np.sin(2 * np.pi * 0.25 * t)
    return amp * x * a * trem / 3


def bell(f, amp, dur=2.2):
    t = t_(dur)
    x = partials(t, f, [(1, 1, 0.9), (2, 0.35, 0.4), (3.01, 0.12, 0.2), (4.2, 0.05, 0.1)])
    return amp * x * np.minimum(1, t / 0.004)


def bass(f, dur, amp):
    t = t_(dur + 0.3)
    a = np.minimum(1, t / 0.03) * np.where(t < dur, np.exp(-t / 1.6), np.exp(-dur / 1.6) * np.exp(-(t - dur) / 0.08))
    return amp * (np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * 2 * f * t)) * a


# Chords (MIDI notes) for each 2-bar step: Fmaj7, Am7, Dm9, Bbmaj7 / Fmaj7, Gm7, Bbmaj7, C6.
chords = [[53, 57, 60, 64], [57, 60, 64, 67], [50, 57, 60, 64], [46, 53, 57, 62],
          [53, 57, 60, 64], [55, 58, 62, 65], [46, 53, 57, 62], [48, 55, 57, 64]]
roots = [41, 45, 38, 46, 41, 43, 46, 48]
for i, ch in enumerate(chords):
    start = i * 8 * BEAT
    for n in ch:
        add(pad_note(midi(n), 8 * BEAT, 0.11), start)
    add(bass(midi(roots[i] - 12 + 12), 3.6 * BEAT, 0.32), start)
    add(bass(midi(roots[i] - 12 + 12 + 7), 1.8 * BEAT, 0.18), start + 4 * BEAT)
    add(bass(midi(roots[i]), 1.8 * BEAT, 0.22), start + 6 * BEAT)

# Melody: F major pentatonic over two octaves, a gentle walk that leans on chord tones.
scale = [65, 67, 69, 72, 74, 77, 79, 81, 84]
mrng = np.random.default_rng(21)


def phrase(seed_chords):
    notes = []
    idx = 4
    for bar in range(4):
        ch = seed_chords[bar // 2]
        beat = 0.0
        while beat < 4:
            step = mrng.choice([-2, -1, -1, 0, 1, 1, 2])
            idx = int(np.clip(idx + step, 0, len(scale) - 1))
            n = scale[idx]
            # Snap to a chord tone on the strong beats.
            if beat in (0.0, 2.0):
                pcs = [(c % 12) for c in ch]
                best = min(range(len(scale)), key=lambda k: (scale[k] % 12 not in pcs, abs(k - idx)))
                idx = best
                n = scale[idx]
            length = mrng.choice([1.0, 1.0, 0.5, 1.5, 2.0])
            if beat + length > 4:
                length = 4 - beat
            if mrng.random() > 0.18:
                notes.append((bar * 4 + beat, n, length))
            beat += length
    return notes


A = phrase(chords[0:2])
B = phrase(chords[2:4])
C = phrase(chords[4:6])
D = phrase(chords[6:8])
for k, ph in enumerate([A, B, C, D]):
    for beat, n, length in ph:
        add(bell(midi(n), 0.2), (k * 16 + beat) * BEAT)
        # A soft echo an octave up, now and then.
        if length >= 1.5:
            add(bell(midi(n + 12), 0.06), (k * 16 + beat + 0.75) * BEAT)

# Gentle brush of air on every second beat.
for b in range(BARS * 4):
    if b % 2 == 1:
        t = t_(0.18)
        add(0.02 * lowpass(noise(0.18), 0.3) * env(t, 0.01, 0.05), b * BEAT)

# Circular reverb: convolve with a decaying-noise impulse and fold the tail back to the start.
ir_t = t_(2.6)
ir = rng.normal(0, 1, len(ir_t)) * np.exp(-ir_t / 0.75)
ir = lowpass(ir, 0.25)
ir /= np.abs(ir).sum() ** 0.5 * 3
wet = np.real(np.fft.ifft(np.fft.fft(mix) * np.fft.fft(ir, L)))
song = 0.75 * mix + 0.55 * wet
song = np.tanh(song / np.abs(song).max() * 1.2) * 0.8
stereo = np.stack([song, np.roll(song, int(0.012 * SR))], axis=1)
raw = f'{OUT}/_calm.wav'
pcm = (np.clip(stereo, -1, 1) * 32767).astype('<i2')
with wave.open(raw, 'wb') as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(pcm.tobytes())
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', raw, '-c:a', 'aac', '-b:a', '96k', f'{OUT}/calm.m4a'], check=True)
os.remove(raw)
print('wrote', sorted(os.listdir(OUT)), f'music {L / SR:.1f}s')
