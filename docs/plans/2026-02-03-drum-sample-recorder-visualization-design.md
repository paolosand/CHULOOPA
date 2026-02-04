# Drum Sample Recorder ChuGL Visualization Design

**Date:** 2026-02-03
**Target File:** `src/drum_sample_recorder.ck`
**Purpose:** Add interactive ChuGL visualization to training data collection tool

## Overview

Add visual feedback to the drum sample recorder that shows real-time training progress through animated geometries. Each drum type (kick, snare, hat) has its own geometry that pulses on detection and grows as samples accumulate. Dynamic coaching instructions guide users through the 5-minute training workflow.

## Design Goals

1. **Clear Progress Feedback:** Visual growth shows how many samples collected per drum type
2. **Immediate Hit Feedback:** Distinct pulse animations for each drum type reinforce classification
3. **Guided Workflow:** Coaching text eliminates confusion about what to do next
4. **Visual Consistency:** Match ACES tonemap and bloom aesthetic from main looper

## Section 1: Visual Layout & Geometry Setup

### Scene Configuration
- **Camera:** GOrbitCamera at Z=6.0 (matching chuloopa_drums_v2.ck)
- **Lighting:**
  - Main directional light (intensity 1.2, rotX -30°)
  - Rim light (intensity 0.6, rotY 180°, rotX 30°)
- **Post-processing:**
  - BloomPass (intensity 0.4, radius 0.8, threshold 0.3)
  - ACES tonemap (mode 4) with 0.5 exposure
  - Creates CRT old TV aesthetic matching main looper

### Horizontal Row Layout

Three geometries arranged in horizontal row at Y=0.0:

```
        [Dynamic Instructions Y=+2.5]

   [CUBE]      [OCTAHEDRON]    [DODECAHEDRON]
   X=-2.0         X=0.0            X=+2.0

    KICK          SNARE             HAT
  Y=-1.2         Y=-1.2           Y=-1.2
```

**Geometry Specifications:**
- **Kick (Left):** `GCube` (6 faces), base scale 0.6
- **Snare (Center):** `GPolyhedron(OCTAHEDRON)` (8 faces), base scale 0.6
- **Hat (Right):** `GPolyhedron(DODECAHEDRON)` (12 faces), base scale 0.6

All geometries use `PhongMaterial` for proper lighting and emission support.

**Label Text:**
- Three `GText` objects below each geometry (Y=-1.2)
- Text: "KICK", "SNARE", "HAT"
- Font scale: 0.18
- Default color: Light gray @(0.7, 0.7, 0.7)
- Active label: White @(1.0, 1.0, 1.0) + slight scale increase to 0.20

**Instruction Text:**
- Single `GText` at Y=+2.5, X=0.0
- Font scale: 0.22 (larger for readability)
- Dynamic color and content (see Section 4)

## Section 2: Growth & Brightness System

### Logarithmic Progression

**Goal:** Fast early rewards that slow after 10 samples (target), encouraging completion without feeling endless.

**Starting State (0 samples):**
- Scale: 0.5 × base_scale = 0.3 units
- Color: Dim blue-gray @(0.3, 0.3, 0.4)
- Emission: 0.0

**Growth Formula:**
```chuck
// Applied per geometry based on its label_counts[i]
scale_multiplier = 0.5 + 0.5 * Math.log(samples + 1) / Math.log(11);
brightness_multiplier = 0.3 + 0.7 * Math.log(samples + 1) / Math.log(11);
```

**Progression Table:**

| Samples | Scale Mult | Brightness | Visual Feel |
|---------|-----------|------------|-------------|
| 0       | 0.50      | 0.30       | Tiny, dim |
| 1       | 0.73      | 0.51       | Fast growth! |
| 5       | 0.90      | 0.72       | Good progress |
| 10      | 1.00      | 1.00       | Target reached, full size |
| 15      | 1.04      | 1.03       | Minimal change |
| 20      | 1.06      | 1.05       | Nearly flat |

**Color Progression by Drum:**

Each geometry lerps from dim blue-gray to its target color:

- **Kick (Cube):** @(0.3, 0.3, 0.4) → @(0.9, 0.2, 0.2) (bright red)
- **Snare (Octahedron):** @(0.3, 0.3, 0.4) → @(1.0, 0.6, 0.1) (bright orange)
- **Hat (Dodecahedron):** @(0.3, 0.3, 0.4) → @(0.2, 0.8, 0.9) (bright cyan)

**Emission (Glow):**
```chuck
emission_intensity = brightness_multiplier * 0.8;
emission_color = target_color * emission_intensity;
```

At 10+ samples, emission creates satisfying glow via bloom pass.

**Real-time Updates:**
Visualization loop checks `label_counts[]` array every frame, smoothly interpolates toward target:
```chuck
current_scale += (target_scale - current_scale) * 0.1;  // Exponential easing
```

## Section 3: Drum Hit Pulse Animations

### Matched Deformation System

Reuses deformation patterns from `chuloopa_drums_v2.ck` to create visual consistency.

**Impulse Variables:**
```chuck
0.0 => float kick_impulse => float snare_impulse => float hat_impulse;
```

Set to 1.0 when onset detected with that label, decay exponentially:
```chuck
kick_impulse *= 0.92;  // ~200ms decay to near-zero
```

### Deformation Styles

**Kick (Cube) - Radial Expansion:**
```chuck
float pulse_scale = base_scale * (1.0 + kick_impulse * 0.4);
cube.sca(pulse_scale);
```
Uniform expansion in all directions. Punchy, explosive feel.

**Snare (Octahedron) - Vertical Compression:**
```chuck
float horizontal_scale = base_scale * (1.0 + snare_impulse * 0.3);
float vertical_scale = base_scale * (1.0 - snare_impulse * 0.4);
octahedron.scaX(horizontal_scale);
octahedron.scaZ(horizontal_scale);
octahedron.scaY(vertical_scale);
```
Squashes down, expands outward. Sharp, snappy motion.

**Hat (Dodecahedron) - Asymmetric Wobble:**
```chuck
dodecahedron.scaX(base_scale * (1.0 + hat_impulse * 0.2));
dodecahedron.scaY(base_scale * (1.0 + hat_impulse * 0.15));
dodecahedron.scaZ(base_scale * (1.0 - hat_impulse * 0.3));
```
Diagonal stretch forward. Quick, jittery feel.

### Trigger Integration

In `recordSample()` function (line ~267), after successful recording:
```chuck
// Trigger visual pulse
if(label == "kick") 1.0 => kick_impulse;
else if(label == "snare") 1.0 => snare_impulse;
else if(label == "hat") 1.0 => hat_impulse;
```

**Stacking Behavior:** Deformations apply on top of growth system. A 5-sample kick has 90% grown size, THEN radial pulse on top.

## Section 4: Dynamic Coaching Instructions

### Instruction State Machine

The instruction text adapts to training progress, providing clear next steps.

**State 1: Initial (no label selected)**
```
Text: "PRESS K (KICK) | S (SNARE) | H (HAT) TO BEGIN"
Color: White @(1.0, 1.0, 1.0)
Scale: 0.22
```

**State 2: Active Recording (label selected, < 10 samples)**
```
Text: "BEATBOX KICKS NOW! (3/10)"
      "BEATBOX SNARES NOW! (7/10)"
      "BEATBOX HI-HATS NOW! (2/10)"
Color: Drum-specific (red/orange/cyan)
Scale: 0.22 + 0.01 * sin(now) (gentle pulse)
```

**State 3: Drum Complete (just hit 10 samples)**
```
Text: "GREAT! PRESS S FOR SNARES"
      "EXCELLENT! PRESS H FOR HI-HATS"
      "PERFECT! PRESS Q TO EXPORT"
Color: Green @(0.3, 1.0, 0.3)
Duration: 2 seconds, then return to State 1
```

**State 4: Almost Complete (2/3 drums done, working on last)**
```
Text: "ALMOST DONE! H:8/10"
Color: Gold @(1.0, 0.8, 0.2)
Scale: 0.22
```

**State 5: All Complete (all drums ≥ 10)**
```
Text: "TRAINING COMPLETE! PRESS Q TO EXPORT (TOTAL: 32)"
Color: Bright green @(0.5, 1.5, 0.5) with emission
Scale: 0.24 + 0.04 * sin(now) (large pulse)
```

### State Transition Logic

Check every frame in visualization loop:
```chuck
// Determine state
if(label_counts[0] >= 10 && label_counts[1] >= 10 && label_counts[2] >= 10) {
    // State 5: All complete
} else if(current_label != "none" && label_counts[getLabelIdx(current_label)] >= 10) {
    // State 3: Just completed current drum
    now => state3_start_time;
} else if(current_label != "none") {
    // State 2: Active recording
} else if(getTotalSamples() == 0) {
    // State 1: Initial
} else {
    // State 4: Between drums, or State 1 if just one drum left
}
```

## Implementation Notes

### Code Structure

1. **Visualization Setup (after line 35):**
   - Add ChuGL imports and scene setup
   - Create camera, lights, bloom, tonemap
   - Instantiate geometries and text objects

2. **State Variables (after line 66):**
   - Add impulse variables (kick_impulse, snare_impulse, hat_impulse)
   - Add growth tracking (current_scale[], current_color[][])
   - Add instruction state tracking

3. **Visualization Loop (new sporked shred):**
   - Update growth system (check label_counts, lerp scales/colors)
   - Apply deformations (read impulses, apply per-geometry transforms)
   - Decay impulses (multiply by 0.92 each frame)
   - Update instruction text (check state, set text/color)
   - Rotate geometries slowly for visual interest (optional)
   - `GG.nextFrame() => now;`

4. **Trigger Integration (in recordSample()):**
   - After storing sample, set corresponding impulse to 1.0
   - Keep existing audio click feedback

### File Organization

Existing file is 508 lines. ChuGL addition will add ~200 lines:
- ~60 lines: Scene setup
- ~40 lines: State variables
- ~100 lines: Visualization loop function

Total: ~700 lines (still manageable for single file)

### Testing Workflow

1. Run recorder: `chuck src/drum_sample_recorder.ck`
2. Press K - verify "BEATBOX KICKS NOW!" appears, left cube activates
3. Beatbox - verify cube pulses and grows with each sample
4. Hit 10 kicks - verify "GREAT! PRESS S" message
5. Repeat for S and H
6. Verify final "TRAINING COMPLETE!" state
7. Press Q - verify export still works

## Visual Aesthetic Alignment

**Consistency with chuloopa_drums_v2.ck:**
- Same ACES tonemap (mode 4, 0.5 exposure)
- Same bloom parameters (intensity 0.4, radius 0.8)
- Same deformation system (matched animations)
- Same color palette (red kick, orange snare, cyan hat)

**Differences (appropriate for training context):**
- Three geometries instead of one (multi-class visualization)
- Static positions instead of dynamic (focus on growth, not spice)
- No hot sauce bottle (not needed for training)
- Coaching text instead of state labels (instructional vs. informational)

## Success Criteria

- [ ] All geometries visible and distinct at startup
- [ ] Growth progression feels rewarding (fast early, slow after 10)
- [ ] Pulse animations clearly distinguish kick/snare/hat
- [ ] Instruction text guides user through entire workflow
- [ ] Visual consistency with main looper aesthetic
- [ ] No performance issues (60fps maintained)
- [ ] Training workflow unchanged (same keyboard controls, same CSV export)

## Future Enhancements (Optional)

- Particle effects on pulse (sparks/trails for extra juice)
- Sound-reactive background grid (like chuloopa_drums_v2)
- Celebration animation on completion (geometry dance?)
- Progress bar showing 30-sample total goal
