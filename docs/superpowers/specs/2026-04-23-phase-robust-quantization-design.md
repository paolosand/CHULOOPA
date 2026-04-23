# Phase-Robust Grid Quantization

**Date:** 2026-04-23
**Status:** Approved for implementation

## Problem

The current quantization algorithm (`step = round(timestamp / step_duration)`) fails when the user starts playing slightly late into a recording. A phase offset of even 0.07s can push all hits past the rounding boundary, shifting every step assignment by +1 and feeding the wrong groove into the grid model. All 5 variations then inherit the shifted pattern.

Secondary failure: when loop duration varies slightly across takes, later hits in the bar drift across rounding boundaries independently, producing inconsistent step assignments for the same intended groove.

Confirmed across 4 test recordings of the same pattern: inputs 2 and 4 produced wrong step assignments (shifted by 1 step) under the naive algorithm.

## Algorithm

### BPM estimation

Unchanged. `step_duration = loop_duration / 16`. The system controls recording length (one bar in 4/4), so loop_duration is a reliable tempo reference.

### Phase estimation (new)

Each hit has a fractional position within its grid cell: `timestamp % step_duration`. If the performance is on-grid but phase-shifted, all these fractions cluster near the same value — the phase offset. Take the median as the phase estimate, subtract before quantizing.

```
step_duration = loop_duration / 16
fracs         = [hit.timestamp % step_duration for hit in hits]
phase         = median(fracs)
step          = clamp(round((hit.timestamp - phase) / step_duration), 0, 15)
```

Verified: produces correct step assignments (`0, 4, 6, 8, 12`) for all 4 test inputs including the previously-failing inputs 2 and 4.

### Spread diagnostic (new)

```
spread = max(fracs) - min(fracs)
if spread > 0.25 * step_duration:
    log warning: "loose timing — quantization is a best approximation"
```

Threshold of 0.25 steps flags patterns where hits are not consistently aligned to the same grid phase (swing, flams, triplets, sloppy performance). No behavior change — just a transparent signal for debugging and paper documentation.

## Shared function

Extract one function used everywhere:

```python
def quantize_to_steps(hits: list[DrumHit], loop_duration: float) -> list[tuple[int, int]]:
    """Returns [(step, midi_note), ...] sorted by step.

    Uses median phase estimation to correct for constant timing offsets
    (e.g. user starts playing slightly late in the recording window).
    """
    step_duration = loop_duration / 16
    fracs = [h.timestamp % step_duration for h in hits]
    phase = statistics.median(fracs) if fracs else 0.0

    spread = max(fracs) - min(fracs) if fracs else 0.0
    if spread > 0.25 * step_duration:
        print(f"  [Quantize] Warning: loose timing (spread={spread:.4f}s = "
              f"{spread/step_duration:.2f} steps) — best approximation")

    events = []
    for hit in hits:
        step = max(0, min(15, round((hit.timestamp - phase) / step_duration)))
        events.append((step, hit.midi_note))
    return sorted(events)
```

## Pipeline changes

### Current order in `_generation_worker()`

```
read file → generate 5 variations (each internally re-quantizes) → sort bank
          → write quantized original → fire bank_ready
```

### New order

```
read file → quantize once → write to disk immediately  ← ChucK gets clean loop ASAP
          → generate 5 variations from quantized pattern → sort bank → fire bank_ready
```

The `# quantized` marker (d9ea631) already suppresses the watchdog from seeing the immediate write as a new recording.

### Touch points

| Location | Change |
|---|---|
| `_generation_worker()` | Quantize upfront, write immediately, pass quantized pattern downstream |
| `grid_model_variation()` | Replace inline rounding with `quantize_to_steps()`; internal re-quantization becomes redundant but harmless |
| `format_converters.py:chuloopa_txt_to_grid_tokens()` | Replace inline rounding with `quantize_to_steps()` |
| `_write_quantized_original()` | Fold into `_generation_worker()` — no longer needs to be a separate function called at bank_ready time |

## Known limitations

- **3/4, 6/8, 5/4 time signatures:** Not supported. System always assumes 4/4, 1 bar, 16 steps.
- **Swing/shuffle:** Off-beat hits have a systematically different fractional position than on-beat hits. The median falls between the two populations, giving suboptimal quantization for both. The spread diagnostic will fire.
- **Triplets:** A 16-step grid cannot represent triplet subdivisions (IOI ≈ 1.33 steps). Three evenly-spaced triplet snares will snap to steps 0, 1, 2 or similar non-uniform positions. Information loss is unavoidable at this resolution.
- **Flams / grace notes:** Two hits within one step of each other may snap to the same step, silently dropping one hit. Requires 32-step resolution to preserve, which is out of scope.
- **Large liftoff errors (> ~100ms):** The loop_duration-based BPM estimate is proportionally wrong. Phase estimation partially compensates but later hits in the bar may still drift. IOI-based BPM estimation would close this gap but adds complexity not justified by the use case.
- **Multi-bar recordings:** If the user records 2 bars, the system sees half the intended BPM and step_duration is 2× too large.

## What this does not change

- Velocity normalization (unchanged at 0.75 for quantized hits)
- Loop duration (unchanged — kept as recorded)
- The `# quantized` marker written to the file header
- The watchdog suppression logic from d9ea631
- Rhythmic creator (non-grid) model path — that path works with raw floating-point timestamps and is unaffected
