# AI Variation Automation Design

**Date:** 2026-01-29
**Project:** CHULOOPA (Single Track Focus)
**Goal:** Auto-generate AI drum variations with live performance controls

## Overview

Automate the drum variation generation workflow so that when a loop is recorded in ChucK, Python automatically generates 3 AI-powered variations. The system enables live performance variation mode where ChucK automatically cycles through variations, creating a "living" drum loop.

## 1. File Organization & Directory Structure

**Simplified to single track** (track_0 only):

```
src/
├── tracks/
│   └── track_0/
│       ├── track_0_drums.txt          # Original recorded pattern
│       └── variations/
│           ├── track_0_drums_var1.txt
│           ├── track_0_drums_var2.txt
│           └── track_0_drums_var3.txt
├── chuloopa_drums_v2.ck
└── drum_variation_ai.py
```

**Key changes:**
- ChucK exports original to `src/tracks/track_0/track_0_drums.txt` (not root directory)
- Python script watches `src/tracks/track_0/` for changes
- Variations saved to `src/tracks/track_0/variations/`
- Script auto-creates directories if they don't exist

**Benefits:**
- Clean separation of original vs. variations
- Easy to delete all variations and start fresh
- Can expand back to 3 tracks later by adding `track_1/` and `track_2/` directories

## 2. Python Script Watch Mode Behavior

**Automatic variation generation:**

1. **Run once at startup**: `python src/drum_variation_ai.py --watch`
2. **Sits in background**, monitoring `src/tracks/track_0/track_0_drums.txt`
3. **When ChucK exports a new recording**:
   - Detects file change (after 0.5s cooldown)
   - Reads current spice level from OSC message state (default: 0.5)
   - Generates 3 **cohesive variations** all based on the original:
     - Each variation is generated FROM the original loop (not from each other)
     - All 3 share the same creative direction at the given spice level
     - Small differences between the 3 for "live feel" (subtle timing, velocity, ghost notes)
     - **Goal**: At high spice (0.9), all 3 are creatively transformed in a similar way
     - **Result**: Sequential playback sounds cohesive and musical, like variations on a theme
   - Saves to `variations/` subdirectory
   - Sends OSC message to ChucK: variations ready
4. **Original file never modified**

**Updated Gemini prompt** (added to existing):
```
When generating variations, ensure they are cohesive with each other - they should share
the same creative direction and musical approach, with only subtle differences in timing,
velocity, and ghost notes to create a "live" feel. Think of them as three takes of the
same creative variation, not three different ideas.
```

**Variation types** (keeping Gemini AI as default):
- Default: Uses Gemini API for intelligent variations
- Fallback: If Gemini unavailable, uses `groove_preserve` algorithm

## 3. ChucK Side - Loading & Playing Variations

**Visual feedback for variations ready:**
- ChucK receives OSC message `/chuloopa/variations_ready`
- Updates ChuGL visualization:
  - Track sphere pulses/glows green
  - Console message: "✓ Track 0: 3 variations ready"
- Feedback persists until user loads variations

**Loading behavior (MIDI button D1/Note 38 for track 0):**

**Mode toggle system:**
- **Mode A: Original** (default state)
  - Plays `track_0_drums.txt` (the recorded original)
  - Press D1 (Note 38) → Switch to **Variation Mode**

- **Mode B: Variation Mode**
  - Randomly picks one of 3 variations and loads it immediately
  - **Auto-cycles at every N loop boundaries** (configurable, default every 1 loop)
  - Randomly picks a new variation each cycle (ensures new ≠ current)
  - Visual indicator: sphere blue to show variation mode active
  - Console: "Variation Mode: loaded var2.txt (auto-cycling)"
  - Press D1 (Note 38) → Switch back to **Original Mode**

**Result**: Set it to variation mode and let it evolve automatically during performance, creating a living, dynamic drum loop.

## 4. Spice Level Control & Regeneration

**MIDI Controls (ChucK side):**

**4 Adjacent Buttons:**
- **Note 36 (C1)**: Record track (press & hold)
- **Note 37 (C#1)**: Clear track
- **Note 38 (D1)**: Toggle variation mode ON/OFF (only works if variations ready)
- **Note 39 (D#1)**: Regenerate variations with current spice level

**Knob:**
- **CC 18**: Spice level (0-127 → 0.0-1.0, default: **0.5**)
  - Updates display in real-time
  - Sends OSC message to Python immediately
  - Does NOT trigger regeneration automatically

**Regeneration workflow:**
1. User records loop → Python auto-generates 3 variations at spice 0.5
2. User adjusts spice knob (CC 18, e.g., to 0.8)
3. User presses **Note 39 (regenerate button)**
4. ChucK sends OSC message `/chuloopa/regenerate` to Python
5. Python regenerates 3 new variations at spice 0.8
6. Variations ready indicator updates when done

**Visual Display:**
- **Spice level**: "SPICE: 0.5" (top-right, color-coded: blue→orange→red)
- **Variation status**: Sphere glow when ready
  - Red: Original mode
  - Green pulse: Variations ready (not loaded yet)
  - Blue: Variation mode active

## 5. ChucK ↔ Python Communication via OSC

**OSC Communication** (low-latency, event-driven):

**ChucK → Python** (sends immediately to `localhost:5000`):
- `/chuloopa/spice <float>` - Spice level changed (CC 18)
- `/chuloopa/regenerate` - Regenerate button pressed (Note 39)
- `/chuloopa/track_cleared` - Track cleared (Note 37)
- `/chuloopa/recording_started` - Recording started (Note 36 pressed)

**Python → ChucK** (sends immediately to `localhost:5001`):
- `/chuloopa/variations_ready <int>` - Number of variations ready (3)
- `/chuloopa/generation_progress <string>` - Status update ("Generating var1...", "Complete!")
- `/chuloopa/error <string>` - Error message if generation fails

**File-based only for drum data** (actual pattern storage):
- `src/tracks/track_0/track_0_drums.txt` - Original (ChucK writes, Python reads)
- `src/tracks/track_0/variations/*.txt` - Variations (Python writes, ChucK reads)

**Benefits:**
- Instant MIDI response (no file I/O delays)
- No polling needed (event-driven)
- Real-time visual feedback during generation
- Perfect for live performance

**Error handling:**
- If Gemini API fails → fallback to `groove_preserve` algorithm
- If spice message missing → default 0.5
- If original drum file empty/corrupt → Python sends error OSC, no variations generated
- ChucK checks file sizes before loading to avoid corrupted files

## 6. ChucK Implementation Details

**Configuration variables** (at top of script):
```chuck
// === VARIATION MODE CONFIGURATION ===
1 => int VARIATION_CYCLE_LOOPS;      // How many loops before switching variation
                                     // 1 = every loop, 2 = every 2 loops, etc.
0.5 => float DEFAULT_SPICE_LEVEL;    // Default spice level (0.0-1.0)
```

**New state variables:**
```chuck
// Variation mode state
int variation_mode_active;           // 0 = playing original, 1 = playing variations
int variations_ready;                // 0 = not ready, 1 = ready to use
float current_spice_level;           // 0.0-1.0
int current_variation_index;         // Which variation is currently loaded (1-3)
int variation_loop_counter;          // Count loops before switching
```

**OSC setup** (correct ChucK syntax):
```chuck
OscIn oin;
OscMsg msg;
5001 => oin.port;
oin.addAddress("/chuloopa/variations_ready");
oin.addAddress("/chuloopa/generation_progress");
oin.addAddress("/chuloopa/error");

OscOut oout;
oout.dest("localhost", 5000);

fun void oscListener() {
    while(true) {
        oin => now;
        while(oin.recv(msg)) {
            if(msg.address == "/chuloopa/variations_ready") {
                msg.getInt(0) => int num_variations;
                1 => variations_ready;
                // Update visual feedback
            }
            else if(msg.address == "/chuloopa/generation_progress") {
                msg.getString(0) => string status;
                <<< "Python:", status >>>;
            }
            else if(msg.address == "/chuloopa/error") {
                msg.getString(0) => string error;
                <<< "ERROR:", error >>>;
            }
        }
    }
}

spork ~ oscListener();
```

**OSC sender examples:**
```chuck
// Send spice level
fun void sendSpiceLevel(float spice) {
    oout.start("/chuloopa/spice");
    spice => oout.add;
    oout.send();
}

// Send regenerate trigger
fun void sendRegenerate() {
    oout.start("/chuloopa/regenerate");
    oout.send();
}
```

**Auto-cycling logic:**
- Increment `variation_loop_counter` at each loop boundary
- When `counter >= VARIATION_CYCLE_LOOPS`, pick new random variation (1-3)
- Ensure new pick ≠ current variation (always switches)
- Load new variation using existing `loadDrumDataFromFile()` function
- Reset counter to 0 after switching
- Update visual feedback

**Visual feedback enhancements:**
- Spice level text (GText in ChuGL, top-right)
- Sphere color indicates mode:
  - Red: Original mode
  - Green pulse: Variations ready (not loaded yet)
  - Blue: Variation mode active
- Console shows which variation is playing

## 7. Python Implementation Details

**Main script modes:**
```python
# New watch mode - runs continuously
python src/drum_variation_ai.py --watch
```

**OSC setup** (using `pythonosc`):
```python
from pythonosc import dispatcher, osc_server, udp_client
import threading

# Listen for ChucK messages on port 5000
dispatcher = dispatcher.Dispatcher()
dispatcher.map("/chuloopa/spice", handle_spice_change)
dispatcher.map("/chuloopa/regenerate", handle_regenerate)
dispatcher.map("/chuloopa/track_cleared", handle_track_cleared)

server = osc_server.ThreadingOSCUDPServer(("localhost", 5000), dispatcher)

# Send to ChucK on port 5001
client = udp_client.SimpleUDPClient("localhost", 5001)
```

**Generation workflow:**
1. Receives trigger (file change OR `/chuloopa/regenerate` OSC)
2. Reads current spice level (stored in memory from last OSC update, default 0.5)
3. Sends: `client.send_message("/chuloopa/generation_progress", "Generating variations...")`
4. Generates 3 variations via Gemini (all at same spice, with prompt for cohesiveness)
5. Saves to `src/tracks/track_0/variations/track_0_drums_var1.txt` (and var2, var3)
6. Sends: `client.send_message("/chuloopa/variations_ready", 3)`

**File watcher:**
- Watches `src/tracks/track_0/track_0_drums.txt` for modifications
- Uses `watchdog` library (existing in code)
- Triggers same generation workflow as regenerate button

**Handler functions:**
```python
def handle_spice_change(address, spice_level):
    global current_spice_level
    current_spice_level = spice_level
    print(f"Spice level updated: {spice_level:.2f}")

def handle_regenerate(address):
    print("Regenerate requested...")
    generate_variations()

def handle_track_cleared(address):
    print("Track cleared")
    # Could delete variations here if desired
```

**Dependencies:**
- `pythonosc` (NEW - for OSC communication)
- `watchdog` (existing - file watching)
- `google-genai` (existing - AI variations)
- `numpy` (existing - algorithmic variations)

## Implementation Checklist

### Python Script (`drum_variation_ai.py`)
- [ ] Add `pythonosc` dependency to requirements
- [ ] Refactor to use OSC instead of file-based state
- [ ] Update watch mode to monitor new file location
- [ ] Add OSC server (port 5000) for receiving ChucK messages
- [ ] Add OSC client (port 5001) for sending to ChucK
- [ ] Update file paths to `src/tracks/track_0/`
- [ ] Implement 3-variation generation with cohesive prompt
- [ ] Add error handling and fallback to groove_preserve

### ChucK Script (`chuloopa_drums_v2.ck`)
- [ ] Add configuration variables (VARIATION_CYCLE_LOOPS, DEFAULT_SPICE_LEVEL)
- [ ] Add new state variables for variation mode
- [ ] Implement OSC listener on port 5001
- [ ] Implement OSC sender to port 5000
- [ ] Update export path to `src/tracks/track_0/track_0_drums.txt`
- [ ] Add CC 18 handler for spice knob
- [ ] Remap buttons: Note 38 (toggle variation), Note 39 (regenerate)
- [ ] Implement variation mode toggle logic
- [ ] Implement auto-cycling at loop boundaries
- [ ] Add spice level GText display
- [ ] Update sphere colors for mode feedback
- [ ] Test variation loading from new file paths

### Testing
- [ ] Test OSC communication both directions
- [ ] Test auto-generation on new recording
- [ ] Test manual regeneration with different spice levels
- [ ] Test variation mode toggle and auto-cycling
- [ ] Test Gemini API integration
- [ ] Test fallback to groove_preserve if Gemini fails
- [ ] Test with MIDI controller (CC 18, Notes 36-39)

## Future Enhancements (Out of Scope)

- Expand back to 3 tracks
- MIDI learn for controller mapping
- Variation preview before loading
- Save/load spice presets
- Visual waveform display of variations
- Integration with GrooVAE model
