"""Original chapter arrangements and dry print-era cues, with no sampled music."""
from pathlib import Path
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / "godot/assets/audio"
RATE = 22050
RNG = np.random.default_rng(1703)


def frequency(note):
    return 440 * 2 ** ((note - 69) / 12)


def pluck(note, duration=2.6, muted=False):
    t = np.arange(int(duration * RATE)) / RATE
    f = frequency(note)
    result = np.zeros_like(t)
    for harmonic in range(1, 9):
        detune = 1 + (harmonic - 1) ** 2 * 0.00010
        result += np.cos(2 * np.pi * f * harmonic * detune * t) * np.exp(-t * (1.0 + harmonic * (0.9 if muted else 0.38))) / harmonic ** 1.3
    return result * (1 - np.exp(-t * 230))


def flute(note, duration=1.5):
    t = np.arange(int(duration * RATE)) / RATE
    f = frequency(note)
    vibrato = 0.012 * np.sin(2 * np.pi * 4.8 * t) * np.minimum(1, t * 2)
    phase = 2 * np.pi * f * t + vibrato
    breath = np.convolve(RNG.standard_normal(len(t)), np.ones(11) / 11, mode="same")
    tone = np.sin(phase) + 0.22 * np.sin(phase * 2) + 0.07 * np.sin(phase * 3) + breath * 0.05
    return tone * (1 - np.exp(-t * 22)) * np.minimum(1, np.maximum(0, (duration - t) / 0.22)) * np.exp(-t * 0.45)


def bell(note, duration=4.0):
    t = np.arange(int(duration * RATE)) / RATE
    return sum(np.sin(2 * np.pi * frequency(note) * ratio * t) * np.exp(-t * decay) * gain for ratio, decay, gain in [(1, 0.8, 0.6), (2.71, 1.5, 0.22), (4.09, 2.8, 0.15)]) * (1 - np.exp(-t * 90))


def drum(high=False):
    duration = 0.13 if high else 0.38
    t = np.arange(int(duration * RATE)) / RATE
    noise = RNG.standard_normal(len(t))
    if high:
        return (np.sin(2 * np.pi * 1350 * t) * 0.7 + np.sin(2 * np.pi * 1780 * t) * 0.2 + noise * 0.05) * np.exp(-t * 60) * (1 - np.exp(-t * 700))
    return (np.sin(2 * np.pi * (85 * t - 33 * t ** 2)) + noise * 0.07) * np.exp(-t * 12) * (1 - np.exp(-t * 300))


def add(mix, sound, seconds, gain, pan=0.0):
    offset = round(seconds * RATE) % len(mix)
    stereo = sound[:, None] * np.array([np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)])[None, :] * gain
    for start in range(0, len(stereo), len(mix)):
        chunk = stereo[start:start + len(mix)]
        count = min(len(chunk), len(mix) - offset)
        mix[offset:offset + count] += chunk[:count]
        if count < len(chunk):
            mix[:len(chunk) - count] += chunk[count:]


def write(name, mix, loop=True):
    if loop:
        bridge = np.linspace(0, 1, 128)[:, None]
        mix[-128:] = mix[-128:] * (1 - bridge) + mix[0] * bridge
    peak = np.max(np.abs(mix))
    mix *= min(1, 0.72 / max(peak, 1e-6))
    with wave.open(str(ROOT / (name + ".wav")), "wb") as file:
        file.setnchannels(2)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes((mix * 32767).astype("<i2").tobytes())
    return {"track": name, "seconds": round(len(mix) / RATE, 3), "peak": round(float(np.max(np.abs(mix))), 4), "rms": round(float(np.sqrt(np.mean(mix ** 2))), 4), "loop_boundary_step": round(float(np.max(np.abs(mix[0] - mix[-1]))), 6) if loop else None}


# Four-note phrases use an original D pentatonic motif, answered rather than
# simply repeated. Each chapter varies orchestration, rhythm and register.
PHRASES = [
    [74, 77, 79, 81], [79, 77, 74, 72], [69, 72, 74, 77], [79, 74, 72, 69],
    [74, 81, 84, 81], [79, 77, 74, 72], [77, 79, 81, 86], [84, 81, 79, 74],
    [69, 74, 77, 72], [74, 79, 77, 74], [81, 79, 74, 72], [77, 74, 72, 69],
    [74, 77, 81, 79], [84, 81, 79, 77], [79, 77, 74, 72], [74, 72, 69, 74],
]


def score(name, tempo, mood):
    beat = 60 / tempo
    mix = np.zeros((round(64 * beat * RATE), 2))
    for bar, phrase in enumerate(PHRASES):
        bass = [50, 48, 53, 45][(bar // 2) % 4]
        start = bar * 4 * beat
        add(mix, pluck(bass, 4 * beat, True), start, 0.13, -0.12)
        add(mix, pluck(bass + 12, 2.5 * beat, True), start + 2.5 * beat, 0.055, 0.2)
        for i, note in enumerate(phrase):
            timing = [0, 1.5, 2.5, 3.25][i]
            if mood in ["night", "temple"] and i == 3 and bar % 2 == 1:
                continue
            lead = flute(note, 1.7 * beat) if mood == "fox" or (mood == "night" and bar >= 8) else pluck(note, 2.8 * beat)
            gain = 0.10 if mood == "night" else 0.13
            add(mix, lead, start + timing * beat, gain, -0.35)
            add(mix, lead, start + timing * beat + 0.27, gain * 0.18, 0.45)
            if bar >= 8 and i % 2 == 0:
                add(mix, pluck(note + 12, beat * 1.8, True), start + (timing + 0.5) * beat, 0.038, 0.5)
        if bar % 4 == 0:
            add(mix, bell(bass + (12 if mood == "temple" else 24)), start, 0.095 if mood == "temple" else 0.04, 0.15)
        if mood != "night":
            for i in range(4):
                add(mix, drum(), start + i * beat, 0.13 if i in (0, 2) and mood in ["tower", "boss"] else 0.035, 0)
                if mood in ["market", "tower", "boss"]:
                    add(mix, drum(True), start + (i + 0.5) * beat, 0.032 if mood == "market" else 0.055, 0.4 if i % 2 else -0.4)
            if mood == "boss":
                for timing in (3.0, 3.5, 3.75):
                    add(mix, drum(), start + timing * beat, 0.1, 0)
    # Every tail and early reflection wraps to the next cycle, preserving the
    # phrase and reverberation at the loop seam without a silent restart.
    return write(name, mix)


if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    report = [score(*spec) for spec in [("night-print", 72, "night"), ("battle-market", 96, "market"), ("battle-fox", 84, "fox"), ("battle-temple", 88, "temple"), ("battle-tower", 104, "tower"), ("battle-boss", 112, "boss")]]
    cue = np.zeros((round(0.18 * RATE), 2))
    add(cue, drum(True), 0, 0.9)
    report.append(write("ui-print", cue, False))
    pickup = np.zeros((round(0.18 * RATE), 2))
    ping = bell(86, 0.18)
    ping *= np.exp(-np.arange(len(ping)) / RATE * 22) * np.linspace(1, 0, len(ping))
    add(pickup, ping, 0, 0.5)
    report.append(write("pickup-print", pickup, False))
    (ROOT / "score_record.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))
