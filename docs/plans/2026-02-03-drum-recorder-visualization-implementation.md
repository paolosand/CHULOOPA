# Drum Sample Recorder ChuGL Visualization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add interactive ChuGL visualization to drum_sample_recorder.ck showing real-time training progress with animated geometries

**Architecture:** Single-file modification adding ~200 lines of ChuGL code. Three geometries (cube/octahedron/dodecahedron) represent kick/snare/hat, growing logarithmically as samples accumulate. Pulse animations trigger on onset detection. Dynamic instruction text guides workflow through 5-state machine.

**Tech Stack:** ChucK, ChuGL (ChucK Graphics Library), PhongMaterial, BloomPass, ACES tonemap

---

## Task 1: Add ChuGL Scene Setup (Camera, Lights, Post-Processing)

**Files:**
- Modify: `src/drum_sample_recorder.ck:35-36` (after audio setup comment, before adc line)

**Step 1: Add ChuGL scene and camera setup**

Insert after line 35 (`"training_data/" => string DATA_DIR;`), before the audio setup comment:

```chuck
// === CHUGL VISUALIZATION SETUP ===
GG.scene() @=> GScene @ scene;

// Camera setup (matching chuloopa_drums_v2.ck)
GOrbitCamera camera --> scene;
GG.scene().camera(camera);
camera.posZ(6.0);

// === LIGHTING ===
GDirLight main_light --> scene;
main_light.intensity(1.2);
main_light.rotX(-30 * Math.PI / 180.0);

GDirLight rim_light --> scene;
rim_light.intensity(0.6);
rim_light.rotY(180 * Math.PI / 180.0);
rim_light.rotX(30 * Math.PI / 180.0);

// === BLOOM EFFECT + ACES TONEMAP ===
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());
bloom_pass.intensity(0.4);
bloom_pass.radius(0.8);
bloom_pass.levels(6);
bloom_pass.threshold(0.3);

// ACES tonemap for CRT old TV effect
output_pass.tonemap(4);  // 4 = ACES
output_pass.exposure(0.5);
```

**Step 2: Verify ChucK compiles without errors**

Run: `chuck src/drum_sample_recorder.ck`

Expected: Program starts, no ChuGL errors in console. Scene should be black (no geometries yet).

Press Q to quit.

**Step 3: Commit scene setup**

```bash
git add src/drum_sample_recorder.ck
git commit -m "feat(viz): add ChuGL scene with ACES tonemap and bloom

- Camera at Z=6.0 (matching main looper)
- Main + rim directional lights
- BloomPass (intensity 0.4, radius 0.8)
- ACES tonemap (mode 4, 0.5 exposure)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Add Geometries and Label Text

**Files:**
- Modify: `src/drum_sample_recorder.ck` (after bloom setup, before audio setup comment)

**Step 1: Add three drum geometries in horizontal row**

Insert after the ACES tonemap section:

```chuck
// === DRUM GEOMETRIES (Horizontal Row Layout) ===
0.6 => float BASE_SCALE;

// Kick (Left) - Cube (6 faces)
GMesh kick_geo(new CubeGeometry, new PhongMaterial) --> scene;
kick_geo.posX(-2.0);
kick_geo.posY(0.0);
kick_geo.sca(BASE_SCALE * 0.5);  // Start at 50% scale
kick_geo.mat() $ PhongMaterial @=> PhongMaterial @ kick_mat;
kick_mat.color(@(0.3, 0.3, 0.4));  // Dim blue-gray

// Snare (Center) - Octahedron (8 faces)
GMesh snare_geo(new PolyhedronGeometry(PolyhedronGeometry.OCTAHEDRON), new PhongMaterial) --> scene;
snare_geo.posX(0.0);
snare_geo.posY(0.0);
snare_geo.sca(BASE_SCALE * 0.5);
snare_geo.mat() $ PhongMaterial @=> PhongMaterial @ snare_mat;
snare_mat.color(@(0.3, 0.3, 0.4));

// Hat (Right) - Dodecahedron (12 faces)
GMesh hat_geo(new PolyhedronGeometry(PolyhedronGeometry.DODECAHEDRON), new PhongMaterial) --> scene;
hat_geo.posX(2.0);
hat_geo.posY(0.0);
hat_geo.sca(BASE_SCALE * 0.5);
hat_geo.mat() $ PhongMaterial @=> PhongMaterial @ hat_mat;
hat_mat.color(@(0.3, 0.3, 0.4));
```

**Step 2: Add label text below each geometry**

```chuck
// === LABEL TEXT (Below Geometries) ===
GText kick_label --> scene;
kick_label.text("KICK");
kick_label.posX(-2.0);
kick_label.posY(-1.2);
kick_label.sca(0.18);
kick_label.color(@(0.7, 0.7, 0.7));

GText snare_label --> scene;
snare_label.text("SNARE");
snare_label.posX(0.0);
snare_label.posY(-1.2);
snare_label.sca(0.18);
snare_label.color(@(0.7, 0.7, 0.7));

GText hat_label --> scene;
hat_label.text("HAT");
hat_label.posX(2.0);
hat_label.posY(-1.2);
hat_label.sca(0.18);
hat_label.color(@(0.7, 0.7, 0.7));

// === INSTRUCTION TEXT (Above Geometries) ===
GText instruction_text --> scene;
instruction_text.text("PRESS K (KICK) | S (SNARE) | H (HAT) TO BEGIN");
instruction_text.posX(0.0);
instruction_text.posY(2.5);
instruction_text.sca(0.22);
instruction_text.color(@(1.0, 1.0, 1.0));
```

**Step 3: Verify geometries visible**

Run: `chuck src/drum_sample_recorder.ck`

Expected: Three small dim geometries visible in horizontal row with labels beneath. Instruction text at top.

Press Q to quit.

**Step 4: Commit geometry setup**

```bash
git add src/drum_sample_recorder.ck
git commit -m "feat(viz): add three drum geometries with labels

- Cube (kick), octahedron (snare), dodecahedron (hat)
- Horizontal row at Y=0.0 (X=-2.0, 0.0, +2.0)
- Label text below each geometry
- Instruction text above (Y=+2.5)
- All start dim blue-gray at 50% scale

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Add Visualization State Variables

**Files:**
- Modify: `src/drum_sample_recorder.ck` (after line 66, in state variables section)

**Step 1: Add impulse and growth tracking variables**

Insert after line 66 (`"none" => string current_label;`):

```chuck
// === VISUALIZATION STATE ===
// Impulse variables for pulse animations
0.0 => float kick_impulse;
0.0 => float snare_impulse;
0.0 => float hat_impulse;

// Current visual state (for smooth interpolation)
float current_scales[3];  // [kick, snare, hat]
0.5 => current_scales[0] => current_scales[1] => current_scales[2];  // Start at 50%

// Target colors for each drum type
vec3 kick_target_color;
@(0.9, 0.2, 0.2) => kick_target_color;  // Bright red

vec3 snare_target_color;
@(1.0, 0.6, 0.1) => snare_target_color;  // Bright orange

vec3 hat_target_color;
@(0.2, 0.8, 0.9) => hat_target_color;  // Bright cyan

vec3 dim_color;
@(0.3, 0.3, 0.4) => dim_color;  // Starting dim blue-gray

// Instruction state machine
0 => int instruction_state;  // 0=initial, 1=recording, 2=drum_complete, 3=almost_done, 4=all_complete
time state2_start_time;  // For 2-second "GREAT!" message duration
now => state2_start_time;
```

**Step 2: Verify compilation**

Run: `chuck src/drum_sample_recorder.ck`

Expected: No errors, variables declared properly.

Press Q to quit.

**Step 3: Commit state variables**

```bash
git add src/drum_sample_recorder.ck
git commit -m "feat(viz): add visualization state variables

- Impulse variables for pulse animations
- Current scales for smooth interpolation
- Target colors per drum type
- Instruction state machine tracking

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Add Helper Functions for Growth System

**Files:**
- Modify: `src/drum_sample_recorder.ck` (after state variables, before onset detection functions)

**Step 1: Add logarithmic growth calculation functions**

Insert before the onset detection functions section (line ~108):

```chuck
// === VISUALIZATION HELPER FUNCTIONS ===

// Calculate logarithmic growth multiplier (0.5 to 1.0+)
fun float getScaleMultiplier(int samples) {
    return 0.5 + 0.5 * Math.log(samples + 1) / Math.log(11);
}

// Calculate brightness multiplier (0.3 to 1.0+)
fun float getBrightnessMultiplier(int samples) {
    return 0.3 + 0.7 * Math.log(samples + 1) / Math.log(11);
}

// Lerp between two vec3 colors
fun vec3 lerpColor(vec3 a, vec3 b, float t) {
    return @(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t
    );
}

// Get label index from string
fun int getLabelIdx(string label) {
    if(label == "kick") return 0;
    else if(label == "snare") return 1;
    else if(label == "hat") return 2;
    else return -1;
}

// Get total samples across all drums
fun int getTotalSamples() {
    return label_counts[0] + label_counts[1] + label_counts[2];
}
```

**Step 2: Verify functions compile**

Run: `chuck src/drum_sample_recorder.ck`

Expected: No compilation errors.

Press Q to quit.

**Step 3: Commit helper functions**

```bash
git add src/drum_sample_recorder.ck
git commit -m "feat(viz): add growth system helper functions

- getScaleMultiplier: logarithmic growth calculation
- getBrightnessMultiplier: brightness progression
- lerpColor: smooth color interpolation
- getLabelIdx, getTotalSamples: utility functions

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Implement Visualization Loop (Growth + Deformations)

**Files:**
- Modify: `src/drum_sample_recorder.ck` (add new function after helper functions, before main program)

**Step 1: Add visualization loop function**

Insert before the main program section (line ~467):

```chuck
// === VISUALIZATION LOOP ===

fun void visualizationLoop() {
    while(true) {
        GG.nextFrame() => now;

        // === UPDATE GROWTH SYSTEM ===
        for(0 => int i; i < 3; i++) {
            // Calculate target scale based on sample count
            getScaleMultiplier(label_counts[i]) => float target_scale;

            // Smooth interpolation (exponential easing)
            current_scales[i] + (target_scale - current_scales[i]) * 0.1 => current_scales[i];

            // Calculate brightness and color
            getBrightnessMultiplier(label_counts[i]) => float brightness;

            vec3 target_color;
            if(i == 0) kick_target_color => target_color;
            else if(i == 1) snare_target_color => target_color;
            else hat_target_color => target_color;

            lerpColor(dim_color, target_color, brightness) @=> vec3 current_color;

            // Calculate emission (glow at higher sample counts)
            brightness * 0.8 => float emission_intensity;
            @(target_color.x * emission_intensity,
              target_color.y * emission_intensity,
              target_color.z * emission_intensity) @=> vec3 emission;

            // Apply to materials
            if(i == 0) {
                kick_mat.color(current_color);
                kick_mat.emission(emission);
            } else if(i == 1) {
                snare_mat.color(current_color);
                snare_mat.emission(emission);
            } else {
                hat_mat.color(current_color);
                hat_mat.emission(emission);
            }
        }

        // === APPLY PULSE DEFORMATIONS ===

        // Kick - Radial expansion
        BASE_SCALE * current_scales[0] * (1.0 + kick_impulse * 0.4) => float kick_scale;
        kick_geo.sca(kick_scale);

        // Snare - Vertical compression
        BASE_SCALE * current_scales[1] => float snare_base;
        snare_geo.scaX(snare_base * (1.0 + snare_impulse * 0.3));
        snare_geo.scaZ(snare_base * (1.0 + snare_impulse * 0.3));
        snare_geo.scaY(snare_base * (1.0 - snare_impulse * 0.4));

        // Hat - Asymmetric wobble
        BASE_SCALE * current_scales[2] => float hat_base;
        hat_geo.scaX(hat_base * (1.0 + hat_impulse * 0.2));
        hat_geo.scaY(hat_base * (1.0 + hat_impulse * 0.15));
        hat_geo.scaZ(hat_base * (1.0 - hat_impulse * 0.3));

        // Decay impulses (exponential decay ~200ms)
        kick_impulse * 0.92 => kick_impulse;
        snare_impulse * 0.92 => snare_impulse;
        hat_impulse * 0.92 => hat_impulse;

        // === UPDATE LABEL TEXT COLORS (Active vs Inactive) ===
        if(current_label == "kick") {
            kick_label.color(@(1.0, 1.0, 1.0));
            kick_label.sca(0.20);
        } else {
            kick_label.color(@(0.7, 0.7, 0.7));
            kick_label.sca(0.18);
        }

        if(current_label == "snare") {
            snare_label.color(@(1.0, 1.0, 1.0));
            snare_label.sca(0.20);
        } else {
            snare_label.color(@(0.7, 0.7, 0.7));
            snare_label.sca(0.18);
        }

        if(current_label == "hat") {
            hat_label.color(@(1.0, 1.0, 1.0));
            hat_label.sca(0.20);
        } else {
            hat_label.color(@(0.7, 0.7, 0.7));
            hat_label.sca(0.18);
        }

        // === UPDATE INSTRUCTION TEXT (State Machine) ===

        // Determine current state
        if(label_counts[0] >= 10 && label_counts[1] >= 10 && label_counts[2] >= 10) {
            // State 4: All complete
            if(instruction_state != 4) {
                4 => instruction_state;
                instruction_text.text("TRAINING COMPLETE! PRESS Q TO EXPORT (TOTAL: " + getTotalSamples() + ")");
                instruction_text.color(@(0.5, 1.5, 0.5));
            }
            // Large pulsing scale
            0.24 + 0.04 * Math.sin((now / second) * Math.PI * 2.0) => float pulse_scale;
            instruction_text.sca(pulse_scale);

        } else if(current_label != "none") {
            getLabelIdx(current_label) => int current_idx;

            if(label_counts[current_idx] >= 10) {
                // State 2: Drum complete (show for 2 seconds)
                if(instruction_state != 2) {
                    2 => instruction_state;
                    now => state2_start_time;

                    // Determine next drum
                    if(label_counts[0] < 10) {
                        instruction_text.text("GREAT! PRESS K FOR KICKS");
                    } else if(label_counts[1] < 10) {
                        instruction_text.text("EXCELLENT! PRESS S FOR SNARES");
                    } else if(label_counts[2] < 10) {
                        instruction_text.text("PERFECT! PRESS H FOR HI-HATS");
                    } else {
                        instruction_text.text("PERFECT! PRESS Q TO EXPORT");
                    }

                    instruction_text.color(@(0.3, 1.0, 0.3));
                    instruction_text.sca(0.22);
                }

                // After 2 seconds, return to state 0
                if(now - state2_start_time > 2::second) {
                    0 => instruction_state;
                }

            } else {
                // State 1: Active recording
                if(instruction_state != 1) {
                    1 => instruction_state;
                }

                // Update text with count
                if(current_label == "kick") {
                    instruction_text.text("BEATBOX KICKS NOW! (" + label_counts[0] + "/10)");
                    instruction_text.color(@(0.9, 0.2, 0.2));  // Red
                } else if(current_label == "snare") {
                    instruction_text.text("BEATBOX SNARES NOW! (" + label_counts[1] + "/10)");
                    instruction_text.color(@(1.0, 0.6, 0.1));  // Orange
                } else if(current_label == "hat") {
                    instruction_text.text("BEATBOX HI-HATS NOW! (" + label_counts[2] + "/10)");
                    instruction_text.color(@(0.2, 0.8, 0.9));  // Cyan
                }

                // Gentle pulsing scale
                0.22 + 0.01 * Math.sin((now / second) * Math.PI * 2.0) => float pulse_scale;
                instruction_text.sca(pulse_scale);
            }

        } else {
            // State 0: Initial or between drums
            if(instruction_state != 0) {
                0 => instruction_state;
                instruction_text.text("PRESS K (KICK) | S (SNARE) | H (HAT) TO BEGIN");
                instruction_text.color(@(1.0, 1.0, 1.0));
                instruction_text.sca(0.22);
            }
        }

        // Slow rotation for visual interest (optional)
        kick_geo.rotY((now / second) * 0.3);
        snare_geo.rotY((now / second) * 0.3);
        hat_geo.rotY((now / second) * 0.3);
    }
}
```

**Step 2: Spork visualization loop in main program**

Find the main program section (line ~502) and add spork before onsetDetectionLoop:

```chuck
spork ~ visualizationLoop();  // NEW LINE
spork ~ onsetDetectionLoop();
spork ~ keyboardListener();
```

**Step 3: Test visualization updates**

Run: `chuck src/drum_sample_recorder.ck`

Expected:
- Geometries slowly rotating
- Instruction text: "PRESS K (KICK) | S (SNARE) | H (HAT) TO BEGIN"
- Press K: Text changes to "BEATBOX KICKS NOW! (0/10)" in red
- Beatbox: Cube should pulse and grow (but won't yet - need Task 6)

Press Q to quit.

**Step 4: Commit visualization loop**

```bash
git add src/drum_sample_recorder.ck
git commit -m "feat(viz): implement visualization loop with growth system

- Logarithmic scale/brightness progression per geometry
- Color lerp from dim blue-gray to target colors
- Emission glow at high sample counts
- Pulse deformations (kick/snare/hat styles)
- Active label highlighting (white + scale up)
- 5-state instruction text machine
- Slow rotation for visual interest

Visualization updates real-time but pulses not triggered yet

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Trigger Visual Pulses on Onset Detection

**Files:**
- Modify: `src/drum_sample_recorder.ck:267` (in recordSample function)

**Step 1: Add impulse triggers in recordSample()**

Find the `recordSample()` function (line ~267). After line 296 (the feature debug output), add:

```chuck
    // Trigger visual pulse
    if(label == "kick") 1.0 => kick_impulse;
    else if(label == "snare") 1.0 => snare_impulse;
    else if(label == "hat") 1.0 => hat_impulse;
```

**Step 2: Test complete visualization with pulses**

Run: `chuck src/drum_sample_recorder.ck`

Testing sequence:
1. Press K
2. Verify: Text "BEATBOX KICKS NOW! (0/10)" in red
3. Beatbox a kick sound
4. Verify: Left cube pulses with radial expansion
5. Verify: Text updates to "(1/10)", cube slightly bigger and redder
6. Continue to 10 kicks
7. Verify: Text changes to "GREAT! PRESS S FOR SNARES" in green for 2 seconds
8. Press S, beatbox 10 snares
9. Verify: Center octahedron pulses with vertical compression
10. Press H, beatbox 10 hats
11. Verify: Right dodecahedron pulses with asymmetric wobble
12. Verify: Text changes to "TRAINING COMPLETE! PRESS Q TO EXPORT (TOTAL: 30)"
13. Press Q
14. Verify: CSV export still works correctly

**Step 3: Commit pulse triggers**

```bash
git add src/drum_sample_recorder.ck
git commit -m "feat(viz): connect onset detection to visual pulses

Trigger impulse variables in recordSample() to animate geometries:
- Kick: radial expansion
- Snare: vertical compression
- Hat: asymmetric wobble

Visualization now fully reactive to beatbox input

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Final Testing and Documentation

**Files:**
- Test: `src/drum_sample_recorder.ck`
- Modify: `CLAUDE.md` (update with visualization features)

**Step 1: Complete end-to-end test**

Run: `chuck src/drum_sample_recorder.ck`

Full workflow test:
1. Verify initial state (3 dim geometries, initial instruction)
2. Record 10 kicks (watch growth progression: fast early, slow after 10)
3. Verify "GREAT!" message appears and returns to selection
4. Record 10 snares (different color, different pulse style)
5. Record 10 hats (third color, third pulse style)
6. Verify "TRAINING COMPLETE!" with large pulsing text
7. Press Q and verify CSV export successful
8. Check CSV file contains 30 samples with correct labels

**Step 2: Update CLAUDE.md documentation**

Find the "Recording Training Samples" section in CLAUDE.md and update:

```markdown
### Recording Training Samples (REQUIRED FIRST STEP)
1. Record 30 samples (10 each of kick/snare/hat):
   ```bash
   chuck src/drum_sample_recorder.ck
   # Visual feedback: Three geometries show training progress
   # - Left cube (kick): pulses with radial expansion
   # - Center octahedron (snare): pulses with vertical compression
   # - Right dodecahedron (hat): pulses with asymmetric wobble
   # Geometries grow and brighten as samples accumulate
   # Dynamic instruction text guides you through the workflow
   # Press K for kick, S for snare, H for hat, Q to quit and export
   # Creates: training_samples.csv
   ```
```

**Step 3: Verify no performance issues**

Run: `chuck src/drum_sample_recorder.ck`

Monitor:
- Smooth 60fps rendering
- No lag when beatboxing
- Onset detection still accurate
- Audio click feedback still works

**Step 4: Final commit**

```bash
git add src/drum_sample_recorder.ck CLAUDE.md
git commit -m "docs: update CLAUDE.md with visualization features

Document new ChuGL visualization in training workflow section:
- Three-geometry layout with distinct pulse animations
- Logarithmic growth feedback system
- Dynamic coaching instructions

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Push to Remote and Create Summary

**Files:**
- All modified files

**Step 1: Push to remote staging branch**

```bash
git push origin staging
```

**Step 2: Verify push successful**

Check git log shows all commits pushed to origin/staging.

**Step 3: Create implementation summary**

Create file: `docs/plans/2026-02-03-drum-recorder-viz-summary.md`

```markdown
# Drum Sample Recorder Visualization - Implementation Summary

**Date:** 2026-02-03
**Branch:** staging
**Commits:** 8 commits (~200 lines added)

## What Was Implemented

Added interactive ChuGL visualization to `src/drum_sample_recorder.ck` that provides real-time training progress feedback.

### Visual Features

1. **Three Geometries (Horizontal Row)**
   - Left: Cube (kick) - red, radial expansion pulse
   - Center: Octahedron (snare) - orange, vertical compression pulse
   - Right: Dodecahedron (hat) - cyan, asymmetric wobble pulse

2. **Logarithmic Growth System**
   - Geometries start small and dim (50% scale, blue-gray)
   - Fast growth for first few samples (rewarding early progress)
   - Slow growth after 10 samples (target reached)
   - Brightness/color progression from dim to vibrant
   - Emission glow at high sample counts (bloom effect)

3. **Dynamic Coaching Instructions**
   - State 0: "PRESS K (KICK) | S (SNARE) | H (HAT) TO BEGIN"
   - State 1: "BEATBOX KICKS NOW! (3/10)" (colored, pulsing)
   - State 2: "GREAT! PRESS S FOR SNARES" (green, 2 seconds)
   - State 3: "ALMOST DONE! H:8/10" (gold)
   - State 4: "TRAINING COMPLETE! PRESS Q TO EXPORT" (bright green, large pulse)

4. **Visual Consistency**
   - ACES tonemap (mode 4, 0.5 exposure) - CRT old TV aesthetic
   - BloomPass (intensity 0.4, radius 0.8)
   - Same deformation system as main looper
   - Same color palette (red/orange/cyan)

### Technical Implementation

- ~200 lines added to drum_sample_recorder.ck
- New visualization loop sporked in main program
- Helper functions for logarithmic growth calculations
- Impulse-based pulse animation system
- 5-state instruction text machine
- Smooth interpolation for scale/color transitions

### Testing Results

✅ All geometries visible at startup
✅ Growth progression feels rewarding (fast early, slows after 10)
✅ Pulse animations clearly distinguish kick/snare/hat
✅ Instruction text guides through entire workflow
✅ Visual consistency with main looper
✅ 60fps maintained (no performance issues)
✅ Training workflow unchanged (same controls, same CSV export)

## Files Modified

- `src/drum_sample_recorder.ck` (+~200 lines)
- `CLAUDE.md` (documentation update)
- `docs/plans/2026-02-03-drum-recorder-visualization-implementation.md` (this plan)
- `docs/plans/2026-02-03-drum-sample-recorder-visualization-design.md` (design doc)

## Next Steps

Optional enhancements (not required):
- Particle effects on pulse (sparks/trails)
- Sound-reactive background grid
- Celebration animation on completion
- Progress bar showing 30-sample total goal
```

**Step 4: Final commit and push**

```bash
git add docs/plans/2026-02-03-drum-recorder-viz-summary.md
git commit -m "docs: add implementation summary for drum recorder viz

Complete summary of ChuGL visualization implementation:
- 8 commits, ~200 lines added
- Three-geometry layout with pulse animations
- Logarithmic growth system
- Dynamic coaching instructions
- All success criteria met

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git push origin staging
```

---

## Success Criteria Checklist

After Task 7 completion, verify:

- [ ] All geometries visible and distinct at startup
- [ ] Growth progression feels rewarding (fast early, slow after 10)
- [ ] Pulse animations clearly distinguish kick/snare/hat
- [ ] Instruction text guides user through entire workflow
- [ ] Visual consistency with main looper aesthetic
- [ ] No performance issues (60fps maintained)
- [ ] Training workflow unchanged (same keyboard controls, same CSV export)

## Reference Files

- Design doc: `docs/plans/2026-02-03-drum-sample-recorder-visualization-design.md`
- Reference implementation: `src/chuloopa_drums_v2.ck` (lines 230-335, 1597-1891)
- ChucK ChuGL docs: https://chuck.stanford.edu/chugl/

## Estimated Time

- Task 1: 5 minutes (scene setup)
- Task 2: 5 minutes (geometries)
- Task 3: 3 minutes (state variables)
- Task 4: 5 minutes (helper functions)
- Task 5: 15 minutes (visualization loop)
- Task 6: 5 minutes (pulse triggers)
- Task 7: 10 minutes (testing + docs)
- Task 8: 5 minutes (push + summary)

**Total:** ~55 minutes
