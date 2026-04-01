//---------------------------------------------------------------------
// name: drum_onset_detector.ck
// desc: Real-time onset detection for vocal beatboxing
//       Uses spectral flux + adaptive thresholding for onset detection
//       Designed for kick, snare, hi-hat classification
//
// Phase 1: Onset Detection Only (classification comes later)
//
// Usage: chuck src/drum_onset_detector.ck
//---------------------------------------------------------------------

// === CONFIGURATION ===
512 => int FRAME_SIZE;           // FFT frame size (smaller = better temporal resolution)
FRAME_SIZE/4 => int HOP_SIZE;    // Hop size for analysis
HOP_SIZE::samp => dur HOP;       // Time advance per frame

// Onset detection parameters (adjusted to prevent double-triggering)
1.5 => float ONSET_THRESHOLD_MULTIPLIER;  // Multiplier for adaptive threshold
0.01 => float MIN_ONSET_STRENGTH;         // Minimum onset strength to consider
150::ms => dur MIN_ONSET_INTERVAL;        // Minimum time between onsets (increased from 100ms)

// === AUDIO SETUP ===
adc => Gain input_gain => blackhole;
1.0 => input_gain.gain;

// === ANALYSIS CHAIN ===
adc => FFT fft => blackhole;
adc => RMS rms => blackhole;

FRAME_SIZE => fft.size;
Windowing.hann(FRAME_SIZE) => fft.window;

// === STATE VARIABLES ===
float prev_spectrum[FRAME_SIZE/2];     // Previous frame spectrum for flux calculation
float onset_strengths[0];              // Detected onset strengths
time onset_times[0];                   // Detected onset times
time last_onset_time;                  // Last detected onset (for debouncing)
now => last_onset_time;

// Running statistics for adaptive thresholding
float flux_history[50];                // Recent flux values for threshold calculation
0 => int flux_history_idx;
0 => int flux_history_filled;

// === ONSET DETECTION FUNCTIONS ===

// Calculate spectral flux (measure of spectral change)
fun float spectralFlux() {
    fft.upchuck() @=> UAnaBlob @ blob;
    0.0 => float flux;

    // Calculate sum of positive differences (Half-Wave Rectified Spectral Flux)
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float current_mag;

        // Only sum increases in magnitude (positive flux)
        Math.max(0.0, current_mag - prev_spectrum[i]) => float diff;
        diff +=> flux;

        // Store current magnitude for next frame
        current_mag => prev_spectrum[i];
    }

    return flux;
}

// Update flux history for adaptive thresholding
fun void updateFluxHistory(float flux) {
    flux => flux_history[flux_history_idx];
    (flux_history_idx + 1) % flux_history.size() => flux_history_idx;

    if(!flux_history_filled && flux_history_idx == 0) {
        1 => flux_history_filled;
    }
}

// Calculate adaptive threshold from flux history
fun float getAdaptiveThreshold() {
    if(!flux_history_filled && flux_history_idx < 10) {
        // Not enough history, use conservative threshold
        return MIN_ONSET_STRENGTH * 2.0;
    }

    // Calculate mean of flux history
    0.0 => float mean;
    flux_history.size() => int count;
    if(!flux_history_filled) {
        flux_history_idx => count;
    }

    for(0 => int i; i < count; i++) {
        flux_history[i] +=> mean;
    }
    mean / count => mean;

    // Threshold is mean * multiplier
    return mean * ONSET_THRESHOLD_MULTIPLIER;
}

// Detect onset from spectral flux
fun int detectOnset(float flux, float threshold) {
    // Check if flux exceeds threshold
    if(flux < threshold) return 0;

    // Check if flux exceeds minimum strength
    if(flux < MIN_ONSET_STRENGTH) return 0;

    // Check if enough time has passed since last onset (debouncing)
    now - last_onset_time => dur time_since_last;
    if(time_since_last < MIN_ONSET_INTERVAL) return 0;

    // Valid onset detected!
    now => last_onset_time;
    return 1;
}

// Save detected onset
fun void saveOnset(float strength) {
    onset_strengths << strength;
    onset_times << now;

    <<< "ONSET DETECTED! Strength:", strength, "Time:", (now/second), "sec" >>>;
}

// === AUDIO FEEDBACK (click on onset) ===
Impulse imp => ResonZ filt => ADSR env => Gain click_gain => dac;
0.3 => click_gain.gain;
2000.0 => filt.freq;
50.0 => filt.Q;
env.set(1::ms, 20::ms, 0.0, 10::ms);

fun void playOnsetClick() {
    1.0 => imp.next;
    env.keyOn();
    1::ms => now;
    env.keyOff();
}

// === MAIN ONSET DETECTION LOOP ===
fun void onsetDetectionLoop() {
    // Let initial buffer fill
    FRAME_SIZE::samp => now;

    <<< "=== Drum Onset Detector ===" >>>;
    <<< "Frame size:", FRAME_SIZE, "samples" >>>;
    <<< "Hop size:", HOP_SIZE, "samples" >>>;
    <<< "Onset threshold multiplier:", ONSET_THRESHOLD_MULTIPLIER >>>;
    <<< "Min onset interval:", MIN_ONSET_INTERVAL/ms, "ms" >>>;
    <<< "" >>>;
    <<< "Start beatboxing! Onsets will be detected and logged." >>>;
    <<< "Press Ctrl+C to stop and see statistics." >>>;
    <<< "" >>>;

    while(true) {
        // Calculate spectral flux
        spectralFlux() => float flux;

        // Update flux history
        updateFluxHistory(flux);

        // Get adaptive threshold
        getAdaptiveThreshold() => float threshold;

        // Detect onset
        if(detectOnset(flux, threshold)) {
            saveOnset(flux);
            spork ~ playOnsetClick();  // Audio feedback (non-blocking)
        }

        // Advance time
        HOP => now;
    }
}

// === STATISTICS & EXPORT ===
fun void printStatistics() {
    <<< "" >>>;
    <<< "=== Onset Detection Statistics ===" >>>;
    <<< "Total onsets detected:", onset_times.size() >>>;
    <<< "" >>>;

    if(onset_times.size() > 0) {
        // Calculate inter-onset intervals (IOI)
        <<< "Inter-Onset Intervals (IOI):" >>>;
        for(1 => int i; i < Math.min(10, onset_times.size()) $ int; i++) {
            (onset_times[i] - onset_times[i-1]) / ms => float ioi_ms;
            <<< "  Onset", i-1, "->", i, ":", ioi_ms, "ms" >>>;
        }

        <<< "" >>>;
        <<< "First 10 onset times:" >>>;
        for(0 => int i; i < Math.min(10, onset_times.size()) $ int; i++) {
            <<< "  Onset", i, ":", (onset_times[i]/second), "sec",
                "(strength:", onset_strengths[i], ")" >>>;
        }
    }
}

// === EXPORT ONSETS TO FILE ===
fun void exportOnsets() {
    "drum_onsets.txt" => string filename;
    FileIO fout;
    fout.open(filename, FileIO.WRITE);

    if(!fout.good()) {
        <<< "ERROR: Could not open file for writing:", filename >>>;
        return;
    }

    fout.write("# Drum Onset Detection Results\n");
    fout.write("# Format: ONSET_INDEX,TIME_SECONDS,STRENGTH\n");

    for(0 => int i; i < onset_times.size(); i++) {
        (onset_times[i] / second) => float time_sec;
        onset_strengths[i] => float strength;

        fout.write(i + "," + time_sec + "," + strength + "\n");
    }

    fout.close();

    <<< "" >>>;
    <<< "Onsets exported to:", filename >>>;
}

// === AUTO-EXPORT LOOP ===
// Continuously exports onset data in real-time (like chuloopa_main.ck)
fun void autoExportLoop() {
    5::second => dur EXPORT_INTERVAL;  // Export every 5 seconds

    <<< "Auto-export enabled - saving to drum_onsets.txt every", EXPORT_INTERVAL/second, "seconds" >>>;

    while(true) {
        EXPORT_INTERVAL => now;

        // Only export if we have data
        if(onset_times.size() > 0) {
            exportOnsets();
        }
    }
}

// === MAIN PROGRAM ===
spork ~ onsetDetectionLoop();
spork ~ autoExportLoop();

// Wait for program to run
while(true) {
    1::second => now;
}
