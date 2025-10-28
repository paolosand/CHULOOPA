//---------------------------------------------------------------------
// name: looper_midi_quneo_vocoder.ck
// desc: MIDI-controlled vocoder looper for QUNEO
//       Voice/audio → pitch detection → synthesize → record → loop
//       Press & hold to record vocoded audio
//       3 independent tracks with free-form looping
//
// Recording Behavior:
//   PRESS AND HOLD pad → detects pitch and synthesizes sine wave
//   RELEASE pad → stops recording, loop starts at exact length
//   Speak/sing into mic while holding pad down
//
// MIDI Mapping:
//   NOTES (for pad triggers):
//     C1, C#1, D1 (36-38):  Press & hold to record vocoded tracks 0-2
//     E1, F1, F#1 (40-42):  Press to clear tracks 0-2
//   
//   CCs (for sliders/knobs):
//     CC 45-47:    Volume control for tracks 0-2
//     CC 48:       BPM display (not used for sync)
//
// Usage:
//   chuck looper_midi_quneo_vocoder.ck
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

// === PITCH DETECTION & SYNTHESIS SETUP ===
// Input chain
adc => Gain input_gain => blackhole;
2.0 => input_gain.gain;

// Analysis chains for pitch detection
adc => Flip flip =^ AutoCorr autocorr => blackhole;
adc => Flip flip_rms =^ RMS rms => blackhole;

// Analysis parameters
1024 => int FRAME_SIZE;
FRAME_SIZE => flip.size => flip_rms.size;
Windowing.hann(FRAME_SIZE) => flip.window;
Windowing.hann(FRAME_SIZE) => flip_rms.window;

FRAME_SIZE/4 => int HOP_SIZE;
HOP_SIZE::samp => dur HOP;

// Pitch detection parameters
0.009 => float AMPLITUDE_THRESHOLD;
44100.0 => float SAMPLE_RATE;
1 => autocorr.normalize;

// Synthesis - Sine wave oscillator
SinOsc sine => ADSR sine_env => Gain synth_output;
0.0 => synth_output.gain;  // Start muted

// Configure envelope
sine_env.set(10::ms, 50::ms, 0.7, 100::ms);

// Synthesis control
0 => int synth_active;
0 => int note_playing;
0.0 => float current_synth_freq;
0.0 => float target_synth_freq;
0.0 => float current_synth_volume;
0.0 => float target_synth_volume;
int current_recording_track;

// Volume mapping parameters
0.009 => float MIN_AMPLITUDE;
0.2 => float MAX_AMPLITUDE;
0.1 => float MIN_VOLUME;
0.8 => float MAX_VOLUME;

// Map amplitude to volume
fun float mapAmplitudeToVolume(float amplitude) {
    Math.max(MIN_AMPLITUDE, Math.min(MAX_AMPLITUDE, amplitude)) => float clamped_amp;
    (clamped_amp - MIN_AMPLITUDE) / (MAX_AMPLITUDE - MIN_AMPLITUDE) => float normalized;
    Math.sqrt(normalized) => float curved;
    return MIN_VOLUME + (curved * (MAX_VOLUME - MIN_VOLUME));
}

// === LOOPER SETUP ===
LiSa lisa[NUM_TRACKS];
Gain output_gains[NUM_TRACKS];

10::second => dur max_duration;
for(0 => int i; i < NUM_TRACKS; i++) {
    max_duration => lisa[i].duration;
    1.0 => lisa[i].gain;
    
    // Route synth output to each LiSa
    synth_output => lisa[i];
    
    1.0 => lisa[i].rate;
    1 => lisa[i].loop;
    0 => lisa[i].bi;

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

// === BPM VARIABLES (for display/future use) ===
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

// === PITCH DETECTION LOOP ===
fun void pitchDetectionLoop() {
    // Initial buffer fill
    FRAME_SIZE::samp => now;
    
    while(true) {
        // Get amplitude
        rms.upchuck();
        rms.fval(0) => float amplitude;
        
        // Only process if synth is active (during recording)
        if(synth_active) {
            // Check if amplitude is above threshold
            if(amplitude > AMPLITUDE_THRESHOLD) {
                // Perform autocorrelation
                autocorr.upchuck();
                autocorr.fvals() @=> float correlation[];
                
                // Find peak in correlation
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
                
                // Convert to frequency if good pitch detected
                if(max_corr > 0.3 && best_lag > 0) {
                    SAMPLE_RATE / best_lag => float detected_freq;
                    detected_freq => target_synth_freq;
                    mapAmplitudeToVolume(amplitude) => target_synth_volume;
                    
                    // Start note if not already playing
                    if(!note_playing) {
                        target_synth_freq => sine.freq;
                        target_synth_freq => current_synth_freq;
                        0.7 => sine.gain;
                        sine_env.keyOn();
                        1 => note_playing;
                        target_synth_volume => current_synth_volume;
                    }
                    // Update frequency and volume if already playing
                    else {
                        // Smooth frequency transition
                        current_synth_freq + (target_synth_freq - current_synth_freq) * 0.1 => current_synth_freq;
                        current_synth_freq => sine.freq;
                        
                        // Smooth volume transition
                        current_synth_volume + (target_synth_volume - current_synth_volume) * 0.3 => current_synth_volume;
                    }
                }
            }
            else {
                // Amplitude below threshold - stop note
                if(note_playing) {
                    sine_env.keyOff();
                    0 => note_playing;
                }
            }
        }
        else {
            // Not recording - ensure note is off
            if(note_playing) {
                sine_env.keyOff();
                0 => note_playing;
            }
        }
        
        HOP => now;
    }
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

    <<< ">>> TRACK", track, "RECORDING STARTED (vocoder - speak now!) <<<" >>>;

    // Prepare synthesis
    track => current_recording_track;
    1.0 => synth_output.gain;
    0 => note_playing;
    220.0 => current_synth_freq;
    0.0 => current_synth_volume;
    1 => synth_active;  // Enable pitch detection

    // Clear and start recording
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
        // Stop synthesis
        0 => synth_active;
        if(note_playing) {
            sine_env.keyOff();
            0 => note_playing;
        }
        0.0 => synth_output.gain;

        // Stop recording
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
    
    // If currently recording this track, stop synthesis
    if(is_recording[track]) {
        0 => synth_active;
        if(note_playing) {
            sine_env.keyOff();
            0 => note_playing;
        }
        0.0 => synth_output.gain;
    }
    
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
<<< "  ChucK Vocoder Looper - QUNEO MIDI Control" >>>;
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
<<< "Pitch detection threshold:", AMPLITUDE_THRESHOLD >>>;
<<< "Synthesis: Sine wave" >>>;
<<< "" >>>;
<<< "MIDI Note Mapping (QUNEO Pads):" >>>;
<<< "  RECORD VOCODED TRACKS (Press & Hold):" >>>;
<<< "    Bottom row: C1 (36) | C#1 (37) | D1 (38)" >>>;
<<< "             Track 0   | Track 1   | Track 2" >>>;
<<< "    → Press and SPEAK/SING into mic!" >>>;
<<< "" >>>;
<<< "  CLEAR TRACKS (Single Press):" >>>;
<<< "    3rd row:    E1 (40) | F1 (41)  | F#1 (42)" >>>;
<<< "             Track 0   | Track 1   | Track 2" >>>;
<<< "" >>>;
<<< "MIDI CC Mapping (QUNEO Bottom Sliders):" >>>;
<<< "  Volume Tracks 0-2: CC", CC_VOLUME_TRACK_0, CC_VOLUME_TRACK_1, CC_VOLUME_TRACK_2 >>>;
<<< "  BPM Control:       CC", CC_BPM >>>;
<<< "" >>>;
<<< "Recording Mode: Vocoder (Press & Hold + Speak)" >>>;
<<< "  1. Press and HOLD pad" >>>;
<<< "  2. Speak/sing into microphone" >>>;
<<< "  3. Release pad when done" >>>;
<<< "  4. Loop plays back vocoded audio!" >>>;
<<< "=====================================================" >>>;

// === MIDI LISTENER (QUNEO OPTIMIZED) ===
int ignore_cc[128];
for(0 => int i; i < 32; i++) {
    1 => ignore_cc[i];  // Ignore CCs 0-31 (pad data)
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
            }
            
            // === NOTE ON MESSAGES ===
            else if(messageType == 0x90 && data2 > 0) {
                <<< "Note ON:", data1, "- Vocoder ready!" >>>;
                
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
spork ~ pitchDetectionLoop();

while(true) {
    1::second => now;
}

