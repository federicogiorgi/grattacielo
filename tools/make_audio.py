"""Cut Grattacielo's sound effects and ambiences out of the Sonniss bundle.

    python tools/make_audio.py
    python tools/make_audio.py --only ding cash amb_day
    python tools/make_audio.py --list

WHERE THE SOUND COMES FROM
--------------------------
The Sonniss GDC Game Audio Bundle, which the project owner already holds and
which he used the same way for Tabi. Its licence permits modification and
commercial use in games and asks for no attribution; provenance is recorded in
assets/audio/CREDITS.md anyway, because in a year nobody will remember which
recording a two-second ding was cut from.

WHAT THIS DOES
--------------
For each entry in SPEC: read the source, downmix, resample to 44.1 kHz, cut the
region that actually contains the sound, and write an OGG into assets/audio/.

Looping beds get a proper seam: the tail is cross-faded back over the head, so
the loop point is inaudible. One-shots get short fades instead, because a click
at the start of a sound that fires every few seconds is the thing you notice
first.

Levels are matched on RMS within each group -- one-shots to one target, beds to
another, much quieter. Peak-matching is not the same thing and sounds wrong:
a bright ting and a dull thud can share a peak and be nowhere near each other
in perceived loudness.
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

BUNDLE = Path(r"G:\qbittorrent\Sonniss.com-GDC2026-GameAudioBundle")
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
RATE = 44100

# Perceived-loudness targets, as RMS of the normalized float signal.
RMS_ONESHOT = 0.115
RMS_BED = 0.045

# name -> source, region, and how it is used.
#   src    : path inside the bundle
#   region : (start_seconds, duration_seconds); None means the whole file
#   kind   : "sfx" one-shot, or "bed" seamless loop
#   mono   : collapse to one channel (true for small effects)
#   trim   : extra gain in dB applied after RMS matching, for taste
SPEC: dict[str, dict] = {
    # --- elevators ---------------------------------------------------------
    "ding": dict(
        src="CB_Sounddesign - Applicable Sounds - Organic UI and Building Games SFX/"
            "UIMisc_Xylophone Ringtone 2_CB Sounddesign_APPlicable Sounds.wav",
        region=(0.00, 0.75), kind="sfx", mono=True, trim=-4.0,
        note="two-note xylophone, used as the car's arrival chime",
    ),
    "doors": dict(
        src="InMotionAudio - USA Hotel/DOORMetl_StairWellDoor01_InMotionAudio_USAHotel.wav",
        region=(0.00, 1.10), kind="sfx", mono=True, trim=-6.0,
        note="a heavy door, used for the service lift",
    ),
    # --- money -------------------------------------------------------------
    "cash": dict(
        src="Cinematic Sound Design - UI Interaction Elements/Ting Coins.wav",
        region=(0.00, 1.10), kind="sfx", mono=False, trim=0.0,
        note="coins, for income arriving",
    ),
    "spend": dict(
        src="Cinematic Sound Design - Hybrid Game & UI Elements/Foley Coin Flip Single Fast.wav",
        region=None, kind="sfx", mono=True, trim=-3.0,
        note="a single coin, for money going out",
    ),
    # --- construction ------------------------------------------------------
    "build": dict(
        src="Epic Stock Media - Public Spaces - Urban Life Exteriors/"
            "AMBCnst_Baltimore Construction Streetside Heavy Machinery And Jakchammers 01_ESM_CPS.wav",
        region=(12.0, 0.85), kind="sfx", mono=True, trim=-5.0,
        note="a burst of a street jackhammer, for placing a facility",
    ),
    "wreck": dict(
        src="Cinematic Sound Design - Colossal Impacts/Woosh Debris.wav",
        region=(0.00, 1.40), kind="sfx", mono=False, trim=-3.0,
        note="falling debris, for demolition",
    ),
    # --- interface ---------------------------------------------------------
    "click": dict(
        src="Epic Stock Media - Board Game - Sound Set Kit for Tabletop and Digital Games/"
            "UIClick_UI Button Analog Vintage Double Click Neutral Dry Press 11_ESM_BG.wav",
        region=(0.00, 0.28), kind="sfx", mono=True, trim=-6.0,
        note="a vintage button, for picking a tool",
    ),
    "deny": dict(
        src="Cinematic Sound Design - System & UI Feedback Elements/Interface Deny Low Fat Dark.wav",
        region=(0.00, 0.80), kind="sfx", mono=True, trim=-8.0,
        note="for a build the tower refuses",
    ),
    "bad": dict(
        src="Cinematic Sound Design - UI Interaction Elements/Deny Muted.wav",
        region=None, kind="sfx", mono=True, trim=-5.0,
        note="something has gone wrong: cockroaches, an unhappy VIP",
    ),
    # --- events ------------------------------------------------------------
    "fanfare": dict(
        src="Cinematic Sound Design - Hybrid Game & UI Elements/Game Entry Happy Short.wav",
        region=None, kind="sfx", mono=False, trim=0.0,
        note="the tower gains a star",
    ),
    "alarm": dict(
        src="Federico Soler - Effective Trailer Alarms Vol. 2/"
            "EffectiveTrailer_Alarms_Vol2_QuarterNotes_013.wav",
        region=(0.00, 2.60), kind="sfx", mono=False, trim=-4.0,
        note="fire, and the terrorist's threat",
    ),
    "boom": dict(
        src="Federico Soler - Effective Trailer Booms Vol. 2/EffectiveTrailer_Booms_Vol2_011.wav",
        region=(0.00, 2.60), kind="sfx", mono=False, trim=-2.0,
        note="the bomb going off",
    ),
    "treasure": dict(
        src="CB_Sounddesign - Applicable Sounds - Organic UI and Building Games SFX/"
            "UIMisc_Kalimba 3 Up_CB Sounddesign_APPlicable Sounds.wav",
        region=(0.00, 2.00), kind="sfx", mono=False, trim=-2.0,
        note="buried treasure, and the VIP arriving",
    ),
    "church": dict(
        src="Ivo Vicic - Church Bells/"
            "04 Church Bells, Near Distance, In Church Tower-3 Different Bell 02.wav",
        region=(6.0, 7.0), kind="sfx", mono=False, trim=-4.0,
        note="the cathedral, and the wedding",
    ),
    "bells": dict(
        src="344 Audio - Christmas Vol. 1/MAGMisc_Magic Christmas Bells 2_344 Audio_Christmas.wav",
        region=(0.0, 4.0), kind="sfx", mono=False, trim=-3.0,
        note="Santa Claus, on the last night of the year",
    ),
    "sleigh": dict(
        src="344 Audio - Christmas Vol. 1/MAGMisc_Sleigh Movement, Pulling_344 Audio_Christmas.wav",
        region=(0.0, 3.0), kind="sfx", mono=True, trim=-6.0,
        note="the sleigh crossing the sky",
    ),
    "train": dict(
        src="Epic Stock Media - Public Spaces - Basic Transportation Sounds/"
            "TRNElec_Electric Train Passby 02 Long Subway Slow_ESM_CPS.wav",
        region=(4.0, 5.0), kind="sfx", mono=False, trim=-8.0,
        note="a train at the metro station",
    ),
    # --- ambience beds -----------------------------------------------------
    "amb_day": dict(
        src="Sonik Sound Library - Urban Life/"
            "AMBUrbn_Ambience, City, Madrid, Spain, Soft Traffic and Human Activity, "
            "Some Birds-Surround_KSL_KS016.wav",
        region=(20.0, 40.0), kind="bed", mono=False, trim=0.0,
        note="the city outside, daytime",
    ),
    "amb_night": dict(
        src="Epic Stock Media - Public Spaces - Urban Life Exteriors/"
            "AMBUrbn_City Nightlife Ext Street In Reutersplatz German Walla Traffic 01_ESM_CPS.wav",
        region=(30.0, 40.0), kind="bed", mono=False, trim=-3.0,
        note="the city outside, after dark",
    ),
    "amb_lobby": dict(
        src="Epic Stock Media - Public Spaces - Crowds Walla and Everyday Ambiences/"
            "AMBPubl_Metro Station Entrance Hall Dings Walla Footsteps 01 Women Shopping_ESM_CPS.wav",
        region=(8.0, 36.0), kind="bed", mono=False, trim=0.0,
        note="a busy concourse: fades up with the tower's population",
    ),
    "amb_rain": dict(
        src="Jake Fielding - Interior Wind Rain and Storms/"
            "RAINInt_Heavy Rain on Window,  Constant _JF_INT Storm.wav",
        region=(2.0, 26.0), kind="bed", mono=False, trim=-2.0,
        note="rain against the glass",
    ),
    "amb_fire": dict(
        src="Epic Stock Media - Synthesized Nature Loops and Sounds/"
            "FIREBurn_Loop Elements Fire Crackling Crunchy Flame Burn 03_ESM_SNLS.wav",
        region=(0.5, 10.0), kind="bed", mono=True, trim=+3.0,
        note="a fire burning somewhere in the tower",
    ),
}


# ---------------------------------------------------------------------------


FFMPEG = shutil.which("ffmpeg") or "ffmpeg"


def cut(src: Path, region, channels: int) -> np.ndarray:
    """Cut, downmix and resample with ffmpeg, then hand the result to numpy.

    Doing the resampling in scipy looked tidier and blew the interpreter up:
    96 kHz to 44.1 kHz is a 147/320 ratio, and resample_poly on forty seconds
    of stereo at that ratio wanted several gigabytes. ffmpeg streams the same
    job in a fraction of a second, and downmixes surround properly while it is
    at it -- the Madrid ambience is six channels.
    """
    cmd = [FFMPEG, "-v", "error", "-nostdin"]
    if region is not None:
        cmd += ["-ss", "%.3f" % region[0], "-t", "%.3f" % region[1]]
    cmd += ["-i", str(src), "-ac", str(channels), "-ar", str(RATE),
            "-c:a", "pcm_f32le", "-f", "wav", "-y"]
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td) / "cut.wav"
        subprocess.run(cmd + [str(tmp)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        x, _ = sf.read(str(tmp), dtype="float32", always_2d=True)
    return x


def encode(x: np.ndarray, dest: Path, quality: int) -> None:
    """Write the OGG through ffmpeg.

    soundfile can write Vorbis directly and it was doing so, until a
    twenty-four second stereo bed took the interpreter down with an abort and
    no traceback -- libsndfile's encoder gives out somewhere above a few
    seconds of stereo. ffmpeg encodes the same buffer without complaint, and
    lets the quality be chosen per group while it is at it.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td) / "raw.wav"
        sf.write(str(tmp), x, RATE, subtype="FLOAT")
        subprocess.run([FFMPEG, "-v", "error", "-nostdin", "-y", "-i", str(tmp),
                        "-c:a", "libvorbis", "-q:a", str(quality), str(dest)],
                       check=True, stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE)


def fade(x: np.ndarray, secs: float, head: bool = True, tail: bool = True) -> np.ndarray:
    n = min(int(secs * RATE), len(x) // 2)
    if n <= 0:
        return x
    ramp = np.linspace(0.0, 1.0, n)[:, None]
    x = x.copy()
    if head:
        x[:n] *= ramp
    if tail:
        x[-n:] *= ramp[::-1]
    return x


def seamless(x: np.ndarray, xf: float = 2.0) -> np.ndarray:
    """Fold the tail back over the head so the loop point cannot be heard."""
    n = min(int(xf * RATE), len(x) // 3)
    if n <= 0:
        return x
    head, tail = x[:n].copy(), x[-n:].copy()
    ramp = np.linspace(0.0, 1.0, n)[:, None]
    body = x[:-n].copy()
    body[:n] = head * ramp + tail * (1.0 - ramp)
    return body


def match_rms(x: np.ndarray, target: float, trim_db: float) -> np.ndarray:
    rms = float(np.sqrt(np.mean(np.square(x)))) or 1e-9
    x = x * (target / rms) * (10.0 ** (trim_db / 20.0))
    peak = float(np.max(np.abs(x)))
    if peak > 0.985:                       # keep the transients, just tame them
        x = x * (0.985 / peak)
    return x


def build(name: str, spec: dict) -> tuple[str, float]:
    src = BUNDLE / spec["src"]
    if not src.exists():
        raise FileNotFoundError(src)
    x = cut(src, spec.get("region"), 1 if spec.get("mono", False) else 2)

    if spec["kind"] == "bed":
        x = seamless(x, 2.0)
        x = match_rms(x, RMS_BED, spec.get("trim", 0.0))
        sub = "ambience"
        quality = 4
    else:
        x = fade(x, 0.006, head=True, tail=False)
        x = fade(x, 0.05, head=False, tail=True)
        x = match_rms(x, RMS_ONESHOT, spec.get("trim", 0.0))
        sub = "sfx"
        quality = 5

    out_dir = OUT / sub
    out_dir.mkdir(parents=True, exist_ok=True)
    dest = out_dir / f"{name}.ogg"
    encode(x, dest, quality)
    return str(dest.relative_to(OUT.parent.parent)), len(x) / RATE


CREDITS_HEAD = """# Audio credits

Every sound effect and every ambience bed in Grattacielo was cut from the
**Sonniss GDC Game Audio Bundle**, which the project owner holds. The bundle's
licence permits modification and commercial use in games and asks for no
attribution; this file exists anyway, because in a year nobody will remember
which recording a two-second lift chime came out of, and because a file whose
provenance is unknown cannot safely be shipped.

Regions are given as start-end in seconds within the source recording. Each
clip was downmixed, resampled to 44.1 kHz, level-matched on RMS against the
others in its group, and encoded to Ogg Vorbis. `tools/make_audio.py` does all
of that and can regenerate every file from the bundle; this list is written by
the same tool, so it cannot drift from what is on disk.

The music is not from the bundle -- the bundle is an effects library with no
music in it. The three loops in `music/` are synthesized by
`tools/make_music.py`; see its docstring for what they are and why.

"""


def write_credits() -> None:
    out = [CREDITS_HEAD]
    for group, kind in (("Sound effects", "sfx"), ("Ambience beds", "bed")):
        out.append("## " + group + "\n")
        for name, spec in SPEC.items():
            if spec["kind"] != kind:
                continue
            region = spec.get("region")
            where = ("whole file" if region is None
                     else "%.2f-%.2fs" % (region[0], region[0] + region[1]))
            out.append("- `%s.ogg` -- %s.\n  Source: `%s`, %s.\n"
                       % (name, spec["note"], spec["src"], where))
        out.append("")
    (OUT / "CREDITS.md").write_text("\n".join(out), encoding="utf-8")
    print("  wrote " + str(OUT / "CREDITS.md"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--credits", action="store_true",
                    help="write assets/audio/CREDITS.md and stop")
    args = ap.parse_args()

    if args.credits:
        OUT.mkdir(parents=True, exist_ok=True)
        write_credits()
        return 0

    if args.list:
        for name, spec in SPEC.items():
            print(f"{name:12s} {spec['kind']:4s} {spec['note']}")
        return 0

    if not BUNDLE.exists():
        print(f"Sonniss bundle not found at {BUNDLE}", file=sys.stderr)
        return 1

    names = args.only or list(SPEC)
    total = 0
    for name in names:
        if name not in SPEC:
            print(f"unknown sound {name!r}", file=sys.stderr)
            return 1
        try:
            rel, secs = build(name, SPEC[name])
        except FileNotFoundError as e:
            print(f"  MISSING SOURCE for {name}: {e}", file=sys.stderr)
            continue
        size = (OUT.parent.parent / rel).stat().st_size
        total += size
        print(f"  {name:12s} {secs:6.2f}s  {size / 1024:7.1f} kB  {rel}")
    print(f"total {total / 1024:.1f} kB")
    write_credits()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
