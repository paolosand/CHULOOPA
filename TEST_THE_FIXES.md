# Test the Critical Fixes

**Quick verification guide for the playback session ID fixes**

---

## Setup

### Terminal 1: Start Python
```bash
cd src
python drum_variation_ai.py --watch
```

### Terminal 2: Start ChucK
```bash
cd src
chuck chuloopa_drums_v2.ck
```

**Watch Console Output:** You should now see ID increment messages!

---

## Test 1: Bug #1 - Rapid Clear/Record (Your Primary Issue)

**What you reported:**
> "I hear kick snare kick snare but when it plays back they sound overlayed and messy"

**Test Steps:**
1. **Record loop 1:** Press and hold C1, beatbox "kick snare kick snare" (~2 seconds)
2. Release C1
3. **Immediately clear:** Press C#1
4. **Immediately record loop 2:** Press and hold C1, beatbox "kick kick snare snare" (~2 seconds)
5. Release C1
6. **Listen carefully**

**What to Look For in Console:**
```
>>> TRACK 0 RECORDING STARTED <<<
  Stopping existing playback before new recording
  Playback ID incremented to 3 (clean recording session)  <-- THIS IS NEW!
Recording... onset detection active
```

**Expected Result:**
- ✅ **Clean playback** of loop 2 only ("kick kick snare snare")
- ✅ No overlaid sounds from loop 1
- ✅ Timing is accurate

**Before Fix:**
- ❌ Messy overlaid playback (both loops playing simultaneously)

---

## Test 2: Bug #2 - Variation Persists After Clear (Your Primary Issue)

**What you reported:**
> "The AI variation sometimes comes back after not playing for a while and has to be 'recleared'"

**Test Steps:**
1. **Record loop:** Press and hold C1, beatbox any pattern (~2 seconds)
2. Release C1
3. **Wait for variation:** Python generates, sphere turns green
4. **Load variation:** Press D1 (Note 38)
5. **Listen to variation:** Let it loop 2-3 times
6. **Clear:** Press C#1
7. **Wait in silence:** 10 seconds

**What to Look For in Console:**
```
>>> CLEARING TRACK 0 <<<
  Playback ID incremented to 2 (invalidates old hits)  <-- THIS IS NEW!
```

**Expected Result:**
- ✅ **Variation stops immediately**
- ✅ **Stays silent** (no comeback!)
- ✅ No need to clear again

**Before Fix:**
- ❌ Variation stops, then comes back after a few seconds
- ❌ Need to clear multiple times

---

## Test 3: Stress Test - Multiple Rapid Clears

**Test Steps:**
1. Record loop → Clear → Record loop → Clear → Record loop → Clear
2. Do this 5 times RAPIDLY
3. Listen to final playback

**What to Look For in Console:**
```
Playback ID incremented to 1 (clean recording session)
Playback ID incremented to 2 (invalidates old hits)
Playback ID incremented to 3 (clean recording session)
Playback ID incremented to 4 (invalidates old hits)
Playback ID incremented to 5 (clean recording session)
...
```

**Expected Result:**
- ✅ Only the LAST recorded loop plays
- ✅ No artifacts from previous loops
- ✅ Clean, clear playback

---

## Test 4: Variation Toggle After Clear (Edge Case)

**Test Steps:**
1. Record loop, wait for variation
2. Press D1 to load variation
3. **Immediately** press C#1 to clear
4. Try to press D1 again (should fail gracefully)

**Expected Result:**
- ✅ Clear succeeds
- ✅ D1 shows error: "Cannot toggle variation mode: no loop recorded"
- ✅ No crashes or weird sounds

---

## Visual Verification

**Sphere Color States (Should Still Work):**
- Gray: No loop recorded
- Red: Playing original loop
- Blue-green (blinking): Variation ready
- Blue→Yellow→Red gradient: Playing variation (color = spice level)

**After Clear:**
- Sphere should turn gray immediately
- No blinking or pulsing

---

## Console Output Comparison

### BEFORE FIX (Bug #1 - Overlaid Playback)
```
>>> TRACK 0 RECORDING STARTED <<<
Recording... onset detection active
Track 0 - Drum playback started (ID: 0)

>>> CLEARING TRACK 0 <<<

>>> TRACK 0 RECORDING STARTED <<<
Recording... onset detection active
Track 0 - Drum playback started (ID: 0)   <-- SAME ID = PROBLEM!
```

### AFTER FIX (Clean Playback)
```
>>> TRACK 0 RECORDING STARTED <<<
  Playback ID incremented to 1 (clean recording session)
Recording... onset detection active
Track 0 - Drum playback started (ID: 1)

>>> CLEARING TRACK 0 <<<
  Playback ID incremented to 2 (invalidates old hits)

>>> TRACK 0 RECORDING STARTED <<<
  Stopping existing playback before new recording
  Playback ID incremented to 3 (clean recording session)
Recording... onset detection active
Track 0 - Drum playback started (ID: 3)   <-- NEW ID = FIXED!
```

---

## If Something Goes Wrong

### Variation Still Comes Back?
- Check console for "Playback ID incremented" messages
- If missing, code didn't apply correctly
- Try: `git diff src/chuloopa_drums_v2.ck` to verify changes

### ChucK Won't Start?
- Look for syntax errors in console
- Verify the two added blocks are correct
- Check line numbers match (should be around lines 1546 and 1671)

### Python Connection Lost?
- Restart Python watch mode
- Verify OSC ports: Python receives on 5000, ChucK receives on 5001

---

## Success Criteria

**You can confirm the fixes are working if:**

1. ✅ Rapid clear/record cycles produce CLEAN playback (no overlay)
2. ✅ Variation stays cleared after pressing C#1 (no comeback)
3. ✅ Console shows "Playback ID incremented" messages
4. ✅ Multiple clears show ID incrementing: 1→2→3→4...
5. ✅ No crashes or unexpected behavior

**If all tests pass, these bugs are FIXED!**

---

## Next Steps

After confirming fixes work:

1. **Commit the changes:**
   ```bash
   git add src/chuloopa_drums_v2.ck
   git commit -m "fix: increment playback ID in clearTrack and startRecording"
   ```

2. **Optional: Merge to staging:**
   ```bash
   git checkout staging
   git merge event-management-chuck
   ```

3. **Continue with other enhancements** (see IMPLEMENTATION_PLAN.md)

---

## Report Issues

If tests fail, please note:
- Which test failed?
- What was the console output?
- Can you reproduce it consistently?

**Contact:** Report in this conversation or open issue in repo
