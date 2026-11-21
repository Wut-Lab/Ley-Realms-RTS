#!/usr/bin/env python3
"""Synthesizes every sound effect and the music loop for Ley Realms (no recorded samples).

Usage:  python3 tools/gen_audio.py          (needs numpy; ffmpeg with libvorbis for the music)
Writes: sounds/*.wav and sounds/music.ogg
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds")
rng = np.random.default_rng(1234)


# ------------------------------------------------------------------ building blocks
def secs(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return rng.uniform(-1.0, 1.0, int(SR * d))


def decay(n, tau, attack=0.002):
    t = np.arange(n) / SR
    e = np.exp(-t / tau)
    a = max(1, int(attack * SR))
    e[:a] *= np.linspace(0, 1, a)
    return e


def lowpass(x, fc):
    a = 1.0 - np.exp(-2 * np.pi * fc / SR)
    k = int(np.ceil(np.log(1e-4) / np.log(1 - a))) if a < 1 else 1
    kern = a * (1 - a) ** np.arange(max(k, 1))
    return np.convolve(x, kern)[: len(x)]


def highpass(x, fc):
    return x - lowpass(x, fc)


def band(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def osc(freq, d, kind="sine"):
    n = int(SR * d)
    f = np.full(n, freq, dtype=float) if np.isscalar(freq) else np.asarray(freq, dtype=float)[:n]
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if kind == "square":
        return np.sign(np.sin(ph))
    if kind == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1.0) - 1) - 1
    raise ValueError(kind)


def sweep(f0, f1, d, curve=1.0):
    t = np.linspace(0, 1, int(SR * d)) ** curve
    return f0 + (f1 - f0) * t


def pluck(freq, d, damp=0.995, bright=0.5):
    """Karplus-Strong plucked string."""
    n = int(SR * d)
    p = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, p) * bright + rng.uniform(-1, 1, p) * (1 - bright) * 0.3
    out = np.zeros(n)
    for i in range(n):
        j = i % p
        out[i] = buf[j]
        buf[j] = damp * 0.5 * (buf[j] + buf[(j + 1) % p])
    return out


def bell(freqs, d, tau=0.6, ratios=(1.0, 2.0, 2.76, 5.4), amps=(1.0, 0.5, 0.35, 0.15)):
    out = np.zeros(int(SR * d))
    for f in np.atleast_1d(freqs):
        for r, a in zip(ratios, amps):
            out += a * osc(f * r, d) * decay(len(out), tau / (0.6 + r * 0.4))
    return out


def place(dst, src, at):
    i = int(at * SR)
    if i >= len(dst):
        return
    n = min(len(src), len(dst) - i)
    dst[i:i + n] += src[:n]


def note(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + 12 * (octave + 1) - 69) / 12)


def save(name, x, peak=0.9):
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    f = min(len(x), int(0.004 * SR))
    x[-f:] *= np.linspace(1, 0, f)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ------------------------------------------------------------------ sound effects
def make_sfx():
    # interface
    d = 0.06
    save("click", (osc(1400, d) * 0.6 + osc(2100, d) * 0.3) * decay(int(SR * d), 0.012), 0.5)
    x = np.zeros(int(SR * 0.16))
    place(x, osc(660, 0.08) * decay(int(SR * 0.08), 0.03), 0)
    place(x, osc(990, 0.08) * decay(int(SR * 0.08), 0.03), 0.06)
    save("select", lowpass(x, 3000), 0.45)
    d = 0.12
    save("order", lowpass(osc(sweep(520, 360, d), d, "tri") * decay(int(SR * d), 0.04), 2500), 0.45)
    d = 0.22
    save("error", lowpass(osc(110, d, "saw") + osc(116, d, "saw"), 900) * decay(int(SR * d), 0.08), 0.5)

    # combat
    for i in range(3):
        d = 0.5
        parts = rng.uniform([1100, 2400, 3600, 5000], [1400, 2900, 4200, 6200])
        m = sum(osc(f, d) * decay(int(SR * d), 0.08 + 0.05 * rng.random()) * a for f, a in zip(parts, (1, .7, .5, .3)))
        hit = band(noise(d), 1500, 6000) * decay(int(SR * d), 0.012)
        save("sword%d" % (i + 1), m * 0.6 + hit * 0.9, 0.75)
    for i in range(2):
        d = 0.18
        thud = lowpass(noise(d), 500 + 200 * i) * decay(int(SR * d), 0.035) + osc(sweep(140, 70, d), d) * decay(int(SR * d), 0.05)
        save("hit%d" % (i + 1), thud, 0.8)
    d = 0.35
    twang = pluck(220, d, 0.99, 0.8) * decay(int(SR * d), 0.12)
    whoosh = band(noise(d), 800, 4000) * np.sin(np.linspace(0, np.pi, int(SR * d))) * 0.25
    save("bow", twang + whoosh, 0.7)
    d = 0.12
    save("arrow_hit", lowpass(noise(d), 1800) * decay(int(SR * d), 0.02) + osc(180, d) * decay(int(SR * d), 0.03) * 0.5, 0.6)
    d = 0.6
    env = np.sin(np.linspace(0, np.pi, int(SR * d))) ** 0.7
    roar = band(noise(d), 300, 2500) * env + osc(sweep(90, 160, d), d, "saw") * env * 0.15
    save("fire_cast", lowpass(roar, 3000), 0.7)
    d = 1.3
    boom = lowpass(noise(d), 700) * decay(int(SR * d), 0.35) + osc(sweep(90, 35, d, 0.5), d) * decay(int(SR * d), 0.3) * 0.9
    crack = band(noise(d), 1500, 6000) * decay(int(SR * d), 0.05) * 0.6
    save("explosion", boom + crack, 0.9)
    d = 0.55
    creak = band(osc(sweep(300, 180, 0.25), 0.25, "saw"), 200, 1500) * decay(int(SR * 0.25), 0.1)
    x = np.zeros(int(SR * d))
    place(x, creak * 0.6, 0)
    place(x, lowpass(noise(0.2), 600) * decay(int(SR * 0.2), 0.04) + osc(120, 0.2) * decay(int(SR * 0.2), 0.05), 0.22)
    place(x, band(noise(0.3), 500, 3000) * np.sin(np.linspace(0, np.pi, int(SR * 0.3))) * 0.3, 0.25)
    save("catapult", x, 0.8)
    d = 1.1
    vib = 6 * np.sin(2 * np.pi * 7 * secs(d))
    f = sweep(110, 75, d) + vib
    env = np.minimum(1, secs(d) / 0.15) * decay(int(SR * d), 0.6)
    growl = (osc(f, d, "saw") + osc(f * 1.5, d, "saw") * 0.5) * env
    save("roar", lowpass(growl + band(noise(d), 400, 3000) * env * 0.5, 1800), 0.85)

    # economy
    for i, fc in enumerate((700, 950)):
        d = 0.16
        knock = band(noise(d), fc * 0.6, fc * 1.6) * decay(int(SR * d), 0.025) + osc(fc * 0.35, d) * decay(int(SR * d), 0.04) * 0.6
        save("chop%d" % (i + 1), knock, 0.6)
    for i, fc in enumerate((2400, 2900)):
        d = 0.25
        clink = osc(fc, d) * decay(int(SR * d), 0.05) + osc(fc * 1.47, d) * decay(int(SR * d), 0.03) * 0.6
        save("mine%d" % (i + 1), clink + band(noise(d), 2000, 7000) * decay(int(SR * d), 0.008) * 0.8, 0.5)
    save("mana", bell([1568, 2093], 0.8, 0.5), 0.35)
    for i, f in enumerate((170, 200)):
        d = 0.14
        save("hammer%d" % (i + 1), lowpass(noise(d), 1500) * decay(int(SR * d), 0.02) + osc(f, d) * decay(int(SR * d), 0.04), 0.6)

    # life and death
    for i, (f0, f1) in enumerate(((420, 180), (360, 150))):
        d = 0.45
        formant = band(noise(d), 200, 900) * 0.5 + osc(sweep(f0 / 3, f1 / 3, d), d, "saw") * 0.6
        save("death%d" % (i + 1), lowpass(formant, sweep(1400, 400, d).mean()) * decay(int(SR * d), 0.15, 0.02), 0.6)
    d = 1.8
    rumble = lowpass(noise(d), 300) * decay(int(SR * d), 0.6, 0.05)
    crackle = band(noise(d), 1000, 5000) * (rng.random(int(SR * d)) > 0.995) * 3 * decay(int(SR * d), 0.6)
    save("collapse", rumble + lowpass(crackle, 4000), 0.85)

    # notifications
    x = np.zeros(int(SR * 1.1))
    for i, n in enumerate(("C5", "E5", "G5")):
        place(x, bell(note(n), 0.8, 0.5), i * 0.11)
    save("complete", x, 0.5)
    x = np.zeros(int(SR * 0.6))
    for i, n in enumerate(("G4", "C5")):
        tone = lowpass(osc(note(n), 0.3, "square") * 0.5 + osc(note(n), 0.3), 2200)
        place(x, tone * np.minimum(1, secs(0.3) / 0.02) * decay(int(SR * 0.3), 0.18), i * 0.15)
    save("ready", x, 0.45)
    x = np.zeros(int(SR * 1.0))
    for i, n in enumerate(("C6", "E6", "G6", "C7")):
        place(x, bell(note(n), 0.6, 0.35), i * 0.07)
    save("research", x, 0.4)

    def horn(f, d):
        env = np.minimum(1, secs(d) / 0.12) * np.minimum(1, (d - secs(d)) / 0.2)
        return lowpass(osc(f, d, "saw") + osc(f * 1.005, d, "saw") * 0.7, 1100) * env

    x = np.zeros(int(SR * 1.6))
    place(x, horn(196, 0.55), 0)
    place(x, horn(196, 0.8), 0.7)
    save("alert", x, 0.75)

    def brass(n, d):
        f = note(n)
        env = np.minimum(1, secs(d) / 0.04) * decay(int(SR * d), d * 0.8)
        return lowpass(osc(f, d, "saw") * 0.6 + osc(f * 2, d) * 0.3 + osc(f, d) * 0.5, 2500) * env

    x = np.zeros(int(SR * 1.6))
    for i, n in enumerate(("C5", "E5", "G5")):
        place(x, brass(n, 0.25), i * 0.13)
    place(x, brass("C6", 0.9), 0.4)
    save("levelup", x, 0.6)
    x = np.zeros(int(SR * 2.6))
    for i, (n, l) in enumerate((("G4", .3), ("C5", .3), ("E5", .3), ("G5", .5))):
        place(x, brass(n, l), [0, .2, .4, .6][i])
    for n in ("C5", "E5", "G5", "C6"):
        place(x, brass(n, 1.6), 1.0)
    save("age_up", x, 0.65)

    # magic
    d = 0.9
    x = band(noise(d), 1500, 6000) * np.sin(np.linspace(0, np.pi, int(SR * d))) * 0.3
    for k in range(12):
        place(x, osc(rng.uniform(1500, 4000), 0.15) * decay(int(SR * 0.15), 0.05) * 0.4, rng.uniform(0, 0.7))
    save("cast", x, 0.5)
    d = 0.9
    x = band(noise(d), 3000, 9000) * decay(int(SR * d), 0.12)
    for k in range(8):
        place(x, bell(rng.uniform(2000, 4500), 0.4, 0.15) * 0.5, rng.uniform(0, 0.4))
    save("frost", x, 0.5)
    d = 1.0
    x = np.zeros(int(SR * d))
    for i, n in enumerate(("A4", "C#5", "E5", "A5")):
        place(x, osc(note(n), 0.7) * np.sin(np.linspace(0, np.pi, int(SR * 0.7))) * 0.5, i * 0.08)
    save("heal", lowpass(x, 3000), 0.4)
    save("shrine", bell([220, 330], 2.2, 1.6), 0.55)

    # match end
    x = np.zeros(int(SR * 3.2))
    for i, n in enumerate(("C5", "E5", "G5", "C6")):
        place(x, brass(n, 0.35), i * 0.18)
    for n in ("C5", "E5", "G5", "C6"):
        place(x, brass(n, 2.2), 0.8)
    save("victory", x, 0.7)
    x = np.zeros(int(SR * 3.2))
    for i, n in enumerate(("A4", "F4", "D4")):
        place(x, horn(note(n), 0.8) * 0.8, i * 0.6)
    place(x, horn(note("D3"), 1.6), 1.8)
    save("defeat", x, 0.7)


# ------------------------------------------------------------------ music
def make_music():
    bpm = 80
    beat = 60.0 / bpm
    bars = 32
    bar = beat * 4
    length = bars * bar
    tail = 3.0
    mix = np.zeros(int(SR * (length + tail)))
    # D dorian progression, two bars per chord
    prog = [("D3", "F3", "A3"), ("C3", "E3", "G3"), ("A#2", "D3", "F3"), ("C3", "E3", "G3"),
            ("D3", "F3", "A3"), ("F3", "A3", "C4"), ("C3", "E3", "G3"), ("D3", "F3", "A3")]
    scale = ["D4", "E4", "F4", "G4", "A4", "B4", "C5", "D5", "E5", "F5", "A5"]

    # pad + drone
    for b in range(0, bars, 2):
        chord = prog[(b // 2) % len(prog)]
        d = bar * 2 + 1.0
        env = np.minimum(1, secs(d) / 0.8) * np.minimum(1, (d - secs(d)) / 1.2)
        pad = np.zeros(int(SR * d))
        for n in chord:
            f = note(n)
            pad += osc(f, d, "tri") * 0.25 + osc(f * 1.003, d) * 0.2 + osc(f * 0.5, d) * 0.12
        place(mix, lowpass(pad * env, 1200) * 0.5, b * bar)
    drone = osc(note("D2"), length) * 0.18 + osc(note("A2"), length) * 0.1
    place(mix, drone * (0.8 + 0.2 * np.sin(2 * np.pi * secs(length) / 12.0)), 0)

    # lute arpeggios (bars 4-27)
    for b in range(4, 28):
        chord = prog[(b // 2) % len(prog)]
        pattern = [0, 1, 2, 1, 0, 2, 1, 2]
        for k, idx in enumerate(pattern):
            f = note(chord[idx]) * 2
            place(mix, pluck(f, 0.9, 0.994, 0.6) * decay(int(SR * 0.9), 0.35) * 0.28, b * bar + k * beat / 2)

    # flute melody (bars 8-23 and 24-31 variation)
    def flute(f, d):
        t = secs(d)
        vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1, t / 0.3)
        tone = osc(f * vib, d) + osc(2 * f * vib, d) * 0.18 + osc(3 * f * vib, d) * 0.05
        breath = band(noise(d), 1500, 5000) * 0.05
        env = np.minimum(1, t / 0.06) * np.minimum(1, (d - t) / 0.12)
        return (tone + breath) * env

    idx = 4
    tpos = 8 * bar
    end = 30 * bar
    while tpos < end:
        dur = beat * rng.choice([1, 1, 2, 0.5, 1.5], p=[0.35, 0.2, 0.25, 0.1, 0.1])
        if rng.random() < 0.12:
            tpos += beat
            continue
        idx = int(np.clip(idx + rng.choice([-2, -1, -1, 0, 1, 1, 2]), 0, len(scale) - 1))
        place(mix, flute(note(scale[idx]), dur * 0.95) * 0.32, tpos)
        tpos += dur

    # frame drum
    def drum(low=True):
        d = 0.35
        if low:
            return osc(sweep(95, 55, d), d) * decay(int(SR * d), 0.12) + lowpass(noise(d), 400) * decay(int(SR * d), 0.03) * 0.5
        return band(noise(0.08), 1500, 6000) * decay(int(SR * 0.08), 0.015) * 0.3

    for b in range(8, 30):
        for k in range(8):
            if k in (0, 5):
                place(mix, drum(True) * 0.5, b * bar + k * beat / 2)
            elif k in (2, 6):
                place(mix, drum(False), b * bar + k * beat / 2)

    # hall reverb by FFT convolution with a decaying noise impulse
    ir_len = int(SR * 2.2)
    ir = rng.uniform(-1, 1, ir_len) * np.exp(-np.arange(ir_len) / (SR * 0.55))
    ir = lowpass(ir, 3500)
    ir /= np.sqrt(np.sum(ir ** 2))
    n = len(mix) + ir_len
    nfft = 1 << (n - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(mix, nfft) * np.fft.rfft(ir, nfft), nfft)[:n]
    out = np.concatenate([mix, np.zeros(ir_len)]) * 0.8 + wet * 0.35
    # wrap the tail into the start so the loop is seamless
    L = int(SR * length)
    loop = out[:L].copy()
    rest = out[L:]
    loop[:len(rest)] += rest[:L]
    loop /= np.max(np.abs(loop))
    loop *= 0.85
    wav_path = os.path.join(OUT, "_music.wav")
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((loop * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "3",
                    os.path.join(OUT, "music.ogg")], check=True)
    os.remove(wav_path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_sfx()
    make_music()
    print("wrote", sorted(os.listdir(OUT)))
