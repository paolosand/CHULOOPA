//---------------------------------------------------------------------
// name: drum_sample_recorder.ck
// desc: Interactive beatbox sample recorder with real-time labeling
//       Designed for collecting training data for drum classifier
//
// Features:
//   - Press keys to label next sample (K=kick, S=snare, H=hat)
//   - Records short clips when onset detected
//   - Auto-saves with labels and timestamps
//   - Exports onset features to CSV for Python training
//
// Usage:
//   chuck src/drum_sample_recorder.ck
//   Press K, S, or H to set label, then beatbox
//   Press E to export all data, Q to quit
//---------------------------------------------------------------------

// === CONFIGURATION ===
512 => int FRAME_SIZE;
FRAME_SIZE/4 => int HOP_SIZE;
HOP_SIZE::samp => dur HOP;

// Onset detection (adjusted to prevent double-triggering)
1.5 => float ONSET_THRESHOLD_MULTIPLIER;
0.01 => float MIN_ONSET_STRENGTH;
150::ms => dur MIN_ONSET_INTERVAL;  // Increased from 100ms to prevent double-triggers

// Recording parameters
200::ms => dur SAMPLE_WINDOW;  // Record 200ms around each onset
50::ms => dur PRE_ONSET_BUFFER;  // Capture 50ms before onset

// Data storage paths
"beatbox_samples/" => string SAMPLE_DIR;
"training_data/" => string DATA_DIR;

// === CHUGL VISUALIZATION SETUP ===
GG.scene() @=> GScene @ scene;

// Camera setup - fixed position for good viewing without zoom
GCamera camera --> scene;
GG.scene().camera(camera);
camera.posZ(8.0);

// === LIGHTING ===
GDirLight main_light --> scene;
main_light.intensity(1.2);
main_light.rotX(-30 * Math.PI / 180.0);

GDirLight rim_light --> scene;
rim_light.intensity(0.6);
rim_light.rotY(180 * Math.PI / 180.0);
rim_light.rotX(30 * Math.PI / 180.0);

// === BLOOM EFFECT + ACES TONEMAP ===
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());
bloom_pass.intensity(0.4);
bloom_pass.radius(0.8);
bloom_pass.levels(6);
bloom_pass.threshold(0.3);

// ACES tonemap for CRT old TV effect
output_pass.tonemap(4);  // 4 = ACES
output_pass.exposure(0.5);

// === DRUM GEOMETRIES (Horizontal Row Layout) ===
0.6 => float BASE_SCALE;

// Kick (Left) - Cube (6 faces)
GMesh kick_geo(new CubeGeometry, new PhongMaterial) --> scene;
kick_geo.posX(-2.0);
kick_geo.posY(0.0);
kick_geo.sca(BASE_SCALE * 0.5);  // Start at 50% scale
kick_geo.mat() $ PhongMaterial @=> PhongMaterial @ kick_mat;
kick_mat.color(@(0.3, 0.3, 0.4));  // Dim blue-gray

// Snare (Center) - Octahedron (8 faces)
GMesh snare_geo(new PolyhedronGeometry(PolyhedronGeometry.OCTAHEDRON), new PhongMaterial) --> scene;
snare_geo.posX(0.0);
snare_geo.posY(0.0);
snare_geo.sca(BASE_SCALE * 0.5);
snare_geo.mat() $ PhongMaterial @=> PhongMaterial @ snare_mat;
snare_mat.color(@(0.3, 0.3, 0.4));

// Hat (Right) - Dodecahedron (12 faces)
GMesh hat_geo(new PolyhedronGeometry(PolyhedronGeometry.DODECAHEDRON), new PhongMaterial) --> scene;
hat_geo.posX(2.0);
hat_geo.posY(0.0);
hat_geo.sca(BASE_SCALE * 0.5);
hat_geo.mat() $ PhongMaterial @=> PhongMaterial @ hat_mat;
hat_mat.color(@(0.3, 0.3, 0.4));

// === LABEL TEXT (Below Geometries) ===
GText kick_label --> scene;
kick_label.text("KICK");
kick_label.posX(-2.0);
kick_label.posY(-1.2);
kick_label.sca(0.18);
kick_label.color(@(0.7, 0.7, 0.7));

GText snare_label --> scene;
snare_label.text("SNARE");
snare_label.posX(0.0);
snare_label.posY(-1.2);
snare_label.sca(0.18);
snare_label.color(@(0.7, 0.7, 0.7));

GText hat_label --> scene;
hat_label.text("HAT");
hat_label.posX(2.0);
hat_label.posY(-1.2);
hat_label.sca(0.18);
hat_label.color(@(0.7, 0.7, 0.7));

// === INSTRUCTION TEXT (Above Geometries) ===
GText instruction_text --> scene;
instruction_text.text("PRESS K (KICK) | S (SNARE) | H (HAT) TO BEGIN");
instruction_text.posX(0.0);
instruction_text.posY(2.5);
instruction_text.sca(0.22);
instruction_text.color(@(1.0, 1.0, 1.0));

// === AUDIO SETUP ===
adc => Gain input_gain => blackhole;
1.0 => input_gain.gain;

// Recording buffer (circular buffer for pre-onset capture)
adc => LiSa recorder => blackhole;
1::second => recorder.duration;  // 1 second circular buffer
1 => recorder.record;
1 => recorder.loop;
0 => recorder.play;

// === ANALYSIS CHAIN ===
adc => FFT fft =^ MFCC mfcc => blackhole;
adc => RMS rms => blackhole;
FRAME_SIZE => fft.size;
Windowing.hann(FRAME_SIZE) => fft.window;
13 => mfcc.numCoeffs;  // Standard 13 MFCC coefficients

// === STATE VARIABLES ===
float prev_spectrum[FRAME_SIZE/2];
float flux_history[50];
0 => int flux_history_idx;
0 => int flux_history_filled;
time last_onset_time;
now => last_onset_time;

// === LABELING STATE ===
"none" => string current_label;  // "kick", "snare", "hat", or "none"

// === VISUALIZATION STATE ===
// Impulse variables for pulse animations
0.0 => float kick_impulse;
0.0 => float snare_impulse;
0.0 => float hat_impulse;

// Current visual state (for smooth interpolation)
float current_scales[3];  // [kick, snare, hat]
0.5 => current_scales[0] => current_scales[1] => current_scales[2];  // Start at 50%

// Target colors for each drum type
vec3 kick_target_color;
@(0.9, 0.2, 0.2) => kick_target_color;  // Bright red

vec3 snare_target_color;
@(1.0, 0.6, 0.1) => snare_target_color;  // Bright orange

vec3 hat_target_color;
@(0.2, 0.8, 0.9) => hat_target_color;  // Bright cyan

vec3 dim_color;
@(0.3, 0.3, 0.4) => dim_color;  // Starting dim blue-gray

// Instruction state machine
0 => int instruction_state;  // 0=initial, 1=recording, 2=drum_complete, 3=almost_done, 4=all_complete
time state2_start_time;  // For 2-second "GREAT!" message duration
now => state2_start_time;

int label_counts[3];  // [kicks, snares, hats]
0 => label_counts[0] => label_counts[1] => label_counts[2];

// === TRAINING DATA STORAGE ===
// Each detected onset stores: label (as int), timestamp, features
int sample_labels[0];  // 0=kick, 1=snare, 2=hat
time sample_times[0];
float sample_features[0][0];  // Array of feature vectors

// Label string lookup
fun string getLabelString(int label_idx) {
    if(label_idx == 0) return "kick";
    else if(label_idx == 1) return "snare";
    else if(label_idx == 2) return "hat";
    else return "unknown";
}

// === AUDIO FEEDBACK ===
Impulse imp => ResonZ filt => ADSR env => Gain click_gain => dac;
0.3 => click_gain.gain;

// Different click sounds for different drum types
fun void playLabeledClick(string label) {
    if(label == "kick") {
        800.0 => filt.freq;
        100.0 => filt.Q;
    } else if(label == "snare") {
        2000.0 => filt.freq;
        50.0 => filt.Q;
    } else if(label == "hat") {
        4000.0 => filt.freq;
        30.0 => filt.Q;
    } else {
        2000.0 => filt.freq;
        50.0 => filt.Q;
    }

    env.set(1::ms, 20::ms, 0.0, 10::ms);
    1.0 => imp.next;
    env.keyOn();
    1::ms => now;
    env.keyOff();
}

// === VISUALIZATION HELPER FUNCTIONS ===

// Calculate logarithmic growth multiplier (0.5 to 1.0+)
fun float getScaleMultiplier(int samples) {
    return 0.5 + 0.5 * Math.log(samples + 1) / Math.log(11);
}

// Calculate brightness multiplier (0.3 to 1.0+)
fun float getBrightnessMultiplier(int samples) {
    return 0.3 + 0.7 * Math.log(samples + 1) / Math.log(11);
}

// Lerp between two vec3 colors
fun vec3 lerpColor(vec3 a, vec3 b, float t) {
    return @(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t
    );
}

// Get label index from string
fun int getLabelIdx(string label) {
    if(label == "kick") return 0;
    else if(label == "snare") return 1;
    else if(label == "hat") return 2;
    else return -1;
}

// Get total samples across all drums
fun int getTotalSamples() {
    return label_counts[0] + label_counts[1] + label_counts[2];
}

// === ONSET DETECTION FUNCTIONS (same as drum_onset_detector.ck) ===

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

// === FEATURE EXTRACTION ===

// Extract enhanced features for better drum classification
fun float[] extractOnsetFeatures(float flux) {
    float features[25];  // 12 spectral + 13 MFCC = 25 features

    // Get current FFT frame
    fft.upchuck() @=> UAnaBlob @ blob;

    // Calculate RMS energy from FFT magnitudes (ChucK's RMS unit doesn't work as expected)
    0.0 => float energy_from_fft;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float mag;
        mag * mag +=> energy_from_fft;  // Sum of squares
    }
    Math.sqrt(energy_from_fft / (FRAME_SIZE/2.0)) => float energy;

    // Frequency band energies (more granular than before)
    0.0 => float band1;  // 0-64 Hz (sub bass - kick fundamental)
    0.0 => float band2;  // 64-256 Hz (low - kick body)
    0.0 => float band3;  // 256-1024 Hz (low-mid - snare fundamental)
    0.0 => float band4;  // 1024-4096 Hz (mid-high - snare harmonics)
    0.0 => float band5;  // 4096+ Hz (high - hat/cymbal)

    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float mag;

        if(i < FRAME_SIZE/32) mag +=> band1;
        else if(i < FRAME_SIZE/8) mag +=> band2;
        else if(i < FRAME_SIZE/4) mag +=> band3;
        else if(i < FRAME_SIZE/2.5) mag +=> band4;
        else mag +=> band5;
    }

    // Spectral centroid (brightness/center of mass)
    0.0 => float centroid_num;
    0.0 => float centroid_den;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float mag;
        i * mag +=> centroid_num;
        mag +=> centroid_den;
    }
    centroid_num / (centroid_den + 0.0001) => float centroid;

    // Spectral rolloff (90% energy point - useful for brightness)
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

    // Spectral flatness (noisiness - high for hats, low for tonal kicks)
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

    // Energy ratios (discriminative!)
    band1 / (energy + 0.0001) => float low_ratio;
    band5 / (energy + 0.0001) => float high_ratio;
    (band3 + band4) / (energy + 0.0001) => float mid_ratio;

    // MFCC (Mel-Frequency Cepstral Coefficients - excellent for timbre!)
    mfcc.upchuck() @=> UAnaBlob @ mfcc_blob;

    // Store all features
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

    // Add 13 MFCC coefficients (features 12-24)
    for(0 => int i; i < 13; i++) {
        mfcc_blob.fval(i) => features[12 + i];
    }

    return features;
}

// === SAMPLE RECORDING ===

fun void recordSample(string label, time onset_time, float flux) {
    if(label == "none") {
        <<< "⚠️  No label set! Press K/S/H before beatboxing" >>>;
        return;
    }

    // Extract features
    extractOnsetFeatures(flux) @=> float features[];

    // Convert label to int
    0 => int label_idx;
    if(label == "kick") 0 => label_idx;
    else if(label == "snare") 1 => label_idx;
    else if(label == "hat") 2 => label_idx;

    // Store data
    sample_labels << label_idx;
    sample_times << onset_time;
    sample_features << features;

    // Update counts
    if(label == "kick") label_counts[0]++;
    else if(label == "snare") label_counts[1]++;
    else if(label == "hat") label_counts[2]++;

    // Visual feedback with feature values
    <<< "✓ Recorded:", label.upper(), "| Total - K:",
        label_counts[0], "S:", label_counts[1], "H:", label_counts[2] >>>;
    <<< "  Features: flux=" + features[0] + " energy=" + features[1] +
        " band1=" + features[2] + " band5=" + features[6] + " centroid=" + features[7] >>>;

    // Trigger visual pulse
    if(label == "kick") 1.0 => kick_impulse;
    else if(label == "snare") 1.0 => snare_impulse;
    else if(label == "hat") 1.0 => hat_impulse;
}

// === DATA EXPORT ===

fun void exportTrainingData() {
    if(sample_labels.size() == 0) {
        <<< "No samples to export!" >>>;
        return;
    }

    // Export to CSV with comma-separated values (save to src directory)
    me.dir() + "/training_samples.csv" => string filename;
    FileIO fout;
    fout.open(filename, FileIO.WRITE);

    if(!fout.good()) {
        <<< "ERROR: Could not open file for writing:", filename >>>;
        return;
    }

    // Write header (CSV format with commas)
    fout.write("label,timestamp,flux,energy,band1,band2,band3,band4,band5,centroid,rolloff,flatness,low_ratio,high_ratio,mfcc0,mfcc1,mfcc2,mfcc3,mfcc4,mfcc5,mfcc6,mfcc7,mfcc8,mfcc9,mfcc10,mfcc11,mfcc12\n");

    // Write each sample
    for(0 => int i; i < sample_labels.size(); i++) {
        getLabelString(sample_labels[i]) => string label;
        (sample_times[i] / second) => float timestamp;

        // Write label and timestamp
        fout.write(label + "," + timestamp);

        // Write all 25 features (comma-separated)
        for(0 => int j; j < 25; j++) {
            fout.write("," + sample_features[i][j]);
        }

        fout.write("\n");
    }

    fout.close();

    <<< "" >>>;
    <<< "╔═══════════════════════════════════════╗" >>>;
    <<< "║  TRAINING DATA EXPORTED              ║" >>>;
    <<< "╚═══════════════════════════════════════╝" >>>;
    <<< "File:", filename >>>;
    <<< "Total samples:", sample_labels.size() >>>;
    <<< "  - Kicks:", label_counts[0] >>>;
    <<< "  - Snares:", label_counts[1] >>>;
    <<< "  - Hats:", label_counts[2] >>>;
    <<< "" >>>;
    <<< "Next steps:" >>>;
    <<< "  1. Run: python train_classifier.py" >>>;
    <<< "  2. Or: chuck src/drum_classifier_realtime.ck (SVM)" >>>;
    <<< "" >>>;
}

// === ONSET DETECTION LOOP ===

fun void onsetDetectionLoop() {
    FRAME_SIZE::samp => now;

    while(true) {
        spectralFlux() => float flux;
        updateFluxHistory(flux);
        getAdaptiveThreshold() => float threshold;

        if(detectOnset(flux, threshold)) {
            // Record sample with current label
            recordSample(current_label, now, flux);
            spork ~ playLabeledClick(current_label);
        }

        HOP => now;
    }
}

// === KEYBOARD LISTENER ===

Hid hi;
HidMsg msg;

fun void keyboardListener() {
    // Try device 0 first, then device 1
    1 => int device;

    <<< "Command line args:", me.args() >>>;
    // get from command line if provided
    if(me.args() > 0) {
        Std.atoi(me.arg(0)) => device;
        <<< "Using keyboard device from command line:", device >>>;
    }
    <<< "Attempting to open keyboard device", device >>>;


    if(!hi.openKeyboard(device)) {
        <<< "Keyboard device 0 failed, trying device 1..." >>>;
        1 => device;
        if(!hi.openKeyboard(device)) {
            <<< "ERROR: Could not open keyboard" >>>;
            <<< "Try running: chuck --probe" >>>;
            <<< "to see available HID devices" >>>;
            return;
        }
    }

    <<< "Keyboard '" + hi.name() + "' ready (device", device + ")" >>>;

    while(true) {
        hi => now;

        while(hi.recv(msg)) {
            if(msg.isButtonDown()) {
                msg.ascii => int key;
                // Debug: show key codes
                // <<< "Key pressed:", key, "(ascii)", msg.which, "(code)" >>>;

                // K = Kick
                if(key == 107 || key == 75) {
                    "kick" => current_label;
                    <<< "🎯 LABEL SET: KICK (K)" >>>;
                }

                // S = Snare
                else if(key == 115 || key == 83) {
                    "snare" => current_label;
                    <<< "🎯 LABEL SET: SNARE (S)" >>>;
                }

                // H = Hat
                else if(key == 104 || key == 72) {
                    "hat" => current_label;
                    <<< "🎯 LABEL SET: HI-HAT (H)" >>>;
                }

                // N = None (disable recording)
                else if(key == 110 || key == 78) {
                    "none" => current_label;
                    <<< "⏸️  RECORDING DISABLED" >>>;
                }

                // E = Export
                else if(key == 101 || key == 69) {
                    <<< "" >>>;
                    <<< "Exporting training data..." >>>;
                    exportTrainingData();
                }

                // Q = Quit
                else if(key == 113 || key == 81) {
                    <<< "" >>>;
                    <<< "Exiting..." >>>;
                    exportTrainingData();
                    <<< "Goodbye!" >>>;
                    me.exit();
                }

                // R = Reset counts (debugging)
                else if(key == 114 || key == 82) {
                    0 => label_counts[0] => label_counts[1] => label_counts[2];
                    sample_labels.clear();
                    sample_times.clear();
                    sample_features.clear();
                    <<< "🔄 RESET - All samples cleared" >>>;
                }
            }
        }
    }
}

// === VISUALIZATION LOOP ===

fun void visualizationLoop() {
    while(true) {
        GG.nextFrame() => now;

        // === UPDATE GROWTH SYSTEM ===
        for(0 => int i; i < 3; i++) {
            // Calculate target scale based on sample count
            getScaleMultiplier(label_counts[i]) => float target_scale;

            // Smooth interpolation (exponential easing)
            current_scales[i] + (target_scale - current_scales[i]) * 0.1 => current_scales[i];

            // Calculate brightness and color
            getBrightnessMultiplier(label_counts[i]) => float brightness;

            vec3 target_color;
            if(i == 0) kick_target_color => target_color;
            else if(i == 1) snare_target_color => target_color;
            else hat_target_color => target_color;

            lerpColor(dim_color, target_color, brightness) @=> vec3 current_color;

            // Calculate emission (glow at higher sample counts)
            brightness * 0.8 => float emission_intensity;
            @(target_color.x * emission_intensity,
              target_color.y * emission_intensity,
              target_color.z * emission_intensity) @=> vec3 emission;

            // Apply to materials
            if(i == 0) {
                kick_mat.color(current_color);
                kick_mat.emission(emission);
            } else if(i == 1) {
                snare_mat.color(current_color);
                snare_mat.emission(emission);
            } else {
                hat_mat.color(current_color);
                hat_mat.emission(emission);
            }
        }

        // === APPLY PULSE DEFORMATIONS ===

        // Kick - Radial expansion
        BASE_SCALE * current_scales[0] * (1.0 + kick_impulse * 0.4) => float kick_scale;
        kick_geo.sca(kick_scale);

        // Snare - Vertical compression
        BASE_SCALE * current_scales[1] => float snare_base;
        snare_geo.scaX(snare_base * (1.0 + snare_impulse * 0.3));
        snare_geo.scaZ(snare_base * (1.0 + snare_impulse * 0.3));
        snare_geo.scaY(snare_base * (1.0 - snare_impulse * 0.4));

        // Hat - Asymmetric wobble
        BASE_SCALE * current_scales[2] => float hat_base;
        hat_geo.scaX(hat_base * (1.0 + hat_impulse * 0.2));
        hat_geo.scaY(hat_base * (1.0 + hat_impulse * 0.15));
        hat_geo.scaZ(hat_base * (1.0 - hat_impulse * 0.3));

        // Decay impulses (exponential decay ~200ms)
        kick_impulse * 0.92 => kick_impulse;
        snare_impulse * 0.92 => snare_impulse;
        hat_impulse * 0.92 => hat_impulse;

        // === UPDATE LABEL TEXT COLORS (Active vs Inactive) ===
        if(current_label == "kick") {
            kick_label.color(@(1.0, 1.0, 1.0));
            kick_label.sca(0.20);
        } else {
            kick_label.color(@(0.7, 0.7, 0.7));
            kick_label.sca(0.18);
        }

        if(current_label == "snare") {
            snare_label.color(@(1.0, 1.0, 1.0));
            snare_label.sca(0.20);
        } else {
            snare_label.color(@(0.7, 0.7, 0.7));
            snare_label.sca(0.18);
        }

        if(current_label == "hat") {
            hat_label.color(@(1.0, 1.0, 1.0));
            hat_label.sca(0.20);
        } else {
            hat_label.color(@(0.7, 0.7, 0.7));
            hat_label.sca(0.18);
        }

        // === UPDATE INSTRUCTION TEXT (State Machine) ===

        // Determine current state
        if(label_counts[0] >= 10 && label_counts[1] >= 10 && label_counts[2] >= 10) {
            // State 4: All complete
            if(instruction_state != 4) {
                4 => instruction_state;
                instruction_text.text("TRAINING COMPLETE! PRESS Q TO EXPORT (TOTAL: " + getTotalSamples() + ")");
                instruction_text.color(@(0.5, 1.5, 0.5));
            }
            // Large pulsing scale
            0.24 + 0.04 * Math.sin((now / second) * Math.PI * 2.0) => float pulse_scale;
            instruction_text.sca(pulse_scale);

        } else if(current_label != "none") {
            getLabelIdx(current_label) => int current_idx;

            if(label_counts[current_idx] >= 10) {
                // State 2: Drum complete (show for 2 seconds)
                if(instruction_state != 2) {
                    2 => instruction_state;
                    now => state2_start_time;

                    // Determine next drum
                    if(label_counts[0] < 10) {
                        instruction_text.text("GREAT! PRESS K FOR KICKS");
                    } else if(label_counts[1] < 10) {
                        instruction_text.text("EXCELLENT! PRESS S FOR SNARES");
                    } else if(label_counts[2] < 10) {
                        instruction_text.text("PERFECT! PRESS H FOR HI-HATS");
                    } else {
                        instruction_text.text("PERFECT! PRESS Q TO EXPORT");
                    }

                    instruction_text.color(@(0.3, 1.0, 0.3));
                    instruction_text.sca(0.22);
                }

                // After 2 seconds, return to state 0
                if(now - state2_start_time > 2::second) {
                    0 => instruction_state;
                }

            } else {
                // State 1: Active recording
                if(instruction_state != 1) {
                    1 => instruction_state;
                }

                // Update text with count
                if(current_label == "kick") {
                    instruction_text.text("BEATBOX KICKS NOW! (" + label_counts[0] + "/10)");
                    instruction_text.color(@(0.9, 0.2, 0.2));  // Red
                } else if(current_label == "snare") {
                    instruction_text.text("BEATBOX SNARES NOW! (" + label_counts[1] + "/10)");
                    instruction_text.color(@(1.0, 0.6, 0.1));  // Orange
                } else if(current_label == "hat") {
                    instruction_text.text("BEATBOX HI-HATS NOW! (" + label_counts[2] + "/10)");
                    instruction_text.color(@(0.2, 0.8, 0.9));  // Cyan
                }

                // Gentle pulsing scale
                0.22 + 0.01 * Math.sin((now / second) * Math.PI * 2.0) => float pulse_scale;
                instruction_text.sca(pulse_scale);
            }

        } else {
            // State 0: Initial or between drums
            if(instruction_state != 0) {
                0 => instruction_state;
                instruction_text.text("PRESS K (KICK) | S (SNARE) | H (HAT) TO BEGIN");
                instruction_text.color(@(1.0, 1.0, 1.0));
                instruction_text.sca(0.22);
            }
        }

        // Slow rotation for visual interest (optional)
        kick_geo.rotY((now / second) * 0.3);
        snare_geo.rotY((now / second) * 0.3);
        hat_geo.rotY((now / second) * 0.3);
    }
}

// === MAIN PROGRAM ===

<<< "" >>>;
<<< "╔═══════════════════════════════════════════════════╗" >>>;
<<< "║  DRUM SAMPLE RECORDER - Training Data Collection ║" >>>;
<<< "╚═══════════════════════════════════════════════════╝" >>>;
<<< "" >>>;
<<< "CONTROLS:" >>>;
<<< "  K = Set label to KICK" >>>;
<<< "  S = Set label to SNARE" >>>;
<<< "  H = Set label to HI-HAT" >>>;
<<< "  N = Disable recording (none)" >>>;
<<< "  E = Export training data" >>>;
<<< "  R = Reset all samples" >>>;
<<< "  Q = Quit and export" >>>;
<<< "" >>>;
<<< "WORKFLOW:" >>>;
<<< "  1. Press K (for kick)" >>>;
<<< "  2. Beatbox kick sounds - each onset auto-records" >>>;
<<< "  3. Press S (for snare)" >>>;
<<< "  4. Beatbox snare sounds" >>>;
<<< "  5. Press H (for hi-hat)" >>>;
<<< "  6. Beatbox hat sounds" >>>;
<<< "  7. Press E to export CSV" >>>;
<<< "" >>>;
<<< "TARGET: 20+ samples per drum type (60+ total)" >>>;
<<< "" >>>;
<<< "Starting in 3 seconds..." >>>;
<<< "" >>>;

3::second => now;

<<< "READY! Press K/S/H to start labeling..." >>>;
<<< "" >>>;

spork ~ visualizationLoop();
spork ~ onsetDetectionLoop();
spork ~ keyboardListener();

while(true) {
    1::second => now;
}
