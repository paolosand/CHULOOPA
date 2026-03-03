#!/usr/bin/env python3
"""
Debug script to trace the source of duplicate timestamps.

We know duplicates happen sporadically. This script instruments
the conversion pipeline to see WHERE they're introduced.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern
from rhythmic_creator_model import get_model
from format_converters import chuloopa_to_rhythmic_creator, rhythmic_creator_to_chuloopa

print("="*80)
print("DUPLICATE TIMESTAMP DIAGNOSTIC")
print("="*80)
print()

# Load original pattern
track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
original = DrumPattern.from_file(str(track_file))

print(f"Original: {len(original.hits)} hits")
print()

# Convert to rhythmic_creator format
context_text = chuloopa_to_rhythmic_creator(original)
print(f"Context text: {context_text}")
print()

# Load model
model = get_model()
print()

# Run multiple generations and check raw model output
num_tests = 10
for test_num in range(1, num_tests + 1):
    print(f"{'='*80}")
    print(f"TEST {test_num}/{num_tests}")
    print(f"{'='*80}")

    # Generate
    generated_text = model.generate_variation(
        input_pattern=context_text,
        num_tokens=30,
        temperature=0.8
    )

    # Parse tokens
    context_tokens = context_text.split()
    generated_tokens = generated_text.split()

    print(f"  Generated {len(generated_tokens)} tokens total")

    # Check for duplicates in RAW MODEL OUTPUT (before stripping context)
    print()
    print("  RAW MODEL OUTPUT (checking for duplicate triplets):")

    triplets_seen = {}
    duplicate_triplets = []

    for i in range(0, len(generated_tokens), 3):
        if i+2 < len(generated_tokens):
            triplet = (generated_tokens[i], generated_tokens[i+1], generated_tokens[i+2])
            if triplet in triplets_seen:
                duplicate_triplets.append((i//3, triplet, triplets_seen[triplet]))
            else:
                triplets_seen[triplet] = i//3

    if duplicate_triplets:
        print(f"    ⚠️  FOUND {len(duplicate_triplets)} DUPLICATE TRIPLETS in raw output:")
        for hit_idx, triplet, first_seen_idx in duplicate_triplets:
            print(f"      Hit {hit_idx}: {triplet} (duplicate of hit {first_seen_idx})")
    else:
        print(f"    ✓ No duplicate triplets in raw output")

    # Strip context
    if len(generated_tokens) > len(context_tokens):
        new_pattern_tokens = generated_tokens[len(context_tokens):]
        new_pattern_text = ' '.join(new_pattern_tokens)
    else:
        new_pattern_text = generated_text

    print()
    print("  AFTER CONTEXT STRIPPING:")
    print(f"    New pattern: {len(new_pattern_tokens)} tokens ({len(new_pattern_tokens)//3} hits)")

    # Convert to CHULOOPA
    raw_pattern = rhythmic_creator_to_chuloopa(new_pattern_text, loop_duration=999)

    # Check for duplicate timestamps in CHULOOPA format
    timestamps = [hit.timestamp for hit in raw_pattern.hits]
    duplicates = [t for t in timestamps if timestamps.count(t) > 1]

    if duplicates:
        print(f"    ⚠️  FOUND {len(set(duplicates))} DUPLICATE TIMESTAMPS after conversion:")
        for dup_time in sorted(set(duplicates)):
            hits_at_time = [(i, h.drum_class) for i, h in enumerate(raw_pattern.hits) if h.timestamp == dup_time]
            print(f"      Time {dup_time:.3f}s: {len(hits_at_time)} hits → {hits_at_time}")
    else:
        print(f"    ✓ No duplicate timestamps after conversion")

    print()

print()
print("="*80)
print("DIAGNOSTIC COMPLETE")
print("="*80)
