# Weighted Variation Selection + Silence Debounce Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hard hysteresis-based variation switcher in `chuloopa_drums_v4.ck` with a weighted probabilistic draw driven by rolling-average spice, and fix the silence gate with a consecutive-frame debounce and loop-boundary unmute.

**Architecture:** All changes are in one file (`src/chuloopa_drums_v4.ck`). Tasks build on each other in order — add constants/state first, then add the new function, then wire it into the coordinator and OSC listener, then remove the old code. Each task leaves the file in a compilable state.

**Tech Stack:** ChucK audio programming language, ChuGL, OSC via `OscIn`/`OscOut`. No Python changes. No external test runner — verification is via console output (`<<<`) observed while running.

**Spec:** `docs/superpowers/specs/2026-03-19-weighted-variation-selection-design.md`

---

## File Map

| File | Change |
|------|--------|
| `src/chuloopa_drums_v4.ck` | All changes — constants, state, new function, coordinator, OSC listener, cleanup |

---

## Task 1: Add Constants, State Variables, and WEIGHT_TABLE

**Files:**
- Modify: `src/chuloopa_drums_v4.ck:36-50` (constants block)
- Modify: `src/chuloopa_drums_v4.ck:318-350` (V4 state block)

- [ ] **Step 1.1: Add three new constants after the existing `DEFAULT_SPICE_CEILING` line (line 38)**

Find this line:
```chuck
1.0 => float DEFAULT_SPICE_CEILING;  // Default ceiling (1.0 = no cap)
```

Add immediately after it:
```chuck
// === WEIGHTED VARIATION SELECTION ===
4 => int ROLLING_WINDOW_BARS;      // Loop cycles to average spice over (configurable)
2 => int MAX_SAME_VAR_REPEATS;     // Max consecutive repeats before forced re-roll

// === SILENCE DEBOUNCE ===
4 => int SILENCE_FRAMES_THRESHOLD; // Consecutive zero-spice reads before muting (4 x 500ms = 2s)
```

- [ ] **Step 1.2: Declare WEIGHT_TABLE and add new state variables after the V4 spice state block**

Find this line (around line 349):
```chuck
int spice_stable_count;              // Consecutive windows at same target (hysteresis)
int spice_stable_target;             // Target variation index being confirmed
```

Add immediately after it:
```chuck
// === WEIGHTED VARIATION SELECTION STATE ===
// Weight table: 5 tiers x 6 vars = 30 values, indexed as [tier * 6 + var_idx]
// Tier spice anchors: 0.0, 0.25, 0.50, 0.75, 1.00
float WEIGHT_TABLE[30];

// Rolling spice average
float rolling_spice_history[4];   // size must be a literal in ChucK (= ROLLING_WINDOW_BARS)
0 => int rolling_spice_idx;       // circular buffer write position
0 => int rolling_spice_filled;    // 1 once buffer has wrapped at least once
0.0 => float rolling_avg_spice;   // computed each loop boundary

// Last-played tracking (repeat prevention)
0 => int last_played_var_idx;
0 => int last_played_count;

// Silence debounce
0 => int silence_frame_count;     // consecutive zero-spice OSC reads
0 => int queued_unmute;           // 1 = unmute drums at next loop boundary
```

- [ ] **Step 1.3: Initialize WEIGHT_TABLE values after the state variable declarations**

Find this line (around line 351):
```chuck
// Initialize variation mode state
```

Add immediately before it:
```chuck
// Initialize WEIGHT_TABLE (5 tiers x 6 vars)
// Tier 0 (spice=0.00): echo-dominant
0.50 => WEIGHT_TABLE[0];  0.40 => WEIGHT_TABLE[1];  0.10 => WEIGHT_TABLE[2];
0.00 => WEIGHT_TABLE[3];  0.00 => WEIGHT_TABLE[4];  0.00 => WEIGHT_TABLE[5];
// Tier 1 (spice=0.25): echo fades, var1/var2 rise
0.20 => WEIGHT_TABLE[6];  0.40 => WEIGHT_TABLE[7];  0.30 => WEIGHT_TABLE[8];
0.10 => WEIGHT_TABLE[9];  0.00 => WEIGHT_TABLE[10]; 0.00 => WEIGHT_TABLE[11];
// Tier 2 (spice=0.50): center mass at var2/var3
0.05 => WEIGHT_TABLE[12]; 0.20 => WEIGHT_TABLE[13]; 0.40 => WEIGHT_TABLE[14];
0.30 => WEIGHT_TABLE[15]; 0.05 => WEIGHT_TABLE[16]; 0.00 => WEIGHT_TABLE[17];
// Tier 3 (spice=0.75): center mass at var3, floor shifts to var1
0.00 => WEIGHT_TABLE[18]; 0.10 => WEIGHT_TABLE[19]; 0.30 => WEIGHT_TABLE[20];
0.40 => WEIGHT_TABLE[21]; 0.20 => WEIGHT_TABLE[22]; 0.00 => WEIGHT_TABLE[23];
// Tier 4 (spice=1.00): high-energy, floor is var2
0.00 => WEIGHT_TABLE[24]; 0.00 => WEIGHT_TABLE[25]; 0.20 => WEIGHT_TABLE[26];
0.40 => WEIGHT_TABLE[27]; 0.30 => WEIGHT_TABLE[28]; 0.10 => WEIGHT_TABLE[29];
```

- [ ] **Step 1.4: Smoke test — start ChucK and verify it runs**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
chuck chuloopa_drums_v4.ck
```

Expected: ChucK starts, prints the startup banner, shows `✓ CHULOOPA v4 ready!` with no compile errors. Kill with Ctrl+C.

- [ ] **Step 1.5: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/chuloopa_drums_v4.ck
git commit -m "feat: add WEIGHT_TABLE and new state variables for weighted variation selection"
```

---

## Task 2: Add `pickVariationByWeight()` Function

**Files:**
- Modify: `src/chuloopa_drums_v4.ck` — add function after `spiceToVariationIndex()` (line ~125)

This function implements the weighted draw. It sits alongside `spiceToVariationIndex()` for now; that function is removed in Task 5.

- [ ] **Step 2.1: Add `pickVariationByWeight()` after the closing brace of `spiceToVariationIndex()`**

Find this block (lines 118-125):
```chuck
fun int spiceToVariationIndex(float spice) {
    if(spice < 0.1) return 0;       // Original (silence/very low)
    else if(spice < 0.3) return 1;  // var1 (spice=0.2)
    else if(spice < 0.5) return 2;  // var2 (spice=0.4)
    else if(spice < 0.7) return 3;  // var3 (spice=0.6)
    else if(spice < 0.9) return 4;  // var4 (spice=0.8)
    else return 5;                  // var5 (spice=1.0)
}
```

Add immediately after its closing `}`:
```chuck
// Weighted probabilistic variation selection driven by rolling-average spice.
// The probability window slides up the variation ladder as spice increases.
// Called at every loop boundary once rolling_spice_filled == 1.
fun int pickVariationByWeight(float spice) {
    // Step 1: Clamp spice
    Math.max(0.0, Math.min(1.0, spice)) => spice;

    // Step 2: Find lower tier index (0-4) and lerp factor t
    0 => int lower_tier;
    0.0 => float t;
    if(spice >= 1.0) {
        4 => lower_tier;
        1.0 => t;
    } else {
        (spice / 0.25) $ int => lower_tier;
        if(lower_tier > 3) 3 => lower_tier;
        (spice - lower_tier * 0.25) / 0.25 => t;
    }

    // Step 3: Interpolate between lower and upper tier weight rows
    float raw_weights[6];
    if(lower_tier >= 4) {
        // At spice=1.0, use tier 4 directly
        for(0 => int i; i < 6; i++) {
            WEIGHT_TABLE[4 * 6 + i] => raw_weights[i];
        }
    } else {
        lower_tier + 1 => int upper_tier;
        for(0 => int i; i < 6; i++) {
            WEIGHT_TABLE[lower_tier * 6 + i] => float w_lo;
            WEIGHT_TABLE[upper_tier * 6 + i] => float w_hi;
            w_lo + t * (w_hi - w_lo) => raw_weights[i];
        }
    }

    // Step 4: Zero out unavailable variations (var0/echo is always available)
    for(1 => int i; i <= 5; i++) {
        if(!variation_available[i]) {
            0.0 => raw_weights[i];
        }
    }

    // Step 5: Repeat prevention — if same var played MAX_SAME_VAR_REPEATS times,
    // tentatively zero it; restore if it's the only option
    if(last_played_count >= MAX_SAME_VAR_REPEATS) {
        raw_weights[last_played_var_idx] => float saved_weight;
        0.0 => raw_weights[last_played_var_idx];

        0.0 => float tentative_sum;
        for(0 => int i; i < 6; i++) {
            tentative_sum + raw_weights[i] => tentative_sum;
        }
        if(tentative_sum <= 0.0) {
            saved_weight => raw_weights[last_played_var_idx];  // accept repeat
        }
    }

    // Step 6: Sum check — return unchanged if nothing to select
    0.0 => float weight_sum;
    for(0 => int i; i < 6; i++) {
        weight_sum + raw_weights[i] => weight_sum;
    }
    if(weight_sum <= 0.0) return current_variation_index;

    // Step 7: Normalize
    for(0 => int i; i < 6; i++) {
        raw_weights[i] / weight_sum => raw_weights[i];
    }

    // Step 8: Weighted random walk
    Math.random2f(0.0, 1.0) => float roll;
    0.0 => float cumulative;
    0 => int selected;
    for(0 => int i; i < 6; i++) {
        cumulative + raw_weights[i] => cumulative;
        if(roll <= cumulative) {
            i => selected;
            break;
        }
    }
    // Edge case: floating-point rounding pushed roll past last weight
    if(roll > cumulative) {
        for(5 => int i; i >= 0; i - 1 => i) {
            if(raw_weights[i] > 0.0) {
                i => selected;
                break;
            }
        }
    }

    // Step 9: Update repeat-prevention state
    if(selected == last_played_var_idx) {
        last_played_count + 1 => last_played_count;
    } else {
        selected => last_played_var_idx;
        1 => last_played_count;
    }

    <<< ">>> WEIGHTED PICK: spice=" + (spice * 100) $ int + "% → var" + selected +
        " (last=" + last_played_var_idx + " x" + last_played_count + ")" >>>;

    return selected;
}
```

- [ ] **Step 2.2: Smoke test**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
chuck chuloopa_drums_v4.ck
```

Expected: Starts cleanly. No errors about `WEIGHT_TABLE`, `variation_available`, etc. Kill with Ctrl+C.

- [ ] **Step 2.3: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/chuloopa_drums_v4.ck
git commit -m "feat: add pickVariationByWeight() function with sliding probability window"
```

---

## Task 3: Update `masterSyncCoordinator()` — Rolling Average + Weighted Selection

**Files:**
- Modify: `src/chuloopa_drums_v4.ck:1155-1236` (masterSyncCoordinator body)

This replaces the hysteresis block entirely. The rolling average update goes just before the queued-action processing block; the queued unmute check and weighted selection replace the old hysteresis block.

- [ ] **Step 3.1: Add rolling average update at the top of the loop-boundary processing block**

Inside `masterSyncCoordinator()`, find the line that starts the boundary processing:
```chuck
                <<< "" >>>;
                <<< "=== LOOP BOUNDARY: Processing queued actions ===" >>>;
```

Add immediately after those two print lines:
```chuck
                // === ROLLING SPICE AVERAGE ===
                effective_spice => rolling_spice_history[rolling_spice_idx];
                (rolling_spice_idx + 1) % ROLLING_WINDOW_BARS => rolling_spice_idx;
                if(!rolling_spice_filled && rolling_spice_idx == 0) {
                    1 => rolling_spice_filled;
                }
                // Compute average over filled portion
                0.0 => float spice_sum;
                ROLLING_WINDOW_BARS => int spice_count;
                if(!rolling_spice_filled) rolling_spice_idx => spice_count;
                for(0 => int i; i < spice_count; i++) {
                    spice_sum + rolling_spice_history[i] => spice_sum;
                }
                if(spice_count > 0) spice_sum / spice_count => rolling_avg_spice;
```

- [ ] **Step 3.2: Add queued unmute check just before the existing queued-toggle check**

Find this line:
```chuck
                // Process queued variation toggle
                if(queued_toggle_variation) {
```

Add immediately before it:
```chuck
                // === QUEUED UNMUTE (silence recovery at loop boundary) ===
                if(queued_unmute && is_muted) {
                    0 => is_muted;
                    0 => queued_unmute;
                    <<< ">>> UNMUTED at loop boundary <<<" >>>;
                }

```

- [ ] **Step 3.3: Replace the hysteresis auto-switch block with weighted selection**

Find and replace this entire block:
```chuck
                // === V4: AUDIO-DRIVEN AUTO-SWITCHING (hysteresis) ===
                // Only switches if no manual toggle is queued and bank is available
                if(!queued_toggle_variation && bank_ready && has_loop[0] && !is_muted) {
                    spiceToVariationIndex(effective_spice) => int target_idx;

                    // Hysteresis: confirm target for 2+ consecutive windows (~1 second)
                    if(target_idx == spice_stable_target) {
                        spice_stable_count++;
                    } else {
                        target_idx => spice_stable_target;
                        1 => spice_stable_count;
                    }

                    // Switch only after target is stable for 2+ windows
                    if(spice_stable_count >= 2 && target_idx != current_variation_index) {
                        // Check that the target variation is available
                        if(target_idx == 0 || variation_available[target_idx]) {
                            <<< "" >>>;
                            <<< ">>> AUTO-SWITCH: spice=" + (effective_spice * 100) $ int + "% → var" + target_idx + " <<<" >>>;

                            target_idx => current_variation_index;

                            if(target_idx == 0) {
                                // Load original
                                loadDrumDataFromFile(0);
                                0 => variation_mode_active;
                            } else {
                                // Load variation
                                loadVariationFile(0, target_idx);
                                1 => variation_mode_active;
                            }
                        }
                    }
                }
```

Replace with:
```chuck
                // === V4: WEIGHTED PROBABILISTIC AUTO-SWITCHING ===
                // Only fires after rolling buffer is fully filled (cold-start guard)
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

- [ ] **Step 3.4: Smoke test**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
chuck chuloopa_drums_v4.ck
```

Expected: Starts cleanly. Record a loop, wait 4+ loop cycles. Console should show `>>> WEIGHTED PICK: spice=XX% → varN` lines at each loop boundary. Kill with Ctrl+C.

- [ ] **Step 3.5: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/chuloopa_drums_v4.ck
git commit -m "feat: replace hysteresis auto-switch with rolling-average weighted variation selection"
```

---

## Task 4: Update `oscListener()` — Silence Debounce

**Files:**
- Modify: `src/chuloopa_drums_v4.ck:1309-1317` (silence gate in oscListener)

- [ ] **Step 4.1: Replace the single-read silence gate with consecutive-count debounce**

Inside `oscListener()`, find and replace this block:
```chuck
                // Silence gate → mute/unmute drums (playDrumHit checks is_muted flag)
                if(effective_spice <= 0.0 && !is_muted && has_loop[0]) {
                    1 => is_muted;
                    <<< "Silence detected → drums muted" >>>;
                } else if(effective_spice > 0.0 && is_muted) {
                    0 => is_muted;
                    <<< "Energy resumed → drums unmuted" >>>;
                }
```

Replace with:
```chuck
                // Silence gate — requires N consecutive zero reads before muting;
                // unmute is queued to next loop boundary for clean re-entry
                if(effective_spice <= 0.0) {
                    silence_frame_count++;
                    if(silence_frame_count >= SILENCE_FRAMES_THRESHOLD && !is_muted && has_loop[0]) {
                        1 => is_muted;
                        0 => queued_unmute;  // cancel any pending unmute
                        <<< "Silence detected (" + silence_frame_count + " frames) → drums muted" >>>;
                    }
                } else {
                    0 => silence_frame_count;  // reset counter on any nonzero read
                    if(is_muted && !queued_unmute) {
                        1 => queued_unmute;
                        <<< "Energy resumed → drums will unmute at next loop boundary" >>>;
                    }
                }
```

- [ ] **Step 4.2: Smoke test**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
chuck chuloopa_drums_v4.ck
```

Expected: Starts cleanly. When spice_detector sends 0 for 4+ consecutive reads (~2 seconds of silence), console shows `Silence detected (4 frames) → drums muted`. When energy returns, console shows `Energy resumed → drums will unmute at next loop boundary`. Kill with Ctrl+C.

- [ ] **Step 4.3: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/chuloopa_drums_v4.ck
git commit -m "feat: add consecutive-frame silence debounce with loop-boundary unmute"
```

---

## Task 5: Cleanup — Remove Old Code

**Files:**
- Modify: `src/chuloopa_drums_v4.ck` — remove `spiceToVariationIndex()`, old state vars, old clearTrack resets

All edits in this task remove code that is no longer referenced.

- [ ] **Step 5.1: Remove `spiceToVariationIndex()` function**

Find and delete this entire function:
```chuck
fun int spiceToVariationIndex(float spice) {
    if(spice < 0.1) return 0;       // Original (silence/very low)
    else if(spice < 0.3) return 1;  // var1 (spice=0.2)
    else if(spice < 0.5) return 2;  // var2 (spice=0.4)
    else if(spice < 0.7) return 3;  // var3 (spice=0.6)
    else if(spice < 0.9) return 4;  // var4 (spice=0.8)
    else return 5;                  // var5 (spice=1.0)
}
```

- [ ] **Step 5.2: Remove `spice_stable_count` and `spice_stable_target` declarations**

Find and remove these two lines from the V4 state declarations block:
```chuck
int spice_stable_count;              // Consecutive windows at same target (hysteresis)
int spice_stable_target;             // Target variation index being confirmed
```

- [ ] **Step 5.3: Remove `spice_stable_count` and `spice_stable_target` init lines**

Find and remove these two lines from the V4 state init block (the block that starts `// Initialize v4 state`):
```chuck
0 => spice_stable_count;
0 => spice_stable_target;
```

- [ ] **Step 5.4: Update `clearTrack()` — remove old resets, add new ones**

Inside `clearTrack()`, find the V4 reset block:
```chuck
    // V4: Reset bank and variation state for track 0
    if(track == 0) {
        0 => bank_ready;
        0 => bank_progress;
        0 => current_variation_index;
        0 => is_muted;
        0 => spice_stable_count;
        0 => spice_stable_target;
        for(0 => int i; i < 6; i++) 0 => variation_available[i];
    }
```

Replace with:
```chuck
    // V4: Reset bank and variation state for track 0
    if(track == 0) {
        0 => bank_ready;
        0 => bank_progress;
        0 => current_variation_index;
        0 => is_muted;
        for(0 => int i; i < 6; i++) 0 => variation_available[i];
        // Weighted selection state
        0 => rolling_spice_idx;
        0 => rolling_spice_filled;
        0.0 => rolling_avg_spice;
        0 => last_played_var_idx;
        0 => last_played_count;
        // Silence debounce state
        0 => silence_frame_count;
        0 => queued_unmute;
    }
```

- [ ] **Step 5.5: Smoke test — verify clean compile and startup**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
chuck chuloopa_drums_v4.ck
```

Expected: Starts cleanly, no references to `spiceToVariationIndex`, `spice_stable_count`, or `spice_stable_target`. Kill with Ctrl+C.

- [ ] **Step 5.6: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/chuloopa_drums_v4.ck
git commit -m "chore: remove spiceToVariationIndex and hysteresis state, clean up clearTrack"
```

---

## Task 6: Integration Test

Full three-process system test verifying both features end-to-end.

**Setup:** Three terminal windows.

- [ ] **Step 6.1: Start Python watch mode (Terminal 1)**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python drum_variation_ai.py --watch
```

Expected: `OSC server listening on 127.0.0.1:5000`

- [ ] **Step 6.2: Start spice detector (Terminal 2)**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
chuck spice_detector.ck
```

Expected: Prints `SPICE: XX%` every 500ms.

- [ ] **Step 6.3: Start CHULOOPA v4 (Terminal 3)**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
chuck chuloopa_drums_v4.ck
```

Expected: `✓ CHULOOPA v4 ready!`

- [ ] **Step 6.4: Verify Feature 1 — weighted variation selection**

1. Press and hold MIDI Note 36 (C1), beatbox a pattern, release.
2. Wait for Python to generate the bank (watch Terminal 1 for `var1/5... var5/5` completion).
3. Wait 4+ loop cycles.
4. Observe Terminal 3 console: should see `>>> WEIGHTED PICK: spice=XX% → varN` lines at each loop boundary with varied N values (not the same index every loop).
5. Play at consistent medium energy (~50% spice) for 10+ loops. Observe that var2 and var3 dominate but others appear occasionally.

- [ ] **Step 6.5: Verify Feature 2 — silence gate**

1. With a loop running and bank ready, stop all sound for ~3 seconds.
2. Terminal 3 should print: `Silence detected (4 frames) → drums muted`
3. Drums should go silent (no MIDI notes reaching Ableton). Loop timing continues.
4. Resume playing. Terminal 3 should print: `Energy resumed → drums will unmute at next loop boundary`
5. Exactly at the next loop boundary, drums resume.

- [ ] **Step 6.6: Verify Feature 2 — clearing resets state**

1. Press MIDI Note 37 (C#1) to clear the track.
2. Record a new pattern.
3. Weighted selection should start fresh (no stale `last_played_var_idx` bias).

- [ ] **Step 6.7: Final commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/chuloopa_drums_v4.ck
git commit -m "feat: weighted variation selection and silence debounce complete"
```
