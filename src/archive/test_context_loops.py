#!/usr/bin/env python3
"""
test_context_loops.py - Compare different context loop multipliers

Tests 1x, 2x, 4x, and 8x context to see which produces the best
loop-aware variations.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import drum_variation_ai
from drum_variation_ai import DrumPattern, rhythmic_creator_variation

def test_context_loops(num_loops):
    """Test generation with specific number of context loops."""
    # Reset global model instance
    from rhythmic_creator_model import _model_instance
    import rhythmic_creator_model
    rhythmic_creator_model._model_instance = None
    drum_variation_ai.rhythmic_model = None

    # Set context loops
    drum_variation_ai.context_loops = num_loops
    drum_variation_ai.use_no_anchor = True  # Skip anchoring to see pure AI output

    # Load pattern
    track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
    if not track_file.exists():
        print(f"Error: No track file found at {track_file}")
        return None

    pattern = DrumPattern.from_file(str(track_file))

    print(f"\n{'='*70}")
    print(f"  {num_loops}X CONTEXT LOOPS")
    print(f"{'='*70}")
    print(f"Original: {len(pattern.hits)} hits")
    print(f"Context: {len(pattern.hits) * num_loops} hits ({num_loops}x repetition)")
    print()

    # Generate variation
    varied, success = rhythmic_creator_variation(pattern, spice_level=0.5)

    print()
    print(f"Result: {len(varied.hits)} hits over {varied.loop_duration:.2f}s")

    # Save with unique name
    variations_dir = track_file.parent / "variations"
    output_file = variations_dir / f"context_{num_loops}x.txt"
    varied.to_file(str(output_file))
    print(f"Saved: {output_file.name}")

    return varied

def main():
    print("=" * 70)
    print("  CONTEXT LOOPS COMPARISON TEST")
    print("=" * 70)
    print()
    print("This tests different context repetition amounts:")
    print("  • 1x = single loop (minimal context)")
    print("  • 2x = doubled (default, good balance)")
    print("  • 4x = quadrupled (strong loop reinforcement)")
    print("  • 8x = 8x repetition (maximum reinforcement)")
    print()
    print("Theory: More repetitions → stronger loop awareness")
    print("But: Too many may bias toward exact repetition")
    print()

    results = {}

    for num_loops in [1, 2, 4, 8]:
        result = test_context_loops(num_loops)
        if result:
            results[num_loops] = result

        if num_loops < 8:
            print("\n" + "="*70)

    print()
    print("=" * 70)
    print("  SUMMARY")
    print("=" * 70)
    print()

    for num_loops, pattern in results.items():
        print(f"{num_loops}x context: {len(pattern.hits)} hits")

    print()
    print("Listen to all 4 variations in ChucK and compare:")
    print("  • Which feels most loop-aware?")
    print("  • Which maintains groove structure best?")
    print("  • Which has the right balance of variation vs repetition?")
    print()
    print("Files saved in: src/tracks/track_0/variations/")
    print("  - context_1x.txt (single loop)")
    print("  - context_2x.txt (doubled - DEFAULT)")
    print("  - context_4x.txt (quadrupled)")
    print("  - context_8x.txt (8x repetition)")
    print()
    print("Recommendation: Start with 2x (default), try 4x if you want")
    print("                stronger loop coherence.")
    print()

if __name__ == '__main__':
    main()
