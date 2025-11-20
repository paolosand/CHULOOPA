# CHULOOPA Quick Start Guide

**Get up and running with CHULOOPA in 5 minutes**

## What is CHULOOPA?

CHULOOPA is an AI-powered intelligent looping system that:
1. Records multi-track audio loops
2. Converts audio to symbolic MIDI data in real-time
3. Generates AI variations (placeholder)
4. Plays back variations as audio

## Installation

**Requirements:**
- ChucK (with ChuGL support for visualization)
- MIDI controller (optional - QuNeo recommended)
- Microphone or audio input

**No installation needed!** Just navigate to the CHULOOPA directory.

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
```

---

## 5-Minute Workflow

### Step 1: Run CHULOOPA

```bash
chuck src/chuloopa_main.ck
```

You should see:
```
╔═══════════════════════════════════════════════════╗
║           CHULOOPA - AI Looper System          ║
╚═══════════════════════════════════════════════════╝
```

A visualization window will open showing 3 spheres (one per track).

### Step 2: Record Your First Loop

**With MIDI Controller (QuNeo):**
- Press and HOLD pad C1 (note 36)
- Sing, play, or speak into your microphone
- Release to stop recording
- The loop will start playing automatically!

**Without MIDI Controller:**
- Edit `src/chuloopa_main.ck` line ~570 to add keyboard triggers
- Or call `startRecording(0)` and `stopRecording(0)` manually

### Step 3: Record More Tracks

- Press and HOLD C#1 (note 37) for Track 1
- Press and HOLD D1 (note 38) for Track 2

**Important:** The first loop becomes the MASTER. All subsequent loops will auto-sync to musical ratios (2×, 0.5×, etc.) to prevent drift!

### Step 4: Export MIDI Data

**With MIDI Controller:**
- Press G1 (note 43)

**Without MIDI Controller:**
- Press Ctrl+C to stop
- Files will be in your directory: `track_0_midi.txt`, `track_1_midi.txt`, `track_2_midi.txt`

### Step 5: Generate Variations

```bash
chuck src/ai_pipeline_placeholder.ck:track_0_midi.txt
```

This creates 5 variations:
- `variation_0_midi.txt` - Transposed +7 semitones
- `variation_1_midi.txt` - Transposed -5 semitones
- `variation_2_midi.txt` - Time stretched 2×
- `variation_3_midi.txt` - Reversed
- `variation_4_midi.txt` - Random permutation

### Step 6: Play Variations

**Single variation:**
```bash
chuck src/variation_playback.ck:variation_0_midi.txt:sine
```

**Looped variation:**
```bash
chuck src/variation_playback.ck:variation_0_midi.txt:mandolin:loop
```

**Multiple variations simultaneously:**
```bash
# Open 3 terminal windows and run:
chuck src/variation_playback.ck:variation_0_midi.txt:sine:loop
chuck src/variation_playback.ck:variation_1_midi.txt:flute:loop
chuck src/variation_playback.ck:variation_2_midi.txt:brass:loop
```

---

## MIDI Control Reference (QuNeo)

### Recording
| Pad  | MIDI Note | Function         |
|------|-----------|------------------|
| C1   | 36        | Record Track 0   |
| C#1  | 37        | Record Track 1   |
| D1   | 38        | Record Track 2   |

**Usage:** Press and HOLD to record, RELEASE to stop

### Clearing
| Pad  | MIDI Note | Function         |
|------|-----------|------------------|
| E1   | 40        | Clear Track 0    |
| F1   | 41        | Clear Track 1    |
| F#1  | 42        | Clear Track 2    |

**Usage:** Single press

### Export
| Pad  | MIDI Note | Function              |
|------|-----------|-----------------------|
| G1   | 43        | Export all MIDI data  |

### Volume Control
| Control | CC Number | Function             |
|---------|-----------|----------------------|
| Slider  | CC 45     | Track 0 Volume       |
| Slider  | CC 46     | Track 1 Volume       |
| Slider  | CC 47     | Track 2 Volume       |

---

## Synthesis Options

Choose different synths for variation playback:

| Synth      | Description                  | Best For                    |
|------------|------------------------------|-----------------------------|
| `sine`     | Pure sine wave (default)     | Clean, simple tones         |
| `square`   | Square wave                  | Retro, chiptune sounds      |
| `saw`      | Sawtooth wave                | Rich, buzzy tones           |
| `mandolin` | STK Mandolin (plucked)       | Melodic, stringed feel      |
| `flute`    | STK Flute (breathy)          | Smooth, lyrical phrases     |
| `brass`    | STK Brass (bold)             | Bold, punchy statements     |

**Example:**
```bash
chuck src/variation_playback.ck:variation_0_midi.txt:flute:loop
```

---

## Troubleshooting

### "No MIDI devices found!"
- Continue without MIDI controller
- Edit code to map keyboard input
- Or manually trigger functions

### "Pitch detection not working"
- Speak/sing LOUDER and CLOSER to microphone
- Check microphone input is selected in system preferences
- Increase `AMPLITUDE_THRESHOLD` in `chuloopa_main.ck` (line ~41)

### "No notes captured"
- Ensure you're making sound during recording!
- Try humming a clear melody
- Avoid percussive or noisy sounds (pitch detection works best with tonal content)

### "Loops drifting out of sync"
- This shouldn't happen with master sync enabled!
- Check that you're using `src/chuloopa_main.ck` (not an older version)
- See `initial implementation/4 - looper midi quneo visual/SOLVING_DRIFT.md`

### "Visualization not showing"
- Make sure ChucK has ChuGL support installed
- Try running without `--silent` flag
- Check that a window opens (may be behind other windows)

---

## Tips for Best Results

### Recording
1. **Melodic content works best** - Hum, sing, or play a wind/string instrument
2. **Clear, sustained notes** - Avoid fast runs or percussive hits
3. **Consistent volume** - Stay close to the mic, maintain steady dynamics
4. **First loop is master** - Make it a good foundation!

### Variations
1. **Layer multiple variations** - Run several playback instances simultaneously
2. **Experiment with synths** - Same melody sounds different on different synths
3. **Try time-stretched variations** - Creates interesting polyrhythms
4. **Mix transposed variations** - Build harmonies automatically

### Performance
1. **Build gradually** - Start with one track, add more
2. **Use clear button** - Don't be afraid to reset and try again
3. **Export often** - Save interesting symbolic data
4. **Combine with DAW** - Record CHULOOPA output into your DAW for further processing

---

## Next Steps

### Explore the Code
- `src/README.md` - Detailed technical documentation
- `src/chuloopa_main.ck` - Main system (well-commented)
- `src/ai_pipeline_placeholder.ck` - AI integration points

### Customize
- Change `NUM_TRACKS` to support more tracks
- Adjust `AMPLITUDE_THRESHOLD` for pitch detection sensitivity
- Modify `valid_multipliers[]` for different loop sync ratios
- Add new variation algorithms to `ai_pipeline_placeholder.ck`

### Integrate AI Models
- Connect to **notochord** for real-time harmonic generation
- Use **loopgen** for seamless loop variations
- Add **living-looper** for neural audio synthesis

See `src/README.md` for integration instructions.

---

## File Overview

```
CHULOOPA/
├── src/
│   ├── chuloopa_main.ck           ← Start here!
│   ├── ai_pipeline_placeholder.ck  ← Generate variations
│   ├── variation_playback.ck       ← Play variations
│   └── README.md                   ← Full documentation
│
├── Output files (generated during use):
│   ├── track_0_midi.txt
│   ├── track_1_midi.txt
│   ├── track_2_midi.txt
│   ├── variation_0_midi.txt
│   └── ...
│
└── initial implementation/         ← Experimental prototypes
```

---

## Example Session

```bash
# Terminal 1: Run main CHULOOPA
chuck src/chuloopa_main.ck

# Record 3 loops using QuNeo
# Press G1 to export MIDI data
# Press Ctrl+C to stop

# Terminal 1: Generate variations from Track 0
chuck src/ai_pipeline_placeholder.ck:track_0_midi.txt

# Terminal 1: Play variation 0 (mandolin, looped)
chuck src/variation_playback.ck:variation_0_midi.txt:mandolin:loop

# Terminal 2: Play variation 1 (flute, looped)
chuck src/variation_playback.ck:variation_1_midi.txt:flute:loop

# Terminal 3: Play variation 3 (brass, looped)
chuck src/variation_playback.ck:variation_3_midi.txt:brass:loop

# Now you have 3 AI-generated variations playing simultaneously!
# Press Ctrl+C in each terminal to stop
```

---

## Getting Help

1. **Read the docs:** `src/README.md` has extensive documentation
2. **Check the code comments:** All files are thoroughly commented
3. **Explore examples:** `initial implementation/` shows component development
4. **Test systematically:** Try each step separately to isolate issues

---

**Ready to loop? Start with Step 1!**

```bash
chuck src/chuloopa_main.ck
```

🎵 Happy looping! 🤖
