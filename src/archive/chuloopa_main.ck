//---------------------------------------------------------------------
// name: chuloopa_main.ck
// desc: CHULOOPA - Integrated AI-powered looper with symbolic transcription
//       Combines multi-track audio looping, real-time pitch detection,
//       symbolic MIDI storage, and MIDI playback synthesis
//
// Architecture:
//   1. Record audio loops (with master sync to prevent drift)
//   2. Real-time pitch detection → symbolic MIDI representation
//   3. AUTO-EXPORT: Symbolic data saved to track_N_midi.txt files
//   4. MIDI PLAYBACK: Transcribed notes played as sine wave (not audio loop)
//   5. Visual feedback (ChuGL) reacts to MIDI synthesis output
//   6. [AI PIPELINE] Use track_N_midi.txt with ai_pipeline_placeholder.ck
//
// NEW BEHAVIOR:
//   - After recording, MIDI data is AUTOMATICALLY exported
//   - DUAL PLAYBACK: Original audio (40%) + MIDI transcription (60%)
//   - Both play simultaneously for sync verification
//   - If no notes detected, only original audio plays
//   - Visualization shows MIDI synth output (pure sine wave harmonics)
//
// MIDI Mapping (QuNeo):
//   RECORDING:
//     C1, C#1, D1 (36-38):    Press & hold to record tracks 0-2
//                             Release to stop recording
//
//   CLEARING:
//     E1, F1, F#1 (40-42):    Press to clear tracks 0-2
//
//   MANUAL EXPORT (optional):
//     G1 (43):                Export all track MIDI data (already auto-exported)
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

39 => int NOTE_CLEAR_TRACK_0;    // E1 (fallback clear button)
40 => int NOTE_CLEAR_TRACK_1;    // F1 (fallback clear button)
41 => int NOTE_CLEAR_TRACK_2;    // F#1 (fallback clear button)

42 => int NOTE_EXPORT_MIDI;      // G1

45 => int CC_VOLUME_TRACK_0;
46 => int CC_VOLUME_TRACK_1;
47 => int CC_VOLUME_TRACK_2;

// FX amount (wet/dry) control per track
48 => int CC_FX_TRACK_0;
49 => int CC_FX_TRACK_1;
50 => int CC_FX_TRACK_2;

// Audio/MIDI mix ratio per track
51 => int CC_MIX_TRACK_0;
52 => int CC_MIX_TRACK_1;
53 => int CC_MIX_TRACK_2;

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

// Analysis latency compensation
// The center of the analysis window is FRAME_SIZE/2 samples in the past
(FRAME_SIZE/2.0 / SAMPLE_RATE)::second => dur ANALYSIS_LATENCY;

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

// === PITCH DETECTION SETUP (SHARED - single chain for all tracks) ===
// This is more reliable than having multiple chains connected to adc
Flip pitch_flip;
AutoCorr pitch_autocorr;
Flip pitch_flip_rms;
RMS pitch_rms;

// === MIDI SYNTHESIS SETUP (per track) ===
// For playing back transcribed MIDI instead of audio loops
SinOsc track_synth[NUM_TRACKS];
ADSR track_env[NUM_TRACKS];
Gain track_synth_gain[NUM_TRACKS];

// Per-track FX send/return architecture
Gain track_dry_gain[NUM_TRACKS];     // Dry signal (no effects)
Gain track_fx_send[NUM_TRACKS];      // Send to effects (wet signal)

// === SHARED EFFECTS FOR MIDI SYNTHESIS ===
Chorus shared_chorus => JCRev shared_reverb => Gain fx_return => dac;

// Configure chorus (now at 100% wet since we control dry/wet with sends)
1.0 => shared_chorus.mix;         // 100% wet
0.2 => shared_chorus.modDepth;    // Modulation depth
0.5 => shared_chorus.modFreq;     // Modulation frequency (Hz)

// Configure reverb (100% wet)
1.0 => shared_reverb.mix;         // 100% wet
0.5 => fx_return.gain;            // Return level

// Configure each track
for(0 => int i; i < NUM_TRACKS; i++) {
    // Setup LiSa
    MAX_LOOP_DURATION => lisa[i].duration;
    1.0 => lisa[i].gain;
    adc => lisa[i];
    1.0 => lisa[i].rate;
    1 => lisa[i].loop;
    0 => lisa[i].bi;

    // Setup output gain for audio loops
    lisa[i] => output_gains[i] => dac;
    0.7 => output_gains[i].gain;

    // Setup MIDI synthesis chain with send/return FX architecture
    track_synth[i] => track_env[i] => track_synth_gain[i];
    0.2 => track_synth_gain[i].gain;

    // Split to dry (direct) and wet (through effects) paths
    track_synth_gain[i] => track_dry_gain[i] => dac;
    track_synth_gain[i] => track_fx_send[i] => shared_chorus;

    // Initial FX amount: 30% wet, 70% dry
    0.7 => track_dry_gain[i].gain;
    0.3 => track_fx_send[i].gain;

    // Configure ADSR envelope (same as variation_playback.ck)
    track_env[i].set(20::ms, 50::ms, 0.8, 150::ms);

    // Setup visualization analysis (FFT + RMS) - taps before effects for clean analysis
    track_synth_gain[i] => track_analysis_gain[i] => track_fft[i] =^ track_rms[i] => blackhole;
    3.0 => track_analysis_gain[i].gain;
    2048 => track_fft[i].size;
    Windowing.hann(2048) => track_fft[i].window;
}

// Setup SHARED pitch detection chain (used by whichever track is recording)
adc => pitch_flip =^ pitch_autocorr => blackhole;
adc => pitch_flip_rms =^ pitch_rms => blackhole;

FRAME_SIZE => pitch_flip.size => pitch_flip_rms.size;
Windowing.hann(FRAME_SIZE) => pitch_flip.window;
Windowing.hann(FRAME_SIZE) => pitch_flip_rms.window;
1 => pitch_autocorr.normalize;

// === STATE VARIABLES (per track) ===
int is_recording[NUM_TRACKS];
int is_playing[NUM_TRACKS];
int waiting_to_record[NUM_TRACKS];
float loop_length[NUM_TRACKS];
dur recorded_duration[NUM_TRACKS];
int has_loop[NUM_TRACKS];
time record_start_time[NUM_TRACKS];

// MIDI playback state
time loop_start_time[NUM_TRACKS];
int midi_playback_active[NUM_TRACKS];

// FX and mix control state
float track_fx_amount[NUM_TRACKS];      // 0.0 = dry, 1.0 = wet
float track_audio_midi_mix[NUM_TRACKS]; // 0.0 = all audio, 1.0 = all MIDI

// Initialize track states
for(0 => int i; i < NUM_TRACKS; i++) {
    0 => is_recording[i];
    0 => is_playing[i];
    0 => waiting_to_record[i];
    0.0 => loop_length[i];
    0::second => recorded_duration[i];
    0 => has_loop[i];

    // Initialize MIDI playback state
    0 => midi_playback_active[i];

    // Initialize FX and mix controls
    0.3 => track_fx_amount[i];          // 30% wet by default
    0.6 => track_audio_midi_mix[i];     // 60% MIDI by default (40% audio)
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
                "Duration:", duration, "sec", "Velocity:", current_velocity[track],
                "| Total notes:", track_midi_notes[track].size() >>>;
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
    <<< "" >>>;
    <<< "=== DEBUG: exportSymbolicData() called for Track", track, "===" >>>;
    <<< "  Array size:", track_midi_notes[track].size() >>>;

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
    <<< "=== Exporting notes to", filename, "===" >>>;
    for(0 => int i; i < track_midi_notes[track].size(); i++) {
        track_midi_notes[track][i] $ int => int midi_note;
        Std.mtof(midi_note) => float frequency;
        track_note_velocities[track][i] => float velocity;
        track_note_starts[track][i] => float start_time;
        track_note_durations[track][i] => float duration;

        fout.write(midi_note + "," + frequency + "," + velocity + "," + start_time + "," + duration + "\n");

        // Log first few notes
        if(i < 5) {
            <<< "  Exporting note", i, "- MIDI:", midi_note, "Freq:", frequency,
                "Vel:", velocity, "Start:", start_time, "Dur:", duration >>>;
        }
    }

    fout.close();

    <<< ">>> Track", track, "exported to", filename, "(" + track_midi_notes[track].size(), "notes) <<<" >>>;
    <<< "" >>>;
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

// === MIDI PLAYBACK FUNCTIONS ===

// Play a single MIDI note with given velocity and duration (blocking version for internal use)
fun void playMidiNote(int track, float midi_note, float velocity, float duration) {
    // Convert MIDI to frequency
    Std.mtof(midi_note $ int) => float freq;
    freq => track_synth[track].freq;

    // Map velocity (0-127) to gain (0.1-1.0)
    // Same mapping as variation_playback.ck
    ((velocity - 27.0) / 100.0) * 0.8 => float gain;
    Math.max(0.1, Math.min(1.0, gain)) => track_synth_gain[track].gain;

    // Trigger envelope
    track_env[track].keyOn();

    // Hold for duration (accounting for release time)
    Math.max(0.05, duration - 0.15) => float hold_time;
    hold_time::second => now;

    // Release
    track_env[track].keyOff();
    0.01::second => now;
}

// Scheduled note playback - waits until scheduled time, then plays
// This runs in its own sporked shred for non-blocking, precise timing
fun void playScheduledNote(int track, float midi_note, float velocity, float duration,
                          time scheduled_time, int note_index, int loop_num) {
    // Wait until it's time to play this note
    scheduled_time - now => dur wait_time;

    if(wait_time > 0::second) {
        wait_time => now;
    }

    // Check if playback is still active (might have been stopped while waiting)
    if(!midi_playback_active[track] || !has_loop[track]) {
        return;
    }

    // Log first loop only to avoid spam
    if(loop_num == 1 && note_index < 3) {
        <<< "  [Scheduled] Playing note", note_index, "at T=",
            (now - scheduled_time + duration::second) / second,
            "- MIDI:", midi_note >>>;
    }

    // Play the note (blocking is OK here since we're in our own shred)
    playMidiNote(track, midi_note, velocity, duration);
}

// Main MIDI playback loop for a track
fun void midiPlaybackLoop(int track) {
    <<< "" >>>;
    <<< "=== DEBUG: midiPlaybackLoop() STARTED for Track", track, "===" >>>;
    <<< "  Array size at entry:", track_midi_notes[track].size() >>>;
    <<< "" >>>;

    if(track_midi_notes[track].size() == 0) {
        <<< "Track", track, "- No MIDI notes to play (will be silent)" >>>;
        return;
    }

    // Use ACTUAL recorded loop duration (NOT calculated from MIDI notes)
    // This ensures MIDI playback matches the audio loop exactly
    loop_length[track] => float total_duration;

    <<< "Track", track, "- MIDI playback started" >>>;
    <<< "  Loop duration:", total_duration, "sec (matches audio)" >>>;
    <<< "  MIDI notes:", track_midi_notes[track].size() >>>;
    <<< "" >>>;

    // Log first few notes for verification
    <<< "=== First 5 notes in array ===" >>>;
    for(0 => int i; i < Math.min(5, track_midi_notes[track].size()) $ int; i++) {
        <<< "  Note", i, "- MIDI:", track_midi_notes[track][i],
            "Start:", track_note_starts[track][i], "s",
            "Duration:", track_note_durations[track][i], "s",
            "Velocity:", track_note_velocities[track][i] >>>;
    }
    <<< "" >>>;

    // Continuous loop playback using NON-BLOCKING scheduled notes
    0 => int loop_count;
    while(midi_playback_active[track] && has_loop[track]) {
        loop_count++;
        <<< "=== Starting loop iteration", loop_count, "===" >>>;

        // Anchor for this loop iteration
        now => loop_start_time[track];

        // Schedule ALL notes for this loop iteration
        // Each note plays in its own sporked shred for precise, non-blocking timing
        for(0 => int i; i < track_midi_notes[track].size(); i++) {
            // Check if still active
            if(!midi_playback_active[track] || !has_loop[track]) break;

            // Calculate when this note should play
            loop_start_time[track] + track_note_starts[track][i]::second => time note_time;

            // Spork the note to play at its scheduled time
            spork ~ playScheduledNote(track,
                                     track_midi_notes[track][i],
                                     track_note_velocities[track][i],
                                     track_note_durations[track][i],
                                     note_time,
                                     i,  // note index for logging
                                     loop_count);  // loop number for logging
        }

        // Wait for the entire loop duration before starting next iteration
        loop_start_time[track] + total_duration::second => time loop_end;
        loop_end - now => dur remaining;

        if(remaining > 0::second) {
            remaining => now;
        } else {
            // If we're already past the loop end, log a warning
            if(loop_count <= 2) {
                <<< "  WARNING: Loop", loop_count, "overran by",
                    (remaining / second) * -1, "seconds" >>>;
            }
        }
    }

    <<< "Track", track, "- MIDI playback stopped" >>>;
}

// === MAIN PITCH DETECTION LOOP (runs in main thread, not sporked) ===
// This continuously checks which track is recording and performs analysis
fun void mainPitchDetectionLoop() {
    // Let initial buffer fill
    FRAME_SIZE::samp => now;

    <<< "Main pitch detection loop started" >>>;

    while(true) {
        // Find which track (if any) is currently recording
        -1 => int active_track;
        for(0 => int i; i < NUM_TRACKS; i++) {
            if(is_recording[i]) {
                i => active_track;
                break;
            }
        }

        // If a track is recording, perform pitch detection
        if(active_track >= 0) {
            // Get amplitude using SHARED analysis chain
            pitch_rms.upchuck();
            pitch_rms.fval(0) => float amplitude;

            if(amplitude > AMPLITUDE_THRESHOLD) {
                // Perform autocorrelation analysis using SHARED chain
                pitch_autocorr.upchuck();
                pitch_autocorr.fvals() @=> float correlation[];

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

                    // Check if this is a new note for the active track
                    if(!note_playing[active_track] || Math.fabs(rounded_midi - current_midi_note[active_track]) >= 1.0) {
                        // Save previous note
                        saveCurrentNote(active_track);

                        // Start new note with latency compensation
                        // Subtract ANALYSIS_LATENCY because the detected audio is from the past
                        rounded_midi => current_midi_note[active_track];
                        now - ANALYSIS_LATENCY => current_note_start[active_track];
                        mapAmplitudeToVelocity(amplitude) => current_velocity[active_track];
                        1 => note_playing[active_track];

                        <<< "Track", active_track, "- Note detected: MIDI", rounded_midi, "Freq:", detected_freq, "Hz" >>>;
                    }
                }
            } else {
                // No signal - end current note if playing
                if(note_playing[active_track]) {
                    saveCurrentNote(active_track);
                    0 => note_playing[active_track];
                }
            }
        }

        // Advance time by hop size
        HOP => now;
    }
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

    // Pitch detection happens automatically in mainPitchDetectionLoop()
    <<< "Recording... pitch detection active" >>>;

    // Start recording monitor
    spork ~ recordingMonitor(track);
}

fun void stopRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;
    if(!is_recording[track]) return;

    0 => lisa[track].record;
    0 => is_recording[track];

    // Save any final note that was being played
    saveCurrentNote(track);
    0 => note_playing[track];

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

        // Store original duration before adjustment
        recorded_duration[track] / second => float original_duration;

        adjusted => recorded_duration[track];
        adjusted / second => float adjusted_duration;

        // Scale MIDI timings if duration was adjusted
        if(adjustment > 0.001 && track_midi_notes[track].size() > 0) {
            adjusted_duration / original_duration => float scale_ratio;

            <<< "Scaling", track_midi_notes[track].size(), "MIDI notes by ratio:", scale_ratio >>>;

            // Scale all note start times and durations
            for(0 => int i; i < track_note_starts[track].size(); i++) {
                track_note_starts[track][i] * scale_ratio => track_note_starts[track][i];
                track_note_durations[track][i] * scale_ratio => track_note_durations[track][i];
            }
        }

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

    <<< "" >>>;
    <<< "=== DEBUG: Post-recording state for Track", track, "===" >>>;
    <<< "  Array size:", track_midi_notes[track].size(), "notes" >>>;
    <<< "  Loop length:", loop_length[track], "seconds" >>>;
    <<< "" >>>;

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

        // === AUTO-EXPORT SYMBOLIC DATA ===
        <<< "=== DEBUG: Before export check ===" >>>;
        <<< "  Array size:", track_midi_notes[track].size() >>>;
        if(track_midi_notes[track].size() > 0) {
            <<< "  Exporting symbolic data..." >>>;
            exportSymbolicData(track);
        } else {
            <<< "  WARNING: No notes to export!" >>>;
        }

        // === ENABLE DUAL PLAYBACK ===
        // Start MIDI playback alongside recorded audio
        <<< "=== DEBUG: Before playback spork ===" >>>;
        <<< "  Array size:", track_midi_notes[track].size() >>>;
        if(track_midi_notes[track].size() > 0) {
            <<< "  Sporking MIDI playback..." >>>;
            1 => midi_playback_active[track];

            // Initialize mix ratios using the current knob settings
            setTrackAudioMIDIMix(track, track_audio_midi_mix[track]);

            spork ~ midiPlaybackLoop(track);
            <<< ">>> DUAL PLAYBACK ENABLED <<<" >>>;
            <<< ">>> Use Mix knob (CC", 51 + track, ") to balance Audio/MIDI <<<" >>>;
        } else {
            0.7 => output_gains[track].gain;  // Original audio at 70%
            <<< ">>> No notes captured - playing recorded audio only <<<" >>>;
        }
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

    // Stop MIDI playback
    0 => midi_playback_active[track];

    // Re-enable LiSa audio gain (in case it was muted for MIDI playback)
    0.7 => output_gains[track].gain;

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
    // Volume controls the overall output gain for the audio loop
    Math.max(0.0, Math.min(1.0, vol)) => float master_vol;
    // Apply the audio/MIDI mix ratio
    master_vol * (1.0 - track_audio_midi_mix[track]) => output_gains[track].gain;
}

// Set FX amount (wet/dry) for a track
fun void setTrackFXAmount(int track, float amount) {
    if(track < 0 || track >= NUM_TRACKS) return;
    Math.max(0.0, Math.min(1.0, amount)) => track_fx_amount[track];

    // Update dry/wet sends using equal power crossfade
    Math.sqrt(1.0 - track_fx_amount[track]) => track_dry_gain[track].gain;
    Math.sqrt(track_fx_amount[track]) => track_fx_send[track].gain;

    <<< "Track", track, "FX:", (track_fx_amount[track] * 100) $ int, "% wet" >>>;
}

// Set audio/MIDI mix ratio for a track
fun void setTrackAudioMIDIMix(int track, float mix) {
    if(track < 0 || track >= NUM_TRACKS) return;
    Math.max(0.0, Math.min(1.0, mix)) => track_audio_midi_mix[track];

    if(has_loop[track] && midi_playback_active[track]) {
        // Update the balance between audio loop and MIDI synthesis
        // mix = 0.0: 100% audio, 0% MIDI
        // mix = 0.5: 50% audio, 50% MIDI
        // mix = 1.0: 0% audio, 100% MIDI

        // Audio loop gain (inverse of mix)
        (1.0 - track_audio_midi_mix[track]) * 0.7 => output_gains[track].gain;

        // MIDI synth gain (proportional to mix)
        track_audio_midi_mix[track] * 0.2 => track_synth_gain[track].gain;

        <<< "Track", track, "Mix: Audio",
            ((1.0 - track_audio_midi_mix[track]) * 100) $ int, "%",
            "/ MIDI", (track_audio_midi_mix[track] * 100) $ int, "%" >>>;
    }
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

// === BUTTON HANDLERS ===

// Handle button press (note on) - starts recording immediately
fun void handleButtonPress(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;
    startRecording(track);
}

// Handle button release (note off) - stops recording
fun void handleButtonRelease(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;

    if(is_recording[track]) {
        stopRecording(track);
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
<<< "    - Press & hold to record" >>>;
<<< "    - Release to stop recording" >>>;
<<< "  CLEAR: E1 (40), F1 (41), F#1 (42)" >>>;
<<< "  EXPORT: G1 (43)" >>>;
<<< "" >>>;
<<< "  KNOBS (per track):" >>>;
<<< "    CC 45-47: Track volume" >>>;
<<< "    CC 48-50: FX amount (dry/wet)" >>>;
<<< "    CC 51-53: Audio/MIDI mix ratio" >>>;
<<< "" >>>;
<<< "=====================================================" >>>;
<<< "" >>>;

// MIDI control
int ignore_cc[128];
for(0 => int i; i < 32; i++) 1 => ignore_cc[i];

// Allow volume CCs
0 => ignore_cc[CC_VOLUME_TRACK_0];
0 => ignore_cc[CC_VOLUME_TRACK_1];
0 => ignore_cc[CC_VOLUME_TRACK_2];

// Allow FX amount CCs
0 => ignore_cc[CC_FX_TRACK_0];
0 => ignore_cc[CC_FX_TRACK_1];
0 => ignore_cc[CC_FX_TRACK_2];

// Allow Audio/MIDI mix CCs
0 => ignore_cc[CC_MIX_TRACK_0];
0 => ignore_cc[CC_MIX_TRACK_1];
0 => ignore_cc[CC_MIX_TRACK_2];

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
                    // Volume controls
                    if(data1 == CC_VOLUME_TRACK_0) setTrackVolume(0, data2 / 127.0);
                    else if(data1 == CC_VOLUME_TRACK_1) setTrackVolume(1, data2 / 127.0);
                    else if(data1 == CC_VOLUME_TRACK_2) setTrackVolume(2, data2 / 127.0);

                    // FX amount controls
                    else if(data1 == CC_FX_TRACK_0) setTrackFXAmount(0, data2 / 127.0);
                    else if(data1 == CC_FX_TRACK_1) setTrackFXAmount(1, data2 / 127.0);
                    else if(data1 == CC_FX_TRACK_2) setTrackFXAmount(2, data2 / 127.0);

                    // Audio/MIDI mix controls
                    else if(data1 == CC_MIX_TRACK_0) setTrackAudioMIDIMix(0, data2 / 127.0);
                    else if(data1 == CC_MIX_TRACK_1) setTrackAudioMIDIMix(1, data2 / 127.0);
                    else if(data1 == CC_MIX_TRACK_2) setTrackAudioMIDIMix(2, data2 / 127.0);
                }
            }

            // Note On
            else if(messageType == 0x90 && data2 > 0) {
                // RECORD buttons with double-tap-to-clear
                if(data1 == NOTE_RECORD_TRACK_0) handleButtonPress(0);
                else if(data1 == NOTE_RECORD_TRACK_1) handleButtonPress(1);
                else if(data1 == NOTE_RECORD_TRACK_2) handleButtonPress(2);
                // Fallback CLEAR buttons (still work)
                else if(data1 == NOTE_CLEAR_TRACK_0) clearTrack(0);
                else if(data1 == NOTE_CLEAR_TRACK_1) clearTrack(1);
                else if(data1 == NOTE_CLEAR_TRACK_2) clearTrack(2);
                // Export
                else if(data1 == NOTE_EXPORT_MIDI) exportAllSymbolicData();
            }

            // Note Off
            else if(messageType == 0x80 || (messageType == 0x90 && data2 == 0)) {
                if(data1 == NOTE_RECORD_TRACK_0) handleButtonRelease(0);
                else if(data1 == NOTE_RECORD_TRACK_1) handleButtonRelease(1);
                else if(data1 == NOTE_RECORD_TRACK_2) handleButtonRelease(2);
            }
        }
    }
}

// === MAIN PROGRAM ===
spork ~ midiListener();
spork ~ visualizationLoop();
spork ~ mainPitchDetectionLoop();

<<< "CHULOOPA running! Ready to loop..." >>>;
<<< "Pitch detection latency compensation:", (ANALYSIS_LATENCY/ms), "ms" >>>;
<<< "" >>>;

while(true) {
    1::second => now;
}
