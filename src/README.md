# CHULOOPA / src

This directory contains all source code for CHULOOPA — a user-trainable beatbox-to-drum looper with AI-powered variation generation.

---

## Running the System

### Step 1: Record Training Samples (one-time, ~5 min)

```bash
chuck drum_sample_recorder.ck
```

Record 10 samples each of your kick, snare, and hi-hat beatbox sounds. Press **K**, **S**, **H** to record each class, **Q** to quit and save.

Creates: `training_samples.csv`

---

### Step 2: Start Python AI Engine (Terminal 1)

```bash
cd src
python drum_variation_ai.py --watch
```

Starts the OSC server and watches for newly recorded loops. Auto-generates variations using `rhythmic_creator` (local, offline) or Gemini API (optional).

---

### Step 3: Run CHULOOPA (Terminal 2)

```bash
cd src
chuck chuloopa_drums_v3.ck
```

KNN classifier trains automatically on startup from `training_samples.csv`. OSC connection to Python established automatically.

---

## MIDI Controls (Akai LPD8)

| Input | Action |
|-------|--------|
| **Note 36** (C1) hold | Record loop — hear drums in real-time as you beatbox |
| **Note 37** (C#1) | Clear track |
| **Note 38** (D1) | Toggle variation ON/OFF (queued at loop boundary) |
| **Note 39** (D#1) | Regenerate variation with current spice level |
| **CC 74** | Spice level knob (0.0–1.0) |

### Spice Levels

| Range | Behavior |
|-------|----------|
| 0.0–0.3 (low) | Simplify — strip to kick/snare skeleton |
| 0.4–0.6 (mid) | Light embellishment, subtle humanization |
| 0.7–1.0 (high) | Add fills, ghost notes, hi-hat density — groove maintained |

---

## Key Files

### Active System
| File | Description |
|------|-------------|
| `chuloopa_drums_v3.ck` | **Main system** — beatbox input, KNN classification, loop recording, OSC, ChuGL visuals |
| `drum_variation_ai.py` | **AI engine** — rhythmic_creator + Gemini variation generation, OSC server |
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
| `chuloopa_drums_v2.ck` | Previous version (CC 18 spice, kept for reference) |
| `chuloopa_main.ck` | Original melody-based system (archived) |
| `chuloopa_drums.ck` | Early drum prototype (archived) |

---

## File Structure

```
src/
├── chuloopa_drums_v3.ck       # Main system
├── drum_variation_ai.py       # AI variation engine
├── drum_sample_recorder.ck    # Training recorder
│
├── tracks/                    # Auto-generated loop data
│   └── track_0/
│       ├── track_0_drums.txt
│       └── variations/
│           └── track_0_drums_var1.txt
│
├── models/                    # rhythmic_creator model weights
├── samples/                   # kick.wav, snare.wav, hat.WAV
├── training_samples.csv       # Your training data (generated)
│
├── evaluation/                # Evaluation scripts
├── test_*.py                  # Diagnostic and unit test scripts
└── diagnose_performance.py    # System performance diagnostic
```

---

## How It Works

```
Beatbox input
  ↓
Onset detection (spectral flux, 512-sample frames)
  ↓
KNN classification (k=3, trained on your 10 samples/class)
  ↓
Drum sample playback (kick/snare/hat, ~25ms latency)
  ↓
Loop recorded → exported to tracks/track_0/track_0_drums.txt
  ↓
Python watchdog detects file → generates AI variation
  ↓
OSC: /chuloopa/variations_ready → ChucK (sphere turns green)
  ↓
Press D1 to load variation at next loop boundary
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

**Note:** Python must use `127.0.0.1`, not `localhost` (pythonosc resolution issue).
