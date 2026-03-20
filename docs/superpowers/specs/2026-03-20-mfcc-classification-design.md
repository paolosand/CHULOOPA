# Design Spec: Beatbox Detection Improvement — MFCC-13 + Confidence Thresholding

**Date:** 2026-03-20
**Branch:** `feature/mfcc-classification` (off `main` — do NOT merge to `main` or `staging` without explicit approval)
**Starting point:** `chuloopa_drums_v4.ck`
**Approach:** Approach B — MFCC-13 feature replacement + confidence thresholding

---

## Problem

The current beatbox classifier uses 5 raw spectral features: spectral flux, RMS energy, and three frequency band energy sums. This produces:

1. Accurate results only for simple, spaced-out patterns (kick-snare with ~1s gaps)
2. Jumbled, incorrect classifications for complex patterns (kick hat snare hat kick kick snare hat)
3. Inconsistent results even when repeating the same sound

**Root causes identified:**
- Feature set is weak: raw band energy sums are crude approximations of spectral shape
- Spectral flux is an onset detection descriptor, not a classification descriptor — it measures change speed, not timbre
- MFCC subsumes all current features and represents them more precisely
- Low-confidence KNN predictions currently go through as misclassifications rather than being gated

---

## Literature Support

- **Martanto 2025** (Beatbox Classification using ML): MFCC(n=22) outperforms spectral magnitude, spectral contrast, and spectral centroid across all KNN and SVM configurations tested. KNN-3 with MFCC achieves ~94.55% accuracy. The paper identifies MFCC as the strongest feature representation for beatbox classification.
- **Delgado 2019** (AVP Dataset): Notes that vowel phonemes in complex beatboxing are confused with new onsets by spectral flux detectors. Recommends minimum onset separation to handle this.
- **Weber 2024** (Few-Shot Drum Transcription): Uses mel spectra with 96 bands for feature extraction — further validation that mel-scale spectral features outperform raw band sums.

**Why drop current features entirely (not stack on top of MFCC):**
- Spectral flux belongs in onset detection, not classification
- Band energy sums are a coarser version of information MFCC already encodes
- Adding redundant features hurts KNN accuracy (noisy distance calculation)
- With only 30 training samples, keeping feature space compact is critical

---

## Design

### 1. Feature Replacement (MFCC-13)

Replace the 5-feature vector (`flux, energy, band1, band2, band5`) with 13 MFCC coefficients using ChucK's built-in `MFCC` UAna.

**Audio chain per track:**
```chuck
adc => track_fft[i] => track_mfcc[i] => blackhole;
```

Calling `track_mfcc[i].upchuck()` propagates upstream and upchucks the FFT too — both onset detection (spectral flux from FFT blob) and classification (MFCC blob) come from the same audio frame. The `track_rms` chains are removed.

**KNN query vector:**
```chuck
float query[13];
for(0 => int i; i < 13; i++) {
    mfcc_blob.fval(i) => query[i];
}
knn.predict(query, K_NEIGHBORS, probs);
```

**KNN training:**
```chuck
float training_features[num_samples][13];
// equal weights initially
[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0] @=> float weights[];
knn.weigh(weights);
```

### 2. Training Data Format Update (`drum_sample_recorder.ck`)

`drum_sample_recorder.ck` gets the same MFCC chain. CSV format changes from:
```
timestamp,label,flux,energy,band1,band2,band5
```
to:
```
timestamp,label,mfcc0,mfcc1,mfcc2,mfcc3,mfcc4,mfcc5,mfcc6,mfcc7,mfcc8,mfcc9,mfcc10,mfcc11,mfcc12
```

`trainKNNFromCSV()` updates the CSV parser to read 13 MFCC columns into `float training_features[n][13]`.

**Legacy detection:** If the file header contains `flux` (old format), print a clear error and halt with instructions to re-record. The old `training_samples.csv` is incompatible and must be deleted before re-training.

### 3. Confidence Thresholding

After `knn.predict()` returns probabilities, gate on the winning class confidence:

```chuck
0.55 => float CONFIDENCE_THRESHOLD;  // configurable constant at top of file

if(best_prob < CONFIDENCE_THRESHOLD) {
    // onset heard but classification uncertain — drop silently
    return -1;
}
```

`classifyOnset()` returns `-1` for low-confidence detections. The caller (`saveDrumHit()`) checks for `-1` and skips recording/playback entirely.

**Visual feedback (debug aid):** A brief white flicker on the shape when a hit is dropped (low confidence). This helps during testing to see how often the gate fires and whether the threshold needs tuning. Can be disabled once tuned.

**Threshold guidance:**
- `0.50` = accept if any majority exists (2/3 neighbors agree)
- `0.55` = default, small margin above bare majority
- `0.67` = strict (all 3 neighbors must agree)

Start at `0.55`. If too many valid hits are dropped, lower to `0.50`. If misclassifications still occur in complex patterns, raise to `0.67`.

### 4. What Stays the Same

- Onset detection: spectral flux + adaptive threshold (`ONSET_THRESHOLD_MULTIPLIER`, `MIN_ONSET_STRENGTH`, `MIN_ONSET_INTERVAL`) — untouched
- KNN2 with K=3
- All MIDI routing to IAC Driver / Ableton
- OSC communication with Python (variation bank, spice system)
- V4 features: silence gate, weighted variation selection, audio-driven spice, bank progress
- `drum_sample_recorder.ck` training workflow (K/S/H interface, 10-sample minimum)

---

## Files Changed

| File | Change |
|------|--------|
| `src/drum_sample_recorder.ck` | Replace FFT+band feature extraction with MFCC-13; update CSV output format |
| `src/chuloopa_drums_v4.ck` | Replace FFT+RMS+band chains with MFCC chain; update KNN feature vector (5→13); add confidence threshold gate; add legacy CSV detection |

**No other files are touched.**

---

## Testing Plan

1. Delete `training_samples.csv` and `drum_classifier.pkl`
2. Re-record training samples using updated `drum_sample_recorder.ck` (same 10 per class)
3. Run `chuloopa_drums_v4.ck` — verify KNN trains successfully with 13 features
4. Test simple pattern (kick-snare-kick-snare, ~1s spacing) — expect same or better accuracy
5. Test complex pattern (kick hat snare hat kick kick snare hat) — expect significantly fewer misclassifications
6. Test confidence gate: make ambiguous sounds — expect white flicker (drop) rather than wrong classification
7. Tune `CONFIDENCE_THRESHOLD` if needed (try 0.50 and 0.67 as bounds)

---

## Branch Workflow

```bash
git checkout main
git checkout -b feature/mfcc-classification
# implement changes
# test
# do NOT merge to main or staging without explicit approval
```

---

## References

- Martanto, J. & Kartowisastro, I.H. (2025). Beatbox Classification to Distinguish User Experiences Using Machine Learning Approaches. *Journal of Computer Science*, 21(4), 961-970.
- Delgado, A. et al. (2019). A New Dataset for Amateur Vocal Percussion Analysis. *AM'19*.
- Weber, P. et al. (2024). Real-Time Automatic Drum Transcription Using Dynamic Few-Shot Learning. *Internet of Sounds 2024*.
