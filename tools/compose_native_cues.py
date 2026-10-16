"""Render original native game cues. No external samples."""

from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / "godot" / "assets" / "audio"
RATE = 22050


def write(name, data):
    ROOT.mkdir(parents=True, exist_ok=True)
    peak = max(1, np.max(np.abs(data)))
    data = np.clip(data / peak, -1, 1)
    with wave.open(str(ROOT / (name + ".wav")), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes((data * 29000).astype("<i2").tobytes())


def pluck(note, duration=3.0, brightness=1):
    t = np.arange(int(RATE * duration)) / RATE
    f = 440 * 2 ** ((note - 69) / 12)
    tone = sum(
        np.sin(2 * np.pi * f * n * t + 0.08 * np.sin(2 * np.pi * 3 * t))
        * np.exp(-t * (1.8 + n * 0.65))
        * brightness
        / n**1.55
        for n in range(1, 7)
    )
    return tone * (1 - np.exp(-t * 95))


def add(dst, sound, start, gain):
    start = int(start * RATE)
    count = min(len(sound), len(dst) - start)
    if count > 0:
        dst[start : start + count] += sound[:count] * gain


def cues():
    rng = np.random.default_rng(11)
    for name, notes in {
        "upgrade": [74, 77, 81, 86],
        "shrine": [69, 74, 81],
        "victory": [74, 77, 81, 84, 86],
        "defeat": [69, 65, 62],
        "boss": [38, 45, 50],
        "heal": [79, 81],
    }.items():
        data = np.zeros(int((0.8 + len(notes) * 0.12) * RATE))
        for i, note in enumerate(notes):
            add(data, pluck(note, 0.8), i * 0.12, 0.45)
        write(name, data)
    t = np.arange(int(0.22 * RATE)) / RATE
    write(
        "cast",
        (rng.random(len(t)) - 0.5) * np.exp(-t * 38) * 0.18
        + np.sin(2 * np.pi * (620 * t - 800 * t * t)) * np.exp(-t * 30) * 0.12,
    )
    write(
        "dash",
        (rng.random(len(t)) - 0.5) * np.sin(np.pi * t / 0.22) ** 2 * np.exp(-t * 13),
    )
    write(
        "hit",
        (rng.random(len(t)) - 0.5) * np.exp(-t * 50)
        + np.sin(2 * np.pi * 125 * t) * np.exp(-t * 35),
    )
    write(
        "hurt",
        np.sin(2 * np.pi * (95 * t - 80 * t * t)) * np.exp(-t * 12)
        + (rng.random(len(t)) - 0.5) * np.exp(-t * 23),
    )
    tt = np.arange(int(0.8 * RATE)) / RATE
    write(
        "pulse",
        np.sin(2 * np.pi * (150 * tt + 200 * tt * tt)) * np.exp(-tt * 6)
        + (rng.random(len(tt)) - 0.5) * np.exp(-tt * 12) * 0.2,
    )
    for name, duration, frequency, sweep, noise, decay in [
        ("swing", 0.20, 310, -210, 0.50, 18),
        ("hammer", 0.32, 90, -50, 0.30, 16),
        ("needle", 0.12, 1050, -300, 0.13, 45),
        ("wheel", 0.28, 680, -180, 0.15, 15),
        ("sand", 0.25, 1250, 180, 0.40, 20),
        ("bow", 0.18, 480, -240, 0.25, 24),
        ("flame", 0.42, 85, -35, 0.65, 11),
        ("ice", 0.38, 1600, -650, 0.15, 12),
        ("bell", 0.95, 176, 0, 0.01, 5),
    ]:
        time = np.arange(int(duration * RATE)) / RATE
        attack = 1 - np.exp(-time * 300)
        envelope = attack * np.exp(-time * decay)
        phase = 2 * np.pi * (frequency * time + sweep * time * time)
        body = np.sin(phase) * 0.22
        if name in ("wheel", "ice", "bell"):
            body += np.sin(phase * 2.71) * 0.09 + np.sin(phase * 4.13) * 0.04
        grain = rng.uniform(-1, 1, len(time)) * noise
        if name in ("swing", "sand", "bow"):
            grain = np.concatenate(([0.0], np.diff(grain))) * 0.5
        write(name, (body + grain) * envelope)


if __name__ == "__main__":
    cues()
    print("Rendered 20 original native game cues.")
