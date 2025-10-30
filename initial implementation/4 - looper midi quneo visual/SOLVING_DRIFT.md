# Solving Loop Drift in Multi-Track Loopers

## The Problem

When multiple audio loops are recorded freeform (without tempo constraints), they will inevitably have slightly different lengths. Over time, these small differences compound, causing loops to drift out of sync with each other.

**Example:**

- Track 0: 3.203 seconds
- Track 1: 6.411 seconds (intended to be 2× Track 0)
- After 10 cycles: ~0.05 second drift
- After 100 cycles: ~0.5 second drift (very noticeable!)

This document describes various techniques to solve this problem **without** forcing the user to record to a specific BPM or metronome.

---

## Solution 1: Master Loop Reference (Recommended)

### Concept

The first recorded loop becomes the "master clock" for all subsequent recordings. New loops are automatically adjusted to be clean integer multiples or divisions of the master loop length.

### How It Works

1. **First loop recorded:** Becomes master reference (any length)
2. **Subsequent loops:** System detects intended relationship to master
3. **Auto-adjustment:** Loop length is adjusted to exact multiple/division

### Implementation Details

```chuck
// Global state
int master_track;
dur master_duration;
0 => int has_master;

// Array of valid multipliers to check (most common ratios)
[0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0] @=> float valid_multipliers[];

fun dur findBestMultiplier(dur recorded_duration, dur master_duration) {
    1000000.0 => float best_error;  // Large initial value
    1.0 => float best_multiplier;

    // Test each multiplier
    for(0 => int i; i < valid_multipliers.size(); i++) {
        valid_multipliers[i] => float mult;
        master_duration * mult => dur target;

        // Calculate absolute error
        Math.fabs((recorded_duration - target) / second) => float error;

        if(error < best_error) {
            error => best_error;
            mult => best_multiplier;
        }
    }

    return master_duration * best_multiplier;
}

fun void stopRecording(int track) {
    // ... existing record stop code ...

    lisa[track].recPos() => recorded_duration[track];

    if(!has_master) {
        // First loop becomes master
        track => master_track;
        recorded_duration[track] => master_duration;
        1 => has_master;
        <<< "Track", track, "is now MASTER loop" >>>;
    } else {
        // Adjust to best fit of master
        findBestMultiplier(recorded_duration[track], master_duration) => dur adjusted;
        adjusted => recorded_duration[track];

        float multiplier = (adjusted / master_duration) $ float;
        <<< "Track", track, "adjusted to", multiplier, "× master length" >>>;
    }

    recorded_duration[track] / second => loop_length[track];

    // ... rest of playback setup ...
}
```

### Pros

- Intuitive: first loop sets the "feel"
- Simple to implement and understand
- Works well for most musical scenarios
- User doesn't need to think about sync

### Cons

- Master loop can't be changed without clearing all
- Limited to predefined multiplier ratios
- If master is very short, longer loops might not fit well

### Best For

- Performance contexts
- Improvisation
- When user naturally records in musical relationships

---

## Solution 2: Longest Loop as Master

### Concept

Similar to Solution 1, but the longest loop is always the master. Shorter loops must divide evenly into it.

### How It Works

1. After each recording, determine which track has the longest loop
2. All other loops are adjusted to divide evenly into the longest
3. If a new longer loop is recorded, recalculate all relationships

### Implementation Details

```chuck
fun void recalculateAllLoops() {
    // Find longest loop
    0::second => dur longest;
    -1 => int longest_track;

    for(0 => int i; i < NUM_TRACKS; i++) {
        if(has_loop[i] && recorded_duration[i] > longest) {
            recorded_duration[i] => longest;
            i => longest_track;
        }
    }

    if(longest_track < 0) return;

    <<< "Master track:", longest_track, "Length:", longest/second, "sec" >>>;

    // Adjust all other loops to divide into longest
    for(0 => int i; i < NUM_TRACKS; i++) {
        if(i == longest_track || !has_loop[i]) continue;

        // Find best divisor (how many times this loop fits in longest)
        (longest / recorded_duration[i]) $ float => float ratio;
        Math.round(ratio) $ int => int divisions;

        if(divisions < 1) 1 => divisions;

        longest / divisions => dur adjusted;
        adjusted => recorded_duration[i];

        // Update LiSa loop points
        0 => lisa[i].play;
        0::second => lisa[i].playPos;
        recorded_duration[i] => lisa[i].loopEnd;
        1 => lisa[i].play;

        <<< "Track", i, "adjusted to fit", divisions, "times in master" >>>;
    }
}

fun void stopRecording(int track) {
    // ... existing record stop code ...

    recalculateAllLoops();  // Recalculate after each recording

    // ... rest of playback setup ...
}
```

### Pros

- Always adapts to accommodate the longest phrase
- No need to designate "first" as special
- Good for building up longer structures

### Cons

- All loops might shift when a new longest loop is recorded
- Can be jarring if existing loops suddenly change
- Computationally more expensive (recalculates all)

### Best For

- Studio/composition work
- Building complex polyrhythms
- When you want maximum flexibility

---

## Solution 3: Greatest Common Divisor (GCD) Adjustment

### Concept

Find a common "beat" length that all loops share, based on the greatest common divisor of their durations. All loops align to this hidden grid.

### How It Works

1. After each recording, calculate GCD of all loop lengths
2. Adjust each loop to nearest multiple of the GCD
3. Creates an invisible "pulse" that all loops lock to

### Implementation Details

```chuck
fun dur gcdDuration(dur a, dur b) {
    // Convert to milliseconds for integer GCD calculation
    (a / ms) $ int => int a_ms;
    (b / ms) $ int => int b_ms;

    // Euclidean algorithm for GCD
    while(b_ms != 0) {
        a_ms % b_ms => int temp;
        b_ms => a_ms;
        temp => b_ms;
    }

    return a_ms::ms;
}

fun dur findCommonPulse() {
    0::second => dur common_pulse;

    // Find GCD of all active loops
    for(0 => int i; i < NUM_TRACKS; i++) {
        if(has_loop[i]) {
            if(common_pulse == 0::second) {
                recorded_duration[i] => common_pulse;
            } else {
                gcdDuration(common_pulse, recorded_duration[i]) => common_pulse;
            }
        }
    }

    // Ensure pulse is reasonable (not too small)
    100::ms => dur min_pulse;
    if(common_pulse < min_pulse) {
        // Find smallest loop and use that instead
        1000::second => dur smallest;
        for(0 => int i; i < NUM_TRACKS; i++) {
            if(has_loop[i] && recorded_duration[i] < smallest) {
                recorded_duration[i] => smallest;
            }
        }
        smallest => common_pulse;
    }

    return common_pulse;
}

fun void alignAllLoops() {
    findCommonPulse() => dur pulse;

    <<< "Common pulse:", pulse/second, "seconds" >>>;

    for(0 => int i; i < NUM_TRACKS; i++) {
        if(!has_loop[i]) continue;

        // Round to nearest multiple of pulse
        (recorded_duration[i] / pulse) $ float => float ratio;
        Math.round(ratio) $ int => int multiples;

        if(multiples < 1) 1 => multiples;

        pulse * multiples => recorded_duration[i];

        // Update LiSa
        0 => lisa[i].play;
        0::second => lisa[i].playPos;
        recorded_duration[i] => lisa[i].loopEnd;
        1 => lisa[i].play;

        <<< "Track", i, "=", multiples, "×", pulse/second, "sec" >>>;
    }
}
```

### Pros

- Most mathematically elegant
- All loops adjust together fairly
- Can create interesting polyrhythmic relationships

### Cons

- Complex to implement correctly
- GCD might be too small (e.g., 1ms) and not useful
- Results can be unpredictable for users
- May require heuristics to find "musical" GCD

### Best For

- Experimental/generative music
- When mathematical precision is valued
- Academic/research contexts

---

## Solution 4: Transparent Quantization

### Concept

Derive an implicit "beat grid" from the first loop without showing tempo to the user. Quantize subsequent loops to this hidden grid.

### How It Works

1. First loop is divided into N beats (4, 8, or 16)
2. Calculate implicit beat length
3. Subsequent loops snap to nearest multiple of this beat
4. User never sees BPM, but loops stay synced

### Implementation Details

```chuck
dur implicit_beat_length;
0 => int implicit_grid_set;

fun dur deriveImplicitBeat(dur loop_duration, int assumed_beats) {
    return loop_duration / assumed_beats;
}

fun int detectBestBeatDivision(dur loop_duration) {
    // Try common divisions and pick most "musical" one
    [4, 8, 16, 12, 6, 3, 2] @=> int divisions[];

    // Prefer beat lengths in musical range (300-900ms for 66-200 BPM)
    250::ms => dur ideal_min;
    1000::ms => dur ideal_max;

    for(0 => int i; i < divisions.size(); i++) {
        loop_duration / divisions[i] => dur beat;
        if(beat >= ideal_min && beat <= ideal_max) {
            return divisions[i];
        }
    }

    // Default to 4 if nothing fits
    return 4;
}

fun void stopRecording(int track) {
    // ... existing record stop code ...

    lisa[track].recPos() => recorded_duration[track];

    if(!implicit_grid_set) {
        // Derive implicit beat from first loop
        detectBestBeatDivision(recorded_duration[track]) => int beats;
        deriveImplicitBeat(recorded_duration[track], beats) => implicit_beat_length;
        1 => implicit_grid_set;

        <<< "Implicit beat derived:", implicit_beat_length/ms, "ms" >>>;
        <<< "(From", beats, "beat division)" >>>;
    } else {
        // Quantize to implicit beat grid
        (recorded_duration[track] / implicit_beat_length) $ float => float beats;
        Math.round(beats) $ int => int quantized_beats;

        if(quantized_beats < 1) 1 => quantized_beats;

        implicit_beat_length * quantized_beats => recorded_duration[track];

        <<< "Track", track, "quantized to", quantized_beats, "beats" >>>;
    }

    recorded_duration[track] / second => loop_length[track];

    // ... rest of playback setup ...
}
```

### Pros

- Feels natural, like having a tempo without seeing it
- Works well for rhythmic music
- User gets quantization benefits without constraints

### Cons

- Still imposes a hidden grid structure
- First loop must be "good" to set proper grid
- May not work well for very free/rubato material

### Best For

- Rhythmic/percussive loops
- When you want the benefits of quantization without the UI
- Users who naturally play in tempo

---

## Solution 5: Manual Sync/Re-Align Button

### Concept

Let loops drift naturally, but provide a manual "sync all" button that realigns loop playback positions to a common start point.

### How It Works

1. Loops record and play at their exact recorded lengths
2. When user presses SYNC button, all loops jump to their start position simultaneously
3. Optionally, can also adjust loop lengths to align better

### Implementation Details

```chuck
// MIDI mapping for sync button
43 => int NOTE_SYNC_ALL;  // G1

fun void syncAllLoops() {
    <<< ">>> SYNCING ALL LOOPS <<<" >>>;

    // Simple version: just reset all play positions
    for(0 => int i; i < NUM_TRACKS; i++) {
        if(has_loop[i]) {
            0::second => lisa[i].playPos;
        }
    }
}

fun void syncAllLoopsWithAdjustment() {
    <<< ">>> SYNCING ALL LOOPS (with adjustment) <<<" >>>;

    // Find longest loop
    0::second => dur longest;
    for(0 => int i; i < NUM_TRACKS; i++) {
        if(has_loop[i] && recorded_duration[i] > longest) {
            recorded_duration[i] => longest;
        }
    }

    // Reset positions
    for(0 => int i; i < NUM_TRACKS; i++) {
        if(!has_loop[i]) continue;

        0::second => lisa[i].playPos;

        // Optional: adjust to fit evenly into longest
        (longest / recorded_duration[i]) $ float => float ratio;
        Math.round(ratio) $ int => int times;

        if(times > 1) {
            longest / times => recorded_duration[i];
            recorded_duration[i] => lisa[i].loopEnd;
            <<< "Track", i, "adjusted to fit", times, "times" >>>;
        }
    }
}

// Add to MIDI listener
fun void midiListener() {
    while(true) {
        min => now;

        while(min.recv(msg)) {
            // ... existing MIDI code ...

            if(messageType == 0x90 && data2 > 0) {
                if(data1 == NOTE_SYNC_ALL) {
                    syncAllLoopsWithAdjustment();
                }
                // ... rest of note handling ...
            }
        }
    }
}
```

### Pros

- Maximum freedom during recording
- User decides when sync is needed
- Can implement different sync strategies (simple reset vs. adjustment)
- No automatic changes to loops

### Cons

- Requires user intervention
- Loops still drift between sync events
- User must remember to sync periodically

### Best For

- Ambient/textural music where drift is acceptable
- Performance with deliberate control over sync
- Experimental approaches where drift is a feature

---

## Comparison Table

| Solution                 | Complexity | User Control             | Musical Flexibility  | Drift Prevention |
| ------------------------ | ---------- | ------------------------ | -------------------- | ---------------- |
| Master Loop Reference    | Low        | Low (first loop decides) | Medium               | Excellent        |
| Longest Loop Master      | Medium     | Medium                   | High                 | Excellent        |
| GCD Adjustment           | High       | Low                      | High (unpredictable) | Excellent        |
| Transparent Quantization | Medium     | Low-Medium               | Medium               | Excellent        |
| Manual Sync Button       | Low        | High                     | Maximum              | Good (when used) |

---

## Hybrid Approaches

### Combination 1: Master Loop + Manual Override

- Use master loop reference by default
- Add button to switch which loop is master
- Add button to disable sync temporarily

### Combination 2: Auto-Sync with Tolerance

- Measure drift between loops
- Only trigger auto-sync when drift exceeds threshold (e.g., 50ms)
- Gives freedom but prevents extreme drift

### Combination 3: Adaptive Grid

- Start with transparent quantization
- If loops drift beyond threshold, automatically recalculate grid
- Self-correcting system

---

## Recommendations

**For Live Performance:** Solution 1 (Master Loop Reference)

- Simple, predictable, reliable
- First loop sets the vibe
- Easy to explain to users

**For Studio/Composition:** Solution 2 (Longest Loop Master)

- Maximum flexibility
- Build complex structures gradually

**For Experimental Work:** Solution 5 (Manual Sync)

- Let the artist decide
- Drift can be musically interesting

**For Rhythmic/Beat-Based:** Solution 4 (Transparent Quantization)

- Gets best of both worlds
- Natural feel with locked timing

---

## Implementation Notes

### Testing Drift Detection

```chuck
// Add drift monitoring to help test solutions
fun void driftMonitor() {
    while(true) {
        1::second => now;

        if(has_master) {
            for(0 => int i; i < NUM_TRACKS; i++) {
                if(has_loop[i] && i != master_track) {
                    // Calculate theoretical vs actual play position drift
                    lisa[i].playPos() => dur current_pos;
                    lisa[master_track].playPos() => dur master_pos;

                    // Calculate expected position based on length ratio
                    (recorded_duration[i] / master_duration) $ float => float ratio;
                    master_pos * ratio => dur expected_pos;

                    Math.fabs((current_pos - expected_pos) / ms) => float drift_ms;

                    if(drift_ms > 10.0) {
                        <<< "Track", i, "drift:", drift_ms, "ms" >>>;
                    }
                }
            }
        }
    }
}

// Spork in main program for testing
// spork ~ driftMonitor();
```

### Visualizing Sync Status

```chuck
// Add visual indicators to show sync status
GSphere sync_indicator --> scene;
sync_indicator.posY(2.5);
sync_indicator.sca(0.3);

// Green = locked, Yellow = slight drift, Red = significant drift
fun void updateSyncIndicator() {
    // Calculate max drift across all tracks
    0.0 => float max_drift_ms;

    // ... drift calculation ...

    if(max_drift_ms < 5.0) {
        sync_indicator.color(@(0.2, 1.0, 0.2));  // Green - locked
    } else if(max_drift_ms < 20.0) {
        sync_indicator.color(@(1.0, 1.0, 0.2));  // Yellow - slight drift
    } else {
        sync_indicator.color(@(1.0, 0.2, 0.2));  // Red - needs sync
    }
}
```

---

## Further Reading

- **Ableton Live's "Follow Action":** Algorithmic loop variation
- **Boss RC-505 Loop Station:** Hardware implementation of multi-track sync
- **Echoplex Digital Pro:** Classic looper with "SwitchQuant" feature
- **SuperCollider's Clock system:** Software timing precision approaches

---

## Conclusion

There is no single "best" solution - the right choice depends on your musical goals:

- **Want predictability?** → Master Loop Reference
- **Want flexibility?** → Longest Loop Master
- **Want control?** → Manual Sync
- **Want hidden structure?** → Transparent Quantization
- **Want to experiment?** → GCD Adjustment

The key insight: **Loop sync can be solved without visible tempo** by using the loops themselves as the timing reference, rather than an external clock.
