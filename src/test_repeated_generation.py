#!/usr/bin/env python3
"""
Test repeated generation behavior to diagnose reliability issues.

This simulates what happens when user repeatedly presses D#1 to regenerate.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern, generate_variation

print("="*80)
print("REPEATED GENERATION TEST")
print("="*80)
print()

# Load original pattern
track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
original = DrumPattern.from_file(str(track_file))

print(f"Original pattern: {len(original.hits)} hits, duration={original.loop_duration:.3f}s")
print()

# Simulate multiple regenerations (like pressing D#1 repeatedly)
num_iterations = 5
spice_level = 0.8

results = []
for i in range(num_iterations):
    print(f"\n{'='*80}")
    print(f"GENERATION {i+1}/{num_iterations} (spice={spice_level})")
    print(f"{'='*80}")

    try:
        variation, success = generate_variation(
            pattern=original,
            variation_type='rhythmic_creator',
            temperature=spice_level
        )

        if success:
            print(f"✓ SUCCESS: {len(variation.hits)} hits, duration={variation.loop_duration:.3f}s")

            # Validate
            issues = []

            # Check for duplicate timestamps
            timestamps = [hit.timestamp for hit in variation.hits]
            duplicates = [t for t in timestamps if timestamps.count(t) > 1]
            if duplicates:
                issues.append(f"Duplicate timestamps: {len(set(duplicates))} cases")

            # Check chronological order
            if sorted(timestamps) != timestamps:
                issues.append("Timestamps not in order")

            # Check within bounds
            max_time = max(timestamps) if timestamps else 0
            if max_time > variation.loop_duration:
                issues.append(f"Timestamps exceed duration ({max_time:.3f}s > {variation.loop_duration:.3f}s)")

            # Check for empty
            if not variation.hits:
                issues.append("Empty variation")

            if issues:
                print(f"  ⚠️  ISSUES: {', '.join(issues)}")
                results.append(('ISSUES', i+1, issues))
            else:
                print(f"  ✓ VALID variation")
                results.append(('SUCCESS', i+1, None))

        else:
            print(f"✗ FAILED: Fallback used")
            results.append(('FAILED', i+1, None))

    except Exception as e:
        print(f"✗ EXCEPTION: {e}")
        import traceback
        traceback.print_exc()
        results.append(('EXCEPTION', i+1, str(e)))

# Summary
print()
print("="*80)
print("SUMMARY")
print("="*80)

success_count = sum(1 for r in results if r[0] == 'SUCCESS')
issues_count = sum(1 for r in results if r[0] == 'ISSUES')
failed_count = sum(1 for r in results if r[0] == 'FAILED')
exception_count = sum(1 for r in results if r[0] == 'EXCEPTION')

print(f"Total iterations: {num_iterations}")
print(f"  ✓ Clean successes: {success_count}")
print(f"  ⚠️  With issues: {issues_count}")
print(f"  ✗ Fallback used: {failed_count}")
print(f"  💥 Exceptions: {exception_count}")
print()

if success_count == num_iterations:
    print("🎉 ALL GENERATIONS SUCCESSFUL - no reliability issues detected")
else:
    print("⚠️  RELIABILITY ISSUES DETECTED")
    print()
    print("Details:")
    for status, iteration, info in results:
        if status != 'SUCCESS':
            print(f"  Generation {iteration}: {status}")
            if info:
                print(f"    {info}")
