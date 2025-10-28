//---------------------------------------------------------------------
// name: looper_midi_quneo_visual.ck
// desc: Multi-track audio looper with ChuGL visualization
//       3 independent audio tracks + 1 input visualization
//       Each track gets a unique shape that pulses with audio
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
// Visual Features:
//   4 shapes that pulse/move with audio:
//     - Sphere (cyan): Input audio level
//     - Cube (red): Track 0
//     - Torus (green): Track 1
//     - Cylinder (yellow): Track 2
//   Shapes only animate when track has recorded audio
//
// Usage:
//   chuck looper_midi_quneo_visual.ck
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
48 => int CC_BPM;

0 => int MIDI_DEVICE;

// === CONFIGURATION ===
3 => int NUM_TRACKS;

// === CHUGL SETUP ===
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ camera;
camera.posZ(8.0);

// Create 4 shapes for visualization
GSphere input_sphere --> scene;
input_sphere.posX(-4.5);
input_sphere.posY(0);
input_sphere.sca(0.8);
input_sphere.color(@(0.2, 0.8, 0.9));  // Cyan for input

GCube track0_cube --> scene;
track0_cube.posX(-1.5);
track0_cube.sca(0.8);
track0_cube.color(@(0.9, 0.2, 0.2));  // Red

GTorus track1_torus --> scene;
track1_torus.posX(1.5);
track1_torus.sca(0.8);
track1_torus.color(@(0.2, 0.9, 0.2));  // Green

GCylinder track2_cylinder --> scene;
track2_cylinder.posX(4.5);
track2_cylinder.sca(0.8);
track2_cylinder.color(@(0.9, 0.9, 0.2));  // Yellow

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
// Input audio analysis
adc => Gain input_analysis_gain => FFT input_fft =^ RMS input_rms => blackhole;
2048 => input_fft.size;
Windowing.hann(2048) => input_fft.window;
1.0 => input_analysis_gain.gain;

// Track audio analysis (RMS for amplitude)
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
    
    // Setup audio analysis for each track
    lisa[i] => track_analysis_gain[i] => track_rms[i] => blackhole;
    1.0 => track_analysis_gain[i].gain;
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

fun dur beatDuration() {
    return (60.0 / bpm)::second;
}

fun dur measureDuration() {
    return (60.0 / bpm * beats_per_measure)::second;
}

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

// === VISUALIZATION SHRED ===
fun void visualizationLoop() {
    float rotation_speed[NUM_TRACKS];
    for(0 => int i; i < NUM_TRACKS; i++) {
        0.5 + (i * 0.3) => rotation_speed[i];
    }
    
    while(true) {
        GG.nextFrame() => now;
        
        // Get input audio level
        input_rms.upchuck();
        input_rms.fval(0) => float input_level;
        input_level * 20.0 => input_level;  // Scale up
        
        // Visualize input (always active)
        1.0 + (input_level * 2.0) => float input_scale;
        input_sphere.sca(input_scale * 0.8);
        input_sphere.rotY(0.02);
        
        // Visualize each track
        for(0 => int i; i < NUM_TRACKS; i++) {
            if(has_loop[i]) {
                // Get track audio level
                track_rms[i].upchuck();
                track_rms[i].fval(0) => float level;
                level * 20.0 => level;  // Scale up
                
                // Calculate scale based on audio
                1.0 + (level * 2.5) => float scale;
                
                // Apply to appropriate shape
                if(i == 0) {  // Cube
                    track0_cube.sca(scale * 0.8);
                    track0_cube.rotY(rotation_speed[i] * 0.02);
                    track0_cube.rotX(rotation_speed[i] * 0.01);
                }
                else if(i == 1) {  // Torus
                    track1_torus.sca(scale * 0.8);
                    track1_torus.rotZ(rotation_speed[i] * 0.02);
                    track1_torus.rotY(rotation_speed[i] * 0.015);
                }
                else if(i == 2) {  // Cylinder
                    track2_cylinder.sca(scale * 0.8);
                    track2_cylinder.rotX(rotation_speed[i] * 0.02);
                    track2_cylinder.rotZ(rotation_speed[i] * 0.01);
                }
            } else {
                // No loop - keep shapes at minimal size and stationary
                if(i == 0) {
                    track0_cube.sca(0.3);
                }
                else if(i == 1) {
                    track1_torus.sca(0.3);
                }
                else if(i == 2) {
                    track2_cylinder.sca(0.3);
                }
            }
        }
    }
}

// === MIDI SETUP ===
MidiIn min;
MidiMsg msg;

<<< "=====================================================" >>>;
<<< "    ChucK Multi-Track Looper with ChuGL Visualization" >>>;
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
<<< "Visual Mapping:" >>>;
<<< "  Cyan Sphere:   Input audio (always active)" >>>;
<<< "  Red Cube:      Track 0 (animates when recorded)" >>>;
<<< "  Green Torus:   Track 1 (animates when recorded)" >>>;
<<< "  Yellow Cylinder: Track 2 (animates when recorded)" >>>;
<<< "=====================================================" >>>;

// === MIDI LISTENER ===
int ignore_cc[128];
for(0 => int i; i < 32; i++) {
    1 => ignore_cc[i];
}
0 => ignore_cc[CC_VOLUME_TRACK_0];
0 => ignore_cc[CC_VOLUME_TRACK_1];
0 => ignore_cc[CC_VOLUME_TRACK_2];
0 => ignore_cc[CC_BPM];

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
                else if(data1 == CC_BPM) {
                    30.0 + (data2 / 127.0 * 270.0) => float new_bpm;
                    setBPM(new_bpm);
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

