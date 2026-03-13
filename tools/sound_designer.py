#!/usr/bin/env python3
"""
Sound Designer — generates sound effects from raw synthesized audio bytes.

Uses only Python standard library (struct, math, random, wave).
Outputs .wav files natively. Converts to .mp3/.ogg if ffmpeg is on PATH.

Usage:
    python3 tools/sound_designer.py                    # generate all presets
    python3 tools/sound_designer.py --list             # list available presets
    python3 tools/sound_designer.py --preset sword_hit # generate one preset
    python3 tools/sound_designer.py --format ogg       # output as ogg (needs ffmpeg)
    python3 tools/sound_designer.py --outdir assets/sfx/

Waveform primitives: sine, square, sawtooth, triangle, white noise, pink noise.
Effects: ADSR envelope, vibrato, pitch sweep, low-pass filter, distortion, reverb.
Mixer: layer multiple sounds with offset, volume, and pan.
"""

import struct
import math
import random
import wave
import os
import subprocess
import argparse
import sys
from dataclasses import dataclass, field
from typing import List, Optional, Callable

SAMPLE_RATE = 44100
BIT_DEPTH = 16
MAX_AMP = 32767  # 16-bit signed max


# ---------------------------------------------------------------------------
# Core waveform generators — return float samples in [-1.0, 1.0]
# ---------------------------------------------------------------------------

def sine_wave(freq: float, duration: float, phase: float = 0.0) -> List[float]:
    n = int(SAMPLE_RATE * duration)
    return [math.sin(2.0 * math.pi * freq * (i / SAMPLE_RATE) + phase) for i in range(n)]


def square_wave(freq: float, duration: float, duty: float = 0.5) -> List[float]:
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = (freq * i / SAMPLE_RATE) % 1.0
        samples.append(1.0 if t < duty else -1.0)
    return samples


def sawtooth_wave(freq: float, duration: float) -> List[float]:
    n = int(SAMPLE_RATE * duration)
    return [2.0 * ((freq * i / SAMPLE_RATE) % 1.0) - 1.0 for i in range(n)]


def triangle_wave(freq: float, duration: float) -> List[float]:
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = (freq * i / SAMPLE_RATE) % 1.0
        samples.append(4.0 * abs(t - 0.5) - 1.0)
    return samples


def white_noise(duration: float, seed: Optional[int] = None) -> List[float]:
    rng = random.Random(seed)
    n = int(SAMPLE_RATE * duration)
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def pink_noise(duration: float, seed: Optional[int] = None) -> List[float]:
    """Voss-McCartney algorithm for pink noise."""
    rng = random.Random(seed)
    n = int(SAMPLE_RATE * duration)
    num_rows = 16
    rows = [0.0] * num_rows
    running_sum = 0.0
    max_val = 0.0
    samples = []
    for i in range(n):
        # Find lowest set bit
        idx = 0
        tmp = i
        while tmp > 0 and (tmp & 1) == 0 and idx < num_rows - 1:
            tmp >>= 1
            idx += 1
        running_sum -= rows[idx]
        rows[idx] = rng.uniform(-1.0, 1.0)
        running_sum += rows[idx]
        val = running_sum + rng.uniform(-1.0, 1.0)
        samples.append(val)
        if abs(val) > max_val:
            max_val = abs(val)
    # Normalize
    if max_val > 0:
        samples = [s / max_val for s in samples]
    return samples


def silence(duration: float) -> List[float]:
    return [0.0] * int(SAMPLE_RATE * duration)


# ---------------------------------------------------------------------------
# Effects processors
# ---------------------------------------------------------------------------

@dataclass
class ADSR:
    attack: float = 0.01   # seconds
    decay: float = 0.05
    sustain: float = 0.7   # level 0-1
    release: float = 0.1

    def apply(self, samples: List[float]) -> List[float]:
        n = len(samples)
        a_end = int(self.attack * SAMPLE_RATE)
        d_end = a_end + int(self.decay * SAMPLE_RATE)
        r_start = max(0, n - int(self.release * SAMPLE_RATE))
        result = []
        for i in range(n):
            if i < a_end:
                env = i / max(a_end, 1)
            elif i < d_end:
                t = (i - a_end) / max(d_end - a_end, 1)
                env = 1.0 - t * (1.0 - self.sustain)
            elif i < r_start:
                env = self.sustain
            else:
                t = (i - r_start) / max(n - r_start, 1)
                env = self.sustain * (1.0 - t)
            result.append(samples[i] * env)
        return result


def apply_volume(samples: List[float], volume: float) -> List[float]:
    return [s * volume for s in samples]


def pitch_sweep(freq_start: float, freq_end: float, duration: float) -> List[float]:
    """Sine wave with linear pitch sweep."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / max(n - 1, 1)
        freq = freq_start + (freq_end - freq_start) * t
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        samples.append(math.sin(phase))
    return samples


def vibrato(samples: List[float], rate: float = 5.0, depth: float = 0.005) -> List[float]:
    """Apply vibrato (pitch modulation) via variable delay."""
    n = len(samples)
    result = []
    for i in range(n):
        delay = depth * SAMPLE_RATE * math.sin(2.0 * math.pi * rate * i / SAMPLE_RATE)
        idx = i + delay
        idx_int = int(idx)
        frac = idx - idx_int
        if 0 <= idx_int < n - 1:
            result.append(samples[idx_int] * (1.0 - frac) + samples[idx_int + 1] * frac)
        elif 0 <= idx_int < n:
            result.append(samples[idx_int])
        else:
            result.append(0.0)
    return result


def low_pass_filter(samples: List[float], cutoff: float = 2000.0) -> List[float]:
    """Simple one-pole low-pass filter."""
    rc = 1.0 / (2.0 * math.pi * cutoff)
    dt = 1.0 / SAMPLE_RATE
    alpha = dt / (rc + dt)
    result = [samples[0]]
    for i in range(1, len(samples)):
        result.append(result[-1] + alpha * (samples[i] - result[-1]))
    return result


def high_pass_filter(samples: List[float], cutoff: float = 500.0) -> List[float]:
    """Simple one-pole high-pass filter."""
    rc = 1.0 / (2.0 * math.pi * cutoff)
    dt = 1.0 / SAMPLE_RATE
    alpha = rc / (rc + dt)
    result = [samples[0]]
    for i in range(1, len(samples)):
        result.append(alpha * (result[-1] + samples[i] - samples[i - 1]))
    return result


def distortion(samples: List[float], gain: float = 2.0) -> List[float]:
    """Soft clipping distortion via tanh."""
    return [math.tanh(s * gain) for s in samples]


def simple_reverb(samples: List[float], delay_ms: float = 80.0, decay: float = 0.3,
                  taps: int = 4) -> List[float]:
    """Simple comb-filter reverb."""
    result = list(samples)
    for tap in range(1, taps + 1):
        delay_samples = int(delay_ms * tap * SAMPLE_RATE / 1000.0)
        gain = decay ** tap
        for i in range(delay_samples, len(result)):
            result[i] += samples[i - delay_samples] * gain
    # Normalize if clipping
    peak = max(abs(s) for s in result) if result else 1.0
    if peak > 1.0:
        result = [s / peak for s in result]
    return result


def fade_in(samples: List[float], duration: float = 0.01) -> List[float]:
    n = min(int(duration * SAMPLE_RATE), len(samples))
    result = list(samples)
    for i in range(n):
        result[i] *= i / max(n, 1)
    return result


def fade_out(samples: List[float], duration: float = 0.05) -> List[float]:
    n = min(int(duration * SAMPLE_RATE), len(samples))
    result = list(samples)
    total = len(result)
    for i in range(n):
        result[total - 1 - i] *= i / max(n, 1)
    return result


# ---------------------------------------------------------------------------
# Mixer — layer multiple sample arrays
# ---------------------------------------------------------------------------

@dataclass
class Layer:
    samples: List[float]
    offset: float = 0.0     # seconds delay before this layer starts
    volume: float = 1.0

    def get_offset_samples(self) -> int:
        return int(self.offset * SAMPLE_RATE)


def mix_layers(layers: List[Layer]) -> List[float]:
    """Mix multiple layers into one buffer."""
    total_len = 0
    for layer in layers:
        end = layer.get_offset_samples() + len(layer.samples)
        if end > total_len:
            total_len = end

    mixed = [0.0] * total_len
    for layer in layers:
        offset = layer.get_offset_samples()
        for i, s in enumerate(layer.samples):
            mixed[offset + i] += s * layer.volume

    # Normalize
    peak = max((abs(s) for s in mixed), default=1.0)
    if peak > 1.0:
        mixed = [s / peak for s in mixed]
    return mixed


# ---------------------------------------------------------------------------
# WAV writer
# ---------------------------------------------------------------------------

def samples_to_bytes(samples: List[float]) -> bytes:
    """Convert float samples [-1,1] to 16-bit PCM bytes."""
    data = bytearray()
    for s in samples:
        clamped = max(-1.0, min(1.0, s))
        val = int(clamped * MAX_AMP)
        data += struct.pack('<h', val)
    return bytes(data)


def write_wav(filepath: str, samples: List[float], channels: int = 1):
    """Write samples to a WAV file."""
    os.makedirs(os.path.dirname(filepath) or '.', exist_ok=True)
    with wave.open(filepath, 'w') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(samples_to_bytes(samples))
    print(f"  wrote: {filepath} ({len(samples) / SAMPLE_RATE:.2f}s, {os.path.getsize(filepath)} bytes)")


def convert_format(wav_path: str, target_format: str) -> Optional[str]:
    """Convert WAV to target format using ffmpeg. Returns output path or None."""
    out_path = wav_path.rsplit('.', 1)[0] + '.' + target_format
    try:
        subprocess.run(
            ['ffmpeg', '-y', '-i', wav_path, '-q:a', '2', out_path],
            capture_output=True, check=True
        )
        os.remove(wav_path)
        print(f"  converted: {out_path}")
        return out_path
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"  [warn] ffmpeg not found or failed — keeping .wav")
        return None


# ---------------------------------------------------------------------------
# Sound effect presets — game-relevant
# ---------------------------------------------------------------------------

def sfx_ui_click() -> List[float]:
    """Short snappy UI click."""
    tone = sine_wave(1200, 0.04)
    tone = ADSR(attack=0.001, decay=0.02, sustain=0.0, release=0.02).apply(tone)
    click = white_noise(0.01, seed=42)
    click = ADSR(attack=0.001, decay=0.005, sustain=0.0, release=0.005).apply(click)
    click = apply_volume(click, 0.3)
    click = high_pass_filter(click, 3000)
    return mix_layers([Layer(tone, volume=0.7), Layer(click, volume=0.4)])


def sfx_ui_hover() -> List[float]:
    """Soft hover sound."""
    tone = sine_wave(800, 0.03)
    return ADSR(attack=0.002, decay=0.015, sustain=0.0, release=0.015).apply(tone)


def sfx_ui_confirm() -> List[float]:
    """Two-tone confirm chime."""
    t1 = sine_wave(600, 0.08)
    t1 = ADSR(attack=0.002, decay=0.03, sustain=0.3, release=0.03).apply(t1)
    t2 = sine_wave(900, 0.12)
    t2 = ADSR(attack=0.002, decay=0.04, sustain=0.3, release=0.05).apply(t2)
    return mix_layers([Layer(t1, volume=0.6), Layer(t2, offset=0.06, volume=0.7)])


def sfx_ui_cancel() -> List[float]:
    """Descending cancel tone."""
    sweep = pitch_sweep(600, 300, 0.15)
    return ADSR(attack=0.002, decay=0.05, sustain=0.4, release=0.06).apply(sweep)


def sfx_sword_hit() -> List[float]:
    """Metallic sword impact."""
    impact = white_noise(0.08, seed=10)
    impact = high_pass_filter(impact, 2000)
    impact = ADSR(attack=0.001, decay=0.03, sustain=0.2, release=0.04).apply(impact)
    ring = sine_wave(2800, 0.2)
    ring2 = sine_wave(4200, 0.15)
    ring = ADSR(attack=0.001, decay=0.08, sustain=0.1, release=0.1).apply(ring)
    ring2 = ADSR(attack=0.001, decay=0.06, sustain=0.05, release=0.08).apply(ring2)
    body = low_pass_filter(white_noise(0.05, seed=11), 800)
    body = ADSR(attack=0.001, decay=0.02, sustain=0.0, release=0.02).apply(body)
    return mix_layers([
        Layer(impact, volume=0.8),
        Layer(ring, volume=0.4),
        Layer(ring2, volume=0.25),
        Layer(body, volume=0.5),
    ])


def sfx_sword_swing() -> List[float]:
    """Whooshing sword swing."""
    sweep = pitch_sweep(200, 800, 0.15)
    noise = white_noise(0.2, seed=20)
    noise = low_pass_filter(noise, 1500)
    noise = ADSR(attack=0.02, decay=0.06, sustain=0.3, release=0.08).apply(noise)
    sweep = ADSR(attack=0.01, decay=0.05, sustain=0.2, release=0.06).apply(sweep)
    return mix_layers([Layer(sweep, volume=0.3), Layer(noise, volume=0.6)])


def sfx_arrow_fire() -> List[float]:
    """Crossbow/bow release twang + whoosh."""
    twang = sine_wave(350, 0.06)
    twang2 = sine_wave(700, 0.04)
    twang = ADSR(attack=0.001, decay=0.03, sustain=0.0, release=0.02).apply(twang)
    twang2 = ADSR(attack=0.001, decay=0.02, sustain=0.0, release=0.015).apply(twang2)
    whoosh = white_noise(0.15, seed=30)
    whoosh = low_pass_filter(whoosh, 2000)
    whoosh = ADSR(attack=0.01, decay=0.05, sustain=0.2, release=0.06).apply(whoosh)
    snap = white_noise(0.02, seed=31)
    snap = high_pass_filter(snap, 4000)
    snap = ADSR(attack=0.001, decay=0.01, sustain=0.0, release=0.01).apply(snap)
    return mix_layers([
        Layer(snap, volume=0.6),
        Layer(twang, offset=0.005, volume=0.5),
        Layer(twang2, offset=0.005, volume=0.3),
        Layer(whoosh, offset=0.02, volume=0.5),
    ])


def sfx_arquebus_fire() -> List[float]:
    """Gunpowder weapon blast."""
    bang = white_noise(0.06, seed=40)
    bang = distortion(bang, gain=3.0)
    bang = ADSR(attack=0.001, decay=0.02, sustain=0.3, release=0.03).apply(bang)
    boom = sine_wave(80, 0.15)
    boom = ADSR(attack=0.001, decay=0.05, sustain=0.4, release=0.08).apply(boom)
    crackle = white_noise(0.3, seed=41)
    crackle = high_pass_filter(crackle, 3000)
    crackle = ADSR(attack=0.01, decay=0.1, sustain=0.15, release=0.15).apply(crackle)
    echo = simple_reverb(bang, delay_ms=60, decay=0.4, taps=5)
    return mix_layers([
        Layer(bang, volume=0.9),
        Layer(boom, volume=0.7),
        Layer(crackle, offset=0.02, volume=0.35),
        Layer(echo, offset=0.05, volume=0.3),
    ])


def sfx_heal() -> List[float]:
    """Magical healing shimmer."""
    tone1 = sine_wave(523, 0.3)  # C5
    tone2 = sine_wave(659, 0.3)  # E5
    tone3 = sine_wave(784, 0.3)  # G5
    tone1 = ADSR(attack=0.05, decay=0.1, sustain=0.5, release=0.1).apply(tone1)
    tone2 = ADSR(attack=0.08, decay=0.1, sustain=0.5, release=0.1).apply(tone2)
    tone3 = ADSR(attack=0.11, decay=0.1, sustain=0.5, release=0.1).apply(tone3)
    shimmer = white_noise(0.4, seed=50)
    shimmer = low_pass_filter(shimmer, 4000)
    shimmer = high_pass_filter(shimmer, 2000)
    shimmer = ADSR(attack=0.05, decay=0.1, sustain=0.3, release=0.15).apply(shimmer)
    return mix_layers([
        Layer(tone1, volume=0.4),
        Layer(tone2, offset=0.06, volume=0.4),
        Layer(tone3, offset=0.12, volume=0.4),
        Layer(shimmer, volume=0.2),
    ])


def sfx_fire_spell() -> List[float]:
    """Alchemical fire / fireball whoosh + crackle."""
    whoosh = pitch_sweep(100, 600, 0.3)
    whoosh = ADSR(attack=0.02, decay=0.1, sustain=0.5, release=0.15).apply(whoosh)
    crackle = white_noise(0.5, seed=60)
    crackle = low_pass_filter(crackle, 3000)
    crackle = ADSR(attack=0.05, decay=0.15, sustain=0.4, release=0.2).apply(crackle)
    rumble = sine_wave(60, 0.4)
    rumble = ADSR(attack=0.02, decay=0.1, sustain=0.5, release=0.15).apply(rumble)
    sizzle = white_noise(0.3, seed=61)
    sizzle = high_pass_filter(sizzle, 5000)
    sizzle = ADSR(attack=0.1, decay=0.1, sustain=0.2, release=0.08).apply(sizzle)
    return mix_layers([
        Layer(whoosh, volume=0.6),
        Layer(crackle, volume=0.5),
        Layer(rumble, volume=0.4),
        Layer(sizzle, offset=0.1, volume=0.25),
    ])


def sfx_shield_block() -> List[float]:
    """Wooden/metal shield impact."""
    thud = sine_wave(120, 0.08)
    thud = ADSR(attack=0.001, decay=0.03, sustain=0.2, release=0.04).apply(thud)
    impact = white_noise(0.05, seed=70)
    impact = low_pass_filter(impact, 1500)
    impact = ADSR(attack=0.001, decay=0.02, sustain=0.0, release=0.02).apply(impact)
    rattle = white_noise(0.12, seed=71)
    rattle = high_pass_filter(rattle, 2000)
    rattle = low_pass_filter(rattle, 5000)
    rattle = ADSR(attack=0.005, decay=0.04, sustain=0.15, release=0.06).apply(rattle)
    return mix_layers([
        Layer(thud, volume=0.7),
        Layer(impact, volume=0.6),
        Layer(rattle, offset=0.01, volume=0.35),
    ])


def sfx_death() -> List[float]:
    """Unit death — low descending tone + thud."""
    fall = pitch_sweep(400, 100, 0.3)
    fall = ADSR(attack=0.01, decay=0.1, sustain=0.4, release=0.15).apply(fall)
    thud = sine_wave(60, 0.15)
    thud = ADSR(attack=0.001, decay=0.05, sustain=0.2, release=0.08).apply(thud)
    body = white_noise(0.1, seed=80)
    body = low_pass_filter(body, 500)
    body = ADSR(attack=0.001, decay=0.04, sustain=0.0, release=0.05).apply(body)
    return mix_layers([
        Layer(fall, volume=0.5),
        Layer(thud, offset=0.2, volume=0.6),
        Layer(body, offset=0.2, volume=0.4),
    ])


def sfx_march_step() -> List[float]:
    """Single marching footstep."""
    thud = sine_wave(80, 0.06)
    thud = ADSR(attack=0.001, decay=0.02, sustain=0.0, release=0.03).apply(thud)
    scuff = white_noise(0.04, seed=90)
    scuff = low_pass_filter(scuff, 1200)
    scuff = ADSR(attack=0.001, decay=0.015, sustain=0.0, release=0.02).apply(scuff)
    return mix_layers([Layer(thud, volume=0.6), Layer(scuff, offset=0.005, volume=0.4)])


def sfx_coin() -> List[float]:
    """Coin clink for shop/economy."""
    clink1 = sine_wave(3500, 0.06)
    clink1 = ADSR(attack=0.001, decay=0.02, sustain=0.1, release=0.03).apply(clink1)
    clink2 = sine_wave(4200, 0.05)
    clink2 = ADSR(attack=0.001, decay=0.015, sustain=0.05, release=0.025).apply(clink2)
    tink = sine_wave(5500, 0.03)
    tink = ADSR(attack=0.001, decay=0.01, sustain=0.0, release=0.015).apply(tink)
    return mix_layers([
        Layer(clink1, volume=0.5),
        Layer(clink2, offset=0.03, volume=0.4),
        Layer(tink, offset=0.05, volume=0.3),
    ])


def sfx_victory_fanfare() -> List[float]:
    """Short triumphant three-note fanfare."""
    # C major arpeggio: C5 → E5 → G5 → C6
    notes = [
        (523.25, 0.15, 0.0),   # C5
        (659.25, 0.15, 0.12),  # E5
        (783.99, 0.15, 0.24),  # G5
        (1046.5, 0.35, 0.36),  # C6 (sustained)
    ]
    layers = []
    for freq, dur, offset in notes:
        tone = sine_wave(freq, dur)
        tone = ADSR(attack=0.01, decay=0.04, sustain=0.6, release=0.06).apply(tone)
        layers.append(Layer(tone, offset=offset, volume=0.5))
    # Harmony on final note
    harmony = sine_wave(783.99, 0.35)
    harmony = ADSR(attack=0.01, decay=0.04, sustain=0.5, release=0.08).apply(harmony)
    layers.append(Layer(harmony, offset=0.36, volume=0.3))
    return mix_layers(layers)


def sfx_defeat() -> List[float]:
    """Low somber defeat tone."""
    tone1 = sine_wave(220, 0.4)  # A3
    tone2 = sine_wave(185, 0.5)  # F#3
    tone1 = ADSR(attack=0.03, decay=0.1, sustain=0.5, release=0.15).apply(tone1)
    tone2 = ADSR(attack=0.05, decay=0.1, sustain=0.5, release=0.2).apply(tone2)
    rumble = pink_noise(0.6, seed=100)
    rumble = low_pass_filter(rumble, 200)
    rumble = ADSR(attack=0.05, decay=0.2, sustain=0.3, release=0.2).apply(rumble)
    return mix_layers([
        Layer(tone1, volume=0.4),
        Layer(tone2, offset=0.25, volume=0.4),
        Layer(rumble, volume=0.25),
    ])


def sfx_text_blip() -> List[float]:
    """Typewriter text reveal blip."""
    blip = sine_wave(600, 0.025)
    return ADSR(attack=0.001, decay=0.01, sustain=0.0, release=0.01).apply(blip)


def sfx_turn_start() -> List[float]:
    """Turn/phase start notification."""
    tone = sine_wave(440, 0.15)
    tone = ADSR(attack=0.005, decay=0.05, sustain=0.4, release=0.06).apply(tone)
    high = sine_wave(880, 0.1)
    high = ADSR(attack=0.005, decay=0.03, sustain=0.2, release=0.04).apply(high)
    return mix_layers([Layer(tone, volume=0.5), Layer(high, offset=0.05, volume=0.3)])


def sfx_pike_thrust() -> List[float]:
    """Pike/spear thrust — sharp quick impact."""
    thrust = pitch_sweep(300, 800, 0.06)
    thrust = ADSR(attack=0.001, decay=0.02, sustain=0.1, release=0.03).apply(thrust)
    hit = white_noise(0.04, seed=110)
    hit = low_pass_filter(hit, 2000)
    hit = ADSR(attack=0.001, decay=0.015, sustain=0.0, release=0.02).apply(hit)
    ring = sine_wave(1600, 0.1)
    ring = ADSR(attack=0.001, decay=0.04, sustain=0.1, release=0.05).apply(ring)
    return mix_layers([
        Layer(thrust, volume=0.6),
        Layer(hit, volume=0.5),
        Layer(ring, offset=0.02, volume=0.25),
    ])


def sfx_morale_boost() -> List[float]:
    """Inspiration / morale boost — ascending shimmer."""
    sweep = pitch_sweep(400, 1200, 0.25)
    sweep = ADSR(attack=0.02, decay=0.08, sustain=0.5, release=0.1).apply(sweep)
    shimmer = white_noise(0.3, seed=120)
    shimmer = high_pass_filter(shimmer, 3000)
    shimmer = ADSR(attack=0.05, decay=0.1, sustain=0.3, release=0.1).apply(shimmer)
    return mix_layers([Layer(sweep, volume=0.5), Layer(shimmer, volume=0.2)])


def sfx_suppression() -> List[float]:
    """Suppression / ORG damage — oppressive low rumble + crack."""
    rumble = sine_wave(50, 0.2)
    rumble = ADSR(attack=0.005, decay=0.06, sustain=0.4, release=0.1).apply(rumble)
    crack = white_noise(0.03, seed=130)
    crack = distortion(crack, 2.0)
    crack = ADSR(attack=0.001, decay=0.01, sustain=0.0, release=0.015).apply(crack)
    return mix_layers([Layer(crack, volume=0.7), Layer(rumble, volume=0.5)])


# ---------------------------------------------------------------------------
# Preset registry
# ---------------------------------------------------------------------------

PRESETS = {
    # UI
    "ui_click":         ("UI click",            sfx_ui_click),
    "ui_hover":         ("UI hover",            sfx_ui_hover),
    "ui_confirm":       ("UI confirm",          sfx_ui_confirm),
    "ui_cancel":        ("UI cancel",           sfx_ui_cancel),
    "text_blip":        ("Text reveal blip",    sfx_text_blip),
    # Combat
    "sword_hit":        ("Sword impact",        sfx_sword_hit),
    "sword_swing":      ("Sword swing",         sfx_sword_swing),
    "arrow_fire":       ("Crossbow fire",       sfx_arrow_fire),
    "arquebus_fire":    ("Arquebus blast",      sfx_arquebus_fire),
    "pike_thrust":      ("Pike thrust",         sfx_pike_thrust),
    "shield_block":     ("Shield block",        sfx_shield_block),
    "fire_spell":       ("Alchemical fire",     sfx_fire_spell),
    "heal":             ("Healing shimmer",     sfx_heal),
    "death":            ("Unit death",          sfx_death),
    "suppression":      ("Suppression hit",     sfx_suppression),
    # Strategy
    "march_step":       ("March footstep",      sfx_march_step),
    "coin":             ("Coin clink",          sfx_coin),
    "turn_start":       ("Turn start chime",    sfx_turn_start),
    "morale_boost":     ("Morale boost",        sfx_morale_boost),
    "victory_fanfare":  ("Victory fanfare",     sfx_victory_fanfare),
    "defeat":           ("Defeat tone",         sfx_defeat),
}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Sound Designer — synthesize game SFX from code")
    parser.add_argument("--list", action="store_true", help="List available presets")
    parser.add_argument("--preset", type=str, help="Generate a single preset by name")
    parser.add_argument("--format", type=str, default="wav", choices=["wav", "mp3", "ogg"],
                        help="Output format (mp3/ogg require ffmpeg)")
    parser.add_argument("--outdir", type=str, default="assets/sfx",
                        help="Output directory (default: assets/sfx/)")
    args = parser.parse_args()

    if args.list:
        print("Available presets:")
        for name, (desc, _) in sorted(PRESETS.items()):
            print(f"  {name:20s} — {desc}")
        return

    if args.preset:
        if args.preset not in PRESETS:
            print(f"Unknown preset: {args.preset}")
            print(f"Available: {', '.join(sorted(PRESETS.keys()))}")
            sys.exit(1)
        targets = {args.preset: PRESETS[args.preset]}
    else:
        targets = PRESETS

    print(f"Generating {len(targets)} sound effect(s) → {args.outdir}/")
    for name, (desc, gen_fn) in sorted(targets.items()):
        print(f"  [{name}] {desc}")
        samples = gen_fn()
        samples = fade_in(samples, 0.002)
        samples = fade_out(samples, 0.01)
        wav_path = os.path.join(args.outdir, f"{name}.wav")
        write_wav(wav_path, samples)
        if args.format != "wav":
            convert_format(wav_path, args.format)

    print("Done!")


if __name__ == "__main__":
    main()
