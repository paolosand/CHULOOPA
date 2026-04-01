# CHULOOPA / src

This directory contains all source code for CHULOOPA — a user-trainable beatbox-to-drum looper with AI-powered variation generation.

---

## Running the System

### Step 1: Record Training Samples (one-time, ~5 min)

```bash
chuck drum_sample_recorder.ck
```

| Key | Action |
|-----|--------|
| K | Set label to kick, then beatbox |
| S | Set label to snare, then beatbox |
| H | Set label to hi-hat, then beatbox |
| N | Disable recording (pause between classes) |
| E / Q | Export to `training_samples.csv` |
| P | Live playback test — beatbox freely, hears KNN classify in real-time |
| R | Full reset — erase all samples and start over |
| ESC | Close window |

**Workflow:** Record K/S/H (10+ each) → press **E** to export → press **P** to test → press **R** to re-record if needed.

Creates: `training_samples.csv`

---

### Step 2: Start Python AI Engine (Terminal 1)

```bash
cd src
python drum_variation_generator.py --watch
```

Starts the OSC server and watches for newly recorded loops. Pre-generates a bank of 5 variations at spice levels 0.2/0.4/0.6/0.8/1.0 using `rhythmic_creator` (local, offline).

---

### Step 3: Start Spice Detector (Terminal 2)

```bash
cd src
chuck spice_detector.ck
```

Analyzes live audio (guitar/vocal/room) and sends composite spice level via OSC every 500ms to both Python (port 5000) and ChucK (port 5001).

> **Stereo mode:** `chuck --channels:2 spice_detector.ck` — enables CC 75 to blend guitar vs. vocal input.

---

### Step 4: Run CHULOOPA (Terminal 3)

```bash
cd src
chuck chuloopa_main.ck
```

KNN classifier trains automatically on startup from `training_samples.csv`. OSC connections to Python and spice_detector established automatically.

---

## MIDI Controls (Akai LPD8)

| Input | Action |
|-------|--------|
| **Note 36** (C1) hold | Record loop — hear drums in real-time as you beatbox |
| **Note 37** (C#1) | Clear track |
| **Note 38** (D1) | Regenerate full variation bank |
| **CC 74** | Spice ceiling knob (0.0–1.0) — caps audio-driven spice |

### Spice Levels

Spice is driven by `spice_detector.ck` from live audio. CC 74 sets the ceiling.
Spice maps to a **token count ceiling** (max 3×) for the rhythmic_creator model.

| Range | Token ceiling | Behavior |
|-------|--------------|----------|
| 0.0–0.3 (low) | ~1× context | Conservative — minimal additions, close to original |
| 0.4–0.6 (mid) | ~2× context | Light embellishment, subtle humanization |
| 0.7–1.0 (high) | up to 3× context | Bold fills, ghost notes, hi-hat density |

---

## Key Files

### Main System (v4 pipeline)
| File | Description |
|------|-------------|
| `chuloopa_main.ck` | **Main ChucK** — beatbox input, MFCC-13 KNN classification, loop recording, MIDI→Ableton via IAC, weighted variation selection, silence debounce, ChuGL visuals |
| `drum_variation_generator.py` | **Main Python** — generates bank of 5 variations (spice 0.2/0.4/0.6/0.8/1.0), sends `bank_ready` + `variation_available` OSC |
| `spice_detector.ck` | **Spice source** — analyzes live audio → composite spice → OSC to Python + ChucK every 500ms |
| `drum_sample_recorder.ck` | Training data collector (run once before using main system) |

### Supporting
| File | Description |
|------|-------------|
| `rhythmic_creator_model.py` | Wrapper for local transformer-LSTM variation model |
| `format_converters.py` | Converts between drum pattern formats |
| `feature_extraction.ck` | ChucK feature extraction utilities |
| `midi_monitor.ck` | Debug tool — prints all MIDI note/CC input |

### Legacy (archived)
| File | Description |
|------|-------------|
| `chuloopa_drums_v3_ableton.ck` | Single-variant Ableton mode (stable fallback) |
| `chuloopa_drums_v3.ck` | Standalone version (built-in WAV samples, no Ableton) |
| `drum_variation_ai.py` | Single-variant AI engine (v1) |
| `chuloopa_drums_v2.ck` | Archived — older standalone version |
| `chuloopa_main.ck` | Original melody-based system (archived) |

---

## File Structure

```
src/
├── chuloopa_main.ck       # MAIN: Audio-driven spice + variation bank
├── drum_variation_generator.py    # MAIN: Variation bank engine (5 variants)
├── spice_detector.ck          # MAIN: Audio-driven spice detector
├── drum_sample_recorder.ck    # Training recorder
│
├── tracks/                    # Auto-generated loop data
│   └── track_0/
│       ├── track_0_drums.txt
│       └── variations/
│           └── track_0_drums_var1.txt
│
├── models/                    # rhythmic_creator model weights
├── training_samples.csv       # Your training data (generated)
│
├── evaluation/                # Evaluation scripts
└── test_*.py                  # Diagnostic and unit test scripts
```

---

## How It Works

**Main pipeline (v4):**
```
spice_detector.ck analyzes live audio → /chuloopa/spice OSC every 500ms → Python + ChucK
  ↓
drum_variation_generator.py pre-generates bank of 5 variations (spice 0.2→1.0)
  sends /chuloopa/variation_available as each completes
  sends /chuloopa/bank_ready when all 5 done
  ↓
chuloopa_main.ck records beatbox input:
  Onset detection (spectral flux, 512-sample frames)
  ↓
  MFCC-13 KNN classification (k=3, confidence threshold 0.55)
  ↓
  MIDI notes → Ableton Drum Rack via IAC Driver (~25ms latency)
  ↓
  Loop recorded → exported to tracks/track_0/track_0_drums.txt
  ↓
  Rolling 4-bar spice average selects best variation at loop boundary
  (CC 74 caps the maximum spice; spice_detector is source of truth)
```

---

## Data Format

**Drum pattern (`track_0_drums.txt`):**
```
# Format: DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME
# Classes: 0=kick, 1=snare, 2=hat
0,0.037,0.169,0.567
1,0.604,0.250,0.406
2,1.010,0.314,0.444
```

`DELTA_TIME` = seconds until next hit. Last hit's delta_time = time until loop end.

---

## OSC Ports

| Direction | Port |
|-----------|------|
| ChucK → Python | `localhost:5000` |
| Python → ChucK | `127.0.0.1:5001` |
| spice_detector → Python | `127.0.0.1:5000` |
| spice_detector → ChucK | `127.0.0.1:5001` |

**Note:** Python must use `127.0.0.1`, not `localhost` (pythonosc resolution issue).
