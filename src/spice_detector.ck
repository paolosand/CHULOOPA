//---------------------------------------------------------------------
// name: spice_detector.ck
// desc: Audio-driven spice detector for CHULOOPA v4
//       Computes spice from dBFS-scaled RMS — no calibration required.
//       Just set your interface gain so loud playing peaks around PEAK_DB.
//       Sends spice via OSC to ChucK (port 5001) every 500ms.
//
// Startup order: Python → spice_detector → chuloopa_main
//
// Usage:
//   chuck src/spice_detector.ck              (BASIC mono mode)
//   chuck --channels:2 src/spice_detector.ck (PERFORMANCE stereo mode)
//
// MIDI CC:
//   CC 75: guitar_mix (0.0 = all vocal, 1.0 = all guitar)
//          Only used in PERFORMANCE mode
//
// OSC Output:
//   /chuloopa/spice <float 0.0-1.0>
//   → ChucK v4 (127.0.0.1:5001)
//---------------------------------------------------------------------

// === CONFIGURATION ===
512 => int FRAME_SIZE;
FRAME_SIZE/4 => int HOP_SIZE;
HOP_SIZE::samp => dur HOP;

500::ms => dur ANALYSIS_WINDOW;

// === dBFS SPICE MAPPING ===
// No calibration needed — just tune these to your interface gain once:
//   NOISE_FLOOR_DB : dBFS below which spice = 0 (silence gate)
//   PEAK_DB        : dBFS at which spice = 1.0 (your max expected playing level)
//
// Tip: check the "dBFS" column in spice_log.csv after a test recording.
//   Soft playing around -70 to -65 dBFS? → NOISE_FLOOR_DB = -75 is good.
//   Loud playing only reaches -58 dBFS? → lower PEAK_DB to -55.
-75.0 => float NOISE_FLOOR_DB;
-50.0 => float PEAK_DB;

// Onset detection (used for logging; not part of spice calculation)
1.5 => float ONSET_THRESHOLD_MULTIPLIER;
0.005 => float MIN_ONSET_STRENGTH;
100::ms => dur MIN_ONSET_INTERVAL;

// OSC ports
5001 => int OSC_PORT_CHUCK;

// MIDI
0 => int MIDI_DEVICE;
75 => int CC_GUITAR_MIX;

0.5 => float guitar_mix;

// === DETECT PERFORMANCE MODE ===
0 => int performance_mode;
if(adc.channels() >= 2) {
    1 => performance_mode;
    <<< "PERFORMANCE MODE: 2-channel audio (guitar/vocal mix)" >>>;
} else {
    <<< "BASIC MODE: Single channel audio" >>>;
}

// === AUDIO SETUP ===
// RMS UAna returns 0 for UGen sources — compute energy from FFT magnitudes instead.
FFT fft => blackhole;

Gain guitar_gain;
Gain vocal_gain;
Gain mono_mix;

if(performance_mode) {
    adc.chan(0) => guitar_gain => mono_mix;
    adc.chan(1) => vocal_gain => mono_mix;
    guitar_mix => guitar_gain.gain;
    (1.0 - guitar_mix) => vocal_gain.gain;
    mono_mix => fft;
} else {
    adc => fft;
}

FRAME_SIZE => fft.size;
Windowing.hann(FRAME_SIZE) => fft.window;

// === OSC SETUP ===
OscOut oout_chuck;
oout_chuck.dest("127.0.0.1", OSC_PORT_CHUCK);

fun void sendSpice(float spice) {
    oout_chuck.start("/chuloopa/spice");
    spice => oout_chuck.add;
    oout_chuck.send();
}

fun void sendPerformanceMode() {
    oout_chuck.start("/chuloopa/performance_mode");
    performance_mode => oout_chuck.add;
    oout_chuck.send();
}

fun void sendGuitarMix(float mix) {
    oout_chuck.start("/chuloopa/guitar_mix");
    mix => oout_chuck.add;
    oout_chuck.send();
}

// === FILE LOGGING ===
FileIO fout;
fout.open("spice_log.csv", FileIO.WRITE);
if(!fout.good()) {
    <<< "WARNING: Could not open spice_log.csv for writing!" >>>;
} else {
    fout.write("timestamp_ms,raw_rms,db_rms,onset_rate,db_spice\n");
}

// === MIDI SETUP ===
MidiIn min;
MidiMsg midi_msg;

0 => int midi_in_opened;
if(min.num() == 0) {
    <<< "WARNING: No MIDI devices found!" >>>;
} else {
    if(min.open("LPD8")) {
        1 => midi_in_opened;
        <<< "MIDI Device (input):", min.name() >>>;
    }
    if(!midi_in_opened && min.num() > 1) {
        if(min.open(1)) {
            1 => midi_in_opened;
            <<< "MIDI Device (input, port 1):", min.name() >>>;
        }
    }
    if(!midi_in_opened) {
        if(min.open(MIDI_DEVICE)) {
            <<< "MIDI Device (input, fallback port 0):", min.name() >>>;
        }
    }
}

fun void midiListener() {
    while(true) {
        min => now;
        while(min.recv(midi_msg)) {
            midi_msg.data1 => int status;
            midi_msg.data2 => int data1;
            midi_msg.data3 => int data2;
            status & 0xF0 => int messageType;

            if(messageType == 0xB0) {
                if(data1 == CC_GUITAR_MIX && performance_mode) {
                    data2 / 127.0 => guitar_mix;
                    guitar_mix => guitar_gain.gain;
                    (1.0 - guitar_mix) => vocal_gain.gain;
                    <<< "Guitar mix:", (guitar_mix * 100) $ int, "% guitar /",
                        ((1.0 - guitar_mix) * 100) $ int, "% vocal" >>>;
                    sendGuitarMix(guitar_mix);
                }
            }
        }
    }
}

// === STATE VARIABLES ===
float prev_spectrum[FRAME_SIZE/2];
float flux_history[50];
0 => int flux_history_idx;
0 => int flux_history_filled;
time last_onset_time;
now => last_onset_time;

// === ENERGY FROM FFT MAGNITUDES ===
fun float computeEnergyFromFFT(UAnaBlob @ blob) {
    0.0 => float sum_sq;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) * blob.fval(i) +=> sum_sq;
    }
    return Math.sqrt(sum_sq / (FRAME_SIZE/2));
}

// === SPECTRAL FLUX (used only for onset detection) ===
fun float computeSpectralFlux(UAnaBlob @ blob) {
    0.0 => float flux;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float current_mag;
        Math.max(0.0, current_mag - prev_spectrum[i]) => float diff;
        diff +=> flux;
        current_mag => prev_spectrum[i];
    }
    return flux;
}

fun float getAdaptiveFluxThreshold() {
    if(!flux_history_filled && flux_history_idx < 10) {
        return MIN_ONSET_STRENGTH * 2.0;
    }
    0.0 => float mean;
    flux_history.size() => int count;
    if(!flux_history_filled) flux_history_idx => count;
    for(0 => int i; i < count; i++) flux_history[i] +=> mean;
    mean / count => mean;
    return mean * ONSET_THRESHOLD_MULTIPLIER;
}

// === dBFS → SPICE MAPPING ===
// Maps raw RMS energy to 0.0–1.0 using a fixed dB scale.
// Values below NOISE_FLOOR_DB → 0.0. Values above PEAK_DB → 1.0 (clamped).
fun float rmsToDbSpice(float rms) {
    if(rms <= 0.0) return 0.0;
    20.0 * Math.log10(rms) => float db;
    return Math.max(0.0, Math.min(1.0, (db - NOISE_FLOOR_DB) / (PEAK_DB - NOISE_FLOOR_DB)));
}

// === WINDOW ACCUMULATORS ===
0 => int current_window_onset_count;
0.0 => float window_rms_acc;
0 => int window_frame_count;

// === FRAME ANALYSIS LOOP ===
fun void frameAnalysisLoop() {
    FRAME_SIZE::samp => now;

    while(true) {
        fft.upchuck() @=> UAnaBlob @ blob;

        computeEnergyFromFFT(blob) => float frame_rms;
        frame_rms +=> window_rms_acc;
        window_frame_count++;

        computeSpectralFlux(blob) => float flux;

        flux => flux_history[flux_history_idx];
        (flux_history_idx + 1) % flux_history.size() => flux_history_idx;
        if(!flux_history_filled && flux_history_idx == 0) 1 => flux_history_filled;

        if(flux >= getAdaptiveFluxThreshold() && flux >= MIN_ONSET_STRENGTH) {
            now - last_onset_time => dur time_since_last;
            if(time_since_last >= MIN_ONSET_INTERVAL) {
                current_window_onset_count++;
                now => last_onset_time;
            }
        }

        HOP => now;
    }
}

// === SPICE CALCULATION LOOP (every 500ms) ===
fun void spiceCalculationLoop() {
    0.0 => float current_spice;

    while(true) {
        ANALYSIS_WINDOW => now;

        // Average RMS for this window
        0.0 => float avg_rms;
        if(window_frame_count > 0) {
            window_rms_acc / window_frame_count => avg_rms;
        }

        // Onset rate (onsets/second) — logged only, not used in spice
        (current_window_onset_count / (ANALYSIS_WINDOW / second)) => float onset_rate;

        // dBFS value for logging and display
        0.0 => float db_rms;
        if(avg_rms > 0.0) 20.0 * Math.log10(avg_rms) => db_rms;

        // Reset accumulators
        0.0 => window_rms_acc;
        0 => window_frame_count;
        0 => current_window_onset_count;

        // Compute spice from dBFS
        rmsToDbSpice(avg_rms) => current_spice;

        // Send via OSC
        sendSpice(current_spice);

        // Log to CSV
        if(fout.good()) {
            fout.write(((now/ms)$int) + "," + avg_rms + "," + db_rms + "," + onset_rate + "," + current_spice + "\n");
        }

        // Console
        <<< "SPICE:", (current_spice * 100) $ int, "%",
            "| dBFS:", (db_rms $ int),
            "| onsets/s:", (onset_rate $ int) >>>;
    }
}

// === MAIN PROGRAM ===

<<< "" >>>;
<<< "╔═══════════════════════════════════════════════════╗" >>>;
<<< "║  SPICE DETECTOR - Audio-Driven Variation Control ║" >>>;
<<< "╚═══════════════════════════════════════════════════╝" >>>;
<<< "" >>>;
<<< "Method: dBFS RMS (no calibration required)" >>>;
<<< "  Noise floor:", NOISE_FLOOR_DB, "dBFS → spice 0.0" >>>;
<<< "  Peak level: ", PEAK_DB,        "dBFS → spice 1.0" >>>;
<<< "" >>>;
<<< "OSC Output:" >>>;
<<< "  ChucK v4 (port:", OSC_PORT_CHUCK, ")" >>>;
<<< "" >>>;
if(performance_mode) {
    <<< "Mode: PERFORMANCE (2-channel, CC 75 controls guitar/vocal mix)" >>>;
} else {
    <<< "Mode: BASIC (single channel)" >>>;
}
<<< "" >>>;
<<< "Logging to: spice_log.csv" >>>;
<<< "" >>>;

spork ~ frameAnalysisLoop();
spork ~ spiceCalculationLoop();
if(midi_in_opened) spork ~ midiListener();

while(true) {
    sendPerformanceMode();
    if(performance_mode) sendGuitarMix(guitar_mix);
    30::second => now;
}
