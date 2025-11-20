# CHULOOPA

**An experimental AI-powered looper in ChucK that explores intelligent audio evolution.**

## Overview

CHULOOPA is an intelligent looping system that uses AI to generate evolving variations of recorded audio. The architecture converts audio into symbolic representations, stores multiple tracks, and uses generative models to create variations that can be selected and decoded back to audio in real-time.

### Core Architecture

![CHULOOPA Architecture](CHULOOPA%20-%20initial%20procedural%20sketch.png)

Each track can store a symbolic representation and generate variations independently, allowing for complex multi-track evolution and composition.

## Current Status

**Main pipeline complete!** The core CHULOOPA system is now functional in the `src/` directory.

- [x] Basic looper implementations (1-4)
- [x] Realtime symbolic transcription (pitch detection)
- [x] Complete architecture and data pipeline
- [x] Main integrated system (`src/chuloopa_main.ck`)
- [x] Symbolic data storage and export
- [x] Variation generation placeholder
- [x] Variation playback system
- [ ] AI integration for pattern generation (placeholder ready)

## Quick Start

**Run the main CHULOOPA system:**

```bash
cd "CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
chuck src/chuloopa_main.ck
```

**Complete workflow:**

1. **Record loops** - Use MIDI controller (QuNeo) or edit code for keyboard input
2. **Export MIDI data** - Press G1 or call `exportAllSymbolicData()`
3. **Generate variations** - `chuck src/ai_pipeline_placeholder.ck:track_0_midi.txt`
4. **Play variations** - `chuck src/variation_playback.ck:variation_0_midi.txt:mandolin:loop`

**See `src/README.md` for detailed documentation.**

---

## Main Source Code (`src/`)

The `src/` directory contains the complete integrated CHULOOPA system:

### `chuloopa_main.ck`
Main system combining multi-track looping, real-time pitch detection, symbolic MIDI storage, and visualization.

**Features:**
- 3-track audio looper with master sync (no drift)
- Real-time pitch detection → MIDI conversion
- Symbolic data recording and export
- ChuGL visualization (spheres react to amplitude & frequency)
- QuNeo MIDI control

### `ai_pipeline_placeholder.ck`
AI variation generator with clear integration points for future AI models.

**Current:** Algorithmic variations (transpose, time-stretch, reverse, permutation)
**Future:** Integration with notochord, loopgen, living-looper

### `variation_playback.ck`
Plays back AI-generated MIDI variations with multiple synthesis options.

**Synths:** sine, square, saw, mandolin, flute, brass
**Modes:** one-shot or looped playback

---

## Experimental Implementations (`initial implementation/`)

**These are prototype implementations that were integrated into the main `src/` system.**

### 1. Simple Looper

OSC-controlled audio looping with GUI interface.

- `looper.ck` + `looper_gui.ck`

### 2. Looper with Vocoder

Adds vocoder processing to the basic looper.

- `looper_vocoder.ck` + `looper_gui_vocoder.ck`

### 3. MIDI Controller (QuNeo)

QuNeo-specific implementations with MIDI control.

- `looper_midi_quneo.ck`
- `looper_midi_quneo_vocoder.ck`

### 4. Visual Looper (QuNeo + ChucK GL) → **Integrated into `src/chuloopa_main.ck`**

Grid-based visual feedback for looping with master sync.

- `[MASTER LOOP] looper_midi_quneo_visual_freeform.ck` - Best implementation
- `looper_midi_quneo_grid_visual.ck`
- `looper_midi_quneo_visual.ck`
- `SOLVING_DRIFT.md` - Technical documentation on loop sync

### 5. Realtime Symbolic Transcription → **Integrated into `src/chuloopa_main.ck`**

Pitch detection using autocorrelation to convert audio to MIDI representations.

- `pitch_detector_recorder.ck` - Records from mic to MIDI text
- `pitch_detector_file.ck` - Converts WAV files to MIDI text
- `midi_playback.ck` - Plays back MIDI text files

## Goals

- **Audio**: Use AI to evolve recorded loops intelligently over time
- **Visual**: Intuitive ChucK GL visualizations of audio and loop state
- **Research**: Push ChucK's boundaries and document improvement areas
