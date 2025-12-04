# Onset Detection Testing Log

## Nov 25, 2025 - Initial Test

### Parameters:

- ONSET_THRESHOLD_MULTIPLIER: 1.5
- MIN_ONSET_STRENGTH: 0.01
- MIN_ONSET_INTERVAL: 100ms
- FRAME_SIZE: 512
- HOP_SIZE: 128

### Test 1: Simple Pattern

**Pattern:** "BOOM tss tss BOOM tss tss"
**Expected onsets:** 6
**Detected onsets:** 6
**Recall:** 6/6
**Notes:** Great

### Test 2: Kick Only

**Pattern:** "BOOM BOOM BOOM BOOM"
**Expected onsets:** 4
**Detected onsets:** 4
**Recall:** 4/4
**Notes:** Perfect

### Test 3: Hi-hats Only

**Pattern:** "tss tss tss tss tss tss tss tss"
**Expected onsets:** 8
**Detected onsets:** 8
**Recall:** 8/8
**Notes:** Great

### Test 4: Fast Pattern

**Pattern:** "BOOM-ts-ts-BOOM-ts-ts" (faster tempo)
**Expected onsets:** 6
**Detected onsets:** 6
**Recall:** 6/6
**Notes:**

### Observations:

- Latency feel (click sync with voice): Latency felt fast and instant. However need to test with actual playback from outputed txt file (recall that we're transcribing 3 different loop tracks)
- False positives during silence: None! All loud short sounds are detected as onsets
- Missed onsets (which type - kick/snare/hat): None
- Parameter adjustments needed: None

### Next Steps:

- [x] Adjust parameters if needed
- [x] Test with different mic distances
- [x] Test in different rooms (reverb) - Not needed as input will be coming from a microphone
- [x] Ready for data collection phase

---

## Template for Additional Tests

### Test X: [Description]

**Date:**
**Pattern:**
**Expected onsets:**
**Detected onsets:**
**Recall:**
**Precision:**
**Notes:**
