# CHULOOPA

**An intelligent drum looper that transforms beatbox into transcribed drum patterns with Gemini AI-powered variations.**

## Overview

CHULOOPA is a real-time drum looping system built in ChucK that uses machine learning to transcribe vocal beatboxing into drum patterns (kick, snare, hat). The system provides immediate audio feedback during recording, automatically exports symbolic drum data, generates AI-powered variations, and enables seamless pattern switching for live performance.

**Key Innovation:** Making drum programming accessible to amateur beatboxers through personalized ML classification combined with AI-powered pattern variations that maintain musical coherence.

### Core Features

- **Real-time Beatbox Transcription** - Vocal input → Drum samples (instant feedback)
- **Single-Track Looper** - Master sync system (multi-track coming in Phase 3)
- **KNN Classifier** - User-trainable personalized drum detection
- **AI Variation Generation** - Gemini-powered drum pattern variations with real-time spice control
- **OSC Integration** - Automatic Python-ChucK communication for seamless AI workflow
- **Pattern Loading** - Load/swap drum patterns from files at loop boundaries
- **Symbolic Export** - Auto-saves drum data with precise timing (delta_time format)
- **ChuGL Visualization** - Real-time visual feedback with color-coded states

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

### 2. Start Python Watch Mode (Terminal 1)

**IMPORTANT: Must run from src directory**

```bash
cd src
python drum_variation_ai.py --watch
```

This starts the AI variation engine that auto-generates variations when you record loops.

**Requirements:** Set `GEMINI_API_KEY` environment variable with your Gemini API key.

### 3. Run CHULOOPA Drums V2 (Terminal 2)

**IMPORTANT: Must run from src directory**

```bash
cd src
chuck chuloopa_drums_v2.ck
```

**Note:** The KNN classifier automatically trains on startup using your `training_samples.csv` file. OSC connection to Python is established automatically.

### 4. MIDI Controls (Single Track)

**Recording (Press & Hold):**

- **MIDI Note 36** (C1): Record track 0
  - _Hear drum samples in real-time as you beatbox!_
  - Release to stop recording
  - Python auto-generates variation when recording completes

**Clearing:**

- **MIDI Note 37** (C#1): Clear track 0

**Variation Control:**

- **MIDI Note 38** (D1): Toggle variation mode ON/OFF
  - Queued at loop boundary for smooth transitions
  - ON: Plays AI-generated variation (sphere turns blue)
  - OFF: Plays original recording (sphere turns red)

- **MIDI Note 39** (D#1): Regenerate variations with current spice level
  - Python generates new variation using current CC 18 value

**Spice Control:**

- **CC 18**: Spice level knob (0.0-1.0)
  - **Low (0.0-0.3)**: Conservative, subtle variations (blue text)
  - **Medium (0.4-0.6)**: Balanced creativity (orange text)
  - **High (0.7-1.0)**: Bold, experimental variations (red text)
  - Visual feedback updates in real-time in ChuGL window

**Future (3-Track Version):**
- Additional tracks will use Notes 40-45 and CC controls 46-53

---

## Complete Workflow

### Initial Setup (One-Time)

1. **Terminal 1:** Start Python watch mode
   ```bash
   cd src && python drum_variation_ai.py --watch
   ```
2. **Terminal 2:** Start ChucK
   ```bash
   cd src && chuck chuloopa_drums_v2.ck
   ```
3. **Verify:** Both terminals show "OSC connection established"

### Recording a Loop

1. **Press & hold MIDI Note 36** (C1) on your MIDI controller
2. **Beatbox:** "BOOM tss tss BOOM"
3. **System responds:**
   - Detects onsets (spectral flux)
   - Classifies each hit (kick/snare/hat)
   - **Plays drum samples immediately** (real-time feedback)
   - Stores timing data with delta_time precision
4. **Release Note 36** to stop
   - Auto-exports to `src/tracks/track_0/track_0_drums.txt`
   - Starts looping the drum pattern
   - **Python auto-generates variation** (watch mode detects file change)
   - ChucK sphere turns **green** when variation ready

### Loading AI Variation

1. **Press MIDI Note 38** (D1) to toggle variation ON
2. Console: `>>> QUEUED: Variation toggle will occur at next loop boundary <<<`
3. **Current loop continues** until boundary
4. **At loop boundary:**
   - Loads `src/tracks/track_0/variations/track_0_drums_var1.txt`
   - Sphere turns **blue** (variation mode)
   - Hear AI-generated variation with different timing/velocities/ghost notes

### Adjusting Spice Level

1. **Turn CC 18 knob** on your MIDI controller
2. **Watch ChuGL window:** Text color changes (blue → orange → red)
3. **Console shows:** "Spice level: 75%"
4. **Press D#1** (Note 39) to regenerate with new spice
5. **Python generates** new variation, sends OSC when ready
6. **Press D1** to load the new variation

### Toggling Back to Original

1. **Press D1** again (already in variation mode)
2. Sphere turns **red** (original mode)
3. Hear your original recorded loop

### Future: Layering Multiple Tracks

Multi-track support coming in Phase 3:
1. Record Track 0 (Note 36/C1): Kick pattern
2. Record Track 1 (Note 40/E1): Snare pattern
3. Record Track 2 (Note 41/F1): Hi-hat pattern
4. All tracks stay perfectly in sync (master sync system)

---

## Technical Architecture

### Complete Pipeline

```
1. Start Python Watch Mode (Terminal 1) + Start ChucK (Terminal 2)
   ↓
2. OSC Connection Established (Python ↔ ChucK)
   ↓
3. Beatbox Input (Microphone)
   ↓
4. Real-time Transcription (Onset Detection + KNN Classification)
   ↓
5. Drum Sample Playback (Instant Feedback)
   ↓
6. Symbolic Data Export (track_0_drums.txt with delta_time)
   ↓
7. Python Watchdog Detects File Change
   ↓
8. AI Variation Generation (Gemini API with current spice level)
   ↓
9. OSC: /chuloopa/variations_ready → ChucK (sphere turns green)
   ↓
10. User Toggles Variation (D1) or Adjusts Spice (CC 18) + Regenerates (D#1)
```

### Drums-Only Mode

CHULOOPA V2 operates in **drums-only mode**:

- ❌ No audio loop playback (audio recorded for analysis only)
- ✅ Real-time drum sample playback during recording
- ✅ Looped drum sample playback after recording
- ✅ Clean pattern switching at loop boundaries
- ✅ AI variations maintain loop duration and tempo

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

### OSC Integration (Python ↔ ChucK)

The system uses OSC (Open Sound Control) for real-time bidirectional communication:

**Ports:**
- ChucK sends to: `localhost:5000` (Python receives)
- Python sends to: `127.0.0.1:5001` (ChucK receives)

**Important:** Use `127.0.0.1` instead of `localhost` for Python client - the pythonosc library doesn't resolve `localhost` properly on some systems.

**OSC Messages:**

| Address | Direction | Data Type | Purpose |
|---------|-----------|-----------|---------|
| `/chuloopa/generation_progress` | Python → ChucK | string | Status updates during generation |
| `/chuloopa/variations_ready` | Python → ChucK | int | Signals variation is complete |
| `/chuloopa/regenerate` | ChucK → Python | none | Request new variation with current spice |
| `/chuloopa/spice_level` | ChucK → Python | float | Update spice level (0.0-1.0) |
| `/chuloopa/clear` | ChucK → Python | none | Track cleared notification |

**Workflow:**
1. User records loop (C1) in ChucK
2. ChucK exports `track_0_drums.txt`
3. Python watchdog detects file change
4. Python auto-generates variation with current spice level
5. Python sends `/chuloopa/variations_ready` to ChucK
6. ChucK sphere turns green (variation ready)
7. User presses D1 to load variation

### ChuGL Visual Feedback

The visualization window shows a single sphere with color-coded states:

**Sphere Colors:**
- **Gray**: No loop recorded
- **Red**: Playing original loop
- **Green** (pulsing): Variation ready (press D1 to load)
- **Blue**: Playing variation

**Spice Level Display:**

Text shows current spice level with color coding:
- **0.0-0.3**: Blue text (conservative variations)
- **0.4-0.6**: Orange text (balanced creativity)
- **0.7-1.0**: Red text (experimental variations)

Updates in real-time as you turn CC 18 knob!

### AI Variation Generation

**Tool:** `src/drum_variation_ai.py`

**Watch Mode (Primary Usage):**

```bash
cd src
python drum_variation_ai.py --watch
```

Automatically generates variations when you record loops. Keep this running in a separate terminal.

**Manual Mode (Optional):**

```bash
cd src
python drum_variation_ai.py --track 0 --type gemini --temperature 0.8
```

**How it works:**

1. **File watching:** Python watchdog monitors `src/tracks/track_0/track_0_drums.txt`
2. **Auto-trigger:** When file changes (after recording), generation starts automatically
3. **Gemini API call:** Sends pattern with constraints:
   - Maintain total loop duration
   - Keep consistent tempo
   - Apply spice level for creativity control
   - Preserve drum pattern structure (kick/snare/hat classes)
4. **Save variation:** Writes to `src/tracks/track_0/variations/track_0_drums_var1.txt`
5. **OSC notification:** Sends `/chuloopa/variations_ready` to ChucK
6. **User loads:** Press D1 to hear the variation

**Spice Level Control:**

The "spice" parameter (0.0-1.0) controls variation creativity:
- **Low spice (0.0-0.3):** Subtle timing/velocity adjustments, maintains original structure
- **Medium spice (0.4-0.6):** Balanced changes, occasional ghost notes
- **High spice (0.7-1.0):** Bold transformations, polyrhythmic variations

Adjust with CC 18 knob, then press D#1 to regenerate.

**Why Gemini over Magenta:**

- Magenta required complex piano roll conversion from ChucK's format
- Conversion process was unreliable and produced unacceptable results
- Gemini works directly with symbolic CSV format
- Consistently maintains loop duration and tempo constraints
- OSC integration enables seamless live workflow
- Simple, reliable, and convenient alternative

---

## File Structure

```
CHULOOPA/
├── src/
│   ├── chuloopa_drums_v2.ck         # Main system (CURRENT)
│   ├── drum_variation_ai.py         # AI variation generator with OSC
│   ├── drum_sample_recorder.ck      # Training data collector
│   ├── feature_extraction.ck        # ChucK feature extraction
│   │
│   ├── tracks/                       # Generated drum data (auto-created)
│   │   └── track_0/
│   │       ├── track_0_drums.txt    # Original recording
│   │       └── variations/
│   │           └── track_0_drums_var1.txt  # AI-generated variation
│   │
│   ├── osc_test_chuck.ck            # OSC test (ChucK sender)
│   ├── osc_test_python.ck           # OSC test (ChucK receiver)
│   ├── osc_test_python.py           # OSC test (Python sender)
│   └── osc_test_python_alt.py       # OSC test (127.0.0.1 fix)
│
├── samples/                          # Drum samples
│   ├── kick.wav
│   ├── snare.wav
│   └── hat.WAV
│
├── requirements.txt                  # Python dependencies (OSC, Gemini, etc.)
├── train_classifier.py               # KNN training script
├── training_samples.csv              # Training data (generated)
├── drum_classifier.pkl               # Trained KNN model (generated)
│
├── docs/plans/
│   └── 2026-01-29-ai-variation-automation-design.md  # OSC integration design
│
├── README.md                         # This file
├── QUICK_START.md                    # Step-by-step guide
├── TESTING.md                        # Testing guide for OSC integration
└── CLAUDE.md                         # AI assistant context
```

**Note:** `src/tracks/track_0/` directory is auto-created on first recording.

---

## Next Steps

### Phase 2: AI Variation Generation ✅ (Current - January 2026)

**Completed:**

- [x] Gemini AI integration for drum pattern variations
- [x] OSC communication (Python ↔ ChucK)
- [x] Automatic variation generation (file watching)
- [x] Real-time spice level control (CC 18)
- [x] Visual feedback (ChuGL sphere states)
- [x] Queued variation toggle at loop boundaries
- [x] Single-track focused workflow

**In Progress:**

- [ ] Multi-variation support (generate 3-5 variants, random selection on toggle)
- [ ] Improved ChuGL visualizations (per-drum-hit feedback)

### Phase 3: Multi-Track Support (Planned - Q1 2026)

**Goals:**

- [ ] Expand to 3 simultaneous tracks
- [ ] Per-track variation control (independent spice levels)
- [ ] Track volume and mix controls (CC 46-53)
- [ ] Visual feedback for all tracks (3 spheres)
- [ ] Cross-track variation coherence

### Phase 4: Enhanced Features (Future)

**Planned:**

- [ ] Drag-and-drop UI for custom drum samples
- [ ] Pattern similarity visualization
- [ ] Real-time classification confidence display
- [ ] Save/load preset collections
- [ ] MIDI sync output for DAW integration
- [ ] Live pattern evolution mode (gradual variation over time)

---

## Research Goals

**Target Conference:** ACM Creativity and Cognition 2026

**Paper Title:** _"Personal Drum Machines: User-Trainable Beatbox Classification with Real-Time AI Variations for Live Performance"_

**Novel Contributions:**

1. User-trainable beatbox classifier (personalized, not generic)
2. Minimal training data (10 samples per class vs. 100s)
3. Live performance focus (<50ms latency)
4. **OSC-based Python-ChucK integration for seamless AI workflow**
5. **Real-time spice control with visual feedback**
6. AI-powered variation generation maintaining musical constraints
7. Queued action system for musical loop boundary transitions
8. End-to-end system from training to performance to variation

**Design Decision:** Initial experiments with Magenta's piano roll conversion proved unreliable. Switching to Gemini API with direct symbolic format and OSC communication produced consistently reliable variations while maintaining loop duration and tempo constraints, enabling seamless live performance workflows.

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

**Python (for AI variations):**

- Python 3.10+
- `python-osc` - OSC communication
- `watchdog` - File watching for auto-generation
- `google-generativeai` - Gemini API
- `numpy` - Algorithmic variations
- `python-dotenv` - Environment variables

Install Python dependencies:
```bash
pip install -r requirements.txt
```

**Required:** `GEMINI_API_KEY` environment variable for AI variations

**Hardware:**

- MIDI controller with CC 18 knob support
- Microphone for beatbox input

---

## Troubleshooting

**Python watch mode not starting:**

- Must run from `src` directory: `cd src && python drum_variation_ai.py --watch`
- Check dependencies: `pip install -r requirements.txt`
- Verify port 5000 is available: `lsof -i :5000`
- Kill conflicting processes: `kill <PID>`

**ChucK not receiving OSC messages:**

- Verify ChucK script running from `src` directory
- Check port 5001 is available: `lsof -i :5001`
- Python must use `127.0.0.1` not `localhost` (pythonosc issue)
- Look for "OSC listener started on port 5001" in ChucK output
- Test with `src/osc_test_python_alt.py` and `src/osc_test_python.ck`

**No MIDI devices found:**

- Check MIDI controller connection
- Verify MIDI port in code (line 62: `0 => int MIDI_DEVICE;`)
- Test MIDI: `python TESTMIDIINPUT.py`

**Classifier accuracy poor:**

- Record more training samples (20+ per class)
- Ensure consistent beatbox technique
- Delete `training_samples.csv` and re-record with `drum_sample_recorder.ck`
- ChucK auto-trains on startup

**Drums out of sync:**

- System uses master sync - should not happen
- Check console for drift warnings
- Verify delta_time in exported files

**AI variation generation fails:**

- Ensure `GEMINI_API_KEY` environment variable is set
- Check internet connection for Gemini API access
- System auto-falls back to `groove_preserve` algorithm if Gemini fails
- Check Python terminal for error details
- Verify `src/tracks/track_0/track_0_drums.txt` exists

**Variation doesn't maintain loop duration:**

- This should not happen with Gemini implementation
- Check Python terminal for "duration mismatch" warnings
- Verify generated file has correct total loop duration in header

**Spice knob not working:**

- Verify CC 18 is mapped correctly: `python TESTMIDIINPUT.py`
- Check ChucK console for "Spice level: XX%" messages
- ChuGL window must be open to see visual feedback
- Turn knob slowly to see updates

**OSC port conflicts:**

- Kill conflicting processes: `lsof -i :5000` and `lsof -i :5001`
- Restart both Python and ChucK
- Check firewall settings if on macOS

---

## Credits

**Developer:** Paolo Sandejas
**Institution:** CalArts - Music Technology MFA
**Advisor:** Ajay Kapur, Jake Cheng
**Year:** 2025

**Inspired by:**

- Google's Gemini AI (variation generation)
- Magenta's GrooVAE (initial exploration)
- Living Looper (nn_tilde)
- Intelligent Instruments Lab's Notochord
