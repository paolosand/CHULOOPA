#!/usr/bin/env python3
"""
test_anchoring.py - Compare variations with and without timing anchoring

Shows how much timing anchoring affects the AI-generated variations.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import drum_variation_ai
from drum_variation_ai import DrumPattern, rhythmic_creator_variation

def test_anchoring_mode(mode_name, use_anchor):
    """Test generation with specific anchoring setting."""
    # Reset global model instance
    from rhythmic_creator_model import _model_instance
    import rhythmic_creator_model
    rhythmic_creator_model._model_instance = None
    drum_variation_ai.rhythmic_model = None

    # Set anchoring flag
    drum_variation_ai.use_no_anchor = not use_anchor

    # Load pattern
    track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
    if not track_file.exists():
        print(f"Error: No track file found at {track_file}")
        return None

    pattern = DrumPattern.from_file(str(track_file))

    print(f"\n{'='*70}")
    print(f"  {mode_name}")
    print(f"{'='*70}")
    print(f"Original pattern: {len(pattern.hits)} hits over {pattern.loop_duration:.2f}s")
    print()

    # Generate variation
    varied, success = rhythmic_creator_variation(pattern, spice_level=0.5)

    print()
    print(f"Result: {len(varied.hits)} hits over {varied.loop_duration:.2f}s")

    # Check intermediate files
    variations_dir = track_file.parent / "variations"
    raw_file = variations_dir / "track_0_drums_var1_raw_model.txt"
    density_file = variations_dir / "track_0_drums_var1_density_matched.txt"

    if raw_file.exists():
        raw_pattern = DrumPattern.from_file(str(raw_file))
        print(f"  Raw model output: {len(raw_pattern.hits)} hits")

    if density_file.exists():
        density_pattern = DrumPattern.from_file(str(density_file))
        print(f"  After density matching: {len(density_pattern.hits)} hits")
        print(f"  After {mode_name.lower()}: {len(varied.hits)} hits")

        if use_anchor:
            loss_pct = ((len(density_pattern.hits) - len(varied.hits)) / len(density_pattern.hits) * 100)
            print(f"  → Lost {loss_pct:.0f}% of hits to timing anchoring")

    # Save this variation with a unique name
    output_file = variations_dir / f"test_{mode_name.lower().replace(' ', '_')}.txt"
    varied.to_file(str(output_file))
    print(f"\nSaved to: {output_file.name}")

    return varied

def main():
    print("=" * 70)
    print("  TIMING ANCHOR COMPARISON TEST")
    print("=" * 70)
    print()
    print("This will generate two variations:")
    print("  1. WITH timing anchoring (snaps to original timing grid)")
    print("  2. WITHOUT timing anchoring (preserves AI-generated timing)")
    print()

    # Test with anchoring (current default)
    with_anchor = test_anchoring_mode("WITH TIMING ANCHOR", use_anchor=True)

    print("\n" + "="*70)
    print()

    # Test without anchoring
    without_anchor = test_anchoring_mode("WITHOUT TIMING ANCHOR", use_anchor=False)

    print()
    print("=" * 70)
    print("  COMPARISON")
    print("=" * 70)
    print()
    if with_anchor and without_anchor:
        print(f"WITH anchoring:    {len(with_anchor.hits)} hits")
        print(f"WITHOUT anchoring: {len(without_anchor.hits)} hits")
        print()
        print("Listen to both variations in ChucK (D1 to toggle) and see which you prefer!")
        print()
        print("Files saved in: src/tracks/track_0/variations/")
        print("  - test_with_timing_anchor.txt")
        print("  - test_without_timing_anchor.txt")
        print()

if __name__ == '__main__':
    main()
