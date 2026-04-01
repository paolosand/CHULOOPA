# CHULOOPA Quick Start Guide

**Get beatboxing with CHULOOPA Drums in 10 minutes**

## What is CHULOOPA Drums?

CHULOOPA Drums is a real-time drum looping system that:
1. **Transcribes** your beatbox into drum patterns (kick, snare, hat)
2. **Plays back** drum samples in real-time as you beatbox
3. **Auto-generates** a bank of 5 AI variations at different spice levels
4. **Loops** your drum patterns with automatic variation switching driven by live audio energy
5. **Real-time spice control** via audio analysis — louder/busier playing = spicier variations

**Key Features:**
- Personalized MFCC-13 KNN classifier trained on YOUR voice
- Audio-driven spice detection from live music (guitar/vocals/room)
- Automatic variation selection — no manual toggling needed
- 3-terminal workflow: Python AI engine + spice detector + ChucK looper

---

## Installation

**Requirements:**
- ChucK 1.5.x+ (with ChuGL support)
- Python 3.10+ with dependencies
- MIDI controller with CC 74 knob
- Microphone for beatbox input

**Install Python dependencies:**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
pip install -r requirements.txt
```

---

## 10-Minute Workflow

### Step 1: Record Training Samples (One-Time, ~5 minutes)

**Important:** This must be done BEFORE using CHULOOPA for the first time!

```bash
chuck src/drum_sample_recorder.ck
```

**A visualization window opens with:**
- **Left cube (kick)**: Pulses with radial expansion
- **Center octahedron (snare)**: Pulses with vertical compression
- **Right dodecahedron (hat)**: Pulses with asymmetric wobble

**Record 10+ samples of each drum:**

1. **Press K**: Set label to kick, then beatbox "BOOM" (10+ times)
2. **Press S**: Set label to snare, then beatbox "PAH"/"TSH" (10+ times)
3. **Press H**: Set label to hi-hat, then beatbox "TSS"/"TSK" (10+ times)
4. **Press E**: Export → creates `training_samples.csv`
5. **Press P**: Test live — beatbox freely and hear KNN classify in real-time
   - If accuracy sounds wrong: **Press R** to reset and re-record all samples
6. **Press ESC**: Close window when satisfied

**Full keyboard reference:**

| Key | Action |
|-----|--------|
| K | Set label → kick |
| S | Set label → snare |
| H | Set label → hi-hat |
| N | Disable recording (pause) |
| E / Q | Export training data |
| P | Live playback test (KNN classify → drum sounds) |
| R | Full reset — erase all samples, start over |
| ESC | Close window |

**Tips:**
- Be **consistent** with your sounds
- Record in a **quiet environment**
- Use **your natural beatbox** voice (this is personalized!)
- Use **P** to verify accuracy before moving on — re-record with **R** if needed

**Note:** The KNN classifier trains automatically when you start CHULOOPA.

---

### Step 2: Start Python AI Engine (Terminal 1)

**IMPORTANT: Must run from src directory**

```bash
cd src
python drum_variation_ai_v2.py --watch
```

You'll see:
```
=============================================================
  CHULOOPA Drum Variation AI v2
=============================================================

OSC client initialized - sending to 127.0.0.1:5001
OSC server listening on localhost:5000

Watching for drum file changes in: tracks/track_0
Bank generation: 5 variants (spice 0.2 / 0.4 / 0.6 / 0.8 / 1.0)

Ready! Press Ctrl+C to stop
```

**Keep this terminal open!** It will auto-generate a variation bank when you record loops.

---

### Step 3: Start Spice Detector (Terminal 2)

**IMPORTANT: Must run from src directory**

```bash
cd src
chuck spice_detector.ck
```

This analyzes live audio and streams a composite spice level (0.0–1.0) via OSC every 500ms.

> **Stereo/performance mode:** `chuck --channels:2 src/spice_detector.ck` — enables CC 75 to blend guitar vs. vocal input.

---

### Step 4: Run CHULOOPA (Terminal 3)

**IMPORTANT: Must run from src directory**

```bash
cd src
chuck chuloopa_drums_v4.ck
```

> **Ableton required:** IAC Driver must be enabled and an Ableton MIDI track set up
> (input: IAC Driver Bus 1, Monitor: In, with Drum Rack mapping C1→Kick, D1→Snare, F#1→Hi-hat).
> See README.md for full setup.

You'll see:
```
=====================================================
      CHULOOPA v4 - Audio-Driven Variation System
=====================================================

OSC Communication:
  Sending to: localhost:5000
  Receiving on: 5001

MODE: DRUMS ONLY (Real-time drum feedback)
=====================================================

✓ CHULOOPA ready!
```

A ChuGL visualization window opens (sphere: gray = no loop yet).

---

### Step 5: Record Your First Drum Loop

**Press and HOLD MIDI Note 36** (C1) on your MIDI controller

**Beatbox into the mic:** "BOOM tss tss BOOM tss tss"

**What happens in ChucK terminal:**
- System detects each sound (onset detection)
- Classifies: kick, hat, hat, kick, hat, hat (using MFCC-13 KNN)
- **Plays drum samples IMMEDIATELY** (real-time feedback)

**Release Note 36** to stop recording

**What happens automatically:**
- Auto-exports to `src/tracks/track_0/track_0_drums.txt`
- Starts looping your drum pattern
- Python watchdog detects file change, starts generating 5 variations
- `spice_detector.ck` drives variation selection from live audio

---

### Step 6: Variations Auto-Select Based on Audio Spice

No manual toggling needed! As you play:

1. `spice_detector.ck` reads audio energy every 500ms
2. ChucK averages spice over 4 bars (rolling window)
3. Best matching variation from the bank loads at the next loop boundary
4. **ChuGL sphere turns blue** when a variation is playing

**To adjust the ceiling:**
- Turn **CC 74** to limit how spicy the auto-selection can get
- Text color: blue (low) → orange (medium) → red (high)

**To regenerate the entire bank:**
- Press **MIDI Note 38** (D1)
- Python generates all 5 new variants and sends `bank_ready` when done

---

### Step 7: Clear Track and Start Over

**Press MIDI Note 37** (C#1) to clear the track

**ChuGL:** Sphere turns **gray** (no loop)

**Ready to record a new loop!**

---

## MIDI Control Reference (Single Track)

| MIDI | Note Name | Function |
|------|-----------|----------|
| Note 36 hold | C1 | Record track 0 — real-time drum feedback while beatboxing |
| Note 37 | C#1 | Clear track 0 (immediate) |
| Note 38 | D1 | Regenerate full variation bank (5 new variants) |
| CC 74 | — | Spice ceiling (0.0–1.0) — caps audio-driven variation level |

---

## Understanding the Output Files

```
src/
└── tracks/
    └── track_0/
        ├── track_0_drums.txt           # Your original recording
        └── variations/
            └── track_0_drums_var1.txt  # AI-generated variation (active slot)
```

**track_0_drums.txt format:**
```
# Format: DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME
# Classes: 0=kick, 1=snare, 2=hat
0,0.037732,0.169278,0.566987
1,0.603719,0.250155,0.406349
0,1.010068,0.314029,0.444082
```

`DELTA_TIME` on the last hit = time until loop end (critical for perfect looping).

---

## Troubleshooting

### "Python watch mode won't start"
- Run from `src` directory: `cd src && python drum_variation_ai_v2.py --watch`
- Install dependencies: `pip install -r requirements.txt`
- Check port 5000 is free: `lsof -i :5000`

### "ChucK not receiving OSC messages"
- Run from `src` directory
- Check port 5001 is free: `lsof -i :5001`
- Look for "OSC listener started on port 5001" in ChucK output
- Python must use `127.0.0.1` not `localhost`

### "No MIDI devices found"
- Check MIDI controller is connected
- Run `chuck src/midi_monitor.ck` to see available ports
- Change `MIDI_DEVICE` constant in `chuloopa_drums_v4.ck` if needed

### "Spice level stuck at 0 / no variation switching"
- Ensure `spice_detector.ck` is running (Terminal 2)
- Check that audio is reaching the mic (speak/play into it)
- Lower `SILENCE_THRESHOLD` in `spice_detector.ck` if signal is weak

### "No drum hits detected during recording"
- **Beatbox LOUDER** — system needs strong signal
- Lower threshold in `chuloopa_drums_v4.ck`: `0.005 => float MIN_ONSET_STRENGTH`

### "Classifier accuracy too low"
- Record more samples (20+ per class) with `drum_sample_recorder.ck`
- Delete `training_samples.csv` and re-record with consistent technique

---

## Example Session

```bash
# Step 1: Record training samples (one-time setup)
cd src
chuck drum_sample_recorder.ck
# Press K/S/H to record 10+ each, E to export
# Press P to test live — R to reset and re-record if needed

# Step 2: Start Python AI engine (Terminal 1)
cd src
python drum_variation_ai_v2.py --watch

# Step 3: Start spice detector (Terminal 2)
cd src
chuck spice_detector.ck

# Step 4: Start ChucK (Terminal 3)
cd src
chuck chuloopa_drums_v4.ck

# On your MIDI controller:
# 1. Press & hold Note 36 (C1), beatbox "BOOM tss BOOM tss", release
#    → Python auto-generates 5 variation bank
#    → Variations auto-select based on audio spice
# 2. Turn CC 74 to set spice ceiling (limits variation intensity)
# 3. Press Note 38 (D1) to regenerate bank with fresh variations
# 4. Press Note 37 (C#1) to clear and start over

# Press Ctrl+C in all terminals to stop
```

---

## Getting Help

1. **Read README.md** — Comprehensive technical documentation
2. **Check code comments** — All files are well-commented
3. **Console messages** — System prints helpful debugging info

---

**Ready to beatbox? Start with Step 1!**

```bash
chuck src/drum_sample_recorder.ck
# K/S/H to record, E to export, P to test, R to reset
```
