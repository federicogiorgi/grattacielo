"""Synthesize Grattacielo's music loops.

    python tools/make_music.py
    python tools/make_music.py --only day

Writes assets/audio/music/{day,night,rush}.ogg

WHAT THESE ARE
--------------
Lounge music for a lobby, which is the joke and also the brief: a game about a
skyscraper full of elevators should sound like the inside of one. Warm electric
piano, an upright bass, a vibraphone that says very little, and a shaker mixed
almost out of hearing. Nothing builds and nothing has a hook, because it plays
for hours behind a game that is really about queueing.

They are SYNTHESIZED, and they sound synthesized. The Sonniss bundle the sound
effects came from is an effects library with no music in it, so the choice was
between writing these and shipping silence. They are addressed by logical name
through data/audio_manifest.gd, so replacing one with something bought or
played is a matter of dropping a file in and nothing else.

THE LOOP IS SEAMLESS BY CONSTRUCTION
------------------------------------
Each track is rendered a few seconds longer than its loop length, and the
overhang is folded back onto the beginning. Every note ringing across the loop
point therefore continues into exactly the sound it would have made anyway, so
there is no click and no gap -- and none of the fading-out that gives away a
loop after the second time round.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf

OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "music"
RATE = 44100
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"

# Semitone offsets from the root for each chord, and the root itself as a MIDI
# note. A ii-V-I turnaround, which is the whole of lounge harmony.
PROGRESSIONS = {
    "day":   [(60, [0, 4, 7, 11, 14]),      # Cmaj9
              (57, [0, 3, 7, 10, 14]),      # Am9
              (62, [0, 3, 7, 10, 14]),      # Dm9
              (55, [0, 4, 7, 10, 14])],     # G9
    "night": [(57, [0, 3, 7, 10, 14]),      # Am9
              (53, [0, 4, 7, 11, 14]),      # Fmaj9
              (60, [0, 4, 7, 11, 14]),      # Cmaj9
              (55, [0, 4, 7, 10, 13])],     # G7b9
    "rush":  [(62, [0, 3, 7, 10, 14]),      # Dm9
              (55, [0, 4, 7, 10, 14]),      # G9
              (60, [0, 4, 7, 11, 14]),      # Cmaj9
              (65, [0, 4, 7, 11, 14])],     # Fmaj9
}

TRACKS = {
    "day":   dict(bpm=84, bars=16, seed=1041, lead=0.55, shaker=0.030,
                  note="the tower at work: warm, mid-century, unhurried"),
    "night": dict(bpm=66, bars=12, seed=2207, lead=0.34, shaker=0.012,
                  note="after hours: slower, sparser, more air around it"),
    "rush":  dict(bpm=96, bars=16, seed=3319, lead=0.62, shaker=0.048,
                  note="the two rush hours: the same room, a little busier"),
}

TAIL = 5.0        # seconds rendered past the loop and folded back


def midi(n: float) -> float:
    return 440.0 * (2.0 ** ((n - 69.0) / 12.0))


def env(n: int, attack: float, decay: float) -> np.ndarray:
    a = max(int(attack * RATE), 1)
    t = np.arange(n, dtype=np.float32)
    e = np.exp(-t / (decay * RATE)).astype(np.float32)
    e[:a] *= np.linspace(0.0, 1.0, a, dtype=np.float32)
    return e


def rhodes(freq: float, dur: float, gain: float, rng) -> np.ndarray:
    """An FM electric piano: one sine bent by another an octave above it."""
    n = int(dur * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    index = 2.4 * np.exp(-t / 0.45)                     # the bell in the attack
    mod = np.sin(2.0 * np.pi * freq * 2.0 * t) * index
    tone = np.sin(2.0 * np.pi * freq * t + mod)
    tone += 0.22 * np.sin(2.0 * np.pi * freq * 3.0 * t) * np.exp(-t / 0.12)
    trem = 1.0 + 0.06 * np.sin(2.0 * np.pi * 4.7 * t + rng.random() * 6.28)
    return (tone * env(n, 0.004, 1.35) * trem * gain).astype(np.float32)


def bass(freq: float, dur: float, gain: float) -> np.ndarray:
    """Upright bass: a fat sine with a short woody knock on the front."""
    n = int(dur * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    tone = np.sin(2.0 * np.pi * freq * t)
    tone += 0.30 * np.sin(2.0 * np.pi * freq * 2.0 * t) * np.exp(-t / 0.08)
    tone = np.tanh(tone * 1.4) * 0.7
    return (tone * env(n, 0.006, 0.55) * gain).astype(np.float32)


def vibes(freq: float, dur: float, gain: float) -> np.ndarray:
    """Vibraphone: near-pure, with the motor's slow wobble."""
    n = int(dur * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    wob = 1.0 + 0.010 * np.sin(2.0 * np.pi * 5.2 * t)
    tone = np.sin(2.0 * np.pi * freq * t * wob)
    tone += 0.18 * np.sin(2.0 * np.pi * freq * 4.0 * t) * np.exp(-t / 0.30)
    return (tone * env(n, 0.003, 1.7) * gain).astype(np.float32)


def shaker(dur: float, gain: float, rng) -> np.ndarray:
    n = int(dur * RATE)
    x = rng.standard_normal(n).astype(np.float32)
    # a crude high-pass, which is all a shaker is
    x = np.diff(np.concatenate([[0.0], x])).astype(np.float32)
    return (x * env(n, 0.002, 0.045) * gain).astype(np.float32)


def add(buf: np.ndarray, sig: np.ndarray, at: int, pan: float) -> None:
    n = min(len(sig), len(buf) - at)
    if n <= 0:
        return
    left = float(np.sqrt(0.5 * (1.0 - pan)))
    right = float(np.sqrt(0.5 * (1.0 + pan)))
    buf[at:at + n, 0] += sig[:n] * left
    buf[at:at + n, 1] += sig[:n] * right


def reverb(x: np.ndarray, seconds: float, mix: float, rng) -> np.ndarray:
    """A room, made by convolving with decaying noise. Cheap and convincing."""
    from scipy.signal import fftconvolve
    n = int(seconds * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    ir = rng.standard_normal((n, 2)).astype(np.float32) * np.exp(-t / (seconds / 4.0))[:, None]
    ir[: int(0.012 * RATE)] = 0.0                       # a little pre-delay
    ir /= np.sqrt(np.sum(ir ** 2, axis=0))[None, :]
    wet = np.stack([fftconvolve(x[:, c], ir[:, c])[: len(x)] for c in range(2)], axis=1)
    return ((1.0 - mix) * x + mix * wet).astype(np.float32)


def render(name: str) -> np.ndarray:
    cfg = TRACKS[name]
    prog = PROGRESSIONS[name]
    rng = np.random.default_rng(cfg["seed"])
    beat = 60.0 / float(cfg["bpm"])
    bar = beat * 4.0
    loop = bar * cfg["bars"]
    total = loop + TAIL
    buf = np.zeros((int(total * RATE) + RATE, 2), dtype=np.float32)

    for b in range(cfg["bars"]):
        root, tones = prog[b % len(prog)]
        t0 = b * bar

        # Electric piano: the chord on beat one, and a lighter stab on the and
        # of two, which is where lounge piano lives.
        for k, semi in enumerate(tones):
            note = root + semi + (12 if k >= 3 else 0)
            pan = -0.42 + 0.21 * k
            add(buf, rhodes(midi(note), 2.6, 0.115, rng),
                int((t0 + rng.uniform(0.0, 0.012)) * RATE), pan)
            if k < 3:
                add(buf, rhodes(midi(note + 12), 1.5, 0.055, rng),
                    int((t0 + beat * 1.5) * RATE), pan * 0.6)

        # Bass: root on one, fifth on three, and a passing note into the next
        # bar every other time.
        add(buf, bass(midi(root - 24), beat * 1.9, 0.36), int(t0 * RATE), 0.0)
        add(buf, bass(midi(root - 24 + 7), beat * 1.4, 0.28),
            int((t0 + beat * 2.0) * RATE), 0.0)
        if b % 2 == 1:
            nxt = prog[(b + 1) % len(prog)][0]
            add(buf, bass(midi(nxt - 24 - 1), beat * 0.8, 0.22),
                int((t0 + beat * 3.0) * RATE), 0.0)

        # Vibraphone: a few notes from the chord, never on the beat, and only
        # in some bars -- silence is most of what makes this bearable for hours.
        if rng.random() < cfg["lead"]:
            for _ in range(rng.integers(1, 4)):
                semi = int(rng.choice(tones))
                when = t0 + beat * float(rng.choice([0.5, 1.5, 2.5, 3.0, 3.5]))
                add(buf, vibes(midi(root + semi + 12), 2.2, 0.085 * rng.uniform(0.7, 1.0)),
                    int(when * RATE), float(rng.uniform(-0.3, 0.3)))

        # Shaker on the offbeats.
        if cfg["shaker"] > 0.0:
            for k in range(8):
                if k % 2 == 0:
                    continue
                add(buf, shaker(0.12, cfg["shaker"] * rng.uniform(0.7, 1.1), rng),
                    int((t0 + beat * 0.5 * k) * RATE), float(rng.uniform(-0.5, 0.5)))

    buf = reverb(buf, 1.6, 0.26, rng)

    # Fold the overhang back onto the head, so the loop point is exact.
    n_loop = int(loop * RATE)
    out = buf[:n_loop].copy()
    tail = buf[n_loop:]
    m = min(len(tail), n_loop)
    out[:m] += tail[:m]

    peak = float(np.max(np.abs(out)))
    if peak > 0.0:
        out *= 0.72 / peak
    return out


def write(name: str, x: np.ndarray) -> tuple[Path, float]:
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / f"{name}.ogg"
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td) / "raw.wav"
        sf.write(str(tmp), x, RATE, subtype="FLOAT")
        subprocess.run([FFMPEG, "-v", "error", "-nostdin", "-y", "-i", str(tmp),
                        "-c:a", "libvorbis", "-q:a", "4", str(dest)],
                       check=True, stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE)
    return dest, len(x) / RATE


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=None)
    args = ap.parse_args()
    names = args.only or list(TRACKS)
    for name in names:
        if name not in TRACKS:
            print(f"unknown track {name!r}", file=sys.stderr)
            return 1
        dest, secs = write(name, render(name))
        print(f"  {name:6s} {secs:6.2f}s  {dest.stat().st_size / 1024:7.1f} kB  "
              f"{TRACKS[name]['note']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
