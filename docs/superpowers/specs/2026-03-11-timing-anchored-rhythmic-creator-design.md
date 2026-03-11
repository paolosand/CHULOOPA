# Timing-Anchored Rhythmic Creator Design

**Date:** 2026-03-11
**Status:** Approved
**Target:** ACM Creativity & Cognition 2026

## Overview

This design improves rhythmic_creator's drum variation generation to preserve the user's beatbox groove while maintaining neural creativity. The current system generates musically valid continuations but fails to match the user's timing and density, making variations feel unrelated to the input.

## Problem Statement

### Current Behavior

Rhythmic_creator generates **continuations** (what comes next in a song) rather than **variations** (same groove, different hits):

**User Input:**
- 9 hits, mostly kicks, ~0.5s spacing, sparse feel
- Duration: 4.27s

**Current Output:**
- 26-28 hits (3x denser)
- Completely different groove and feel
- Timing bears no relationship to input positions
- Inconsistent between runs

### Core Issues (Ranked by Priority)

1. **Timing/Musicality (#1):** Hits don't land on musical beats relative to input groove
2. **Groove Preservation (#2):** Feel completely changes (sparse → dense, kicks → snares)
3. **Inconsistency (#2):** Same input produces wildly different outputs
4. **Density Mismatch (#3):** Less critical if groove is preserved

### User Requirements

**Success = "Input timing matching":**
- Variations should share the same rhythmic DNA as the input
- Switching between original and variation should feel natural
- Low spice: ~same hit count, positions mostly intact, small tweaks
- High spice: moderate hit increase (up to 1.5x), significant restructuring, but still recognizably "that groove"

## Solution: Three-Layer System

### Architecture Overview

```
User beatboxes → ChucK records → Python receives
                                     ↓
                        [1] rhythmic_creator generates raw output
                            - Fixed temperature (0.7) for stability
                                     ↓
                        [2] DENSITY MATCHING (already implemented)
                            - Choose wrap vs continuation based on hit count
                                     ↓
                        [3] NEW: TIMING ANCHORING
                            - Extract timing grid from original input
                            - Anchor model hits to input positions
                            - Spice controls drift distance and fills
                                     ↓
                        [4] Time-warp to match loop duration
                                     ↓
                        [5] Export variation → ChucK loads
                                     ↓
                [FALLBACK] Algorithmic variation if model fails
```

**Key Insight:** Density matching and timing anchoring work together as complementary fixes:
- Density matching fixes hit count issues
- Timing anchoring fixes groove/musicality

## Layer 1: Density Matching (Already Implemented)

Choose between continuation hits (after original pattern) or wrap hits (looped back to start) based on which is closer to the original pattern's density.

**Strategy:**
```python
# Calculate how far each is from original density
original_density = len(pattern.hits)
cont_density = len(continuation_hits)
wrap_density = len(wrap_hits)

cont_diff = abs(cont_density - original_density)
wrap_diff = abs(wrap_density - original_density)

# Use whichever is closer (prefer wrap on tie)
use_continuation = cont_diff < wrap_diff and cont_density >= 3
```

**Example:**
```
Input: 9 hits
Continuation: 31 hits (diff = 22)
Wrap: 13 hits (diff = 4)
→ Use wrap (closer to original density)
```

## Layer 2: Timing Anchoring (New)

### Core Algorithm

**Step 1: Extract Timing Grid from Input**

From the original beatbox recording, extract hit positions as a "reference grid":

```python
# Input pattern:
original_hits = [0.14s, 0.66s, 1.22s, 1.73s, 2.28s, 2.79s, 3.35s, 3.85s, 4.00s]

# This becomes the timing grid:
timing_grid = [0.14, 0.66, 1.22, 1.73, 2.28, 2.79, 3.35, 3.85, 4.00]
```

**Step 2: Anchor Model Hits to Grid Positions**

For each hit the model generates:
1. Find the **nearest position** in the timing grid
2. **Drift** the hit toward that position based on spice level
3. **Allow fills** between grid positions at high spice

**Spice Mapping:**

```python
# Calculate spice-based parameters
max_drift = 0.02 + (spice_level * 0.13)  # 20ms at low, 150ms at high
fill_probability = spice_level * 0.8      # 0% at low, 80% at high
```

| Spice Level | Max Drift | Fill Probability | Behavior |
|-------------|-----------|------------------|----------|
| 0.0-0.3 (Low) | 20-50ms | 0-24% | Tight anchoring, rare fills |
| 0.4-0.6 (Med) | 60-100ms | 32-48% | Moderate drift, some fills |
| 0.7-1.0 (High) | 110-150ms | 56-80% | Loose anchoring, many fills |

**Step 3: Handling Density Mismatch**

**More hits than grid positions:**
- **Primary hits** (closest to grid) → anchor to grid positions
- **Extra hits** (far from grid) → treat as potential fills
  - Keep them if `random() < fill_probability`
  - Discard if they don't pass the fill test

**Example:**
```
Input grid:     [0.0s,  0.5s,  1.0s,  1.5s]  (4 hits)
Model output:   [0.02s, 0.48s, 0.75s, 1.01s, 1.52s]  (5 hits)

Low spice (0.2):
  - Anchor: [0.0s, 0.5s, 1.0s, 1.5s]  (4 hits, 0.75s discarded as off-grid)

High spice (0.8):
  - Anchor: [0.0s, 0.5s, 1.0s, 1.5s]  (4 hits)
  - Fill: [0.75s]  (kept with 60% probability)
  - Result: [0.0s, 0.5s, 0.75s, 1.0s, 1.5s]  (5 hits total)
```

**Fewer hits than grid positions:**
- Use all model hits (they're valuable AI choices)
- Anchor each to nearest available grid position
- Some grid positions won't have hits (creates variation)

**Example:**
```
Input grid:     [0.0s,  0.5s,  1.0s,  1.5s]  (4 hits)
Model output:   [0.02s, 1.52s]  (2 hits - sparse variation)

Result:
  - Anchor: [0.0s, 1.5s]  (2 hits, positions 0.5s and 1.0s skipped)
```

### Drum Class Strategy: Trust the Model

**Decision:** Use model's drum class choices (kick/snare/hat) directly.

**Rationale:**
- The rhythmic_creator model was trained on real drum performances
- Its drum class choices are already musically coherent
- Random swapping isn't musical (e.g., all snares → hats destroys backbeat)
- Model's orchestration + user's timing = interesting hybrid patterns

**Implementation:**
```python
anchored_hit = DrumHit(
    drum_class=model_hit.drum_class,  # ← Trust the model's choice
    timestamp=anchor_to_grid(model_hit.timestamp),  # ← Fix timing
    velocity=model_hit.velocity
)
```

**Trade-off:**
- **Rhythm/groove** comes from user (via timing anchoring)
- **Orchestration** (which drums play) comes from model's training
- Creates musically valid variations that are rhythmically consistent with input

## Layer 3: Algorithmic Fallback (New)

### When to Use

Fallback to algorithmic variation when:
- Model generates zero usable hits after filtering
- All hits get filtered during timing anchoring
- Model crashes or fails unexpectedly

### Algorithm: Musical Variation

Uses real drumming techniques with spice-controlled probabilities:

```python
def generate_musical_variation(drum_data, spice_level):
    """
    Mathematical variation that respects groove structure.
    """
    # Scale all probabilities by spice level
    base_probs = {
        'double': 0.15,      # Double kick/snare
        'ghost': 0.10,       # Ghost note fill
        'triplet': 0.05,     # Hi-hat triplets
        'shift_and': 0.10,   # Shift to "and"
        'substitute': 0.10,  # Drum substitution
    }

    # At low spice (0.2): reduce all mutations by 50%
    # At high spice (0.8): increase by 50%
    spice_multiplier = 0.5 + spice_level  # Range: 0.5x to 1.5x

    probs = {k: v * spice_multiplier for k, v in base_probs.items()}

    varied_groove = []

    for i, hit in enumerate(drum_data):
        c = hit['class']
        v = hit['vel']
        d = hit['delta']

        # PROTECT ANCHORS (always protected regardless of spice)
        is_anchor = (i == 0) or (c == 1 and v > 0.7)

        if is_anchor:
            # Just humanize velocity
            v = max(0.1, min(1.0, v + random.uniform(-0.03, 0.03)))
            varied_groove.append({'class': c, 'vel': v, 'delta': d})
            continue

        # Apply mutations with spice-scaled probabilities
        roll = random.random()

        if roll < probs['double']:
            # Double the hit (split delta in half)
            half_delta = d / 2.0
            varied_groove.append({'class': c, 'vel': v * 0.9, 'delta': half_delta})
            varied_groove.append({'class': c, 'vel': v * 0.7, 'delta': half_delta})

        elif roll < probs['double'] + probs['ghost']:
            # Add ghost note
            half_delta = d / 2.0
            varied_groove.append({'class': c, 'vel': v, 'delta': half_delta})
            varied_groove.append({'class': 1, 'vel': random.uniform(0.15, 0.35), 'delta': half_delta})

        elif roll < probs['double'] + probs['ghost'] + probs['triplet'] and c == 2:
            # Hi-hat triplets
            third_delta = d / 3.0
            varied_groove.append({'class': 2, 'vel': v, 'delta': third_delta})
            varied_groove.append({'class': 2, 'vel': v * 0.6, 'delta': third_delta})
            varied_groove.append({'class': 2, 'vel': v * 0.8, 'delta': third_delta})

        # ... other mutations (shift_and, substitute)

        else:
            # Pass through unchanged
            varied_groove.append({'class': c, 'vel': v, 'delta': d})

    # Recalculate timestamps to preserve exact loop duration
    return rebuild_timestamps(varied_groove)
```

**Key Features:**
- Protects structural anchors (first hit, strong backbeats)
- Uses musically valid techniques (doubling, ghost notes, triplets, syncopation)
- Maintains exact loop duration via delta time manipulation
- Spice-aware mutation probabilities

## Temperature vs Spice Separation

### Design Decision: Decouple Model Temperature from User Spice

**Problem:** Currently spice controls both:
- Model's sampling randomness (temperature)
- Post-processing variation (timing drift, fills)

High spice → high temperature → chaotic, unstable patterns that don't relate to input.

**Solution: Fixed Model Temperature**

```python
# Use a STABLE temperature for the model (empirically determined)
RHYTHMIC_CREATOR_TEMPERATURE = 0.7  # Or whatever produces best continuations

model_output = rhythmic_model.generate(
    input_pattern=context,
    temperature=RHYTHMIC_CREATOR_TEMPERATURE  # FIXED, not spice-controlled
)

# Then use spice ONLY for post-processing:
anchored = timing_anchor(model_output, original, spice_level=current_spice_level)
```

**Benefits:**
- Model always generates stable continuations (consistent temperature)
- Spice controls how much we vary from that (timing drift, fills, density matching)
- Maximum control and predictability

**Testing Plan:**
1. Test rhythmic_creator at fixed temperatures: 0.3, 0.5, 0.7, 0.9, 1.0
2. Generate 10 variations per temperature using same input pattern
3. Measure: hit count variation, drum class consistency, timing coherence
4. Find "sweet spot" temperature that produces stable, musical continuations
5. Document optimal value in code comments

## Error Handling & Edge Cases

### Edge Case 1: Model Generates Zero Usable Hits

**Handling:**
```python
if len(model_hits) < 3:  # Minimum threshold
    print("  Warning: Model generated too few hits, falling back to algorithmic variation")
    return generate_musical_variation(pattern, spice_level), False
```

### Edge Case 2: All Hits Filtered During Anchoring

**Handling:**
```python
# After anchoring process
if len(anchored_hits) < 2:
    print("  Warning: All hits filtered during anchoring, using model output directly")
    return model_hits  # Skip anchoring, use raw model output
```

### Edge Case 3: Extreme Spice Values

**Low extreme (spice = 0.0):**
- max_drift = 0.02s (20ms - very tight)
- fill_probability = 0.0 (no fills)
- Result: Near-perfect copy of input timing

**High extreme (spice = 1.0):**
- max_drift = 0.15s (150ms - very loose)
- fill_probability = 0.8 (lots of fills)
- Result: More creative, but still related to input

### Edge Case 4: Very Sparse Input (2-3 hits)

**Handling:**
- Timing grid has very few positions
- Model can still add fills between them at high spice
- Low spice might produce very sparse variations (2-4 hits total)
- This is desirable - preserves sparse feel!

### Edge Case 5: Very Dense Input (20+ hits)

**Handling:**
- Large timing grid
- Model likely generates fewer hits than grid positions
- Result: Simplified variations (which is musically valid)

### Fallback Strategy

Any time the anchoring process fails or produces questionable output, fall back to `generate_musical_variation()`. This ensures the user always gets something musical, even if it's not AI-generated.

## Implementation

### Files to Modify

```
src/drum_variation_ai.py
├── rhythmic_creator_variation()  [MODIFY]
│   └── Add timing_anchor() call after density matching
│
├── timing_anchor()  [NEW FUNCTION]
│   └── Core timing anchoring logic
│
├── generate_musical_variation()  [NEW FUNCTION]
│   └── Algorithmic fallback with spice control
│
└── groove_preserve()  [REPLACE]
    └── Replace with generate_musical_variation()
```

### New Function: timing_anchor()

```python
def timing_anchor(model_pattern: DrumPattern,
                  original_pattern: DrumPattern,
                  spice_level: float) -> DrumPattern:
    """
    Anchor model hits to original pattern's timing grid.

    Args:
        model_pattern: Raw output from rhythmic_creator
        original_pattern: User's beatbox input
        spice_level: 0.0-1.0 (controls drift and fills)

    Returns:
        Anchored pattern with timing locked to original groove
    """
    # Extract timing grid from original
    timing_grid = [hit.timestamp for hit in original_pattern.hits]

    # Calculate spice-based parameters
    max_drift = 0.02 + (spice_level * 0.13)  # 20ms-150ms
    fill_probability = spice_level * 0.8     # 0%-80%

    anchored_hits = []

    for model_hit in model_pattern.hits:
        # Find nearest grid position
        nearest_pos = min(timing_grid, key=lambda t: abs(t - model_hit.timestamp))
        distance = abs(model_hit.timestamp - nearest_pos)

        if distance < max_drift:
            # Anchor to grid position
            anchored_hits.append(DrumHit(
                drum_class=model_hit.drum_class,  # Trust model's choice
                timestamp=nearest_pos,
                velocity=model_hit.velocity,
                delta_time=0.0  # Will recalculate
            ))
        elif random.random() < fill_probability:
            # Keep as fill (off-grid)
            anchored_hits.append(model_hit)

    # Create pattern and recalculate delta_times
    result = DrumPattern(hits=anchored_hits, loop_duration=original_pattern.loop_duration)
    result._recalculate_delta_times()

    return result
```

### Integration Point in rhythmic_creator_variation()

```python
def rhythmic_creator_variation(pattern: DrumPattern, temperature: float = 0.7) -> tuple:
    """[Existing function, modified]"""

    # ... existing code for model generation ...
    # ... existing code for density matching (wrap vs continuation) ...

    # Create raw pattern with natural duration
    raw_pattern = DrumPattern(hits=shifted_hits, loop_duration=natural_duration)

    # NEW: Apply timing anchoring BEFORE time-warping
    print(f"    Applying timing anchoring (spice: {temperature:.2f})...")
    anchored_pattern = timing_anchor(raw_pattern, pattern, temperature)

    if not anchored_pattern.hits or len(anchored_pattern.hits) < 2:
        print("  Warning: Timing anchoring failed, falling back to algorithmic variation")
        return generate_musical_variation(pattern, temperature), False

    # Time-warp to fit exact loop duration
    variation = fit_to_loop_duration(anchored_pattern, pattern.loop_duration)

    if not variation.hits:
        print("  Warning: No hits after time-warping, falling back")
        return generate_musical_variation(pattern, temperature), False

    print(f"    Final variation: {len(variation.hits)} hits")
    return variation, True
```

### Incremental Testing Plan

**Phase 1: Test Current Density Matching** (already implemented)
- Run rhythmic_creator with current code
- Check if wrap selection improves hit count
- Document results

**Phase 2: Add Timing Anchoring**
- Implement `timing_anchor()` function
- Test with various spice levels
- Measure timing deviation metrics
- Compare before/after

**Phase 3: Add Algorithmic Fallback**
- Implement `generate_musical_variation()`
- Test fallback when model fails
- Compare neural vs algorithmic output quality

**Phase 4: Run Full Evaluation Suite**
- Temperature stability test
- Timing anchoring evaluation
- Spice control evaluation
- Rhythmic_creator vs Gemini comparison

**Phase 5: Document Results**
- Write markdown docs in `docs/evaluation/`
- Include metrics, examples, audio files
- Prepare for ACM C&C 2026 paper

## Testing & Validation

### Test 1: Timing Deviation Metrics

**Measure:**
```python
def measure_timing_deviation(original_pattern, variation_pattern):
    """
    For each variation hit, find distance to nearest original hit.
    Returns average deviation in milliseconds.
    """
    original_grid = [hit.timestamp for hit in original_pattern.hits]

    deviations = []
    for var_hit in variation_pattern.hits:
        nearest_distance = min(abs(var_hit.timestamp - t) for t in original_grid)
        deviations.append(nearest_distance * 1000)  # Convert to ms

    return {
        'avg_ms': avg_deviation,
        'max_ms': max_deviation,
        'within_50ms': sum(1 for d in deviations if d < 50) / len(deviations)
    }
```

**Expected Results by Spice:**
- **Low spice (0.2)**: avg < 30ms, max < 50ms, 95%+ within 50ms
- **High spice (0.8)**: avg < 100ms, max < 150ms, 70%+ within 50ms

### Test 2: Density Preservation

**Measure:**
```python
def measure_density_similarity(original, variation):
    """How close is the variation's density to the original?"""
    orig_count = len(original.hits)
    var_count = len(variation.hits)
    density_ratio = var_count / orig_count

    return {
        'original_hits': orig_count,
        'variation_hits': var_count,
        'ratio': density_ratio,  # 1.0 = same, 1.5 = 50% denser
        'within_30_percent': 0.7 <= density_ratio <= 1.3
    }
```

**Expected:** Most variations should be 0.7x to 1.5x original density.

### Test 3: Spice Level Response

Generate 10 variations at each spice level (0.0, 0.5, 1.0), measure:

**Expected correlations with increasing spice:**
- Timing deviation increases ✓
- Drum class changes increase ✓
- Fill hit count increases ✓
- Consistency decreases (more randomness) ✓

### Test 4: Integration Test

**Full workflow:**
```bash
# 1. Record a test pattern
python test_timing_anchoring.py --record-test-pattern

# 2. Generate 5 variations at spice=0.2
python test_timing_anchoring.py --spice 0.2 --count 5

# 3. Generate 5 variations at spice=0.8
python test_timing_anchoring.py --spice 0.8 --count 5

# 4. Print metrics for all 10 variations
# 5. Export to .wav files for listening test
```

### Test 5: Subjective Listening Test (Most Important!)

Record a beatbox loop and generate variations at different spice levels.

**Questions:**
- Does switching between original and variation feel natural?
- At low spice, is it "your groove but improved"?
- At high spice, is it creative but still recognizable?
- Can you perform live with these variations?

**Success Criteria:**
- ✅ 80%+ of variations feel musically related to input
- ✅ Timing feels locked to your groove
- ✅ Spice control is intuitive (low = safe, high = creative)
- ✅ Better than current rhythmic_creator output
- ✅ Fast enough for live performance (<15 seconds)

## Evaluation & Documentation for ACM C&C 2026

### Documentation Structure

```
docs/evaluation/
├── 2026-03-11-temperature-stability-test.md
│   └── Results of finding optimal fixed temperature
│
├── 2026-03-XX-timing-anchoring-evaluation.md
│   └── Metrics comparing before/after timing anchoring
│
├── 2026-03-XX-spice-control-evaluation.md
│   └── How spice affects output at different levels
│
└── 2026-03-XX-rhythmic-vs-gemini-comparison.md
    └── Quantitative + qualitative comparison
```

### Test 1: Temperature Stability Evaluation

**File:** `docs/evaluation/2026-03-11-temperature-stability-test.md`

**Methodology:**
- Test patterns: sparse (9 hits), dense (20 hits), syncopated (12 hits)
- Temperatures tested: [0.3, 0.5, 0.7, 0.9, 1.0]
- Repetitions: 10 per temperature

**Metrics:**
- Average hit count and standard deviation
- Hit count range (min-max)
- Consistency score (lower σ = more consistent)
- Musical coherence (subjective rating)

**Format:**
```markdown
| Temperature | Avg Hits | Std Dev | Hit Count Range | Consistency | Musical Coherence |
|-------------|----------|---------|-----------------|-------------|-------------------|
| 0.3         | 12.3     | 1.2     | 11-14           | High (σ=1.2)| ✓ Predictable    |
| 0.7         | 14.2     | 3.8     | 9-21            | Medium-Low  | ✓ Creative       |
| 1.0         | 21.3     | 8.7     | 8-35            | Very Low    | ✗ Chaotic        |

### Recommendation
Temperature 0.7 provides best balance: moderate variation, musical coherence, creative without chaos.
```

### Test 2: Timing Anchoring Evaluation

**File:** `docs/evaluation/2026-03-XX-timing-anchoring-evaluation.md`

**Methodology:**
- Compare before/after timing anchoring on 5-10 diverse patterns
- Measure timing deviation, density similarity, groove preservation

**Format:**
```markdown
### Timing Deviation from Input Grid

| Pattern | Before Anchoring | After Anchoring | Improvement |
|---------|------------------|-----------------|-------------|
| Sparse 9-hit | 347ms avg | 42ms avg | **88% ↓** |
| Dense 20-hit | 412ms avg | 38ms avg | **91% ↓** |

Result: Timing anchoring reduces deviation by 88% average

### Qualitative Observations

Before: "Feels like a different song", "Doesn't match my groove"
After: "That's MY groove with variation!", "Switching feels natural"
```

### Test 3: Spice Control Evaluation

**File:** `docs/evaluation/2026-03-XX-spice-control-evaluation.md`

**Format:**
```markdown
## Input Pattern: Sparse Kicks (9 hits, 4.27s)

### Spice 0.2 (Conservative)
- Avg timing drift: 18ms
- Drum class changes: 1.2/9 hits (13%)
- Fill additions: 0.3 hits average
- Subjective: "Very similar, safe variation"

### Spice 0.8 (Creative)
- Avg timing drift: 92ms
- Drum class changes: 6.8/9 hits (76%)
- Fill additions: 4.3 hits average
- Subjective: "Bold variation, still recognizable"

[Include audio examples at each spice level]
```

### Test 4: Rhythmic Creator vs Gemini Comparison

**File:** `docs/evaluation/2026-03-XX-rhythmic-vs-gemini-comparison.md`

**Format:**
```markdown
| Metric | Rhythmic Creator | Gemini | Winner |
|--------|------------------|--------|--------|
| Generation Time | 8.3s avg | 18.7s avg | **RC 2.3x faster** |
| Timing Deviation | 45ms avg | 12ms avg | Gemini (better) |
| Novelty Score | 0.73 | 0.42 | **RC (more creative)** |
| Cost per variation | $0 | $0.003 | **RC (free)** |
| Offline capability | ✓ Yes | ✗ No | **RC** |

Conclusion: With timing anchoring, rhythmic_creator achieves comparable groove preservation to Gemini while maintaining superior novelty and speed.
```

### Evaluation Test Suite

**Implementation:**
```python
# src/evaluation/run_all_tests.py

def run_evaluation_suite():
    """Run all evaluation tests and generate markdown documentation."""
    print("Running evaluation suite for ACM C&C 2026 paper...")

    # Test 1: Temperature stability
    temp_results = test_temperature_stability()
    save_markdown(temp_results, "docs/evaluation/temperature-stability-test.md")

    # Test 2: Timing anchoring
    anchoring_results = test_timing_anchoring()
    save_markdown(anchoring_results, "docs/evaluation/timing-anchoring-evaluation.md")

    # Test 3: Spice control
    spice_results = test_spice_control()
    save_markdown(spice_results, "docs/evaluation/spice-control-evaluation.md")

    # Test 4: Comparison
    comparison = test_rhythmic_vs_gemini()
    save_markdown(comparison, "docs/evaluation/rhythmic-vs-gemini-comparison.md")

    print("✓ All tests complete. Documentation saved to docs/evaluation/")
    print("  Results ready for ACM C&C 2026 paper.")
```

## Success Criteria

### Quantitative Metrics

1. **Timing Accuracy:** 80%+ of hits within 50ms of input grid at low spice
2. **Density Preservation:** Output within 0.7x-1.5x of input hit count
3. **Spice Correlation:** Clear relationship between spice level and variation metrics
4. **Performance:** Generation time < 15 seconds for live use

### Qualitative Metrics

1. **Musicality:** Switching between original and variation feels natural
2. **Groove Preservation:** Variations recognizable as "that groove"
3. **Spice Intuitiveness:** Low = conservative, high = creative (as expected)
4. **Improvement:** Better than current unanchored rhythmic_creator

### Research Contribution

For ACM C&C 2026 paper:
- Novel approach to adapting continuation models for variation generation
- Timing anchoring technique for groove preservation
- Evaluation framework comparing neural vs. algorithmic approaches
- Documentation of temperature stability findings
- Real-world performance system integration

## Open Questions

1. **Optimal fixed temperature:** Need empirical testing to determine (likely 0.5-0.8 range)
2. **Spice curve:** Linear mapping (0.0-1.0) or exponential for more control at low end?
3. **Fill detection:** Should we use more sophisticated criteria beyond distance threshold?
4. **Multi-track:** Does timing anchoring extend to multi-track scenarios (Phase 3)?

## Future Enhancements

**Not in scope for initial implementation:**

1. **Adaptive temperature:** Learn optimal temperature per user/pattern type
2. **Grid subdivision:** Allow fills on subdivisions of the timing grid (8th notes, 16th notes)
3. **Groove templates:** Extract common groove patterns and bias anchoring toward them
4. **Hybrid anchoring:** Blend model timing with user timing based on spice
5. **Multi-model ensemble:** Combine multiple model outputs for better stability

## References

- Jake Chen's rhythmic_creator model (CalArts MFA Thesis 2025)
- AI_GENERATIONS.md (existing integration documentation)
- CLAUDE.md (project overview and current system state)

## Approval

**Status:** Approved by user on 2026-03-11

**Next Steps:**
1. Run spec-document-reviewer for validation
2. User review of written spec
3. Invoke writing-plans skill to create implementation plan
