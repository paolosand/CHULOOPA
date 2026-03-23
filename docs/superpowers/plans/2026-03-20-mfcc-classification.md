# MFCC-13 + Confidence Thresholding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 5-feature raw spectral classifier in `chuloopa_drums_v4.ck` with MFCC-13 features and a confidence gate to eliminate misclassifications from complex beatbox patterns.

**Architecture:** The `drum_sample_recorder.ck` already has an MFCC chain (`=^` operator, `numCoeffs=13`) — its change is a *reduction* from 25 features to 13. `chuloopa_drums_v4.ck` needs a new MFCC array chained to the existing FFT array, an updated CSV parser, and a rewritten `classifyOnset()` function. A `-1` return from `classifyOnset()` silently drops the onset rather than misclassifying it.

**Tech Stack:** ChucK (ChuK audio programming language), ChucK UAna (`FFT`, `MFCC`, `KNN2`), `=^` upchuck-chain operator, `String.find()` for legacy CSV detection.

**Worktree:** `.worktrees/feature-mfcc-classification` on branch `feature/mfcc-classification`
**Spec:** `docs/superpowers/specs/2026-03-20-mfcc-classification-design.md`

---

## File Map

| File | Change Type | What Changes |
|------|-------------|--------------|
| `src/drum_sample_recorder.ck` | Modify | Simplify `extractOnsetFeatures()` to 13 MFCC coefficients only; remove `flux` param; update CSV header + writer to 13 columns |
| `src/chuloopa_drums_v4.ck` | Modify | Add `MFCC track_mfcc[]` array; fix audio chain to `=^`; add `CONFIDENCE_THRESHOLD`; update `trainKNNFromCSV()` (legacy guard + 13-col parser); rewrite `classifyOnset()`; handle `-1` in onset loop; add visual flash |

---

## Context: Critical ChucK Details for This Codebase

- **UAna chaining uses `=^` not `=>`:** `adc => FFT fft =^ MFCC mfcc => blackhole` — calling `mfcc.upchuck()` propagates upstream and computes `fft` in the same call. A subsequent `fft.upchuck()` returns the cached blob (same frame, no double-compute).
- **`String.find()` returns -1 if not found** — use `header.find("flux") != -1` to detect legacy CSV.
- **`drum_sample_recorder.ck` spectralFlux() calls `fft.upchuck()` independently** (line 264) for onset detection — this is separate from feature extraction and must NOT be changed.
- **No automated tests exist** — verification is done by running ChucK and observing console output + behavior.
- **All ChucK files must be run from `src/` directory:** `cd src && chuck filename.ck`

---

## Task 1: Simplify `drum_sample_recorder.ck` Feature Extraction to MFCC-13

**Files:**
- Modify: `src/drum_sample_recorder.ck:318-413` (`extractOnsetFeatures` function)
- Modify: `src/drum_sample_recorder.ck:419-438` (`recordSample` function)
- Modify: `src/drum_sample_recorder.ck:474-490` (CSV header + writer)

- [ ] **Step 1: Replace `extractOnsetFeatures()`**

Find the function at line 318. Replace the entire body (lines 318–413) with:

```chuck
// Extract MFCC features for drum classification (MFCC-13 only)
// Note: mfcc.upchuck() propagates upstream and also upchucks fft
fun float[] extractOnsetFeatures() {
    float features[13];
    mfcc.upchuck() @=> UAnaBlob @ mfcc_blob;
    for(0 => int i; i < 13; i++) {
        mfcc_blob.fval(i) => features[i];
    }
    return features;
}
```

- [ ] **Step 2: Update `recordSample()` signature and call site**

Find `fun void recordSample(string label, time onset_time, float flux)` at line 419.

Change the signature to remove `float flux`:
```chuck
fun void recordSample(string label, time onset_time) {
```

Change the internal call from `extractOnsetFeatures(flux)` to:
```chuck
    extractOnsetFeatures() @=> float features[];
```

Find the call site in `onsetDetectionLoop()` at line 523:
```chuck
// OLD:
recordSample(current_label, now, flux);
// NEW:
recordSample(current_label, now);
```

- [ ] **Step 3: Update CSV header and writer**

Find the CSV writer block around line 474. Replace the header line:
```chuck
// OLD (27 columns):
fout.write("label,timestamp,flux,energy,band1,band2,band3,band4,band5,centroid,rolloff,flatness,low_ratio,high_ratio,mfcc0,mfcc1,mfcc2,mfcc3,mfcc4,mfcc5,mfcc6,mfcc7,mfcc8,mfcc9,mfcc10,mfcc11,mfcc12\n");

// NEW (15 columns):
fout.write("label,timestamp,mfcc0,mfcc1,mfcc2,mfcc3,mfcc4,mfcc5,mfcc6,mfcc7,mfcc8,mfcc9,mfcc10,mfcc11,mfcc12\n");
```

Replace the feature writer loop:
```chuck
// OLD:
for(0 => int j; j < 25; j++) {
    fout.write("," + sample_features[i][j]);
}

// NEW:
for(0 => int j; j < 13; j++) {
    fout.write("," + sample_features[i][j]);
}
```

- [ ] **Step 4: Verify recorder compiles and runs**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification/src"
chuck drum_sample_recorder.ck
```

Expected: ChucK starts, ChuGL window opens, no errors in console. Press E to export (creates `training_samples.csv`), then Q to quit. Step 5 inspects the CSV written during this session.

- [ ] **Step 5: Verify CSV format**

After step 4, press K a few times to set label and beatbox a kick, then press E to export. Open `src/training_samples.csv` and verify:
- Header reads: `label,timestamp,mfcc0,mfcc1,...,mfcc12` (15 columns)
- Each data row has exactly 15 comma-separated values

- [ ] **Step 6: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification"
git add src/drum_sample_recorder.ck
git commit -m "feat: simplify recorder to MFCC-13 only, drop 12 spectral features"
```

---

## Task 2: Add MFCC Chain to `chuloopa_drums_v4.ck`

**Files:**
- Modify: `src/chuloopa_drums_v4.ck:36-82` (config section — add CONFIDENCE_THRESHOLD)
- Modify: `src/chuloopa_drums_v4.ck:366-367` (array declarations — add MFCC, remove RMS)
- Modify: `src/chuloopa_drums_v4.ck:384-388` (audio chain setup in for-loop)
- Modify: `src/chuloopa_drums_v4.ck:495` (impulse declarations — add low_confidence_flash)

- [ ] **Step 1: Add `CONFIDENCE_THRESHOLD` constant**

Find the config block near line 36 (near `DEFAULT_SPICE_LEVEL`). Add after line 38:
```chuck
0.55 => float CONFIDENCE_THRESHOLD; // Min KNN probability to accept classification
                                     // 0.50 = any majority, 0.55 = default, 0.67 = strict
```

- [ ] **Step 2: Replace RMS array with MFCC array**

Find lines 366-367:
```chuck
// OLD:
FFT track_fft[NUM_TRACKS];
RMS track_rms[NUM_TRACKS];

// NEW:
FFT track_fft[NUM_TRACKS];
MFCC track_mfcc[NUM_TRACKS];
```

- [ ] **Step 3: Update audio chain in setup loop**

Find the track configuration for-loop (lines 384-388). The loop body contains:
```chuck
// OLD:
adc => track_fft[i] => blackhole;
adc => track_rms[i] => blackhole;

FRAME_SIZE => track_fft[i].size;
Windowing.hann(FRAME_SIZE) => track_fft[i].window;

// NEW:
adc => track_fft[i] =^ track_mfcc[i] => blackhole;

FRAME_SIZE => track_fft[i].size;
Windowing.hann(FRAME_SIZE) => track_fft[i].window;
13 => track_mfcc[i].numCoeffs;
```

Note: `=^` is the UAna upchuck-chain operator. `adc => track_rms[i] => blackhole` is removed entirely.

- [ ] **Step 4: Add `low_confidence_flash` impulse variable**

Find line 495 where `kick_impulse`, `snare_impulse`, `hat_impulse` are declared:
```chuck
// OLD:
0.0 => float kick_impulse => float snare_impulse => float hat_impulse;

// NEW:
0.0 => float kick_impulse => float snare_impulse => float hat_impulse;
0.0 => float low_confidence_flash;  // Flashes white when onset is dropped by confidence gate
```

- [ ] **Step 5: Verify v4 compiles and starts**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification/src"
chuck chuloopa_drums_v4.ck
```

Expected: ChucK starts, ChuGL window opens. It will try to train KNN and likely print an error about mismatched CSV format (that's OK — we haven't updated the parser yet). No ChucK *syntax* errors. Press Ctrl+C to stop.

- [ ] **Step 6: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification"
git add src/chuloopa_drums_v4.ck
git commit -m "feat: add MFCC UAna chain to v4, add CONFIDENCE_THRESHOLD constant"
```

---

## Task 3: Update `trainKNNFromCSV()` in `chuloopa_drums_v4.ck`

**Files:**
- Modify: `src/chuloopa_drums_v4.ck:606-722` (`trainKNNFromCSV` function)

- [ ] **Step 1: Add legacy CSV detection**

Find the header-skip line (around line 624):
```chuck
// OLD:
fin.readLine() => string header;

// NEW:
fin.readLine() => string header;

// Detect legacy 5-feature format (pre-MFCC)
if(header.find("flux") != -1) {
    <<< "ERROR: Legacy training_samples.csv detected (old 5-feature/25-feature format)." >>>;
    <<< "Delete training_samples.csv and re-record with the updated drum_sample_recorder.ck" >>>;
    fin.close();
    return 0;
}
```

- [ ] **Step 2: Update feature array allocation**

Find the allocation near line 646:
```chuck
// OLD:
// Using 5 features: flux, energy, band1, band2, band5
float training_features[num_samples][5];

// NEW:
// Using 13 MFCC coefficients
float training_features[num_samples][13];
```

- [ ] **Step 3: Replace the skip-heavy CSV parser**

Find the data-reading section (around lines 680-700). Replace from the `tok.next()` label-read through the `for(0 => int i; i < 18; i++) tok.next();` skip block with:

```chuck
        // Parse CSV: label,timestamp,mfcc0,mfcc1,...,mfcc12
        tok.next() => string label;

        // Convert label to int (0=kick, 1=snare, 2=hat)
        0 => int label_val;
        if(label == "kick") {
            0 => label_val;
            label_counts[0]++;
        }
        else if(label == "snare") {
            1 => label_val;
            label_counts[1]++;
        }
        else if(label == "hat") {
            2 => label_val;
            label_counts[2]++;
        }

        label_val => training_labels[sample_idx];

        // Skip timestamp
        tok.next();

        // Read 13 MFCC features
        for(0 => int j; j < 13; j++) {
            Std.atof(tok.next()) => training_features[sample_idx][j];
        }

        sample_idx++;
```

- [ ] **Step 4: Update feature weights**

Find the weights array near line 713:
```chuck
// OLD:
[1.0, 1.0, 1.0, 1.0, 1.0] @=> float weights[];  // 5 weights

// NEW:
[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0] @=> float weights[];  // 13 weights
```

- [ ] **Step 5: Add feature dimension console print**

Add immediately after `knn.weigh(weights);`:
```chuck
<<< "Feature dimensions:", training_features[0].size() >>>;  // Should print 13
```

- [ ] **Step 6: Re-record training samples with updated recorder**

First delete the old CSV:
```bash
rm "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification/src/training_samples.csv"
```

Then record fresh samples:
```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification/src"
chuck drum_sample_recorder.ck
```

Record 10+ samples each of kick (K), snare (S), hat (H). Press E to export, Q to quit.

- [ ] **Step 7: Verify v4 trains with 13 features**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification/src"
chuck chuloopa_drums_v4.ck
```

Expected console output includes:
```
Feature dimensions: 13
✓ KNN training complete!
Using k = 3 neighbors
```

Press Ctrl+C to stop.

- [ ] **Step 8: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification"
git add src/chuloopa_drums_v4.ck
git commit -m "feat: update trainKNNFromCSV to 13-col MFCC parser with legacy detection"
```

---

## Task 4: Rewrite `classifyOnset()` with MFCC-13 + Confidence Gate

**Files:**
- Modify: `src/chuloopa_drums_v4.ck:728-779` (`classifyOnset` function)
- Modify: `src/chuloopa_drums_v4.ck:1554-1572` (onset detection loop — upchuck order + call site)

- [ ] **Step 1: Rewrite `classifyOnset()`**

Find the function at line 728. Replace the entire function with:

```chuck
// MFCC-13 classification with confidence gate
// Returns: drum class (0=kick, 1=snare, 2=hat), or -1 if confidence too low
fun int classifyOnset(int track, UAnaBlob @ mfcc_blob) {
    if(knn_trained) {
        // Build 13-feature MFCC query vector
        float query[13];
        for(0 => int i; i < 13; i++) {
            mfcc_blob.fval(i) => query[i];
        }

        // Get class probabilities from KNN
        float probs[3];
        knn.predict(query, K_NEIGHBORS, probs);

        // Find winning class and its confidence
        0 => int best_class;
        probs[0] => float best_prob;
        for(1 => int i; i < 3; i++) {
            if(probs[i] > best_prob) {
                i => best_class;
                probs[i] => best_prob;
            }
        }

        // Confidence gate: drop uncertain classifications
        if(best_prob < CONFIDENCE_THRESHOLD) return -1;

        return best_class;
    }
    else {
        // Fallback heuristic (no KNN trained) — uses raw MFCC energy proxy
        // mfcc_blob.fval(0) is the 0th coefficient (related to overall energy)
        // mfcc_blob.fval(1..2) carry low-freq info (kick vs. hat proxy)
        mfcc_blob.fval(0) => float c0;
        mfcc_blob.fval(1) => float c1;
        if(c0 > 50.0) return 0;       // High energy → kick
        else if(c1 < -10.0) return 2; // Negative low-freq coefficient → hat
        else return 1;                 // Default → snare
    }
}
```

- [ ] **Step 2: Update onset detection loop upchuck order**

Find the onset detection loop around line 1551. The existing block to replace looks like this (old code):

```chuck
        if(active_track >= 0) {
            track_fft[active_track].upchuck() @=> UAnaBlob @ fft_blob;
            track_rms[active_track].upchuck() @=> UAnaBlob @ rms_blob;

            spectralFlux(active_track, fft_blob) => float flux;
            updateFluxHistory(active_track, flux);
            getAdaptiveThreshold(active_track) => float threshold;

            if(detectOnset(active_track, flux, threshold)) {
                classifyOnset(active_track, flux, fft_blob, rms_blob) => int drum_class;

                Math.min(1.0, flux / 0.1) => float raw_velocity;
                0.7 + (raw_velocity * 0.2) => float velocity;

                saveDrumHit(active_track, drum_class, velocity);
            }
        }
```

Replace the entire block above with:

```chuck
        if(active_track >= 0) {
            // Upchuck MFCC first — this propagates upstream and computes FFT in the same call
            track_mfcc[active_track].upchuck() @=> UAnaBlob @ mfcc_blob;
            // Upchuck FFT second — returns the cached blob from the MFCC chain (same frame)
            track_fft[active_track].upchuck() @=> UAnaBlob @ fft_blob;

            // Calculate flux from cached FFT blob (onset detection unchanged)
            spectralFlux(active_track, fft_blob) => float flux;
            updateFluxHistory(active_track, flux);
            getAdaptiveThreshold(active_track) => float threshold;

            if(detectOnset(active_track, flux, threshold)) {
                // Classify using MFCC blob (same frame as FFT blob)
                classifyOnset(active_track, mfcc_blob) => int drum_class;

                // Calculate velocity from flux
                Math.min(1.0, flux / 0.1) => float raw_velocity;
                0.7 + (raw_velocity * 0.2) => float velocity;

                if(drum_class == -1) {
                    // Low confidence — flash white, do NOT record hit
                    1.0 => low_confidence_flash;
                } else {
                    saveDrumHit(active_track, drum_class, velocity);
                }
            }
        }
```

- [ ] **Step 3: Verify v4 compiles, trains, and classifies**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification/src"
chuck chuloopa_drums_v4.ck
```

Expected: KNN trains with 13 features, system is ready. Hold C1 to record, beatbox some kicks and snares. Verify console prints `KICK`, `SNARE`, or `HAT` (not a ChucK error). Press Ctrl+C to stop.

- [ ] **Step 4: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification"
git add src/chuloopa_drums_v4.ck
git commit -m "feat: rewrite classifyOnset() with MFCC-13 and confidence gate"
```

---

## Task 5: Add Low-Confidence Visual Flash to `visualizationLoop()`

**Files:**
- Modify: `src/chuloopa_drums_v4.ck:1670-1672` (impulse decay block)
- Modify: `src/chuloopa_drums_v4.ck:1731-1750` (deformation section)
- Modify: `src/chuloopa_drums_v4.ck` (color/bloom section of visualizationLoop)

- [ ] **Step 1: Add `low_confidence_flash` decay**

Find the impulse decay block (around line 1664) where `kick_impulse`, `snare_impulse`, `hat_impulse` decay. Add after the hat decay:

```chuck
    // Decay low_confidence_flash
    low_confidence_flash * 0.85 => low_confidence_flash;
    if(low_confidence_flash < 0.01) 0.0 => low_confidence_flash;
```

- [ ] **Step 2: Add white flash to shape color logic**

Find the section in `visualizationLoop()` where `target_color` is set (around line 1686). After all the `if/else` color blocks but before applying color to shapes, add:

```chuck
        // White flash on low-confidence drop (debug aid)
        if(low_confidence_flash > 0.1) {
            low_confidence_flash => float wf;
            @(0.5 + wf * 0.5, 0.5 + wf * 0.5, 0.5 + wf * 0.5) => target_color;
        }
```

- [ ] **Step 3: Verify visual flash works**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification/src"
chuck chuloopa_drums_v4.ck
```

Hold C1 and make some ambiguous sounds (soft vocalizations, quiet hums). Observe:
- Clear kick/snare/hat sounds → shape stays its normal color, console prints class
- Ambiguous sounds → shape briefly flashes white, console prints nothing

- [ ] **Step 4: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification"
git add src/chuloopa_drums_v4.ck
git commit -m "feat: add low-confidence visual flash for dropped onsets"
```

---

## Task 6: Integration Test

- [ ] **Step 1: Delete old training data and re-record fresh**

```bash
rm "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification/src/training_samples.csv"
```

Run recorder:
```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification/src"
chuck drum_sample_recorder.ck
```

Record 15+ samples each of kick, snare, hat with good consistent technique. Press E then Q.

- [ ] **Step 2: Verify CSV format**

Open `training_samples.csv` and verify:
- Header: `label,timestamp,mfcc0,...,mfcc12` (15 columns total)
- Each row: 15 comma-separated values
- Rows present for kick, snare, hat labels

- [ ] **Step 3: Test simple pattern**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification/src"
chuck chuloopa_drums_v4.ck
```

Verify console shows `Feature dimensions: 13`. Hold C1 and beatbox a simple kick-snare-kick-snare pattern with ~1 second between hits. Expected: correct classification on the majority of hits.

- [ ] **Step 4: Test complex pattern**

Still in v4 — hold C1 and beatbox `kick hat snare hat kick kick snare hat` at a moderate pace. Expected result (vs. old behaviour): fewer or no consecutive misclassifications where one sound is labelled as another. Ambiguous sounds flash white and produce no hit rather than a wrong one.

- [ ] **Step 5: Test confidence gate**

Make some soft, ambiguous sounds (mouth clicks, breathing, quiet voice). Expected: white flashes in ChuGL, no drum hits produced. This confirms the gate is working.

- [ ] **Step 6: Tune `CONFIDENCE_THRESHOLD` if needed**

If valid hits are being dropped (too many white flashes on real beats): lower `CONFIDENCE_THRESHOLD` from `0.55` to `0.50` at the top of `chuloopa_drums_v4.ck`.

If misclassifications still occur: raise to `0.67`.

- [ ] **Step 7: Final commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feature-mfcc-classification"
git add src/training_samples.csv
git commit -m "chore: add fresh MFCC-13 training samples for feature/mfcc-classification"
```

---

## Completion Checklist

- [ ] `drum_sample_recorder.ck` exports 15-column CSV (label, timestamp, mfcc0–mfcc12)
- [ ] `chuloopa_drums_v4.ck` trains KNN and prints `Feature dimensions: 13`
- [ ] Legacy CSV guard prints clear error when old file detected
- [ ] Complex beatbox patterns produce fewer misclassifications than before
- [ ] Ambiguous sounds flash white and produce no hit (confidence gate working)
- [ ] All changes committed to `feature/mfcc-classification` branch
- [ ] Branch has NOT been merged to `main` or `staging`
