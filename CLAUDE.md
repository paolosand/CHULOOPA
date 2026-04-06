# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CHULOOPA is a real-time drum looping system built in ChucK that uses machine learning to transcribe vocal beatboxing into drum patterns (kick, snare, hat). The system provides immediate audio feedback during recording, automatically exports symbolic drum data, and enables seamless pattern switching for live performance.

**Current Focus (March 2026):** User-trainable personalized drum machine with AI variation generation for live performance using:
- Beatbox input → Onset detection → KNN classification → Pattern looping → **Ableton via IAC Driver**
- **OSC-based Python-ChucK integration** for automatic AI variation generation
- **Real-time spice control** via MIDI CC 74 knob (spice = token count ceiling, max 3×)
- Single-track focus (multi-track planned for Phase 3)
- **V4 pipeline:** Audio-driven spice detection (`spice_detector.ck`) + 5-variant bank (`drum_variation_generator.py`) + weighted probabilistic variation selection + silence debounce (`chuloopa_main.ck`)

**Target:** AIMC (AI Music Creativity) submission

## Running the System

### Complete Workflow (Drum System - CURRENT)

**Step 1: Record Training Samples (One-time, ~5 minutes)**
```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"

# Record training samples (10 each of kick/snare/hat)
chuck src/drum_sample_recorder.ck
# Press 1 for kick, 2 for snare, 3 for hat, Q to quit
# Creates: training_samples.csv
```

**Step 2: Start Python Watch Mode (Terminal 1)**
```bash
cd src
python drum_variation_ai.py --watch
# Starts OSC server on port 5000, sends to ChucK on port 5001
# Auto-generates variations when loops are recorded
# Spice maps to token count ceiling (max 3× original context)
```

**Step 3: Run CHULOOPA (Terminal 2)**

Stable — Ableton via IAC Driver (recommended):
```bash
cd src
chuck chuloopa_drums_v3_ableton.ck
# KNN classifier trains automatically on startup using training_samples.csv
# Drum hits routed to Ableton Drum Rack via IAC Driver MIDI
```

Standalone — no Ableton required:
```bash
cd src
chuck chuloopa_drums_v3.ck
```

**V4 pipeline (3 terminals):**
```bash
cd src && python drum_variation_generator.py --watch  # Terminal 1: generates 5-variant bank + bank_ready OSC
cd src && chuck spice_detector.ck                 # Terminal 2: audio-driven spice → OSC
cd src && chuck chuloopa_main.ck              # Terminal 3: weighted variation auto-selection
```
Note: v4 requires drum_variation_generator.py (not v1). v4 gates auto-switching on `/chuloopa/bank_ready` and `variation_available[]` OSC messages, which only v2 sends. `/chuloopa/bank_ready` fires after all 5 slots finish generating and the bank is sorted by deviation score (least to most deviant).

**MIDI Controls (Single Track):**
- **Note 36** (C1): Press & hold to record track 0
- **Note 37** (C#1): Clear track 0
- **Note 38** (D1): Toggle variation mode ON/OFF (queued at loop boundary)
- **Note 39** (D#1): Regenerate variations with current spice level
- **CC 74**: Spice level knob (0.0-1.0, real-time visual feedback; in v4 = spice ceiling)

**Note:** Multi-track support (3 tracks) planned for Phase 3

### Legacy System (Melody-based - ARCHIVED)

```bash
# Original melody-based system (preserved as backup plan)
chuck src/chuloopa_main.ck
```

## Architecture Overview

### Drum System Architecture (STABLE - chuloopa_drums_v3_ableton.ck)

**Setup Phase (One-time, ~5 minutes):**
```
User beatboxes 10 samples each of kick/snare/hat
  ↓
Onset detection extracts timing (spectral flux)
  ↓
Feature extraction (flux, centroid, energy, band energies)
  ↓
Train personalized KNN classifier (k=3)
  ↓
Save drum_classifier.pkl
```

**Performance Phase (Real-time):**
```
Python Watch Mode (Terminal 1) + ChucK (Terminal 2)
  ↓
OSC Connection Established (ports 5000 ↔ 5001)
  ↓
Live beatbox input
  ↓
Onset detection (spectral flux + adaptive thresholding)
  ↓
Classification (personalized KNN: kick/snare/hat)
  ↓
Real-time drum sample playback (immediate feedback)
  ↓
Symbolic drum data export (src/tracks/track_0/track_0_drums.txt with delta_time)
  ↓
Python watchdog detects file change
  ↓
AI variation generation (Gemini API with current spice level)
  ↓
OSC: /chuloopa/variations_ready → ChucK (sphere turns green)
  ↓
User toggles variation (D1) or adjusts spice (CC 74) + regenerates (D#1)
  ↓
Load/swap patterns at loop boundaries (queued action system)
```

**Key Innovations:**
- **Drums-only mode:** No audio loop playback, only classified drum samples play back in real-time
- **OSC integration:** Seamless Python-ChucK communication for automatic AI workflow
- **Real-time spice control:** MIDI CC 74 knob adjusts variation creativity with visual feedback

## Key Technical Details

### Onset Detection (Drum System - CURRENT)
- **Algorithm:** Spectral flux with adaptive thresholding
- **Frame size:** 512 samples, hop size 128 samples
- **Adaptive thresholding:** 1.5× running mean of flux history
- **Min onset strength:** 0.005 (configurable in code)
- **Debouncing:** 150ms minimum between onsets

### KNN Classification (Drum System - CURRENT)
- **Algorithm:** K-Nearest Neighbors (k=3)
- **Feature vector (5 dimensions):**
  1. Spectral flux (onset strength)
  2. RMS energy (loudness)
  3. Spectral band 1 (low frequencies - distinguishes kicks)
  4. Spectral band 2 (mid frequencies)
  5. Spectral band 5 (high frequencies - distinguishes hats)
- **Training:** User-specific (10 samples per class: kick, snare, hat)
- **Fallback:** Heuristic classifier if KNN fails to load
- **Target accuracy:** >85% for personalized models

### Master Loop Sync (Prevents Drift)
- First recorded loop becomes master reference
- Subsequent loops auto-adjusted to musical ratios: [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0]
- Algorithm finds closest multiplier and adjusts loop length

### Queued Action System (Pattern Switching)
- MIDI actions queue during loop cycle (inspired by chuck_sample_code/chuck_looper/)
- Master coordinator executes at loop boundaries
- Prevents overlap and maintains sync
- Playback session IDs invalidate old scheduled hits

### Delta Time Format (Precise Loop Timing)
- Exported files include time until next hit
- Last hit's delta_time = time until loop end
- Ensures perfect loop timing when loading from files

### OSC Communication (Python ↔ ChucK)
- **Ports:** ChucK sends to `localhost:5000`, Python sends to `127.0.0.1:5001`
- **Critical:** Python must use `127.0.0.1` not `localhost` (pythonosc resolution issue)
- **ChucK setup:** `oin.listenAll()` instead of address filtering for reliability
- **Messages:**
  - `/chuloopa/generation_progress` (Python → ChucK): Status updates
  - `/chuloopa/variations_ready` (Python → ChucK): Variation complete
  - `/chuloopa/regenerate` (ChucK → Python): Request new variation
  - `/chuloopa/spice_level` (ChucK → Python): Update spice (0.0-1.0)
  - `/chuloopa/clear` (ChucK → Python): Track cleared notification
- **Workflow:** File change → watchdog → generation → OSC notification → visual feedback

### ChuGL Visual Feedback
- **Sphere colors:**
  - Gray: No loop recorded
  - Red: Playing original loop
  - Green (pulsing): Variation ready (press D1)
  - Blue: Playing variation
- **Spice level display:**
  - 0.0-0.3: Blue text (conservative)
  - 0.4-0.6: Orange text (balanced)
  - 0.7-1.0: Red text (experimental)
- Updates in real-time with CC 74 knob

## File Structure

```
CHULOOPA/
├── src/
│   ├── chuloopa_drums_v3_ableton.ck  # STABLE: Main drum looper → Ableton via IAC
│   ├── chuloopa_drums_v3.ck          # Standalone: no Ableton required
│   ├── chuloopa_main.ck          # IN PROGRESS: audio-driven spice + variation bank
│   ├── drum_variation_ai.py          # STABLE: AI variation engine with OSC
│   ├── drum_variation_generator.py       # IN PROGRESS: variation bank engine (5 variants)
│   ├── spice_detector.ck             # IN PROGRESS: audio → spice → OSC
│   ├── drum_sample_recorder.ck       # Training data collector (RUN FIRST!)
│   ├── feature_extraction.ck         # ChucK feature extraction
│   │
│   ├── tracks/                        # Generated drum data (auto-created)
│   │   └── track_0/
│   │       ├── track_0_drums.txt     # Original recording
│   │       └── variations/
│   │           └── track_0_drums_var1.txt  # AI-generated variation
│   │
│   ├── osc_test_chuck.ck             # OSC test (ChucK sender)
│   ├── osc_test_python.ck            # OSC test (ChucK receiver)
│   ├── osc_test_python.py            # OSC test (Python sender)
│   └── osc_test_python_alt.py        # OSC test (127.0.0.1 fix)
│
├── samples/                           # Drum samples
│   ├── kick.wav
│   ├── snare.wav
│   └── hat.WAV
│
├── requirements.txt                   # Python dependencies (OSC, Gemini, etc.)
├── train_classifier.py                # KNN training script
├── training_samples.csv               # Training data (generated)
├── drum_classifier.pkl                # Trained KNN model (generated)
│
├── README.md                          # Project overview
├── CLAUDE.md                          # This file
│
└── docs/
    └── internal/
        ├── QUICK_START.md             # Step-by-step user guide
        ├── TESTING.md                 # OSC integration testing guide
        ├── LATENCY_ANALYSIS.md        # ~25ms latency measurements (for paper)
        ├── RHYTHMIC_CREATOR_QUICKSTART.md  # AI model quick start
        ├── PAPER_EVALUATION_RUBRIC.md # AIMC evaluation criteria
        ├── GETTING_MODELS_FROM_JAKE.md
        ├── evaluation/                # 5 evaluation result files (data for paper)
        └── paper/                     # Paper drafts + assets
            ├── paper.md
            ├── paper - edit pao.md
            ├── rrl.md
            ├── conferences.md
            ├── CONDENSED_VERSION_NOTES.md
            ├── LATEX_README.md
            ├── PAPER_EVALUATION_2026-03-12.md
            ├── chuloopa_aimc2026.tex
            ├── chuloopa_aimc2026_condensed.tex
            ├── references.bib
            └── assets/                # UI screenshots for paper/README
```

## MIDI Controller Mapping

**CHULOOPA Drums V2 (CURRENT - Single Track):**

**Recording (Press & Hold):**
- **MIDI Note 36** (C1): Record track 0
  - Real-time drum feedback during recording
  - Auto-exports to src/tracks/track_0/track_0_drums.txt on release
  - Python auto-generates variation via OSC

**Clearing:**
- **MIDI Note 37** (C#1): Clear track 0 (immediate)

**Variation Control:**
- **MIDI Note 38** (D1): Toggle variation mode ON/OFF
  - Queued at loop boundary for smooth transition
  - ON: Loads src/tracks/track_0/variations/track_0_drums_var1.txt (sphere turns blue)
  - OFF: Loads original (sphere turns red)
- **MIDI Note 39** (D#1): Regenerate variations with current spice level
  - Sends `/chuloopa/regenerate` OSC message to Python
  - Python generates new variation and sends back `/chuloopa/variations_ready`

**Spice Control:**
- **CC 74**: Spice level knob (0.0-1.0)
  - Sends `/chuloopa/spice_level` OSC message to Python
  - Real-time visual feedback in ChuGL (blue/orange/red text)
  - Low (0.0-0.3): Conservative variations
  - Medium (0.4-0.6): Balanced creativity
  - High (0.7-1.0): Experimental variations

**Future (Phase 3 - Multi-Track):**
- Notes 40-45 and CC 46-53 reserved for tracks 1-2

## Current Development Status

**✅ Phase 1 Complete (December 2025):**
- ✅ Onset detection implemented and tested (spectral flux)
- ✅ KNN classifier training pipeline complete
- ✅ Real-time drum transcription working
- ✅ Single-track looper with master sync
- ✅ Real-time drum playback (drums-only mode)
- ✅ Queued action system for smooth transitions
- ✅ Delta_time format for precise loop timing
- ✅ File loading/swapping at loop boundaries
- ✅ Playback session IDs prevent overlap

**✅ Phase 2 Complete (January 2026):**
- ✅ OSC integration (Python ↔ ChucK)
- ✅ Automatic variation generation (file watching)
- ✅ AI-powered drum pattern variations (rhythmic_creator by default, Gemini API optional)
- ✅ Real-time spice control (CC 74 knob)
- ✅ ChuGL visual feedback (color-coded sphere states)
- ✅ Queued variation toggle at loop boundaries
- ✅ Single-track focused workflow

**🔄 Phase 2 In Progress (Next Steps):**
- Multi-variation support (generate 3-5 variants, random selection)
- Improved ChuGL visualizations (per-drum-hit feedback)

**⏳ Phase 3 Pending (Q1 2026):**
- Multi-track support (3 simultaneous tracks)
- Per-track variation control
- Evaluation and metrics
- ACM Creativity & Cognition 2026 paper writing

**Status:** Single-track AI variation system FULLY WORKING! OSC integration seamless, ready for multi-track expansion.

## Research Angle

**Paper Title:** "Personal Drum Machines: User-Trainable Beatbox Classification with Real-Time AI Variations for Live Performance"

**Novel Contributions:**
1. User-trainable beatbox classifier (personalized per user, not generic)
2. Minimal training data (10 samples per class vs. 100s)
3. Live performance focus (<50ms latency)
4. **OSC-based Python-ChucK integration for seamless AI workflow**
5. **Real-time spice control with visual feedback**
6. AI-powered variation generation maintaining musical constraints
7. Queued action system for musical loop boundary transitions
8. End-to-end system from training to performance to variation

**Design Decision:** Initial experiments with Magenta's GrooVAE and piano roll conversion proved unreliable. We now use Jake Chen's rhythmic_creator model (Transformer-LSTM-FNN hybrid trained on Lakh MIDI) as the default variation engine, with Google's Gemini API as an optional alternative. The rhythmic_creator model provides offline, low-latency generation ideal for live performance, while OSC communication enables seamless Python-ChucK integration for automatic variation workflows.

## Future Enhancements

**Multi-Track Support (Phase 3):**
- 3 simultaneous tracks with independent variation control
- Cross-track variation coherence
- Per-track spice levels

**Advanced AI Features:**
- Multi-variation generation (5+ variants, random selection)
- Pattern evolution mode (gradual variation over time)
- Style transfer between performances

**Integration Points for Future AI Models:**
- **Notochord** (../notochord): Real-time MIDI AI via OSC
- **LoopGen** (../loopgen): Training-free loop generation
- **Living Looper** (../living-looper): Neural audio synthesis

## Data Export Formats

**Drum pattern format (track_N_drums.txt) - CURRENT:**
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

**Training samples format (training_samples.csv):**
```
timestamp,label,flux,energy,band1,band2,band5
0.152,kick,12.45,0.85,0.92,0.45,0.12
0.523,snare,8.32,0.72,0.35,0.68,0.65
0.891,hat,6.21,0.51,0.15,0.42,0.89
```

## Common Development Patterns

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
2. Classifier trains automatically when you start chuloopa_drums_v3_ableton.ck (or v3.ck)
3. Target accuracy: >85% for personalized models
4. If accuracy <70%, delete training_samples.csv and re-record with consistent technique

### Recording and Looping Drums with AI Variations
1. **Terminal 1:** Start Python watch mode: `cd src && python drum_variation_ai.py --watch`
2. **Terminal 2:** Run ChucK: `cd src && chuck chuloopa_drums_v3_ableton.ck`
3. **Verify OSC:** Both terminals show connection established
4. **Record:** Press & hold MIDI Note 36 (C1), beatbox into mic
5. **Real-time feedback:** System plays drum samples as you beatbox
6. **Release Note 36:** Pattern auto-exports to `src/tracks/track_0/track_0_drums.txt` and starts looping
7. **Auto-generation:** Python watchdog detects file change, generates variation
8. **OSC notification:** Python sends `/chuloopa/variations_ready` to ChucK
9. **Visual feedback:** Sphere turns green (variation ready)
10. **Load variation:** Press D1 to toggle variation ON (sphere turns blue)

### Loading AI Variations
1. **Press MIDI Note 38** (D1) mid-loop to queue variation toggle
2. Console shows: `>>> QUEUED: Variation toggle will occur at next loop boundary <<<`
3. Current loop continues until boundary
4. At boundary: loads `src/tracks/track_0/variations/track_0_drums_var1.txt`
5. Sphere turns blue (variation mode) or red (original mode)

### Adjusting Variation Creativity
1. **Turn CC 74 knob** on MIDI controller
2. **Visual feedback:** Spice level text changes color (blue→orange→red) in ChuGL
3. **Regenerate:** Press D#1 to trigger Python regeneration with new spice
4. **Wait for ready:** Sphere turns green when variation complete
5. **Load new variation:** Press D1 to hear the updated pattern

### Tuning Parameters
- **Onset sensitivity:** src/chuloopa_drums_v3_ableton.ck (`MIN_ONSET_STRENGTH`)
- **Debounce time:** src/chuloopa_drums_v3_ableton.ck (`MIN_ONSET_INTERVAL`)
- **Max loop duration:** src/chuloopa_drums_v3_ableton.ck (`MAX_LOOP_DURATION`)

## Important Notes

- **MUST record training samples first:** Run `drum_sample_recorder.ck` to create `training_samples.csv` before using main system
- **MUST run from src directory:** Both Python and ChucK scripts require `cd src` to find files correctly
- **Two-terminal workflow:** Python watch mode (Terminal 1) + ChucK (Terminal 2) must both be running
- **OSC ports:** Python receives on 5000, ChucK receives on 5001. Use `127.0.0.1` not `localhost` for Python
- **Automatic training:** Classifier trains automatically when chuloopa_drums_v3_ableton.ck (or v3.ck) starts
- **Spice = token count ceiling:** Spice (0.0-1.0) maps to how many tokens rhythmic_creator generates above context (max 3×), not temperature
- **Stable pipeline:** chuloopa_drums_v3_ableton.ck + drum_variation_ai.py
- **In-progress pipeline:** chuloopa_main.ck + drum_variation_generator.py + spice_detector.ck (audio-driven spice, 5-variant bank)
- **Path handling:** Working directory contains spaces - always use quoted paths in bash commands
- **Git branch:** Active development on `staging` branch, PRs into `main`
- **ChucK STK docs:** https://chuck.stanford.edu/doc/reference/ugens-stk.html
- **Drums-only mode:** No audio loop playback, only drum samples
- **Queued actions:** Variation toggle/clear happen at loop boundaries for smooth transitions
- **Single track focus:** Multi-track support (3 tracks) planned for Phase 3
