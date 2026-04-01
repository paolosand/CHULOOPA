//---------------------------------------------------------------------
// name: drum_feature_diagnostic.ck
// desc: Diagnostic tool to test feature extraction in real-time
//       Shows live feature values to verify RMS, band energies, etc.
//
// Usage:
//   chuck src/drum_feature_diagnostic.ck
//   Make beatbox sounds and watch the feature readouts
//---------------------------------------------------------------------

// === CONFIGURATION ===
512 => int FRAME_SIZE;
FRAME_SIZE/4 => int HOP_SIZE;
HOP_SIZE::samp => dur HOP;

// === AUDIO SETUP ===
adc => FFT fft =^ MFCC mfcc => blackhole;
adc => RMS rms => blackhole;

FRAME_SIZE => fft.size;
Windowing.hann(FRAME_SIZE) => fft.window;
13 => mfcc.numCoeffs;

// === ONSET DETECTION (from drum_onset_detector.ck) ===
1.5 => float ONSET_THRESHOLD_MULTIPLIER;
0.01 => float MIN_ONSET_STRENGTH;
150::ms => dur MIN_ONSET_INTERVAL;

float prev_spectrum[FRAME_SIZE/2];
float flux_history[50];
0 => int flux_history_idx;
0 => int flux_history_filled;
time last_onset_time;
now => last_onset_time;

fun float spectralFlux() {
    fft.upchuck() @=> UAnaBlob @ blob;
    0.0 => float flux;

    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float current_mag;
        Math.max(0.0, current_mag - prev_spectrum[i]) => float diff;
        diff +=> flux;
        current_mag => prev_spectrum[i];
    }

    return flux;
}

fun void updateFluxHistory(float flux) {
    flux => flux_history[flux_history_idx];
    (flux_history_idx + 1) % flux_history.size() => flux_history_idx;

    if(!flux_history_filled && flux_history_idx == 0) {
        1 => flux_history_filled;
    }
}

fun float getAdaptiveThreshold() {
    if(!flux_history_filled && flux_history_idx < 10) {
        return MIN_ONSET_STRENGTH * 2.0;
    }

    0.0 => float mean;
    flux_history.size() => int count;
    if(!flux_history_filled) {
        flux_history_idx => count;
    }

    for(0 => int i; i < count; i++) {
        flux_history[i] +=> mean;
    }
    mean / count => mean;

    return mean * ONSET_THRESHOLD_MULTIPLIER;
}

fun int detectOnset(float flux, float threshold) {
    if(flux < threshold) return 0;
    if(flux < MIN_ONSET_STRENGTH) return 0;

    now - last_onset_time => dur time_since_last;
    if(time_since_last < MIN_ONSET_INTERVAL) return 0;

    now => last_onset_time;
    return 1;
}

// === FEATURE EXTRACTION (same as recorder) ===
fun void analyzeFeatures() {
    // Get FFT
    fft.upchuck() @=> UAnaBlob @ blob;

    // Calculate RMS energy from FFT magnitudes (since ChucK RMS doesn't work as expected)
    0.0 => float energy_from_fft;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float mag;
        mag * mag +=> energy_from_fft;  // Sum of squares
    }
    Math.sqrt(energy_from_fft / (FRAME_SIZE/2.0)) => float energy;

    // Band energies
    0.0 => float band1;  // 0-64 Hz (sub bass)
    0.0 => float band2;  // 64-256 Hz (low)
    0.0 => float band3;  // 256-1024 Hz (low-mid)
    0.0 => float band4;  // 1024-4096 Hz (mid-high)
    0.0 => float band5;  // 4096+ Hz (high)

    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float mag;

        if(i < FRAME_SIZE/32) mag +=> band1;
        else if(i < FRAME_SIZE/8) mag +=> band2;
        else if(i < FRAME_SIZE/4) mag +=> band3;
        else if(i < FRAME_SIZE/2.5) mag +=> band4;
        else mag +=> band5;
    }

    // Spectral centroid
    0.0 => float centroid_num;
    0.0 => float centroid_den;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float mag;
        i * mag +=> centroid_num;
        mag +=> centroid_den;
    }
    centroid_num / (centroid_den + 0.0001) => float centroid;

    // Spectral flatness (noisiness)
    0.0 => float geometric_mean;
    0.0 => float arithmetic_mean;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float mag;
        Math.log(mag + 0.0001) +=> geometric_mean;
        mag +=> arithmetic_mean;
    }
    geometric_mean / (FRAME_SIZE/2.0) => geometric_mean;
    Math.exp(geometric_mean) => geometric_mean;
    arithmetic_mean / (FRAME_SIZE/2.0) => arithmetic_mean;
    geometric_mean / (arithmetic_mean + 0.0001) => float flatness;

    // Calculate total band energy
    band1 + band2 + band3 + band4 + band5 => float total_band_energy;

    // Get all 13 MFCC coefficients
    mfcc.upchuck() @=> UAnaBlob @ mfcc_blob;
    float mfccs[13];
    for(0 => int i; i < 13; i++) {
        mfcc_blob.fval(i) => mfccs[i];
    }

    // Print features (called only on detected onsets)
    <<< "──────────────────────────────────────────────" >>>;
    <<< "RMS Energy (FFT):", energy >>>;
    <<< "Band1 (sub):    ", band1, "(kick should be HIGH here)" >>>;
    <<< "Band2 (low):    ", band2, "(kick should be HIGH here)" >>>;
    <<< "Band3 (low-mid):", band3, "(snare should be HIGH here)" >>>;
    <<< "Band4 (mid-hi): ", band4, "(snare should be HIGH here)" >>>;
    <<< "Band5 (high):   ", band5, "(hat should be HIGH here)" >>>;
    <<< "Total Band:     ", total_band_energy >>>;
    <<< "Centroid:       ", centroid >>>;
    <<< "Flatness:       ", flatness, "(high=noisy, low=tonal)" >>>;
    <<< "MFCCs: [" + mfccs[0] + ", " + mfccs[1] + ", " + mfccs[2] + ", " + mfccs[3] + ", " +
        mfccs[4] + ", " + mfccs[5] + ", " + mfccs[6] + ", " + mfccs[7] + ", " +
        mfccs[8] + ", " + mfccs[9] + ", " + mfccs[10] + ", " + mfccs[11] + ", " + mfccs[12] + "]" >>>;
    <<< "" >>>;

    // Diagnostic hints (adjusted for laptop mic sensitivity)
    if(energy < 0.0001) {
        <<< "⚠️  WARNING: RMS energy is extremely low!" >>>;
        <<< "   Check microphone input level or get closer to mic" >>>;
    } else if(energy < 0.0005) {
        <<< "⚠️  Energy is low (laptop mic?)" >>>;
        <<< "   Values: 0.0001-0.001 = laptop mic, 0.001-0.01 = normal mic" >>>;
    } else if(energy < 0.005) {
        <<< "✅ Energy is GOOD for laptop mic (0.0005-0.005)" >>>;
    } else {
        <<< "✅ Energy is EXCELLENT (proper microphone level)" >>>;
    }

    if(band1 + band2 > band3 + band4 + band5) {
        <<< "💡 Hint: Looks like a KICK (low frequencies dominant)" >>>;
    } else if(band5 > band1 + band2) {
        <<< "💡 Hint: Looks like a HAT (high frequencies dominant)" >>>;
    } else if(band3 + band4 > band1 + band2 + band5) {
        <<< "💡 Hint: Looks like a SNARE (mid frequencies dominant)" >>>;
    }
}

// === MAIN LOOP ===

<<< "" >>>;
<<< "╔═══════════════════════════════════════════════════╗" >>>;
<<< "║  DRUM FEATURE DIAGNOSTIC - Real-time Analysis    ║" >>>;
<<< "╚═══════════════════════════════════════════════════╝" >>>;
<<< "" >>>;
<<< "Instructions:" >>>;
<<< "  1. Make beatbox sounds:" >>>;
<<< "     - BOOM (kick) - should show high band1/band2" >>>;
<<< "     - PSH (snare) - should show high band3/band4" >>>;
<<< "     - tss (hat) - should show high band5" >>>;
<<< "  2. Watch the feature readouts (ONLY shows when onset detected)" >>>;
<<< "  3. Press Ctrl+C to exit" >>>;
<<< "" >>>;
<<< "Listening for onsets... (make some sounds!)" >>>;
<<< "" >>>;

// Warm up the onset detector
FRAME_SIZE::samp => now;

while(true) {
    // Calculate spectral flux
    spectralFlux() => float flux;
    updateFluxHistory(flux);
    getAdaptiveThreshold() => float threshold;

    // Only analyze features when onset detected
    if(detectOnset(flux, threshold)) {
        <<< "🎵 ONSET DETECTED!" >>>;
        analyzeFeatures();
    }

    HOP => now;
}
