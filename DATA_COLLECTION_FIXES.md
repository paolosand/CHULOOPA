# Data Collection Fixes - Dec 4, 2025

## Issues Found in training_samples.csv

### 🚨 Critical Issues:
1. **All RMS energy values were ZERO** (66/66 samples)
   - Root cause: `rms.upchuck()` not storing result in blob reference
   - Impact: Energy is a critical discriminative feature for drums

2. **Band energy distribution was backwards**
   - Kicks had LOW energy in band1/band2 (should be HIGH)
   - Hats had HIGH energy in band1/band2 (should be in band5)
   - Suggests labeling errors or microphone issues

3. **Spectral rolloff was disordered**
   - Expected: kick < snare < hat
   - Actual: snare < kick < hat (snare too low)

4. **Rapid onset triggers**
   - Some samples only 125-174ms apart
   - Indicates double-triggering on single beatbox sounds

## Fixes Implemented

### Fix #1: RMS Energy Calculation ✅
**File:** `src/drum_sample_recorder.ck` (line 173-174)

**Before:**
```chuck
rms.upchuck();
rms.fval(0) => float energy;
```

**After:**
```chuck
rms.upchuck() @=> UAnaBlob @ rms_blob;
rms_blob.fval(0) => float energy;
```

**Why:** ChucK's `upchuck()` returns a UAnaBlob that must be captured to access feature values.

### Fix #2: Prevent Double-Triggering ✅
**Files:**
- `src/drum_sample_recorder.ck` (line 26)
- `src/drum_onset_detector.ck` (line 20)

**Changed:**
```chuck
100::ms => dur MIN_ONSET_INTERVAL;  // OLD
150::ms => dur MIN_ONSET_INTERVAL;  // NEW (50% increase)
```

**Why:** Human beatboxing typically needs 150-200ms between sounds. 100ms was too sensitive.

### Fix #3: Real-time Feature Feedback ✅
**File:** `src/drum_sample_recorder.ck` (line 291-292)

**Added visual output after each recording:**
```chuck
<<< "  Features: flux=" + features[0] + " energy=" + features[1] +
    " band1=" + features[2] + " band5=" + features[6] + " centroid=" + features[7] >>>;
```

**Why:** Allows immediate verification that features are being extracted correctly.

### Fix #4: Diagnostic Tool ✅
**New file:** `src/drum_feature_diagnostic.ck`

**Features:**
- Real-time feature analysis (no recording needed)
- Shows RMS energy, all band energies, centroid, flatness, MFCC
- Provides hints: "Looks like a KICK" based on band distribution
- Only prints when audio detected (energy > 0.001)

**Usage:**
```bash
chuck src/drum_feature_diagnostic.ck
# Make beatbox sounds and watch the readouts
```

## Testing Workflow

### Step 1: Test Feature Extraction
```bash
chuck src/drum_feature_diagnostic.ck
```

**What to verify:**
1. Make "BOOM" sound → Should see:
   - High band1 (sub-bass) and band2 (low)
   - RMS energy > 0
   - Hint: "Looks like a KICK"

2. Make "PSH" sound → Should see:
   - High band3 (low-mid) and band4 (mid-high)
   - RMS energy > 0
   - Hint: "Looks like a SNARE"

3. Make "tss" sound → Should see:
   - High band5 (high)
   - RMS energy > 0
   - Hint: "Looks like a HAT"

### Step 2: Record New Training Data
```bash
chuck src/drum_sample_recorder.ck
```

**Best practices:**
1. **Test your sounds first** with the diagnostic tool
2. **Choose consistent beatbox sounds:**
   - Pick ONE kick sound and stick to it
   - Pick ONE snare sound and stick to it
   - Pick ONE hat sound and stick to it

3. **Recording tips:**
   - Wait 0.5-1 second between each beatbox
   - Maintain consistent volume/distance from mic
   - Record in quiet environment
   - Watch the feature readouts - energy should NEVER be 0

4. **Target samples:**
   - 20+ kicks (press K, then beatbox 20 times)
   - 20+ snares (press S, then beatbox 20 times)
   - 20+ hats (press H, then beatbox 20 times)

5. **Verify as you go:**
   - Kicks should show: high band1/band2, moderate energy
   - Snares should show: high band3/band4, high energy
   - Hats should show: high band5, moderate energy
   - If energy = 0, STOP and debug

### Step 3: Analyze New Data
```bash
jupyter notebook drum_feature_analysis.ipynb
```

**Expected results with fixed data:**
- Energy column should have non-zero values
- Band energies should align with drum type:
  - Kicks: band1 > band2 > others
  - Snares: band3/band4 highest
  - Hats: band5 highest
- Spectral rolloff: kick < snare < hat
- Classification accuracy: >80% achievable

## Verification Checklist

Before accepting new training data:
- [ ] All energy values > 0
- [ ] Kicks have highest energy in band1/band2
- [ ] Hats have highest energy in band5
- [ ] Snares have highest energy in band3/band4
- [ ] Spectral rolloff ordered: kick < snare < hat
- [ ] Minimum 0.15s gap between samples (no double-triggers)
- [ ] At least 20 samples per class

## Next Steps

1. **Collect clean data** using the fixed recorder
2. **Run feature analysis** notebook to verify quality
3. **Train classifier** with new data
4. **Achieve >80% accuracy** (should be possible with good data)
5. **Test real-time classification** in `drum_classifier_realtime.ck`

## Files Modified
- ✅ `src/drum_sample_recorder.ck` - Fixed RMS, added feedback, increased debounce
- ✅ `src/drum_onset_detector.ck` - Increased debounce interval
- ✅ `src/drum_feature_diagnostic.ck` - NEW diagnostic tool

## Files to Update Next
- `src/drum_classifier_realtime.ck` - Apply same RMS fix if needed
- `src/feature_extraction.ck` - Verify RMS extraction
- `train_classifier.py` - Ready to use with new CSV data
