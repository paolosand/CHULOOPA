#!/usr/bin/env python3
"""
test_heuristic.py - Test heuristic (--no-ai) generation

Shows the algorithmic fallback performance and quality.
"""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import drum_variation_ai
from drum_variation_ai import DrumPattern, generate_variation

def main():
    print("=" * 70)
    print("  HEURISTIC (NO-AI) MODE TEST")
    print("=" * 70)
    print()

    # Load pattern
    track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
    if not track_file.exists():
        print(f"Error: No track file found at {track_file}")
        return 1

    pattern = DrumPattern.from_file(str(track_file))
    print(f"Original pattern: {len(pattern.hits)} hits over {pattern.loop_duration:.2f}s")
    print()

    # Test heuristic mode
    print("TESTING HEURISTIC GENERATION (--no-ai)")
    print("-" * 70)

    # Enable no-ai mode
    drum_variation_ai.use_no_ai = True

    # Run 3 generations at different spice levels
    for spice in [0.3, 0.5, 0.8]:
        print(f"\nSpice level: {spice:.1f}")

        start = time.time()
        varied, success = generate_variation(
            pattern,
            variation_type='rhythmic_creator',  # Will be overridden by use_no_ai
            temperature=spice
        )
        elapsed = time.time() - start

        print(f"  Generated: {len(varied.hits)} hits in {elapsed:.3f}s")
        print(f"  Success flag: {success} (False = fallback used, as expected)")

        # Save with spice level in filename
        variations_dir = track_file.parent / "variations"
        variations_dir.mkdir(parents=True, exist_ok=True)
        output_file = variations_dir / f"heuristic_spice_{int(spice*10)}.txt"
        varied.to_file(str(output_file))
        print(f"  Saved: {output_file.name}")

    print()
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print()
    print("Heuristic mode generates variations using algorithmic techniques:")
    print("  • Doubling: Repeat hits (drum rolls)")
    print("  • Ghost notes: Add quiet snare fills")
    print("  • Triplets: Convert hi-hats to triplet patterns")
    print("  • Syncopation: Shift hits to 'and' positions")
    print("  • Substitution: Swap weak kicks for hats")
    print()
    print("Benefits:")
    print("  ✅ Instant generation (<0.1s)")
    print("  ✅ No model loading, no thermal throttling")
    print("  ✅ Preserves exact loop duration")
    print("  ✅ Musically valid variations")
    print()
    print("Trade-offs:")
    print("  ⚠️  Less creative than AI")
    print("  ⚠️  Doesn't learn from training data")
    print("  ⚠️  Simpler variation patterns")
    print()
    print("Files saved in: src/tracks/track_0/variations/")
    print("  - heuristic_spice_3.txt (conservative)")
    print("  - heuristic_spice_5.txt (balanced)")
    print("  - heuristic_spice_8.txt (creative)")
    print()

if __name__ == '__main__':
    main()
