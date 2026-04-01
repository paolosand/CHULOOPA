#!/usr/bin/env python3
"""
Debug script to see exactly what tokens we're feeding to the model
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern
from format_converters import chuloopa_to_rhythmic_creator
from rhythmic_creator_model import get_model

# Load your pattern
track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
pattern = DrumPattern.from_file(str(track_file))

print("="*80)
print("INPUT PATTERN")
print("="*80)
print(f"Hits: {len(pattern.hits)}")
print(f"Duration: {pattern.loop_duration:.3f}s")
print()
for i, hit in enumerate(pattern.hits):
    print(f"  {i}: class={hit.drum_class}, time={hit.timestamp:.6f}, vel={hit.velocity:.3f}")
print()

# Convert to rhythmic_creator format
context_text = chuloopa_to_rhythmic_creator(pattern)
print("="*80)
print("CONVERTED TO RHYTHMIC_CREATOR FORMAT")
print("="*80)
print(f"Text: {context_text}")
print()
tokens = context_text.split()
print(f"Tokens ({len(tokens)} total):")
for i in range(0, len(tokens), 3):
    if i+2 < len(tokens):
        print(f"  [{i//3}] {tokens[i]} {tokens[i+1]} {tokens[i+2]}")
print()

# Load model and check vocabulary
print("="*80)
print("CHECKING VOCABULARY")
print("="*80)
model = get_model()
processor = model.processor

# Check if our tokens are in vocabulary
print("Checking if our tokens exist in vocabulary:")
missing = []
for token in tokens:
    if token not in processor.unique_notes:
        missing.append(token)
        print(f"  ✗ MISSING: '{token}'")
    else:
        print(f"  ✓ Found: '{token}'")

if missing:
    print(f"\n⚠ WARNING: {len(missing)} tokens not in vocabulary!")
    print("This will cause generation errors!")
else:
    print(f"\n✓ All {len(tokens)} tokens found in vocabulary")

print()
print("="*80)
print("SAMPLE FROM TRAINING DATA")
print("="*80)
# Show a sample from training data
import random
training_path = Path(__file__).parent / "models" / "training_1.txt"
with open(training_path) as f:
    lines = f.readlines()
    sample_line = random.choice(lines[:10])  # First 10 lines
    sample_tokens = sample_line.strip().split()[:30]  # First 30 tokens
    print(f"Sample tokens from training: {' '.join(sample_tokens)}")
    print()
    print("Format analysis:")
    for i in range(0, min(9, len(sample_tokens)), 3):
        if i+2 < len(sample_tokens):
            print(f"  [{i//3}] {sample_tokens[i]} {sample_tokens[i+1]} {sample_tokens[i+2]}")
