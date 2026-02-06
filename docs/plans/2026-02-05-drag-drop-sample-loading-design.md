# Drag-and-Drop Sample Loading Design

**Date:** 2026-02-05
**Target File:** `src/chuloopa_drums_v2.ck`
**Purpose:** Add drag-and-drop UI for instant hot-swapping kick/snare/hat samples during live performance

## Overview

Add three drag-and-drop zones at the bottom of the CHULOOPA visualization that allow users to instantly replace kick, snare, or hat samples during performance. Files are detected by mouse position and loaded immediately into all track SndBuf arrays, enabling seamless sample experimentation without interrupting loop playback.

## Design Goals

1. **Instant Hot-Swap:** New samples load immediately, next hit uses new sample
2. **Clear Visual Feedback:** Color-coded zones with flash effects on load success/failure
3. **Unobtrusive Placement:** Below loop geometry, doesn't interfere with performance UI
4. **Error Handling:** Invalid files rejected with visual feedback, no crash

## Visual Layout

```
            [SPICE TEXT] [HOT SAUCE ICON]
              [STATE TEXT]

              [LOOP GEOMETRY]

     [KICK]      [SNARE]      [HAT]
   kick.wav    snare.wav    hat.WAV
   LOADED!      LOADED!     LOADED!
```

**Zone Positions:**
- Y = -2.0 (zones)
- Y = -2.5 (text labels)
- X = [-1.5, 0.0, +1.5] (left/center/right)
- Size: 0.4 × 0.4 squares

**Zone Colors (matching drum_sample_recorder.ck):**
- Zone 0 (Kick): Red @(0.9, 0.2, 0.2)
- Zone 1 (Snare): Orange @(1.0, 0.6, 0.1)
- Zone 2 (Hat): Cyan @(0.2, 0.8, 0.9)

## Components

### 1. Visual Elements

```chuck
// Drop zone squares (PhongMaterial for emission)
GMesh drop_zones[3];
PhongMaterial drop_zone_mats[3];

// Text labels below zones
GText zone_labels[3];

// Flash effect state
float zone_flash_intensity[3];  // 0.0 = no flash, 3.0 = bright, -1.0 = error (red)
time zone_flash_start[3];       // For flash timing

// Drag-and-drop detection
GWindow.files() @=> string files[];
string current_sample_names[3];  // Track loaded filenames for display
```

### 2. Setup Code (after existing visualization setup)

```chuck
// === DROP ZONE SETUP ===
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

    // Initialize state
    0.0 => zone_flash_intensity[i];
    now => zone_flash_start[i];
    getFilename(KICK_SAMPLE) => current_sample_names[0];  // Default samples
    getFilename(SNARE_SAMPLE) => current_sample_names[1];
    getFilename(HAT_SAMPLE) => current_sample_names[2];
}
```

## Core Functions

### 1. Mouse Position to Zone Detection

```chuck
fun int detectZoneFromMouse(vec2 mousePos) {
    // Divide screen into thirds based on mouse X position
    GG.windowWidth() => float windowWidth;
    mousePos.x => float mouseX;
    windowWidth / 3.0 => float zoneWidth;

    if(mouseX < zoneWidth) return 0;        // KICK (left third)
    else if(mouseX < zoneWidth * 2.0) return 1;  // SNARE (middle third)
    else return 2;                          // HAT (right third)
}
```

### 2. Filename Extraction Helper

```chuck
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
```

### 3. Sample Loading (Hot-Swap)

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

### 4. Visual Flash Trigger

```chuck
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

## Integration into Visualization Loop

Add to existing `visualizationLoop()` function:

```chuck
fun void visualizationLoop() {
    while(true) {
        GG.nextFrame() => now;

        // [... existing growth system, pulse deformations, etc. ...]

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

        // [... rest of existing visualization loop ...]
    }
}
```

## Technical Details

### Hot-Swap Behavior

**During Playback:**
- Currently scheduled hits continue with old sample
- `playDrumHit()` reads from SndBuf arrays that were just updated
- Next hit (after load completes) automatically uses new sample
- No timing disruption, no audio glitches
- Loop continues seamlessly

**Why It Works:**
- ChucK's `SndBuf.read()` is instant (loads into memory)
- Setting `pos` to `samples()` makes buffer silent until next `0 => pos` trigger
- All NUM_TRACKS arrays updated together (consistency across tracks)

### File Validation

**Supported Formats:**
- WAV, AIFF, raw audio (ChucK's SndBuf supported formats)
- Any sample rate, mono or stereo

**Invalid File Handling:**
- `SndBuf.samples() == 0` indicates load failure
- Red flash + "INVALID FILE" text
- Original sample remains loaded (no disruption)
- Console error message for debugging

### Performance Considerations

**Memory:**
- Each SndBuf reload allocates new buffer
- Old buffer auto-freed by ChucK GC
- NUM_TRACKS=3 means 3 copies per drum type
- Typical sample: ~1MB × 3 tracks × 3 drums = ~9MB total

**Latency:**
- File load: <10ms for typical drum samples (50-500ms duration)
- No perceptible delay during performance
- Flash effect provides feedback during load

## Visual Consistency

**Integration with Existing UI:**
- Zone colors match drum_sample_recorder.ck palette (red/orange/cyan)
- Flash effect similar to hot sauce bottle blinks (emission-based)
- Text style consistent with existing GText elements
- Positioned below loop geometry (doesn't crowd performance area)

**Z-Fighting Prevention:**
- Drop zones at Z=0.0
- Text at Z=0.0 (ChucK's GText always renders on top)
- No overlap with loop geometry or other 3D elements

## Success Criteria

- [ ] Three drop zones visible at bottom, color-coded correctly
- [ ] Mouse position correctly detects left/middle/right zones
- [ ] Valid audio files load instantly and play on next hit
- [ ] Invalid files show red flash + error text without crashing
- [ ] Text labels show filename + "LOADED!" after successful drop
- [ ] Currently playing loops continue without interruption during load
- [ ] Works with all audio formats supported by ChucK SndBuf

## Future Enhancements (Optional)

- Undo/redo for sample changes
- Save/load sample sets (presets)
- Visual waveform preview in zones
- Drag sample from one zone to another to copy
- Folder drop to batch-load samples
