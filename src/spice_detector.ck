//---------------------------------------------------------------------
// name: spice_detector.ck
// desc: Audio-driven spice detector for CHULOOPA v4
//       Analyzes ensemble audio (guitar/vocal/room) and computes a
//       composite "spice level" from RMS, spectral flux, onset density,
//       and delta RMS. Sends spice via OSC to both Python (port 5000)
//       and ChucK v4 (port 5001) every 500ms.
//
// Startup order: Python → spice_detector → chuloopa_drums_v4
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
//   → Python (127.0.0.1:5000)
//   → ChucK v4 (127.0.0.1:5001)
//---------------------------------------------------------------------

// === CONFIGURATION ===
512 => int FRAME_SIZE;
FRAME_SIZE/4 => int HOP_SIZE;
HOP_SIZE::samp => dur HOP;

// Analysis window size (500ms for spice update rate)
500::ms => dur ANALYSIS_WINDOW;

// Feature weights for composite spice
0.35 => float W_RMS;          // How loud right now
0.25 => float W_FLUX;         // Strumming rate / timbral change
0.25 => float W_ONSET;        // How many attacks per window
0.15 => float W_DELTA;        // Energy picking up or dying down

// Silence gate: if RMS below this, spice = 0.0
// Note: FFT-derived energy is ~10x smaller than time-domain RMS
0.0001 => float SILENCE_THRESHOLD;

// Onset detection
1.5 => float ONSET_THRESHOLD_MULTIPLIER;
0.005 => float MIN_ONSET_STRENGTH;
100::ms => dur MIN_ONSET_INTERVAL;

// Self-calibration: rolling 30-second history (60 windows × 500ms)
60 => int HISTORY_LENGTH;

// Initial conservative spice (used while warming up calibration)
0.3 => float WARMUP_SPICE;
30 => int WARMUP_FRAMES;  // Number of windows before full calibration active

// OSC ports
5000 => int OSC_PORT_PYTHON;   // Python drum_variation_ai.py
5001 => int OSC_PORT_CHUCK;    // chuloopa_drums_v4.ck

// MIDI device for guitar_mix control
0 => int MIDI_DEVICE;
75 => int CC_GUITAR_MIX;

// Guitar/vocal mix (0.0 = all vocal, 1.0 = all guitar)
// Only meaningful in PERFORMANCE mode (--channels:2)
0.5 => float guitar_mix;

// === DETECT PERFORMANCE MODE ===
// Check if we have 2 channels available (--channels:2 flag)
0 => int performance_mode;
if(adc.channels() >= 2) {
    1 => performance_mode;
    <<< "PERFORMANCE MODE: 2-channel audio (guitar/vocal mix)" >>>;
} else {
    <<< "BASIC MODE: Single channel audio" >>>;
}

// === AUDIO SETUP ===
// RMS UAna returns 0 when driven by UGen sources (adc is not a UAna).
// Solution: use FFT as sole UAna; compute energy from FFT magnitudes.
FFT fft => blackhole;

// Declare gain objects globally so MIDI can update them
Gain guitar_gain;
Gain vocal_gain;
Gain mono_mix;

// Connect audio input
if(performance_mode) {
    // Weighted mix of 2 channels into a mono_mix Gain, then into FFT
    adc.chan(0) => guitar_gain => mono_mix;
    adc.chan(1) => vocal_gain => mono_mix;
    guitar_mix => guitar_gain.gain;
    (1.0 - guitar_mix) => vocal_gain.gain;
    mono_mix => fft;
} else {
    // Single channel: direct connection
    adc => fft;
}

FRAME_SIZE => fft.size;
Windowing.hann(FRAME_SIZE) => fft.window;

// === OSC SETUP ===
OscOut oout_python;
oout_python.dest("127.0.0.1", OSC_PORT_PYTHON);

OscOut oout_chuck;
oout_chuck.dest("127.0.0.1", OSC_PORT_CHUCK);

fun void sendSpice(float spice) {
    oout_python.start("/chuloopa/spice");
    spice => oout_python.add;
    oout_python.send();

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

// === MIDI SETUP ===
MidiIn min;
MidiMsg midi_msg;

if(min.num() > 0) {
    if(min.open(MIDI_DEVICE)) {
        <<< "MIDI Device:", min.name() >>>;
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
                    // Update gain values in real-time
                    guitar_mix => guitar_gain.gain;
                    (1.0 - guitar_mix) => vocal_gain.gain;
                    <<< "Guitar mix:", (guitar_mix * 100) $ int, "% guitar /" , ((1.0 - guitar_mix) * 100) $ int, "% vocal" >>>;
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

// Previous RMS for delta calculation
0.0 => float prev_rms_value;

// === SELF-CALIBRATING NORMALIZATION ===
// Rolling min/max for each feature over HISTORY_LENGTH windows

// Per-feature history arrays
float rms_history[HISTORY_LENGTH];
float flux_history_spice[HISTORY_LENGTH];
float onset_history[HISTORY_LENGTH];
float delta_history[HISTORY_LENGTH];

// Current history index and fill count
0 => int history_idx;
0 => int history_filled;
0 => int warmup_count;

// Per-window state
float window_onset_count;
now => time window_start;

fun float arrayMin(float arr[], int filled_count) {
    if(filled_count == 0) return 0.0;
    arr[0] => float min_val;
    for(1 => int i; i < filled_count; i++) {
        if(arr[i] < min_val) arr[i] => min_val;
    }
    return min_val;
}

fun float arrayMax(float arr[], int filled_count) {
    if(filled_count == 0) return 1.0;
    arr[0] => float max_val;
    for(1 => int i; i < filled_count; i++) {
        if(arr[i] > max_val) arr[i] => max_val;
    }
    return max_val;
}

// Normalize a value using observed min/max, with fallback if range is tiny
fun float normalizeFeature(float val, float arr[], int filled_count) {
    if(filled_count < 3) {
        // Not enough history yet - return conservative estimate
        return 0.3;
    }
    arrayMin(arr, filled_count) => float min_val;
    arrayMax(arr, filled_count) => float max_val;
    max_val - min_val => float range;
    if(range < 0.0001) return 0.5;  // Avoid division by zero
    return Math.max(0.0, Math.min(1.0, (val - min_val) / range));
}

// === ENERGY FROM FFT MAGNITUDES ===
// RMS UAna doesn't accumulate UGen audio; compute energy from FFT spectrum instead.
// Energy = sqrt(mean(mag^2)) across all bins (proportional to time-domain RMS).
fun float computeEnergyFromFFT(UAnaBlob @ blob) {
    0.0 => float sum_sq;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) * blob.fval(i) +=> sum_sq;
    }
    return Math.sqrt(sum_sq / (FRAME_SIZE/2));
}

// === SPECTRAL FLUX COMPUTATION ===
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

// === MAIN ANALYSIS LOOP (frame-level accumulation) ===
// Runs at HOP rate, accumulates features per 500ms window

0 => int current_window_onset_count;
0.0 => float window_rms_acc;
0.0 => float window_flux_acc;
0.0 => float window_flux_max;
0 => int window_frame_count;

fun void frameAnalysisLoop() {
    FRAME_SIZE::samp => now;

    while(true) {
        fft.upchuck() @=> UAnaBlob @ blob;

        // Energy from FFT magnitudes (RMS UAna returns 0 for UGen sources)
        computeEnergyFromFFT(blob) => float frame_rms;
        frame_rms +=> window_rms_acc;
        window_frame_count++;

        // Spectral flux
        computeSpectralFlux(blob) => float flux;
        flux +=> window_flux_acc;
        if(flux > window_flux_max) flux => window_flux_max;

        // Update flux history for adaptive threshold
        flux => flux_history[flux_history_idx];
        (flux_history_idx + 1) % flux_history.size() => flux_history_idx;
        if(!flux_history_filled && flux_history_idx == 0) 1 => flux_history_filled;

        // Onset detection within window
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

// === SPICE CALCULATION LOOP (runs every 500ms) ===
fun void spiceCalculationLoop() {
    // Initialize history
    for(0 => int i; i < HISTORY_LENGTH; i++) {
        0.0 => rms_history[i];
        0.0 => flux_history_spice[i];
        0.0 => onset_history[i];
        0.0 => delta_history[i];
    }

    0.0 => float current_spice;

    while(true) {
        ANALYSIS_WINDOW => now;

        // === COLLECT THIS WINDOW'S FEATURES ===

        // Average RMS for this window
        0.0 => float avg_rms;
        if(window_frame_count > 0) {
            window_rms_acc / window_frame_count => avg_rms;
        }

        // Average spectral flux
        0.0 => float avg_flux;
        if(window_frame_count > 0) {
            window_flux_acc / window_frame_count => avg_flux;
        }

        // Onset count per second (normalize by window duration)
        (current_window_onset_count / (ANALYSIS_WINDOW / second)) => float onset_rate;

        // Delta RMS: difference from previous window
        avg_rms - prev_rms_value => float delta_rms;
        avg_rms => prev_rms_value;

        // Reset accumulators for next window
        0.0 => window_rms_acc;
        0.0 => window_flux_acc;
        0.0 => window_flux_max;
        0 => window_frame_count;
        0 => current_window_onset_count;

        // === SILENCE GATE ===
        if(avg_rms < SILENCE_THRESHOLD) {
            0.0 => current_spice;
            sendSpice(0.0);
            <<< "SPICE: 0% (silence)" >>>;
            continue;
        }

        // === UPDATE HISTORY ===
        avg_rms => rms_history[history_idx];
        avg_flux => flux_history_spice[history_idx];
        onset_rate => onset_history[history_idx];
        Math.fabs(delta_rms) => delta_history[history_idx];  // Use absolute delta

        (history_idx + 1) % HISTORY_LENGTH => history_idx;
        if(!history_filled && history_idx == 0) 1 => history_filled;
        warmup_count++;

        // === NORMALIZE FEATURES ===
        HISTORY_LENGTH => int count;
        if(!history_filled) Math.min(warmup_count, HISTORY_LENGTH) $ int => count;

        normalizeFeature(avg_rms, rms_history, count) => float norm_rms;
        normalizeFeature(avg_flux, flux_history_spice, count) => float norm_flux;
        normalizeFeature(onset_rate, onset_history, count) => float norm_onset;
        normalizeFeature(Math.fabs(delta_rms), delta_history, count) => float norm_delta;

        // === COMPOSITE SPICE ===
        W_RMS * norm_rms +
        W_FLUX * norm_flux +
        W_ONSET * norm_onset +
        W_DELTA * norm_delta => float composite;

        Math.max(0.0, Math.min(1.0, composite)) => current_spice;

        // === SEND VIA OSC ===
        sendSpice(current_spice);

        // === CONSOLE OUTPUT ===
        <<< "SPICE:", (current_spice * 100) $ int, "%",
            "| RMS:", (norm_rms * 100) $ int,
            "| FLUX:", (norm_flux * 100) $ int,
            "| ONSET:", (norm_onset * 100) $ int,
            "| DELTA:", (norm_delta * 100) $ int >>>;
    }
}

// === MAIN PROGRAM ===

<<< "" >>>;
<<< "╔═══════════════════════════════════════════════════╗" >>>;
<<< "║  SPICE DETECTOR - Audio-Driven Variation Control ║" >>>;
<<< "╚═══════════════════════════════════════════════════╝" >>>;
<<< "" >>>;
<<< "Features:" >>>;
<<< "  RMS Level    (weight:", W_RMS, ")" >>>;
<<< "  Spectral Flux (weight:", W_FLUX, ")" >>>;
<<< "  Onset Density (weight:", W_ONSET, ")" >>>;
<<< "  Delta RMS     (weight:", W_DELTA, ")" >>>;
<<< "" >>>;
<<< "OSC Output:" >>>;
<<< "  Python (port:", OSC_PORT_PYTHON, ")" >>>;
<<< "  ChucK v4 (port:", OSC_PORT_CHUCK, ")" >>>;
<<< "" >>>;
if(performance_mode) {
    <<< "Mode: PERFORMANCE (2-channel, CC 75 controls guitar/vocal mix)" >>>;
} else {
    <<< "Mode: BASIC (single channel)" >>>;
}
<<< "" >>>;
<<< "Calibrating (play at varying intensities for 30 seconds)..." >>>;
<<< "" >>>;

spork ~ frameAnalysisLoop();
spork ~ spiceCalculationLoop();
if(min.num() > 0) spork ~ midiListener();

while(true) {
    sendPerformanceMode();
    if(performance_mode) sendGuitarMix(guitar_mix);
    30::second => now;
}
