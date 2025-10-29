# CHULOOPA

**An experimental AI-powered looper in ChucK that explores intelligent audio evolution.**

## Overview

CHULOOPA is an intelligent looping system that uses AI to generate evolving variations of recorded audio. The architecture converts audio into symbolic representations, stores multiple tracks, and uses generative models to create variations that can be selected and decoded back to audio in real-time.

### Core Architecture

![CHULOOPA Architecture](CHULOOPA%20-%20initial%20procedural%20sketch.png)

Each track can store a symbolic representation and generate variations independently, allowing for complex multi-track evolution and composition.

## Current Status

**Early exploration phase** - Testing ChucK's capabilities and identifying language improvements needed.

- [x] Basic looper implementations (1-4)
- [x] Realtime symbolic transcription (pitch detection)
- [ ] Complete architecture and data pipeline
- [ ] AI integration for pattern generation

## Implementations

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

### 4. Visual Looper (QuNeo + ChucK GL)

Grid-based visual feedback for looping.

- `looper_midi_quneo_grid_visual.ck`
- `looper_midi_quneo_visual.ck`

### 5. Realtime Symbolic Transcription

Pitch detection using autocorrelation to convert audio to MIDI representations.

- `pitch_detector_recorder.ck` - records from mic to MIDI text
- `pitch_detector_file.ck` - converts WAV files to MIDI text
- `midi_playback.ck` - plays back MIDI text files

## Goals

- **Audio**: Use AI to evolve recorded loops intelligently over time
- **Visual**: Intuitive ChucK GL visualizations of audio and loop state
- **Research**: Push ChucK's boundaries and document improvement areas
