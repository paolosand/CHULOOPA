# CHULOOPA

**An intelligent drum looper that transforms beatbox into transcribed drum patterns with AI-powered variations.**

## Overview

CHULOOPA is a real-time drum looping system built in ChucK that uses machine learning to transcribe vocal beatboxing into drum patterns (kick, snare, hat). The system provides immediate audio feedback during recording, automatically exports symbolic drum data, and enables seamless pattern switching for live performance.

**Key Innovation:** Making drum programming accessible to amateur beatboxers through personalized ML classification.

### Core Features

- **Real-time Beatbox Transcription** - Vocal input → Drum samples (instant feedback)
- **3-Track Looper** - Master sync prevents drift across tracks
- **KNN Classifier** - User-trainable personalized drum detection
- **Pattern Loading** - Load/swap drum patterns from files at loop boundaries
- **Symbolic Export** - Auto-saves drum data with precise timing (delta_time format)
- **ChuGL Visualization** - Real-time visual feedback per track

## Quick Start

### 1. Record Training Samples (One-time, ~5 minutes)

Record 10 samples each of kick, snare, and hi-hat sounds using your voice:

```bash
chuck src/drum_sample_recorder.ck
```

**Controls:**

- Press **1**: Record kick samples (record 10)
- Press **2**: Record snare samples (record 10)
- Press **3**: Record hi-hat samples (record 10)
- Press **Q**: Quit and save to `training_samples.csv`

This creates `training_samples.csv` with your personalized beatbox samples.

### 2. Run CHULOOPA Drums V2

```bash
chuck src/chuloopa_drums_v2.ck
```

**Note:** The KNN classifier automatically trains on startup using your `training_samples.csv` file.

### 3. MIDI Controls

**Recording (Press & Hold):**

- **MIDI Note 36, 37, 38** (C1, C#1, D1): Record tracks 0-2
  - _Hear drum samples in real-time as you beatbox!_
  - Release to stop recording

**Clearing (Queued for next cycle):**

- **MIDI Note 39, 40, 41** (D#1, E1, F1): Clear tracks 0-2

**Load Pattern from File (Queued for next cycle):**

- **MIDI Note 42, 43, 44** (F3, F#1, G1): Load `track_N_drums.txt` into tracks 0-2

**Export:**

- **MIDI Note 45** (A1): Manually export all tracks (auto-exports after recording)

**Volume:**

- **CC 46, 47, 48**: Drum volume for tracks 0-2

**Audio/Drum Mix:**

- **CC 51, 52, 53**: Audio/Drum mix control for tracks 0-2

---

## Complete Workflow

### Recording a Loop

1. **Press & hold MIDI Note 36** (C1) on your MIDI controller
2. **Beatbox:** "BOOM tss tss BOOM"
3. **System responds:**
   - Detects onsets (spectral flux)
   - Classifies each hit (kick/snare/hat)
   - **Plays drum samples immediately** (real-time feedback)
   - Stores timing data with delta_time precision
4. **Release Note 36** to stop
   - Auto-exports to `track_0_drums.txt`
   - Starts looping the drum pattern

### Loading a Saved Pattern

1. **Press MIDI Note 43** (G1) mid-loop to queue load
2. Console: `>>> QUEUED: Track 0 will load from file at next loop cycle <<<`
3. **Current loop continues** until boundary
4. **At loop boundary:**
   - Old drums stop cleanly
   - New drums from file start immediately
   - Zero overlap, zero drift!

### Layering Multiple Tracks

1. Record Track 0 (Note 36/C1): Kick pattern
2. Record Track 1 (Note 37/C#1): Snare pattern
3. Record Track 2 (Note 38/D1): Hi-hat pattern
4. All tracks stay perfectly in sync (master sync system)

---

## Technical Architecture

### Drums-Only Mode

CHULOOPA V2 operates in **drums-only mode**:

- ❌ No audio loop playback (audio recorded for analysis only)
- ✅ Real-time drum sample playback during recording
- ✅ Looped drum sample playback after recording
- ✅ Clean pattern switching at loop boundaries

### Master Sync System

Prevents drift across tracks using musical ratios:

- First recorded loop becomes **master reference**
- Subsequent loops auto-adjusted to ratios: `[0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0]`
- Algorithm finds closest multiplier and adjusts loop length
- See `initial implementation/4 - looper midi quneo visual/SOLVING_DRIFT.md` for details

### Onset Detection

- **Algorithm:** Spectral flux with adaptive thresholding
- **Frame size:** 512 samples, hop size 128 samples
- **Threshold:** 1.5× running mean of flux history
- **Debouncing:** 150ms minimum between onsets

### KNN Classification

- **Algorithm:** K-Nearest Neighbors (k=3)
- **Features:** 5-dimensional vector (flux, energy, band1, band2, band5)
- **Training:** User-specific (10 samples per class)
- **Fallback:** Heuristic classifier if training fails

### Queued Action System

Smooth transitions inspired by `chuck_sample_code/chuck_looper/`:

- MIDI actions queue during loop cycle
- Master coordinator executes at loop boundaries
- Prevents overlap and maintains sync

### Delta Time Format

Exported files include precise loop timing:

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

**Key:** Last hit's delta_time (0.444082s) ensures perfect loop timing!

---

## File Structure

```
CHULOOPA/
├── src/
│   ├── chuloopa_drums_v2.ck         # Main system (CURRENT)
│   ├── chuloopa_drums.ck            # Original version (no file loading)
│   ├── chuloopa_main.ck             # OLD: Melody-based system (archived)
│   ├── drum_sample_recorder.ck      # Training data collector
│   └── feature_extraction.ck        # ChucK feature extraction
│
├── samples/                          # Drum samples
│   ├── kick.wav
│   ├── snare.wav
│   └── hat.WAV
│
├── train_classifier.py               # KNN training script
├── training_samples.csv              # Training data (generated)
├── track_0_drums.txt                 # Exported drum patterns (generated)
├── track_1_drums.txt
├── track_2_drums.txt
│
├── README.md                         # This file
├── QUICK_START.md                    # Step-by-step guide
└── CLAUDE.md                         # AI assistant context
```

---

## Next Steps

### Phase 2: AI Variation Generation

**Coming Soon:**

- [ ] GrooVAE integration for drum pattern variations
- [ ] Pattern evolution and humanization
- [ ] Style transfer between beatbox performances

### Phase 3: Enhanced Visuals

**Planned:**

- [ ] Improved ChuGL visualizations
- [ ] Per-drum-hit visual feedback
- [ ] Pattern similarity visualization

---

## Research Goals

**Target Conference:** ICMC 2025

**Paper Title:** _"Personal Drum Machines: User-Trainable Beatbox Classification for Live Performance"_

**Novel Contributions:**

1. User-trainable beatbox classifier (personalized, not generic)
2. Minimal training data (10 samples per class vs. 100s)
3. Live performance focus (<50ms latency)
4. Personalized sample playback
5. End-to-end system from training to performance

---

## Legacy Systems

**Melody-based system (archived):**

- `src/chuloopa_main.ck` - Pitch detection → MIDI transcription
- Preserved as backup plan
- See git history for development timeline

**Experimental prototypes:**

- `initial implementation/` - Evolution of looper designs (1-5)
- Concepts integrated into current drum system

---

## Dependencies

**ChucK:**

- ChucK 1.5.x+ (with ChuGL support)
- STK (Synthesis Toolkit) - included with ChucK

**Hardware:**

- MIDI controller
- Microphone for beatbox input

---

## Troubleshooting

**No MIDI devices found:**

- Check MIDI controller connection
- Verify MIDI port in code (line 62: `0 => int MIDI_DEVICE;`)

**Classifier accuracy poor:**

- Record more training samples (20+ per class)
- Ensure consistent beatbox technique
- Retrain classifier: `python train_classifier.py`

**Drums out of sync:**

- System uses master sync - should not happen
- Check console for drift warnings
- Verify delta_time in exported files

---

## Credits

**Developer:** Paolo Sandejas
**Institution:** CalArts - Music Technology MFA
**Advisor:** Ajay Kapur, Jake Cheng
**Year:** 2025

**Inspired by:**

- Magenta's GrooVAE
- Living Looper (nn_tilde)
- Intelligent Instruments Lab's Notochord
