# CHULOOPA

**An intelligent drum looper that transforms beatbox into transcribed drum patterns with AI-powered variations.**

<p align="center">
  <img src="docs/internal/paper/assets/chuloopa%20-%20active%20state.png" alt="CHULOOPA active variation state" />
  <br/>
  <em>Figure 1: CHULOOPA UI active state</em>
</p>

## Overview

CHULOOPA is a real-time drum looping system built in ChucK that uses machine learning to transcribe vocal beatboxing into drum patterns (kick, snare, hat). The system provides immediate audio feedback during recording, automatically exports symbolic drum data, generates AI-powered variations, and enables seamless pattern switching for live performance.

**Key Innovation:** Making drum programming accessible to amateur beatboxers through personalized ML classification combined with AI-powered pattern variations that maintain musical coherence.

### Core Features

- **Real-time Beatbox Transcription** - Vocal input → Drum samples (instant feedback)
- **Single-Track Looper** - Master sync system (multi-track coming in Phase 3)
- **KNN Classifier** - User-trainable personalized drum detection
- **AI Variation Generation** - Local transformer-LSTM model for offline drum pattern variations with real-time spice control
- **OSC Integration** - Automatic Python-ChucK communication for seamless AI workflow
- **Ableton Live Routing** - MIDI output via macOS IAC Driver for full DAW integration (Drum Rack, FX, mixing)
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

- Press **K**: Set label to kick, then beatbox (10+ samples)
- Press **S**: Set label to snare, then beatbox (10+ samples)
- Press **H**: Set label to hi-hat, then beatbox (10+ samples)
- Press **N**: Disable recording (pause between classes)
- Press **E** or **Q**: Export training data to `training_samples.csv`
- Press **P**: Start live playback test — beatbox freely, hear KNN classification in real-time
- Press **R**: Full reset — erase all samples and start over
- Press **ESC**: Close window

**Workflow:**

1. Record K/S/H samples (10+ each)
2. Press **E** to export
3. Press **P** to test — if classification sounds wrong, press **R** and re-record

This creates `training_samples.csv` with your personalized beatbox samples.

### 2. Start Python AI Engine (Terminal 1)

**IMPORTANT: Must run from src directory**

```bash
cd src
python drum_variation_generator.py --watch
```

This starts the AI variation engine that pre-generates a bank of 5 variations at different spice levels using Jake Chen's rhythmic_creator model (local inference, no API required).

### 3. Start Spice Detector (Terminal 2)

**IMPORTANT: Must run from src directory**

```bash
cd src
chuck spice_detector.ck
```

This analyzes live audio (guitar/vocal/room) and sends a composite spice level via OSC to both Python and ChucK every 500ms.

> **Stereo mode (performance):** `chuck --channels:2 src/spice_detector.ck` — enables CC 75 knob to blend guitar vs. vocal input.

### 4. Run CHULOOPA (Terminal 3)

**IMPORTANT: Must run from src directory**

```bash
cd src
chuck chuloopa_main.ck
```

> **Ableton setup required:** Enable IAC Driver in macOS Audio MIDI Setup → create a MIDI track in Ableton → input: IAC Driver Bus 1, Monitor: In → load Drum Rack → assign C1(36)=Kick, D1(38)=Snare, F#1(42)=Hi-hat. See [Ableton Integration](#ableton-integration) below.

**Note:** The KNN classifier automatically trains on startup using your `training_samples.csv` file. OSC connections are established automatically.

### 5. MIDI Controls (Single Track)

**Recording (Press & Hold):**

- **MIDI Note 36** (C1): Record track 0
  - _Hear drum samples in real-time as you beatbox!_
  - Release to stop recording
  - Python auto-generates full variation bank when recording completes

**Clearing:**

- **MIDI Note 37** (C#1): Clear track 0

**Variation Control:**

- **MIDI Note 38** (D1): Regenerate full variation bank
  - Triggers Python to regenerate all 5 spice-level variants
  - Variation auto-selection is driven by audio spice (no manual toggle needed)

**Spice Ceiling:**

- **CC 74**: Spice ceiling knob (0.0-1.0)
  - Caps how high the audio-driven spice can go
  - `spice_detector.ck` is the source of truth for actual spice level
  - **Low (0.0-0.3)**: Conservative ceiling — only subtle variations selected
  - **Medium (0.4-0.6)**: Balanced ceiling
  - **High (0.7-1.0)**: Full range — bold variations allowed

**Future (3-Track Version):**

- Additional tracks will use Notes 40-45 and CC controls 46-53

---

## Complete Workflow

### Initial Setup (One-Time)

1. **Terminal 1:** Start Python AI engine
   ```bash
   cd src && python drum_variation_generator.py --watch
   ```
2. **Terminal 2:** Start spice detector
   ```bash
   cd src && chuck spice_detector.ck
   ```
3. **Terminal 3:** Start ChucK (Ableton pipeline)
   ```bash
   cd src && chuck chuloopa_main.ck
   ```
4. **Verify:** All terminals show OSC connections established

### Recording a Loop

1. **Press & hold MIDI Note 36** (C1) on your MIDI controller
2. **Beatbox:** "BOOM tss tss BOOM"
3. **System responds:**
   - Detects onsets (spectral flux)
   - Classifies each hit using MFCC-13 KNN (kick/snare/hat)
   - **Plays drum samples immediately** (real-time feedback)
   - Stores timing data with delta_time precision
4. **Release Note 36** to stop
   - Auto-exports to `src/tracks/track_0/track_0_drums.txt`
   - Starts looping the drum pattern
   - **Python auto-generates bank of 5 variations** (spice levels 0.2/0.4/0.6/0.8/1.0)
   - ChucK gates auto-switching on `/chuloopa/bank_ready` OSC

### Audio-Driven Variation Selection

Variation selection is **automatic** — no manual toggling needed:

1. `spice_detector.ck` analyzes live audio every 500ms
2. Sends `/chuloopa/spice` to both Python and ChucK
3. ChucK selects the variation whose spice level best matches the current audio energy
4. Variation switches happen at loop boundaries (rolling 4-bar window averages spice)
5. **CC 74** sets a ceiling to cap how spicy it can get

### Regenerating the Variation Bank

1. **Press MIDI Note 38** (D1) to trigger full bank regeneration
2. Python regenerates all 5 variants and sends `/chuloopa/bank_ready` when done
3. Auto-selection resumes with the new bank

### Future: Layering Multiple Tracks

Multi-track support coming in Phase 3:

1. Record Track 0 (Note 36/C1): Kick pattern
2. Record Track 1 (Note 40/E1): Snare pattern
3. Record Track 2 (Note 41/F1): Hi-hat pattern
4. All tracks stay perfectly in sync (master sync system)

---

## Ableton Integration

`chuloopa_drums_v3_ableton.ck` routes all drum hits as MIDI notes to Ableton Live via the macOS **IAC Driver** (built-in virtual MIDI bus), giving you full access to Ableton's Drum Rack, FX chains, and mixing.

### Architecture

```
ChucK (MidiOut) → IAC Driver Bus 1 → Ableton MIDI Track → Drum Rack
```

### MIDI Note Mapping (GM Standard)

| Drum   | MIDI Note | Pitch |
| ------ | --------- | ----- |
| Kick   | 36        | C1    |
| Snare  | 38        | D1    |
| Hi-hat | 42        | F#1   |

### macOS IAC Driver Setup (one-time)

1. Open **Audio MIDI Setup** (Spotlight → "Audio MIDI Setup")
2. **Window → Show MIDI Studio**
3. Double-click **IAC Driver**
4. Check **"Device is online"**
5. Confirm **Bus 1** exists → click Apply

### Ableton Live Setup

1. Create a new **MIDI track**
2. Set MIDI input to **IAC Driver (Bus 1)**
3. Set Monitor to **In**
4. Load a **Drum Rack** on the track
5. Drop samples onto pads: C1 → Kick, D1 → Snare, F#1 → Hi-hat

### Differences from V3 standalone

| Feature           | V3 standalone (chuloopa_drums_v3.ck) | V3 Ableton (chuloopa_drums_v3_ableton.ck) |
| ----------------- | ------------------------------------ | ----------------------------------------- |
| Audio output      | ChucK SndBuf (WAV files)             | Ableton Drum Rack via MIDI                |
| Sound design      | Fixed WAV samples                    | Any samples/synths in Ableton             |
| FX                | None                                 | Full Ableton FX chain                     |
| Velocity          | Applied to SndBuf gain               | Sent as MIDI velocity (1–127)             |
| ChuGL visuals     | ✅                                   | ✅ (unchanged)                            |
| Recording/KNN/OSC | ✅                                   | ✅ (unchanged)                            |
| Ableton required  | ❌                                   | ✅                                        |

---

## Technical Architecture

### Complete Pipeline

**Current pipeline (v4 + drum_variation_generator.py + spice_detector.ck):**

```
1. spice_detector.ck (Terminal 2) analyzes live audio → sends /chuloopa/spice via OSC
   ↓
2. drum_variation_generator.py (Terminal 1) pre-generates bank of 5 variations
   (spice levels 0.2/0.4/0.6/0.8/1.0) → sends /chuloopa/bank_ready when done
   ↓
3. chuloopa_main.ck (Terminal 3) records beatbox → MFCC-13 KNN → Ableton MIDI
   ↓
4. Loop exported → Python watchdog auto-generates variation bank
   ↓
5. Audio-driven spice (rolling 4-bar average) selects matching variation at loop boundary
   ↓
6. CC 74 sets spice ceiling (caps how high audio-driven spice can go)
   ↓
7. D1 (Note 38) triggers full bank regeneration on demand
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

- **Algorithm:** K-Nearest Neighbors (k=3) using ChucK's KNN2
- **Features:** MFCC-13 (13 mel-frequency cepstral coefficients)
- **Confidence threshold:** 0.55 minimum probability to accept classification
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

| Address                         | Direction                     | Data Type | Purpose                                   |
| ------------------------------- | ----------------------------- | --------- | ----------------------------------------- |
| `/chuloopa/generation_progress` | Python → ChucK                | string    | Status updates during generation          |
| `/chuloopa/bank_ready`          | Python → ChucK                | int       | Signals all 5 variations are ready        |
| `/chuloopa/variation_available` | Python → ChucK                | int,int   | Index + spice level of each ready variant |
| `/chuloopa/regenerate`          | ChucK → Python                | none      | Request full bank regeneration            |
| `/chuloopa/spice`               | spice_detector → Python+ChucK | float     | Current audio-driven spice (0.0-1.0)      |
| `/chuloopa/clear`               | ChucK → Python                | none      | Track cleared notification                |

**Workflow:**

1. User records loop (C1) in ChucK
2. ChucK exports `track_0_drums.txt`
3. Python watchdog detects file change
4. Python generates bank of 5 variations (spice 0.2/0.4/0.6/0.8/1.0)
5. Python sends `/chuloopa/bank_ready` to ChucK
6. `spice_detector.ck` streams `/chuloopa/spice` every 500ms
7. ChucK auto-selects best variation at each loop boundary based on audio spice
8. User presses D1 to trigger full bank regeneration on demand

### ChuGL Visual Feedback

The visualization window shows a single sphere with color-coded states:

**Sphere Colors:**

- **Gray**: No loop recorded
- **Red**: Playing original loop
- **Green**: Variation bank ready
- **Blue**: Playing a variation (auto-selected by spice)

**Spice Level Display:**

Text shows current audio-driven spice with color coding:

- **0.0-0.3**: Blue text (conservative)
- **0.4-0.6**: Orange text (balanced)
- **0.7-1.0**: Red text (experimental)

Updates every 500ms from `spice_detector.ck`.

### AI Variation Generation

**Tool:** `src/drum_variation_generator.py`

**Watch Mode (Primary Usage):**

```bash
cd src
python drum_variation_generator.py --watch
```

Automatically generates a bank of 5 variations when you record loops using Jake Chen's rhythmic_creator model. Keep this running in a separate terminal.

**How it works (v2 variation bank approach):**

1. **File watching:** Python watchdog monitors `src/tracks/track_0/track_0_drums.txt`
2. **Auto-trigger:** When file changes (after recording), bank generation starts automatically
3. **Bank generation:** Generates 5 variants at fixed spice levels (0.2 / 0.4 / 0.6 / 0.8 / 1.0)
   - For each level: converts pattern to MIDI triplet format, generates continuation tokens
   - Spice maps to token count ceiling (max 3× original context)
   - Time-warps each variant to match original loop duration exactly
4. **Progressive notification:** Sends `/chuloopa/variation_available` as each variant completes
5. **Bank complete:** Sends `/chuloopa/bank_ready` when all 5 variants are ready
6. **Auto-selection:** ChucK picks the variant matching current audio spice (no user action needed)

**Model Architecture (rhythmic_creator):**

- **Author:** Jake Chen (Zhaohan Chen), CalArts MFA Thesis 2025
- **Paper:** "Music As Natural Language: Deep Learning Driven Rhythmic Creation"
- **Architecture:** Transformer-LSTM Hybrid (4.49M parameters)
  - 6 Transformer blocks (192-dim embeddings, 6 attention heads)
  - 2 LSTM layers (64 hidden units each)
  - Feed-forward network for predictions
- **Performance:** ~3-5 seconds generation time on CPU
- **Operation:** Fully offline, no API dependencies

**Spice Level Control:**

The "spice" parameter (0.0-1.0) maps to a **token count ceiling** for variation creativity — higher spice allows the rhythmic_creator model to generate more additional tokens (more new content) on top of the original context. The ceiling is capped at 3× the original token count to keep output musical.

- **Low spice (0.0-0.3):** Conservative — minimal additional tokens, close to original
- **Medium spice (0.4-0.6):** Balanced — moderate new content, light embellishment
- **High spice (0.7-1.0):** Experimental — maximum tokens (up to 3× context), bold variations

Adjust with CC 74 knob, then press D#1 to regenerate.

**Why rhythmic_creator over Gemini/Magenta:**

- **Offline operation:** No API keys or internet required (critical for live performance)
- **Fast inference:** ~3-5s vs 5-10s for Gemini API
- **Reliable:** Consistent generation without rate limits or network issues
- **Continuation-based:** Uses model's natural sequence extension as variations
- **Preserves timing:** Proportional time-warping maintains non-quantized groove
- **OSC integration:** Seamless live workflow with automatic generation

**Alternative: Gemini API option** (`--type gemini`) available in `drum_variation_gemini.py` for studio contexts where internet is available and more sophisticated musical reasoning is desired.

---

## File Structure

```
CHULOOPA/
├── src/
│   ├── chuloopa_main.ck         # MAIN: Audio-driven spice + variation bank (Ableton via IAC)
│   ├── drum_variation_generator.py      # MAIN: Variation bank engine (5 variants, bank_ready OSC)
│   ├── spice_detector.ck            # MAIN: Audio-driven spice → OSC (500ms updates)
│   │
│   ├── drum_sample_recorder.ck      # Training data collector (run once before main system)
│   ├── rhythmic_creator_model.py    # Wrapper for local transformer-LSTM variation model
│   ├── format_converters.py         # Converts between drum pattern formats
│   ├── feature_extraction.ck        # ChucK feature extraction utilities
│   │
│   ├── tracks/                       # Generated drum data (auto-created)
│   │   └── track_0/
│   │       ├── track_0_drums.txt    # Original recording
│   │       └── variations/
│   │           └── track_0_drums_var1.txt  # AI-generated variation
│   │
│   ├── chuloopa_drums_v3_ableton.ck # Legacy: single-variant Ableton mode
│   ├── chuloopa_drums_v3.ck          # Legacy: standalone (built-in WAV, no Ableton)
│   ├── drum_variation_ai.py         # Legacy: single-variant AI engine
│   │
│   ├── osc_test_chuck.ck            # OSC test (ChucK sender)
│   ├── osc_test_python.ck           # OSC test (ChucK receiver)
│   └── osc_test_python_alt.py       # OSC test (127.0.0.1 fix)
│
├── samples/                          # Drum samples
│   ├── kick.wav
│   ├── snare.wav
│   └── hat.WAV
│
├── requirements.txt                  # Python dependencies (OSC, PyTorch, etc.)
├── training_samples.csv              # Training data (generated)
├── drum_classifier.pkl               # Trained KNN model (generated)
│
├── README.md                         # This file
└── CLAUDE.md                         # AI assistant context
```

**Note:** `src/tracks/track_0/` directory is auto-created on first recording.

---

## Next Steps

### Phase 2: AI Variation Generation ✅ (Complete - March 2026)

**Completed:**

- [x] Local AI integration using rhythmic_creator model (Jake Chen, CalArts MFA 2025)
- [x] Continuation-based variation generation approach
- [x] OSC communication (Python ↔ ChucK ↔ spice_detector)
- [x] Automatic variation bank generation (file watching, 5 variants per loop)
- [x] Audio-driven spice detection (`spice_detector.ck` → OSC → Python + ChucK)
- [x] Auto-selection: variation switches at loop boundaries based on audio spice
- [x] CC 74 as spice ceiling (caps how high audio-driven spice can go)
- [x] MFCC-13 KNN classification (upgraded from 5-band spectral)
- [x] Silence debounce (mutes drums during silence gaps)
- [x] Weighted probabilistic variation selection (rolling 4-bar window)
- [x] Single-track focused workflow
- [x] Offline operation (no API dependencies)

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

**Design Decision:** Initial experiments with Magenta's GrooVAE and piano roll conversion proved unreliable. We then switched to Gemini API with direct symbolic format, which worked well but required internet connectivity. Finally, we integrated Jake Chen's rhythmic_creator transformer-LSTM model for fully offline operation. The continuation-based approach (using the model's sequence extension as variations, time-warped to match loop duration) produces musically coherent variations while maintaining loop constraints. This enables reliable live performance workflows without external API dependencies.

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
- `torch` - PyTorch for rhythmic_creator model
- `numpy` - Algorithmic variations
- `scikit-learn` - KNN classifier training
- `google-generativeai` - Gemini API (optional, for alternative variation engine)
- `python-dotenv` - Environment variables

Install Python dependencies:

```bash
pip install -r requirements.txt
```

**Optional:** `GEMINI_API_KEY` environment variable for Gemini-based variations (alternative to default rhythmic_creator model)

**Hardware:**

- MIDI controller with CC 74 knob support
- Microphone for beatbox input

---

## Troubleshooting

**Python watch mode not starting:**

- Must run from `src` directory: `cd src && python drum_variation_generator.py --watch`
- Check dependencies: `pip install -r requirements.txt`
- Verify port 5000 is available: `lsof -i :5000`
- Kill conflicting processes: `kill <PID>`

**ChucK not receiving OSC messages:**

- Verify all ChucK scripts running from `src` directory
- Check ports 5001 is available: `lsof -i :5001`
- Python must use `127.0.0.1` not `localhost` (pythonosc issue)
- Look for "OSC listener started on port 5001" in ChucK output
- Test with `src/osc_test_python_alt.py` and `src/osc_test_python.ck`

**No MIDI devices found:**

- Check MIDI controller connection
- Verify MIDI port in code (line 62: `0 => int MIDI_DEVICE;`)
- Test MIDI: `python TESTMIDIINPUT.py`

**Ableton not receiving drum hits (v3_ableton):**

- Confirm IAC Driver is online in Audio MIDI Setup
- Set Ableton MIDI track input to "IAC Driver Bus 1" and Monitor to "In"
- Check ChucK output for `"Opened MIDI output: IAC Driver Bus 1"`
- Ensure Drum Rack pads are mapped to C1(36), D1(38), F#1(42)
- If LPD8 not detected as MIDI input, ChucK prints all available ports on startup — use that to verify port numbering

**Classifier accuracy poor:**

- Record more training samples (20+ per class)
- Ensure consistent beatbox technique
- Delete `training_samples.csv` and re-record with `drum_sample_recorder.ck`
- ChucK auto-trains on startup

**Drums out of sync:**

- System uses master sync - should not happen
- Check console for drift warnings
- Verify delta_time in exported files

**AI variation bank generation fails:**

- rhythmic_creator model works offline without API keys
- Check Python terminal for error details
- Verify `src/tracks/track_0/track_0_drums.txt` exists
- Ensure PyTorch is installed: `pip install torch`
- Confirm rhythmic_creator model weights exist in `src/models/`

**Variation doesn't maintain loop duration:**

- This should not happen with rhythmic_creator's time-warping implementation
- Check Python terminal for "duration mismatch" warnings
- Verify generated file has correct total loop duration in header
- Check that continuation hits are being extracted correctly (timestamps > original_end)

**Spice ceiling knob not working:**

- Verify CC 74 is mapped correctly: check `src/midi_monitor.ck`
- CC 74 sets a ceiling — actual spice comes from `spice_detector.ck`
- Ensure `spice_detector.ck` is running (Terminal 2)
- ChuGL window must be open to see visual feedback

**OSC port conflicts:**

- Kill conflicting processes: `lsof -i :5000` and `lsof -i :5001`
- Restart both Python and ChucK
- Check firewall settings if on macOS

---

## Credits

**Developer:** Paolo Sandejas
**Institution:** CalArts - Music Technology MFA
**Advisors:** Ajay Kapur, Jake Cheng
**Year:** 2026

**AI Model Integration:**

- **rhythmic_creator** by Jake Chen (Zhaohan Chen), CalArts MFA 2025
  - Paper: "Music As Natural Language: Deep Learning Driven Rhythmic Creation"
  - Transformer-LSTM hybrid for MIDI sequence generation
  - Adapted for continuation-based loop variation generation

**Inspired by:**

- Jake Chen's rhythmic_creator (local AI variation generation)
- Google's Gemini AI (alternative variation engine)
- Magenta's GrooVAE (initial exploration)
- Living Looper (nn_tilde)
- Intelligent Instruments Lab's Notochord
