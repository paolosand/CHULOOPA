# Variation Bank Sorting by Deviation

**Date:** 2026-04-02
**File:** `src/drum_variation_generator.py`
**Status:** Approved

## Problem

The 5-slot variation bank generates at fixed spice levels (0.2, 0.4, 0.6, 0.8, 1.0), where spice controls the number of tokens requested from `rhythmic_creator`. Because the model runs at fixed temperature (1.0), a low-spice run can produce a more complex/deviant pattern than a high-spice run. Slots 1–5 are not reliably ordered by deviation from the original.

## Goal

Re-order the slot files after generation so that slot 1 is always the least deviant variation and slot 5 is the most deviant. ChucK's existing slot→spice mapping remains unchanged.

## Trimming Note

Hits are trimmed by `start_time >= loop_duration` in `rhythmic_creator_to_chuloopa` (format_converters.py:136). Hits that start before the boundary are kept in full — `end_time` is not considered and hits are never shortened. Scoring must happen on the already-trimmed `DrumPattern` (post-generation, not on raw model output).

## Scoring Function

```python
CORE_KIT = {35, 36, 38, 40, 42}  # kick variants + snare variants + closed hat

def compute_deviation_score(variation: DrumPattern, original: DrumPattern) -> float:
    hit_delta = len(variation.hits) - len(original.hits)
    non_standard = sum(1 for h in variation.hits if h.midi_note not in CORE_KIT)
    return hit_delta + 0.3 * non_standard
```

- **`hit_delta`** — primary driver. More hits = more deviant. Can be negative (sparser than original).
- **`non_standard`** — secondary. Counts hits outside core kick/snare/hat set (e.g. open hat 46, crash 49, ride 51, toms). Weighted 0.3 so a few exotic notes don't outweigh a meaningful hit count difference.
- Both computed on the trimmed `DrumPattern`.

### Scoring examples (original: 14 hits, all core kit)

| Variation | Hits | Non-std | hit_delta | Score | Slot |
|-----------|------|---------|-----------|-------|------|
| Sparse, core only | 11 | 0 | -3 | -3.0 | 1 |
| Same count, core only | 14 | 0 | 0 | 0.0 | 2 |
| Same count + open hat/ride | 14 | 4 | 0 | 1.2 | 3 |
| Denser, core only | 16 | 0 | +2 | 2.0 | 4 |
| Denser + crash/open hat | 16 | 3 | +2 | 2.9 | 5 |

Ties between close scores are acceptable — the bank needs rough least→most ordering, not exact ranking.

## Implementation

### Approach

Sort-and-rewrite in `_generation_worker` after all slot threads join. Generation flow is unchanged.

### Changes

**1. Add `compute_deviation_score` function** — pure function, no side effects. Place near the top of the algorithmic variations section.

**2. Modify `_generation_worker`** — add a sort-and-rewrite step after all threads join, before sending `bank_ready`:

```
After all slot threads joined:
  1. Load each written variation file into DrumPattern
  2. Score each against original pattern using compute_deviation_score
  3. Sort written_slots by score ascending
  4. Load all variation files into memory
  5. Write them back in sorted order to var1..var{n}.txt (in-memory rewrite avoids rename conflicts)
  6. Send /chuloopa/bank_ready OSC
```

**3. `bank_ready` timing change** — currently fires when slot 1 joins. After this change, fires after all slots are done and sorted. Net improvement: ChucK receives a fully-ordered bank rather than a partial one.

### No changes to

- `_run_slot_thread` — slots still generate at spice 0.2→1.0, still write to var1..var5.txt initially
- ChucK side — slot numbering and OSC messages unchanged
- `generate_variations_for_track` (single-variation legacy path) — untouched

## Out of Scope

- Timing displacement metric (requires hit-matching across patterns with insertions/deletions — too complex for marginal gain)
- Multi-track support
- Exposing scores to ChucK via OSC
