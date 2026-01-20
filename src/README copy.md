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
3. REAL-TIME PITCH DETECTION → SYMBOLIC MIDI
   ↓
4. SYMBOLIC DATA STORAGE (per track)
   ↓
5. AI GENERATION [PLACEHOLDER] → VARIATIONS
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
- Real-time pitch detection per track
- Symbolic MIDI data recording
- MIDI data export
- ChuGL visualization

**Usage:**

```bash
chuck src/chuloopa_main.ck
```

**MIDI Control (QuNeo):**

- **Record:** C1, C#1, D1 (notes 36-38) - Press & hold
- **Clear:** E1, F1, F#1 (notes 40-42) - Single press
- **Export MIDI:** G1 (note 43) - Export all track data
- **Volume:** CC 45-47 - Track volumes

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

### `ai_pipeline_placeholder.ck`

**AI variation generation (placeholder)**

Takes symbolic MIDI data and generates variations using algorithmic transformations (placeholder for future AI models).

**Usage:**

```bash
chuck src/ai_pipeline_placeholder.ck:track_0_midi.txt
```

**Current Algorithmic Variations:**

1. **Transpose +7** (Perfect 5th up)
2. **Transpose -5** (Perfect 4th down)
3. **Time Stretch 2×** (slower)
4. **Reverse** (retrograde)
5. **Random Permutation**

**Output:**

- `variation_0_midi.txt` through `variation_4_midi.txt`

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

---

### `variation_playback.ck`

**Plays back AI-generated variations**

**Usage:**

```bash
# Basic playback (sine wave)
chuck src/variation_playback.ck:variation_0_midi.txt

# Different synthesis
chuck src/variation_playback.ck:variation_0_midi.txt:mandolin

# Looped playback
chuck src/variation_playback.ck:variation_0_midi.txt:flute:loop
```

**Synth Options:**

- `sine` - Sine wave (default)
- `square` - Square wave
- `saw` - Sawtooth
- `mandolin` - STK Mandolin
- `flute` - STK Flute
- `brass` - STK Brass

---

## Complete Workflow Example

### 1. Record and Export Loops

```bash
# Start CHULOOPA
chuck src/chuloopa_main.ck

# In CHULOOPA:
# - Record 3 tracks using QuNeo pads (C1, C#1, D1)
# - Press G1 to export MIDI data
# - Files created: track_0_midi.txt, track_1_midi.txt, track_2_midi.txt
```

### 2. Generate AI Variations

```bash
# Generate variations from Track 0
chuck src/ai_pipeline_placeholder.ck:track_0_midi.txt

# Output: variation_0_midi.txt through variation_4_midi.txt
```

### 3. Play Back Variations

```bash
# Play variation 0 with mandolin synthesis, looped
chuck src/variation_playback.ck:variation_0_midi.txt:mandolin:loop

# Play variation 1 with flute synthesis
chuck src/variation_playback.ck:variation_1_midi.txt:flute
```

### 4. Multi-Variation Playback

```bash
# Play multiple variations simultaneously (in separate terminals)
chuck src/variation_playback.ck:variation_0_midi.txt:sine:loop &
chuck src/variation_playback.ck:variation_1_midi.txt:mandolin:loop &
chuck src/variation_playback.ck:variation_2_midi.txt:flute:loop &

# Creates evolving polyrhythmic textures!
```

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

**CSV format:** `MIDI_NOTE,FREQUENCY,VELOCITY,START_TIME,DURATION`

**Example:**

```
# Track 0 MIDI Data
# Format: MIDI_NOTE,FREQUENCY,VELOCITY,START_TIME,DURATION
60,261.626,85,0.0,0.523
62,293.665,92,0.6,0.412
64,329.628,78,1.1,0.635
```

### Visualization

- **Sphere Size:** Amplitude/volume (RMS)
- **Sphere Color:** Dominant frequency (FFT)
  - Blue → Low frequencies
  - Green/Yellow → Mid frequencies
  - Red → High frequencies
- **Master Track:** Subtle gold highlight

---

## Future Development Roadmap

### Phase 1: AI Integration (Current)

- [x] Symbolic data pipeline
- [x] Algorithmic variation placeholders
- [ ] OSC communication setup
- [ ] Python bridge for AI models

### Phase 2: Notochord Integration

- [ ] Connect to notochord OSC server
- [ ] Real-time harmonic generation
- [ ] Co-improvisation mode
- [ ] MIDI prompt integration

### Phase 3: LoopGen Integration

- [ ] Training-free loop generation
- [ ] Seamless loop variations
- [ ] Audio-level loop transformations

### Phase 4: Living Looper Integration

- [ ] Neural audio synthesis
- [ ] RAVE encoder-decoder models
- [ ] Timbral evolution
- [ ] Hybrid symbolic/audio generation

### Phase 5: Advanced Features

- [ ] Multi-variation blending
- [ ] Real-time variation switching
- [ ] Variation morphing/interpolation
- [ ] Performance recording/export

---

## Integration with Existing Projects

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
│   ├── chuloopa_main.ck           # Main system
│   ├── ai_pipeline_placeholder.ck  # AI generation
│   ├── variation_playback.ck       # Playback
│   └── README.md                   # This file
│
├── initial implementation/         # Experimental code
│   ├── 4 - looper midi quneo visual/
│   └── 5 - realtime symbolic transcription/
│
└── Output files (generated):
    ├── track_0_midi.txt            # Exported MIDI data
    ├── track_1_midi.txt
    ├── track_2_midi.txt
    ├── variation_0_midi.txt        # AI variations
    ├── variation_1_midi.txt
    └── ...
```

---

## Troubleshooting

### No MIDI device found

If you don't have a QuNeo or MIDI controller:

- Edit `chuloopa_main.ck` to map computer keyboard input
- Or manually trigger functions in the code

### Pitch detection not working

- Increase `AMPLITUDE_THRESHOLD` (currently 0.009)
- Check microphone input gain
- Ensure audio input is selected in system preferences

### Loops drifting

This should not happen with the master sync system! If it does:

- Check `SOLVING_DRIFT.md` in `initial implementation/4 - looper midi quneo visual/`
- Verify `findBestMultiplier()` function

### No symbolic data exported

- Ensure pitch was detected during recording
- Check amplitude threshold
- Try singing/playing louder or closer to mic

---

## Performance Tips

### Best Recording Practices

1. **First loop sets the tempo** - Make it a good one!
2. **Clear melodic lines** work better for pitch detection than chords
3. **Consistent volume** helps maintain accurate velocity data
4. **Shorter loops** (2-8 seconds) sync more reliably

### Variation Generation

1. **Experiment with different synths** - Each variation sounds different with different timbres
2. **Layer variations** - Play multiple variations simultaneously
3. **Time-stretched variations** create interesting polyrhythms

### Visualization

- Master track has **gold highlight**
- **Blue/cool colors** = low frequencies (bass)
- **Red/warm colors** = high frequencies (treble)
- **Sphere size** = amplitude (louder = bigger)

---

## Known Limitations

1. **Monophonic only** - Pitch detection works best with single notes
2. **3 tracks maximum** - Can be increased by editing NUM_TRACKS
3. **No undo** - Once you clear a track, symbolic data is lost
4. **AI is placeholder** - Real AI models not yet integrated
5. **No variation editing** - Generated variations can't be manually tweaked (yet)

---

## Questions?

For issues or questions:

1. Check the main `CHULOOPA/README.md`
2. Review code comments in source files
3. Examine `initial implementation/` for component details

---

## Credits

Built from experimental implementations:

- **Multi-track looper:** `initial implementation/4 - looper midi quneo visual/`
- **Pitch detection:** `initial implementation/5 - realtime symbolic transcription/`

Prepares for integration with:

- **Notochord** - Real-time MIDI AI
- **LoopGen** - Training-free loop generation
- **Living Looper** - Neural audio synthesis

---

**CHULOOPA** - Where AI meets the loop pedal 🎵🤖
