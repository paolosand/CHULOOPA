# Testing the AI Variation Automation System

This guide walks through testing the complete OSC-based variation automation system.

## Prerequisites

### 1. Install Python Dependencies

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
pip install -r requirements.txt
```

Required packages:
- `python-osc` (OSC communication)
- `watchdog` (file watching)
- `google-genai` (AI variations)
- `numpy` (algorithmic variations)
- `python-dotenv` (environment variables)

### 2. Set Up Gemini API Key

Create a `.env` file in the project root:

```bash
echo "GEMINI_API_KEY=your_api_key_here" > .env
```

Or export it in your shell:

```bash
export GEMINI_API_KEY=your_api_key_here
```

### 3. Connect MIDI Controller

Make sure your MIDI controller is connected with:
- **CC 18** mapped to a knob (spice level control)
- **Note 36** (C1): Record button
- **Note 37** (C#1): Clear button
- **Note 38** (D1): Toggle variation button
- **Note 39** (D#1): Regenerate button

## Testing Workflow

### Step 1: Start Python Watch Mode

**IMPORTANT: Must run from src directory**

Open a terminal and run:

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python drum_variation_ai.py --watch
```

**Expected output:**
```
=============================================================
  CHULOOPA Drum Variation AI
=============================================================

OSC client initialized - sending to localhost:5001
OSC server listening on localhost:5000

Watching for drum file changes in: src/tracks/track_0
Variation type: gemini
Current spice level: 0.50

Ready! Press Ctrl+C to stop
```

**Keep this terminal open** - it will show real-time status as variations are generated.

### Step 2: Start ChucK

**IMPORTANT: Must run from src directory**

In a **second terminal**, run:

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
chuck chuloopa_drums_v2.ck
```

**Expected output:**
```
=====================================================
      CHULOOPA - AI Drum Variation System
=====================================================

MIDI Device: [Your Controller Name]

Drum Samples Loaded:
  Kick: XXXX samples
  Snare: XXXX samples
  Hat: XXXX samples

MIDI Controls (Single Track):
  C1  (36): Record track (press & hold)
  C#1 (37): Clear track
  D1  (38): Toggle variation mode ON/OFF (queued at loop boundary)
  D#1 (39): Regenerate with current spice level
  CC  18:   Spice level knob (0.0-1.0, real-time visual feedback)

OSC Communication:
  Sending to: localhost: 5000
  Receiving on: 5001

Variation Settings:
  Auto-cycle every: 1 loop(s)
  Default spice: 0.500000

MODE: DRUMS ONLY (Real-time drum feedback)
=====================================================

OSC listener started on port 5001
Master sync coordinator started
Main onset detection loop started

✓ CHULOOPA ready!

Quick Start:
  1. Press C1 to record a beatbox loop
  2. Wait for Python to generate 3 variations
  3. Press D1 to toggle variation mode (auto-cycles)
  4. Adjust CC 18 knob and press D#1 to regenerate
```

**ChuGL window should open** showing a red sphere (no loop yet).

### Step 3: Record Your First Loop

1. **Press and hold C1** on your MIDI controller
2. **Beatbox into your microphone** (kick, snare, hat sounds)
3. **Release C1** to stop recording

**Expected behavior:**

**In ChucK terminal:**
```
>>> TRACK 0 RECORDING STARTED <<<
Recording... onset detection active

Track 0 - KICK at 0.123 sec | Total hits: 1
Track 0 - SNARE at 0.456 sec | Total hits: 2
Track 0 - HAT at 0.789 sec | Total hits: 3
...

>>> TRACK 0 LOOPING <<<
>>> Captured 12 drum hits <<<

>>> Track 0 exported to tracks/track_0/track_0_drums.txt (12 hits) <<<
    Total loop duration: 2.182676 seconds

>>> DRUM PLAYBACK ENABLED (Drums Only Mode) <<<
```

**In Python terminal:**
```
Detected change: src/tracks/track_0/track_0_drums.txt

Loading: src/tracks/track_0/track_0_drums.txt
  Loaded 12 hits, duration: 2.183s
  Current spice level: 0.50

  Generating variation (spice: 0.50)
  Calling Gemini API (gemini-3-flash-preview)...
  Gemini reasoning: [AI explanation of variation approach]
  Generated 15 hits (original: 12)
  Saved: src/tracks/track_0/variations/track_0_drums_var1.txt
  Sending OSC: /chuloopa/variations_ready (1) to port 5001

✓ Generated variation (spice: 0.50)
============================================================
```

**In ChucK terminal:**
```
Python: Generating variation...
OSC received: /chuloopa/generation_progress
Python: Complete!
OSC received: /chuloopa/variations_ready

✓ Python: Variation ready!
  Press D1 (Note 38) to load variation
```

**ChuGL window:** Sphere should turn **green** and pulse (variation ready).

### Step 4: Load Variation

**Press D1** on your MIDI controller.

**Expected behavior:**

**In ChucK terminal:**
```
╔═══════════════════════════════════════╗
║  LOADING VARIATION                   ║
╚═══════════════════════════════════════╝

╔═══════════════════════════════════════╗
║  LOADING VARIATION 1                 ║
╚═══════════════════════════════════════╝
Loading: /path/to/src/tracks/track_0/variations/track_0_drums_var1.txt
✓ Loaded 15 drum hits
✓ Loop length: 2.183 seconds

>>> VARIATION LOADED (Playback ID: 1) <<<
```

**ChuGL window:** Sphere should turn **blue** (variation loaded).

**Audio:** You should hear a variation of your loop playing with different timing, velocities, and possibly ghost notes.

### Step 5: Adjust Spice Level and Regenerate

1. **Turn the CC 18 knob** on your controller

**Expected:**
```
Spice level: 75%
```

**ChuGL:** Spice text updates in real-time with color coding:
- **0.0-0.3**: Blue text (low spice, conservative variations)
- **0.4-0.6**: Orange text (medium spice, balanced creativity)
- **0.7-1.0**: Red text (high spice, experimental variations)

2. **Press D#1** to regenerate with new spice level

**Expected in ChucK:**
```
Sent regenerate request to Python
OSC received: /chuloopa/generation_progress
Python: Generating variation...
```

**Expected in Python:**
```
============================================================
REGENERATE requested from ChucK
============================================================
Loading: src/tracks/track_0/track_0_drums.txt
  Loaded 12 hits, duration: 2.183s
  Current spice level: 0.75

  Generating variation (spice: 0.75)
  ...
  Sending OSC: /chuloopa/variations_ready (1) to port 5001
```

The variation should be more creative/different at higher spice levels.

3. **Press D1** again to load the new variation (if you're on original) or it will auto-reload if you're already in variation mode

### Step 6: Toggle Back to Original

**Press D1** again to return to original.

**Expected:**
```
╔═══════════════════════════════════════╗
║  LOADING ORIGINAL                    ║
╚═══════════════════════════════════════╝

╔═══════════════════════════════════════╗
║  LOADING DRUM DATA FROM FILE         ║
╚═══════════════════════════════════════╝
Loading: /path/to/src/tracks/track_0/track_0_drums.txt
✓ Loaded 12 drum hits

Playing original loop
```

**ChuGL:** Sphere turns **red** (original).

**Audio:** You should hear your original recorded loop.

### Step 7: Clear and Start Over

**Press C#1** to clear the track.

**Expected:**
```
>>> CLEARING TRACK 0 <<<
Track 0 drum data cleared

╔═══════════════════════════════════════╗
║  MASTER LOOP CLEARED               ║
╚═══════════════════════════════════════╝
```

**ChuGL:** Sphere turns **gray** (no loop).

**Python:** Receives clear notification.

## Troubleshooting

### Problem: "OSC server already in use"

**Solution:** Another process is using port 5000 or 5001. Find and kill it:

```bash
lsof -i :5000
lsof -i :5001
kill <PID>
```

### Problem: "No MIDI devices found"

**Solution:** Check MIDI controller connection:

```bash
python TESTMIDIINPUT.py
```

### Problem: "Gemini API call failed"

**Solutions:**
- Check your API key is set: `echo $GEMINI_API_KEY`
- System will fallback to `groove_preserve` algorithm automatically
- Check Python terminal for error details

### Problem: "No hits found in pattern"

**Solutions:**
- Check microphone input level (adc gain)
- Onset detection might be too sensitive/insensitive
- Try beatboxing louder with clearer articulation
- Adjust `MIN_ONSET_STRENGTH` in ChucK script if needed

### Problem: Variations sound identical

**Solutions:**
- Increase spice level (CC 18 knob)
- Press D#1 to regenerate
- Check that Gemini API is working (not using fallback)

### Problem: Sphere doesn't change color

**Solutions:**
- Make sure ChuGL window is focused
- Check ChucK console for errors
- Restart ChucK script

## File Structure After Testing

After recording and generating a variation, your directory should look like:

```
src/
├── tracks/
│   └── track_0/
│       ├── track_0_drums.txt          # Your original recording
│       └── variations/
│           └── track_0_drums_var1.txt  # Generated variation
├── chuloopa_drums_v2.ck
└── drum_variation_ai.py
```

## Advanced Testing

### Test Manual Variation Generation

Instead of watch mode, generate manually (from src directory):

```bash
cd src

# Generate for track 0 with high spice
python drum_variation_ai.py --track 0 --type gemini --temperature 0.9

# Generate with different algorithms
python drum_variation_ai.py --track 0 --type groove_preserve
python drum_variation_ai.py --track 0 --type mutate
```

### Test Without Gemini API

Unset the API key to test fallback:

```bash
unset GEMINI_API_KEY
python src/drum_variation_ai.py --watch
```

Should automatically use `groove_preserve` algorithm.

## Success Criteria

✅ Python watch mode starts without errors (from src directory)
✅ ChucK starts with OSC communication established (from src directory)
✅ Recording captures drum hits with real-time feedback
✅ Python auto-generates variation after recording
✅ ChucK receives variations_ready OSC message (see debug output)
✅ Sphere turns green when variation ready
✅ D1 button loads variation (sphere turns blue)
✅ Variation sounds different from original (timing/velocity/ghost notes)
✅ Spice level updates in real-time (UI and OSC)
✅ Regenerate button (D#1) triggers new variation
✅ Higher spice = more creative variation
✅ D1 toggles back to original works correctly (sphere turns red)

## Next Steps

Once testing is complete:
- Experiment with different spice levels for different musical contexts
- Try longer/shorter loops
- Test with different beatbox styles
- Generate multiple variations by regenerating with different spice levels
- Perform live - toggle between original and variation on the fly!
