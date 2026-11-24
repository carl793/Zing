"""Writes the app's 8-bit sound effects to assets/audio/sfx.

    python tool/make_sfx.py

Every sound is synthesised here, so there is nothing to license.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'audio' / 'sfx'
random.seed(7)


def square(phase, duty=0.5):
    return 1.0 if phase % 1 < duty else -1.0


def triangle(phase):
    p = phase % 1
    return 4 * abs(p - 0.5) - 1


def tone(ms, start, end=None, shape='square', duty=0.5, vol=0.3, decay=4.0):
    """One note, optionally sliding from [start] to [end] Hz."""
    end = start if end is None else end
    n = int(RATE * ms / 1000)
    phase, out = 0.0, []
    for i in range(n):
        t = i / n
        phase += (start + (end - start) * t) / RATE
        if shape == 'noise':
            value = random.uniform(-1, 1)
        elif shape == 'triangle':
            value = triangle(phase)
        else:
            value = square(phase, duty)
        # A short attack and release, so notes never pop.
        edge = min(1.0, i / 40, (n - i) / 60)
        out.append(value * vol * math.exp(-decay * t) * edge)
    return out


def silence(ms):
    return [0.0] * int(RATE * ms / 1000)


def mix(*tracks):
    out = [0.0] * max(len(t) for t in tracks)
    for track in tracks:
        for i, v in enumerate(track):
            out[i] += v
    return out


def save(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b''.join(
            struct.pack('<h', int(max(-1, min(1, v)) * 32767)) for v in samples))


# A mechanical key: a click of noise over a short falling blip.
save('tap', mix(tone(9, 0, shape='noise', vol=0.22, decay=6),
                tone(46, 760, 420, duty=0.25, vol=0.2, decay=5)))
save('tick', tone(24, 1250, 1100, duty=0.25, vol=0.14, decay=4))
save('toggle_on', tone(45, 660, duty=0.25, vol=0.18, decay=2)
     + tone(70, 990, duty=0.25, vol=0.18, decay=4))
save('toggle_off', tone(45, 880, duty=0.25, vol=0.16, decay=2)
     + tone(70, 587, duty=0.25, vol=0.16, decay=4))
save('open', tone(30, 523, duty=0.25, vol=0.13, decay=1)
     + tone(30, 659, duty=0.25, vol=0.13, decay=1)
     + tone(60, 784, duty=0.25, vol=0.13, decay=4))
save('close', tone(30, 784, duty=0.25, vol=0.12, decay=1)
     + tone(60, 523, duty=0.25, vol=0.12, decay=4))
save('error', tone(80, 196, 180, vol=0.2, decay=1.5) + silence(30)
     + tone(120, 156, 130, vol=0.2, decay=2.5))
save('hop', tone(120, 330, 820, duty=0.5, vol=0.14, decay=2.5))
# Coin.
save('save', tone(70, 988, duty=0.5, vol=0.17, decay=0.8)
     + tone(330, 1319, duty=0.5, vol=0.17, decay=4.5))
# Lid, then latch.
save('seal', mix(tone(130, 140, 60, shape='triangle', vol=0.6, decay=4),
                 tone(60, 0, shape='noise', vol=0.16, decay=7))
     + silence(40)
     + tone(140, 1568, 1480, duty=0.25, vol=0.15, decay=6))
notes = [523, 659, 784, 1047, 1319]
fanfare = []
for note in notes:
    fanfare += tone(75, note, duty=0.5, vol=0.16, decay=1.2)
fanfare += mix(tone(620, 1568, duty=0.5, vol=0.14, decay=3.2),
               tone(620, 1047, duty=0.25, vol=0.1, decay=3.2),
               tone(620, 262, shape='triangle', vol=0.25, decay=3))
save('unlock', fanfare)
