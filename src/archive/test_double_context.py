#!/usr/bin/env python3
"""
test_double_context.py - Compare single vs double context for rhythmic_creator

Tests whether passing the loop twice helps the model understand looping structure.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import drum_variation_ai
from drum_variation_ai import DrumPattern, rhythmic_creator_variation

def test_context_mode(mode_name, use_double):
    """Test generation with specific context mode."""
    # Reset global model instance
    from rhythmic_creator_model import _model_instance
    import rhythmic_creator_model
    rhythmic_creator_model._model_instance = None
    drum_variation_ai.rhythmic_model = None

    # Set context mode
    drum_variation_ai.use_double_context = use_double
    drum_variation_ai.use_no_anchor = True  # Skip anchoring to see pure AI output

    # Load pattern
    track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
    if not track_file.exists():
        print(f"Error: No track file found at {track_file}")
        return None

    pattern = DrumPattern.from_file(str(track_file))

    print(f"\n{'='*70}")
    print(f"  {mode_name}")
    print(f"{'='*70}")
    print(f"Original: {len(pattern.hits)} hits over {pattern.loop_duration:.2f}s")
    print()

    # Generate variation
    varied, success = rhythmic_creator_variation(pattern, spice_level=0.5)

    print()
    print(f"Result: {len(varied.hits)} hits over {varied.loop_duration:.2f}s")

    # Save with unique name
    variations_dir = track_file.parent / "variations"
    output_file = variations_dir / f"test_{mode_name.lower().replace(' ', '_').replace('(', '').replace(')', '')}.txt"
    varied.to_file(str(output_file))
    print(f"Saved to: {output_file.name}")

    return varied

def main():
    print("=" * 70)
    print("  DOUBLE CONTEXT TEST")
    print("=" * 70)
    print()
    print("This tests whether passing the loop TWICE helps the model")
    print("understand it's a repeating pattern.")
    print()
    print("Theory: Doubling reinforces the looping structure, leading to")
    print("more coherent variations that 'feel' like they loop naturally.")
    print()

    # Test single context
    single = test_context_mode("SINGLE CONTEXT (1x loop)", use_double=False)

    print("\n" + "="*70)

    # Test double context
    double = test_context_mode("DOUBLE CONTEXT (2x loop)", use_double=True)

    print()
    print("=" * 70)
    print("  COMPARISON")
    print("=" * 70)
    print()
    if single and double:
        print(f"Single context: {len(single.hits)} hits")
        print(f"Double context: {len(double.hits)} hits")
        print()
        print("Listen to both in ChucK and compare:")
        print("  - Does the doubled version feel more loop-aware?")
        print("  - Does it maintain the groove structure better?")
        print("  - Is the variation more musically coherent?")
        print()
        print("Files saved in: src/tracks/track_0/variations/")
        print("  - test_single_context_1x_loop.txt")
        print("  - test_double_context_2x_loop.txt")
        print()

if __name__ == '__main__':
    main()
