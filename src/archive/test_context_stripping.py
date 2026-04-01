#!/usr/bin/env python3
"""
Test the context-stripping fix in rhythmic_creator_variation()
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern, rhythmic_creator_variation

print("="*80)
print("TESTING CONTEXT-STRIPPING FIX")
print("="*80)
print()

# Load original pattern
track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
original = DrumPattern.from_file(str(track_file))

print(f"Original pattern: {len(original.hits)} hits, duration={original.loop_duration:.3f}s")
for i, hit in enumerate(original.hits[:5]):  # Show first 5
    print(f"  [{i}] class={hit.drum_class}, time={hit.timestamp:.3f}s")
print()

# Generate variation using the actual function with the fix
print("Generating variation with context stripping...")
print()

variation, success = rhythmic_creator_variation(
    pattern=original,
    temperature=0.8
)

if not success:
    print("✗ Generation failed!")
    sys.exit(1)

print()
print("="*80)
print("RESULT")
print("="*80)
print(f"Variation: {len(variation.hits)} hits, duration={variation.loop_duration:.3f}s")
print()

# Show timestamps
print("Variation timestamps:")
for i, hit in enumerate(variation.hits):
    print(f"  [{i:2d}] class={hit.drum_class}, time={hit.timestamp:.3f}s")
print()

# Check for issues
timestamps = [hit.timestamp for hit in variation.hits]
duplicates = [t for t in timestamps if timestamps.count(t) > 1]

print("="*80)
print("VALIDATION")
print("="*80)

if duplicates:
    print(f"✗ FAIL: Found hits at same timestamp!")
    for dup_time in set(duplicates):
        hits_at_time = [h for h in variation.hits if h.timestamp == dup_time]
        print(f"  Time {dup_time:.3f}s: {len(hits_at_time)} hits (classes: {[h.drum_class for h in hits_at_time]})")
else:
    print("✓ PASS: No duplicate timestamps")

# Check timestamps are in order
sorted_times = sorted(timestamps)
if sorted_times == timestamps:
    print("✓ PASS: Timestamps are in chronological order")
else:
    print("✗ FAIL: Timestamps are NOT in order!")

# Check all times fit within loop duration
max_time = max(timestamps)
if max_time <= variation.loop_duration:
    print(f"✓ PASS: All hits within loop duration ({max_time:.3f}s <= {variation.loop_duration:.3f}s)")
else:
    print(f"✗ FAIL: Hits exceed loop duration ({max_time:.3f}s > {variation.loop_duration:.3f}s)")

print()
if not duplicates and sorted_times == timestamps and max_time <= variation.loop_duration:
    print("🎉 ALL TESTS PASSED! Context stripping is working correctly.")
else:
    print("⚠️  SOME TESTS FAILED - needs investigation")
print()
