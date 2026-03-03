#!/usr/bin/env python3
"""
Test with the user's exact input to see what the model actually outputs.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern, DrumHit
from rhythmic_creator_model import get_model
from format_converters import chuloopa_to_rhythmic_creator, rhythmic_creator_to_chuloopa

# Create the user's exact input pattern
hits = [
    DrumHit(drum_class=0, timestamp=0.104490, velocity=0.729024, delta_time=0.374422),
    DrumHit(drum_class=2, timestamp=0.478912, velocity=0.723966, delta_time=0.333787),
    DrumHit(drum_class=2, timestamp=0.812698, velocity=0.733898, delta_time=0.365714),
    DrumHit(drum_class=0, timestamp=1.178413, velocity=0.750315, delta_time=0.177052),
    DrumHit(drum_class=2, timestamp=1.355465, velocity=0.741133, delta_time=0.185760),
    DrumHit(drum_class=0, timestamp=1.541224, velocity=0.748191, delta_time=0.371519),
    DrumHit(drum_class=2, timestamp=1.912744, velocity=0.731524, delta_time=0.348299),
    DrumHit(drum_class=1, timestamp=2.261043, velocity=0.752669, delta_time=0.554376),
]

pattern = DrumPattern(hits=hits, loop_duration=2.815420)

print("="*80)
print("USER'S EXAMPLE - RAW MODEL OUTPUT ANALYSIS")
print("="*80)
print()

print("INPUT PATTERN:")
print(f"  {len(pattern.hits)} hits, duration={pattern.loop_duration:.3f}s")
for i, hit in enumerate(pattern.hits):
    drum_name = ['kick', 'snare', 'hat'][hit.drum_class]
    print(f"    [{i}] {drum_name:5s} at {hit.timestamp:.3f}s")
print()

# Convert to rhythmic_creator format
context_text = chuloopa_to_rhythmic_creator(pattern)
print("CONTEXT TEXT (what we feed to model):")
print(f"  {context_text}")
print()

context_tokens = context_text.split()
print(f"CONTEXT: {len(context_tokens)} tokens ({len(context_tokens)//3} hits)")
print()

# Load model and generate
model = get_model()
print()

num_tokens = len(pattern.hits) * 6  # What we're currently using
print(f"GENERATING {num_tokens} tokens...")
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
print(f"Total tokens: {len(generated_tokens)} ({len(generated_tokens)//3} hits)")
print()

# Show as triplets
print("All output triplets:")
for i in range(0, len(generated_tokens), 3):
    if i+2 < len(generated_tokens):
        note = generated_tokens[i]
        start = generated_tokens[i+1]
        end = generated_tokens[i+2]

        # Determine if this is context echo or new generation
        triplet_idx = i // 3
        is_context = triplet_idx < len(context_tokens) // 3
        marker = "  [CONTEXT]" if is_context else "  [NEW]"

        print(f"  [{triplet_idx:2d}] {note:3s} {start:6s} {end:6s}{marker}")
print()

# Strip context
if len(generated_tokens) > len(context_tokens):
    new_pattern_tokens = generated_tokens[len(context_tokens):]
    new_pattern_text = ' '.join(new_pattern_tokens)
    print(f"AFTER STRIPPING CONTEXT:")
    print(f"  New pattern tokens: {len(new_pattern_tokens)} ({len(new_pattern_tokens)//3} hits)")
    print(f"  Text: {new_pattern_text}")
    print()

    # Show new pattern triplets
    print("New pattern triplets:")
    for i in range(0, len(new_pattern_tokens), 3):
        if i+2 < len(new_pattern_tokens):
            note = new_pattern_tokens[i]
            start = new_pattern_tokens[i+1]
            end = new_pattern_tokens[i+2]
            print(f"    [{i//3:2d}] {note:3s} {start:6s} {end:6s}")
    print()

    # Convert to CHULOOPA
    raw_pattern = rhythmic_creator_to_chuloopa(new_pattern_text, loop_duration=999)

    print("CONVERTED TO CHULOOPA:")
    print(f"  {len(raw_pattern.hits)} hits")
    if raw_pattern.hits:
        first_hit = min(h.timestamp for h in raw_pattern.hits)
        last_hit = max(h.timestamp for h in raw_pattern.hits)
        print(f"  Time range: {first_hit:.3f}s to {last_hit:.3f}s")
        print()

        print("  All hits:")
        for i, hit in enumerate(raw_pattern.hits):
            drum_name = ['kick', 'snare', 'hat'][hit.drum_class]
            print(f"    [{i:2d}] {drum_name:5s} at {hit.timestamp:.3f}s")
