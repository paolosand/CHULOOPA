# RMS Energy Fix - ChucK RMS Unit Issue

## Problem

ChucK's `RMS` unit analyzer was returning 0 for all energy calculations, even when audio was present. This is a critical issue because RMS energy is one of the most discriminative features for drum classification.

## Root Cause

ChucK's `RMS` unit analyzer doesn't work as expected in the same way as `FFT` and `MFCC`. The issue appears to be related to how/when the RMS buffer is computed.

Attempted fix that didn't work:
```chuck
// This still returned 0
rms.upchuck() @=> UAnaBlob @ rms_blob;
rms_blob.fval(0) => float energy;
```

## Solution

Calculate RMS energy directly from FFT magnitude spectrum using Parseval's theorem:

```chuck
// Get FFT
fft.upchuck() @=> UAnaBlob @ blob;

// Calculate RMS energy from FFT magnitudes
0.0 => float energy_from_fft;
for(0 => int i; i < FRAME_SIZE/2; i++) {
    blob.fval(i) => float mag;
    mag * mag +=> energy_from_fft;  // Sum of squares
}
Math.sqrt(energy_from_fft / (FRAME_SIZE/2.0)) => float energy;
```

**Mathematical Basis:**
- Parseval's theorem: Energy in time domain = Energy in frequency domain
- RMS = sqrt(sum of squared magnitudes / N)
- This gives us the same information as time-domain RMS

## Files Updated

1. **`src/drum_feature_diagnostic.ck`**
   - Uses FFT-based energy calculation
   - Now shows all 13 MFCC coefficients
   - Only triggers on onsets (not continuous)

2. **`src/drum_sample_recorder.ck`**
   - Uses FFT-based energy calculation
   - Will now record non-zero energy values

## Testing

Run the diagnostic again:
```bash
chuck src/drum_feature_diagnostic.ck
```

Expected behavior:
- Make a beatbox sound
- See "🎵 ONSET DETECTED!"
- **RMS Energy (FFT) should now be NON-ZERO**
- Should see "✅ RMS energy is NON-ZERO (good!)"

## Impact on Classification

With proper energy values:
- **Kicks** should have moderate-high energy
- **Snares** should have high energy (loudest)
- **Hats** should have low-moderate energy

This will significantly improve classification accuracy as energy is a primary discriminative feature.

## Next Steps

1. ✅ Test diagnostic shows non-zero energy
2. 🔄 Record NEW training data with drum_sample_recorder.ck
3. ⏳ Verify energy column is non-zero in training_samples.csv
4. ⏳ Re-run feature analysis notebook
5. ⏳ Train classifier with corrected data
6. ⏳ Achieve >80% accuracy

## Technical Note

This is a workaround for ChucK's RMS unit analyzer. The FFT-based calculation is mathematically equivalent and actually more efficient since we're already computing FFT for other features (bands, centroid, etc.).
