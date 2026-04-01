#!/usr/bin/env python3
"""
test_timing.py - Test rhythmic_creator generation timing

Run this to diagnose where the slowdown is happening.
"""

import sys
import time
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern, rhythmic_creator_variation

def main():
    print("=" * 70)
    print("  RHYTHMIC_CREATOR TIMING DIAGNOSTIC")
    print("=" * 70)
    print()

    # Load a real pattern
    track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"

    if not track_file.exists():
        print(f"Error: Track file not found: {track_file}")
        print("Please record a drum loop first using ChucK")
        return 1

    print(f"Loading test pattern: {track_file}")
    pattern = DrumPattern.from_file(str(track_file))

    if not pattern.hits:
        print("Error: No hits in pattern")
        return 1

    print(f"  Pattern: {len(pattern.hits)} hits, {pattern.loop_duration:.2f}s duration")
    print()

    # Run 3 generations to see consistency
    print("Running 3 test generations...")
    print()

    for i in range(3):
        print(f"\n{'='*70}")
        print(f"  GENERATION {i+1}/3")
        print(f"{'='*70}")

        start = time.time()
        varied, success = rhythmic_creator_variation(pattern, spice_level=0.5)
        total = time.time() - start

        print(f"\nGeneration {i+1} complete: {total:.2f}s total")
        print(f"  Success: {success}")
        print(f"  Output: {len(varied.hits)} hits")
        print()

    print("=" * 70)
    print("DIAGNOSTIC COMPLETE")
    print("=" * 70)
    print()
    print("Look for the ⏱️ timing markers above to see where time is spent:")
    print("  - Model init: Should be <0.1s after first run")
    print("  - MODEL GENERATION: The core inference time")
    print("  - Timing anchor: Post-processing time")
    print()

if __name__ == '__main__':
    sys.exit(main())
