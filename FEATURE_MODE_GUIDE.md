# Feature Mode Switching Guide

Quick guide to switch between 3 feature configurations for testing.

## Current Status
- **Mode 3** (All 25 features normalized) - CURRENTLY ACTIVE
- Kick works well, snare/hat less consistent

## The 3 Modes

### Mode 1: Original 5 Features (PROVEN BASELINE)
- **Features:** flux, energy, band1, band2, band5
- **Pros:** Fast, proven to work, balanced scales
- **Best for:** Reliability, fast performance
- **CSV indices:** 0, 1, 2, 3, 6 (skipping 4, 5)

### Mode 2: MFCC-Only (RESEARCH-BACKED)
- **Features:** mfcc0-mfcc12 (13 features)
- **Pros:** Best for timbre discrimination, internally consistent scales
- **Best for:** Distinguishing similar-sounding drums
- **CSV indices:** 14-26 (last 13 features)

### Mode 3: All 25 Features Normalized (COMPREHENSIVE)
- **Features:** All 25 with z-score normalization
- **Pros:** Maximum information, handles scale mismatch
- **Best for:** Experimental comparison
- **CSV indices:** 0-24 (all features)

---

## Quick Switch Instructions

Rather than implementing complex mode switching, here's how to quickly test each mode:

### To Test Mode 1 (5 Features - Original)

**File:** `src/chuloopa_drums_v2.ck`

**Line ~745** - Change array size:
```chuck
float training_features[num_samples][5];  // Was [25]
```

**Line ~786** - Change feature reading:
```chuck
// Read only 5 features: flux, energy, band1, band2, band5
Std.atof(tok.next()) => training_features[sample_idx][0];  // flux
Std.atof(tok.next()) => training_features[sample_idx][1];  // energy
Std.atof(tok.next()) => training_features[sample_idx][2];  // band1
Std.atof(tok.next()) => training_features[sample_idx][3];  // band2
tok.next(); // skip band3
tok.next(); // skip band4
Std.atof(tok.next()) => training_features[sample_idx][4];  // band5
// Skip remaining features
for(0 => int i; i < 18; i++) tok.next();
```

**Line ~798** - Comment out normalization:
```chuck
// normalizeFeatures(training_features, num_samples, 25);  // DISABLED for Mode 1
```

**Line ~804** - Change weights:
```chuck
[1.0, 1.0, 1.0, 1.0, 1.0] @=> float weights[];  // 5 weights
```

**Line ~887** - Change query array size in classifyOnset():
```chuck
float query[5];  // Was [25]
```

**Line ~912** - Comment out normalization in classifyOnset():
```chuck
// if(normalization_enabled) { ... }  // DISABLED for Mode 1
```

---

### To Test Mode 2 (MFCC-Only - 13 Features)

**Line ~745:**
```chuck
float training_features[num_samples][13];  // 13 MFCCs
```

**Line ~786:**
```chuck
// Skip first 14 features (flux through high_ratio)
for(0 => int i; i < 14; i++) tok.next();
// Read 13 MFCCs
for(0 => int i; i < 13; i++) {
    Std.atof(tok.next()) => training_features[sample_idx][i];
}
```

**Line ~798:** Keep normalization enabled (MFCCs benefit from it):
```chuck
normalizeFeatures(training_features, num_samples, 13);  // Normalize 13 features
```

**Line ~804:**
```chuck
[1.0, 1.0, 1.0, 1.0, 1.0,   // mfcc0-4
 1.0, 1.0, 1.0, 1.0, 1.0,   // mfcc5-9
 1.0, 1.0, 1.0] @=> float weights[];  // mfcc10-12
```

**Line ~887** in classifyOnset():
```chuck
float query[13];  // 13 MFCCs only
// Fill with MFCC values only
for(0 => int i; i < 13; i++) {
    mfcc_blob.fval(i) => query[i];
}
```

**Line ~912:** Keep normalization enabled

---

### To Test Mode 3 (All 25 Normalized - CURRENT)

This is what's currently running. No changes needed!

---

## Testing Protocol

For each mode:

1. **Modify code** as shown above
2. **Restart ChucK:** `chuck src/chuloopa_drums_v2.ck`
3. **Test same patterns** for fair comparison:
   - Fast kick-snare-hat sequence
   - Slow deliberate patterns
   - Repeated same sound (consistency test)
4. **Document results:**
   - Which mode classifies kick best?
   - Which handles snare/hat distinction?
   - Which is most consistent?

---

## Recommendation

**Start with Mode 1 (5 features)** - it was working before, so this confirms baseline.

Then try **Mode 2 (MFCC-only)** - research says MFCCs are best for timbre.

If neither works well, the issue might be:
- Training data quality (need more samples)
- Microphone quality (built-in mic limitations)
- Debounce timing (150ms might be too aggressive)

---

## Quick Comparison Results (Fill in after testing)

| Mode | Kick Accuracy | Snare Accuracy | Hat Accuracy | Consistency | Speed |
|------|---------------|----------------|--------------|-------------|-------|
| 1 (5 feat) | ? | ? | ? | ? | Fast |
| 2 (MFCC) | ? | ? | ? | ? | Fast |
| 3 (25 norm) | Good | Poor | Poor | Medium | Slow |

---

## Next Steps Based on Results

- **If Mode 1 wins:** Stick with it, research shows simple can be better
- **If Mode 2 wins:** MFCCs confirmed as best, consider increasing to 22 coefficients
- **If all struggle with snare/hat:** Problem is likely:
  1. Need more training samples (30-50 per class)
  2. Microphone quality limiting frequency resolution
  3. Snare/hat too acoustically similar in your beatbox style

