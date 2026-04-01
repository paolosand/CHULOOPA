#!/usr/bin/env python3
"""Quick test to see how new mapping affects density"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern
from rhythmic_creator_model import get_model
from format_converters import chuloopa_to_rhythmic_creator, rhythmic_creator_to_chuloopa

# Load model
print("Loading model...")
model = get_model()

# Load your sample pattern
pattern_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
original = DrumPattern.from_file(str(pattern_file))

print(f"\nOriginal pattern:")
print(f"  Hits: {len(original.hits)}")
print(f"  Duration: {original.loop_duration:.2f}s")
print(f"  Distribution: kick={sum(1 for h in original.hits if h.drum_class==0)}, "
      f"snare={sum(1 for h in original.hits if h.drum_class==1)}, "
      f"hat={sum(1 for h in original.hits if h.drum_class==2)}")

# Convert to rhythmic_creator format
context_text = chuloopa_to_rhythmic_creator(original)
print(f"\nContext: {len(original.hits)} hits → {len(context_text.split())} tokens")

# Generate
print("\nGenerating variation (temp=0.8)...")
num_tokens = len(original.hits) * 3
generated_text = model.generate_variation(
    input_pattern=context_text,
    num_tokens=num_tokens,
    temperature=0.8
)

generated_tokens = generated_text.split()
print(f"Generated: {len(generated_tokens)} tokens")

# Convert back (using full output - variations can have different density)
raw_pattern = rhythmic_creator_to_chuloopa(generated_text, loop_duration=999)

print(f"\nRaw generated pattern:")
print(f"  Hits: {len(raw_pattern.hits)}")
print(f"  Distribution: kick={sum(1 for h in raw_pattern.hits if h.drum_class==0)}, "
      f"snare={sum(1 for h in raw_pattern.hits if h.drum_class==1)}, "
      f"hat={sum(1 for h in raw_pattern.hits if h.drum_class==2)}")

# Time-warp to fit
from drum_variation_ai import fit_to_loop_duration
variation = fit_to_loop_duration(raw_pattern, original.loop_duration)

print(f"\nFinal variation (after time-warp):")
print(f"  Hits: {len(variation.hits)}")
print(f"  Duration: {variation.loop_duration:.2f}s")
print(f"  Distribution: kick={sum(1 for h in variation.hits if h.drum_class==0)}, "
      f"snare={sum(1 for h in variation.hits if h.drum_class==1)}, "
      f"hat={sum(1 for h in variation.hits if h.drum_class==2)}")

print(f"\n=== COMPARISON ===")
print(f"Hit count: {len(original.hits)} → {len(variation.hits)} ({len(variation.hits) - len(original.hits):+d})")
