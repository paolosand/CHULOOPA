# Implementation Plan: Spice-Controlled Batch Variation Generation for CHULOOPA

**Date:** March 13, 2026
**Author:** Claude Sonnet 4.5 (claude.ai/code)
**Status:** Planning - Not Yet Implemented

**Goal:** Fix inconsistent variation quality and enable spice-controlled complexity in rhythmic_creator AI variations.

**Timeline:** 1-2 weeks (AIMC deadline)

---

## Problem Statement

Current issues with CHULOOPA's variation generation:
1. **Inconsistent quality:** Some variations good, some bad, no way to filter
2. **Inconsistent complexity:** Some simple, some complex, unpredictable
3. **Spice ignored by model:** Temperature fixed at 0.9, spice only affects post-processing
4. **No user control:** Can't reliably get "conservative" vs "creative" variations

## Solution Overview

Replace single-shot generation with **batch generation + intelligent ranking**:

```
CURRENT: Generate 1 variation (temp=0.9 fixed) → Done

NEW: Generate 5 variations (temp=spice-based) → Filter invalid → Rank by complexity → Select best → Done
```

**Key Principles:**
- **Parallel generation:** 3-5 variations on GPU simultaneously (~2-3x slower, not 5x)
- **Spice controls both:** Temperature range (diversity) + target complexity (selection)
- **Quality filtering:** Reject variations with musical errors
- **Pragmatic metrics:** Fast, reliable complexity scoring (density, velocity, diversity)

## Architecture Components

### 1. Batch Generation Module
**File:** `src/rhythmic_creator_model.py`

Add `generate_variations_batch()` method:
- Generate N variations in parallel (batch_size=N)
- Each variation uses different temperature from spice-controlled range
- Return list of generated patterns

**Spice → Temperature Mapping:**
- Low spice (0.0-0.35): temp_range = [0.6, 0.8] (conservative)
- Mid spice (0.35-0.65): temp_range = [0.75, 1.05] (balanced)
- High spice (0.65-1.0): temp_range = [0.94, 1.34] (creative)

### 2. Complexity Metrics Module
**File:** `src/variation_metrics.py` (NEW)

Calculate complexity score (0.0-1.0) using:
- **Hit density** (40% weight): hits per second, normalized
- **Velocity variance** (30% weight): dynamic range
- **Drum diversity** (30% weight): entropy of drum class distribution

Fast computation: <10ms per variation

### 3. Musicality Filter Module
**File:** `src/variation_filters.py` (NEW)

Validation rules to reject invalid variations:
- Minimum 2 hits, maximum 100 hits (for 2-3s loop)
- No duplicate timestamps (same drum at same time)
- No impossible rolls (same drum <30ms apart)
- Valid velocity range (0.0-1.0)
- Temporal ordering (sorted by timestamp)

Returns: `(is_valid: bool, reason: str)`

### 4. Selection Module
**File:** `src/variation_selector.py` (NEW)

Ranking algorithm:
1. Filter out invalid variations
2. Calculate complexity score for each valid variation
3. Select variation with complexity closest to target
4. If tie, randomly select (adds variety across regenerations)

**Spice → Target Complexity Mapping:**
- Linear: `target_complexity = 0.3 + (spice * 0.6)`
- Spice 0.0 → target 0.3 (sparse, simple)
- Spice 0.5 → target 0.6 (medium)
- Spice 1.0 → target 0.9 (dense, complex)

**Fallback:** If all variations invalid, use `generate_musical_variation()` (heuristic)

### 5. Integration Point
**File:** `src/drum_variation_ai.py`

Modify `rhythmic_creator_variation()` (lines 792-924):
- Replace single `generate_variation()` call with `generate_variations_batch()`
- Add selection logic to pick best from batch
- Keep existing timing anchor post-processing (already works well)

## Critical Files

| File | Type | Lines | Changes |
|------|------|-------|---------|
| `src/rhythmic_creator_model.py` | MODIFY | 110-229 | Add `generate_variations_batch()`, modify `_generate_with_temperature()` for batch temperatures |
| `src/drum_variation_ai.py` | MODIFY | 792-924 | Replace single-shot with batch pipeline in `rhythmic_creator_variation()` |
| `src/variation_selector.py` | NEW | ~150 | Spice mappings + ranking logic |
| `src/variation_metrics.py` | NEW | ~100 | Complexity scoring (3 metrics) |
| `src/variation_filters.py` | NEW | ~80 | Validation rules (6 filters) |
| `src/models/rhythmic_creator/lstm_integration.py` | READ ONLY | 56-59 | No changes needed - `init_hidden()` already supports batch_size |

## Implementation Steps

### Week 1: Core Functionality (MVP)

**Days 1-2: Batch Generation**
- [ ] Modify `_generate_with_temperature()` to accept list of temperatures
- [ ] Implement `generate_variations_batch()` method
- [ ] Test batch generation speed (target: <60s for 5 variations)
- [ ] If too slow, reduce to 3 variations

**Days 3-4: Metrics & Filters**
- [ ] Create `variation_metrics.py` (density + velocity + diversity)
- [ ] Create `variation_filters.py` (6 validation rules)
- [ ] Unit test with synthetic patterns (sparse vs dense)

**Days 5-6: Selection & Integration**
- [ ] Create `variation_selector.py` (spice mappings + ranking)
- [ ] Modify `rhythmic_creator_variation()` to use batch pipeline
- [ ] End-to-end test with real beatbox patterns

**Day 7: Testing & Validation**
- [ ] Run spice sweep test (0.0, 0.3, 0.5, 0.7, 1.0)
- [ ] Listening tests in ChucK
- [ ] Verify spice knob feels responsive
- [ ] **Checkpoint:** MVP working or pivot to fallback?

### Week 2: Polish & Evaluation (if time permits)

**Days 8-9: Optimization**
- [ ] Profile performance bottlenecks
- [ ] Tune complexity metric weights based on listening tests
- [ ] Add syncopation metric if schedule allows

**Days 10-11: Documentation & Demo**
- [ ] Generate comparison plots (spice vs complexity)
- [ ] Record demo videos for AIMC
- [ ] Update CLAUDE.md

**Days 12-14: Paper Writing & Buffer**
- [ ] Evaluation section for paper
- [ ] Contingency for unexpected issues
- [ ] Final submission prep

## Verification Strategy

### Unit Tests
Create in `src/` directory:

**1. `test_batch_generation.py`**
- Load model, generate 5 variations
- Verify: 5 unique outputs, all valid format
- Measure: Time per variation (target: <12s each on cloud GPU)

**2. `test_complexity_metrics.py`**
- Create synthetic patterns: sparse (3 hits/2s), dense (20 hits/2s)
- Verify: Metrics correctly rank dense > sparse
- Measure: Computation time (<10ms per pattern)

**3. `test_validation_filters.py`**
- Create invalid patterns: 1 hit, 150 hits, duplicate timestamps, impossible roll
- Verify: All correctly rejected with reasons

**4. `test_spice_control.py`**
- Generate 10 variations at spice=0.2 and spice=0.8
- Verify: High spice has higher average complexity
- Success criterion: Complexity difference >0.2

### Integration Test

**5. `test_batch_pipeline_e2e.py`**
```python
# Load real pattern
original = DrumPattern.from_file("tracks/track_0/track_0_drums.txt")

# Test spice sweep
for spice in [0.0, 0.3, 0.5, 0.7, 1.0]:
    variation, success = rhythmic_creator_variation(original, spice)
    complexity = calculate_complexity_score(variation)
    target = spice_to_target_complexity(spice)
    print(f"Spice {spice}: target={target:.2f}, actual={complexity:.2f}, error={abs(complexity-target):.2f}")
```

**Success Criteria:**
- Average error <0.15 (complexity within 15% of target)
- Total time <60s for 5 variations
- No crashes, no fallbacks

### Listening Tests
- Record 3 beatbox patterns (simple, medium, complex)
- Generate variations at spice=0.3, 0.5, 0.8
- Manual validation:
  - [ ] Variations sound musical (no nonsense)
  - [ ] Low spice = conservative (close to original)
  - [ ] High spice = creative (interesting changes)
  - [ ] No timing artifacts

## Risk Mitigation

**Risk 1: Batch generation too slow**
- Mitigation: Reduce to 3 variations, optimize GPU usage
- Fallback: Single-shot with temperature variation

**Risk 2: All variations rejected by filters**
- Mitigation: Fall back to `generate_musical_variation()` (heuristic)
- Tracking: Log rejection rates, tune thresholds if >50%

**Risk 3: Complexity metrics don't correlate with spice**
- Mitigation: Early validation (test_spice_control.py in Week 1)
- Fallback: Simplify to density-only metric

**Risk 4: Time overrun (can't finish in 1-2 weeks)**
- Mitigation: Phased implementation (Week 1 = MVP, Week 2 = polish)
- Fallback: Ship Week 1 MVP, skip Week 2 features

## Success Metrics

**Must Achieve (MVP):**
- [ ] Generate 3-5 variations in <60s total
- [ ] Spice=0.2 produces simpler patterns than spice=0.8 (subjective listening test)
- [ ] No crashes during 20 consecutive generations
- [ ] Variation quality ≥ current single-shot

**Nice to Have:**
- [ ] Complexity score correlates with spice (R² > 0.5)
- [ ] Generation time <40s for 5 variations
- [ ] Filter rejection rate <20%
- [ ] User-perceivable difference across 5 spice levels

## Alternative Approaches (If Primary Plan Fails)

### Fallback 1: Temperature Variation Only
- No batch generation, no ranking
- Just vary temperature based on spice (1 variation per call)
- Simpler, faster to implement
- Less consistent quality

### Fallback 2: Post-Hoc Filtering Only
- Keep single-shot generation
- Add validation filters, regenerate if invalid
- No complexity ranking
- Improves reliability, not creativity

### Fallback 3: Pre-Computed Variation Bank
- Generate 20 variations offline, store in files
- Select from bank at runtime based on spice
- Fast, but not reactive to user input

## Key Design Decisions

**Q: Should spice control temperature and complexity separately or together?**
**A:** COUPLED - Same spice value controls both, but with different mappings. High spice = wide temperature range + preference for complex patterns. This matches user expectation ("spice = crazier").

**Q: How many variations to generate?**
**A:** Start with 5, reduce to 3 if performance issues. More variations = better selection quality but slower generation.

**Q: What if all variations are invalid?**
**A:** Fall back to `generate_musical_variation()` (algorithmic heuristic). Never fail silently - always return a variation.

**Q: Should we retrain the model?**
**A:** NO - not enough time for 1-2 week deadline. Use existing checkpoint with inference-time control. Retraining can be future work post-AIMC.

## Expected Outcomes

After implementation:
1. **Consistent quality:** Invalid variations filtered out, user always gets playable pattern
2. **Spice control works:** Low spice = conservative, high spice = creative (both generation AND selection)
3. **Predictable complexity:** Spice knob reliably produces target complexity level
4. **Live performance ready:** Total latency <60s acceptable for performance workflow

This transforms CHULOOPA from "random AI dice roll" to "controlled creative instrument" - a key contribution for the AIMC paper.

---

## Next Steps

When ready to implement:
1. Start with Week 1 MVP (batch generation + basic metrics)
2. Test early and often (especially temperature ranges and spice control)
3. Be prepared to cut scope if timeline is tight
4. Document findings for AIMC paper as you go

Good luck! 🥁
