//---------------------------------------------------------------------
// name: looper_midi_quneo.ck
// desc: Multi-track audio looper optimized for QUNEO controller
//       3 independent audio tracks, each with own recording/playback
//       Handles QUNEO's multi-dimensional pad data intelligently
//
// Recording Behavior:
//   PRESS AND HOLD to record - starts immediately
//   RELEASE to stop - loop is exact length of recording
//   No quantization - free-form looping
//
// MIDI Mapping (customize below):
//   NOTES (for pad triggers):
//     C1, C#1, D1 (36-38):  Press & hold to record tracks 0-2
//     E1, F1, F#1 (40-42):  Press to clear tracks 0-2
//   
//   CCs (for continuous controls - sliders/knobs):
//     CC 45-47:    Volume control for tracks 0-2
//     CC 48:       BPM control (30-300 BPM)
//
// Usage:
//   chuck looper_midi_quneo.ck
//---------------------------------------------------------------------

// === MIDI CONFIGURATION ===
// MIDI Note mappings (for pad button presses)
// Bottom row pads: C1, C#1, D1 = Record tracks 0, 1, 2
// Third row pads:  E1, F1, F#1 = Clear tracks 0, 1, 2
36 => int NOTE_RECORD_TRACK_0;   // C1 (bottom row, left)
37 => int NOTE_RECORD_TRACK_1;   // C#1 (bottom row, 2nd)
38 => int NOTE_RECORD_TRACK_2;   // D1 (bottom row, 3rd)

40 => int NOTE_CLEAR_TRACK_0;    // E1 (third row, left)
41 => int NOTE_CLEAR_TRACK_1;    // F1 (third row, 2nd)
42 => int NOTE_CLEAR_TRACK_2;    // F#1 (third row, 3rd)

// CC mappings for continuous controls (use horizontal sliders on QUNEO)
// Bottom sliders typically use CC 45-48
45 => int CC_VOLUME_TRACK_0;   // Bottom slider 1
46 => int CC_VOLUME_TRACK_1;   // Bottom slider 2
47 => int CC_VOLUME_TRACK_2;   // Bottom slider 3

48 => int CC_BPM;               // Bottom slider 4

0 => int MIDI_DEVICE;  // Which MIDI device to use (0 = first device)

// === CONFIGURATION ===
3 => int NUM_TRACKS;          // Number of independent tracks

// === AUDIO SETUP ===
adc => Gain input_gain => blackhole;
1.0 => input_gain.gain;

// Create array of LiSa loopers (one per track)
LiSa lisa[NUM_TRACKS];
Gain output_gains[NUM_TRACKS];

// Configure each track
10::second => dur max_duration;
for(0 => int i; i < NUM_TRACKS; i++) {
    // Setup LiSa
    max_duration => lisa[i].duration;
    1.0 => lisa[i].gain;
    adc => lisa[i];  // Connect input
    1.0 => lisa[i].rate;
    1 => lisa[i].loop;
    0 => lisa[i].bi;

    // Setup output gain
    lisa[i] => output_gains[i] => dac;
    0.7 => output_gains[i].gain;
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

// === BPM / TEMPO VARIABLES ===
120.0 => float bpm;
4 => int beats_per_measure;
time tempo_start_time;
now => tempo_start_time;

// Calculate beat and measure durations
fun dur beatDuration() {
    return (60.0 / bpm)::second;
}

fun dur measureDuration() {
    return (60.0 / bpm * beats_per_measure)::second;
}

// Set BPM (kept for potential future use with sliders)
fun void setBPM(float new_bpm) {
    Math.max(30.0, Math.min(300.0, new_bpm)) => bpm;
    <<< "BPM set to:", bpm >>>;
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

    // Clear and start recording immediately
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
        recorded_duration[track] / second => loop_length[track];

        <<< ">>> TRACK", track, "RECORDING STOPPED <<<" >>>;
        <<< "Loop length:", loop_length[track], "seconds" >>>;

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

// Removed toggleRecording - now using press/release instead

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

// === MIDI SETUP ===
MidiIn min;
MidiMsg msg;

<<< "=====================================================" >>>;
<<< "    ChucK Multi-Track Looper - QUNEO Optimized" >>>;
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
<<< "Default BPM:", bpm >>>;
<<< "Time signature:", beats_per_measure + "/4" >>>;
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
<<< "  BPM Control:       CC", CC_BPM, "(30-300 BPM)" >>>;
<<< "" >>>;
<<< "Recording Mode: Press & Hold (Free-form)" >>>;
<<< "  - Press pad to START recording immediately" >>>;
<<< "  - Release pad to STOP - loop is exact length" >>>;
<<< "  - No quantization - free-form looping" >>>;
<<< "=====================================================" >>>;

// === MIDI LISTENER (QUNEO OPTIMIZED) ===
// Track which CC numbers are "pad pressure" CCs (ignore these for buttons)
// QUNEO typically uses CC 0-31 for pad pressure/position
int ignore_cc[128];
for(0 => int i; i < 32; i++) {
    1 => ignore_cc[i];  // Ignore CCs 0-31 (typically pad data)
}
0 => ignore_cc[CC_VOLUME_TRACK_0];  // Allow our volume CCs
0 => ignore_cc[CC_VOLUME_TRACK_1];
0 => ignore_cc[CC_VOLUME_TRACK_2];
0 => ignore_cc[CC_BPM];  // Allow BPM CC

fun void midiListener() {
    while(true) {
        min => now;
        
        while(min.recv(msg)) {
            msg.data1 => int status;
            msg.data2 => int data1;
            msg.data3 => int data2;
            
            status & 0xF0 => int messageType;
            
            // === CONTROL CHANGE MESSAGES (for sliders/knobs only) ===
            if(messageType == 0xB0) {
                // Skip if this is a pad pressure CC
                if(ignore_cc[data1]) {
                    continue;  // Skip this message
                }
                
                // Volume controls (continuous 0-127 -> 0.0-1.0)
                if(data1 == CC_VOLUME_TRACK_0) {
                    setTrackVolume(0, data2 / 127.0);
                }
                else if(data1 == CC_VOLUME_TRACK_1) {
                    setTrackVolume(1, data2 / 127.0);
                }
                else if(data1 == CC_VOLUME_TRACK_2) {
                    setTrackVolume(2, data2 / 127.0);
                }
                
                // BPM control
                else if(data1 == CC_BPM) {
                    30.0 + (data2 / 127.0 * 270.0) => float new_bpm;
                    setBPM(new_bpm);
                }
                
                else {
                    <<< "Unmapped CC:", data1, "Value:", data2 >>>;
                }
            }
            
            // === NOTE ON MESSAGES (pad button pressed) ===
            else if(messageType == 0x90 && data2 > 0) {
                <<< "Note ON:", data1, "Velocity:", data2 >>>;
                
                // Start recording (press and hold)
                if(data1 == NOTE_RECORD_TRACK_0) {
                    startRecording(0);
                }
                else if(data1 == NOTE_RECORD_TRACK_1) {
                    startRecording(1);
                }
                else if(data1 == NOTE_RECORD_TRACK_2) {
                    startRecording(2);
                }
                
                // Clear tracks (single press)
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
            
            // === NOTE OFF MESSAGES (pad button released) ===
            else if(messageType == 0x80 || (messageType == 0x90 && data2 == 0)) {
                <<< "Note OFF:", data1 >>>;
                
                // Stop recording when button released
                if(data1 == NOTE_RECORD_TRACK_0) {
                    stopRecording(0);
                }
                else if(data1 == NOTE_RECORD_TRACK_1) {
                    stopRecording(1);
                }
                else if(data1 == NOTE_RECORD_TRACK_2) {
                    stopRecording(2);
                }
                // Ignore note off for clear buttons
            }
        }
    }
}

// === MAIN PROGRAM ===
spork ~ midiListener();

while(true) {
    1::second => now;
}

