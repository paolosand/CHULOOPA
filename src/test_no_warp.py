#!/usr/bin/env python3
"""
Test rhythmic_creator output WITHOUT time-warping

This test generates a variation and saves it with the model's natural timing,
without any time-warping to fit the original loop duration.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern
from rhythmic_creator_model import get_model
from format_converters import chuloopa_to_rhythmic_creator, rhythmic_creator_to_chuloopa

def test_no_warp():
    print("\n" + "="*80)
    print("RHYTHMIC CREATOR - NO TIME-WARPING TEST")
    print("="*80)
    print()

    # Load model
    print("Loading model...")
    model = get_model()
    print()

    # Load original pattern
    track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
    original = DrumPattern.from_file(str(track_file))

    print("Original pattern:")
    print(f"  Hits: {len(original.hits)}")
    print(f"  Duration: {original.loop_duration:.3f}s")
    print(f"  Distribution: kick={sum(1 for h in original.hits if h.drum_class==0)}, "
          f"snare={sum(1 for h in original.hits if h.drum_class==1)}, "
          f"hat={sum(1 for h in original.hits if h.drum_class==2)}")
    print()

    # Convert to rhythmic_creator format
    context_text = chuloopa_to_rhythmic_creator(original)
    print(f"Context: {len(original.hits)} hits → {len(context_text.split())} tokens")
    print()

    # Generate with model
    print("Generating (temp=0.8)...")
    num_tokens = len(original.hits) * 3  # Generate ~1x pattern length
    generated_text = model.generate_variation(
        input_pattern=context_text,
        num_tokens=num_tokens,
        temperature=0.8
    )
    print(f"Generated: {len(generated_text.split())} tokens")
    print()

    # Convert back to CHULOOPA format WITHOUT time-warping
    # Use a large duration so we can see the model's natural timing
    print("Converting to CHULOOPA format (NO TIME-WARPING)...")
    raw_variation = rhythmic_creator_to_chuloopa(generated_text, loop_duration=999)

    if not raw_variation.hits:
        print("✗ No hits generated!")
        return

    # Find the actual duration from timestamps
    max_time = max(hit.timestamp for hit in raw_variation.hits)

    print(f"Raw variation (model's natural timing):")
    print(f"  Hits: {len(raw_variation.hits)}")
    print(f"  Actual duration: {max_time:.3f}s")
    print(f"  Distribution: kick={sum(1 for h in raw_variation.hits if h.drum_class==0)}, "
          f"snare={sum(1 for h in raw_variation.hits if h.drum_class==1)}, "
          f"hat={sum(1 for h in raw_variation.hits if h.drum_class==2)}")
    print()

    # Save with natural timing (set loop duration to actual max time)
    raw_variation.loop_duration = max_time
    raw_variation._recalculate_delta_times()

    output_dir = track_file.parent / "variations"
    output_dir.mkdir(exist_ok=True)
    output_file = output_dir / "track_0_drums_var1_no_warp.txt"

    raw_variation.to_file(str(output_file))

    print("="*80)
    print("COMPARISON")
    print("="*80)
    print(f"Original: {len(original.hits)} hits in {original.loop_duration:.3f}s")
    print(f"Raw variation: {len(raw_variation.hits)} hits in {max_time:.3f}s")
    print(f"Duration ratio: {max_time / original.loop_duration:.2f}x")
    print()
    print(f"✓ Saved raw variation (no time-warping) to:")
    print(f"  {output_file}")
    print()
    print("Now you can:")
    print("1. Load this variation in ChucK to hear the model's natural timing")
    print("2. Compare timestamps to see if time-warping was distorting the rhythm")
    print()

if __name__ == '__main__':
    test_no_warp()
