//---------------------------------------------------------------------
// name: drum_classifier_realtime.ck
// desc: Real-time drum classification using ChucK's built-in SVM
//       Trains SVM from training_samples.csv, then classifies live input
//
// Features:
//   - Loads training data from CSV
//   - Trains SVM classifier in ChucK (no Python needed!)
//   - Real-time onset detection + classification
//   - Audio + visual feedback for classified drums
//
// Usage:
//   chuck src/drum_classifier_realtime.ck
//   Beatbox and see real-time classification!
//---------------------------------------------------------------------

// === CONFIGURATION ===
512 => int FRAME_SIZE;
FRAME_SIZE/4 => int HOP_SIZE;
HOP_SIZE::samp => dur HOP;

// Onset detection (same as recorder)
1.5 => float ONSET_THRESHOLD_MULTIPLIER;
0.01 => float MIN_ONSET_STRENGTH;
100::ms => dur MIN_ONSET_INTERVAL;

// === AUDIO SETUP ===
adc => Gain input_gain => blackhole;
1.0 => input_gain.gain;

// === ANALYSIS CHAIN ===
adc => FFT fft => blackhole;
adc => RMS rms => blackhole;
adc => MFCC mfcc => blackhole;
FRAME_SIZE => fft.size;
Windowing.hann(FRAME_SIZE) => fft.window;
FRAME_SIZE => mfcc.fftSize;
13 => mfcc.numCoeffs;

// === SVM CLASSIFIER ===
SVM svm;

// SVM parameters (set after creation)
// Note: ChucK's SVM uses default RBF kernel
// Parameters are set via train() method

int model_trained;
0 => model_trained;

// === STATE VARIABLES ===
float prev_spectrum[FRAME_SIZE/2];
float flux_history[50];
0 => int flux_history_idx;
0 => int flux_history_filled;
time last_onset_time;
now => last_onset_time;

// === CLASSIFICATION STATS ===
int class_counts[3];  // [kicks, snares, hats]
0 => class_counts[0] => class_counts[1] => class_counts[2];

// === AUDIO FEEDBACK (different sounds per class) ===
Impulse imp[3];
ResonZ filt[3];
ADSR env[3];
Gain class_gain[3];

for(0 => int i; i < 3; i++) {
    imp[i] => filt[i] => env[i] => class_gain[i] => dac;
    0.4 => class_gain[i].gain;
    env[i].set(1::ms, 30::ms, 0.0, 10::ms);
}

// Kick - low frequency
800.0 => filt[0].freq;
100.0 => filt[0].Q;

// Snare - mid frequency
2000.0 => filt[1].freq;
50.0 => filt[1].Q;

// Hat - high frequency
4000.0 => filt[2].freq;
30.0 => filt[2].Q;

fun void playClassClick(int class_idx) {
    1.0 => imp[class_idx].next;
    env[class_idx].keyOn();
    1::ms => now;
    env[class_idx].keyOff();
}

// === FEATURE EXTRACTION ===

fun float[] extractOnsetFeatures(float flux) {
    float features[25];  // 12 spectral + 13 MFCC

    fft.upchuck() @=> UAnaBlob @ blob;
    rms.upchuck();
    mfcc.upchuck() @=> UAnaBlob @ mfcc_blob;

    rms.fval(0) => float energy;

    // Frequency bands
    0.0 => float band1 => float band2 => float band3 => float band4 => float band5;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float mag;
        if(i < FRAME_SIZE/32) mag +=> band1;
        else if(i < FRAME_SIZE/8) mag +=> band2;
        else if(i < FRAME_SIZE/4) mag +=> band3;
        else if(i < FRAME_SIZE/2.5) mag +=> band4;
        else mag +=> band5;
    }

    // Spectral centroid
    0.0 => float centroid_num => float centroid_den;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float mag;
        i * mag +=> centroid_num;
        mag +=> centroid_den;
    }
    centroid_num / (centroid_den + 0.0001) => float centroid;

    // Spectral rolloff
    0.0 => float total_energy;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) +=> total_energy;
    }
    total_energy * 0.9 => float rolloff_threshold;
    0.0 => float running_sum;
    0 => int rolloff;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) +=> running_sum;
        if(running_sum >= rolloff_threshold && rolloff == 0) {
            i => rolloff;
        }
    }

    // Spectral flatness
    0.0 => float geometric_mean => float arithmetic_mean;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float mag;
        Math.log(mag + 0.0001) +=> geometric_mean;
        mag +=> arithmetic_mean;
    }
    geometric_mean / (FRAME_SIZE/2.0) => geometric_mean;
    Math.exp(geometric_mean) => geometric_mean;
    arithmetic_mean / (FRAME_SIZE/2.0) => arithmetic_mean;
    geometric_mean / (arithmetic_mean + 0.0001) => float flatness;

    // Energy ratios
    band1 / (energy + 0.0001) => float low_ratio;
    band5 / (energy + 0.0001) => float high_ratio;

    // Pack features
    flux => features[0];
    energy => features[1];
    band1 => features[2];
    band2 => features[3];
    band3 => features[4];
    band4 => features[5];
    band5 => features[6];
    centroid => features[7];
    rolloff => features[8];
    flatness => features[9];
    low_ratio => features[10];
    high_ratio => features[11];

    // Add MFCCs
    for(0 => int i; i < 13; i++) {
        mfcc_blob.fval(i) => features[12 + i];
    }

    return features;
}

// === ONSET DETECTION FUNCTIONS ===

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

// === SVM TRAINING FROM TXT ===

fun int trainSVMFromTXT(string filename) {
    <<< "" >>>;
    <<< "╔═══════════════════════════════════════╗" >>>;
    <<< "║  TRAINING SVM FROM TXT               ║" >>>;
    <<< "╚═══════════════════════════════════════╝" >>>;
    <<< "" >>>;

    FileIO fin;
    fin.open(filename, FileIO.READ);

    if(!fin.good()) {
        <<< "ERROR: Could not open training file:", filename >>>;
        return 0;
    }

    // Skip header
    fin.readLine() => string header;

    // Count samples first
    0 => int num_samples;
    while(fin.more()) {
        fin.readLine();
        num_samples++;
    }

    <<< "Found", num_samples, "training samples" >>>;

    // Reset file
    fin.close();
    fin.open(filename, FileIO.READ);
    fin.readLine();  // Skip header again

    // Allocate arrays
    float training_data[num_samples][25];  // 25 features
    float training_labels[num_samples][1];  // Labels as float[][] for SVM

    // Read data
    0 => int sample_idx;
    int label_counts_train[3];
    0 => label_counts_train[0] => label_counts_train[1] => label_counts_train[2];

    while(fin.more()) {
        fin.readLine() => string line;
        if(line.length() == 0) continue;

        // Parse space-delimited: label timestamp + 25 features
        StringTokenizer tok;
        tok.set(line);

        // Get label
        tok.next() => string label;
        0.0 => float label_val;
        if(label == "kick") {
            0.0 => label_val;
            label_counts_train[0]++;
        }
        else if(label == "snare") {
            1.0 => label_val;
            label_counts_train[1]++;
        }
        else if(label == "hat") {
            2.0 => label_val;
            label_counts_train[2]++;
        }

        label_val => training_labels[sample_idx][0];

        // Skip timestamp
        tok.next();

        // Read 25 features
        for(0 => int i; i < 25; i++) {
            Std.atof(tok.next()) => training_data[sample_idx][i];
        }

        sample_idx++;
    }

    fin.close();

    <<< "Training samples per class:" >>>;
    <<< "  Kicks:", label_counts_train[0] >>>;
    <<< "  Snares:", label_counts_train[1] >>>;
    <<< "  Hats:", label_counts_train[2] >>>;
    <<< "" >>>;

    // Train SVM
    <<< "Training SVM classifier..." >>>;

    svm.train(training_data, training_labels);

    <<< "✓ SVM training complete!" >>>;
    <<< "" >>>;

    return 1;
}

// === CLASSIFICATION ===

fun void classifyAndRespond(float flux) {
    if(!model_trained) return;

    // Extract features
    extractOnsetFeatures(flux) @=> float features[];

    // Classify (SVM.predict expects features as array and returns result in output array)
    float result[1];
    svm.predict(features, result);

    // Convert to int and round
    Math.round(result[0]) $ int => int predicted_class;

    // Clamp to valid range
    if(predicted_class < 0) 0 => predicted_class;
    if(predicted_class > 2) 2 => predicted_class;

    // Update stats
    class_counts[predicted_class]++;

    // Get label name
    "UNKNOWN" => string class_name;
    if(predicted_class == 0) "KICK" => class_name;
    else if(predicted_class == 1) "SNARE" => class_name;
    else if(predicted_class == 2) "HAT" => class_name;

    // Visual feedback
    <<< "🥁", class_name, "| Total - K:", class_counts[0],
        "S:", class_counts[1], "H:", class_counts[2] >>>;

    // Audio feedback
    spork ~ playClassClick(predicted_class);
}

// === ONSET DETECTION + CLASSIFICATION LOOP ===

fun void onsetClassificationLoop() {
    FRAME_SIZE::samp => now;

    <<< "Starting real-time classification..." >>>;
    <<< "Beatbox to test the classifier!" >>>;
    <<< "" >>>;

    while(true) {
        spectralFlux() => float flux;
        updateFluxHistory(flux);
        getAdaptiveThreshold() => float threshold;

        if(detectOnset(flux, threshold)) {
            classifyAndRespond(flux);
        }

        HOP => now;
    }
}

// === MAIN PROGRAM ===

<<< "" >>>;
<<< "╔═══════════════════════════════════════════════════╗" >>>;
<<< "║  REAL-TIME DRUM CLASSIFIER (ChucK SVM)          ║" >>>;
<<< "╚═══════════════════════════════════════════════════╝" >>>;
<<< "" >>>;

// Train SVM from TXT
if(trainSVMFromTXT("training_samples.txt")) {
    1 => model_trained;

    <<< "╔═══════════════════════════════════════╗" >>>;
    <<< "║  READY FOR REAL-TIME CLASSIFICATION  ║" >>>;
    <<< "╚═══════════════════════════════════════╝" >>>;
    <<< "" >>>;
    <<< "Audio feedback:" >>>;
    <<< "  KICK  = Low click (800 Hz)" >>>;
    <<< "  SNARE = Mid click (2000 Hz)" >>>;
    <<< "  HAT   = High click (4000 Hz)" >>>;
    <<< "" >>>;

    // Start classification
    spork ~ onsetClassificationLoop();

    // Run forever
    while(true) {
        1::second => now;
    }
} else {
    <<< "Failed to load training data!" >>>;
    <<< "Make sure training_samples.txt exists." >>>;
    <<< "Run drum_sample_recorder.ck first to collect data." >>>;
}
