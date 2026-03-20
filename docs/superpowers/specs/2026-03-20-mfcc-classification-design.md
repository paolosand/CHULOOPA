# Design Spec: Beatbox Detection Improvement — MFCC-13 + Confidence Thresholding

**Date:** 2026-03-20
**Branch:** `feature/mfcc-classification` (off `main` — do NOT merge to `main` or `staging` without explicit approval)
**Starting point:** `chuloopa_drums_v4.ck`
**Approach:** Approach B — MFCC-13 feature replacement + confidence thresholding

---

## Problem

The current beatbox classifier in `chuloopa_drums_v4.ck` uses 5 raw spectral features — spectral flux, RMS energy, and three frequency band energy sums — with ChucK's `KNN2`. This produces:

1. Accurate results only for simple, spaced-out patterns (kick-snare with ~1s gaps)
2. Jumbled, incorrect classifications for complex patterns (kick hat snare hat kick kick snare hat)
3. Inconsistent results even when repeating the same sound

**Root causes identified:**
- Feature set is weak: raw band energy sums are crude approximations of spectral shape
- Spectral flux is an onset detection descriptor, not a classification descriptor — it measures change speed, not timbre
- MFCC subsumes all current features and represents them more precisely
- Low-confidence KNN predictions currently pass through as misclassifications rather than being gated

---

## Literature Support

- **Martanto 2025** (Beatbox Classification using ML): MFCC(n=22) outperforms spectral magnitude, spectral contrast, and spectral centroid across all KNN and SVM configurations tested. KNN-3 with MFCC achieves ~94.55% accuracy. Identified as the strongest feature representation for beatbox classification.
- **Delgado 2019** (AVP Dataset): Notes that vowel phonemes in complex beatboxing are confused with new onsets by spectral flux detectors. Recommends minimum onset separation to handle this.
- **Weber 2024** (Few-Shot Drum Transcription): Uses mel spectra with 96 bands — validates that mel-scale spectral features outperform raw band sums.

**Why drop current features entirely (not stack on top of MFCC):**
- Spectral flux belongs in onset detection, not classification
- Band energy sums are a coarser version of information MFCC already encodes more precisely
- Adding redundant features hurts KNN accuracy (noisy distance calculation)
- With only 30 training samples, keeping feature space compact is critical

---

## Current State (Important Context for Implementer)

### `drum_sample_recorder.ck`

The recorder **already** has an MFCC UAna chain:
```chuck
adc => FFT fft =^ MFCC mfcc => blackhole;
13 => mfcc.numCoeffs;
```

However, `extractOnsetFeatures()` currently computes and exports a **25-feature vector** — 12 spectral descriptors (flux, energy, 5 band sums, centroid, rolloff, flatness, low_ratio, high_ratio) followed by 13 MFCC coefficients. The CSV header is:
```
label,timestamp,flux,energy,band1,band2,band3,band4,band5,centroid,rolloff,flatness,low_ratio,high_ratio,mfcc0,...,mfcc12
```

The change to this file is a **reduction**: strip the 12 extra spectral descriptors, output only the 13 MFCC coefficients. The MFCC chain (`=^` operator, `numCoeffs=13`) stays exactly as-is.

### `chuloopa_drums_v4.ck`

The v4 file uses 5 features. Its audio setup wires FFT and RMS as **separate parallel chains**:
```chuck
adc => track_fft[i] => blackhole;
adc => track_rms[i] => blackhole;
```
There is no MFCC chain here yet. The feature extraction happens inside `classifyOnset()` using the FFT and RMS blobs.

---

## Design

### 1. Feature Replacement in `chuloopa_drums_v4.ck`

**Declare a new MFCC array** alongside the existing FFT array (RMS array is removed):
```chuck
FFT track_fft[NUM_TRACKS];
MFCC track_mfcc[NUM_TRACKS];
// RMS track_rms[NUM_TRACKS];  <-- remove this
```

**Wire the chain** using `=^` (UAna upchuck propagation operator, not `=>`):
```chuck
adc => track_fft[i] =^ track_mfcc[i] => blackhole;
// adc => track_rms[i] => blackhole;  <-- remove this

FRAME_SIZE => track_fft[i].size;
Windowing.hann(FRAME_SIZE) => track_fft[i].window;
13 => track_mfcc[i].numCoeffs;
```

**Upchuck strategy (avoids double-upchuck timing issue):**

The existing code has a comment: "FIXED: Accept pre-computed FFT blob to prevent double-upchuck timing issues." With the new chain, MFCC upchuck propagates upstream and computes the FFT in the same call. The onset detection loop calls MFCC upchuck first, then FFT upchuck returns the already-cached blob from the same frame:

```chuck
// In mainOnsetDetectionLoop(), per hop — replaces current double upchuck:
track_mfcc[active_track].upchuck() @=> UAnaBlob @ mfcc_blob;  // triggers FFT internally
track_fft[active_track].upchuck() @=> UAnaBlob @ fft_blob;    // returns cached FFT blob (same frame)

// Flux uses fft_blob (same as before — spectralFlux() signature unchanged)
spectralFlux(active_track, fft_blob) => float flux;
// ...
if(detectOnset(active_track, flux, threshold)) {
    classifyOnset(active_track, mfcc_blob) => int drum_class;
    // ...
}
```

**Updated `classifyOnset()` signature:**

Remove `flux`, `fft_blob`, and `rms_blob` parameters — the function now only needs the MFCC blob:

```chuck
// OLD: fun int classifyOnset(int track, float flux, UAnaBlob @ fft_blob, UAnaBlob @ rms_blob)
// NEW:
fun int classifyOnset(int track, UAnaBlob @ mfcc_blob) {
    float query[13];
    for(0 => int i; i < 13; i++) {
        mfcc_blob.fval(i) => query[i];
    }

    float probs[3];
    knn.predict(query, K_NEIGHBORS, probs);

    0 => int best_class;
    probs[0] => float best_prob;
    for(1 => int i; i < 3; i++) {
        if(probs[i] > best_prob) {
            i => best_class;
            probs[i] => best_prob;
        }
    }

    // Confidence gate
    if(best_prob < CONFIDENCE_THRESHOLD) return -1;

    return best_class;
}
```

**KNN training** — update feature array dimensions and weights:
```chuck
float training_features[num_samples][13];  // was [num_samples][5]

[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0] @=> float weights[];
knn.weigh(weights);

// Add after training completes:
<<< "Feature dimensions:", training_features[0].size() >>>;  // Should print 13
```

### 2. Training Data Format Update in `drum_sample_recorder.ck`

The MFCC chain (`=^`, `numCoeffs=13`) is already correct — do not touch it.

**Simplify `extractOnsetFeatures()`:** Remove all spectral descriptor computations (energy_from_fft, band1-5, centroid, rolloff, flatness, ratios). Return only the 13 MFCC coefficients:

```chuck
fun float[] extractOnsetFeatures() {
    float features[13];
    mfcc.upchuck() @=> UAnaBlob @ mfcc_blob;
    for(0 => int i; i < 13; i++) {
        mfcc_blob.fval(i) => features[i];
    }
    return features;
}
```

Note: `flux` parameter is removed from the signature since it's no longer stored in the feature vector (flux is still used internally for onset detection — only its role in classification is removed).

**Update CSV header and writer:**
```chuck
fout.write("label,timestamp,mfcc0,mfcc1,mfcc2,mfcc3,mfcc4,mfcc5,mfcc6,mfcc7,mfcc8,mfcc9,mfcc10,mfcc11,mfcc12\n");

// Write each sample (13 features only)
for(0 => int j; j < 13; j++) {
    fout.write("," + sample_features[i][j]);
}
```

### 3. Confidence Thresholding

Add at the top of `chuloopa_drums_v4.ck` with other config constants:
```chuck
0.55 => float CONFIDENCE_THRESHOLD;
```

`classifyOnset()` returns `-1` for low-confidence detections (see Section 1 above). The caller `saveDrumHit()` checks for `-1` and skips recording/playback:

```chuck
if(drum_class == -1) {
    // Low confidence — trigger white flicker visual, skip hit
    1 => low_confidence_flash;  // new float flag, decays like kick/snare/hat impulses
    // do NOT call saveDrumHit
} else {
    saveDrumHit(active_track, drum_class, velocity);
}
```

**Visual feedback:** Add a `low_confidence_flash` float (decays at same rate as drum impulses). In `visualizationLoop()`, briefly shift the shape toward white when this flag is active. This is a debug aid — see how often the gate fires and whether the threshold needs tuning.

**Threshold guidance:**
- `0.50` = accept if any majority (2/3 neighbors agree)
- `0.55` = default, small margin above bare majority
- `0.67` = strict (all 3 neighbors must agree)

Start at `0.55`. If too many valid hits drop, lower to `0.50`. If misclassifications persist in complex patterns, raise to `0.67`.

### 4. CSV Parser Update in `trainKNNFromCSV()` (`chuloopa_drums_v4.ck`)

**Legacy format detection** — add immediately after reading the header line:
```chuck
fin.readLine() => string header;

// Detect legacy 5-feature format
if(header.find("flux") != -1) {
    <<< "ERROR: Legacy training_samples.csv detected (old 5-feature format)." >>>;
    <<< "Delete training_samples.csv and re-record with the updated drum_sample_recorder.ck" >>>;
    fin.close();
    return 0;
}
```

**Updated feature parser loop** — replace the current skip-heavy 5-feature parser:
```chuck
// OLD parser: skipped band3, band4, then jumped to band5 at index 6
// NEW parser: reads label, skips timestamp, reads 13 MFCC values directly

tok.next() => string label;   // label column
tok.next();                   // skip timestamp
for(0 => int j; j < 13; j++) {
    Std.atof(tok.next()) => training_features[sample_idx][j];
}
```

### 5. What Stays the Same

- Onset detection: spectral flux + adaptive threshold — the `spectralFlux()` function and all its parameters are unchanged
- `KNN2` with K=3
- All MIDI routing to IAC Driver / Ableton
- OSC communication with Python (variation bank, spice system)
- V4 features: silence gate, weighted variation selection, audio-driven spice, bank progress
- `drum_sample_recorder.ck` training workflow (K/S/H interface, visual feedback, 10-sample minimum)
- Minimum training: existing 10-sample minimum stays (20+ recommended per console prompt)

---

## Files Changed

| File | Change |
|------|--------|
| `src/drum_sample_recorder.ck` | Simplify `extractOnsetFeatures()` to MFCC-13 only (remove 12 spectral descriptors); update CSV header and writer to 13 columns |
| `src/chuloopa_drums_v4.ck` | Add `MFCC track_mfcc[]` array with `=^` chain; remove `track_rms[]`; update `trainKNNFromCSV()` (legacy detection + new parser); update `classifyOnset()` signature and body; add `CONFIDENCE_THRESHOLD` constant; add `low_confidence_flash` visual |

**No other files are touched.**

---

## Testing Plan

1. Delete `training_samples.csv` (old 25-feature format is incompatible)
2. Re-record training samples using updated `drum_sample_recorder.ck` (same K/S/H workflow, 10+ per class)
3. Open `training_samples.csv` and verify the header reads `label,timestamp,mfcc0,...,mfcc12` (15 columns)
4. Run `chuloopa_drums_v4.ck` — verify console prints `Feature dimensions: 13`
5. Test simple pattern (kick-snare-kick-snare, ~1s spacing) — expect same or better accuracy
6. Test complex pattern (kick hat snare hat kick kick snare hat) — expect significantly fewer misclassifications
7. Test confidence gate: make ambiguous or soft sounds — expect white shape flicker (drop) rather than wrong classification
8. If too many valid hits drop → lower `CONFIDENCE_THRESHOLD` to `0.50`; if misclassifications persist → raise to `0.67`

---

## Branch Workflow

```bash
git checkout main
git checkout -b feature/mfcc-classification
# implement changes in drum_sample_recorder.ck and chuloopa_drums_v4.ck
# test against plan above
# do NOT merge to main or staging without explicit approval
```

---

## References

- Martanto, J. & Kartowisastro, I.H. (2025). Beatbox Classification to Distinguish User Experiences Using Machine Learning Approaches. *Journal of Computer Science*, 21(4), 961-970.
- Delgado, A. et al. (2019). A New Dataset for Amateur Vocal Percussion Analysis. *AM'19*.
- Weber, P. et al. (2024). Real-Time Automatic Drum Transcription Using Dynamic Few-Shot Learning. *Internet of Sounds 2024*.
