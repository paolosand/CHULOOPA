# Velocity Humanizer for Grid Model Output

**Date:** 2026-04-23
**Status:** Approved

## Problem

The GPTBarPair grid model hardcodes `velocity=0.75` for every hit during pattern reconstruction. All existing humanization functions (`humanize_pattern`, `groove_preserve`) work as deltas on top of existing velocity — useless when everything starts at the same value. Result: grid variations sound robotic and uniformly loud regardless of how softly the original was played.

## Design

### New function: `humanize_velocity_relative(variation, original)`

A post-processing step applied to the grid model variation before it is returned. Synthesizes fresh velocities for all hits using a Gaussian draw anchored to the original recording's dynamic level.

### Algorithm

1. Compute `base = mean(hit.velocity for hit in original.hits)`
   - If original has no hits, fall back to `base = 0.72`
2. For each hit in variation, look up instrument class:

| Instrument | MIDI notes | Offset from base | Sigma |
|---|---|---|---|
| Kick | 35, 36 | +0.05 | 0.05 |
| Snare | 37, 38, 39, 40 | +0.00 | 0.06 |
| Hat | 42, 44, 46 | −0.15 | 0.08 |
| Other | all others | +0.00 | 0.06 |

3. Draw: `velocity = clamp(gauss(base + offset, sigma), 0.10, 1.0)`

### Rationale for per-instrument values

- Kick gets a slight boost (+0.05) and tight spread (0.05): kicks are typically the loudest element and most consistent in real drumming
- Hat gets the largest negative offset (−0.15) and widest spread (0.08): hats are quietest and vary most — research confirms hats have the largest velocity fluctuations
- Sigma values validated against production literature (Slam Tracks, DeMidify, ResearchGate groove study)

### Why input-anchored

Anchoring to the original's global mean velocity ensures the variation respects the dynamic level of the performance. A softly played beatbox groove produces soft variations; a hard-hit pattern produces louder ones. Fixed absolute centers would slam a gentle input.

### Integration

- Add `humanize_velocity_relative()` near the existing `humanize_pattern` / `groove_preserve` functions in `drum_variation_generator.py`
- Call it at the end of `grid_model_variation()`, just before `return variation, True`
- The original `DrumPattern` is already in scope at that call site
- The hardcoded `velocity=0.75` in the reconstruction loop is left as-is — it is immediately overwritten by this function

### Scope boundary

- Only affects the grid model path (`grid_model_variation`)
- No changes to `humanize_pattern`, `groove_preserve`, or any non-grid variation paths
- No changes to the quantized-original write-back (the `velocity=0.75` in the quantize step is a separate concern and intentionally left alone — it writes the reference file, not a variation)

## Files Changed

- `src/drum_variation_generator.py`: add `humanize_velocity_relative()`, call it in `grid_model_variation()`

## Out of Scope

- Beat-position accent boosting (downbeat kicks, backbeat snares) — valid future enhancement, not needed for quality baseline
- Per-instrument mean anchoring (requires enough hits per class; global mean is more robust for sparse originals)
- Applying humanization to the non-grid variation path (already has `humanize_pattern` calls)
