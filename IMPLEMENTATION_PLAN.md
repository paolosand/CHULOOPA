# Event Management Implementation Plan

**Branch:** event-management-chuck
**Goal:** Fix inconsistent queuing behavior and improve event management reliability

---

## Summary of Issues

### Critical Issues (Must Fix)

1. **Inconsistent Queuing:** `clearTrack()` executes immediately while `toggleVariationMode()` queues for loop boundary
2. **Missing Return Value Checks:** File loading failures are silent
3. **Race Condition:** Variation ready signal can arrive during new recording

### Enhancement Opportunities

4. **Multi-Variation Support:** Always loads var1, can't select between multiple variations
5. **Dead Code:** `queued_clear_track[]` array exists but is never used

---

## Phase 1: Fix Immediate Execution Issue (Critical)

### 1.1 Make Clear Track Queued

**Current Behavior:**
```chuck
// MIDI handler (line 2117)
else if(data1 == NOTE_CLEAR_TRACK) {
    clearTrack(0);  // ❌ Immediate execution
    sendTrackCleared();
    0 => variations_ready;
    0 => variation_mode_active;
    0 => generation_requested;
}
```

**Proposed Fix:**
```chuck
// Add new function
fun void queueClearTrack(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;

    <<< "" >>>;
    <<< ">>> QUEUED: Track", track, "will clear at next loop boundary <<<" >>>;
    <<< "" >>>;

    1 => queued_clear_track[track];
}

// Update MIDI handler
else if(data1 == NOTE_CLEAR_TRACK) {
    if(has_loop[0]) {
        queueClearTrack(0);  // ✅ Queued if loop exists
    } else {
        clearTrack(0);  // ✅ Immediate if no loop (no boundary to wait for)
        sendTrackCleared();
        0 => variations_ready;
        0 => variation_mode_active;
        0 => generation_requested;
    }
}

// Update clearTrack to send OSC after clearing
fun void clearTrack(int track) {
    // ... existing clear logic ...

    // Send OSC at end of function
    sendTrackCleared();
    0 => variations_ready;
    0 => variation_mode_active;
    0 => generation_requested;
}
```

**Files to Modify:**
- `src/chuloopa_drums_v2.ck` (lines 1650-1680, 2115-2122)

**Testing:**
1. Record 4-second loop
2. Press C#1 at t=1s
3. Verify: Loop continues until t=4s, then clears
4. Verify: Console shows ">>> QUEUED: Track 0 will clear at next loop boundary <<<"

---

## Phase 2: Add Error Handling (Critical)

### 2.1 Check loadVariationFile Return Values

**Current Code:**
```chuck
fun void executeToggleVariation() {
    if(variation_mode_active == 0) {
        1 => variation_mode_active;
        loadVariationFile(0, 1);  // ❌ No return value check
    }
}
```

**Proposed Fix:**
```chuck
fun void executeToggleVariation() {
    if(variation_mode_active == 0) {
        <<< "" >>>;
        <<< "╔═══════════════════════════════════════╗" >>>;
        <<< "║  LOADING VARIATION                   ║" >>>;
        <<< "╚═══════════════════════════════════════╝" >>>;

        if(loadVariationFile(0, 1)) {
            1 => variation_mode_active;
            <<< "✓ Variation loaded successfully" >>>;
        } else {
            0 => variation_mode_active;  // Stay in original mode
            0 => variations_ready;       // Mark as not ready
            <<< "" >>>;
            <<< "✗ ERROR: Failed to load variation file!" >>>;
            <<< "  File may be missing or corrupted" >>>;
            <<< "  Staying in original mode" >>>;
        }
        <<< "" >>>;
    }
    else {
        // Switch back to original
        <<< "" >>>;
        <<< "╔═══════════════════════════════════════╗" >>>;
        <<< "║  LOADING ORIGINAL                    ║" >>>;
        <<< "╚═══════════════════════════════════════╝" >>>;

        if(loadDrumDataFromFile(0)) {
            0 => variation_mode_active;
            <<< "✓ Original loaded successfully" >>>;
        } else {
            <<< "✗ ERROR: Failed to load original file!" >>>;
            // This is critical - can't play anything
            clearTrack(0);
        }
        <<< "" >>>;
    }
}
```

**Files to Modify:**
- `src/chuloopa_drums_v2.ck` (lines 1463-1493)

**Testing:**
1. Delete variation file manually
2. Press D1 to toggle variation
3. Verify: Error message appears
4. Verify: `variation_mode_active` stays 0
5. Verify: Original continues playing

---

## Phase 3: Fix Race Condition (Critical)

### 3.1 Invalidate Variations on New Recording

**Problem Flow:**
```
t=0s:  Record loop 1
t=2s:  Release recording → Python generating variation for loop 1
t=3s:  Record loop 2
t=4s:  Release recording → Python generating variation for loop 2
t=5s:  OSC: variations_ready for loop 1 (LATE!)
       variations_ready = 1  ❌ Wrong! This is for OLD loop
t=6s:  User toggles → Plays variation for loop 1 on loop 2 data
```

**Proposed Fix:**
```chuck
// In recording release handler (after exportDrumData)
fun void onRecordingReleased(int track) {
    // Export drum data
    exportDrumData(track);

    // CRITICAL: Invalidate old variations
    0 => variations_ready;       // Old variations no longer valid
    0 => variation_mode_active;  // Force back to original mode
    0 => generation_requested;   // Clear request flag

    <<< "" >>>;
    <<< ">>> Variation state reset (new recording) <<<" >>>;
    <<< ">>> Waiting for Python to generate new variation... <<<" >>>;
    <<< "" >>>;
}

// In MIDI note-off handler for Note 36 (recording release)
if(is_recording[0]) {
    0 => is_recording[0];
    // ... existing duration calculation ...
    onRecordingReleased(0);  // ✅ Centralized handler
}
```

**Additional Safety:**
```chuck
// In oscListener, add recording check
if(msg.address == "/chuloopa/variations_ready") {
    if(is_recording[0]) {
        <<< ">>> Ignoring variations_ready (recording in progress) <<<" >>>;
        // Don't set variations_ready flag
    } else {
        msg.getInt(0) => int num_variations;
        1 => variations_ready;
        0 => generation_failed;
        <<< "✓ Python: Variation ready!" >>>;
    }
}
```

**Files to Modify:**
- `src/chuloopa_drums_v2.ck` (lines 1400-1414, 2080-2110)

**Testing:**
1. Record loop 1 (2 seconds)
2. Immediately record loop 2 (3 seconds) BEFORE variation ready
3. Wait for variation ready signal
4. Verify: `variations_ready` is set for loop 2, not loop 1
5. Verify: Toggling variation plays variation of loop 2

---

## Phase 4: Multi-Variation Support (Enhancement)

### 4.1 Add Variation Selection

**New State Variables:**
```chuck
// Add after line 513
int current_variation_num;       // Which variation is currently loaded (1-5)
int num_variations_available;    // How many variations Python generated
1 => current_variation_num;      // Default to var1
1 => num_variations_available;   // Default to 1
```

**New MIDI Mapping:**
```chuck
// Add constant (line ~130)
40 => int NOTE_NEXT_VARIATION;   // D#1 (was NOTE_REGENERATE, shift to E1)
41 => int NOTE_REGENERATE;       // E1 (shifted up)

// Add MIDI handler
else if(data1 == NOTE_NEXT_VARIATION) {
    if(!has_loop[0]) {
        <<< "Cannot cycle variations: no loop recorded" >>>;
    }
    else if(!variations_ready) {
        <<< "Cannot cycle variations: no variations generated" >>>;
    }
    else {
        cycleToNextVariation();
    }
}
```

**New Function:**
```chuck
fun void cycleToNextVariation() {
    // Increment variation number (wrap around)
    current_variation_num % num_variations_available + 1 => current_variation_num;

    <<< "" >>>;
    <<< ">>> Loading variation", current_variation_num, "<<<" >>>;

    if(loadVariationFile(0, current_variation_num)) {
        1 => variation_mode_active;  // Ensure variation mode active
        <<< "✓ Variation", current_variation_num, "loaded" >>>;
    } else {
        <<< "✗ Variation", current_variation_num, "not found" >>>;
        // Try var1 as fallback
        if(loadVariationFile(0, 1)) {
            1 => current_variation_num;
            <<< "  Loaded variation 1 instead" >>>;
        }
    }
}
```

**Update OSC Handler:**
```chuck
if(msg.address == "/chuloopa/variations_ready") {
    msg.getInt(0) => int num_variations;
    num_variations => num_variations_available;  // ✅ Store count
    1 => current_variation_num;                  // Reset to var1
    1 => variations_ready;
    0 => generation_failed;

    <<< "" >>>;
    <<< "✓ Python:", num_variations, "variations ready!" >>>;
    <<< "  Press D1 to load variation 1" >>>;
    <<< "  Press D#1 to cycle through variations" >>>;
    <<< "" >>>;
}
```

**Update executeToggleVariation:**
```chuck
if(variation_mode_active == 0) {
    // Use current_variation_num instead of hardcoded 1
    if(loadVariationFile(0, current_variation_num)) {
        1 => variation_mode_active;
    }
}
```

**Files to Modify:**
- `src/chuloopa_drums_v2.ck` (lines 130, 513, 1406, 1474, 2130)

**Testing:**
1. Record loop
2. Wait for Python to generate variations
3. Press D1 to load variation 1
4. Press D#1 to cycle to variation 2
5. Verify: Different patterns play
6. Press D#1 again to cycle to variation 3
7. Verify: Wraps back to variation 1 after last variation

---

## Phase 5: Visual Feedback Improvements (Enhancement)

### 5.1 Update Sphere Color for Multi-Variation

**Current:** Blue-green when variation ready

**Proposed:** Show variation number via hue shift

```chuck
// In visual feedback loop (line ~1813)
else if(variations_ready && !variation_mode_active) {
    // Calculate hue based on current_variation_num
    (current_variation_num - 1) / (num_variations_available $ float) => float hue;

    // HSV to RGB (simplified)
    hue * 0.3 + 0.5 => float h;  // Map to 0.5-0.8 (cyan to blue range)
    @(0.2 + h * 0.3, 0.6, 0.7 - h * 0.2) => target_color;
    0.6 => target_bloom;
}
```

### 5.2 Add Variation Number Text Display

```chuck
// Add new GText element (after line ~245)
GText variation_num_text --> scene;
variation_num_text.pos(@(0.0, 1.5, 0.0));  // Above sphere
variation_num_text.text("");
variation_num_text.sca(0.3);

// Update in visual loop
if(variation_mode_active) {
    "Var " + current_variation_num => variation_num_text.text;
    @(0.9, 0.9, 0.9) => variation_num_text.color;
} else {
    "" => variation_num_text.text;  // Hide when not in variation mode
}
```

**Files to Modify:**
- `src/chuloopa_drums_v2.ck` (lines 245, 1813, visual loop)

---

## Implementation Order

**Week 1: Critical Fixes**
1. Phase 1: Queued clear track (2 hours)
2. Phase 2: Error handling (1 hour)
3. Phase 3: Race condition fix (2 hours)
4. Testing & validation (2 hours)

**Week 2: Enhancements**
5. Phase 4: Multi-variation support (3 hours)
6. Phase 5: Visual feedback (2 hours)
7. Integration testing (2 hours)
8. Documentation update (1 hour)

**Total Estimated Time:** 15 hours

---

## Testing Checklist

### Critical Path Tests

- [ ] **Queued Clear:** Record loop, press C#1 mid-loop, verify clears at boundary
- [ ] **Immediate Clear:** No loop, press C#1, verify immediate clear
- [ ] **Load Failure:** Delete variation file, toggle mode, verify error message
- [ ] **Race Condition:** Record two loops rapidly, verify correct variation
- [ ] **Variation Toggle:** Record, wait for ready, toggle, verify smooth transition

### Edge Cases

- [ ] **Clear During Variation:** Load variation, clear track, verify OSC sent
- [ ] **Regenerate During Recording:** Start recording, press regenerate, verify ignored
- [ ] **Toggle Without Ready:** No variation, press D1, verify error message
- [ ] **Multiple Queued Actions:** Queue clear + toggle, verify both execute
- [ ] **Python Offline:** Record loop, no OSC response, verify timeout handling

### Performance Tests

- [ ] **Long Loop:** 8-second loop, verify queue timing accurate
- [ ] **Rapid Actions:** Press D1 rapidly, verify only one queued
- [ ] **Memory Leak:** Record/clear 100 times, verify no memory growth

---

## Files to Backup Before Changes

```bash
cd .worktrees/event-management-chuck
cp src/chuloopa_drums_v2.ck src/chuloopa_drums_v2.ck.backup
git add -A
git commit -m "backup: save pre-refactor state"
```

---

## Documentation Updates Needed

After implementation:

1. **CLAUDE.md:**
   - Update MIDI mappings (D#1 → Note 40, E1 → Note 41)
   - Document queued clear behavior
   - Add multi-variation workflow

2. **QUICK_START.md:**
   - Add section: "Understanding Queued Actions"
   - Add section: "Working with Multiple Variations"
   - Update troubleshooting (file loading errors)

3. **TESTING.md:**
   - Add event management test scenarios
   - Document race condition test procedure

---

## Future Considerations

### Beyond This Branch

**Architectural Refactor (Future Branch):**
- Replace global state with `TrackState` class
- Implement proper action queue data structure
- Add event logging/replay for debugging

**Python Integration (Future Branch):**
- Add timeout handling for OSC messages
- Implement variation caching
- Add variation preview mode (play first 2 seconds)

**UX Enhancements (Future Branch):**
- Visual progress bar during Python generation
- Variation thumbnail previews (symbolic pattern visualization)
- Auto-variation mode (randomly cycles every N loops)

---

**End of Implementation Plan**
