//---------------------------------------------------------------------
// name: looper_vocoder.ck
// desc: Multi-track vocoder looper with pitch-to-instrument synthesis
//       Voice/audio input → pitch detection → synthesize → record → loop
//       Each track can use a different instrument
//       All tracks sync to shared BPM with automatic quantization
//
//       Integrates VOCpluginDupe functionality:
//       - Real-time pitch detection with autocorrelation
//       - Amplitude-based note triggering (responds to voice dynamics)
//       - Automatic volume mapping from input amplitude
//       - Smooth frequency and volume transitions
//
// OSC Commands:
//   /loop/record <track> 1    - Start recording on track (0-2)
//   /loop/record <track> 0    - Stop recording on track
//   /loop/clear <track>       - Clear track buffer
//   /loop/volume <track> f    - Set track playback volume (0.0-1.0)
//   /loop/instrument <track> n - Set track instrument (1-6)
//   /loop/bpm f               - Set BPM (30-300)
//
// Instruments: 1=Sine, 2=Square, 3=Mandolin, 4=Flute, 5=Brass, 6=HnkyTonk
//
// Usage:
//   chuck looper_vocoder.ck looper_gui_vocoder.ck
//---------------------------------------------------------------------

// === CONFIGURATION ===
3 => int NUM_TRACKS;

// === INSTRUMENT SYNTHESIS SETUP ===
// Create all instruments (shared, only one active when recording)
SinOsc sine => ADSR sine_env => Gain sine_gain => Gain synth_output;
SqrOsc square => ADSR square_env => Gain square_gain => synth_output;
Mandolin mandolin => ADSR mandolin_env => Gain mandolin_gain => synth_output;
Flute flute => ADSR flute_env => Gain flute_gain => synth_output;
Brass brass => ADSR brass_env => Gain brass_gain => synth_output;
HnkyTonk honky => ADSR honky_env => Gain honky_gain => synth_output;

// Initially all instruments off
0.0 => sine_gain.gain => square_gain.gain => mandolin_gain.gain;
0.0 => flute_gain.gain => brass_gain.gain => honky_gain.gain;

// Configure ADSR envelopes
sine_env.set(10::ms, 50::ms, 0.7, 100::ms);
square_env.set(10::ms, 50::ms, 0.7, 100::ms);
mandolin_env.set(5::ms, 200::ms, 0.5, 300::ms);
flute_env.set(50::ms, 100::ms, 0.8, 200::ms);
brass_env.set(20::ms, 150::ms, 0.7, 250::ms);
honky_env.set(10::ms, 100::ms, 0.6, 200::ms);

// Synth output will route to recording or monitoring
0.0 => synth_output.gain;  // Start muted

// === PITCH DETECTION SETUP ===
adc => Gain input_gain => blackhole;
2.0 => input_gain.gain;

// Analysis chains
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

// Synthesis control
0 => int synth_active;
0 => int note_playing;  // Track if note is currently playing
0.0 => float current_synth_freq;
0.0 => float target_synth_freq;
0.0 => float current_synth_volume;
0.0 => float target_synth_volume;
int current_recording_track;  // Which track is currently recording

// Volume mapping parameters
0.009 => float MIN_AMPLITUDE;
0.2 => float MAX_AMPLITUDE;
0.1 => float MIN_VOLUME;
0.8 => float MAX_VOLUME;

// Function to map amplitude to volume
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

    // Route synth output to each LiSa (will only record when active)
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
int track_instrument[NUM_TRACKS];  // Instrument selection per track

// Initialize track states
for(0 => int i; i < NUM_TRACKS; i++) {
    0 => is_recording[i];
    0 => is_playing[i];
    0 => waiting_to_record[i];
    0.0 => loop_length[i];
    0::second => recorded_duration[i];
    0 => has_loop[i];
    1 => track_instrument[i];  // Default to sine wave
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

fun dur timeUntilNextMeasure() {
    now - tempo_start_time => dur elapsed;
    measureDuration() => dur measure_dur;
    elapsed % measure_dur => dur position_in_measure;

    if(position_in_measure == 0::second) {
        return 0::second;
    } else {
        return measure_dur - position_in_measure;
    }
}

fun dur quantizeToMeasure(dur input) {
    measureDuration() => dur measure;
    (input / measure) $ int => int num_measures;

    if((input % measure) > (measure * 0.5)) {
        num_measures++;
    }

    if(num_measures < 1) {
        1 => num_measures;
    }

    return num_measures * measure;
}

fun void setBPM(float new_bpm) {
    Math.max(30.0, Math.min(300.0, new_bpm)) => bpm;
    <<< "BPM set to:", bpm >>>;
}

// === INSTRUMENT CONTROL FUNCTIONS ===
["", "Sine", "Square", "Mandolin", "Flute", "Brass", "HnkyTonk"] @=> string instrument_names[];

fun void selectInstrument(int instrument_num) {
    // Turn off all instruments
    0.0 => sine_gain.gain => square_gain.gain => mandolin_gain.gain;
    0.0 => flute_gain.gain => brass_gain.gain => honky_gain.gain;

    // Turn on selected instrument
    0.3 => float inst_gain;
    if(instrument_num == 1) inst_gain => sine_gain.gain;
    else if(instrument_num == 2) inst_gain => square_gain.gain;
    else if(instrument_num == 3) inst_gain => mandolin_gain.gain;
    else if(instrument_num == 4) inst_gain => flute_gain.gain;
    else if(instrument_num == 5) inst_gain => brass_gain.gain;
    else if(instrument_num == 6) inst_gain => honky_gain.gain;
}

fun void setInstrumentFreq(int instrument_num, float freq) {
    if(instrument_num == 1) freq => sine.freq;
    else if(instrument_num == 2) freq => square.freq;
    else if(instrument_num == 3) freq => mandolin.freq;
    else if(instrument_num == 4) freq => flute.freq;
    else if(instrument_num == 5) freq => brass.freq;
    else if(instrument_num == 6) freq => honky.freq;
}

fun void instrumentNoteOn(int instrument_num) {
    if(instrument_num == 1) { 0.7 => sine.gain; sine_env.keyOn(); }
    else if(instrument_num == 2) { 0.7 => square.gain; square_env.keyOn(); }
    else if(instrument_num == 3) { mandolin.noteOn(0.7); mandolin_env.keyOn(); }
    else if(instrument_num == 4) { flute.noteOn(0.7); flute_env.keyOn(); }
    else if(instrument_num == 5) { brass.noteOn(0.7); brass_env.keyOn(); }
    else if(instrument_num == 6) { honky.noteOn(0.7); honky_env.keyOn(); }
}

fun void instrumentNoteOff(int instrument_num) {
    if(instrument_num == 1) sine_env.keyOff();
    else if(instrument_num == 2) square_env.keyOff();
    else if(instrument_num == 3) { mandolin.noteOff(0.0); mandolin_env.keyOff(); }
    else if(instrument_num == 4) { flute.noteOff(0.0); flute_env.keyOff(); }
    else if(instrument_num == 5) { brass.noteOff(0.0); brass_env.keyOff(); }
    else if(instrument_num == 6) { honky.noteOff(0.0); honky_env.keyOff(); }
}

fun void setTrackInstrument(int track, int instrument_num) {
    if(track < 0 || track >= NUM_TRACKS) return;
    if(instrument_num < 1 || instrument_num > 6) return;

    instrument_num => track_instrument[track];
    <<< "Track", track, "instrument set to:", instrument_names[instrument_num] >>>;
}

// === OSC SETUP ===
OscIn oin;
OscMsg msg;
6450 => int OSC_PORT;
OSC_PORT => oin.port;
oin.listenAll();

<<< "=====================================================" >>>;
<<< "   ChucK Vocoder Multi-Track Looper - OSC Control" >>>;
<<< "=====================================================" >>>;
<<< "OSC Port:", OSC_PORT >>>;
<<< "Tempo Out Port:", 6451 >>>;
<<< "Number of tracks:", NUM_TRACKS >>>;
<<< "Max loop duration:", max_duration / second, "seconds" >>>;
<<< "Default BPM:", bpm >>>;
<<< "Time signature:", beats_per_measure + "/4" >>>;
<<< "Quantization: Nearest measure" >>>;
<<< "Pitch detection threshold:", AMPLITUDE_THRESHOLD >>>;
<<< "Speak or sing into your microphone!" >>>;
<<< "=====================================================" >>>;

// === PITCH DETECTION & SYNTHESIS LOOP ===
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

                // Find peak
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
                        setInstrumentFreq(track_instrument[current_recording_track], target_synth_freq);
                        target_synth_freq => current_synth_freq;
                        instrumentNoteOn(track_instrument[current_recording_track]);
                        1 => note_playing;
                        target_synth_volume => current_synth_volume;
                    }
                    // Update frequency and volume if already playing
                    else {
                        // Smooth frequency transition
                        current_synth_freq + (target_synth_freq - current_synth_freq) * 0.1 => current_synth_freq;
                        setInstrumentFreq(track_instrument[current_recording_track], current_synth_freq);
                        
                        // Smooth volume transition
                        current_synth_volume + (target_synth_volume - current_synth_volume) * 0.3 => current_synth_volume;
                    }
                }
            }
            else {
                // Amplitude below threshold - stop note
                if(note_playing) {
                    instrumentNoteOff(track_instrument[current_recording_track]);
                    0 => note_playing;
                }
            }
        }
        else {
            // Not recording - ensure note is off
            if(note_playing) {
                instrumentNoteOff(track_instrument[current_recording_track]);
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

    if(is_recording[track] || waiting_to_record[track]) {
        <<< "Track", track, "already recording or waiting!" >>>;
        return;
    }

    timeUntilNextMeasure() => dur wait_time;

    <<< ">>> TRACK", track, "WAITING FOR NEXT MEASURE <<<" >>>;
    <<< "Starting in:", wait_time / second, "seconds" >>>;
    <<< "Instrument:", instrument_names[track_instrument[track]] >>>;

    1 => waiting_to_record[track];
    sendTrackState(track);

    spork ~ actuallyStartRecording(track, wait_time);
}

fun void actuallyStartRecording(int track, dur wait_time) {
    wait_time => now;

    if(!waiting_to_record[track]) return;

    0 => waiting_to_record[track];

    <<< ">>> TRACK", track, "RECORDING STARTED <<<" >>>;
    <<< "Instrument:", instrument_names[track_instrument[track]] >>>;

    // Prepare synthesis
    track => current_recording_track;
    selectInstrument(track_instrument[track]);
    1.0 => synth_output.gain;
    0 => note_playing;  // Reset note state
    220.0 => current_synth_freq;  // Initial frequency
    0.0 => current_synth_volume;  // Initial volume
    1 => synth_active;  // Enable pitch detection loop

    // Clear and start recording
    0 => lisa[track].play;
    lisa[track].clear();
    0::second => lisa[track].recPos;
    1 => lisa[track].record;

    1 => is_recording[track];
    now => record_start_time[track];

    sendTrackState(track);

    spork ~ recordingMonitor(track);
}

fun void stopRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;

    if(is_recording[track]) {
        // Stop synthesis
        0 => synth_active;
        if(note_playing) {
            instrumentNoteOff(track_instrument[track]);
            0 => note_playing;
        }
        0.0 => synth_output.gain;

        // Stop recording
        0 => lisa[track].record;
        0 => is_recording[track];

        lisa[track].recPos() => dur raw_duration;
        quantizeToMeasure(raw_duration) => recorded_duration[track];
        recorded_duration[track] / second => loop_length[track];

        (recorded_duration[track] / measureDuration()) $ int => int num_measures;
        (recorded_duration[track] / beatDuration()) $ int => int num_beats;

        <<< ">>> TRACK", track, "RECORDING STOPPED <<<" >>>;
        <<< "Raw length:", raw_duration / second, "seconds" >>>;
        <<< "Quantized to:", loop_length[track], "seconds",
            "(" + num_measures + " measures,", num_beats + " beats)" >>>;

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
            <<< "Track", track, "recording too short" >>>;
        }

        sendTrackState(track);
    }
}

fun void clearTrack(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;

    <<< ">>> CLEARING TRACK", track, "<<<" >>>;

    // If currently recording this track, stop synthesis
    if(is_recording[track]) {
        0 => synth_active;
        if(note_playing) {
            instrumentNoteOff(track_instrument[track]);
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

    sendTrackState(track);
}

fun void setTrackVolume(int track, float vol) {
    if(track < 0 || track >= NUM_TRACKS) return;

    Math.max(0.0, Math.min(1.0, vol)) => float clamped_vol;
    clamped_vol => output_gains[track].gain;
    <<< "Track", track, "volume:", clamped_vol >>>;
}

fun void recordingMonitor(int track) {
    while(is_recording[track]) {
        now - record_start_time[track] => dur elapsed;

        if(elapsed >= max_duration) {
            <<< "Track", track, "max duration reached" >>>;
            stopRecording(track);
            return;
        }

        100::ms => now;
    }
}

// === OSC OUTPUT ===
OscOut osc_out;
osc_out.dest("127.0.0.1", 6451);

fun void sendTrackState(int track) {
    osc_out.start("/track/state");
    osc_out.add(track);
    osc_out.add(is_recording[track]);
    osc_out.add(is_playing[track]);
    osc_out.add(waiting_to_record[track]);
    osc_out.add(track_instrument[track]);
    osc_out.send();
}

fun void tempoPulse() {
    0 => int beat_count;

    while(true) {
        osc_out.start("/tempo/beat");
        osc_out.add(beat_count % beats_per_measure);
        osc_out.send();

        beat_count++;
        beatDuration() => now;
    }
}

// === OSC LISTENER ===
fun void oscListener() {
    while(true) {
        oin => now;
        while(oin.recv(msg)) {

            if(msg.address == "/loop/record") {
                msg.getInt(0) => int track;
                msg.getInt(1) => int record_state;

                if(record_state == 1) {
                    startRecording(track);
                } else {
                    stopRecording(track);
                }
            }

            else if(msg.address == "/loop/clear") {
                msg.getInt(0) => int track;
                clearTrack(track);
            }

            else if(msg.address == "/loop/volume") {
                msg.getInt(0) => int track;
                msg.getFloat(1) => float vol;
                setTrackVolume(track, vol);
            }

            else if(msg.address == "/loop/instrument") {
                msg.getInt(0) => int track;
                msg.getInt(1) => int inst;
                setTrackInstrument(track, inst);
                sendTrackState(track);
            }

            else if(msg.address == "/loop/bpm") {
                msg.getFloat(0) => float new_bpm;
                setBPM(new_bpm);
            }
        }
    }
}

// === MAIN PROGRAM ===
spork ~ oscListener();
spork ~ tempoPulse();
spork ~ pitchDetectionLoop();

while(true) {
    1::second => now;
}
