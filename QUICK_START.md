# CHULOOPA Quick Start Guide

**Get beatboxing with CHULOOPA Drums in 10 minutes**

## What is CHULOOPA Drums?

CHULOOPA Drums is a real-time drum looping system that:
1. **Transcribes** your beatbox into drum patterns (kick, snare, hat)
2. **Plays back** drum samples in real-time as you beatbox
3. **Loops** your drum patterns perfectly in sync
4. **Loads/swaps** patterns from files at loop boundaries

**Key Feature:** Personalized ML classifier trained on YOUR voice!

---

## Installation

**Requirements:**
- ChucK 1.5.x+ (with ChuGL support)
- Python 3.x (for training)
- MIDI controller (QuNeo recommended)
- Microphone for beatbox input

**Python packages:**
```bash
pip install scikit-learn pandas numpy joblib
```

**No other installation needed!** Just navigate to CHULOOPA:

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
```

---

## 10-Minute Workflow

### Step 1: Train Your Classifier (One-Time, ~5 minutes)

**Important:** This must be done BEFORE using CHULOOPA for the first time!

#### 1a. Record Training Samples

```bash
chuck src/drum_sample_recorder.ck
```

You'll see:
```
╔═══════════════════════════════════════╗
║  DRUM SAMPLE RECORDER                ║
╚═══════════════════════════════════════╝

Press 1/2/3 to record samples, Q to quit
```

**Record 10 samples of each drum:**

1. **Press 1**: Record KICK samples
   - Say "BOOM" into the mic (make a deep kick sound)
   - Repeat 10 times
   - Each sample: 1 second long

2. **Press 2**: Record SNARE samples
   - Say "PAH" or "TSH" into the mic (sharp snare sound)
   - Repeat 10 times

3. **Press 3**: Record HI-HAT samples
   - Say "TSS" or "TSK" into the mic (high-pitched hat sound)
   - Repeat 10 times

4. **Press Q**: Quit and save
   - Creates `training_samples.csv` (30 samples)

**Tips:**
- Be **consistent** with your sounds
- Record in a **quiet environment**
- Use **your normal beatbox** voice (this is personalized!)
- Each sample should be **distinct and clear**

#### 1b. Train the Classifier

```bash
python train_classifier.py
```

You'll see:
```
Training KNN classifier...
Accuracy: 95.8%
✓ Model saved to drum_classifier.pkl
```

**Files created:**
- `drum_classifier.pkl` - Your personalized KNN model
- `training_samples.csv` - Your training data (saved)

---

### Step 2: Run CHULOOPA Drums V2

```bash
chuck src/chuloopa_drums_v2.ck
```

You'll see:
```
╔═══════════════════════════════════════╗
║  KNN CLASSIFIER READY                ║
╚═══════════════════════════════════════╝

MODE: DRUMS ONLY (Real-time drum feedback during recording)
```

A visualization window will open showing 3 color-coded spheres (tracks).

---

### Step 3: Record Your First Drum Loop

**Press and HOLD C1** on your QuNeo controller

**Beatbox into the mic:** "BOOM tss tss BOOM tss tss"

**What happens:**
- System detects each sound (onset detection)
- Classifies: kick, hat, hat, kick, hat, hat
- **Plays drum samples IMMEDIATELY** (real-time feedback!)
- Console shows: `Track 0 - KICK at 0.037 sec | Total hits: 1`

**Release C1** to stop recording

**What happens:**
- Auto-exports to `track_0_drums.txt`
- Starts looping your drum pattern
- Console: `>>> DRUM PLAYBACK ENABLED (Drums Only Mode) <<<`

**You should now hear your drums looping!**

---

### Step 4: Add More Tracks

**Record Track 1 (C#1):**
- Press and HOLD C#1
- Beatbox: "tss tss tss tss" (hi-hat pattern)
- Release
- Track 1 loops in sync with Track 0!

**Record Track 2 (D1):**
- Press and HOLD D1
- Beatbox: "PAH...PAH...PAH" (snare backbeat)
- Release
- All 3 tracks now loop together perfectly!

**Important:** First track becomes MASTER - all tracks sync to it!

---

### Step 5: Load a Saved Pattern

**During playback, press G1** (mid-loop is fine!)

Console shows:
```
>>> QUEUED: Track 0 will load from file at next loop cycle <<<
```

**Current loop continues** until the end

**At loop boundary:**
```
=== LOOP BOUNDARY: Processing queued actions ===
Executing queued load for track 0
>>> TRACK 0 LOADED FROM FILE (DRUM-ONLY MODE, Playback ID: 1) <<<
```

**New pattern starts immediately** - zero overlap, perfect sync!

---

### Step 6: Adjust Volume

**Use CC sliders on QuNeo:**
- **CC 45**: Track 0 drum volume
- **CC 46**: Track 1 drum volume
- **CC 47**: Track 2 drum volume

Console shows: `Track 0 Volume: 80%`

---

### Step 7: Clear Tracks

**Press D#1, E1, or F1** to queue track clearing

Console: `>>> QUEUED: Track 0 will clear at next loop cycle <<<`

Track clears at next boundary (smooth transition)

---

## MIDI Control Reference (QuNeo)

### Recording (Press & Hold)
| Pad  | MIDI Note | Function              |
|------|-----------|----------------------|
| C1   | 36        | Record Track 0       |
| C#1  | 37        | Record Track 1       |
| D1   | 38        | Record Track 2       |

**Usage:** Press and HOLD to record, RELEASE to stop

### Clearing (Queued)
| Pad  | MIDI Note | Function              |
|------|-----------|----------------------|
| D#1  | 39        | Clear Track 0        |
| E1   | 40        | Clear Track 1        |
| F1   | 41        | Clear Track 2        |

**Usage:** Single press (executes at next loop boundary)

### Loading from File (Queued)
| Pad  | MIDI Note | Function                      |
|------|-----------|------------------------------|
| G1   | 43        | Load track_0_drums.txt       |
| G#1  | 44        | Load track_1_drums.txt       |
| A1   | 45        | Load track_2_drums.txt       |

**Usage:** Single press (executes at next loop boundary)

### Export
| Pad  | MIDI Note | Function              |
|------|-----------|----------------------|
| A#1  | 46        | Export all tracks    |

**Note:** Auto-exports after recording anyway!

### Volume Control
| Control | CC Number | Function             |
|---------|-----------|----------------------|
| Slider  | CC 45     | Track 0 Volume       |
| Slider  | CC 46     | Track 1 Volume       |
| Slider  | CC 47     | Track 2 Volume       |

---

## Understanding the Output Files

### track_N_drums.txt Format

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

**Columns:**
1. `DRUM_CLASS`: 0=kick, 1=snare, 2=hat
2. `TIMESTAMP`: When hit occurs (seconds from loop start)
3. `VELOCITY`: How loud (0.0-1.0)
4. `DELTA_TIME`: Time until next hit (last one = time to loop end)

**The delta_time on the last hit is critical for perfect loop timing!**

---

## Troubleshooting

### "No MIDI devices found!"
**Solution:**
- Check MIDI controller is connected
- Verify MIDI port: Edit line 62 in `chuloopa_drums_v2.ck`
  ```chuck
  0 => int MIDI_DEVICE;  // Try changing to 1, 2, etc.
  ```

### "Could not load kick.wav / snare.wav / hat.WAV"
**Solution:**
- Check `samples/` directory exists
- Verify sample files are present:
  ```bash
  ls samples/
  # Should show: kick.wav  snare.wav  hat.WAV
  ```

### "No drum hits detected during recording"
**Solutions:**
- **Beatbox LOUDER** - system needs strong signal
- **Get closer to mic**
- Lower threshold in code (line 76):
  ```chuck
  0.005 => float MIN_ONSET_STRENGTH;  // Lower = more sensitive
  ```

### "Classifier accuracy too low"
**Solutions:**
- Record MORE training samples (20+ per class)
- Be more **consistent** with sounds
- Record in **quieter environment**
- Retrain: `python train_classifier.py`

### "Drums triggering on silence / too many false positives"
**Solution:**
- Increase threshold (line 76):
  ```chuck
  0.02 => float MIN_ONSET_STRENGTH;  // Higher = less sensitive
  ```

### "Drums out of sync after loading from file"
**This shouldn't happen!** The system uses:
- Master sync with musical ratios
- Delta_time for precise loop lengths
- Queued actions at loop boundaries

If it does happen:
- Check console for error messages
- Verify `track_N_drums.txt` has delta_time column
- Check total loop duration in file header

### "Loaded drums play at the same time as buffer drums"
**This is fixed in V2!** Each playback session has a unique ID.
- Old hits check their ID and abort if it doesn't match
- Console shows: `Track 0 - Drum playback started (ID: 1)`
- Incrementing ID = old drums stop, new drums start

---

## Tips for Best Results

### Recording Training Samples
1. **Be consistent** - Use the same beatbox sounds every time
2. **Quiet room** - Minimize background noise
3. **Normal voice** - Use your natural beatbox (not exaggerated)
4. **Distinct sounds** - Make kick/snare/hat clearly different
5. **More is better** - 20+ samples per class = higher accuracy

### Recording Loops
1. **Start simple** - Begin with basic kick pattern
2. **Layer gradually** - Add snare, then hi-hat
3. **Use real-time feedback** - Listen to classification as you beatbox
4. **If misclassified** - Retrain with more/better samples
5. **Clear and retry** - Don't be afraid to start over!

### Pattern Loading
1. **Queue mid-loop** - Press G1 anytime, it waits for boundary
2. **Smooth transitions** - No overlap, no gaps
3. **Edit txt files** - Manually adjust timing/velocity if needed
4. **Backup patterns** - Save interesting patterns to new files

### Performance
1. **Build gradually** - Start with one track, layer more
2. **Volume balance** - Use CC 45-47 to balance tracks
3. **Clear strategically** - Remove tracks to create space
4. **Reload variations** - Try different patterns on same track

---

## Next Steps

### Customize Your System
- Adjust onset detection sensitivity (line 76)
- Change loop duration limit (line 66): `30::second => dur MAX_LOOP_DURATION;`
- Modify drum samples in `samples/` directory
- Edit training data in `training_samples.csv`

### Integrate AI Variations
**Coming Soon:**
- GrooVAE for drum pattern generation
- Pattern evolution and humanization
- Style transfer between performances

### Improve Visuals
**Coming Soon:**
- Per-drum-hit visual feedback
- Pattern similarity visualization
- Real-time classification confidence display

---

## Example Session

```bash
# Terminal 1: Train classifier (one-time setup)
chuck src/drum_sample_recorder.ck
# Record 10 kicks, 10 snares, 10 hats, press Q
python train_classifier.py

# Terminal 1: Run CHULOOPA
chuck src/chuloopa_drums_v2.ck

# On QuNeo:
# 1. Press & hold C1, beatbox "BOOM tss BOOM tss", release
# 2. Press & hold C#1, beatbox "tss tss tss tss", release
# 3. Press & hold D1, beatbox "PAH...PAH", release
# 4. Adjust volumes with CC 45-47
# 5. Press G1 to reload track 0 from file
# 6. Press D#1 to clear track 0

# Press Ctrl+C to stop
```

---

## File Structure Reference

```
CHULOOPA/
├── src/
│   ├── chuloopa_drums_v2.ck         ← Main system (START HERE!)
│   ├── drum_sample_recorder.ck      ← Training sample collector
│   └── chuloopa_main.ck             ← OLD: Melody system (archived)
│
├── samples/                          ← Drum samples
│   ├── kick.wav
│   ├── snare.wav
│   └── hat.WAV
│
├── train_classifier.py               ← Trains KNN model
├── training_samples.csv              ← Your training data (generated)
├── drum_classifier.pkl               ← Your model (generated)
│
├── track_0_drums.txt                 ← Exported patterns (generated)
├── track_1_drums.txt
└── track_2_drums.txt
```

---

## Getting Help

1. **Read README.md** - Comprehensive technical documentation
2. **Check code comments** - All files are well-commented
3. **Console messages** - System prints helpful debugging info
4. **Test systematically** - Try training → recording → playback separately

---

**Ready to beatbox? Start with Step 1!**

```bash
# Step 1: Train
chuck src/drum_sample_recorder.ck
python train_classifier.py

# Step 2: Loop!
chuck src/chuloopa_drums_v2.ck
```

🥁 Happy beatboxing! 🎵
