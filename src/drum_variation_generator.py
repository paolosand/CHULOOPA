#!/usr/bin/env python3
"""
drum_variation_generator.py - AI-powered drum pattern variation generator for CHULOOPA

Generates a bank of 5 variations at different spice levels from a recorded drum pattern.
Communicates with chuloopa_main.ck via OSC to signal when the bank is ready.

Usage:
    # Watch for file changes and auto-generate variation bank
    python drum_variation_generator.py --watch

    # Generate variation bank for a specific track
    python drum_variation_generator.py --track 0

Requirements:
    pip install numpy watchdog google-genai python-osc
"""

import os
import sys
import argparse
import time
import random
import threading
from dataclasses import dataclass
from typing import List, Optional
from pathlib import Path

import numpy as np
import json

# Load .env file if python-dotenv is available
try:
    from dotenv import load_dotenv
    load_dotenv()  # Load from .env in current directory
    load_dotenv(Path(__file__).parent / '.env')  # Also try src/.env
except ImportError:
    pass  # python-dotenv not installed, rely on environment variables

# Optional imports for Gemini
try:
    from google import genai
    HAVE_GEMINI = True
except ImportError:
    HAVE_GEMINI = False
    print("Note: google-genai not installed. Gemini features disabled.")
    print("      Install with: pip install google-genai")

# Gemini configuration
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
GEMINI_MODEL = 'models/gemini-2.5-flash'

# Optional file watching
try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
    HAVE_WATCHDOG = True
except ImportError:
    HAVE_WATCHDOG = False

# OSC communication
try:
    from pythonosc import dispatcher, osc_server, udp_client
    HAVE_OSC = True
except ImportError:
    HAVE_OSC = False
    print("Note: python-osc not installed. OSC features disabled.")
    print("      Install with: pip install python-osc")


# =============================================================================
# CONFIGURATION
# =============================================================================

# Default paths
DEFAULT_TRACK_DIR = Path(__file__).parent / "tracks" / "track_0"  # src/tracks/track_0/
DEFAULT_VARIATIONS_DIR = DEFAULT_TRACK_DIR / "variations"

# OSC configuration
OSC_RECEIVE_PORT = 5000  # Python listens on this port (ChucK sends to this)
OSC_SEND_PORT = 5001     # Python sends to this port (ChucK listens on this)
OSC_HOST = "127.0.0.1"   # Use IP instead of "localhost" for better compatibility

# Global OSC client (set up in watch mode)
osc_client = None

# Global state
use_no_warp = True  # Skip time-warping by default (preserve rhythmic_creator natural timing)
use_no_anchor = True  # Timing anchoring off by default (rhythmic_creator output is solid)
use_no_ai = False  # Force heuristic generation (skip AI) if True
context_loops = 1  # How many times to repeat loop in context (1, 2, 4, 8) - DEFAULT: 1
current_variation_type = 'rhythmic_creator'  # Default variation type (set by CLI --type arg)

# Fixed model temperature for stability (empirically determined)
# Spice controls post-processing (timing drift, fills), NOT model temperature
RHYTHMIC_CREATOR_TEMPERATURE = 1.0  # Matches Jake's original gen.py (no temperature scaling)

stop_event = threading.Event()  # Set to cancel in-progress generation thread
generation_lock = threading.Lock()  # Ensures one generation thread at a time
generation_queue = []           # List of slot ints (1-5)
generation_thread = None        # type: Optional[threading.Thread]


# =============================================================================
# DATA STRUCTURES
# =============================================================================

@dataclass
class DrumHit:
    """Single drum hit with timing and velocity."""
    midi_note: int       # GM MIDI note number (36=kick, 38=snare, 42=hat)
    timestamp: float     # seconds from loop start
    velocity: float      # 0.0-1.0
    delta_time: float    # seconds until next hit (or loop end)


@dataclass
class DrumPattern:
    """Complete drum pattern with metadata."""
    hits: List[DrumHit]
    loop_duration: float  # total duration in seconds
    source_file: Optional[str] = None

    @classmethod
    def from_file(cls, filepath: str) -> 'DrumPattern':
        """Load drum pattern from CHULOOPA txt file."""
        hits = []
        loop_duration = 0.0

        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()

                # Parse header for loop duration
                if line.startswith('# Total loop duration:'):
                    try:
                        loop_duration = float(line.split(':')[1].strip().split()[0])
                    except (IndexError, ValueError):
                        pass
                    continue

                # Skip other comments and empty lines
                if not line or line.startswith('#'):
                    continue

                # Parse data line: MIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME
                try:
                    parts = line.split(',')
                    if len(parts) >= 4:
                        raw = int(parts[0])
                        # Backward compat: old files use 0/1/2 class notation
                        _LEGACY_MAP = {0: 36, 1: 38, 2: 42}
                        midi_note = _LEGACY_MAP.get(raw, raw) if raw <= 2 else raw
                        hit = DrumHit(
                            midi_note=midi_note,
                            timestamp=float(parts[1]),
                            velocity=float(parts[2]),
                            delta_time=float(parts[3])
                        )
                        hits.append(hit)
                except (ValueError, IndexError) as e:
                    print(f"Warning: Could not parse line: {line} ({e})")

        # Estimate loop duration from last hit if not found in header
        if loop_duration == 0.0 and hits:
            last_hit = hits[-1]
            loop_duration = last_hit.timestamp + last_hit.delta_time

        return cls(hits=hits, loop_duration=loop_duration, source_file=filepath)

    def to_file(self, filepath: str):
        """Save drum pattern to CHULOOPA txt file."""
        # Recalculate delta_times
        self._recalculate_delta_times()

        with open(filepath, 'w') as f:
            # Write header
            f.write(f"# Track Drum Data (AI Generated Variation)\n")
            f.write(f"# Format: MIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME\n")
            f.write(f"# MIDI_NOTE: GM MIDI note number (36=kick, 38=snare, 42=hat, etc.)\n")
            f.write(f"# DELTA_TIME: Duration until next hit (for last hit: time until loop end)\n")
            f.write(f"# Total loop duration: {self.loop_duration:.6f} seconds\n")

            # Write hits with velocity normalization to 0.7-0.9 range
            for hit in self.hits:
                # Normalize velocity: clamp to 0-1, then map to 0.7-0.9
                normalized_velocity = max(0.0, min(1.0, hit.velocity))
                normalized_velocity = 0.7 + (normalized_velocity * 0.2)
                f.write(f"{hit.midi_note},{hit.timestamp:.6f},{normalized_velocity:.6f},{hit.delta_time:.6f}\n")

    def _recalculate_delta_times(self):
        """Recalculate delta_times based on timestamps and loop duration."""
        if not self.hits:
            return

        # Sort by timestamp
        self.hits.sort(key=lambda h: h.timestamp)

        for i, hit in enumerate(self.hits):
            if i < len(self.hits) - 1:
                # Time to next hit
                hit.delta_time = self.hits[i + 1].timestamp - hit.timestamp
            else:
                # Last hit: time to loop end
                hit.delta_time = self.loop_duration - hit.timestamp

    def copy(self) -> 'DrumPattern':
        """Create a deep copy of the pattern."""
        return DrumPattern(
            hits=[DrumHit(h.midi_note, h.timestamp, h.velocity, h.delta_time)
                  for h in self.hits],
            loop_duration=self.loop_duration,
            source_file=self.source_file
        )


# =============================================================================
# ALGORITHMIC VARIATIONS
# =============================================================================

def humanize_pattern(pattern: DrumPattern,
                     timing_variance: float = 0.02,
                     velocity_variance: float = 0.1) -> DrumPattern:
    """Add subtle human-like timing and velocity variations.

    Args:
        pattern: Input pattern
        timing_variance: Max timing shift in seconds (default: 20ms)
        velocity_variance: Max velocity change (default: 0.1)

    Returns:
        Humanized pattern
    """
    result = pattern.copy()

    for hit in result.hits:
        # Add timing variance (Gaussian distribution)
        timing_shift = random.gauss(0, timing_variance / 2)
        hit.timestamp = max(0, hit.timestamp + timing_shift)

        # Add velocity variance
        velocity_shift = random.gauss(0, velocity_variance / 2)
        hit.velocity = max(0.1, min(1.0, hit.velocity + velocity_shift))

    # Ensure timestamps don't exceed loop duration
    for hit in result.hits:
        hit.timestamp = min(hit.timestamp, result.loop_duration - 0.01)

    return result


def mutate_pattern(pattern: DrumPattern,
                   swap_probability: float = 0.2,
                   add_probability: float = 0.1,
                   remove_probability: float = 0.1) -> DrumPattern:
    """Mutate pattern by swapping, adding, or removing hits.

    Args:
        pattern: Input pattern
        swap_probability: Probability of swapping each hit's drum class
        add_probability: Probability of adding a ghost note after each hit
        remove_probability: Probability of removing each hit

    Returns:
        Mutated pattern
    """
    result = pattern.copy()
    new_hits = []

    for hit in result.hits:
        # Maybe remove this hit
        if random.random() < remove_probability:
            continue

        # Maybe swap drum note
        if random.random() < swap_probability:
            # Swap to a different note
            other_classes = [n for n in [36, 38, 42] if n != hit.midi_note]
            hit.midi_note = random.choice(other_classes)

        new_hits.append(hit)

        # Maybe add a ghost note
        if random.random() < add_probability:
            ghost_offset = random.uniform(0.05, 0.15)
            ghost_timestamp = hit.timestamp + ghost_offset

            if ghost_timestamp < result.loop_duration:
                ghost_hit = DrumHit(
                    midi_note=random.choice([36, 38, 42]),
                    timestamp=ghost_timestamp,
                    velocity=hit.velocity * random.uniform(0.3, 0.6),
                    delta_time=0.0
                )
                new_hits.append(ghost_hit)

    result.hits = new_hits
    return result


def densify_pattern(pattern: DrumPattern,
                    fill_probability: float = 0.3) -> DrumPattern:
    """Add more hits to create a busier pattern.

    Args:
        pattern: Input pattern
        fill_probability: Probability of adding fill hits in gaps

    Returns:
        Denser pattern
    """
    result = pattern.copy()

    # Find gaps between hits
    result.hits.sort(key=lambda h: h.timestamp)
    new_hits = list(result.hits)

    for i in range(len(result.hits) - 1):
        current = result.hits[i]
        next_hit = result.hits[i + 1]
        gap = next_hit.timestamp - current.timestamp

        # If gap is large enough, maybe add fills
        if gap > 0.2 and random.random() < fill_probability:
            # Add 1-3 fill hits
            num_fills = random.randint(1, min(3, int(gap / 0.1)))

            for j in range(num_fills):
                fill_time = current.timestamp + gap * (j + 1) / (num_fills + 1)
                fill_hit = DrumHit(
                    midi_note=42,  # Usually closed hi-hat for fills
                    timestamp=fill_time,
                    velocity=random.uniform(0.3, 0.6),
                    delta_time=0.0
                )
                new_hits.append(fill_hit)

    result.hits = new_hits
    return result


def timing_anchor(model_pattern: DrumPattern,
                  original_pattern: DrumPattern,
                  spice_level: float) -> DrumPattern:
    """
    Anchor model hits to original pattern's timing grid.

    This function extracts a "timing grid" from the original beatbox pattern
    and anchors the model's generated hits to those positions. Spice controls
    how tightly hits are anchored and whether off-grid "fill" hits are kept.

    Args:
        model_pattern: Raw output from rhythmic_creator
        original_pattern: User's beatbox input
        spice_level: 0.0-1.0 (controls drift and fills)
            - 0.0-0.3: Tight anchoring (20-50ms drift), rare fills
            - 0.4-0.6: Moderate drift (60-100ms), some fills
            - 0.7-1.0: Loose anchoring (110-150ms), many fills

    Returns:
        Anchored pattern with timing locked to original groove

    Algorithm:
        1. Extract timing grid from original hit timestamps
        2. For each model hit:
           - Find nearest grid position
           - If within max_drift: anchor to grid (deduplicate if needed)
           - Otherwise: keep as fill with probability based on spice
        3. Recalculate delta_times
    """
    if not original_pattern.hits or not model_pattern.hits:
        return model_pattern

    # Extract timing grid from original
    timing_grid = [hit.timestamp for hit in original_pattern.hits]

    # Calculate spice-based parameters
    # max_drift: 20ms at spice=0.0, 150ms at spice=1.0
    max_drift = 0.02 + (spice_level * 0.13)

    # fill_probability: 0% at spice=0.0, 80% at spice=1.0
    fill_probability = spice_level * 0.8

    # Use dictionary to deduplicate - keep best hit per grid slot
    # grid_position -> best_hit
    grid_slots = {}

    # Off-grid fills
    fill_hits = []

    for model_hit in model_pattern.hits:
        # Find nearest grid position
        nearest_pos = min(timing_grid, key=lambda t: abs(t - model_hit.timestamp))
        distance = abs(model_hit.timestamp - nearest_pos)

        if distance < max_drift:
            # Anchor to grid position
            # If multiple hits map to same slot, keep hit with highest velocity
            if nearest_pos not in grid_slots or model_hit.velocity > grid_slots[nearest_pos].velocity:
                grid_slots[nearest_pos] = DrumHit(
                    midi_note=model_hit.midi_note,  # Trust model's choice
                    timestamp=nearest_pos,
                    velocity=model_hit.velocity,
                    delta_time=0.0  # Will recalculate
                )
        elif random.random() < fill_probability:
            # Keep as fill (off-grid)
            fill_hits.append(model_hit)

    # Combine grid-anchored hits and fills
    anchored_hits = list(grid_slots.values()) + fill_hits

    if not anchored_hits:
        # Fallback: return model output unchanged
        return model_pattern

    # Create pattern and recalculate delta_times
    result = DrumPattern(hits=anchored_hits, loop_duration=original_pattern.loop_duration)
    result._recalculate_delta_times()

    return result


def fit_to_loop_duration(pattern: DrumPattern, target_duration: float) -> DrumPattern:
    """
    Time-warp pattern to fit exact loop duration.

    This function uniformly scales all timestamps proportionally,
    preserving relative spacing between hits while ensuring the
    pattern loops perfectly at the target duration.

    Args:
        pattern: Anchored pattern (may have any duration)
        target_duration: Target loop duration in seconds

    Returns:
        Pattern with exactly target_duration

    Note: This time-warping is usually minimal (<5% scale factor) because
    timing anchoring already produces patterns close to target duration.
    """
    if not pattern.hits:
        return DrumPattern(hits=[], loop_duration=target_duration)

    # Find actual duration of pattern
    max_timestamp = max(hit.timestamp for hit in pattern.hits)

    if max_timestamp == 0 or max_timestamp <= 0.01:
        # Pattern has no duration or all hits at start
        return DrumPattern(hits=[], loop_duration=target_duration)

    # Calculate uniform scale factor
    scale_factor = target_duration / max_timestamp

    # Scale all timestamps proportionally
    fitted_hits = []
    for hit in pattern.hits:
        new_timestamp = hit.timestamp * scale_factor

        # Keep only hits within target duration (allow hits at boundary)
        if new_timestamp <= target_duration:
            fitted_hits.append(DrumHit(
                midi_note=hit.midi_note,
                timestamp=new_timestamp,
                velocity=hit.velocity,
                delta_time=0.0  # Will recalculate
            ))

    # Create pattern and recalculate delta_times
    result = DrumPattern(hits=fitted_hits, loop_duration=target_duration)
    result._recalculate_delta_times()

    return result


def rebuild_timestamps(varied_groove: List[dict], original_start_time: float = 0.0) -> List[dict]:
    """
    Rebuild absolute timestamps from delta times.

    Guarantees exact loop duration match to original by reconstructing
    timestamps from delta times (which are manipulated by mutations).

    Args:
        varied_groove: List of {'midi_note', 'vel', 'delta'} dicts
        original_start_time: Timestamp of first hit in original pattern

    Returns:
        List of {'midi_note', 'timestamp', 'vel', 'delta'} dicts
    """
    final_output = []
    current_time = original_start_time

    for hit in varied_groove:
        final_output.append({
            'midi_note': hit['midi_note'],
            'timestamp': current_time,
            'vel': hit['vel'],
            'delta': hit['delta']
        })
        current_time += hit['delta']

    return final_output


def generate_musical_variation(pattern: DrumPattern, spice_level: float) -> DrumPattern:
    """
    Generate variation using real drumming techniques.

    This is the algorithmic fallback when neural models fail or aren't available.
    Uses musically valid techniques: doubling, ghost notes, triplets, syncopation,
    and substitution, all controlled by spice level.

    Args:
        pattern: Original drum pattern
        spice_level: 0.0-1.0 controlling mutation probability
            - Low (0.0-0.3): Conservative (50-80% of base probabilities)
            - High (0.7-1.0): Creative (120-150% of base probabilities)

    Returns:
        Varied pattern maintaining exact loop duration

    Algorithm:
        1. Protect structural anchors (first hit, strong backbeats)
        2. Apply spice-scaled mutations to other hits
        3. Rebuild timestamps from delta times to preserve duration
    """
    if not pattern.hits:
        return pattern

    # Base mutation probabilities
    base_probs = {
        'double': 0.15,      # Double kick/snare
        'ghost': 0.10,       # Ghost note fill
        'triplet': 0.05,     # Hi-hat triplets
        'shift_and': 0.10,   # Shift to "and" (syncopation)
        'substitute': 0.10,  # Drum substitution
    }

    # Scale by spice level
    # At low spice (0.2): reduce all mutations by 50% (multiplier = 0.7)
    # At high spice (0.8): increase by 50% (multiplier = 1.3)
    spice_multiplier = 0.5 + spice_level  # Range: 0.5x to 1.5x

    probs = {k: v * spice_multiplier for k, v in base_probs.items()}

    # Convert to dict format for easier manipulation
    drum_data = [
        {'midi_note': h.midi_note, 'vel': h.velocity, 'delta': h.delta_time, 'timestamp': h.timestamp}
        for h in pattern.hits
    ]

    varied_groove = []

    for i, hit in enumerate(drum_data):
        c = hit['midi_note']
        v = hit['vel']
        d = hit['delta']

        # PROTECT ANCHORS (always protected regardless of spice)
        # Protect: first hit, strong backbeats (snares with high velocity)
        is_anchor = (i == 0) or (c in (37, 38, 39, 40) and v > 0.7)

        if is_anchor:
            # Just humanize velocity slightly
            v = max(0.1, min(1.0, v + random.uniform(-0.03, 0.03)))
            varied_groove.append({'midi_note': c, 'vel': v, 'delta': d})
            continue

        # Apply mutations with spice-scaled probabilities
        roll = random.random()

        if roll < probs['double']:
            # Double the hit (split delta in half)
            half_delta = d / 2.0
            varied_groove.append({'midi_note': c, 'vel': v * 0.9, 'delta': half_delta})
            varied_groove.append({'midi_note': c, 'vel': v * 0.7, 'delta': half_delta})

        elif roll < probs['double'] + probs['ghost']:
            # Add ghost note (snare)
            half_delta = d / 2.0
            varied_groove.append({'midi_note': c, 'vel': v, 'delta': half_delta})
            varied_groove.append({'midi_note': 38, 'vel': random.uniform(0.15, 0.35), 'delta': half_delta})

        elif roll < probs['double'] + probs['ghost'] + probs['triplet'] and c == 42:
            # Hi-hat triplets (only for closed hi-hat)
            third_delta = d / 3.0
            varied_groove.append({'midi_note': 42, 'vel': v, 'delta': third_delta})
            varied_groove.append({'midi_note': 42, 'vel': v * 0.6, 'delta': third_delta})
            varied_groove.append({'midi_note': 42, 'vel': v * 0.8, 'delta': third_delta})

        elif roll < probs['double'] + probs['ghost'] + probs['triplet'] + probs['shift_and'] and len(varied_groove) > 0:
            # Shift to "and" (syncopation)
            # Push this note later by extending previous note's delta
            shift_amount = d / 2.0
            varied_groove[-1]['delta'] += shift_amount  # Lengthen previous note
            varied_groove.append({'midi_note': c, 'vel': v, 'delta': d - shift_amount})  # Shorten current

        elif roll < probs['double'] + probs['ghost'] + probs['triplet'] + probs['shift_and'] + probs['substitute']:
            # Drum substitution (swap weak kicks for hats, or hats for weak kicks)
            new_class = 42 if c in (35, 36) else 36
            varied_groove.append({'midi_note': new_class, 'vel': v * 0.8, 'delta': d})

        else:
            # Pass through unchanged
            varied_groove.append({'midi_note': c, 'vel': v, 'delta': d})

    # Rebuild timestamps from delta times to preserve exact loop duration
    final_hits_data = rebuild_timestamps(varied_groove, original_start_time=pattern.hits[0].timestamp if pattern.hits else 0.0)

    # Convert back to DrumHit objects
    final_hits = []
    for hit_data in final_hits_data:
        final_hits.append(DrumHit(
            midi_note=hit_data['midi_note'],
            timestamp=hit_data['timestamp'],
            velocity=hit_data['vel'],
            delta_time=hit_data['delta']
        ))

    # Create result pattern
    result = DrumPattern(hits=final_hits, loop_duration=pattern.loop_duration)

    # Ensure exact duration by recalculating
    result._recalculate_delta_times()

    return result


def simplify_pattern(pattern: DrumPattern,
                     keep_probability: float = 0.6) -> DrumPattern:
    """Simplify pattern by removing some hits.

    Args:
        pattern: Input pattern
        keep_probability: Probability of keeping each hit

    Returns:
        Simplified pattern
    """
    result = pattern.copy()

    # Always keep the first kick
    first_kick = None
    for hit in result.hits:
        if hit.midi_note in (35, 36):
            first_kick = hit
            break

    # Filter hits
    new_hits = []
    for hit in result.hits:
        if hit is first_kick or random.random() < keep_probability:
            new_hits.append(hit)

    result.hits = new_hits
    return result


def shift_pattern(pattern: DrumPattern,
                  shift_amount: float = None) -> DrumPattern:
    """Shift all hits forward/backward in time (rotation).

    Args:
        pattern: Input pattern
        shift_amount: Seconds to shift (negative = earlier).
                      If None, shifts by random 16th note equivalent.

    Returns:
        Shifted pattern
    """
    result = pattern.copy()

    if shift_amount is None:
        # Estimate 16th note duration
        sixteenth = result.loop_duration / 16
        shift_amount = random.choice([-2, -1, 1, 2]) * sixteenth

    for hit in result.hits:
        new_time = hit.timestamp + shift_amount
        # Wrap around loop
        hit.timestamp = new_time % result.loop_duration

    return result


def groove_preserve(pattern: DrumPattern,
                    timing_variance: float = 0.015,
                    velocity_variance: float = 0.08,
                    accent_shift: float = 0.1,
                    swap_probability: float = 0.05) -> DrumPattern:
    """Create variation while strictly preserving the groove structure.

    This keeps your exact hit positions and drum choices, adding only:
    - Small timing humanization (±15ms default)
    - Velocity variations with musical accent patterns
    - Rare instrument swaps (5% default)

    Args:
        pattern: Input pattern
        timing_variance: Max timing shift in seconds (default: 15ms)
        velocity_variance: Base velocity variation (default: 0.08)
        accent_shift: Additional velocity boost for accented beats (default: 0.1)
        swap_probability: Probability of swapping drum class (default: 0.05)

    Returns:
        Variation with identical structure but human feel
    """
    result = pattern.copy()

    if not result.hits:
        return result

    # Analyze pattern to find strong beats (for accent pattern)
    # Assume 4/4 time, estimate beat positions
    beat_duration = result.loop_duration / 4
    half_beat = beat_duration / 2

    for hit in result.hits:
        # 1. Timing humanization (Gaussian, tighter than humanize_pattern)
        # Kicks tend to be more on-beat, hats/snares can be looser
        if hit.midi_note in (35, 36):  # kick - tighter timing
            timing_shift = random.gauss(0, timing_variance / 3)
        else:  # snare/hat - slightly looser
            timing_shift = random.gauss(0, timing_variance / 2)

        hit.timestamp = max(0, hit.timestamp + timing_shift)
        hit.timestamp = min(hit.timestamp, result.loop_duration - 0.01)

        # 2. Velocity variation with musical accent pattern
        # Determine if this hit is on a strong beat
        beat_position = hit.timestamp % beat_duration
        is_downbeat = beat_position < (beat_duration * 0.1)  # First 10% of beat
        is_backbeat = abs(beat_position - half_beat) < (beat_duration * 0.1)

        # Base velocity variation
        vel_shift = random.gauss(0, velocity_variance / 2)

        # Accent pattern: boost downbeats and backbeats slightly
        if is_downbeat and hit.midi_note in (35, 36):  # Kick on downbeat
            vel_shift += accent_shift * random.uniform(0.5, 1.0)
        elif is_backbeat and hit.midi_note in (37, 38, 39, 40):  # Snare on backbeat
            vel_shift += accent_shift * random.uniform(0.3, 0.8)

        hit.velocity = max(0.1, min(1.0, hit.velocity + vel_shift))

        # 3. Rare drum class swap (very conservative)
        if random.random() < swap_probability:
            # For now, keep all classes - swapping disrupts groove too much
            pass

    return result


# =============================================================================
# RHYTHMIC CREATOR (JAKE'S MODEL) VARIATION GENERATOR
# =============================================================================

# Try to import rhythmic creator model
try:
    from rhythmic_creator_model import get_model as get_rhythmic_model
    from format_converters import chuloopa_to_rhythmic_creator, rhythmic_creator_to_chuloopa, VALID_GM_DRUM_NOTES
    HAVE_RHYTHMIC_CREATOR = True
except ImportError as e:
    HAVE_RHYTHMIC_CREATOR = False
    print(f"Note: rhythmic_creator not available: {e}")

# Global model instance
rhythmic_model = None
force_cpu = False  # Global flag to force CPU inference


def init_rhythmic_creator():
    """Initialize rhythmic creator model (call once at startup)."""
    global rhythmic_model, force_cpu

    if not HAVE_RHYTHMIC_CREATOR:
        return False

    try:
        device = 'cpu' if force_cpu else None  # Auto-detect if not forced
        rhythmic_model = get_rhythmic_model(device=device)
        return True
    except Exception as e:
        print(f"Warning: Failed to load rhythmic_creator: {e}")
        return False


def rhythmic_creator_variation(pattern: DrumPattern,
                               spice_level: float = 0.5) -> tuple:
    """
    Generate variation using rhythmic_creator (SIMPLIFIED - NO WARP VERSION).

    This function implements a clean pipeline based on test_rhythmic_creator_nowarp.py:
    1. Generate variation using rhythmic_creator at FIXED temperature
    2. Use FULL model output (no context stripping)
    3. Use natural model duration (no time-warping)
    4. Optional timing anchoring to preserve groove

    Args:
        pattern: Original user beatbox pattern
        spice_level: 0.0-1.0 controlling variation amount
            - Controls timing anchoring (drift, fills) if enabled
            - Model temperature is FIXED at RHYTHMIC_CREATOR_TEMPERATURE

    Returns:
        Tuple of (DrumPattern, success: bool)
    """
    global rhythmic_model
    import time  # DIAGNOSTIC

    t_start = time.time()  # DIAGNOSTIC

    # Initialize model if needed
    t0 = time.time()  # DIAGNOSTIC
    if rhythmic_model is None:
        if not init_rhythmic_creator():
            print("  Rhythmic creator not available, falling back to groove_preserve")
            return generate_musical_variation(pattern, spice_level), False
    t_init = time.time() - t0  # DIAGNOSTIC
    if t_init > 0.1:  # DIAGNOSTIC
        print(f"  ⏱️  Model init: {t_init:.2f}s")  # DIAGNOSTIC

    try:
        # Convert to rhythmic_creator format (single loop)
        t0 = time.time()  # DIAGNOSTIC
        context_text = chuloopa_to_rhythmic_creator(pattern)

        if not context_text:
            print("  Warning: Empty context, falling back")
            return generate_musical_variation(pattern, spice_level), False

        context_tokens = context_text.split()
        t_prep = time.time() - t0  # DIAGNOSTIC
        if t_prep > 0.05:  # DIAGNOSTIC
            print(f"  ⏱️  Context prep: {t_prep:.3f}s")  # DIAGNOSTIC

        # Spice controls token count: ×0.85 (low) → ×1.5 (high)
        # Interpolate linearly: spice 0.0 → 0.85×, spice 0.5 → 1.175×, spice 1.0 → 1.5×
        # Low spice generates fewer tokens than input → sparse/selective variations
        # High spice adds fills without straying too far from original groove
        token_multiplier = 0.85 + (spice_level * 0.65)
        num_tokens = int(len(context_tokens) * token_multiplier)

        print(f"  Generating variation with rhythmic_creator (temp={RHYTHMIC_CREATOR_TEMPERATURE:.2f}, spice={spice_level:.2f})...")
        print(f"    Context: {len(pattern.hits)} hits, loop={pattern.loop_duration:.2f}s")
        print(f"    Generating: {num_tokens} tokens (~{num_tokens//3} hits) (multiplier={token_multiplier:.1f}×)")

        t0 = time.time()
        generated_texts = rhythmic_model.generate_variation_batch(
            batch_size=1,
            input_pattern=context_text,
            num_tokens=num_tokens,
            temperature=RHYTHMIC_CREATOR_TEMPERATURE,
            stop_event=stop_event  # module-level global — allows mid-generation cancellation
        )
        t_generate = time.time() - t0
        print(f"    ⏱️  MODEL GENERATION: {t_generate:.2f}s")

        loop_dur = pattern.loop_duration
        raw_pattern = rhythmic_creator_to_chuloopa(generated_texts[0], loop_duration=loop_dur)

        if not raw_pattern.hits or len(raw_pattern.hits) < 2:
            print("  Warning: Generated pattern invalid, falling back")
            return generate_musical_variation(pattern, spice_level), False

        max_time = max(hit.timestamp for hit in raw_pattern.hits)
        print(f"    Model output: {max_time:.2f}s last hit (loop: {pattern.loop_duration:.2f}s)")

        variation = DrumPattern(hits=raw_pattern.hits, loop_duration=pattern.loop_duration)
        variation._recalculate_delta_times()

        print(f"    Variation: {len(variation.hits)} hits, loop={pattern.loop_duration:.2f}s")

        # Save intermediate files for debugging (if source file is known)
        if pattern.source_file:
            variations_dir = Path(pattern.source_file).parent / "variations"
            variations_dir.mkdir(parents=True, exist_ok=True)

            # Save raw model output (natural duration, no processing)
            raw_model_file = variations_dir / "track_0_drums_var1_raw_model.txt"
            variation.to_file(str(raw_model_file))
            print(f"    Saved raw model output: {raw_model_file.name} ({len(variation.hits)} hits, {max_time:.2f}s, loop={pattern.loop_duration:.2f}s)")

        # Optional timing anchoring (if --no-anchor flag not set)
        if use_no_anchor:
            print(f"    Skipping timing anchoring (--no-anchor)")
            final_variation = variation
        else:
            print(f"    Applying timing anchoring (spice: {spice_level:.2f})...")
            t0 = time.time()  # DIAGNOSTIC
            anchored = timing_anchor(variation, pattern, spice_level)
            t_anchor = time.time() - t0  # DIAGNOSTIC
            print(f"    ⏱️  Timing anchor: {t_anchor:.3f}s")  # DIAGNOSTIC

            if not anchored.hits or len(anchored.hits) < 2:
                print("  Warning: Timing anchoring removed too many hits, using raw model output")
                final_variation = variation
            else:
                final_variation = anchored
                print(f"    Anchored variation: {len(final_variation.hits)} hits")

        t_total = time.time() - t_start  # DIAGNOSTIC
        print(f"  🏁 TOTAL TIME: {t_total:.2f}s")  # DIAGNOSTIC

        print(f"    Final variation: {len(final_variation.hits)} hits, {final_variation.loop_duration:.2f}s")
        return final_variation, True

    except Exception as e:
        print(f"  Warning: rhythmic_creator generation failed: {e}")
        import traceback
        traceback.print_exc()
        print("  Falling back to groove_preserve")
        return generate_musical_variation(pattern, spice_level), False


# =============================================================================
# GEMINI VARIATION GENERATOR
# =============================================================================

def pattern_to_gemini_prompt(pattern: DrumPattern) -> str:
    """Convert DrumPattern to Gemini prompt format."""
    lines = [
        f"Loop duration: {pattern.loop_duration:.6f} seconds",
        f"Total hits: {len(pattern.hits)}",
        "",
        "Pattern (MIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME):",
        "# MIDI_NOTE: GM drum note (36=kick, 38=snare, 42=closed hat, 44=pedal hat, 46=open hat, 49=crash, 51=ride, etc.)"
    ]
    for hit in pattern.hits:
        lines.append(f"{hit.midi_note},{hit.timestamp:.6f},{hit.velocity:.6f},{hit.delta_time:.6f}")
    return "\n".join(lines)


def parse_gemini_pattern(pattern_text: str, loop_duration: float) -> DrumPattern:
    """Parse Gemini's pattern output back to DrumPattern."""
    # Import VALID_GM_DRUM_NOTES for validation (may not be available if format_converters not loaded)
    try:
        from format_converters import VALID_GM_DRUM_NOTES as _VALID_NOTES
    except ImportError:
        _VALID_NOTES = set(range(27, 88))

    hits = []
    for line in pattern_text.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split(',')
        if len(parts) >= 4:
            try:
                midi_note = int(parts[0])
                if midi_note not in _VALID_NOTES:
                    continue
                hits.append(DrumHit(
                    midi_note=midi_note,
                    timestamp=float(parts[1]),
                    velocity=float(parts[2]),
                    delta_time=float(parts[3])
                ))
            except (ValueError, IndexError):
                continue
    return DrumPattern(hits=hits, loop_duration=loop_duration)


def gemini_variation(pattern: DrumPattern, spice_level: float = 0.5) -> DrumPattern:
    """Generate variation using Gemini AI.

    Spice controls target hit density:
        0.0 → ~0.7× original hits (sparse skeleton)
        0.5 → ~1.35× original hits (moderate embellishment)
        1.0 → ~2.0× original hits (dense fills, hi-hats, ghost notes)

    Args:
        pattern: Input drum pattern
        spice_level: 0.0-1.0 controlling hit density of the variation

    Returns:
        Tuple of (DrumPattern, success: bool)
        - DrumPattern: New pattern with variation (or fallback)
        - success: True if AI generated, False if fallback was used
    """
    if not HAVE_GEMINI:
        print("Warning: google-genai not installed, falling back to groove_preserve")
        return groove_preserve(pattern), False

    if not GEMINI_API_KEY:
        print("Warning: GEMINI_API_KEY not set, falling back to groove_preserve")
        return groove_preserve(pattern), False

    # Compute target hit count: 0.7× at spice=0.0, 1.35× at spice=0.5, 2.0× at spice=1.0
    hit_multiplier = 0.7 + (spice_level * 1.3)
    target_hits = max(1, round(len(pattern.hits) * hit_multiplier))

    try:
        # Client reads API key from GEMINI_API_KEY environment variable
        client = genai.Client()

        system_prompt = f"""You are an expert drum loop programmer. Generate a variation of the input drum pattern that targets approximately {target_hits} total hits (original has {len(pattern.hits)} hits). Use hit count as a proxy for overall energy and complexity — not just hi-hat density.

ENERGY LEVEL GUIDE (based on target hit count relative to original):
- Fewer hits than original → reduce complexity: simplify rhythms, drop fills, thin out percussion. The pattern should feel more open and spacious.
- Similar hits to original → reinterpret the groove: swap instruments, shift accents, vary velocities, add ghost notes where hits are removed elsewhere. Keep the same energy, change the texture.
- More hits than original → raise the energy: add kick doubles, snare ghost notes, off-beat accents, toms, syncopation, anticipations. Think like a drummer who is "heating up" — the groove gets busier and more intense across ALL drum voices, not just cymbals.

IMPORTANT: Do NOT default to hi-hats as the primary way to add hits. Spread additional complexity across the full kit — kicks, snares, toms, and cymbals all contribute to energy.

AVAILABLE DRUM SOUNDS (use any that serve the groove):
- 35/36: Bass drum (kick) — doubles, anticipations, syncopation
- 38/40: Snare — backbeat, ghost notes, drags
- 37: Cross-stick — subtle snare replacement or accent
- 42: Closed hi-hat
- 44: Pedal hi-hat
- 46: Open hi-hat (use for accents, not filler)
- 49/57: Crash cymbal (section accents only)
- 51: Ride cymbal
- 41/43/45/47/48/50: Toms low→high (fills, accents)
- 39: Hand clap (use sparingly)

RULES:
1. The rhythmic backbone (kick/snare pulse) must remain recognizable — don't erase the original groove
2. Loop duration must be EXACTLY {pattern.loop_duration:.6f} seconds
3. Sum of all DELTA_TIME values must equal the loop duration exactly
4. Velocities should feel human: kick ~0.7-0.9, snare ~0.6-0.85, ghost notes ~0.2-0.4, cymbals ~0.3-0.6
5. Aim for {target_hits} hits (±2 acceptable) — spread across the full kit, not just one voice
6. No random note dumps — every hit should serve the groove

OUTPUT FORMAT (JSON):
{{"pattern": "MIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME\\nMIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME\\n..."}}

Where:
- MIDI_NOTE: integer GM drum note number
- TIMESTAMP: seconds from loop start (0.0 to < {pattern.loop_duration:.6f})
- VELOCITY: 0.0-1.0
- DELTA_TIME: seconds until next hit; last hit's DELTA_TIME = time remaining until loop end

Hits must be sorted by TIMESTAMP ascending."""

        user_prompt = pattern_to_gemini_prompt(pattern)

        print(f"  Calling Gemini API ({GEMINI_MODEL}, spice={spice_level:.2f}, target={target_hits} hits)...")
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=system_prompt + "\n\nInput pattern:\n" + user_prompt,
            config={"temperature": 1.0, "max_output_tokens": 4096, "thinking_config": {"thinking_budget": 2048}}
        )

        # Extract text from response
        response_text = response.text

        # Try to extract JSON from response (may be wrapped in markdown code blocks)
        json_text = response_text
        if "```json" in response_text:
            json_text = response_text.split("```json")[1].split("```")[0]
        elif "```" in response_text:
            json_text = response_text.split("```")[1].split("```")[0]

        # Parse JSON response
        result = json.loads(json_text.strip())

        # Parse pattern back to DrumPattern
        variation = parse_gemini_pattern(result['pattern'], pattern.loop_duration)

        if not variation.hits:
            print("  Warning: Gemini returned empty pattern, falling back to groove_preserve")
            return groove_preserve(pattern), False

        print(f"  Generated {len(variation.hits)} hits (original: {len(pattern.hits)})")
        return variation, True  # Success!

    except json.JSONDecodeError as e:
        print(f"  Warning: Failed to parse Gemini JSON response: {e}")
        print(f"  Response was: {response_text[:200]}...")
        print("  Falling back to groove_preserve")
        return groove_preserve(pattern), False
    except Exception as e:
        print(f"  Warning: Gemini API call failed: {e}")
        print("  Falling back to groove_preserve")
        return groove_preserve(pattern), False


# =============================================================================
# OSC HANDLERS
# =============================================================================

def handle_regenerate(address):
    """Handle regenerate request from ChucK — cancels in-progress, starts fresh full bank."""
    global current_variation_type

    print(f"\n{'='*60}")
    print("REGENERATE BANK requested from ChucK (D#1 / Note 39)")
    print(f"{'='*60}")

    track_file = DEFAULT_TRACK_DIR / "track_0_drums.txt"

    if not track_file.exists():
        error_msg = f"Error: Original track file not found: {track_file}"
        print(error_msg)
        if osc_client:
            osc_client.send_message("/chuloopa/error", error_msg)
        return

    try:
        cancel_generation()
        start_full_bank_generation()
    except Exception as e:
        error_msg = f"Error generating variation bank: {e}"
        print(error_msg)
        if osc_client:
            osc_client.send_message("/chuloopa/error", error_msg)


def handle_track_cleared(address):
    """Cancel in-progress generation and delete all stale variation files."""
    print("\n>>> OSC RECEIVED: /chuloopa/track_cleared — cancelling generation <<<")
    cancel_generation()

    # Delete all variation files — prevents stale files being loaded for new recording
    deleted = []
    for slot in range(1, 6):
        var_file = DEFAULT_VARIATIONS_DIR / f"track_0_drums_var{slot}.txt"
        if var_file.exists():
            var_file.unlink()
            deleted.append(f"var{slot}.txt")

    if deleted:
        print(f"  Deleted stale variation files: {', '.join(deleted)}")
    else:
        print("  No variation files to delete")

    if osc_client:
        try:
            osc_client.send_message("/chuloopa/generation_progress", "Cancelled — track cleared")
        except Exception as e:
            print(f"  OSC error: {e}")


def generate_variations_for_track(track_file: Path, variation_type: str = 'rhythmic_creator'):
    """Generate 1 variation for a track file and send OSC notification."""
    global osc_client

    print(f"Loading: {track_file}")
    pattern = DrumPattern.from_file(str(track_file))

    if not pattern.hits:
        error_msg = "Warning: No hits found in pattern"
        print(error_msg)
        if osc_client:
            osc_client.send_message("/chuloopa/error", error_msg)
        return

    print(f"  Loaded {len(pattern.hits)} hits, duration: {pattern.loop_duration:.3f}s")

    # Create variations directory if it doesn't exist
    variations_dir = DEFAULT_VARIATIONS_DIR
    variations_dir.mkdir(parents=True, exist_ok=True)

    # Generate 1 variation
    if osc_client:
        osc_client.send_message("/chuloopa/generation_progress", f"Generating variation...")

    print(f"\n  Generating variation (spice: 0.5 default)")
    varied, success = generate_variation(pattern, variation_type, temperature=0.5)

    output_file = variations_dir / f"track_0_drums_var1.txt"
    varied.to_file(str(output_file))
    print(f"  Saved: {output_file}")

    # Notify ChucK based on success/failure
    if osc_client:
        try:
            if success:
                # AI generation succeeded
                print(f"  Sending OSC: /chuloopa/variations_ready (1) to {OSC_HOST}:{OSC_SEND_PORT}")
                osc_client.send_message("/chuloopa/variations_ready", 1)
                print(f"  Sending OSC: /chuloopa/generation_progress to {OSC_HOST}:{OSC_SEND_PORT}")
                osc_client.send_message("/chuloopa/generation_progress", "Complete!")
                print(f"  OSC messages sent successfully")
            else:
                # AI generation failed, fallback was used
                print(f"  Sending OSC: /chuloopa/generation_failed to {OSC_HOST}:{OSC_SEND_PORT}")
                osc_client.send_message("/chuloopa/generation_failed", "API call failed - try again")
                print(f"  Sending OSC: /chuloopa/generation_progress to {OSC_HOST}:{OSC_SEND_PORT}")
                osc_client.send_message("/chuloopa/generation_progress", "Failed - try again")
                print(f"  OSC messages sent successfully")
        except Exception as e:
            print(f"  ERROR sending OSC: {e}")
    else:
        print("  WARNING: OSC client not initialized, cannot send ready notification")

    if success:
        print(f"\n✓ Generated variation")
    else:
        print(f"\n✗ Generation FAILED - used fallback")
        print(f"  Press D#1 in ChucK to try again")
    print(f"{'='*60}\n")


def track_file_exists() -> bool:
    """Check if the main track file exists."""
    return (DEFAULT_TRACK_DIR / "track_0_drums.txt").exists()


def cancel_generation():
    """Signal running generation to stop and wait for clean exit."""
    global generation_thread, generation_queue
    stop_event.set()
    if generation_thread and generation_thread.is_alive():
        generation_thread.join()  # no timeout — threads exit within ~150ms via stop_event
    stop_event.clear()  # cleared AFTER join — no race window
    with generation_lock:
        generation_queue.clear()


def _generation_worker():
    """Coordinator: spawns one thread per slot, joins in order, fires bank_ready on slot 1."""
    variations_dir = DEFAULT_VARIATIONS_DIR
    variations_dir.mkdir(parents=True, exist_ok=True)

    track_file = DEFAULT_TRACK_DIR / "track_0_drums.txt"
    if not track_file.exists():
        print("  Worker: track file not found, aborting")
        return

    pattern = DrumPattern.from_file(str(track_file))
    if not pattern.hits:
        print("  Worker: no hits in pattern, aborting")
        return

    # Snapshot and clear queue atomically
    with generation_lock:
        slots = list(generation_queue)
        generation_queue.clear()

    if not slots:
        return

    print(f"\n  [Worker] Starting parallel generation: slots={slots}")

    written_slots = set()  # slots that successfully wrote a file

    # Spawn one thread per slot — all start simultaneously
    threads = {
        slot: threading.Thread(
            target=_run_slot_thread,
            args=(slot, pattern, written_slots),
            daemon=True,
            name=f"slot-{slot}"
        )
        for slot in slots
    }
    for t in threads.values():
        t.start()

    completed_slots = set()
    bank_ready_sent = False

    # Join in slot order — bank_ready fires when slot 1 specifically completes
    for slot in slots:
        threads[slot].join()
        completed_slots.add(slot)
        print(f"  [Worker] Slot {slot} joined")

        if slot == 1 and not bank_ready_sent and 1 in written_slots and not stop_event.is_set() and osc_client:
            try:
                osc_client.send_message("/chuloopa/bank_ready", 0)
                osc_client.send_message("/chuloopa/generation_progress",
                                        "var1 ready — auto-switching enabled")
                bank_ready_sent = True
                print("  [Worker] bank_ready sent (slot 1 complete)")
            except Exception as e:
                print(f"  [Worker] OSC error sending bank_ready: {e}")

    # Fallback: if slot 1 failed for any reason
    if not bank_ready_sent and written_slots and not stop_event.is_set() and osc_client:
        lowest = min(written_slots)
        try:
            osc_client.send_message("/chuloopa/bank_ready", 0)
            osc_client.send_message("/chuloopa/generation_progress",
                                    f"var{lowest} ready — auto-switching enabled")
            bank_ready_sent = True
        except Exception as e:
            print(f"  [Worker] OSC error sending bank_ready fallback: {e}")

    # All-fail case — notify ChucK (only if nothing was written and not cancelled)
    if not bank_ready_sent and not written_slots and not stop_event.is_set() and osc_client:
        try:
            osc_client.send_message("/chuloopa/generation_progress",
                                    "All slots failed — press D#1 to retry")
        except Exception as e:
            print(f"  [Worker] OSC error sending all-fail message: {e}")

    print(f"  [Worker] Done.")


def start_full_bank_generation():
    """Start a fresh full bank (all 5 slots). Caller must call cancel_generation() first."""
    global generation_thread

    all_slots = [1, 2, 3, 4, 5]
    print(f"\n  Starting bank: slots={all_slots}")

    with generation_lock:
        generation_queue.clear()
        generation_queue.extend(all_slots)
        if generation_thread is None or not generation_thread.is_alive():
            generation_thread = threading.Thread(target=_generation_worker, daemon=True)
            generation_thread.start()
            print(f"  Coordinator thread started")


def generate_variation_bank(track_file: Path, variation_type: str = 'rhythmic_creator'):
    """Generate all 5 variation slots in parallel.

    /chuloopa/bank_ready 0 is sent when slot 1 completes to enable auto-switching.
    """
    global current_variation_type
    current_variation_type = variation_type

    if not track_file.exists():
        error_msg = f"Error: Track file not found: {track_file}"
        print(error_msg)
        if osc_client:
            osc_client.send_message("/chuloopa/error", error_msg)
        return

    cancel_generation()
    start_full_bank_generation()


def _run_slot_thread(slot: int, pattern: DrumPattern, written_slots: set):
    """Per-slot worker: generates one variation and saves it. Respects stop_event."""
    if stop_event.is_set():
        return  # cancelled before starting — don't write anything

    spice = [0.2, 0.4, 0.6, 0.8, 1.0][slot - 1]
    variations_dir = DEFAULT_VARIATIONS_DIR
    variations_dir.mkdir(parents=True, exist_ok=True)

    if osc_client:
        try:
            osc_client.send_message("/chuloopa/generation_progress",
                                    f"Generating var{slot}/5 (spice {spice:.1f})...")
        except Exception:
            pass

    try:
        # Cancellation is via the module-level stop_event global, which rhythmic_creator_variation
        # reads directly when calling generate_variation_batch — no explicit parameter needed.
        varied, success = generate_variation(pattern, current_variation_type, temperature=spice)

        # Post-generation cancel check: discard if cancelled during generation
        if stop_event.is_set():
            return

        output_file = variations_dir / f"track_0_drums_var{slot}.txt"
        varied.to_file(str(output_file))
        written_slots.add(slot)
        print(f"  [Slot {slot}] Saved: {output_file.name} ({len(varied.hits)} hits, spice={spice:.1f})")
        if osc_client:
            try:
                osc_client.send_message("/chuloopa/bank_progress", slot)
            except Exception:
                pass

    except Exception as e:
        print(f"  [Slot {slot}] Generation failed: {e}")
        if stop_event.is_set():
            return  # cancelled — skip fallback too

        try:
            fallback = humanize_pattern(
                pattern,
                timing_variance=0.005 + 0.02 * spice,
                velocity_variance=0.05 + 0.1 * spice
            )
            output_file = variations_dir / f"track_0_drums_var{slot}.txt"
            fallback.to_file(str(output_file))
            written_slots.add(slot)
            print(f"  [Slot {slot}] Fallback saved")
            if osc_client:
                try:
                    osc_client.send_message("/chuloopa/bank_progress", slot)
                except Exception:
                    pass
        except Exception as e2:
            print(f"  [Slot {slot}] Fallback also failed: {e2}")


# =============================================================================
# FILE WATCHING
# =============================================================================

if HAVE_WATCHDOG:
    class DrumFileHandler(FileSystemEventHandler):
        """Watch for changes to drum pattern files."""

        def __init__(self, variation_type: str = 'rhythmic_creator',
                     auto_generate: bool = True,
                     cooldown: float = 2.0):
            """
            Args:
                variation_type: Type of variation to generate
                auto_generate: Whether to auto-generate on file change
                cooldown: Seconds to wait before processing (debounce)
            """
            self.variation_type = variation_type
            self.auto_generate = auto_generate
            self.cooldown = cooldown
            self.last_modified = {}

        def on_modified(self, event):
            if event.is_directory:
                return

            filepath = Path(event.src_path)

            # Only watch track_0_drums.txt (not variations)
            if filepath.name != 'track_0_drums.txt':
                return

            # Ignore variations directory
            if 'variations' in str(filepath):
                return

            # Ignore AI-generated modifications (check for recent write)
            current_time = time.time()
            last_time = self.last_modified.get(str(filepath), 0)

            if current_time - last_time < self.cooldown:
                return

            self.last_modified[str(filepath)] = current_time

            print(f"\nDetected change: {filepath}")

            if self.auto_generate:
                # Wait a moment for file to finish writing
                time.sleep(0.5)

                try:
                    cancel_generation()
                    generate_variation_bank(filepath, self.variation_type)
                except Exception as e:
                    error_msg = f"Error generating variation bank: {e}"
                    print(error_msg)
                    if osc_client:
                        osc_client.send_message("/chuloopa/error", error_msg)


def watch_directory(directory: str, variation_type: str = 'gemini'):
    """Watch directory for drum file changes and listen for OSC messages."""
    global osc_client, current_variation_type

    # Set the global variation type so OSC handlers can use it
    current_variation_type = variation_type

    if not HAVE_WATCHDOG:
        print("Error: watchdog not installed. Install with: pip install watchdog")
        return

    if not HAVE_OSC:
        print("Error: python-osc not installed. Install with: pip install python-osc")
        return

    # Setup OSC client (for sending to ChucK)
    osc_client = udp_client.SimpleUDPClient(OSC_HOST, OSC_SEND_PORT)
    print(f"OSC client initialized - sending to {OSC_HOST}:{OSC_SEND_PORT}")

    # Send test message to verify connection
    print("Sending test message to ChucK...")
    osc_client.send_message("/chuloopa/generation_progress", "Python OSC test - connection established!")

    # Setup OSC server (for receiving from ChucK)
    disp = dispatcher.Dispatcher()
    disp.map("/chuloopa/regenerate", handle_regenerate)
    disp.map("/chuloopa/track_cleared", handle_track_cleared)

    server = osc_server.ThreadingOSCUDPServer((OSC_HOST, OSC_RECEIVE_PORT), disp)
    print(f"OSC server listening on {OSC_HOST}:{OSC_RECEIVE_PORT}")

    # Start OSC server in background thread
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.daemon = True
    server_thread.start()

    # Setup file watcher (auto_generate=True: generate bank automatically on new recording)
    handler = DrumFileHandler(variation_type=variation_type, auto_generate=True)
    observer = Observer()
    observer.schedule(handler, directory, recursive=False)
    observer.start()

    print(f"\nWatching for drum file changes in: {directory}")
    print(f"Variation type: {variation_type}{' (HEURISTIC MODE - AI disabled)' if use_no_ai else ''}")
    print(f"Device: {'CPU (forced)' if force_cpu else 'Auto-detect (MPS/CUDA/CPU)'}")
    print(f"Timing anchor: {'DISABLED (default — AI timing preserved)' if use_no_anchor else 'ENABLED (--anchor)'}")
    print(f"Time-warping: {'DISABLED (natural timing)' if use_no_warp else 'enabled'}")
    print("\nWaiting for OSC /chuloopa/regenerate message from ChucK...")
    print("Press Ctrl+C to stop\n")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nShutting down...")
        observer.stop()
        server.shutdown()

    observer.join()
    server_thread.join(timeout=1)


# =============================================================================
# MAIN VARIATION GENERATOR
# =============================================================================

def generate_variation(pattern: DrumPattern,
                       variation_type: str = 'rhythmic_creator',
                       **kwargs) -> DrumPattern:
    """Generate a variation of the input pattern.

    Args:
        pattern: Input drum pattern
        variation_type: One of:
            - 'rhythmic_creator': (DEFAULT) Jake Chen's Transformer-LSTM+FNN model
            - 'gemini': Use Gemini AI for intelligent variations
            - 'groove_preserve': Preserve structure, add subtle feel
            - 'humanize': Add subtle timing/velocity variations
            - 'mutate': Swap/add/remove hits
            - 'densify': Add more hits
            - 'simplify': Remove hits
            - 'shift': Rotate pattern in time
            - 'random': Apply random combination of variations
        **kwargs: Additional arguments for specific variation types

    Returns:
        Tuple of (DrumPattern, success: bool)
    """
    # Check if AI is disabled (--no-ai flag)
    if use_no_ai and variation_type in ['rhythmic_creator', 'gemini']:
        print(f"  Skipping {variation_type} (--no-ai): using heuristic generation")
        spice = kwargs.get('temperature', 0.5)
        return generate_musical_variation(pattern, spice), True  # True = intentional heuristic mode, not a failure

    if variation_type == 'rhythmic_creator':
        return rhythmic_creator_variation(pattern, spice_level=kwargs.get('temperature', 0.7))

    elif variation_type == 'gemini':
        return gemini_variation(pattern, spice_level=kwargs.get('spice_level', kwargs.get('temperature', 0.5)))

    elif variation_type == 'groove_preserve':
        return groove_preserve(
            pattern,
            timing_variance=kwargs.get('timing_variance', 0.015),
            velocity_variance=kwargs.get('velocity_variance', 0.08),
            accent_shift=kwargs.get('accent_shift', 0.1),
            swap_probability=kwargs.get('swap_probability', 0.05)
        )

    elif variation_type == 'humanize':
        return humanize_pattern(
            pattern,
            timing_variance=kwargs.get('timing_variance', 0.02),
            velocity_variance=kwargs.get('velocity_variance', 0.1)
        )

    elif variation_type == 'mutate':
        return mutate_pattern(
            pattern,
            swap_probability=kwargs.get('swap_probability', 0.2),
            add_probability=kwargs.get('add_probability', 0.1),
            remove_probability=kwargs.get('remove_probability', 0.1)
        )

    elif variation_type == 'densify':
        return densify_pattern(
            pattern,
            fill_probability=kwargs.get('fill_probability', 0.3)
        )

    elif variation_type == 'simplify':
        return simplify_pattern(
            pattern,
            keep_probability=kwargs.get('keep_probability', 0.6)
        )

    elif variation_type == 'shift':
        return shift_pattern(
            pattern,
            shift_amount=kwargs.get('shift_amount', None)
        )

    elif variation_type == 'random':
        # Apply random combination of variations
        result = pattern.copy()

        # Always humanize a bit
        result = humanize_pattern(result, timing_variance=0.015, velocity_variance=0.08)

        # Randomly apply other variations
        if random.random() < 0.3:
            result = mutate_pattern(result, swap_probability=0.15,
                                    add_probability=0.1, remove_probability=0.05)

        if random.random() < 0.2:
            result = densify_pattern(result, fill_probability=0.2)

        if random.random() < 0.15:
            result = shift_pattern(result)

        return result

    else:
        print(f"Unknown variation type: {variation_type}, using rhythmic_creator")
        return rhythmic_creator_variation(pattern, temperature=kwargs.get('temperature', 0.7))


def generate_variation_for_file(filepath: str,
                                 variation_type: str = 'rhythmic_creator',
                                 backup: bool = False,
                                 **kwargs) -> bool:
    """Load pattern from file, generate 1 variation, and save to variations directory.

    Args:
        filepath: Path to drum pattern file
        variation_type: Type of variation to apply
        backup: If True, save backup before generating
        **kwargs: Additional arguments for variation generator

    Returns:
        True if successful
    """
    try:
        # Load pattern
        print(f"Loading: {filepath}")
        pattern = DrumPattern.from_file(filepath)

        if not pattern.hits:
            print("Warning: No hits found in pattern")
            return False

        print(f"  Loaded {len(pattern.hits)} hits, duration: {pattern.loop_duration:.3f}s")
        print(f"  Using spice level: 0.5 (default)")

        # Optional backup
        if backup:
            backup_path = filepath + '.backup'
            pattern.to_file(backup_path)
            print(f"  Backup saved: {backup_path}")

        # Create variations directory
        filepath_obj = Path(filepath)
        variations_dir = filepath_obj.parent / "variations"
        variations_dir.mkdir(parents=True, exist_ok=True)

        # Generate 1 variation
        print(f"\n  Generating variation")
        varied, success = generate_variation(pattern, variation_type, **kwargs)

        if not success:
            print("Warning: Variation generation returned failure flag")

        output_file = variations_dir / f"{filepath_obj.stem}_var1.txt"
        varied.to_file(str(output_file))
        print(f"  Saved: {output_file}")

        print(f"\n✓ Generated variation successfully!")

        return True

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False


# =============================================================================
# CLI
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Generate AI-powered drum pattern variations for CHULOOPA',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Watch for file changes and auto-generate (RECOMMENDED)
    python drum_variation_ai.py --watch

    # The watch mode will:
    #   - Listen for OSC messages from ChucK (spice level, regenerate requests)
    #   - Watch src/tracks/track_0/track_0_drums.txt for changes
    #   - Auto-generate 1 variation to src/tracks/track_0/variations/
    #   - Send OSC notifications back to ChucK when ready

    # Manual generation for track 0
    python drum_variation_generator.py --track 0

    # Generate variations for specific file
    python drum_variation_generator.py --file src/tracks/track_0/track_0_drums.txt

Variation Types:
    gemini           (default) Uses Gemini AI for intelligent cohesive variations
    groove_preserve  Keeps exact structure, adds subtle feel/accents
    humanize         Simple timing/velocity variations
    mutate           Swaps/adds/removes hits
    densify          Adds fill hits in gaps
    simplify         Removes some hits
    shift            Rotates pattern in time
    random           Combines multiple variation types

Performance Options:
    --cpu               Force CPU inference instead of GPU
                        • More consistent performance (no thermal throttling)
                        • Slower (~15-25s per generation)
                        • Recommended for M1/M2 MacBook Air (fanless)

    Default (MPS/GPU):  Auto-detect GPU acceleration
                        • Faster when cool (~8-15s per generation)
                        • May throttle when hot (20-60s)
                        • Recommended for M1/M2 Pro/Max with fans

Variation Control:
    --no-ai             Skip AI entirely, use fast heuristic algorithm
                        • Instant generation (<0.1s)
                        • Uses drumming techniques: doubling, ghost notes, triplets
                        • Preserves exact loop duration
                        • Controlled by spice level
                        • Good for testing or low-latency workflows

    --context-loops N   Repeat loop N times in context (1 or 2)
                        • Default: 2 (doubled pattern reinforces looping)
                        • 1 = single loop (minimal context, less loop-aware)
                        • 2 = doubled (RECOMMENDED, best results)
                        • Higher values (4+) exceed model's vocabulary range
                        • Only affects rhythmic_creator, not Gemini

    --anchor            Enable timing anchoring (snaps AI hits to original timing grid)
                        • Off by default — AI timing is trusted as-is
                        • Use if variations feel rhythmically misaligned with original
                        • Recommended for more adventurous variations

    Default (anchored): Snap AI hits to original pattern's timing grid
                        • Safer, stays closer to original groove
                        • May remove many AI-generated hits

OSC Communication:
    Receives on port 5000:
      /chuloopa/regenerate           - Regenerate variations
      /chuloopa/track_cleared        - Track cleared notification

    Sends to port 5001:
      /chuloopa/variations_ready <int>    - Number of variations ready
      /chuloopa/generation_progress <str> - Status updates
      /chuloopa/error <str>               - Error messages
        """
    )

    parser.add_argument('--track', '-t', type=int, choices=[0, 1, 2],
                        help='Track number (0-2)')

    parser.add_argument('--file', '-f', type=str,
                        help='Path to drum pattern file')

    parser.add_argument('--type', '-T', type=str, default='rhythmic_creator',
                        choices=['rhythmic_creator', 'gemini', 'groove_preserve', 'humanize', 'mutate',
                                 'densify', 'simplify', 'shift', 'random'],
                        help='Variation type (default: rhythmic_creator)')

    parser.add_argument('--watch', '-w', action='store_true',
                        help='Watch for file changes and auto-generate')

    parser.add_argument('--dir', '-d', type=str, default=str(DEFAULT_TRACK_DIR),
                        help='Directory containing track files')

    parser.add_argument('--backup', '-b', action='store_true',
                        help='Create backup before overwriting')

    parser.add_argument('--temperature', type=float, default=0.7,
                        help='Gemini sampling temperature (0.0-1.0, default 0.7)')

    parser.add_argument('--warp', action='store_true',
                        help='Enable time-warping to fit exact loop duration (off by default)')

    parser.add_argument('--cpu', action='store_true',
                        help='Force CPU inference (more consistent, avoids thermal throttling on MPS/GPU)')

    parser.add_argument('--anchor', action='store_true',
                        help='Enable timing anchoring (snaps AI hits to original timing grid; off by default)')

    parser.add_argument('--no-ai', action='store_true',
                        help='Skip AI generation, use fast heuristic algorithm instead (instant generation)')

    parser.add_argument('--context-loops', type=int, default=1, choices=[1, 2],
                        help='How many times to repeat loop in context (1 or 2, default: 2)')

    args = parser.parse_args()

    # Set global flags
    global use_no_warp, force_cpu, use_no_anchor, use_no_ai, context_loops
    use_no_warp = not args.warp
    force_cpu = args.cpu
    use_no_anchor = not args.anchor  # Default True (anchoring OFF); --anchor enables it
    use_no_ai = args.no_ai
    context_loops = args.context_loops

    print("=" * 60)
    print("  CHULOOPA Drum Variation AI")
    print("=" * 60)
    if use_no_ai:
        print("  Mode: HEURISTIC (AI disabled - instant generation)")
    elif force_cpu:
        print("  Device: CPU (forced - consistent performance)")
    print()

    # Watch mode
    if args.watch:
        watch_directory(str(DEFAULT_TRACK_DIR), args.type)
        return

    # Determine file path (for manual generation)
    if args.file:
        filepath = args.file
    elif args.track is not None:
        # For backwards compatibility, but we're focusing on track_0
        filepath = str(DEFAULT_TRACK_DIR / f"track_{args.track}_drums.txt")
    else:
        print("Error: Specify --track or --file")
        parser.print_help()
        sys.exit(1)

    # Check file exists
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}")
        sys.exit(1)

    # Generate variation
    kwargs = {
        'temperature': args.temperature,
    }

    success = generate_variation_for_file(
        filepath,
        variation_type=args.type,
        backup=args.backup,
        **kwargs
    )

    if success:
        print("\n✓ Variation generated successfully!")
        print("File saved to variations/ subdirectory")
        print("Use MIDI trigger (D1/Note 38) in CHULOOPA to load variation.")
    else:
        print("\n✗ Failed to generate variation.")
        sys.exit(1)


if __name__ == '__main__':
    main()
