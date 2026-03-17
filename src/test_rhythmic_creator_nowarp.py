#!/usr/bin/env python3
"""
test_rhythmic_creator_nowarp.py - Test model WITHOUT time-warping

This script tests if the rhythmic_creator model can naturally infer loop duration
without artificial time-warping. Tests the hypothesis that the model understands
groove structure well enough to generate variations at the correct tempo.

Pipeline:
1. Load existing CHULOOPA drum pattern from track_0/track_0_drums.txt
2. Generate variation using rhythmic_creator model
3. Save variation with NATURAL MODEL DURATION (no time-warping)
4. Compare original vs variation (duration and structure)

Usage:
    cd src
    python test_rhythmic_creator_nowarp.py
"""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern, DrumHit
from rhythmic_creator_model import get_model
from format_converters import chuloopa_to_rhythmic_creator, rhythmic_creator_to_chuloopa


def test_model_loading():
    """Test 1: Load the model."""
    print("=" * 80)
    print("TEST 1: Loading Rhythmic Creator Model")
    print("=" * 80)
    print()

    try:
        model = get_model()
        print("✓ Model loaded successfully!\n")

        info = model.info()
        print("Model Configuration:")
        for key, value in info.items():
            print(f"  {key:20s} = {value}")

        print()
        return model
    except Exception as e:
        print(f"✗ Model loading failed: {e}")
        import traceback
        traceback.print_exc()
        return None


def test_format_conversion(pattern):
    """Test 2: Format conversion."""
    print("=" * 80)
    print("TEST 2: Format Conversion (CHULOOPA ↔ Rhythmic Creator)")
    print("=" * 80)
    print()

    print(f"Original pattern:")
    print(f"  Hits: {len(pattern.hits)}")
    print(f"  Duration: {pattern.loop_duration:.2f}s")
    print(f"  First 3 hits: ")
    for i, hit in enumerate(pattern.hits[:3]):
        print(f"    [{i}] class={hit.drum_class}, time={hit.timestamp:.2f}s, vel={hit.velocity:.2f}")

    print()
    print("Converting to rhythmic_creator format...")
    rc_text = chuloopa_to_rhythmic_creator(pattern)
    rc_tokens = rc_text.split()
    print(f"  Generated {len(rc_tokens)} tokens")
    print(f"  First 30 tokens: {' '.join(rc_tokens[:30])}...")

    print()
    print("Converting back to CHULOOPA format...")
    reconstructed = rhythmic_creator_to_chuloopa(rc_text, pattern.loop_duration)
    print(f"  Reconstructed {len(reconstructed.hits)} hits")

    if len(reconstructed.hits) == len(pattern.hits):
        print("✓ Round-trip conversion successful!")
    else:
        print(f"⚠ Hit count changed: {len(pattern.hits)} → {len(reconstructed.hits)}")

    print()
    return rc_text


def test_generation_no_warp(model, context_text, original_duration, temperature=0.8):
    """Test 3: Generate variation WITHOUT time-warping."""
    print("=" * 80)
    print(f"TEST 3: Generating Variation (temperature={temperature}, NO TIME-WARP)")
    print("=" * 80)
    print()

    # Use full pattern as context
    context_tokens = context_text.split()

    print(f"Context:")
    print(f"  Using full pattern: {len(context_tokens)} tokens (~{len(context_tokens) // 3} hits)")
    print(f"  Original duration: {original_duration:.2f}s")
    print(f"  Context: {context_text[:100]}...")

    print()
    print("Generating continuation...")

    num_tokens = len(context_tokens)  # Generate ~1x pattern length

    try:
        generated_text = model.generate_variation(
            input_pattern=context_text,
            num_tokens=num_tokens,
            temperature=temperature
        )

        generated_tokens = generated_text.split()
        print(f"✓ Generated {len(generated_tokens)} tokens (~{len(generated_tokens) // 3} hits)")
        print(f"  First 30 tokens: {' '.join(generated_tokens[:30])}...")

        print()
        print("Converting to CHULOOPA format (using natural model duration)...")
        raw_pattern = rhythmic_creator_to_chuloopa(generated_text, loop_duration=999)
        print(f"  Raw pattern: {len(raw_pattern.hits)} hits")

        # Find actual duration
        if raw_pattern.hits:
            max_time = max(hit.timestamp for hit in raw_pattern.hits)
            print(f"  Model's natural duration: {max_time:.2f}s")
            print(f"  Original duration: {original_duration:.2f}s")

            duration_diff = max_time - original_duration
            duration_ratio = (max_time / original_duration) * 100 if original_duration > 0 else 0

            print(f"  Duration difference: {duration_diff:+.3f}s ({duration_ratio:.1f}% of original)")
        else:
            print("  ⚠ No hits in generated pattern!")
            return None

        print()
        print("🚫 SKIPPING TIME-WARP - Using natural model duration")
        print(f"  Final duration: {max_time:.2f}s (natural, not forced to {original_duration:.2f}s)")

        # Create variation with NATURAL duration (no time-warp)
        variation = DrumPattern(hits=raw_pattern.hits, loop_duration=max_time)
        variation._recalculate_delta_times()

        print(f"✓ Final variation: {len(variation.hits)} hits, {max_time:.2f}s (natural duration)")

        print()
        return variation

    except Exception as e:
        print(f"✗ Generation failed: {e}")
        import traceback
        traceback.print_exc()
        return None


def test_comparison(original, variation):
    """Test 4: Compare original vs variation."""
    print("=" * 80)
    print("TEST 4: Original vs Variation Comparison")
    print("=" * 80)
    print()

    print(f"Original:")
    print(f"  Hits: {len(original.hits)}")
    print(f"  Duration: {original.loop_duration:.2f}s")
    drum_dist_orig = {0: 0, 1: 0, 2: 0}
    for hit in original.hits:
        drum_dist_orig[hit.drum_class] += 1
    print(f"  Drum distribution: kick={drum_dist_orig[0]}, snare={drum_dist_orig[1]}, hat={drum_dist_orig[2]}")

    print()
    print(f"Variation:")
    print(f"  Hits: {len(variation.hits)}")
    print(f"  Duration: {variation.loop_duration:.2f}s")
    drum_dist_var = {0: 0, 1: 0, 2: 0}
    for hit in variation.hits:
        drum_dist_var[hit.drum_class] += 1
    print(f"  Drum distribution: kick={drum_dist_var[0]}, snare={drum_dist_var[1]}, hat={drum_dist_var[2]}")

    print()
    print(f"Differences:")
    print(f"  Hit count: {len(original.hits)} → {len(variation.hits)} ({len(variation.hits) - len(original.hits):+d})")
    print(f"  Kick: {drum_dist_orig[0]} → {drum_dist_var[0]} ({drum_dist_var[0] - drum_dist_orig[0]:+d})")
    print(f"  Snare: {drum_dist_orig[1]} → {drum_dist_var[1]} ({drum_dist_var[1] - drum_dist_orig[1]:+d})")
    print(f"  Hat: {drum_dist_orig[2]} → {drum_dist_var[2]} ({drum_dist_var[2] - drum_dist_orig[2]:+d})")

    # Duration analysis
    duration_diff = variation.loop_duration - original.loop_duration
    duration_ratio = (variation.loop_duration / original.loop_duration) * 100 if original.loop_duration > 0 else 0

    print(f"  Duration: {original.loop_duration:.2f}s → {variation.loop_duration:.2f}s ({duration_diff:+.3f}s, {duration_ratio:.1f}%)")

    if abs(duration_diff) < 0.1:
        print(f"  ✓ Duration match: Model naturally inferred correct loop length!")
    elif abs(duration_diff) < 0.5:
        print(f"  ~ Close duration: Model was within 0.5s of target")
    else:
        print(f"  ✗ Duration mismatch: Model did not infer correct loop length")

    print()


def main():
    print()
    print("🎵" * 40)
    print("Rhythmic Creator Test - NO TIME-WARP")
    print("Testing if model can naturally infer loop duration")
    print("🎵" * 40)
    print()

    # Load existing track
    track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"

    if not track_file.exists():
        print(f"✗ Track file not found: {track_file}")
        print("  Please record a loop in CHULOOPA first!")
        return 1

    print(f"Loading existing drum pattern from:")
    print(f"  {track_file}")
    print()

    original = DrumPattern.from_file(str(track_file))

    print(f"Loaded pattern: {len(original.hits)} hits, {original.loop_duration:.2f}s")
    print()

    # Test 1: Model loading
    model = test_model_loading()
    if model is None:
        return 1

    # Test 2: Format conversion
    rc_text = test_format_conversion(original)

    # Test 3: Generate variation WITHOUT time-warping
    variation = test_generation_no_warp(model, rc_text, original.loop_duration, temperature=0.9)
    if variation is None:
        return 1

    # Test 4: Compare
    test_comparison(original, variation)

    # Save variation
    print("=" * 80)
    print("SAVING VARIATION (with natural model duration)")
    print("=" * 80)
    print()

    output_dir = track_file.parent / "variations"
    output_dir.mkdir(parents=True, exist_ok=True)
    output_file = output_dir / "track_0_drums_var1_nowarp.txt"

    variation.to_file(str(output_file))
    print(f"✓ Saved variation to:")
    print(f"  {output_file}")
    print(f"  Duration: {variation.loop_duration:.2f}s (natural, not time-warped)")

    print()
    print("=" * 80)
    print("✓ TEST COMPLETE!")
    print("=" * 80)
    print()
    print("Key Question: Did the model naturally produce the correct loop duration?")
    print("Check the 'Duration difference' in the comparison above.")
    print()
    print("Next steps:")
    print("1. Try different temperatures (0.5-1.5)")
    print("2. Test with different input patterns (sparse vs dense)")
    print("3. Compare nowarp vs warped versions")
    print()

    return 0


if __name__ == '__main__':
    sys.exit(main())
