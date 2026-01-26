# PAOLO UPDATED README as of 1/19:

A lot has changed since the original version of this project. The final semi-working condition of this project works such that

1. NO MORE MAGENTA VARIATIONS: When experimenting with magenta (shown in chuloopa/magenta_variations), I found that the conversion from my chuck output format to a piano roll was difficult and did not result in any acceptable responses. In my frustration, turning to gemini out the box with my requirements (make a variation with the same total loop duration and keep tempo), gemini was able to consistently successfully generate new variations of the beat. Super simple solution but incredibly reliable results.
2. The current pipeline now works such that
   - Launch chuck script ("chuck chuloopa_main_v2.ck")
   - Record your drum loop through a mic (ensure mic levels are the same as when the samples were recorded)
   - Drum loop plays back to you and a transcribed copy is saved to track_x_drums.txt
   - run python script to create variation ("python drum_variation_ai.py -- track x") and wait for the finished output.
   - load the newly modfied track_X_drums.txt file into the chuck script

Next step is to finalize the UI and user flow and better connecting the chuck script and the python script

CHUCK PYTHON INTEGRATIONS

- Ideally after a drum loop is recorded, we instantly trigger the python script to create variations of that drum loop.
- while we currently generate the loops one at a time, we can instead maybe opt to generate 5 variants and have them saved to a variants directory.
- if the user selects to load a new variant we simply select a new random file from that directory.

CHUCK UI

- Improve UI significantly, super boring right now. Think of an exciting way to visualize this using samples found here /Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHUGL
- visualize what happens when the loops are being played + what changes when the variations are being played. CHULOOPA spicy variations.
  BONUS: idk if we can do this but to add a UI to drag and drop kick, snare, and hi hat samples would be cool.

# READ ME PROPER

# CHULOOPA - Main Source Code

**An GEMINI-powered intelligent looping system in ChucK**

This directory contains the main CHULOOPA implementation that integrates all experimental components from the `initial implementation` directory into a complete pipeline.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     CHULOOPA PIPELINE                       │
└─────────────────────────────────────────────────────────────┘

1. AUDIO INPUT
   ↓
2. MULTI-TRACK LOOPER (with master sync)
   ↓
3. BEAT BOX to DRUM HIT TRANSCRIPTION → SYMBOLIC MIDI
   ↓
4. SYMBOLIC DATA STORAGE (per track)
   ↓
5. GEMINI VARIATION GENERATION → TRACK VARIATIONS
   ↓
6. VARIATION PLAYBACK → AUDIO OUTPUT
   ↓
7. VISUAL FEEDBACK (ChuGL)
```

## Core Files

### `chuloopa_main.ck`

**The main integrated system**

Combines:

- Multi-track audio looping (3 tracks)
- Master loop sync (prevents drift)
- Real-time drum hit classification (based on trained user samples "drums_sample_recorder.ck") per track
- Symbolic data recording and transcription
- Symbolic data export
- ChuGL visualization

**Usage:**

```bash
chuck src/chuloopa_main_v2.ck
```

**MIDI Control:**

- **Record:** C1, C#1, D1 (notes 36-38) - Press & hold
- **Clear:** D#1, E1, F1 (notes 39-41) - Single press
- **Load MIDI txt into chuck:** F#1, G1, G#1 (note 42) - Import transcription from txt file

**Features:**

- **Master Loop Sync:** First loop becomes master, subsequent loops auto-adjust to musical ratios (0.25×, 0.5×, 1×, 2×, etc.)
- **Real-time Transcription:** Converts audio to MIDI notes during recording
- **Symbolic Storage:** Each track stores MIDI note data (pitch, velocity, timing)
- **Visual Feedback:** Spheres react to amplitude (size) and frequency (color)

**Output:**

- `track_0_midi.txt` - Track 0 MIDI data
- `track_1_midi.txt` - Track 1 MIDI data
- `track_2_midi.txt` - Track 2 MIDI data

Format: `MIDI_NOTE,FREQUENCY,VELOCITY,START_TIME,DURATION`

---

### `drum_variation_ai.py'

**gemini ai variation generation (placeholder)**

Takes symbolic MIDI data and generates variations. Used to be with magenta but gemini proved to be a reliable, consistent, and convenient alternative.

**Usage:**

```bash
python drum_variation_ai.py
```

**Output:**

- overwrites 'track_NUM_drums.txt`

**Future AI Integration Points:**

```chuck
// INTEGRATION POINT 1: Python AI via OSC
// Send MIDI → Python (notochord/loopgen) → Receive AI variations

// INTEGRATION POINT 2: Real-time Notochord
// Run: notochord server --port 5005
// Live co-improvisation with AI

// INTEGRATION POINT 3: Living Looper Neural Synthesis
// MIDI variation → living-looper model → Neural audio
```

## Complete Workflow Example

### 1. Record and Export Loops

```bash
# Start CHULOOPA
chuck src/chuloopa_main_v2.ck

# In CHULOOPA:
# - Record 1 track using button pads (c1, c#1, d1)

# OUTPUT -> track_NUM_drums.txt with NUM corrsponding to track number
```

### 2. Generate AI Variations

TO BE FIXED IN NEXT ITERATION WITH BETTER CHUCK AND PYTHON INTEGRATION

```bash
# run python variation script to send to gemini api
python drum_variation_ai.py

# OUTPUT: takes existing track_NUM_drums.txt and overwrites it with new variation
```

### 3. Play Back Variations

Once finished import new variation into chuck via CHULOOPA ui

- hit respective track load button pad (F#1, G1, G#1)

---

## Technical Details

### Pitch Detection Algorithm

- **Method:** Autocorrelation
- **Frame Size:** 1024 samples
- **Hop Size:** 256 samples (FRAME_SIZE/4)
- **Amplitude Threshold:** 0.009
- **Frequency Range:** 80-800 Hz (vocal/instrumental)
- **Minimum Note Duration:** 50ms

### Master Loop Sync

- **Strategy:** First loop becomes master reference
- **Valid Multipliers:** [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0]
- **Algorithm:** Finds closest multiplier match, adjusts loop length
- **Result:** Zero drift, perfect sync

### Symbolic Data Format

# Track 0 Drum Data

# Format: DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME

# Classes: 0=kick, 1=snare, 2=hat

# Total loop duration: 5.061950 seconds

0,0.084172,0.482133,0.635646
1,0.719819,0.132769,0.635646
0,1.355465,0.272635,0.632744
1,1.988209,0.123715,0.641451
0,2.629660,0.326760,0.606621
1,3.236281,0.216937,0.609524
0,3.845805,0.329060,0.320000
1,4.165805,0.080000,0.321451
1,4.487256,0.253780,0.574694

**CSV format:** `DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME`

**Example:**

```
# Track 0 Drum Data
# Format: DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME
# Classes: 0=kick, 1=snare, 2=hat
# Total loop duration: 5.061950 seconds
0,0.084172,0.482133,0.635646
1,0.719819,0.132769,0.635646
0,1.355465,0.272635,0.632744
1,1.988209,0.123715,0.641451
0,2.629660,0.326760,0.606621
1,3.236281,0.216937,0.609524
0,3.845805,0.329060,0.320000
1,4.165805,0.080000,0.321451
1,4.487256,0.253780,0.574694
```

### Visualization (WILL BE IMPROVED I JUST SUCK AT CHUGL AND ENJOY THE OTHER PARTS MORE)

- **Sphere Size:** Amplitude/volume (RMS)
- **Sphere Color:** Dominant frequency (FFT)
  - Blue → Low frequencies
  - Green/Yellow → Mid frequencies
  - Red → High frequencies
- **Master Track:** Subtle gold highlight

---

## Future Development Roadmap

PHASE 1: Initial Implementations

[X] Messed around with different prototypes with both

---

## Other projects that inspired me

### Notochord

```python
# Run notochord OSC server
notochord server --port 5005

# In ChucK, send MIDI events:
# → Notochord generates harmonic responses
# → Receive variations via OSC
```

### LoopGen

```python
# Use loopgen for variation generation
from loopgen import Loopgen

# Load MIDI data from CHULOOPA
# Generate seamless loop variations
# Export back to MIDI format
```

### Living Looper

```python
# Export RAVE model for living-looper
livinglooper export <rave_model.ts> <output.ts>

# Use in CHULOOPA for neural synthesis
# MIDI variation → living-looper → Audio
```

---

## File Dependencies

```
CHULOOPA/
├── src/
│   ├── chuloopa_main_v2.ck           # Main system
│   ├── drum_sample_recorder.ck       # Beat box sample recorder
│   ├── training_samples.csv          # Training samples recorded from beat box sample recorder
│   ├── drum_variation_ai.py          # AI generation
│   └── README.md                     # This file (not currently since this one is my copy, paolo the writer hehe)
│
├── initial implementation/         # Experimental code
│   ├── 4 - looper midi quneo visual/ # when I started using a quneo midi board
│   └── 5 - realtime symbolic transcription/
│
└── Output files (generated):
    ├── track_0_drums.txt            # Exported MIDI data
    ├── track_1_drums.txt
    ├── track_2_drums.txt
```

---

## Troubleshooting

### Beat boxing not being classified properly

Rerun training script and check your input gain. Too high gain will result in very similar classifications

### Loops drifting

This should not happen with the master sync system! If it does:

- Check `SOLVING_DRIFT.md` in `initial implementation/4 - looper midi quneo visual/`
- Verify `findBestMultiplier()` function

### No symbolic data exported

- Ensure drum hits was detected during recording
- Try singing/playing louder or closer to mic
