#!/usr/bin/env python3
"""
drum_variation_ai.py - AI-powered drum pattern variation generator for CHULOOPA

This script monitors drum pattern files and generates variations using GrooVAE
or fallback algorithmic methods. It overwrites the original files so that
chuloopa_drums_v2.ck can load the variations via MIDI triggers.

Architecture:
    1. Load drum pattern from track_N_drums.txt
    2. Convert to GrooVAE-compatible format (quantized pianoroll)
    3. Generate variation using GrooVAE (or fallback algorithm)
    4. Convert back to CHULOOPA format with delta_times
    5. Overwrite original file

Usage:
    # Generate variation for a specific track (manual mode)
    python drum_variation_ai.py --track 0

    # Watch for file changes and auto-generate variations
    python drum_variation_ai.py --watch

    # Use specific variation type
    python drum_variation_ai.py --track 0 --type humanize
    python drum_variation_ai.py --track 0 --type groove_vae
    python drum_variation_ai.py --track 0 --type mutate

Requirements:
    pip install numpy watchdog

    For GrooVAE:
    pip install magenta note-seq tensorflow
"""

import os
import sys
import argparse
import time
import random
from dataclasses import dataclass
from typing import List, Optional, Tuple, TYPE_CHECKING
from pathlib import Path

import numpy as np

# Optional imports for GrooVAE
try:
    import note_seq
    from note_seq.protobuf import music_pb2
    HAVE_NOTE_SEQ = True
except ImportError:
    HAVE_NOTE_SEQ = False
    print("Note: note_seq not installed. GrooVAE features disabled.")
    print("      Install with: pip install note-seq")

try:
    from magenta.models.music_vae import configs
    from magenta.models.music_vae.trained_model import TrainedModel
    HAVE_MAGENTA = True
except ImportError:
    HAVE_MAGENTA = False
    print("Note: magenta not installed. Using fallback algorithms.")
    print("      Install with: pip install magenta")

# Optional file watching
try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
    HAVE_WATCHDOG = True
except ImportError:
    HAVE_WATCHDOG = False


# =============================================================================
# CONFIGURATION
# =============================================================================

# CHULOOPA drum class mapping to General MIDI drum pitches
DRUM_CLASS_TO_MIDI = {
    0: 36,  # kick -> Bass Drum 1
    1: 38,  # snare -> Acoustic Snare
    2: 42,  # hat -> Closed Hi-Hat
}

MIDI_TO_DRUM_CLASS = {v: k for k, v in DRUM_CLASS_TO_MIDI.items()}

# GrooVAE configuration
STEPS_PER_QUARTER = 4  # 16th notes
QUARTERS_PER_BAR = 4
STEPS_PER_BAR = STEPS_PER_QUARTER * QUARTERS_PER_BAR  # 16 steps per bar

# Default paths
DEFAULT_TRACK_DIR = Path(__file__).parent.parent  # CHULOOPA root
DEFAULT_CHECKPOINT = DEFAULT_TRACK_DIR / "models" / "groovae_2bar_humanize" / "model.ckpt-3061"


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

            # Write hits
            for hit in self.hits:
                f.write(f"{hit.drum_class},{hit.timestamp:.6f},{hit.velocity:.6f},{hit.delta_time:.6f}\n")

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
# GROOVAE INTEGRATION
# =============================================================================

def estimate_bpm_from_duration(duration: float, min_bpm: float = 60, max_bpm: float = 180) -> Tuple[float, int]:
    """Estimate BPM from loop duration by assuming reasonable bar count.

    Tries 1, 2, and 4 bars and picks the one that gives a BPM in the reasonable range.

    Args:
        duration: Loop duration in seconds
        min_bpm: Minimum reasonable BPM
        max_bpm: Maximum reasonable BPM

    Returns:
        Tuple of (estimated_bpm, assumed_bars)
    """
    for bars in [2, 1, 4]:  # Try 2 bars first (most common), then 1, then 4
        # bars * 4 beats, BPM = (beats / duration) * 60
        bpm = (bars * 4 * 60) / duration
        if min_bpm <= bpm <= max_bpm:
            return bpm, bars

    # If none fit, default to 2 bars and clamp BPM
    bpm = (2 * 4 * 60) / duration
    bpm = max(min_bpm, min(max_bpm, bpm))
    return bpm, 2


class GrooVAEModel:
    """Wrapper for GrooVAE model."""

    def __init__(self, checkpoint_path: Optional[str] = None):
        """Initialize GrooVAE model.

        Args:
            checkpoint_path: Path to GrooVAE checkpoint file prefix (e.g., path/model.ckpt-3061).
                             If None, uses default checkpoint.
        """
        self.model = None
        self.config = None

        if not HAVE_MAGENTA:
            print("GrooVAE not available - magenta not installed")
            return

        # Use groovae_2bar_humanize config
        self.config = configs.CONFIG_MAP['groovae_2bar_humanize']

        # Use default checkpoint if not specified
        if checkpoint_path is None:
            checkpoint_path = str(DEFAULT_CHECKPOINT)

        self._load_checkpoint(checkpoint_path)

    def _load_checkpoint(self, checkpoint_path: str):
        """Load model from checkpoint.

        Args:
            checkpoint_path: Path to checkpoint file prefix (NOT directory).
                             e.g., 'models/groovae_2bar_humanize/model.ckpt-3061'
        """
        if not HAVE_MAGENTA:
            return

        # Suppress TensorFlow warnings during model loading
        import os
        os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

        try:
            self.model = TrainedModel(
                self.config,
                batch_size=1,
                checkpoint_dir_or_path=checkpoint_path
            )
            print(f"Loaded GrooVAE from: {checkpoint_path}")
        except Exception as e:
            print(f"Failed to load GrooVAE checkpoint: {e}")
            print(f"  Hint: checkpoint_path should be the file prefix, e.g., 'path/model.ckpt-3061'")
            self.model = None

    def is_available(self) -> bool:
        """Check if model is loaded and ready."""
        return self.model is not None

    def generate_variation(self, pattern: DrumPattern, temperature: float = 0.3) -> DrumPattern:
        """Generate variation using GrooVAE latent space interpolation.

        Args:
            pattern: Input drum pattern
            temperature: Amount of variation (0.0=identical, 1.0=very different)
                         Default 0.3 for subtle musical variations.

        Returns:
            New DrumPattern with variation, preserving exact original loop_duration
        """
        if not self.is_available():
            raise RuntimeError("GrooVAE model not loaded")

        # Estimate BPM from loop duration
        estimated_bpm, assumed_bars = estimate_bpm_from_duration(pattern.loop_duration)
        print(f"  Estimated {estimated_bpm:.1f} BPM ({assumed_bars} bars)")

        # Convert to NoteSequence with estimated tempo
        note_sequence = pattern_to_note_sequence(pattern, estimated_bpm)

        # Encode to latent space
        z, mu, sigma = self.model.encode([note_sequence])

        # Add variation by interpolating toward random point in latent space
        z_random = np.random.randn(*z.shape)
        z_varied = z + temperature * (z_random - z)

        # Decode back to sequence (32 steps = 2 bars at 16th note resolution)
        decoded = self.model.decode(z_varied, length=32)

        # Convert back to DrumPattern, scaling to original duration
        if decoded and len(decoded) > 0:
            return note_sequence_to_pattern(decoded[0], pattern.loop_duration)

        return pattern.copy()


def pattern_to_note_sequence(pattern: DrumPattern, bpm: float = 120.0) -> 'music_pb2.NoteSequence':
    """Convert DrumPattern to Magenta NoteSequence.

    Args:
        pattern: The drum pattern to convert
        bpm: Tempo in beats per minute

    Returns:
        NoteSequence with drum notes
    """
    if not HAVE_NOTE_SEQ:
        raise RuntimeError("note_seq not installed")

    sequence = music_pb2.NoteSequence()
    sequence.ticks_per_quarter = 480

    tempo = sequence.tempos.add()
    tempo.qpm = bpm
    tempo.time = 0.0

    for hit in pattern.hits:
        note = sequence.notes.add()
        note.pitch = DRUM_CLASS_TO_MIDI.get(hit.drum_class, 36)
        note.velocity = int(hit.velocity * 127)
        note.start_time = hit.timestamp
        note.end_time = hit.timestamp + 0.1  # Drums are short
        note.is_drum = True

    sequence.total_time = pattern.loop_duration

    return sequence


def note_sequence_to_pattern(sequence: 'music_pb2.NoteSequence',
                              target_duration: float) -> DrumPattern:
    """Convert Magenta NoteSequence back to DrumPattern.

    Scales all timestamps to fit within target_duration.
    """
    if not HAVE_NOTE_SEQ:
        raise RuntimeError("note_seq not installed")

    hits = []

    # First pass: collect all notes and find actual time span
    raw_notes = []
    for note in sequence.notes:
        if not note.is_drum:
            continue

        drum_class = MIDI_TO_DRUM_CLASS.get(note.pitch)
        if drum_class is None:
            # Map unknown drums to closest CHULOOPA class
            if note.pitch in [35, 36]:  # Bass drums
                drum_class = 0
            elif note.pitch in [37, 38, 39, 40]:  # Snares/claps
                drum_class = 1
            else:  # Hi-hats and cymbals
                drum_class = 2

        raw_notes.append((note.start_time, drum_class, note.velocity))

    if not raw_notes:
        return DrumPattern(hits=[], loop_duration=target_duration)

    # Calculate actual span of notes in the output
    min_time = min(n[0] for n in raw_notes)
    max_time = max(n[0] for n in raw_notes)
    source_span = max_time - min_time if max_time > min_time else 1.0

    # Scale factor to fit notes within target duration
    # Leave a small margin at the end for the last delta_time
    usable_duration = target_duration * 0.95
    scale_factor = usable_duration / source_span if source_span > 0 else 1.0

    # Second pass: create hits with scaled timestamps
    for start_time, drum_class, velocity in raw_notes:
        scaled_time = (start_time - min_time) * scale_factor
        hits.append(DrumHit(
            drum_class=drum_class,
            timestamp=scaled_time,
            velocity=velocity / 127.0,
            delta_time=0.0  # Will be recalculated
        ))

    return DrumPattern(hits=hits, loop_duration=target_duration)


# =============================================================================
# FALLBACK ALGORITHMIC VARIATIONS
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


# =============================================================================
# FILE WATCHING
# =============================================================================

if HAVE_WATCHDOG:
    class DrumFileHandler(FileSystemEventHandler):
        """Watch for changes to drum pattern files."""

        def __init__(self, variation_type: str = 'humanize',
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

            filepath = event.src_path
            if not filepath.endswith('_drums.txt'):
                return

            # Ignore AI-generated modifications (check for recent write)
            current_time = time.time()
            last_time = self.last_modified.get(filepath, 0)

            if current_time - last_time < self.cooldown:
                return

            self.last_modified[filepath] = current_time

            print(f"\nDetected change: {filepath}")

            if self.auto_generate:
                # Wait a moment for file to finish writing
                time.sleep(0.5)

                try:
                    generate_variation_for_file(filepath, self.variation_type)
                except Exception as e:
                    print(f"Error generating variation: {e}")


def watch_directory(directory: str, variation_type: str = 'humanize'):
    """Watch directory for drum file changes."""
    if not HAVE_WATCHDOG:
        print("Error: watchdog not installed. Install with: pip install watchdog")
        return

    handler = DrumFileHandler(variation_type=variation_type)
    observer = Observer()
    observer.schedule(handler, directory, recursive=False)
    observer.start()

    print(f"Watching for drum file changes in: {directory}")
    print(f"Variation type: {variation_type}")
    print("Press Ctrl+C to stop\n")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()

    observer.join()


# =============================================================================
# MAIN VARIATION GENERATOR
# =============================================================================

# Global GrooVAE model instance
_groovae_model: Optional[GrooVAEModel] = None


def get_groovae_model(checkpoint_path: Optional[str] = None) -> Optional[GrooVAEModel]:
    """Get or create GrooVAE model singleton."""
    global _groovae_model

    if _groovae_model is None:
        _groovae_model = GrooVAEModel(checkpoint_path)

    return _groovae_model if _groovae_model.is_available() else None


def generate_variation(pattern: DrumPattern,
                       variation_type: str = 'humanize',
                       **kwargs) -> DrumPattern:
    """Generate a variation of the input pattern.

    Args:
        pattern: Input drum pattern
        variation_type: One of:
            - 'humanize': Add subtle timing/velocity variations
            - 'mutate': Swap/add/remove hits
            - 'densify': Add more hits
            - 'simplify': Remove hits
            - 'shift': Rotate pattern in time
            - 'groove_vae': Use GrooVAE model (if available)
            - 'random': Apply random combination of variations
        **kwargs: Additional arguments for specific variation types

    Returns:
        New DrumPattern with variation applied
    """
    if variation_type == 'humanize':
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

    elif variation_type == 'groove_vae':
        model = get_groovae_model(kwargs.get('checkpoint_path'))
        if model:
            return model.generate_variation(
                pattern,
                temperature=kwargs.get('temperature', 0.5)
            )
        else:
            print("GrooVAE not available, falling back to humanize")
            return humanize_pattern(pattern)

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
        print(f"Unknown variation type: {variation_type}, using humanize")
        return humanize_pattern(pattern)


def generate_variation_for_file(filepath: str,
                                 variation_type: str = 'humanize',
                                 backup: bool = False,
                                 **kwargs) -> bool:
    """Load pattern from file, generate variation, and overwrite.

    Args:
        filepath: Path to drum pattern file
        variation_type: Type of variation to apply
        backup: If True, save backup before overwriting
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

        # Optional backup
        if backup:
            backup_path = filepath + '.backup'
            pattern.to_file(backup_path)
            print(f"  Backup saved: {backup_path}")

        # Generate variation
        print(f"  Generating variation: {variation_type}")
        varied = generate_variation(pattern, variation_type, **kwargs)

        print(f"  Result: {len(varied.hits)} hits")

        # Overwrite original
        varied.to_file(filepath)
        print(f"  Saved: {filepath}")

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
    # Generate variation for track 0
    python drum_variation_ai.py --track 0

    # Use GrooVAE model
    python drum_variation_ai.py --track 0 --type groove_vae

    # Watch for file changes
    python drum_variation_ai.py --watch

    # Generate variation for specific file
    python drum_variation_ai.py --file track_0_drums.txt --type mutate
        """
    )

    parser.add_argument('--track', '-t', type=int, choices=[0, 1, 2],
                        help='Track number (0-2)')

    parser.add_argument('--file', '-f', type=str,
                        help='Path to drum pattern file')

    parser.add_argument('--type', '-T', type=str, default='humanize',
                        choices=['humanize', 'mutate', 'densify', 'simplify',
                                 'shift', 'groove_vae', 'random'],
                        help='Variation type (default: humanize)')

    parser.add_argument('--watch', '-w', action='store_true',
                        help='Watch for file changes and auto-generate')

    parser.add_argument('--dir', '-d', type=str, default=str(DEFAULT_TRACK_DIR),
                        help='Directory containing track files')

    parser.add_argument('--backup', '-b', action='store_true',
                        help='Create backup before overwriting')

    parser.add_argument('--checkpoint', '-c', type=str,
                        help='Path to GrooVAE checkpoint (for groove_vae type)')

    parser.add_argument('--temperature', type=float, default=0.5,
                        help='GrooVAE sampling temperature (0.0-1.0)')

    args = parser.parse_args()

    print("=" * 60)
    print("  CHULOOPA Drum Variation AI")
    print("=" * 60)
    print()

    # Watch mode
    if args.watch:
        watch_directory(args.dir, args.type)
        return

    # Determine file path
    if args.file:
        filepath = args.file
    elif args.track is not None:
        filepath = os.path.join(args.dir, f"track_{args.track}_drums.txt")
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
        'checkpoint_path': args.checkpoint,
        'temperature': args.temperature,
    }

    success = generate_variation_for_file(
        filepath,
        variation_type=args.type,
        backup=args.backup,
        **kwargs
    )

    if success:
        print("\nVariation generated successfully!")
        print("Use MIDI trigger (G1/G#1/A1) in CHULOOPA to load the variation.")
    else:
        print("\nFailed to generate variation.")
        sys.exit(1)


if __name__ == '__main__':
    main()
