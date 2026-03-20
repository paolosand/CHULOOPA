# Design: Weighted Variation Selection + Silence Debounce

**Date:** 2026-03-19
**File affected:** `src/chuloopa_drums_v4.ck`
**Status:** Approved

---

## Problem

1. **Repetitive variation playback:** The current auto-switch logic selects a single variation index based on a hard spice-to-index mapping with hysteresis. Once a spice level is stable, the same variation plays on every loop — no musical dynamics.

2. **Broken silence gate:** The current `is_muted` flag sets on any single zero-spice OSC read and unsets immediately on any non-zero read. This is too sensitive and unmutes mid-loop, causing abrupt re-entries.

---

## Solution Overview

Both changes are confined to `src/chuloopa_drums_v4.ck`. No Python changes required.

### Feature 1: Weighted Probabilistic Variation Selection

At every loop boundary, instead of hard-switching to a fixed index, perform a weighted random draw across available variations (var0–var5). The probability weights are driven by a **rolling-average spice** (last N loop cycles), and the weight window slides up the variation ladder as spice increases — so at high spice, the "resting state" is var2 (not echo).

### Feature 2: Silence Debounce + Queued Unmute

Muting now requires **N consecutive zero-spice OSC reads** before engaging. Unmuting is **queued to the next loop boundary** for a clean musical re-entry.

---

## New Constants (top of file)

```chuck
// === WEIGHTED VARIATION SELECTION ===
4 => int ROLLING_WINDOW_BARS;      // Loop cycles to average spice over
2 => int MAX_SAME_VAR_REPEATS;     // Max consecutive repeats before forced re-roll

// === SILENCE DEBOUNCE ===
4 => int SILENCE_FRAMES_THRESHOLD; // Consecutive zero-spice reads before muting (4 x 500ms = 2s)
```

---

## New State Variables (with initialisations)

```chuck
// Rolling spice average
float rolling_spice_history[ROLLING_WINDOW_BARS];  // circular buffer
0 => int rolling_spice_idx;                         // write position
0 => int rolling_spice_filled;                      // has buffer wrapped once
0.0 => float rolling_avg_spice;                     // computed each loop boundary

// Last-played tracking (for repeat prevention)
0 => int last_played_var_idx;    // variation index last loaded
0 => int last_played_count;      // consecutive times that index has played

// Silence debounce
0 => int silence_frame_count;    // consecutive zero-spice OSC reads
0 => int queued_unmute;          // 1 = unmute drums at next loop boundary
```

---

## Weight Table

Five anchor spice tiers, each with weights for var0 (echo/original) through var5. The probability mass slides up the ladder as spice increases — high spice's "floor" is var2.

| Tier | Spice | var0 (echo) | var1 | var2 | var3 | var4 | var5 |
|------|-------|-------------|------|------|------|------|------|
| 0    | 0.00  | 0.50        | 0.40 | 0.10 | 0.00 | 0.00 | 0.00 |
| 1    | 0.25  | 0.20        | 0.40 | 0.30 | 0.10 | 0.00 | 0.00 |
| 2    | 0.50  | 0.05        | 0.20 | 0.40 | 0.30 | 0.05 | 0.00 |
| 3    | 0.75  | 0.00        | 0.10 | 0.30 | 0.40 | 0.20 | 0.00 |
| 4    | 1.00  | 0.00        | 0.00 | 0.20 | 0.40 | 0.30 | 0.10 |

Intermediate spice values are linearly interpolated between the two surrounding tiers.

Implemented as a flat float array `WEIGHT_TABLE[30]` (5 tiers × 6 vars), indexed as `WEIGHT_TABLE[tier * 6 + var_idx]`.

**Note:** `variation_available[0]` is intentionally never checked — var0 (echo/original) is always considered available. Only var1–var5 are gated by `variation_available[i]`.

---

## New Function: `pickVariationByWeight(float spice)`

Returns a variation index (0–5).

**Algorithm:**

1. **Clamp and find tiers:** Clamp `spice` to [0.0, 1.0]. If `spice >= 1.0`, use tier 4 directly (no lerp). Otherwise, find the two surrounding anchor tiers (e.g. spice=0.6 → tiers 2 and 3, corresponding to spice=0.50 and 0.75).
2. Compute lerp factor `t = (spice - lower_tier_spice) / (upper_tier_spice - lower_tier_spice)`. The denominator is always 0.25 (fixed tier spacing) — no division-by-zero risk.
3. Interpolate the two weight rows element-wise → 6 raw weights.
4. Zero out weights for unavailable variations: for i = 1 to 5, if `variation_available[i] == 0`, set `raw_weights[i] = 0.0`. (var0/echo is always available — never zeroed here.)
5. **Repeat prevention:** If `last_played_count >= MAX_SAME_VAR_REPEATS`, save the current value of `raw_weights[last_played_var_idx]` (its post-step-4 value, which may already be 0 if that variation is unavailable), then tentatively set it to 0.0. Compute the tentative sum. If the tentative sum > 0.0, keep the zeroing (other options exist). If the tentative sum == 0.0, restore `raw_weights[last_played_var_idx]` to the saved post-step-4 value — accept the repeat. Do NOT restore from the raw interpolated weight; restoring from the post-step-4 value ensures unavailable variations cannot become selectable through this path.
6. Compute the sum of remaining weights. If sum == 0.0, return `current_variation_index` unchanged (no state update).
7. Normalize weights by dividing each by sum.
8. Roll `Math.random2f(0.0, 1.0)`, walk the cumulative weight array to select index.
9. **Update state:** if selected index == `last_played_var_idx`, increment `last_played_count`. Otherwise, set `last_played_var_idx = selected`, `last_played_count = 1`.
10. Return selected index.

**Note on cold-start:** `pickVariationByWeight` is only called once `rolling_spice_filled == 1` (i.e., the buffer has wrapped at least once, meaning N full loop cycles have elapsed). During the warm-up period, the system continues playing the current variation unchanged. This avoids spurious low-spice draws while the rolling average stabilises.

---

## Changes to `masterSyncCoordinator()`

### Replace hysteresis auto-switch block (lines ~1192–1225)

**Remove:**
- `spice_stable_count`, `spice_stable_target` hysteresis logic
- `spiceToVariationIndex()` call

**Add — before queued action processing:**
```
// Push effective_spice into rolling history
effective_spice => rolling_spice_history[rolling_spice_idx];
(rolling_spice_idx + 1) % ROLLING_WINDOW_BARS => rolling_spice_idx;
if(!rolling_spice_filled && rolling_spice_idx == 0) 1 => rolling_spice_filled;

// Compute rolling average (uses actual filled count during warm-up)
0.0 => float spice_sum;
ROLLING_WINDOW_BARS => int spice_count;
if(!rolling_spice_filled) rolling_spice_idx => spice_count;
for(0 => int i; i < spice_count; i++) rolling_spice_history[i] +=> spice_sum;
if(spice_count > 0) spice_sum / spice_count => rolling_avg_spice;
```

**Add — handle queued unmute (before variation selection):**
```
if(queued_unmute && is_muted) {
    0 => is_muted;
    0 => queued_unmute;
    <<< ">>> UNMUTED at loop boundary <<<" >>>;
}
```

**Add — weighted variation selection (replaces hysteresis block):**
```
// Only select once rolling buffer is filled (cold-start guard)
if(!queued_toggle_variation && bank_ready && has_loop[0] && !is_muted && rolling_spice_filled) {
    pickVariationByWeight(rolling_avg_spice) => int target_idx;
    if(target_idx != current_variation_index) {
        target_idx => current_variation_index;
        if(target_idx == 0) {
            loadDrumDataFromFile(0);
            0 => variation_mode_active;
        } else {
            loadVariationFile(0, target_idx);
            1 => variation_mode_active;
        }
    }
}
```

**Remove state:** `spice_stable_count`, `spice_stable_target` (replaced by rolling average).

---

## Changes to `oscListener()` — Silence Gate

**Replace lines ~1310–1316:**

```chuck
if(effective_spice <= 0.0) {
    silence_frame_count++;
    if(silence_frame_count >= SILENCE_FRAMES_THRESHOLD && !is_muted && has_loop[0]) {
        1 => is_muted;
        0 => queued_unmute;  // cancel any pending unmute
        <<< "Silence detected → drums muted" >>>;
    }
} else {
    0 => silence_frame_count;  // reset on any nonzero read
    if(is_muted && !queued_unmute) {
        1 => queued_unmute;
        <<< "Energy resumed → drums will unmute at next loop boundary" >>>;
    }
}
```

Note: `silence_frame_count` is not capped — it increments unboundedly during sustained silence. This is harmless (no overflow risk for realistic performance durations) and is accepted behaviour.

---

## State Cleanup

**Remove from state variable declarations and init blocks:**
- `spice_stable_count`
- `spice_stable_target`

**Remove function:**
- `spiceToVariationIndex()` (replaced by weight table + `pickVariationByWeight()`)

**Remove from existing `clearTrack()` reset block (lines ~1541–1542):**
- `0 => spice_stable_count;`
- `0 => spice_stable_target;`

**Add to `clearTrack()` reset block (track == 0):**
```chuck
0 => rolling_spice_idx;
0 => rolling_spice_filled;
0.0 => rolling_avg_spice;
0 => last_played_var_idx;
0 => last_played_count;
0 => silence_frame_count;
0 => queued_unmute;
```

---

## Acceptance Criteria

- At low spice, loop plays echo and var1 most often with occasional var2
- At high spice, loop plays var2–var4 most often; echo appears rarely or not at all
- Same variation never plays more than `MAX_SAME_VAR_REPEATS` times in a row, unless it is the only currently available variation (in which case the repeat is accepted)
- No variation selection occurs during the first `ROLLING_WINDOW_BARS` loop cycles (cold-start guard)
- Silence sustained for >= 2 seconds mutes drums; loop timing continues running
- After silence, drums re-enter exactly at a loop boundary (never mid-loop)
- Clearing a track resets all new state variables to their zero/initial values
