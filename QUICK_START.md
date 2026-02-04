# CHULOOPA Quick Start Guide

**Get beatboxing with CHULOOPA Drums in 10 minutes**

## What is CHULOOPA Drums?

CHULOOPA Drums is a real-time drum looping system that:
1. **Transcribes** your beatbox into drum patterns (kick, snare, hat)
2. **Plays back** drum samples in real-time as you beatbox
3. **Auto-generates** AI variations via OSC (Python ↔ ChucK)
4. **Loops** your drum patterns with seamless variation switching
5. **Real-time spice control** for adjusting variation creativity

**Key Features:**
- Personalized ML classifier trained on YOUR voice
- OSC integration for automatic AI workflow
- Live spice control with visual feedback

---

## Installation

**Requirements:**
- ChucK 1.5.x+ (with ChuGL support)
- Python 3.10+ with dependencies
- MIDI controller with CC 18 knob
- Microphone for beatbox input

**Install Python dependencies:**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
pip install -r requirements.txt
```

**Set up Gemini API key:**

```bash
export GEMINI_API_KEY=your_api_key_here
# Or create a .env file with: GEMINI_API_KEY=your_api_key_here
```

---

## 10-Minute Workflow

### Step 1: Record Training Samples (One-Time, ~5 minutes)

**Important:** This must be done BEFORE using CHULOOPA for the first time!

```bash
chuck src/drum_sample_recorder.ck
```

You'll see:
```
╔═══════════════════════════════════════╗
║  DRUM SAMPLE RECORDER                ║
╚═══════════════════════════════════════╝

Press K/S/H to record samples, Q to quit
```

**A visualization window opens with:**
- **Left cube (kick)**: Pulses with radial expansion
- **Center octahedron (snare)**: Pulses with vertical compression
- **Right dodecahedron (hat)**: Pulses with asymmetric wobble
- **Instruction text**: Guides you through the workflow step-by-step

**Record 10 samples of each drum:**

1. **Press K**: Record KICK samples
   - Say "BOOM" into the mic (make a deep kick sound)
   - Repeat 10 times
   - Watch the left cube grow and pulse with each recording
   - Each sample: 1 second long

2. **Press S**: Record SNARE samples
   - Say "PAH" or "TSH" into the mic (sharp snare sound)
   - Repeat 10 times
   - Watch the center octahedron grow and pulse

3. **Press H**: Record HI-HAT samples
   - Say "TSS" or "TSK" into the mic (high-pitched hat sound)
   - Repeat 10 times
   - Watch the right dodecahedron grow and pulse

4. **Press Q**: Quit and save
   - Creates `training_samples.csv` (30 samples)

**Tips:**
- Be **consistent** with your sounds
- Record in a **quiet environment**
- Use **your normal beatbox** voice (this is personalized!)
- Each sample should be **distinct and clear**

**File created:**
- `training_samples.csv` - Your personalized training data

**Note:** The KNN classifier will automatically train when you start CHULOOPA Drums V2!

---

### Step 2: Start Python Watch Mode (Terminal 1)

**IMPORTANT: Must run from src directory**

```bash
cd src
python drum_variation_ai.py --watch
```

You'll see:
```
=============================================================
  CHULOOPA Drum Variation AI
=============================================================

OSC client initialized - sending to 127.0.0.1:5001
OSC server listening on localhost:5000

Watching for drum file changes in: tracks/track_0
Variation type: gemini
Current spice level: 0.50

Ready! Press Ctrl+C to stop
```

**Keep this terminal open!** It will auto-generate variations when you record loops.

### Step 3: Run CHULOOPA Drums V2 (Terminal 2)

**IMPORTANT: Must run from src directory**

In a **second terminal**, run:

```bash
cd src
chuck chuloopa_drums_v2.ck
```

You'll see:
```
=====================================================
      CHULOOPA - AI Drum Variation System
=====================================================

OSC Communication:
  Sending to: localhost:5000
  Receiving on: 5001

MODE: DRUMS ONLY (Real-time drum feedback)
=====================================================

✓ CHULOOPA ready!
```

A visualization window will open showing a sphere (red = no loop yet).

---

### Step 4: Record Your First Drum Loop

**Press and HOLD MIDI Note 36** (C1) on your MIDI controller

**Beatbox into the mic:** "BOOM tss tss BOOM tss tss"

**What happens in ChucK terminal:**
- System detects each sound (onset detection)
- Classifies: kick, hat, hat, kick, hat, hat
- **Plays drum samples IMMEDIATELY** (real-time feedback!)
- Console shows: `Track 0 - KICK at 0.037 sec | Total hits: 1`

**Release Note 36** to stop recording

**What happens in ChucK:**
- Auto-exports to `src/tracks/track_0/track_0_drums.txt`
- Starts looping your drum pattern
- Console: `>>> DRUM PLAYBACK ENABLED (Drums Only Mode) <<<`

**What happens in Python terminal (automatically!):**
```
Detected change: tracks/track_0/track_0_drums.txt

Loading: tracks/track_0/track_0_drums.txt
  Loaded 12 hits, duration: 2.183s
  Current spice level: 0.50

  Generating variation (spice: 0.50)
  Calling Gemini API...
  Saved: tracks/track_0/variations/track_0_drums_var1.txt
  Sending OSC: /chuloopa/variations_ready

✓ Generated variation (spice: 0.50)
```

**Back in ChucK:**
```
Python: Complete!
OSC received: /chuloopa/variations_ready

✓ Python: Variation ready!
  Press D1 (Note 38) to load variation
```

**ChuGL window:** Sphere turns **green** (variation ready!)

**You should now hear your drums looping!**

---

### Step 5: Load the AI Variation

**Press MIDI Note 38** (D1) to toggle variation ON

Console shows:
```
>>> QUEUED: Variation toggle will occur at next loop boundary <<<
```

**Current loop continues** until the end

**At loop boundary:**
```
╔═══════════════════════════════════════╗
║  LOADING VARIATION 1                 ║
╚═══════════════════════════════════════╝

>>> VARIATION LOADED (Playback ID: 1) <<<
```

**ChuGL window:** Sphere turns **blue** (variation mode)

**Audio:** You should hear a variation with different timing, velocities, and possibly ghost notes!

**Press D1 again** to toggle back to original (sphere turns red)

---

### Step 6: Adjust Spice Level and Regenerate

**Turn the CC 18 knob** on your MIDI controller

**In ChucK console:**
```
Spice level: 75%
```

**In ChuGL window:**
- Text color changes: blue (low) → orange (medium) → red (high)
- Higher spice = more creative variations!

**Press MIDI Note 39** (D#1) to regenerate with new spice level

**In Python terminal:**
```
============================================================
REGENERATE requested from ChucK
============================================================
Loading: tracks/track_0/track_0_drums.txt
  Current spice level: 0.75

  Generating variation (spice: 0.75)
  ...
✓ Generated variation (spice: 0.75)
```

**Press D1** to hear the new, spicier variation!

---

### Step 7: Clear Track and Start Over

**Press MIDI Note 37** (C#1) to clear the track

Console:
```
>>> CLEARING TRACK 0 <<<
Track 0 drum data cleared
```

**ChuGL:** Sphere turns **gray** (no loop)

**Python:** Receives clear notification

**Ready to record a new loop!**

---

## MIDI Control Reference (Single Track)

### Recording (Press & Hold)
| MIDI Note | Note Name | Function              |
|-----------|-----------|----------------------|
| 36        | C1        | Record track 0       |

**Usage:** Press and HOLD to record, RELEASE to stop. Python auto-generates variation.

### Clearing
| MIDI Note | Note Name | Function              |
|-----------|-----------|----------------------|
| 37        | C#1       | Clear track 0        |

**Usage:** Single press (immediate)

### Variation Control
| MIDI Note | Note Name | Function                      |
|-----------|-----------|------------------------------|
| 38        | D1        | Toggle variation ON/OFF      |
| 39        | D#1       | Regenerate with current spice |

**Usage:**
- D1: Single press (queued at loop boundary)
- D#1: Single press (triggers Python regeneration)

### Spice Control
| CC Number | Function                   | Visual Feedback |
|-----------|----------------------------|-----------------|
| CC 18     | Spice level (0.0-1.0)      | Blue/Orange/Red |

**Usage:** Turn knob to adjust creativity level

### Future (3-Track Version)
Additional controls for Track 1 and Track 2 will use Notes 40-45 and CC 46-53

---

## Understanding the Output Files

### File Structure

After recording, you'll have:

```
src/
└── tracks/
    └── track_0/
        ├── track_0_drums.txt           # Your original recording
        └── variations/
            └── track_0_drums_var1.txt  # AI-generated variation
```

### track_0_drums.txt Format (Original)

```
# Track 0 Drum Data
# Format: DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME
# Classes: 0=kick, 1=snare, 2=hat
# DELTA_TIME: Duration until next hit (for last hit: time until loop end)
# Total loop duration: 2.182676 seconds
0,0.037732,0.169278,0.566987
1,0.603719,0.250155,0.406349
0,1.010068,0.314029,0.444082
```

**Columns:**
1. `DRUM_CLASS`: 0=kick, 1=snare, 2=hat
2. `TIMESTAMP`: When hit occurs (seconds from loop start)
3. `VELOCITY`: How loud (0.0-1.0)
4. `DELTA_TIME`: Time until next hit (last one = time to loop end)

**The delta_time on the last hit is critical for perfect loop timing!**

### track_0_drums_var1.txt Format (Variation)

Same format as original, but with AI-modified:
- Hit timing (subtle tempo variations)
- Velocities (dynamic changes)
- Ghost notes (additional quiet hits)
- Maintained total loop duration (same as original)

---

## Troubleshooting

### "Python watch mode won't start"
**Solution:**
- Must run from `src` directory: `cd src && python drum_variation_ai.py --watch`
- Install dependencies: `pip install -r requirements.txt`
- Check port 5000 is free: `lsof -i :5000`
- Kill conflicting process: `kill <PID>`

### "ChucK not receiving OSC messages"
**Solution:**
- Must run from `src` directory: `cd src && chuck chuloopa_drums_v2.ck`
- Check port 5001 is free: `lsof -i :5001`
- Look for "OSC listener started on port 5001" in ChucK output
- Verify Python is using `127.0.0.1` not `localhost`

### "No MIDI devices found!"
**Solution:**
- Check MIDI controller is connected
- Test MIDI: `python TESTMIDIINPUT.py`
- Verify MIDI port: Edit line 62 in `chuloopa_drums_v2.ck`
  ```chuck
  0 => int MIDI_DEVICE;  // Try changing to 1, 2, etc.
  ```

### "Could not load kick.wav / snare.wav / hat.WAV"
**Solution:**
- Check `samples/` directory exists
- Verify sample files are present:
  ```bash
  ls samples/
  # Should show: kick.wav  snare.wav  hat.WAV
  ```

### "No drum hits detected during recording"
**Solutions:**
- **Beatbox LOUDER** - system needs strong signal
- **Get closer to mic**
- Lower threshold in code (line 76):
  ```chuck
  0.005 => float MIN_ONSET_STRENGTH;  // Lower = more sensitive
  ```

### "Classifier accuracy too low"
**Solutions:**
- Record MORE training samples (20+ per class)
- Be more **consistent** with sounds
- Record in **quieter environment**
- Delete `training_samples.csv` and re-record samples
- Restart CHULOOPA (classifier trains automatically on startup)

### "Drums triggering on silence / too many false positives"
**Solution:**
- Increase threshold (line 76):
  ```chuck
  0.02 => float MIN_ONSET_STRENGTH;  // Higher = less sensitive
  ```

### "Drums out of sync after loading from file"
**This shouldn't happen!** The system uses:
- Master sync with musical ratios
- Delta_time for precise loop lengths
- Queued actions at loop boundaries

If it does happen:
- Check console for error messages
- Verify `track_N_drums.txt` has delta_time column
- Check total loop duration in file header

### "Variation not being generated automatically"
**Solution:**
- Check Python terminal for errors
- Verify `GEMINI_API_KEY` is set
- System falls back to `groove_preserve` algorithm if Gemini fails
- Check that `src/tracks/track_0/track_0_drums.txt` was created

### "Spice knob not working"
**Solution:**
- Verify CC 18 is mapped: `python TESTMIDIINPUT.py`
- Turn knob slowly to see "Spice level: XX%" in ChucK console
- ChuGL window must be open to see visual feedback

### "Sphere not changing color"
**Solution:**
- Make sure ChuGL window is open and visible
- Check ChucK console for OSC messages
- Restart both Python and ChucK

### "Loaded drums play at the same time as buffer drums"
**This is fixed in V2!** Each playback session has a unique ID.
- Old hits check their ID and abort if it doesn't match
- Console shows: `Track 0 - Drum playback started (ID: 1)`
- Incrementing ID = old drums stop, new drums start

---

## Tips for Best Results

### Recording Training Samples
1. **Be consistent** - Use the same beatbox sounds every time
2. **Quiet room** - Minimize background noise
3. **Normal voice** - Use your natural beatbox (not exaggerated)
4. **Distinct sounds** - Make kick/snare/hat clearly different
5. **More is better** - 20+ samples per class = higher accuracy

### Recording Loops
1. **Start simple** - Begin with basic kick pattern
2. **Layer gradually** - Add snare, then hi-hat
3. **Use real-time feedback** - Listen to classification as you beatbox
4. **If misclassified** - Retrain with more/better samples
5. **Clear and retry** - Don't be afraid to start over!

### Pattern Loading
1. **Queue mid-loop** - Press G1 anytime, it waits for boundary
2. **Smooth transitions** - No overlap, no gaps
3. **Edit txt files** - Manually adjust timing/velocity if needed
4. **Backup patterns** - Save interesting patterns to new files

### Performance
1. **Build gradually** - Start with one track, layer more
2. **Volume balance** - Use CC 45-47 to balance tracks
3. **Clear strategically** - Remove tracks to create space
4. **Reload variations** - Try different patterns on same track

---

## Next Steps

### Experiment with AI Variations
- Try different spice levels (CC 18) for different musical contexts
- Regenerate (D#1) multiple times to find interesting variations
- Toggle between original and variation during performance
- Record longer/shorter loops to test variation quality

### Customize Your System
- Adjust onset detection sensitivity (line 76 in `chuloopa_drums_v2.ck`)
- Change loop duration limit (line 66): `30::second => dur MAX_LOOP_DURATION;`
- Modify drum samples in `samples/` directory
- Edit training data in `training_samples.csv`
- Adjust spice ranges in Python script

### Coming Soon
**Phase 3: Multi-Track Support**
- 3 simultaneous tracks with independent variations
- Per-track spice control
- Visual feedback for all tracks

**Phase 4: Enhanced Features**
- Multi-variation support (5+ variants, random selection)
- Per-drum-hit visual feedback
- Pattern evolution mode (gradual variation over time)

---

## Example Session

```bash
# Step 1: Record training samples (one-time setup)
cd src
chuck drum_sample_recorder.ck
# Press K/S/H to record 10 kicks, 10 snares, 10 hats
# Watch the geometries grow and pulse
# Press Q to quit

# Step 2: Start Python watch mode (Terminal 1)
cd src
python drum_variation_ai.py --watch
# Keep running!

# Step 3: Start ChucK (Terminal 2, new terminal)
cd src
chuck chuloopa_drums_v2.ck

# On your MIDI controller:
# 1. Press & hold Note 36 (C1), beatbox "BOOM tss BOOM tss", release
#    → Python auto-generates variation
#    → Sphere turns green (variation ready)
# 2. Press Note 38 (D1) to load variation
#    → Sphere turns blue (variation playing)
# 3. Turn CC 18 knob to adjust spice level
#    → Text color changes in ChuGL window
# 4. Press Note 39 (D#1) to regenerate with new spice
#    → Python generates new variation
# 5. Press Note 38 (D1) to hear new variation
# 6. Press Note 38 (D1) again to toggle back to original
#    → Sphere turns red (original playing)
# 7. Press Note 37 (C#1) to clear track

# Press Ctrl+C in both terminals to stop
```

---

## File Structure Reference

```
CHULOOPA/
├── src/
│   ├── chuloopa_drums_v2.ck         ← Main ChucK system (START HERE!)
│   ├── drum_variation_ai.py         ← AI variation engine with OSC
│   ├── drum_sample_recorder.ck      ← Training sample collector
│   │
│   └── tracks/                       ← Generated drum data (auto-created)
│       └── track_0/
│           ├── track_0_drums.txt    ← Original recording
│           └── variations/
│               └── track_0_drums_var1.txt  ← AI variation
│
├── samples/                          ← Drum samples
│   ├── kick.wav
│   ├── snare.wav
│   └── hat.WAV
│
├── requirements.txt                  ← Python dependencies
├── train_classifier.py               ← KNN training script
├── training_samples.csv              ← Your training data (generated)
└── drum_classifier.pkl               ← Your model (generated)
```

---

## Getting Help

1. **Read README.md** - Comprehensive technical documentation
2. **Check code comments** - All files are well-commented
3. **Console messages** - System prints helpful debugging info
4. **Test systematically** - Try training → recording → playback separately

---

**Ready to beatbox? Start with Step 1!**

```bash
# Step 1: Record training samples
chuck src/drum_sample_recorder.ck

# Step 2: Loop! (classifier trains automatically)
chuck src/chuloopa_drums_v2.ck
```

🥁 Happy beatboxing! 🎵
