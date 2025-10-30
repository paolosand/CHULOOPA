//---------------------------------------------------------------------
// name: [MASTER LOOP] looper_midi_quneo_visual_freeform.ck
// desc: Multi-track audio looper with ChuGL visualization + MASTER LOOP SYNC
//       3 independent audio tracks with frequency-reactive spheres
//       Each sphere reacts to amplitude (size) and frequency (color)
//       DRIFT PREVENTION: First loop becomes master, subsequent loops
//       auto-adjust to clean multiples (0.25×, 0.5×, 1×, 2×, etc.)
//
// Recording Behavior:
//   PRESS AND HOLD to record - starts immediately
//   RELEASE to stop - loop length adjusted to sync with master
//
// Sync System:
//   - First recorded loop = MASTER (sets the timing reference)
//   - Subsequent loops automatically snap to nearest multiple of master
//   - Valid multipliers: 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0
//   - System chooses closest match to what you recorded
//   - Clear all tracks to reset master and start fresh
//
// MIDI Mapping (customize below):
//   NOTES (for pad triggers):
//     C1, C#1, D1 (36-38):  Press & hold to record tracks 0-2
//     E1, F1, F#1 (40-42):  Press to clear tracks 0-2
//   
//   CCs (for continuous controls - sliders/knobs):
//     CC 45-47:    Volume control for tracks 0-2
//
// Visual Features:
//   Track Spheres:
//     - SIZE: Amplitude/volume of playback
//     - COLOR: Dominant frequency (cool to warm gradient)
//       Blue → Cyan → Green → Yellow → Red
//       (low frequencies → high frequencies)
//     - Master track has a subtle gold highlight
//
// Usage:
//   chuck "[MASTER LOOP] looper_midi_quneo_visual_freeform.ck"
//---------------------------------------------------------------------

// === MIDI CONFIGURATION ===
36 => int NOTE_RECORD_TRACK_0;   // C1
37 => int NOTE_RECORD_TRACK_1;   // C#1
38 => int NOTE_RECORD_TRACK_2;   // D1

40 => int NOTE_CLEAR_TRACK_0;    // E1
41 => int NOTE_CLEAR_TRACK_1;    // F1
42 => int NOTE_CLEAR_TRACK_2;    // F#1

45 => int CC_VOLUME_TRACK_0;
46 => int CC_VOLUME_TRACK_1;
47 => int CC_VOLUME_TRACK_2;

0 => int MIDI_DEVICE;

// === CONFIGURATION ===
3 => int NUM_TRACKS;

// === MASTER LOOP SYNC SYSTEM ===
-1 => int master_track;
0::second => dur master_duration;
0 => int has_master;

// Valid multipliers for sync (most common musical ratios)
[0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0] @=> float valid_multipliers[];

// Find best multiplier to sync with master loop
fun dur findBestMultiplier(dur recorded_duration, dur master_duration) {
    1000000.0 => float best_error;  // Large initial value
    1.0 => float best_multiplier;

    // Test each multiplier
    for(0 => int i; i < valid_multipliers.size(); i++) {
        valid_multipliers[i] => float mult;
        master_duration * mult => dur target;

        // Calculate absolute error
        Math.fabs((recorded_duration - target) / second) => float error;

        if(error < best_error) {
            error => best_error;
            mult => best_multiplier;
        }
    }

    return master_duration * best_multiplier;
}

// Check if any loops exist
fun int anyLoopsExist() {
    for(0 => int i; i < NUM_TRACKS; i++) {
        if(has_loop[i]) return 1;
    }
    return 0;
}

// === CHUGL SETUP ===
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ camera;
camera.posZ(8.0);

// Create 3 spheres for track visualization
GSphere track_sphere[NUM_TRACKS];
for(0 => int i; i < NUM_TRACKS; i++) {
    track_sphere[i] --> scene;
    track_sphere[i].posX(-3.0 + (i * 3.0));  // Evenly spaced: -3, 0, +3
    track_sphere[i].posY(0);
    track_sphere[i].sca(0.8);
    
    // Different starting colors (blue, cyan, green - all cool tones)
    if(i == 0) track_sphere[i].color(@(0.2, 0.3, 0.9));      // Blue
    else if(i == 1) track_sphere[i].color(@(0.2, 0.7, 0.8)); // Cyan
    else if(i == 2) track_sphere[i].color(@(0.3, 0.8, 0.4)); // Green
}

// Add some lighting
GDirLight light --> scene;
light.intensity(0.8);
light.rotX(-45);

// === AUDIO SETUP ===
adc => Gain input_gain => blackhole;
1.0 => input_gain.gain;

// Create array of LiSa loopers (one per track)
LiSa lisa[NUM_TRACKS];
Gain output_gains[NUM_TRACKS];

// === AUDIO ANALYSIS SETUP ===
// Track audio analysis (FFT for frequency + RMS for amplitude)
FFT track_fft[NUM_TRACKS];
RMS track_rms[NUM_TRACKS];
Gain track_analysis_gain[NUM_TRACKS];

// Configure each track
10::second => dur max_duration;
for(0 => int i; i < NUM_TRACKS; i++) {
    // Setup LiSa
    max_duration => lisa[i].duration;
    1.0 => lisa[i].gain;
    adc => lisa[i];
    1.0 => lisa[i].rate;
    1 => lisa[i].loop;
    0 => lisa[i].bi;

    // Setup output gain
    lisa[i] => output_gains[i] => dac;
    0.7 => output_gains[i].gain;
    
    // Setup audio analysis for each track (FFT + RMS chain)
    lisa[i] => track_analysis_gain[i] => track_fft[i] =^ track_rms[i] => blackhole;
    3.0 => track_analysis_gain[i].gain;  // Boost for better detection
    2048 => track_fft[i].size;
    Windowing.hann(2048) => track_fft[i].window;
}

// === STATE VARIABLES (per track) ===
int is_recording[NUM_TRACKS];
int is_playing[NUM_TRACKS];
int waiting_to_record[NUM_TRACKS];
float loop_length[NUM_TRACKS];
dur recorded_duration[NUM_TRACKS];
int has_loop[NUM_TRACKS];
time record_start_time[NUM_TRACKS];

// Initialize track states
for(0 => int i; i < NUM_TRACKS; i++) {
    0 => is_recording[i];
    0 => is_playing[i];
    0 => waiting_to_record[i];
    0.0 => loop_length[i];
    0::second => recorded_duration[i];
    0 => has_loop[i];
}

// === TRACK FUNCTIONS ===

fun void startRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) {
        <<< "Invalid track:", track >>>;
        return;
    }

    if(is_recording[track]) {
        <<< "Track", track, "already recording!" >>>;
        return;
    }

    <<< ">>> TRACK", track, "RECORDING STARTED (press and hold) <<<" >>>;

    0 => lisa[track].play;
    lisa[track].clear();
    0::second => lisa[track].recPos;
    1 => lisa[track].record;

    1 => is_recording[track];
    0 => waiting_to_record[track];
    now => record_start_time[track];

    spork ~ recordingMonitor(track);
}

fun void stopRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) {
        <<< "Invalid track:", track >>>;
        return;
    }

    if(is_recording[track]) {
        0 => lisa[track].record;
        0 => is_recording[track];

        lisa[track].recPos() => recorded_duration[track];

        // === MASTER LOOP LOGIC ===
        if(!has_master) {
            // First loop becomes master
            track => master_track;
            recorded_duration[track] => master_duration;
            1 => has_master;
            
            <<< "" >>>;
            <<< "╔═══════════════════════════════════════╗" >>>;
            <<< "║  MASTER LOOP SET: Track", track, "          ║" >>>;
            <<< "╚═══════════════════════════════════════╝" >>>;
            <<< "Duration:", master_duration / second, "seconds" >>>;
            <<< "All future loops will sync to this!" >>>;
            <<< "" >>>;
        } else {
            // Adjust to best fit of master
            findBestMultiplier(recorded_duration[track], master_duration) => dur adjusted;
            
            // Calculate multiplier for display
            (adjusted / master_duration) $ float => float multiplier;
            
            // Calculate how much we adjusted (for user feedback)
            Math.fabs((adjusted - recorded_duration[track]) / second) => float adjustment;
            
            adjusted => recorded_duration[track];
            
            <<< "" >>>;
            <<< ">>> TRACK", track, "SYNCED TO MASTER <<<" >>>;
            <<< "Adjusted to", multiplier, "× master length" >>>;
            <<< "Final length:", recorded_duration[track] / second, "seconds" >>>;
            if(adjustment > 0.01) {
                <<< "Adjustment:", adjustment, "seconds" >>>;
            }
            <<< "" >>>;
        }

        recorded_duration[track] / second => loop_length[track];

        if(loop_length[track] > 0.1) {
            0::second => lisa[track].playPos;
            recorded_duration[track] => lisa[track].loopEnd;
            0::second => lisa[track].loopStart;
            1 => lisa[track].loop;
            1 => lisa[track].play;
            1 => is_playing[track];
            1 => has_loop[track];

            <<< ">>> TRACK", track, "LOOPING <<<" >>>;
        } else {
            <<< "Track", track, "recording too short, not looping" >>>;
        }
    } else {
        <<< "Track", track, "not recording!" >>>;
    }
}

fun void clearTrack(int track) {
    if(track < 0 || track >= NUM_TRACKS) {
        <<< "Invalid track:", track >>>;
        return;
    }

    <<< ">>> CLEARING TRACK", track, "<<<" >>>;
    0 => lisa[track].play;
    0 => lisa[track].record;
    lisa[track].clear();
    0 => is_recording[track];
    0 => is_playing[track];
    0 => waiting_to_record[track];
    0.0 => loop_length[track];
    0::second => recorded_duration[track];
    0 => has_loop[track];
    
    // If we cleared the master track, check if we need to reset master
    if(track == master_track) {
        if(!anyLoopsExist()) {
            <<< "" >>>;
            <<< "╔═══════════════════════════════════════╗" >>>;
            <<< "║  MASTER LOOP CLEARED               ║" >>>;
            <<< "╚═══════════════════════════════════════╝" >>>;
            <<< "Next recorded loop will become new master" >>>;
            <<< "" >>>;
            
            -1 => master_track;
            0::second => master_duration;
            0 => has_master;
        }
    }
}

fun void setTrackVolume(int track, float vol) {
    if(track < 0 || track >= NUM_TRACKS) {
        <<< "Invalid track:", track >>>;
        return;
    }

    Math.max(0.0, Math.min(1.0, vol)) => float clamped_vol;
    clamped_vol => output_gains[track].gain;
    <<< "Track", track, "volume set to:", clamped_vol >>>;
}

fun void recordingMonitor(int track) {
    while(is_recording[track]) {
        now - record_start_time[track] => dur elapsed;

        if(elapsed >= max_duration) {
            <<< "Track", track, "max duration reached, stopping" >>>;
            stopRecording(track);
            return;
        }

        100::ms => now;
    }
}

// === FREQUENCY ANALYSIS FUNCTIONS ===
// Vocal frequency ranges for color mapping
80.0 => float VOCAL_LOW;
500.0 => float VOCAL_MID;
1000.0 => float VOCAL_HIGH;

// Get dominant frequency from a track's FFT
fun float getDominantFrequency(int track) {
    track_fft[track].upchuck() @=> UAnaBlob @ blob;
    blob.fvals() @=> float fvals[];
    
    0.0 => float max_magnitude;
    0 => int max_bin;
    
    // Skip first few bins (DC and very low frequencies)
    for(3 => int i; i < fvals.size(); i++) {
        if(fvals[i] > max_magnitude) {
            fvals[i] => max_magnitude;
            i => max_bin;
        }
    }
    
    // Convert bin number to frequency
    max_bin * (second / samp => float sr) / track_fft[track].size() => float freq;
    
    return freq;
}

// Map frequency to color (cool to warm)
fun vec3 frequencyToColor(float freq) {
    // Clamp frequency to vocal range
    Math.max(VOCAL_LOW, Math.min(VOCAL_HIGH, freq)) => freq;
    
    if(freq < VOCAL_MID) {
        // LOW TO MID: Blue → Cyan → Green
        (freq - VOCAL_LOW) / (VOCAL_MID - VOCAL_LOW) => float t;
        
        // Interpolate from Blue (0,0.3,1) to Green (0.2,0.9,0.4)
        0.0 + (t * 0.2) => float r;
        0.3 + (t * 0.6) => float g;
        1.0 - (t * 0.6) => float b;
        
        return @(r, g, b);
    }
    else {
        // MID TO HIGH: Green → Yellow → Orange → Red
        (freq - VOCAL_MID) / (VOCAL_HIGH - VOCAL_MID) => float t;
        
        // Interpolate from Green (0.2,0.9,0.4) to Red (1,0.2,0.1)
        0.2 + (t * 0.8) => float r;
        0.9 - (t * 0.7) => float g;
        0.4 - (t * 0.3) => float b;
        
        return @(r, g, b);
    }
}

// Add subtle gold tint for master track
fun vec3 addMasterHighlight(vec3 color, float intensity) {
    color.x + (intensity * 0.3) => float r;
    color.y + (intensity * 0.2) => float g;
    color.z => float b;
    
    return @(r, g, b);
}

// === VISUALIZATION SHRED ===
fun void visualizationLoop() {
    float rotation_speed[NUM_TRACKS];
    float smoothed_freq[NUM_TRACKS];
    
    // Initialize
    for(0 => int i; i < NUM_TRACKS; i++) {
        0.5 + (i * 0.3) => rotation_speed[i];
        0.0 => smoothed_freq[i];
    }
    
    0.15 => float FREQ_SMOOTHING;  // Smoothing factor for frequency changes
    
    while(true) {
        GG.nextFrame() => now;
        
        // Visualize each track
        for(0 => int i; i < NUM_TRACKS; i++) {
            if(has_loop[i]) {
                // Get track audio level (amplitude)
                track_rms[i].upchuck();
                track_rms[i].fval(0) => float level;
                level * 20.0 => level;  // Scale up
                
                // Calculate scale based on audio amplitude
                0.8 + (level * 2.5) => float scale;
                track_sphere[i].sca(scale);
                
                // Get dominant frequency for color
                getDominantFrequency(i) => float freq;
                
                // Smooth frequency changes
                smoothed_freq[i] + (freq - smoothed_freq[i]) * FREQ_SMOOTHING => smoothed_freq[i];
                
                // Update color based on frequency (cool to warm)
                if(level > 0.01) {  // Only change color when there's sound
                    frequencyToColor(smoothed_freq[i]) => vec3 color;
                    
                    // Add subtle highlight if this is the master track
                    if(i == master_track) {
                        addMasterHighlight(color, 0.15) => color;
                    }
                    
                    track_sphere[i].color(color);
                }
                
                // Gentle rotation for visual interest
                track_sphere[i].rotY(rotation_speed[i] * 0.015);
                track_sphere[i].rotX(rotation_speed[i] * 0.01);
            } else {
                // No loop - keep sphere small and at starting color
                track_sphere[i].sca(0.3);
                
                // Reset to starting colors when no loop
                if(i == 0) track_sphere[i].color(@(0.2, 0.3, 0.9));      // Blue
                else if(i == 1) track_sphere[i].color(@(0.2, 0.7, 0.8)); // Cyan
                else if(i == 2) track_sphere[i].color(@(0.3, 0.8, 0.4)); // Green
                
                // Minimal rotation when idle
                track_sphere[i].rotY(0.005);
            }
        }
    }
}

// === MIDI SETUP ===
MidiIn min;
MidiMsg msg;

<<< "=====================================================" >>>;
<<< "  ChucK Multi-Track Looper - MASTER LOOP SYNC" >>>;
<<< "=====================================================" >>>;
<<< "Scanning for MIDI devices..." >>>;
<<< "Number of MIDI devices:", min.num() >>>;

if(min.num() == 0) {
    <<< "ERROR: No MIDI devices found!" >>>;
    <<< "Please connect your QUNEO." >>>;
    me.exit();
}

if(!min.open(MIDI_DEVICE)) {
    <<< "ERROR: Failed to open MIDI device", MIDI_DEVICE >>>;
    <<< "Available devices: 0 to", min.num() - 1 >>>;
    me.exit();
}

<<< "" >>>;
<<< "Opened MIDI device:", min.name() >>>;
<<< "Number of tracks:", NUM_TRACKS >>>;
<<< "Max loop duration:", max_duration / second, "seconds" >>>;
<<< "" >>>;
<<< "MIDI Note Mapping (QUNEO Pads):" >>>;
<<< "  RECORD TRACKS (Press & Hold):" >>>;
<<< "    Bottom row: C1 (36) | C#1 (37) | D1 (38)" >>>;
<<< "             Track 0   | Track 1   | Track 2" >>>;
<<< "" >>>;
<<< "  CLEAR TRACKS (Single Press):" >>>;
<<< "    3rd row:    E1 (40) | F1 (41)  | F#1 (42)" >>>;
<<< "             Track 0   | Track 1   | Track 2" >>>;
<<< "" >>>;
<<< "MIDI CC Mapping (QUNEO Bottom Sliders):" >>>;
<<< "  Volume Tracks 0-2: CC", CC_VOLUME_TRACK_0, CC_VOLUME_TRACK_1, CC_VOLUME_TRACK_2 >>>;
<<< "" >>>;
<<< "Visual Mapping:" >>>;
<<< "  Track Spheres (Left to Right):" >>>;
<<< "    Track 0 | Track 1 | Track 2" >>>;
<<< "    SIZE:  Reacts to amplitude (volume)" >>>;
<<< "    COLOR: Reacts to dominant frequency" >>>;
<<< "      Blue (cool) → Low frequencies" >>>;
<<< "      Green/Yellow → Mid frequencies" >>>;
<<< "      Red (warm) → High frequencies" >>>;
<<< "    Master track has subtle gold highlight" >>>;
<<< "" >>>;
<<< "╔═══════════════════════════════════════════════════╗" >>>;
<<< "║           MASTER LOOP SYNC SYSTEM              ║" >>>;
<<< "╚═══════════════════════════════════════════════════╝" >>>;
<<< "" >>>;
<<< "How it works:" >>>;
<<< "  1. First recorded loop becomes MASTER" >>>;
<<< "  2. Subsequent loops auto-adjust to sync" >>>;
<<< "  3. Valid multipliers:" >>>;
<<< "     0.25×, 0.5×, 0.75×, 1×, 1.5×, 2×, 3×, 4×, 6×, 8×" >>>;
<<< "  4. System picks closest match to your recording" >>>;
<<< "  5. Clear all tracks to reset and start fresh" >>>;
<<< "" >>>;
<<< "Result: NO DRIFT! Loops stay perfectly synced!" >>>;
<<< "=====================================================" >>>;

// === MIDI LISTENER ===
int ignore_cc[128];
for(0 => int i; i < 32; i++) {
    1 => ignore_cc[i];
}
0 => ignore_cc[CC_VOLUME_TRACK_0];
0 => ignore_cc[CC_VOLUME_TRACK_1];
0 => ignore_cc[CC_VOLUME_TRACK_2];

fun void midiListener() {
    while(true) {
        min => now;
        
        while(min.recv(msg)) {
            msg.data1 => int status;
            msg.data2 => int data1;
            msg.data3 => int data2;
            
            status & 0xF0 => int messageType;
            
            // === CONTROL CHANGE MESSAGES ===
            if(messageType == 0xB0) {
                if(ignore_cc[data1]) {
                    continue;
                }
                
                if(data1 == CC_VOLUME_TRACK_0) {
                    setTrackVolume(0, data2 / 127.0);
                }
                else if(data1 == CC_VOLUME_TRACK_1) {
                    setTrackVolume(1, data2 / 127.0);
                }
                else if(data1 == CC_VOLUME_TRACK_2) {
                    setTrackVolume(2, data2 / 127.0);
                }
                else {
                    <<< "Unmapped CC:", data1, "Value:", data2 >>>;
                }
            }
            
            // === NOTE ON MESSAGES ===
            else if(messageType == 0x90 && data2 > 0) {
                <<< "Note ON:", data1, "Velocity:", data2 >>>;
                
                if(data1 == NOTE_RECORD_TRACK_0) {
                    startRecording(0);
                }
                else if(data1 == NOTE_RECORD_TRACK_1) {
                    startRecording(1);
                }
                else if(data1 == NOTE_RECORD_TRACK_2) {
                    startRecording(2);
                }
                else if(data1 == NOTE_CLEAR_TRACK_0) {
                    clearTrack(0);
                }
                else if(data1 == NOTE_CLEAR_TRACK_1) {
                    clearTrack(1);
                }
                else if(data1 == NOTE_CLEAR_TRACK_2) {
                    clearTrack(2);
                }
                else {
                    <<< "Unmapped Note:", data1 >>>;
                }
            }
            
            // === NOTE OFF MESSAGES ===
            else if(messageType == 0x80 || (messageType == 0x90 && data2 == 0)) {
                <<< "Note OFF:", data1 >>>;
                
                if(data1 == NOTE_RECORD_TRACK_0) {
                    stopRecording(0);
                }
                else if(data1 == NOTE_RECORD_TRACK_1) {
                    stopRecording(1);
                }
                else if(data1 == NOTE_RECORD_TRACK_2) {
                    stopRecording(2);
                }
            }
        }
    }
}

// === MAIN PROGRAM ===
spork ~ midiListener();
spork ~ visualizationLoop();

while(true) {
    1::second => now;
}

