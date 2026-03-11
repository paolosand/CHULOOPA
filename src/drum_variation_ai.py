#!/usr/bin/env python3
"""
drum_variation_ai.py - AI-powered drum pattern variation generator for CHULOOPA

This script generates variations of drum patterns using Gemini AI or algorithmic
methods. It overwrites the original files so that chuloopa_drums_v2.ck can load
the variations via MIDI triggers.

Architecture:
    1. Load drum pattern from track_N_drums.txt
    2. Generate variation using Gemini AI (or fallback algorithm)
    3. Convert back to CHULOOPA format with delta_times
    4. Overwrite original file

Usage:
    # Generate variation for a specific track (uses gemini by default)
    python drum_variation_ai.py --track 0

    # Watch for file changes and auto-generate variations
    python drum_variation_ai.py --watch

    # Use specific variation type
    python drum_variation_ai.py --track 0 --type humanize
    python drum_variation_ai.py --track 0 --type gemini
    python drum_variation_ai.py --track 0 --type mutate

Requirements:
    pip install numpy watchdog google-genai
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
GEMINI_MODEL = 'gemini-3-flash-preview'

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
current_spice_level = 0.5  # Default spice level
use_no_warp = False  # Skip time-warping if True
current_variation_type = 'gemini'  # Default variation type (gemini or rhythmic_creator)


# =============================================================================
# DATA STRUCTURES
# =============================================================================

@dataclass
class DrumHit:
    """Single drum hit with timing and velocity."""
    drum_class: int      # 0=kick, 1=snare, 2=hat
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

                # Parse data line: DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME
                try:
                    parts = line.split(',')
                    if len(parts) >= 4:
                        hit = DrumHit(
                            drum_class=int(parts[0]),
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
            f.write(f"# Format: DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME\n")
            f.write(f"# Classes: 0=kick, 1=snare, 2=hat\n")
            f.write(f"# DELTA_TIME: Duration until next hit (for last hit: time until loop end)\n")
            f.write(f"# Total loop duration: {self.loop_duration:.6f} seconds\n")

            # Write hits with velocity normalization to 0.7-0.9 range
            for hit in self.hits:
                # Normalize velocity: clamp to 0-1, then map to 0.7-0.9
                normalized_velocity = max(0.0, min(1.0, hit.velocity))
                normalized_velocity = 0.7 + (normalized_velocity * 0.2)
                f.write(f"{hit.drum_class},{hit.timestamp:.6f},{normalized_velocity:.6f},{hit.delta_time:.6f}\n")

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
            hits=[DrumHit(h.drum_class, h.timestamp, h.velocity, h.delta_time)
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

        # Maybe swap drum class
        if random.random() < swap_probability:
            # Swap to a different class
            other_classes = [c for c in [0, 1, 2] if c != hit.drum_class]
            hit.drum_class = random.choice(other_classes)

        new_hits.append(hit)

        # Maybe add a ghost note
        if random.random() < add_probability:
            ghost_offset = random.uniform(0.05, 0.15)
            ghost_timestamp = hit.timestamp + ghost_offset

            if ghost_timestamp < result.loop_duration:
                ghost_hit = DrumHit(
                    drum_class=random.choice([0, 1, 2]),
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
                    drum_class=2,  # Usually hats for fills
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
                    drum_class=model_hit.drum_class,  # Trust model's choice
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
                drum_class=hit.drum_class,
                timestamp=new_timestamp,
                velocity=hit.velocity,
                delta_time=0.0  # Will recalculate
            ))

    # Create pattern and recalculate delta_times
    result = DrumPattern(hits=fitted_hits, loop_duration=target_duration)
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
        if hit.drum_class == 0:
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
        if hit.drum_class == 0:  # kick - tighter timing
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
        if is_downbeat and hit.drum_class == 0:  # Kick on downbeat
            vel_shift += accent_shift * random.uniform(0.5, 1.0)
        elif is_backbeat and hit.drum_class == 1:  # Snare on backbeat
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
    from format_converters import chuloopa_to_rhythmic_creator, rhythmic_creator_to_chuloopa
    HAVE_RHYTHMIC_CREATOR = True
except ImportError as e:
    HAVE_RHYTHMIC_CREATOR = False
    print(f"Note: rhythmic_creator not available: {e}")

# Global model instance
rhythmic_model = None


def init_rhythmic_creator():
    """Initialize rhythmic creator model (call once at startup)."""
    global rhythmic_model

    if not HAVE_RHYTHMIC_CREATOR:
        return False

    try:
        rhythmic_model = get_rhythmic_model()
        return True
    except Exception as e:
        print(f"Warning: Failed to load rhythmic_creator: {e}")
        return False


def rhythmic_creator_variation(pattern: DrumPattern,
                               temperature: float = 0.7) -> tuple:
    """
    Generate variation using Jake Chen's Transformer-LSTM+FNN model.

    This function:
    1. Uses full pattern as context (gives model complete groove understanding)
    2. Generates continuation with temperature control
    3. Time-warps result to match original loop duration
    4. Returns variation with same duration as original

    Args:
        pattern: Input drum pattern
        temperature: Spice level (0.5-1.5)
                    - 0.5-0.9: Conservative (stays close to training)
                    - 1.0: Normal sampling
                    - 1.1-1.5: Creative (more variation)

    Returns:
        Tuple of (DrumPattern, success: bool)
    """
    global rhythmic_model

    # Initialize model if needed
    if rhythmic_model is None:
        if not init_rhythmic_creator():
            print("  Rhythmic creator not available, falling back to groove_preserve")
            return groove_preserve(pattern), False

    try:
        # Use full pattern as context (gives model complete groove understanding)
        context_hits = pattern.hits

        # Create context pattern
        context_pattern = DrumPattern(
            hits=context_hits,
            loop_duration=pattern.loop_duration
        )

        # Convert to rhythmic_creator format
        context_text = chuloopa_to_rhythmic_creator(context_pattern)

        if not context_text:
            print("  Warning: Empty context, falling back")
            return groove_preserve(pattern), False

        # Calculate how many tokens to generate
        # Model outputs [context echo] + [continuation]
        # Some continuation hits may use invalid MIDI (melody notes) that get filtered
        # Generate 6-8x pattern length to ensure enough valid drum hits in continuation
        # For a 4-hit input, this generates 24-32 new tokens (~8-10 hits after filtering)
        num_tokens = max(60, len(pattern.hits) * 18)

        print(f"  Generating with rhythmic_creator (temp={temperature:.2f})...")
        print(f"    Context: {len(context_hits)} hits (full pattern)")
        print(f"    Generating: {num_tokens} tokens (~{num_tokens//3} hits)")

        # Generate continuation
        # Note: Model outputs [context echo] + [continuation from context end]
        # Jake's model does conditional generation = extends the pattern, not replaces it
        generated_text = rhythmic_model.generate_variation(
            input_pattern=context_text,
            num_tokens=num_tokens,
            temperature=temperature
        )

        generated_tokens = generated_text.split()
        context_tokens = context_text.split()
        print(f"    Generated: {len(generated_tokens)} tokens ({len(generated_tokens)//3} hits)")

        # The model echoes context then generates continuation
        # We need to strip the context echo to avoid layering original over variation
        if len(generated_tokens) > len(context_tokens):
            # Strip context echo - keep only NEW tokens
            new_tokens = generated_tokens[len(context_tokens):]
            new_text = ' '.join(new_tokens)
            print(f"    Stripping context: {len(new_tokens)} new tokens ({len(new_tokens)//3} new hits)")
        else:
            # Model didn't generate enough - use full output
            new_text = generated_text
            print(f"    Warning: Output shorter than context, using full output")

        # Convert NEW tokens to CHULOOPA
        # The model generates continuation starting from where context ended
        # This continuation is the variation we want!
        new_pattern = rhythmic_creator_to_chuloopa(new_text, loop_duration=999)

        if not new_pattern.hits:
            print("  Warning: No valid hits in new pattern, falling back")
            return groove_preserve(pattern), False

        # The continuation starts after the last hit in the original pattern
        # Find original end time
        original_end = max(hit.timestamp for hit in pattern.hits)

        # Take continuation hits (those that come after original pattern)
        continuation_hits = [
            hit for hit in new_pattern.hits
            if hit.timestamp > original_end
        ]

        # Also take any hits near the start (loop wrap) as fallback
        wrap_hits = [
            hit for hit in new_pattern.hits
            if hit.timestamp <= original_end
        ]

        # GROOVE PRESERVATION STRATEGY:
        # Prefer whichever set has density closer to original pattern
        # This preserves the sparse/dense feel of the input
        original_density = len(pattern.hits)
        cont_density = len(continuation_hits)
        wrap_density = len(wrap_hits)

        # Calculate how far each is from original density
        cont_diff = abs(cont_density - original_density)
        wrap_diff = abs(wrap_density - original_density)

        # Use whichever is closer to original density (prefer wrap on tie)
        use_continuation = cont_diff < wrap_diff and cont_density >= 3

        source_hits = continuation_hits if use_continuation else wrap_hits

        print(f"    DENSITY MATCHING: orig={original_density}, cont={cont_density} (diff={cont_diff}), wrap={wrap_density} (diff={wrap_diff})")

        if not source_hits:
            print("  Warning: No usable hits in generation, falling back")
            return groove_preserve(pattern), False

        # Shift hits to start at 0.0
        min_time = min(hit.timestamp for hit in source_hits)
        max_time = max(hit.timestamp for hit in source_hits)
        natural_duration = max_time - min_time

        shifted_hits = []
        for hit in source_hits:
            shifted_hits.append(DrumHit(
                drum_class=hit.drum_class,
                timestamp=hit.timestamp - min_time,
                velocity=hit.velocity,
                delta_time=0.0
            ))

        # Create raw pattern with natural duration
        raw_pattern = DrumPattern(hits=shifted_hits, loop_duration=natural_duration)
        raw_pattern._recalculate_delta_times()

        source_type = "continuation" if use_continuation else "loop wrap"
        print(f"    Using {source_type} ({len(continuation_hits)} cont / {len(wrap_hits)} wrap): {len(raw_pattern.hits)} hits, duration={natural_duration:.2f}s")

        if not raw_pattern.hits:
            print("  Warning: Model generated empty pattern, falling back")
            return groove_preserve(pattern), False

        # Time-warp to fit exact loop duration (unless --no-warp is set)
        global use_no_warp
        if use_no_warp:
            # Use model's natural timing
            max_time = max(hit.timestamp for hit in raw_pattern.hits) if raw_pattern.hits else 0
            raw_pattern.loop_duration = max_time
            raw_pattern._recalculate_delta_times()
            variation = raw_pattern
            print(f"    Using natural timing: {max_time:.2f}s (no time-warping)")
        else:
            # Time-warp to original duration
            print(f"    Time-warping to {pattern.loop_duration:.2f}s...")
            variation = fit_to_loop_duration(raw_pattern, pattern.loop_duration)

            if not variation.hits:
                print("  Warning: No hits after time-warping, falling back")
                return groove_preserve(pattern), False

        print(f"    Final variation: {len(variation.hits)} hits")

        return variation, True

    except Exception as e:
        print(f"  Warning: rhythmic_creator generation failed: {e}")
        import traceback
        traceback.print_exc()
        print("  Falling back to groove_preserve")
        return groove_preserve(pattern), False


# =============================================================================
# GEMINI VARIATION GENERATOR
# =============================================================================

def pattern_to_gemini_prompt(pattern: DrumPattern) -> str:
    """Convert DrumPattern to Gemini prompt format."""
    lines = [
        f"Loop duration: {pattern.loop_duration:.6f} seconds",
        f"Total hits: {len(pattern.hits)}",
        "",
        "Pattern (DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME):",
        "# Classes: 0=kick, 1=snare, 2=hat"
    ]
    for hit in pattern.hits:
        lines.append(f"{hit.drum_class},{hit.timestamp:.6f},{hit.velocity:.6f},{hit.delta_time:.6f}")
    return "\n".join(lines)


def parse_gemini_pattern(pattern_text: str, loop_duration: float) -> DrumPattern:
    """Parse Gemini's pattern output back to DrumPattern."""
    hits = []
    for line in pattern_text.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split(',')
        if len(parts) >= 4:
            try:
                hits.append(DrumHit(
                    drum_class=int(parts[0]),
                    timestamp=float(parts[1]),
                    velocity=float(parts[2]),
                    delta_time=float(parts[3])
                ))
            except (ValueError, IndexError):
                continue
    return DrumPattern(hits=hits, loop_duration=loop_duration)


def gemini_variation(pattern: DrumPattern, temperature: float = 0.7) -> DrumPattern:
    """Generate variation using Gemini AI.

    Args:
        pattern: Input drum pattern
        temperature: Sampling temperature (0.0-1.0, default 0.7)

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

    try:
        # Client reads API key from GEMINI_API_KEY environment variable
        client = genai.Client()

        system_prompt = f"""You are a drum loop generator. Given an input drum pattern you will output a variation of an existing drum pattern given the previous pattern and the output variant's target "spice" level. While maintaining the same key groove and ensuring that the total loop duration is exactly the same. Ensure you always understand the user's groove first before trying to variate.

Add natural human variation through subtle timing shifts, velocity changes, and ghost notes to make the loop feel "alive" like a real drummer playing the groove.

Return the output in the following json format:
{{"reasoning": "", "pattern": ""}}

The pattern field should contain the drum data in the exact same CSV format as the input:
DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME
Where:
- DRUM_CLASS: 0=kick, 1=snare, 2=hat
- TIMESTAMP: seconds from loop start
- VELOCITY: 0.0-1.0
- DELTA_TIME: seconds until next hit (last hit's delta_time = time until loop end)

CRITICAL: The sum of all delta_times must equal the loop duration exactly.

SPICE LEVEL: A float from 0.0 to 1.0 indicating how much variation to apply:
- 0.0 = minimal variation (very close to original)
- 0.5 = moderate variation
- 1.0 = maximum variation (more creative changes)

SPICE LEVEL for this request: {temperature}"""

        user_prompt = pattern_to_gemini_prompt(pattern)

        print(f"  Calling Gemini API ({GEMINI_MODEL})...")
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=system_prompt + "\n\nInput pattern:\n" + user_prompt,
            config={"temperature": temperature}
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
        print(f"  Gemini reasoning: {result.get('reasoning', 'No reasoning provided')}")

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

def handle_spice_change(address, spice_level):
    """Handle spice level change from ChucK."""
    global current_spice_level
    current_spice_level = max(0.0, min(1.0, spice_level))
    print(f"\n>>> OSC RECEIVED from ChucK: /chuloopa/spice = {current_spice_level:.2f} <<<\n")


def handle_regenerate(address):
    """Handle regenerate request from ChucK."""
    global current_variation_type

    print(f"\n{'='*60}")
    print("GENERATE requested from ChucK (D#1 / Note 39)")
    print(f"{'='*60}")

    track_file = DEFAULT_TRACK_DIR / "track_0_drums.txt"

    if not track_file.exists():
        error_msg = f"Error: Original track file not found: {track_file}"
        print(error_msg)
        if osc_client:
            osc_client.send_message("/chuloopa/error", error_msg)
        return

    try:
        generate_variations_for_track(track_file, variation_type=current_variation_type)
    except Exception as e:
        error_msg = f"Error generating variations: {e}"
        print(error_msg)
        if osc_client:
            osc_client.send_message("/chuloopa/error", error_msg)


def handle_track_cleared(address):
    """Handle track cleared notification from ChucK."""
    print("Track cleared notification received")
    # Could delete variations here if desired
    # For now, just log it


def generate_variations_for_track(track_file: Path, variation_type: str = 'rhythmic_creator'):
    """Generate 1 variation for a track file and send OSC notification."""
    global osc_client, current_spice_level

    print(f"Loading: {track_file}")
    pattern = DrumPattern.from_file(str(track_file))

    if not pattern.hits:
        error_msg = "Warning: No hits found in pattern"
        print(error_msg)
        if osc_client:
            osc_client.send_message("/chuloopa/error", error_msg)
        return

    print(f"  Loaded {len(pattern.hits)} hits, duration: {pattern.loop_duration:.3f}s")
    print(f"  Current spice level: {current_spice_level:.2f}")

    # Create variations directory if it doesn't exist
    variations_dir = DEFAULT_VARIATIONS_DIR
    variations_dir.mkdir(parents=True, exist_ok=True)

    # Generate 1 variation
    if osc_client:
        osc_client.send_message("/chuloopa/generation_progress", f"Generating variation...")

    print(f"\n  Generating variation (spice: {current_spice_level:.2f})")
    varied, success = generate_variation(pattern, variation_type, temperature=current_spice_level)

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
        print(f"\n✓ Generated variation (spice: {current_spice_level:.2f})")
    else:
        print(f"\n✗ Generation FAILED - used fallback (spice: {current_spice_level:.2f})")
        print(f"  Press D#1 in ChucK to try again")
    print(f"{'='*60}\n")


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
                    generate_variations_for_track(filepath, self.variation_type)
                except Exception as e:
                    error_msg = f"Error generating variations: {e}"
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
    disp.map("/chuloopa/spice", handle_spice_change)
    disp.map("/chuloopa/regenerate", handle_regenerate)
    disp.map("/chuloopa/track_cleared", handle_track_cleared)

    server = osc_server.ThreadingOSCUDPServer((OSC_HOST, OSC_RECEIVE_PORT), disp)
    print(f"OSC server listening on {OSC_HOST}:{OSC_RECEIVE_PORT}")

    # Start OSC server in background thread
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.daemon = True
    server_thread.start()

    # Setup file watcher (auto_generate=False means only generate on OSC request)
    handler = DrumFileHandler(variation_type=variation_type, auto_generate=False)
    observer = Observer()
    observer.schedule(handler, directory, recursive=False)
    observer.start()

    print(f"\nWatching for drum file changes in: {directory}")
    print(f"Variation type: {variation_type}")
    print(f"Time-warping: {'DISABLED (natural timing)' if use_no_warp else 'enabled'}")
    print(f"Current spice level: {current_spice_level:.2f}")
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
    if variation_type == 'rhythmic_creator':
        return rhythmic_creator_variation(pattern, temperature=kwargs.get('temperature', 0.7))

    elif variation_type == 'gemini':
        return gemini_variation(pattern, temperature=kwargs.get('temperature', 0.7))

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
        print(f"  Using spice level: {current_spice_level:.2f}")

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
        print(f"\n  Generating variation (spice: {current_spice_level:.2f})")
        varied = generate_variation(pattern, variation_type, temperature=current_spice_level, **kwargs)

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
    python drum_variation_ai.py --track 0

    # Generate variations for specific file
    python drum_variation_ai.py --file src/tracks/track_0/track_0_drums.txt

Variation Types:
    gemini           (default) Uses Gemini AI for intelligent cohesive variations
    groove_preserve  Keeps exact structure, adds subtle feel/accents
    humanize         Simple timing/velocity variations
    mutate           Swaps/adds/removes hits
    densify          Adds fill hits in gaps
    simplify         Removes some hits
    shift            Rotates pattern in time
    random           Combines multiple variation types

OSC Communication:
    Receives on port 5000:
      /chuloopa/spice <float>        - Spice level (0.0-1.0)
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

    parser.add_argument('--no-warp', action='store_true',
                        help='Skip time-warping (use model\'s natural timing)')

    args = parser.parse_args()

    # Set global no_warp flag
    global use_no_warp
    use_no_warp = args.no_warp

    print("=" * 60)
    print("  CHULOOPA Drum Variation AI")
    print("=" * 60)
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
