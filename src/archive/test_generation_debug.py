#!/usr/bin/env python3
"""
Debug actual generation to see what the model outputs
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern
from format_converters import chuloopa_to_rhythmic_creator, rhythmic_creator_to_chuloopa
from rhythmic_creator_model import get_model

# Load your 4-hit pattern
track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
pattern = DrumPattern.from_file(str(track_file))

print("="*80)
print("INPUT PATTERN")
print("="*80)
print(f"Hits: {len(pattern.hits)}")
for i, hit in enumerate(pattern.hits):
    print(f"  {i}: class={hit.drum_class}, time={hit.timestamp:.3f}s")
print()

# Convert to context
context_text = chuloopa_to_rhythmic_creator(pattern)
context_tokens = context_text.split()
print(f"Context: {len(context_tokens)} tokens ({len(context_tokens)//3} hits)")
print(f"  {context_text}")
print()

# Load model
model = get_model()

# Generate with EXACT settings from your test
num_tokens = len(pattern.hits) * 6  # 2x (what you said you set)
print("="*80)
print("GENERATING")
print("="*80)
print(f"Asking model for {num_tokens} tokens (input was {len(context_tokens)} tokens)")
print()

generated_text = model.generate_variation(
    input_pattern=context_text,
    num_tokens=num_tokens,
    temperature=0.8
)

print("="*80)
print("RAW MODEL OUTPUT")
print("="*80)
generated_tokens = generated_text.split()
print(f"Generated {len(generated_tokens)} tokens ({len(generated_tokens)//3} hits)")
print()
print("All tokens:")
print(f"  {generated_text}")
print()

# Show as triplets
print("As triplets:")
for i in range(0, len(generated_tokens), 3):
    if i+2 < len(generated_tokens):
        note = generated_tokens[i]
        start = generated_tokens[i+1]
        end = generated_tokens[i+2]
        print(f"  [{i//3:2d}] {note:3s} {start:6s} {end:6s}")
print()

# Convert to CHULOOPA
print("="*80)
print("CONVERTING TO CHULOOPA")
print("="*80)
raw_pattern = rhythmic_creator_to_chuloopa(generated_text, loop_duration=999)
print(f"Result: {len(raw_pattern.hits)} hits")
print()

# Show timestamps
print("Timestamps:")
for i, hit in enumerate(raw_pattern.hits):
    print(f"  [{i:2d}] class={hit.drum_class}, time={hit.timestamp:.3f}s")

# Check for issues
print()
print("="*80)
print("ISSUES CHECK")
print("="*80)

# Check for duplicate timestamps
timestamps = [hit.timestamp for hit in raw_pattern.hits]
duplicates = [t for t in timestamps if timestamps.count(t) > 1]
if duplicates:
    print(f"⚠ WARNING: Found hits at same timestamp!")
    for dup_time in set(duplicates):
        hits_at_time = [h for h in raw_pattern.hits if h.timestamp == dup_time]
        print(f"  Time {dup_time:.3f}s: {len(hits_at_time)} hits (classes: {[h.drum_class for h in hits_at_time]})")
else:
    print("✓ No duplicate timestamps")

# Check timestamps are increasing
sorted_times = sorted(timestamps)
if sorted_times == timestamps:
    print("✓ Timestamps are in order")
else:
    print("⚠ WARNING: Timestamps are NOT in order!")
    print(f"  Original: {timestamps[:10]}")
    print(f"  Sorted:   {sorted_times[:10]}")
