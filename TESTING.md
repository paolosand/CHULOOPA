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
- **CC 18** mapped to a knob (spice level)
- **Notes 36-39** (C1, C#1, D1, D#1) mapped to buttons

## Testing Workflow

### Step 1: Start Python Watch Mode

Open a terminal and run:

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
python src/drum_variation_ai.py --watch
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

In a **second terminal**, run:

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
chuck src/chuloopa_drums_v2.ck
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
  D1  (38): Toggle variation mode ON/OFF
  D#1 (39): Regenerate variations
  CC  18:   Spice level knob (0.0-1.0)

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

  Generating variation 1/3 (spice: 0.50)
  Calling Gemini API (gemini-3-flash-preview)...
  Gemini reasoning: [AI explanation of variation approach]
  Generated 15 hits (original: 12)
  Saved: src/tracks/track_0/variations/track_0_drums_var1.txt

  Generating variation 2/3 (spice: 0.50)
  ...

  Generating variation 3/3 (spice: 0.50)
  ...

✓ Generated 3 variations (spice: 0.50)
============================================================
```

**In ChucK terminal:**
```
Python: Generating variation 1/3...
Python: Generating variation 2/3...
Python: Generating variation 3/3...

✓ Python: 3 variations ready!
  Press D1 (Note 38) to toggle variation mode
```

**ChuGL window:** Sphere should turn **green** and pulse (variations ready).

### Step 4: Toggle Variation Mode

**Press D1** on your MIDI controller.

**Expected behavior:**

**In ChucK terminal:**
```
╔═══════════════════════════════════════╗
║  VARIATION MODE: ON                  ║
╚═══════════════════════════════════════╝

╔═══════════════════════════════════════╗
║  LOADING VARIATION 2                 ║
╚═══════════════════════════════════════╝
Loading: tracks/track_0/variations/track_0_drums_var2.txt
✓ Loaded 15 drum hits
✓ Loop length: 2.183 seconds

>>> VARIATION 2 LOADED (Playback ID: 1) <<<

Auto-cycling every 1 loop(s)
```

**ChuGL window:** Sphere should turn **blue** (variation mode active).

**Audio:** You should hear a variation of your loop playing with subtle differences.

### Step 5: Watch Auto-Cycling

Wait for the loop to complete (every ~2 seconds in this example).

**Expected behavior:**

At each loop boundary:
```
Auto-cycling to variation 3

╔═══════════════════════════════════════╗
║  LOADING VARIATION 3                 ║
╚═══════════════════════════════════════╝
...

>>> VARIATION 3 LOADED <<<
```

The variations should **cycle randomly** - you'll hear different variations each loop cycle, making the drum pattern feel "alive" and dynamic.

### Step 6: Adjust Spice Level and Regenerate

1. **Turn the CC 18 knob** on your controller

**Expected:**
```
Spice level: 75%
```

**ChuGL:** Spice text updates in real-time, color changes (blue → orange → red).

2. **Press D#1** to regenerate with new spice level

**Expected in ChucK:**
```
Sent regenerate request to Python
```

**Expected in Python:**
```
============================================================
REGENERATE requested from ChucK
============================================================
Loading: src/tracks/track_0/track_0_drums.txt
  Loaded 12 hits, duration: 2.183s
  Current spice level: 0.75

  Generating variation 1/3 (spice: 0.75)
  ...
```

The variations should be more creative/different at higher spice levels.

### Step 7: Toggle Back to Original

**Press D1** again to exit variation mode.

**Expected:**
```
╔═══════════════════════════════════════╗
║  VARIATION MODE: OFF                 ║
╚═══════════════════════════════════════╝

╔═══════════════════════════════════════╗
║  LOADING DRUM DATA FROM FILE         ║
╚═══════════════════════════════════════╝
Loading: tracks/track_0/track_0_drums.txt
✓ Loaded 12 drum hits

Playing original loop
```

**ChuGL:** Sphere turns **red** (original mode).

**Audio:** You should hear your original recorded loop.

### Step 8: Clear and Start Over

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

After recording and generating variations, your directory should look like:

```
src/
├── tracks/
│   └── track_0/
│       ├── track_0_drums.txt          # Your original recording
│       └── variations/
│           ├── track_0_drums_var1.txt
│           ├── track_0_drums_var2.txt
│           └── track_0_drums_var3.txt
├── chuloopa_drums_v2.ck
└── drum_variation_ai.py
```

## Advanced Testing

### Test Different Variation Cycle Intervals

Edit `src/chuloopa_drums_v2.ck`:

```chuck
2 => int VARIATION_CYCLE_LOOPS;  // Change from 1 to 2 (cycles every 2 loops)
```

### Test Manual Variation Generation

Instead of watch mode, generate manually:

```bash
# Generate for track 0 with high spice
python src/drum_variation_ai.py --track 0 --type gemini --temperature 0.9

# Generate with different algorithms
python src/drum_variation_ai.py --track 0 --type groove_preserve
python src/drum_variation_ai.py --track 0 --type mutate
```

### Test Without Gemini API

Unset the API key to test fallback:

```bash
unset GEMINI_API_KEY
python src/drum_variation_ai.py --watch
```

Should automatically use `groove_preserve` algorithm.

## Success Criteria

✅ Python watch mode starts without errors
✅ ChucK starts with OSC communication established
✅ Recording captures drum hits with real-time feedback
✅ Python auto-generates 3 variations after recording
✅ ChucK receives variations_ready OSC message
✅ Sphere turns green when variations ready
✅ Variation mode toggles on/off with D1
✅ Variations auto-cycle at loop boundaries
✅ Spice level updates in real-time
✅ Regenerate button triggers new variations
✅ All 3 variations sound cohesive but slightly different
✅ Toggle back to original works correctly

## Next Steps

Once testing is complete:
- Adjust `VARIATION_CYCLE_LOOPS` to your preference
- Experiment with different spice levels for different musical contexts
- Try longer/shorter loops
- Test with different beatbox styles
- Perform live with variation mode!
