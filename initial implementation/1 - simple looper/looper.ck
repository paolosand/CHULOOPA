//---------------------------------------------------------------------
// name: looper.ck
// desc: Multi-track audio looper with OSC control
//       2 independent audio tracks, each with own recording/playback
//       All tracks sync to shared BPM with automatic quantization
//       Controlled via OSC messages from GUI
//
// OSC Commands:
//   /loop/record <track> 1    - Start recording on track (0 or 1)
//   /loop/record <track> 0    - Stop recording on track
//   /loop/clear <track>       - Clear track buffer
//   /loop/volume <track> f    - Set track playback volume (0.0-1.0)
//   /loop/bpm f               - Set BPM (30-300)
//
// Usage:
//   chuck looper.ck looper_gui.ck
//---------------------------------------------------------------------

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
int waiting_to_record[NUM_TRACKS];  // Track is waiting for next measure to start recording
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

// === BPM / TEMPO VARIABLES (shared across all tracks) ===
120.0 => float bpm;
4 => int beats_per_measure;
time tempo_start_time;  // When the tempo clock started
now => tempo_start_time;

// Calculate beat and measure durations
fun dur beatDuration() {
    return (60.0 / bpm)::second;
}

fun dur measureDuration() {
    return (60.0 / bpm * beats_per_measure)::second;
}

// Calculate time until next measure starts
fun dur timeUntilNextMeasure() {
    now - tempo_start_time => dur elapsed;
    measureDuration() => dur measure_dur;

    // Find position within current measure
    elapsed % measure_dur => dur position_in_measure;

    // Time remaining until next measure
    if(position_in_measure == 0::second) {
        return 0::second;  // We're exactly on a measure boundary
    } else {
        return measure_dur - position_in_measure;
    }
}

// Quantize duration to nearest measure
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

// Set BPM
fun void setBPM(float new_bpm) {
    Math.max(30.0, Math.min(300.0, new_bpm)) => bpm;
    <<< "BPM set to:", bpm >>>;
}

// === OSC SETUP ===
OscIn oin;
OscMsg msg;
6450 => int OSC_PORT;
OSC_PORT => oin.port;
oin.listenAll();

<<< "=====================================================" >>>;
<<< "      ChucK Multi-Track Looper - OSC Control" >>>;
<<< "=====================================================" >>>;
<<< "OSC Port:", OSC_PORT >>>;
<<< "Tempo Out Port:", 6451 >>>;
<<< "Number of tracks:", NUM_TRACKS >>>;
<<< "Max loop duration:", max_duration / second, "seconds" >>>;
<<< "Default BPM:", bpm >>>;
<<< "Time signature:", beats_per_measure + "/4" >>>;
<<< "Quantization: Nearest measure" >>>;
<<< "Waiting for commands..." >>>;
<<< "=====================================================" >>>;

// === TRACK FUNCTIONS ===

// Start recording on track (waits for next measure)
fun void startRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) {
        <<< "Invalid track:", track >>>;
        return;
    }

    if(is_recording[track] || waiting_to_record[track]) {
        <<< "Track", track, "already recording or waiting!" >>>;
        return;
    }

    // Calculate wait time until next measure
    timeUntilNextMeasure() => dur wait_time;

    <<< ">>> TRACK", track, "WAITING FOR NEXT MEASURE <<<" >>>;
    <<< "Starting in:", wait_time / second, "seconds" >>>;

    1 => waiting_to_record[track];
    sendTrackState(track);

    // Schedule recording to start on next measure
    spork ~ actuallyStartRecording(track, wait_time);
}

// Actually start recording (called after waiting for measure boundary)
fun void actuallyStartRecording(int track, dur wait_time) {
    // Wait for next measure
    wait_time => now;

    // Check if still supposed to record (user might have cancelled)
    if(!waiting_to_record[track]) {
        return;
    }

    0 => waiting_to_record[track];

    <<< ">>> TRACK", track, "RECORDING STARTED <<<" >>>;

    // Clear and start recording
    0 => lisa[track].play;
    lisa[track].clear();
    0::second => lisa[track].recPos;
    1 => lisa[track].record;

    1 => is_recording[track];
    now => record_start_time[track];

    sendTrackState(track);

    // Monitor recording
    spork ~ recordingMonitor(track);
}

// Stop recording on track
fun void stopRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) {
        <<< "Invalid track:", track >>>;
        return;
    }

    if(is_recording[track]) {
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
            "(" + num_measures + " measures,", num_beats + " beats @" + bpm + " BPM)" >>>;

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

        sendTrackState(track);
    } else {
        <<< "Track", track, "not recording!" >>>;
    }
}

// Clear track
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
    0 => waiting_to_record[track];  // Cancel waiting state
    0.0 => loop_length[track];
    0::second => recorded_duration[track];
    0 => has_loop[track];

    sendTrackState(track);
}

// Set track volume
fun void setTrackVolume(int track, float vol) {
    if(track < 0 || track >= NUM_TRACKS) {
        <<< "Invalid track:", track >>>;
        return;
    }

    Math.max(0.0, Math.min(1.0, vol)) => float clamped_vol;
    clamped_vol => output_gains[track].gain;
    <<< "Track", track, "volume set to:", clamped_vol >>>;
}

// Monitor recording (auto-stop at max duration)
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

// === OSC LISTENER ===
fun void oscListener() {
    while(true) {
        oin => now;
        while(oin.recv(msg)) {

            // Record command: /loop/record <track> <state>
            if(msg.address == "/loop/record") {
                msg.getInt(0) => int track;
                msg.getInt(1) => int record_state;

                if(record_state == 1) {
                    startRecording(track);
                } else {
                    stopRecording(track);
                }
            }

            // Clear command: /loop/clear <track>
            else if(msg.address == "/loop/clear") {
                msg.getInt(0) => int track;
                clearTrack(track);
            }

            // Volume command: /loop/volume <track> <vol>
            else if(msg.address == "/loop/volume") {
                msg.getInt(0) => int track;
                msg.getFloat(1) => float vol;
                setTrackVolume(track, vol);
            }

            // BPM command: /loop/bpm <bpm>
            else if(msg.address == "/loop/bpm") {
                msg.getFloat(0) => float new_bpm;
                setBPM(new_bpm);
            }

            // Status request
            else if(msg.address == "/loop/status") {
                <<< "=== LOOPER STATUS ===" >>>;
                <<< "BPM:", bpm >>>;
                for(0 => int i; i < NUM_TRACKS; i++) {
                    <<< "Track", i, "- Recording:", is_recording[i],
                        "| Playing:", is_playing[i],
                        "| Length:", loop_length[i], "sec" >>>;
                }
            }
        }
    }
}

// === OSC OUTPUT ===
OscOut osc_out;
osc_out.dest("127.0.0.1", 6451);

// Send track state update to GUI
fun void sendTrackState(int track) {
    osc_out.start("/track/state");
    osc_out.add(track);
    osc_out.add(is_recording[track]);
    osc_out.add(is_playing[track]);
    osc_out.add(waiting_to_record[track]);
    osc_out.send();
}

// === TEMPO PULSE SENDER ===
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

// === MAIN PROGRAM ===
spork ~ oscListener();
spork ~ tempoPulse();

while(true) {
    1::second => now;
}
