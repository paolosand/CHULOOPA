//---------------------------------------------------------------------
// name: chuloopa_main.ck
// desc: CHULOOPA - Integrated AI-powered looper with symbolic transcription
//       Combines multi-track audio looping, real-time pitch detection,
//       symbolic MIDI storage, and AI generation pipeline (placeholder)
//
// Architecture:
//   1. Record audio loops (with master sync to prevent drift)
//   2. Real-time pitch detection → symbolic MIDI representation
//   3. Store MIDI data for each track independently
//   4. [AI PLACEHOLDER] Generate variations from symbolic data
//   5. Playback variations through synthesis
//   6. Visual feedback (ChuGL) for audio + symbolic data
//
// MIDI Mapping (QuNeo):
//   RECORDING:
//     C1, C#1, D1 (36-38):    Press & hold to record tracks 0-2
//
//   CLEARING:
//     E1, F1, F#1 (40-42):    Clear tracks 0-2
//
//   EXPORT SYMBOLIC DATA:
//     G1 (43):                Export all track MIDI data to files
//
//   VOLUME:
//     CC 45-47:               Volume control for tracks 0-2
//
// Usage:
//   chuck src/chuloopa_main.ck
//---------------------------------------------------------------------

// === MIDI CONFIGURATION ===
36 => int NOTE_RECORD_TRACK_0;   // C1
37 => int NOTE_RECORD_TRACK_1;   // C#1
38 => int NOTE_RECORD_TRACK_2;   // D1

40 => int NOTE_CLEAR_TRACK_0;    // E1
41 => int NOTE_CLEAR_TRACK_1;    // F1
42 => int NOTE_CLEAR_TRACK_2;    // F#1

43 => int NOTE_EXPORT_MIDI;      // G1

45 => int CC_VOLUME_TRACK_0;
46 => int CC_VOLUME_TRACK_1;
47 => int CC_VOLUME_TRACK_2;

0 => int MIDI_DEVICE;

// === CONFIGURATION ===
3 => int NUM_TRACKS;
10::second => dur MAX_LOOP_DURATION;

// === PITCH DETECTION PARAMETERS ===
1024 => int FRAME_SIZE;
FRAME_SIZE/4 => int HOP_SIZE;
HOP_SIZE::samp => dur HOP;

0.009 => float AMPLITUDE_THRESHOLD;
44100.0 => float SAMPLE_RATE;
50::ms => dur MIN_NOTE_DURATION;

// Volume mapping for pitch detection
0.009 => float MIN_AMPLITUDE;
0.2 => float MAX_AMPLITUDE;

// === MASTER LOOP SYNC SYSTEM ===
-1 => int master_track;
0::second => dur master_duration;
0 => int has_master;

// Valid multipliers for sync (most common musical ratios)
[0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0] @=> float valid_multipliers[];

// Find best multiplier to sync with master loop
fun dur findBestMultiplier(dur recorded_duration, dur master_duration) {
    1000000.0 => float best_error;
    1.0 => float best_multiplier;

    for(0 => int i; i < valid_multipliers.size(); i++) {
        valid_multipliers[i] => float mult;
        master_duration * mult => dur target;
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

// === CHUGL VISUALIZATION SETUP ===
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ camera;
camera.posZ(8.0);

// Create 3 spheres for track visualization
GSphere track_sphere[NUM_TRACKS];
for(0 => int i; i < NUM_TRACKS; i++) {
    track_sphere[i] --> scene;
    track_sphere[i].posX(-3.0 + (i * 3.0));
    track_sphere[i].posY(0);
    track_sphere[i].sca(0.8);

    if(i == 0) track_sphere[i].color(@(0.2, 0.3, 0.9));      // Blue
    else if(i == 1) track_sphere[i].color(@(0.2, 0.7, 0.8)); // Cyan
    else if(i == 2) track_sphere[i].color(@(0.3, 0.8, 0.4)); // Green
}

// Add lighting
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
FFT track_fft[NUM_TRACKS];
RMS track_rms[NUM_TRACKS];
Gain track_analysis_gain[NUM_TRACKS];

// === PITCH DETECTION SETUP (per track) ===
Flip track_flip[NUM_TRACKS];
AutoCorr track_autocorr[NUM_TRACKS];
Flip track_flip_rms[NUM_TRACKS];
RMS track_pitch_rms[NUM_TRACKS];

// Configure each track
for(0 => int i; i < NUM_TRACKS; i++) {
    // Setup LiSa
    MAX_LOOP_DURATION => lisa[i].duration;
    1.0 => lisa[i].gain;
    adc => lisa[i];
    1.0 => lisa[i].rate;
    1 => lisa[i].loop;
    0 => lisa[i].bi;

    // Setup output gain
    lisa[i] => output_gains[i] => dac;
    0.7 => output_gains[i].gain;

    // Setup visualization analysis (FFT + RMS)
    lisa[i] => track_analysis_gain[i] => track_fft[i] =^ track_rms[i] => blackhole;
    3.0 => track_analysis_gain[i].gain;
    2048 => track_fft[i].size;
    Windowing.hann(2048) => track_fft[i].window;

    // Setup pitch detection chain (during recording only)
    adc => track_flip[i] =^ track_autocorr[i] => blackhole;
    adc => track_flip_rms[i] =^ track_pitch_rms[i] => blackhole;

    FRAME_SIZE => track_flip[i].size => track_flip_rms[i].size;
    Windowing.hann(FRAME_SIZE) => track_flip[i].window;
    Windowing.hann(FRAME_SIZE) => track_flip_rms[i].window;
    1 => track_autocorr[i].normalize;
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

// === SYMBOLIC MIDI DATA STORAGE (per track) ===
// Each track stores its own MIDI note sequence
float track_midi_notes[NUM_TRACKS][0];      // MIDI note numbers
float track_note_starts[NUM_TRACKS][0];     // Start times (seconds from loop start)
float track_note_durations[NUM_TRACKS][0];  // Note durations (seconds)
float track_note_velocities[NUM_TRACKS][0]; // MIDI velocities (0-127)

// Current note tracking for pitch detection
float current_midi_note[NUM_TRACKS];
time current_note_start[NUM_TRACKS];
float current_velocity[NUM_TRACKS];
int note_playing[NUM_TRACKS];

// Initialize
for(0 => int i; i < NUM_TRACKS; i++) {
    0.0 => current_midi_note[i];
    0.0 => current_velocity[i];
    0 => note_playing[i];
}

// === SYMBOLIC DATA FUNCTIONS ===

// Map amplitude to MIDI velocity (0-127)
fun int mapAmplitudeToVelocity(float amplitude) {
    Math.max(MIN_AMPLITUDE, Math.min(MAX_AMPLITUDE, amplitude)) => float clamped_amp;
    (clamped_amp - MIN_AMPLITUDE) / (MAX_AMPLITUDE - MIN_AMPLITUDE) => float normalized;
    return (normalized * 100 + 27) $ int;
}

// Save current note to track's symbolic data
fun void saveCurrentNote(int track) {
    if(note_playing[track] && is_recording[track]) {
        now - current_note_start[track] => dur note_length;

        if(note_length >= MIN_NOTE_DURATION) {
            // Calculate note start time relative to loop start
            (current_note_start[track] - record_start_time[track]) / second => float start_time;
            note_length / second => float duration;

            // Store in track's symbolic data
            track_midi_notes[track] << current_midi_note[track];
            track_note_starts[track] << start_time;
            track_note_durations[track] << duration;
            track_note_velocities[track] << current_velocity[track];

            <<< "Track", track, "- Saved note: MIDI", current_midi_note[track],
                "Duration:", duration, "sec", "Velocity:", current_velocity[track] >>>;
        }
    }
}

// Clear symbolic data for a track
fun void clearSymbolicData(int track) {
    // Clear all arrays
    track_midi_notes[track].clear();
    track_note_starts[track].clear();
    track_note_durations[track].clear();
    track_note_velocities[track].clear();

    0 => note_playing[track];

    <<< "Track", track, "symbolic data cleared" >>>;
}

// Export symbolic data to file
fun void exportSymbolicData(int track) {
    if(track_midi_notes[track].size() == 0) {
        <<< "Track", track, "has no symbolic data to export" >>>;
        return;
    }

    "track_" + track + "_midi.txt" => string filename;
    FileIO fout;
    fout.open(filename, FileIO.WRITE);

    if(!fout.good()) {
        <<< "ERROR: Could not open file for writing:", filename >>>;
        return;
    }

    // Write header
    fout.write("# Track " + track + " MIDI Data\n");
    fout.write("# Format: MIDI_NOTE,FREQUENCY,VELOCITY,START_TIME,DURATION\n");

    // Write each note
    for(0 => int i; i < track_midi_notes[track].size(); i++) {
        track_midi_notes[track][i] $ int => int midi_note;
        Std.mtof(midi_note) => float frequency;
        track_note_velocities[track][i] => float velocity;
        track_note_starts[track][i] => float start_time;
        track_note_durations[track][i] => float duration;

        fout.write(midi_note + "," + frequency + "," + velocity + "," + start_time + "," + duration + "\n");
    }

    fout.close();

    <<< ">>> Track", track, "exported to", filename, "(" + track_midi_notes[track].size(), "notes) <<<" >>>;
}

// Export all tracks
fun void exportAllSymbolicData() {
    <<< "" >>>;
    <<< "╔═══════════════════════════════════════╗" >>>;
    <<< "║  EXPORTING ALL SYMBOLIC DATA       ║" >>>;
    <<< "╚═══════════════════════════════════════╝" >>>;
    <<< "" >>>;

    for(0 => int i; i < NUM_TRACKS; i++) {
        if(has_loop[i]) {
            exportSymbolicData(i);
        }
    }

    <<< "" >>>;
    <<< "Export complete!" >>>;
    <<< "" >>>;
}

// === PITCH DETECTION (per track, during recording) ===
fun void pitchDetectionLoop(int track) {
    // Let buffer fill
    FRAME_SIZE::samp => now;

    <<< "Pitch detection started for track", track >>>;

    while(is_recording[track]) {
        // Get amplitude
        track_pitch_rms[track].upchuck();
        track_pitch_rms[track].fval(0) => float amplitude;

        if(amplitude > AMPLITUDE_THRESHOLD) {
            // Perform autocorrelation analysis
            track_autocorr[track].upchuck();
            track_autocorr[track].fvals() @=> float correlation[];

            // Find peak in autocorrelation
            0.0 => float max_corr;
            0 => int best_lag;

            Math.max(20, SAMPLE_RATE/800) $ int => int min_lag;
            Math.min(correlation.size()-1, SAMPLE_RATE/80) $ int => int max_lag;

            for(min_lag => int lag; lag <= max_lag; lag++) {
                if(correlation[lag] > max_corr) {
                    correlation[lag] => max_corr;
                    lag => best_lag;
                }
            }

            // Convert lag to frequency
            if(max_corr > 0.3 && best_lag > 0) {
                SAMPLE_RATE / best_lag => float detected_freq;
                12.0 * Math.log2(detected_freq / 440.0) + 69.0 => float detected_midi;
                Math.round(detected_midi) => float rounded_midi;

                // Check if this is a new note
                if(!note_playing[track] || Math.fabs(rounded_midi - current_midi_note[track]) >= 1.0) {
                    // Save previous note
                    saveCurrentNote(track);

                    // Start new note
                    rounded_midi => current_midi_note[track];
                    now => current_note_start[track];
                    mapAmplitudeToVelocity(amplitude) => current_velocity[track];
                    1 => note_playing[track];
                }
            }
        } else {
            // No signal - end current note
            if(note_playing[track]) {
                saveCurrentNote(track);
                0 => note_playing[track];
            }
        }

        HOP => now;
    }

    // Save final note when recording stops
    saveCurrentNote(track);
    0 => note_playing[track];

    <<< "Pitch detection stopped for track", track >>>;
}

// === TRACK CONTROL FUNCTIONS ===

fun void startRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;
    if(is_recording[track]) return;

    <<< "" >>>;
    <<< ">>> TRACK", track, "RECORDING STARTED <<<" >>>;

    // Clear previous symbolic data
    clearSymbolicData(track);

    // Setup LiSa for recording
    0 => lisa[track].play;
    lisa[track].clear();
    0::second => lisa[track].recPos;
    1 => lisa[track].record;

    1 => is_recording[track];
    now => record_start_time[track];

    // Start pitch detection for this track
    spork ~ pitchDetectionLoop(track);
    spork ~ recordingMonitor(track);
}

fun void stopRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;
    if(!is_recording[track]) return;

    0 => lisa[track].record;
    0 => is_recording[track];

    lisa[track].recPos() => recorded_duration[track];

    // === MASTER LOOP SYNC ===
    if(!has_master) {
        track => master_track;
        recorded_duration[track] => master_duration;
        1 => has_master;

        <<< "" >>>;
        <<< "╔═══════════════════════════════════════╗" >>>;
        <<< "║  MASTER LOOP SET: Track", track, "          ║" >>>;
        <<< "╚═══════════════════════════════════════╝" >>>;
        <<< "Duration:", master_duration / second, "seconds" >>>;
        <<< "" >>>;
    } else {
        findBestMultiplier(recorded_duration[track], master_duration) => dur adjusted;
        (adjusted / master_duration) $ float => float multiplier;
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
        <<< ">>> Captured", track_midi_notes[track].size(), "MIDI notes <<<" >>>;
    } else {
        <<< "Track", track, "recording too short" >>>;
    }
}

fun void clearTrack(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;

    <<< ">>> CLEARING TRACK", track, "<<<" >>>;

    0 => lisa[track].play;
    0 => lisa[track].record;
    lisa[track].clear();
    0 => is_recording[track];
    0 => is_playing[track];
    0 => has_loop[track];

    clearSymbolicData(track);

    // Reset master if needed
    if(track == master_track && !anyLoopsExist()) {
        <<< "" >>>;
        <<< "╔═══════════════════════════════════════╗" >>>;
        <<< "║  MASTER LOOP CLEARED               ║" >>>;
        <<< "╚═══════════════════════════════════════╝" >>>;
        <<< "" >>>;

        -1 => master_track;
        0::second => master_duration;
        0 => has_master;
    }
}

fun void setTrackVolume(int track, float vol) {
    if(track < 0 || track >= NUM_TRACKS) return;
    Math.max(0.0, Math.min(1.0, vol)) => output_gains[track].gain;
}

fun void recordingMonitor(int track) {
    while(is_recording[track]) {
        now - record_start_time[track] => dur elapsed;
        if(elapsed >= MAX_LOOP_DURATION) {
            <<< "Track", track, "max duration reached" >>>;
            stopRecording(track);
            return;
        }
        100::ms => now;
    }
}

// === VISUALIZATION ===
80.0 => float VOCAL_LOW;
500.0 => float VOCAL_MID;
1000.0 => float VOCAL_HIGH;

fun float getDominantFrequency(int track) {
    track_fft[track].upchuck() @=> UAnaBlob @ blob;
    blob.fvals() @=> float fvals[];

    0.0 => float max_magnitude;
    0 => int max_bin;

    for(3 => int i; i < fvals.size(); i++) {
        if(fvals[i] > max_magnitude) {
            fvals[i] => max_magnitude;
            i => max_bin;
        }
    }

    return max_bin * (second / samp => float sr) / track_fft[track].size();
}

fun vec3 frequencyToColor(float freq) {
    Math.max(VOCAL_LOW, Math.min(VOCAL_HIGH, freq)) => freq;

    if(freq < VOCAL_MID) {
        (freq - VOCAL_LOW) / (VOCAL_MID - VOCAL_LOW) => float t;
        return @(0.0 + (t * 0.2), 0.3 + (t * 0.6), 1.0 - (t * 0.6));
    } else {
        (freq - VOCAL_MID) / (VOCAL_HIGH - VOCAL_MID) => float t;
        return @(0.2 + (t * 0.8), 0.9 - (t * 0.7), 0.4 - (t * 0.3));
    }
}

fun vec3 addMasterHighlight(vec3 color, float intensity) {
    return @(color.x + (intensity * 0.3), color.y + (intensity * 0.2), color.z);
}

fun void visualizationLoop() {
    float rotation_speed[NUM_TRACKS];
    float smoothed_freq[NUM_TRACKS];

    for(0 => int i; i < NUM_TRACKS; i++) {
        0.5 + (i * 0.3) => rotation_speed[i];
        0.0 => smoothed_freq[i];
    }

    0.15 => float FREQ_SMOOTHING;

    while(true) {
        GG.nextFrame() => now;

        for(0 => int i; i < NUM_TRACKS; i++) {
            if(has_loop[i]) {
                track_rms[i].upchuck();
                track_rms[i].fval(0) => float level;
                level * 20.0 => level;

                0.8 + (level * 2.5) => float scale;
                track_sphere[i].sca(scale);

                getDominantFrequency(i) => float freq;
                smoothed_freq[i] + (freq - smoothed_freq[i]) * FREQ_SMOOTHING => smoothed_freq[i];

                if(level > 0.01) {
                    frequencyToColor(smoothed_freq[i]) => vec3 color;
                    if(i == master_track) {
                        addMasterHighlight(color, 0.15) => color;
                    }
                    track_sphere[i].color(color);
                }

                track_sphere[i].rotY(rotation_speed[i] * 0.015);
                track_sphere[i].rotX(rotation_speed[i] * 0.01);
            } else {
                track_sphere[i].sca(0.3);
                if(i == 0) track_sphere[i].color(@(0.2, 0.3, 0.9));
                else if(i == 1) track_sphere[i].color(@(0.2, 0.7, 0.8));
                else if(i == 2) track_sphere[i].color(@(0.3, 0.8, 0.4));
                track_sphere[i].rotY(0.005);
            }
        }
    }
}

// === MIDI LISTENER ===
MidiIn min;
MidiMsg msg;

<<< "" >>>;
<<< "=====================================================" >>>;
<<< "           CHULOOPA - AI Looper System" >>>;
<<< "=====================================================" >>>;
<<< "" >>>;

if(min.num() == 0) {
    <<< "WARNING: No MIDI devices found!" >>>;
    <<< "You can still use this by editing the code to map" >>>;
    <<< "computer keyboard or other input methods." >>>;
} else {
    if(min.open(MIDI_DEVICE)) {
        <<< "MIDI Device:", min.name() >>>;
    }
}

<<< "Tracks:", NUM_TRACKS >>>;
<<< "Max loop duration:", MAX_LOOP_DURATION / second, "sec" >>>;
<<< "" >>>;
<<< "MIDI Controls:" >>>;
<<< "  RECORD: C1 (36), C#1 (37), D1 (38)" >>>;
<<< "  CLEAR:  E1 (40), F1 (41), F#1 (42)" >>>;
<<< "  EXPORT: G1 (43)" >>>;
<<< "  VOLUME: CC 45-47" >>>;
<<< "" >>>;
<<< "=====================================================" >>>;
<<< "" >>>;

// MIDI control
int ignore_cc[128];
for(0 => int i; i < 32; i++) 1 => ignore_cc[i];
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

            // Control Change
            if(messageType == 0xB0) {
                if(!ignore_cc[data1]) {
                    if(data1 == CC_VOLUME_TRACK_0) setTrackVolume(0, data2 / 127.0);
                    else if(data1 == CC_VOLUME_TRACK_1) setTrackVolume(1, data2 / 127.0);
                    else if(data1 == CC_VOLUME_TRACK_2) setTrackVolume(2, data2 / 127.0);
                }
            }

            // Note On
            else if(messageType == 0x90 && data2 > 0) {
                if(data1 == NOTE_RECORD_TRACK_0) startRecording(0);
                else if(data1 == NOTE_RECORD_TRACK_1) startRecording(1);
                else if(data1 == NOTE_RECORD_TRACK_2) startRecording(2);
                else if(data1 == NOTE_CLEAR_TRACK_0) clearTrack(0);
                else if(data1 == NOTE_CLEAR_TRACK_1) clearTrack(1);
                else if(data1 == NOTE_CLEAR_TRACK_2) clearTrack(2);
                else if(data1 == NOTE_EXPORT_MIDI) exportAllSymbolicData();
            }

            // Note Off
            else if(messageType == 0x80 || (messageType == 0x90 && data2 == 0)) {
                if(data1 == NOTE_RECORD_TRACK_0) stopRecording(0);
                else if(data1 == NOTE_RECORD_TRACK_1) stopRecording(1);
                else if(data1 == NOTE_RECORD_TRACK_2) stopRecording(2);
            }
        }
    }
}

// === MAIN PROGRAM ===
spork ~ midiListener();
spork ~ visualizationLoop();

<<< "CHULOOPA running! Ready to loop..." >>>;
<<< "" >>>;

while(true) {
    1::second => now;
}
