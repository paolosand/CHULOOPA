# Event Management Analysis: chuloopa_drums_v2.ck

**Analysis Date:** 2026-03-11
**Branch:** event-management-chuck
**File Analyzed:** src/chuloopa_drums_v2.ck

## Executive Summary

The current event management system uses a **queued action pattern** to ensure all state changes happen at loop boundaries, preventing audio glitches and maintaining musical timing. This analysis identifies the current architecture, data flow, and opportunities for improvement.

---

## 1. Current Architecture Overview

### 1.1 State Variables

**Variation Mode State** (lines 508-523):
```chuck
int variation_mode_active;           // 0 = original, 1 = variation
int variations_ready;                // 0 = not ready, 1 = ready
int generation_requested;            // 0 = not requested, 1 = requested
int generation_failed;               // 0 = no failure, 1 = failed
float current_spice_level;           // 0.0-1.0
string variation_status_message;     // Status from Python
```

**Queued Actions** (lines 503-506):
```chuck
int queued_load_track[NUM_TRACKS];      // Load from file at next cycle
int queued_clear_track[NUM_TRACKS];     // Clear at next cycle
int queued_toggle_variation;            // Toggle variation at next cycle
```

**Playback Control** (lines 486-496):
```chuck
int is_playing[NUM_TRACKS];
int has_loop[NUM_TRACKS];
int drum_playback_active[NUM_TRACKS];
int drum_playback_id[NUM_TRACKS];       // Session ID to invalidate old hits
time loop_start_time[NUM_TRACKS];
float loop_length[NUM_TRACKS];
```

---

## 2. Event Flow Diagrams

### 2.1 Variation Generation Flow

```
User Records Loop
       ↓
   [MIDI Release Note 36]
       ↓
   Export to track_0_drums.txt
       ↓
   Python Watchdog Detects Change
       ↓
   Generate Variation (Gemini API)
       ↓
   OSC: /chuloopa/variations_ready → ChucK
       ↓
   variations_ready = 1
       ↓
   Visual Feedback (sphere turns blue-green)
       ↓
   User Presses D1 (Note 38)
       ↓
   toggleVariationMode() queues action
       ↓
   queued_toggle_variation = 1
       ↓
   [WAIT FOR LOOP BOUNDARY]
       ↓
   executeToggleVariation() at boundary
       ↓
   Load variation file
       ↓
   variation_mode_active = 1
```

### 2.2 Clear Track Flow

```
User Presses C#1 (Note 37)
       ↓
   clearTrack(0) - IMMEDIATE execution
       ↓
   Stop playback: drum_playback_active[0] = 0
       ↓
   Clear symbolic data
       ↓
   Reset flags: has_loop[0] = 0
       ↓
   OSC: /chuloopa/track_cleared → Python
       ↓
   Python cancels watchdog
       ↓
   Reset variation state:
     - variations_ready = 0
     - variation_mode_active = 0
     - generation_requested = 0
```

### 2.3 Queued Action Execution (Master Coordinator)

```
Master Coordinator Loop (lines 1320-1389)
       ↓
   Find reference track with active playback
       ↓
   Calculate time to next loop boundary
       ↓
   [WAIT: time_to_boundary => now]
       ↓
   === LOOP BOUNDARY REACHED ===
       ↓
   Process queued_toggle_variation
       ↓
   Process queued_load_track[i]
       ↓
   Process queued_clear_track[i]
       ↓
   [Loop continues]
```

---

## 3. Key Functions

### 3.1 Loading Functions

**loadDrumDataFromFile(int track)** (line 918):
- Loads original recorded pattern from `track_N_drums.txt`
- Stops existing playback via `drum_playback_id` increment
- Parses CSV format (class, timestamp, velocity, delta_time)
- Starts new `drumPlaybackLoop()` with new playback ID
- **Execution:** At loop boundary OR immediately if no loop active

**loadVariationFile(int track, int var_num)** (line 1100):
- Loads AI-generated variation from `track_N_drums_var{var_num}.txt`
- Same parsing logic as `loadDrumDataFromFile()`
- Increments `drum_playback_id` to invalidate old hits
- **Execution:** At loop boundary only (called by `executeToggleVariation()`)

### 3.2 Clearing Functions

**clearTrack(int track)** (line 1650):
- Stops LiSa playback (legacy audio loop system)
- Clears symbolic data arrays
- Resets flags: `is_recording`, `is_playing`, `has_loop`
- Stops drum playback: `drum_playback_active[track] = 0`
- Resets master if this was the master track
- **Execution:** IMMEDIATE (not queued)

**clearSymbolicData(int track)** (not shown in excerpts):
- Clears drum class, timestamp, velocity, delta_time arrays
- Called by `clearTrack()` and before loading new data

### 3.3 Queuing Functions

**toggleVariationMode()** (line 1443):
- Validates: has_loop[0] must be true
- Validates: variations_ready must be 1 (if switching TO variation)
- Sets `queued_toggle_variation = 1`
- Console output: ">>> QUEUED: Variation toggle will occur at next loop boundary <<<"

**queueLoadFromFile(int track)** (line 908):
- Sets `queued_load_track[track] = 1`
- Console output: ">>> QUEUED: Track will load from file at next loop cycle <<<"

### 3.4 Execution Functions

**executeToggleVariation()** (line 1463):
- Called at loop boundary by master coordinator
- Checks `variation_mode_active` flag
- If 0 → 1: Load variation file (`loadVariationFile(0, 1)`)
- If 1 → 0: Load original file (`loadDrumDataFromFile(0)`)
- Updates `variation_mode_active` flag
- Console output with box drawing characters

---

## 4. OSC Communication

### 4.1 ChucK → Python

**sendRegenerate()** (line 211):
- Message: `/chuloopa/regenerate`
- Payload: None
- Trigger: User presses D#1 (Note 39)
- Purpose: Request new variation generation

**sendTrackCleared()** (line 217):
- Message: `/chuloopa/track_cleared`
- Payload: None
- Trigger: `clearTrack()` called
- Purpose: Cancel Python watchdog

**sendSpiceLevel(float spice)** (line 205):
- Message: `/chuloopa/spice`
- Payload: Float (0.0-1.0)
- Trigger: CC 74 knob movement
- Purpose: Update variation creativity level

### 4.2 Python → ChucK

**Received in oscListener()** (lines 1400-1440):

**/chuloopa/variations_ready**:
- Payload: `int num_variations`
- Action: `variations_ready = 1`, `generation_failed = 0`
- Console: "✓ Python: Variation ready! Press D1..."

**/chuloopa/generation_failed**:
- Payload: `string reason`
- Action: `variations_ready = 0`, `generation_failed = 1`
- Console: "✗ Python: Generation FAILED! Reason: ..."

**/chuloopa/generation_progress**:
- Payload: `string status`
- Action: Store in `variation_status_message`
- Console: "Python: {status}"

---

## 5. Critical Invariants

### 5.1 Playback Session IDs

**Purpose:** Prevent old scheduled drum hits from playing after pattern change

**Mechanism:**
- Each track has `drum_playback_id[track]`
- Incremented when loading new pattern
- `drumPlaybackLoop()` captures ID at start
- Before playing hit: check if current ID matches captured ID
- If mismatch: abort hit (old session)

**Code Location:** Lines 494, 1121, 1091

### 5.2 Loop Boundary Synchronization

**Ensures:**
- Pattern changes happen at musically correct times
- No mid-loop jarring transitions
- Master loop timing maintained

**Mechanism:**
- Master coordinator calculates `time_to_boundary`
- Waits: `time_to_boundary => now`
- Executes all queued actions atomically
- Only processes actions if boundary is within current loop cycle

**Code Location:** Lines 1342-1376

### 5.3 State Flag Consistency

**Clear Track Resets:**
```chuck
variations_ready = 0          // Variations invalid
variation_mode_active = 0     // Exit variation mode
generation_requested = 0      // Cancel pending generation
has_loop[0] = 0              // No loop exists
drum_playback_active[0] = 0  // Stop playback
```

**Code Location:** Lines 2117-2122

---

## 6. Identified Issues

### 6.1 Inconsistent Queuing Behavior

**Problem:**
- `clearTrack()` executes IMMEDIATELY (line 2117)
- `toggleVariationMode()` queues for loop boundary (line 1456)
- `loadDrumDataFromFile()` can execute immediately OR at boundary

**Impact:**
- Clearing mid-loop creates jarring silence
- Inconsistent with stated "queued action system" design
- User confusion about timing behavior

**Evidence:**
```chuck
// Line 2117: Clear is immediate
else if(data1 == NOTE_CLEAR_TRACK) {
    clearTrack(0);  // <-- Direct call, no queuing
    sendTrackCleared();
    ...
}

// Line 2125: Toggle is queued
else if(data1 == NOTE_TOGGLE_VARIATION) {
    toggleVariationMode();  // <-- Queues action
}
```

### 6.2 Missing Queued Clear Implementation

**Problem:**
- `queued_clear_track[]` array exists (line 505)
- Master coordinator processes it (lines 1370-1376)
- But NO function calls `queued_clear_track[i] = 1`
- `clearTrack()` is always called directly

**Impact:**
- Dead code (queued clear logic never used)
- Violates intended architecture pattern

### 6.3 Hardcoded Variation Number

**Problem:**
```chuck
loadVariationFile(0, 1);  // Always loads var1
```

**Impact:**
- Cannot select between multiple variations
- Python can generate multiple variations but ChucK ignores them
- No random selection or user choice

**Code Location:** Line 1474

### 6.4 No Error Handling for Missing Files

**Problem:**
- `loadDrumDataFromFile()` and `loadVariationFile()` check `fin.good()`
- If file missing: return 0
- But calling code doesn't check return value

**Impact:**
- Silent failures (no user feedback)
- State flags may become inconsistent
- Example: `variation_mode_active = 1` but variation failed to load

**Code Location:** Lines 926, 1114

### 6.5 Race Condition: Variation Ready During Recording

**Scenario:**
1. User recording new loop
2. Python finishes generating variation for OLD loop
3. OSC: `/chuloopa/variations_ready` arrives
4. `variations_ready = 1` set
5. User releases recording
6. Old variation now "ready" but doesn't match new loop

**Impact:**
- Variation from OLD loop applied to NEW loop
- Timing/musical mismatch

**Code Location:** Lines 1406-1414

### 6.6 Spice Level Not Sent on Variation Toggle

**Problem:**
- User adjusts CC 74 (spice level)
- User presses D1 (toggle variation)
- Variation loads with OLD spice level
- User must press D#1 (regenerate) to get new spice

**Impact:**
- Two-step process instead of one
- Confusing UX

---

## 7. Timing Analysis

### 7.1 Loop Boundary Wait Time

**Best Case:** 0ms (action queued exactly at boundary)
**Worst Case:** `loop_length[track]` seconds
**Average Case:** `loop_length[track] / 2` seconds

**Typical Loop Length:** 2-8 seconds
**Average Wait:** 1-4 seconds

### 7.2 Variation Generation Time

**Python Processing:**
- File detection: ~50-100ms (watchdog)
- Gemini API call: 500-2000ms
- File write: ~10ms
- OSC send: ~5ms

**Total:** 565ms - 2115ms (0.5-2 seconds)

### 7.3 Total Time: Record → Play Variation

**User Journey:**
1. Release Note 36 (record) → Export file → **~10ms**
2. Python detects file → **~50ms**
3. Gemini generates → **~1000ms** (1 second)
4. OSC /variations_ready → **~5ms**
5. User presses D1 → Queue → **~2000ms** (average wait)
6. Load variation at boundary → **~50ms**

**Total:** ~3.1 seconds (best case) to ~6 seconds (worst case)

---

## 8. Visual Feedback State Machine

### 8.1 Sphere Color States

**Gray (No Loop):**
- Condition: `!has_loop[0] && !is_recording[0]`
- RGB: (0.5, 0.5, 0.5)
- Bloom: 0.3

**Red (Playing Original):**
- Condition: `has_loop[0] && !variation_mode_active && !variations_ready`
- RGB: (1.0, 0.3, 0.3)
- Bloom: 0.4

**Blue-Green (Variation Ready):**
- Condition: `variations_ready && !variation_mode_active`
- RGB: (0.2, 0.6, 0.7)
- Bloom: 0.6
- **Blinking:** Yes (6 Hz sine wave)

**Blue→Yellow→Red Gradient (Playing Variation):**
- Condition: `variation_mode_active`
- Color based on `current_spice_level`:
  - 0.0-0.5: Blue → Yellow gradient
  - 0.5-1.0: Yellow → Red gradient
- Bloom: 0.5 + spice * 0.3

**Code Location:** Lines 1790-1830

### 8.2 Shape Morphing

**Cube (Conservative):**
- Condition: `variation_mode_active && spice < 0.4`
- Faces: 6

**Octahedron (Balanced):**
- Condition: `variation_mode_active && spice 0.4-0.7`
- Faces: 8

**Dodecahedron (Experimental):**
- Condition: `variation_mode_active && spice >= 0.7`
- Faces: 12

**Code Location:** Lines 1835-1850

---

## 9. Recommendations

### 9.1 Immediate Fixes (High Priority)

**A. Make Clear Track Queued**
```chuck
// Replace direct clearTrack(0) call with:
fun void queueClearTrack(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;
    <<< ">>> QUEUED: Track", track, "will clear at next loop boundary <<<" >>>;
    1 => queued_clear_track[track];
}

// In MIDI handler:
else if(data1 == NOTE_CLEAR_TRACK) {
    queueClearTrack(0);  // Queue instead of immediate
}
```

**B. Add Return Value Checking**
```chuck
// In executeToggleVariation():
if(variation_mode_active == 0) {
    if(!loadVariationFile(0, 1)) {
        <<< "ERROR: Failed to load variation file!" >>>;
        0 => variation_mode_active;  // Stay in original mode
        return;
    }
}
```

**C. Invalidate Variations on New Recording**
```chuck
// In recording release handler (after exportDrumData):
0 => variations_ready;       // Old variations no longer valid
0 => variation_mode_active;  // Force back to original
```

### 9.2 Feature Enhancements (Medium Priority)

**D. Multi-Variation Support**
```chuck
int current_variation_num;  // Track which variation is loaded (1-5)

fun void loadNextVariation() {
    current_variation_num % 5 + 1 => current_variation_num;
    loadVariationFile(0, current_variation_num);
}

// Add MIDI mapping: Note 40 = load next variation
```

**E. Immediate Mode Toggle (Dev Feature)**
```chuck
// Add to config section:
0 => int QUEUED_ACTIONS_ENABLED;  // Toggle for testing

// In toggleVariationMode():
if(!QUEUED_ACTIONS_ENABLED) {
    executeToggleVariation();  // Immediate
} else {
    1 => queued_toggle_variation;  // Queued
}
```

### 9.3 Architecture Improvements (Low Priority)

**F. Unified Action Queue System**

Instead of separate `queued_*` arrays, use a queue data structure:

```chuck
class QueuedAction {
    int action_type;  // 0=load, 1=clear, 2=toggle_var
    int track;
    int var_num;      // For load variation actions
}

QueuedAction action_queue[10];  // Max 10 pending actions
int queue_size;
```

**G. State Machine Refactor**

Current state is scattered across multiple variables. Consider:

```chuck
class TrackState {
    int mode;  // 0=empty, 1=recording, 2=playing_original, 3=playing_variation
    int variations_available;
    int current_variation;
    float spice_level;
}
```

---

## 10. Testing Recommendations

### 10.1 Unit Tests Needed

**Test: Queued Actions Execute at Boundary**
- Record 2-second loop
- Queue clear at t=0.5s
- Verify clear happens at t=2.0s (boundary)

**Test: Playback ID Invalidation**
- Start playback
- Load new pattern mid-loop
- Verify old hits don't play

**Test: Variation Invalidation on New Recording**
- Generate variation
- Record new loop
- Verify variations_ready = 0

### 10.2 Integration Tests Needed

**Test: Full Variation Workflow**
- Record loop → Export → Python generates → OSC ready → Toggle → Verify playback

**Test: Spice Level Propagation**
- Set CC 74 = 0.8
- Regenerate variation
- Verify Python receives 0.8
- Verify visual feedback shows red color

**Test: Clear During Variation Mode**
- Load variation
- Clear track
- Verify variation_mode_active = 0
- Verify Python receives track_cleared OSC

---

## 11. Code Quality Observations

### 11.1 Strengths

✅ **Clear Separation of Concerns:**
- Queuing functions separate from execution functions
- OSC communication isolated in dedicated functions
- Visual feedback in separate shred

✅ **Comprehensive Console Logging:**
- Box-drawing characters for major events
- Clear ">>> QUEUED:" messages
- Emoji indicators (✓, ✗)

✅ **Playback Session ID Pattern:**
- Elegant solution to prevent old hits from playing
- Simple increment-based invalidation

### 11.2 Weaknesses

❌ **Magic Numbers:**
- `1 => queued_toggle_variation` (should be constant QUEUED)
- Hardcoded variation number `1` in multiple places

❌ **Inconsistent Naming:**
- `variation_mode_active` vs `variations_ready` (plural inconsistency)
- `drum_playback_active` vs `is_playing` (different patterns)

❌ **Long Function:**
- `oscListener()` is ~40 lines with nested conditionals
- Consider extracting handlers: `handleVariationsReady()`, etc.

❌ **Global State:**
- All state in global variables (no encapsulation)
- Difficult to test in isolation

---

## 12. Related Files to Review

**Python Side:**
- `src/drum_variation_ai.py` - Watchdog and generation logic
- Check: How does Python handle `/chuloopa/track_cleared` message?
- Check: Is spice level used in generation prompt?

**Data Files:**
- `src/tracks/track_0/track_0_drums.txt` - Original pattern format
- `src/tracks/track_0/variations/track_0_drums_var1.txt` - Variation format
- Verify: Are delta_time values preserved in variations?

**Documentation:**
- `CLAUDE.md` - Update with new queued clear behavior
- `QUICK_START.md` - Document timing expectations

---

## Appendix A: State Transition Table

| Current State | Event | Next State | Actions |
|---------------|-------|------------|---------|
| No Loop | Press Record | Recording | Start onset detection |
| Recording | Release Record | Playing Original | Export → Python generates |
| Playing Original | Variation Ready (OSC) | Ready to Toggle | Set variations_ready=1 |
| Ready to Toggle | Press D1 | **QUEUED** | Set queued_toggle_variation=1 |
| **QUEUED** | Loop Boundary | Playing Variation | executeToggleVariation() |
| Playing Variation | Press D1 | **QUEUED** | Set queued_toggle_variation=1 |
| **QUEUED** | Loop Boundary | Playing Original | executeToggleVariation() |
| Any State | Press C#1 | No Loop | clearTrack() **IMMEDIATE** |
| Any State | Press D#1 | Waiting for Gen | OSC regenerate → Python |

**Key Insight:** Only ONE transition is immediate (clear). All others respect loop boundaries.

---

## Appendix B: Memory Layout

**Per-Track Arrays (NUM_TRACKS = 3):**
```
drum_classes[3][MAX_HITS]         // 3 tracks × 1000 hits × 4 bytes = 12 KB
drum_timestamps[3][MAX_HITS]      // 3 × 1000 × 4 bytes = 12 KB
drum_velocities[3][MAX_HITS]      // 3 × 1000 × 4 bytes = 12 KB
drum_delta_times[3][MAX_HITS]     // 3 × 1000 × 4 bytes = 12 KB
```

**Total symbolic data:** ~48 KB

**LiSa buffers (legacy, unused):**
```
lisa[3] with MAX_LOOP_DURATION = 20 seconds @ 44.1 kHz
= 3 × 20 × 44100 × 2 bytes = 5.3 MB
```

**Recommendation:** Remove LiSa buffers in drums-only mode to save memory.

---

## Appendix C: Console Output Examples

**Successful Variation Toggle:**
```
>>> QUEUED: Variation toggle will occur at next loop boundary <<<

[2 seconds pass...]

=== LOOP BOUNDARY: Processing queued actions ===
Executing queued variation toggle

╔═══════════════════════════════════════╗
║  LOADING VARIATION                   ║
╚═══════════════════════════════════════╝

>>> TRACK 0 LOADED FROM FILE (DRUM-ONLY MODE, Playback ID: 2) <<<
```

**Failed Variation Load:**
```
>>> QUEUED: Variation toggle will occur at next loop boundary <<<

=== LOOP BOUNDARY: Processing queued actions ===
Executing queued variation toggle

╔═══════════════════════════════════════╗
║  LOADING VARIATION                   ║
╚═══════════════════════════════════════╝

[No output - silent failure]
```

**Recommendation:** Add error message if `loadVariationFile()` returns 0.

---

**End of Analysis**
