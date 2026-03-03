# Drag-and-Drop Sample Loading Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add three drag-and-drop zones to chuloopa_drums_v2.ck for instant hot-swapping of kick/snare/hat samples during live performance

**Architecture:** Add visual drop zones below loop geometry with mouse position detection. Files dropped into zones trigger instant SndBuf reload across all tracks. Flash effects provide success/error feedback. No test framework needed (ChucK audio program).

**Tech Stack:** ChucK, ChuGL (graphics), SndBuf (audio playback), UI.getMousePos(), GWindow.files()

---

## Task 1: Add Drop Zone Visual Elements and State Variables

**Files:**
- Modify: `src/chuloopa_drums_v2.ck` (after hot sauce bottle setup, ~line 310)

**Step 1: Add state variables after hot sauce bottle setup**

Insert after the hot sauce bottle setup (around line 310):

```chuck
// === DROP ZONE STATE VARIABLES ===
// For drag-and-drop detection
GWindow.files() @=> string files[];

// Drop zone visual elements
GMesh drop_zones[3];
PhongMaterial drop_zone_mats[3];
GText zone_labels[3];

// Flash effect state
float zone_flash_intensity[3];
time zone_flash_start[3];

// Zone configuration
float zone_x_positions[3];
-1.5 => zone_x_positions[0];  // Kick (left)
0.0 => zone_x_positions[1];   // Snare (center)
1.5 => zone_x_positions[2];   // Hat (right)

vec3 zone_colors[3];
@(0.9, 0.2, 0.2) => zone_colors[0];  // Red (kick)
@(1.0, 0.6, 0.1) => zone_colors[1];  // Orange (snare)
@(0.2, 0.8, 0.9) => zone_colors[2];  // Cyan (hat)

string zone_drum_names[3];
"KICK" => zone_drum_names[0];
"SNARE" => zone_drum_names[1];
"HAT" => zone_drum_names[2];

string current_sample_names[3];
```

**Step 2: Test ChucK compiles**

Run: `chuck src/chuloopa_drums_v2.ck`

Expected: Program starts without errors (may quit early since zones not created yet, that's OK)

**Step 3: Commit state variables**

```bash
git add src/chuloopa_drums_v2.ck
git commit -m "feat(drop): add drop zone state variables

- GWindow.files() for drag-and-drop detection
- Drop zone visual element arrays (3 zones)
- Flash effect state tracking
- Zone positions, colors, names configuration

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Create Drop Zone Visual Elements

**Files:**
- Modify: `src/chuloopa_drums_v2.ck` (after state variables, before audio setup)

**Step 1: Add drop zone creation loop**

Insert after the drop zone state variables:

```chuck
// === CREATE DROP ZONES ===
for(0 => int i; i < 3; i++) {
    // Create drop zone square
    GMesh zone(new CubeGeometry, new PhongMaterial) --> scene;
    zone @=> drop_zones[i];
    drop_zones[i].sca(0.4);  // Small square
    drop_zones[i].posX(zone_x_positions[i]);
    drop_zones[i].posY(-2.0);
    drop_zones[i].posZ(0.0);

    // Get material reference
    drop_zones[i].mat() $ PhongMaterial @=> drop_zone_mats[i];
    drop_zone_mats[i].color(zone_colors[i] * 0.6);  // Dim initially
    drop_zone_mats[i].specular(zone_colors[i] * 0.3);
    drop_zone_mats[i].emission(@(0.0, 0.0, 0.0));

    // Create text label
    GText label --> scene;
    label @=> zone_labels[i];
    zone_labels[i].text("DROP " + zone_drum_names[i]);
    zone_labels[i].posX(zone_x_positions[i]);
    zone_labels[i].posY(-2.5);
    zone_labels[i].posZ(0.0);
    zone_labels[i].sca(0.15);
    zone_labels[i].color(@(0.7, 0.7, 0.7));

    // Initialize flash state
    0.0 => zone_flash_intensity[i];
    now => zone_flash_start[i];
}
```

**Step 2: Test visual elements appear**

Run: `chuck src/chuloopa_drums_v2.ck`

Expected:
- Three colored squares visible at bottom (red/orange/cyan)
- Three text labels "DROP KICK", "DROP SNARE", "DROP HAT" below squares
- Program runs without errors

**Step 3: Commit visual elements**

```bash
git add src/chuloopa_drums_v2.ck
git commit -m "feat(drop): create drop zone visual elements

- Three colored squares (PhongMaterial) at Y=-2.0
- Text labels below at Y=-2.5
- Zone colors: red (kick), orange (snare), cyan (hat)
- Initial state: dim, no emission

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Add Helper Functions (Mouse Detection, Filename Extraction, Flash Trigger)

**Files:**
- Modify: `src/chuloopa_drums_v2.ck` (before main program section, ~line 1600)

**Step 1: Add helper functions before main program**

Insert before the main program section (after existing functions, before "=== MAIN PROGRAM ==="):

```chuck
// === DROP ZONE HELPER FUNCTIONS ===

fun int detectZoneFromMouse(vec2 mousePos) {
    // Divide screen into thirds based on mouse X position
    GG.windowWidth() => float windowWidth;
    mousePos.x => float mouseX;
    windowWidth / 3.0 => float zoneWidth;

    if(mouseX < zoneWidth) return 0;        // KICK (left third)
    else if(mouseX < zoneWidth * 2.0) return 1;  // SNARE (middle third)
    else return 2;                          // HAT (right third)
}

fun string getFilename(string filepath) {
    // Extract just filename from full path
    -1 => int last_slash;
    for(0 => int i; i < filepath.length(); i++) {
        if(filepath.substring(i, i+1) == "/") {
            i => last_slash;
        }
    }
    if(last_slash >= 0 && last_slash < filepath.length() - 1) {
        return filepath.substring(last_slash + 1, filepath.length());
    }
    return filepath;
}

fun void triggerZoneFlash(int zone, int success) {
    // success: 1=green flash, 0=red error flash
    now => zone_flash_start[zone];

    if(success) {
        3.0 => zone_flash_intensity[zone];  // Bright green emission
    } else {
        -1.0 => zone_flash_intensity[zone];  // Negative = red error flag
    }
}
```

**Step 2: Test ChucK compiles**

Run: `chuck src/chuloopa_drums_v2.ck`

Expected: Program starts without errors, helper functions available

**Step 3: Commit helper functions**

```bash
git add src/chuloopa_drums_v2.ck
git commit -m "feat(drop): add helper functions

- detectZoneFromMouse: divide screen into thirds
- getFilename: extract filename from path
- triggerZoneFlash: set flash intensity (green/red)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Add Sample Loading Function (Hot-Swap)

**Files:**
- Modify: `src/chuloopa_drums_v2.ck` (after helper functions)

**Step 1: Add loadDrumSample function**

Insert after the helper functions:

```chuck
fun int loadDrumSample(int zone, string filepath) {
    // zone: 0=kick, 1=snare, 2=hat
    <<< "" >>>;
    <<< ">>> LOADING SAMPLE:", zone_drum_names[zone], "<<<" >>>;
    <<< "File:", filepath >>>;

    // Test load to validate file
    SndBuf test;
    filepath => test.read;

    if(test.samples() == 0) {
        <<< "ERROR: Invalid audio file or file not found" >>>;
        triggerZoneFlash(zone, 0);  // Red error flash
        "INVALID FILE" => zone_labels[zone].text;
        return 0;
    }

    <<< "Valid file, loading into all tracks..." >>>;

    // Hot-swap: reload all track SndBufs for this drum type
    for(0 => int i; i < NUM_TRACKS; i++) {
        if(zone == 0) {
            // KICK
            filepath => kick_sample[i].read;
            kick_sample[i].samples() => kick_sample[i].pos;  // Reset to end (silent)
        }
        else if(zone == 1) {
            // SNARE
            filepath => snare_sample[i].read;
            snare_sample[i].samples() => snare_sample[i].pos;
        }
        else if(zone == 2) {
            // HAT
            filepath => hat_sample[i].read;
            hat_sample[i].samples() => hat_sample[i].pos;
        }
    }

    // Success feedback
    triggerZoneFlash(zone, 1);  // Green success flash
    getFilename(filepath) => string fname;
    fname => current_sample_names[zone];
    fname + " | LOADED!" => zone_labels[zone].text;

    <<< "✓ Sample loaded successfully!" >>>;
    <<< "  Duration:", (test.length() / second) $ float, "sec" >>>;
    <<< "" >>>;

    return 1;
}
```

**Step 2: Test ChucK compiles**

Run: `chuck src/chuloopa_drums_v2.ck`

Expected: Program starts without errors, function available

**Step 3: Commit sample loading function**

```bash
git add src/chuloopa_drums_v2.ck
git commit -m "feat(drop): add sample loading with hot-swap

- loadDrumSample: test load, then reload all tracks
- Validates file before loading (SndBuf.samples() check)
- Triggers flash feedback (green=success, red=error)
- Updates zone label text with filename
- Instant hot-swap: next hit uses new sample

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Integrate Drop Zone Visual Updates into Visualization Loop

**Files:**
- Modify: `src/chuloopa_drums_v2.ck:1684-1891` (in visualizationLoop function)

**Step 1: Add drop zone visual updates**

Find the visualizationLoop() function. After the hot sauce bottle section (around line 1896), add:

```chuck
        // === UPDATE DROP ZONE VISUALS ===
        for(0 => int i; i < 3; i++) {
            // Decay flash intensity (200ms flash duration)
            zone_flash_intensity[i] * 0.85 => zone_flash_intensity[i];

            // Apply flash effect to material
            if(zone_flash_intensity[i] > 0.1) {
                // Success flash (green)
                drop_zone_mats[i].color(zone_colors[i]);
                drop_zone_mats[i].emission(@(0.5, 1.5, 0.5) * zone_flash_intensity[i]);
            }
            else if(zone_flash_intensity[i] < -0.1) {
                // Error flash (red)
                drop_zone_mats[i].color(@(1.0, 0.2, 0.2));
                drop_zone_mats[i].emission(@(2.0, 0.3, 0.3) * Math.fabs(zone_flash_intensity[i]));
            }
            else {
                // Normal state (dim, no emission)
                drop_zone_mats[i].color(zone_colors[i] * 0.6);
                drop_zone_mats[i].emission(@(0.0, 0.0, 0.0));
            }
        }
```

**Step 2: Test visual feedback works**

Run: `chuck src/chuloopa_drums_v2.ck`

Expected:
- Drop zones visible at bottom (dim, no flash)
- Program runs without errors

To test flash (manual): temporarily add `triggerZoneFlash(0, 1);` at startup to see green flash on kick zone

**Step 3: Commit visual update integration**

```bash
git add src/chuloopa_drums_v2.ck
git commit -m "feat(drop): integrate zone visual updates

- Flash intensity decay (0.85 factor, ~200ms duration)
- Green emission for success flash (zone_flash > 0.1)
- Red emission for error flash (zone_flash < -0.1)
- Dim state when no flash active

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Add Drag-and-Drop Detection Logic

**Files:**
- Modify: `src/chuloopa_drums_v2.ck:1684-1891` (in visualizationLoop function)

**Step 1: Add drag-and-drop detection**

In visualizationLoop(), after the drop zone visual updates, add:

```chuck
        // === DRAG-AND-DROP DETECTION ===
        if(GWindow.files() != files) {
            GWindow.files() @=> files;

            if(files.size() > 0) {
                // Detect drop zone from mouse position
                UI.getMousePos() => vec2 mousePos;
                detectZoneFromMouse(mousePos) => int target_zone;

                <<< "" >>>;
                <<< ">>> FILE DROPPED into", zone_drum_names[target_zone], "zone <<<" >>>;

                // Load sample (hot-swap)
                loadDrumSample(target_zone, files[0]);
            }
        }
```

**Step 2: Test drag-and-drop functionality**

Run: `chuck src/chuloopa_drums_v2.ck`

Test sequence:
1. Verify program starts and shows three drop zones
2. Drag a valid WAV file (e.g., any drum sample) into the window
3. Expected:
   - Console shows ">>> FILE DROPPED into [KICK/SNARE/HAT] zone <<<"
   - Zone flashes green briefly
   - Text updates to "filename.wav | LOADED!"
4. Record a loop (press Note 36, beatbox)
5. Verify the new sample plays when hits trigger
6. Try dragging an invalid file (e.g., .txt file)
7. Expected:
   - Zone flashes red
   - Text shows "INVALID FILE"
   - Original sample still works

**Step 3: Commit drag-and-drop detection**

```bash
git add src/chuloopa_drums_v2.ck
git commit -m "feat(drop): add drag-and-drop detection

- Detect file drop via GWindow.files() comparison
- Use UI.getMousePos() to determine target zone
- Trigger loadDrumSample() for hot-swap
- Console feedback for dropped file location

Complete drag-and-drop sample loading feature

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Initialize Default Sample Names on Startup

**Files:**
- Modify: `src/chuloopa_drums_v2.ck` (in drop zone creation loop)

**Step 1: Add default sample name initialization**

Find the drop zone creation loop. After the flash state initialization, add:

```chuck
// Initialize with default sample names
for(0 => int i; i < 3; i++) {
    // [... existing zone creation code ...]

    // Initialize flash state
    0.0 => zone_flash_intensity[i];
    now => zone_flash_start[i];
}

// Set initial sample names (AFTER loop)
getFilename(KICK_SAMPLE) => current_sample_names[0];
getFilename(SNARE_SAMPLE) => current_sample_names[1];
getFilename(HAT_SAMPLE) => current_sample_names[2];

// Update zone labels with default samples
current_sample_names[0] => zone_labels[0].text;
current_sample_names[1] => zone_labels[1].text;
current_sample_names[2] => zone_labels[2].text;
```

**Step 2: Test default names display**

Run: `chuck src/chuloopa_drums_v2.ck`

Expected:
- Zone labels show "kick.wav", "snare.wav", "hat.WAV" (or actual filenames)
- Not "DROP KICK" anymore (shows loaded samples)

**Step 3: Commit default sample names**

```bash
git add src/chuloopa_drums_v2.ck
git commit -m "feat(drop): display default sample names on startup

- Initialize current_sample_names with default samples
- Update zone labels to show filenames instead of DROP prompts
- Users see what samples are currently loaded

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Final Testing and Push

**Files:**
- Test: `src/chuloopa_drums_v2.ck`

**Step 1: Complete end-to-end test**

Run: `chuck src/chuloopa_drums_v2.ck`

Full test sequence:
1. **Visual check:**
   - Three colored zones at bottom (red/orange/cyan)
   - Labels show default sample names

2. **Drop valid sample (kick zone):**
   - Drag a WAV file to left third of window
   - Verify: Green flash, text updates to "[filename] | LOADED!"

3. **Test hot-swap during playback:**
   - Record a loop (MIDI Note 36, beatbox some kicks)
   - While loop playing, drop a different kick sample
   - Verify: New sample plays on next hit, no glitches

4. **Drop to snare zone:**
   - Drag sample to center third
   - Verify: Correct zone detects drop, loads into snare

5. **Drop to hat zone:**
   - Drag sample to right third
   - Verify: Correct zone detects drop, loads into hat

6. **Drop invalid file:**
   - Drag a .txt or .jpg file
   - Verify: Red flash, "INVALID FILE" text, no crash

7. **Performance check:**
   - Verify smooth 60fps during drops
   - No audio dropouts during hot-swap

**Step 2: Push to remote staging**

```bash
git push origin staging
```

**Step 3: Create implementation summary**

Create `docs/plans/2026-02-05-drag-drop-implementation-summary.md`:

```markdown
# Drag-and-Drop Sample Loading - Implementation Summary

**Date:** 2026-02-05
**Branch:** staging
**Commits:** 7 commits

## What Was Implemented

Added drag-and-drop sample loading to chuloopa_drums_v2.ck with three color-coded zones for instant hot-swapping kick/snare/hat samples during live performance.

### Features

1. **Three Drop Zones**
   - Position: Y=-2.0 (below loop geometry)
   - Colors: Red (kick), Orange (snare), Cyan (hat)
   - Size: 0.4x0.4 squares with PhongMaterial

2. **Mouse Position Detection**
   - Screen divided into thirds (left/center/right)
   - `detectZoneFromMouse()` determines target zone

3. **Instant Hot-Swap**
   - Valid files reload all track SndBuf arrays
   - Next scheduled hit uses new sample
   - No interruption to currently playing loops

4. **Visual Feedback**
   - Green flash (200ms) on successful load
   - Red flash on error (invalid file)
   - Text shows "filename.wav | LOADED!"

5. **Error Handling**
   - Invalid files rejected with SndBuf.samples() check
   - Red flash + "INVALID FILE" text
   - Original sample remains loaded

### Files Modified

- `src/chuloopa_drums_v2.ck` (+~150 lines)

### Success Criteria

✅ Three drop zones visible at bottom, color-coded correctly
✅ Mouse position correctly detects left/middle/right zones
✅ Valid audio files load instantly and play on next hit
✅ Invalid files show red flash + error text without crashing
✅ Text labels show filename + "LOADED!" after successful drop
✅ Currently playing loops continue without interruption during load
✅ Works with all audio formats supported by ChucK SndBuf

## Next Steps

Optional enhancements:
- Save/load sample sets (presets)
- Visual waveform preview in zones
- Undo/redo for sample changes
```

**Step 4: Commit summary and push**

```bash
git add docs/plans/2026-02-05-drag-drop-implementation-summary.md
git commit -m "docs: add drag-drop implementation summary

Complete summary of drag-and-drop sample loading:
- 7 commits, ~150 lines added
- Three color-coded zones with hot-swap
- Green/red flash feedback
- All success criteria met

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git push origin staging
```

---

## Success Criteria Checklist

After Task 7 completion, verify all criteria:

- [ ] Three drop zones visible at bottom, color-coded correctly
- [ ] Mouse position correctly detects left/middle/right zones
- [ ] Valid audio files load instantly and play on next hit
- [ ] Invalid files show red flash + error text without crashing
- [ ] Text labels show filename + "LOADED!" after successful drop
- [ ] Currently playing loops continue without interruption during load
- [ ] Works with all audio formats supported by ChucK SndBuf

## Reference Files

- Design doc: `docs/plans/2026-02-05-drag-drop-sample-loading-design.md`
- Reference implementation: `/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHUGL/sound_dropper_stage2.ck`

## Notes for ChucK Implementation

- No test framework (ChucK audio program)
- Testing via manual playback and file drops
- Frequent commits after each functional addition
- Console output for debugging (<<< >>>)
