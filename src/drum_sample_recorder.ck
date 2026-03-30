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
//   Press E to export training data, ESC to close window
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

// === CONTROLS OVERLAY (Upper-right corner, small) ===
GText ctrl_title --> scene;
ctrl_title.text("CONTROLS");
ctrl_title.posX(3.8);
ctrl_title.posY(3.2);
ctrl_title.posZ(0.1);
ctrl_title.sca(0.12);
ctrl_title.color(@(0.9, 0.9, 0.9));

GText ctrl_keys --> scene;
ctrl_keys.text("K / S / H  =  label drum type");
ctrl_keys.posX(3.8);
ctrl_keys.posY(2.95);
ctrl_keys.posZ(0.1);
ctrl_keys.sca(0.10);
ctrl_keys.color(@(0.7, 0.7, 0.7));

GText ctrl_pause --> scene;
ctrl_pause.text("N  =  pause recording");
ctrl_pause.posX(3.8);
ctrl_pause.posY(2.72);
ctrl_pause.posZ(0.1);
ctrl_pause.sca(0.10);
ctrl_pause.color(@(0.7, 0.7, 0.7));

GText ctrl_export --> scene;
ctrl_export.text("E  =  export training data");
ctrl_export.posX(3.8);
ctrl_export.posY(2.49);
ctrl_export.posZ(0.1);
ctrl_export.sca(0.10);
ctrl_export.color(@(0.7, 0.7, 0.7));

GText ctrl_close --> scene;
ctrl_close.text("ESC  =  close window");
ctrl_close.posX(3.8);
ctrl_close.posY(2.26);
ctrl_close.posZ(0.1);
ctrl_close.sca(0.10);
ctrl_close.color(@(0.7, 0.7, 0.7));

GText ctrl_test --> scene;
ctrl_test.text("P  =  live playback test");
ctrl_test.posX(3.8);
ctrl_test.posY(2.03);
ctrl_test.posZ(0.1);
ctrl_test.sca(0.10);
ctrl_test.color(@(0.7, 0.7, 0.7));

// === TEST MODE INDICATOR (center bottom) ===
GText test_mode_text --> scene;
test_mode_text.text("");
test_mode_text.posX(0.0);
test_mode_text.posY(-2.5);
test_mode_text.posZ(0.1);
test_mode_text.sca(0.20);
test_mode_text.color(@(0.2, 1.0, 0.5));

// === AUDIO SETUP ===
adc => Gain input_gain => blackhole;
1.0 => input_gain.gain;

// === DRUM SAMPLE PLAYBACK (for test mode) ===
SndBuf kick_snd => dac;
SndBuf snare_snd => dac;
SndBuf hat_snd => dac;

me.dir() + "/samples/kick.wav" => kick_snd.read;
me.dir() + "/samples/snare.wav" => snare_snd.read;
me.dir() + "/samples/hat.WAV" => hat_snd.read;

0 => kick_snd.loop => snare_snd.loop => hat_snd.loop;
// Park at end so they don't auto-play
kick_snd.samples() => kick_snd.pos;
snare_snd.samples() => snare_snd.pos;
hat_snd.samples() => hat_snd.pos;
0.8 => kick_snd.gain => snare_snd.gain => hat_snd.gain;

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
0 => int recording_complete;     // 1 after E/Q export — no more recording
0 => int playback_mode;          // 1 after P — onset → KNN classify → play drum sound

// === KNN CLASSIFIER (trained in-memory before playback) ===
KNN2 knn;
3 => int K_NEIGHBORS;

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

fun void playDrumSample(string label) {
    if(label == "kick") { 0 => kick_snd.pos; }
    else if(label == "snare") { 0 => snare_snd.pos; }
    else if(label == "hat") { 0 => hat_snd.pos; }
}

fun int trainKNN() {
    sample_labels.size() => int n;
    if(n == 0) {
        <<< "No samples to train on!" >>>;
        return 0;
    }

    float features[n][13];
    int labels[n];
    for(0 => int i; i < n; i++) {
        sample_labels[i] => labels[i];
        for(0 => int j; j < 13; j++) {
            sample_features[i][j] => features[i][j];
        }
    }

    [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0] @=> float weights[];
    knn.train(features, labels);
    knn.weigh(weights);

    <<< "KNN trained: K=" + K_NEIGHBORS + " samples=" + n +
        " (K=" + label_counts[0] + " S=" + label_counts[1] + " H=" + label_counts[2] + ")" >>>;
    return 1;
}

fun void classifyAndPlay(UAnaBlob @ mfcc_blob) {
    float query[13];
    for(0 => int i; i < 13; i++) {
        mfcc_blob.fval(i) => query[i];
    }

    float probs[3];
    knn.predict(query, K_NEIGHBORS, probs);

    0 => int best_class;
    probs[0] => float best_prob;
    for(1 => int i; i < 3; i++) {
        if(probs[i] > best_prob) { i => best_class; probs[i] => best_prob; }
    }

    if(best_class == 0) { playDrumSample("kick"); 1.0 => kick_impulse; }
    else if(best_class == 1) { playDrumSample("snare"); 1.0 => snare_impulse; }
    else { playDrumSample("hat"); 1.0 => hat_impulse; }
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

// Extract MFCC features for drum classification (MFCC-13 only)
// Note: mfcc.upchuck() propagates upstream and also upchucks fft
fun float[] extractOnsetFeatures() {
    float features[13];
    mfcc.upchuck() @=> UAnaBlob @ mfcc_blob;
    for(0 => int i; i < 13; i++) {
        mfcc_blob.fval(i) => features[i];
    }
    return features;
}

// === SAMPLE RECORDING ===

fun void recordSample(string label, time onset_time) {
    if(label == "none") {
        <<< "⚠️  No label set! Press K/S/H before beatboxing" >>>;
        return;
    }

    // Extract features
    extractOnsetFeatures() @=> float features[];

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
    <<< "  Features: mfcc0=" + features[0] + " mfcc1=" + features[1] +
        " mfcc2=" + features[2] + " mfcc3=" + features[3] + " mfcc4=" + features[4] >>>;

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
    fout.write("label,timestamp,mfcc0,mfcc1,mfcc2,mfcc3,mfcc4,mfcc5,mfcc6,mfcc7,mfcc8,mfcc9,mfcc10,mfcc11,mfcc12\n");

    // Write each sample
    for(0 => int i; i < sample_labels.size(); i++) {
        getLabelString(sample_labels[i]) => string label;
        (sample_times[i] / second) => float timestamp;

        // Write label and timestamp
        fout.write(label + "," + timestamp);

        // Write all 13 MFCC features (comma-separated)
        for(0 => int j; j < 13; j++) {
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
    <<< "  1. Run: chuck chuloopa_drums_v4.ck (trains KNN automatically)" >>>;
    <<< "  2. Training loads automatically when you run chuloopa_drums_v4.ck" >>>;
    <<< "" >>>;
}

// === ONSET DETECTION LOOP ===

fun void onsetDetectionLoop() {
    FRAME_SIZE::samp => now;

    while(true) {
        // In playback mode: upchuck MFCC first (propagates to FFT for flux caching)
        UAnaBlob @ mfcc_blob;
        if(playback_mode) {
            mfcc.upchuck() @=> mfcc_blob;
        }

        spectralFlux() => float flux;  // calls fft.upchuck() — returns cached if already upchucked
        updateFluxHistory(flux);
        getAdaptiveThreshold() => float threshold;

        if(detectOnset(flux, threshold)) {
            if(playback_mode) {
                // Live test: classify via KNN, play matching drum sound
                classifyAndPlay(mfcc_blob);
            } else if(!recording_complete && current_label != "none") {
                // Recording: store sample + click feedback
                recordSample(current_label, now);
                spork ~ playLabeledClick(current_label);
            }
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

                // E = Export + end recording
                else if(key == 101 || key == 69) {
                    exportTrainingData();
                    1 => recording_complete;
                    "none" => current_label;
                    <<< "Recording complete. Press P to start live playback test." >>>;
                }

                // Q = Export + end recording (same as E)
                else if(key == 113 || key == 81) {
                    exportTrainingData();
                    1 => recording_complete;
                    "none" => current_label;
                    <<< "Recording complete. Press P to start live playback test." >>>;
                }

                // P = Start live playback (KNN classify + play drum sounds)
                else if(key == 112 || key == 80) {
                    if(sample_labels.size() == 0) {
                        <<< "No samples recorded yet — record K/S/H first." >>>;
                    } else if(!playback_mode) {
                        if(trainKNN()) {
                            1 => playback_mode;
                            1 => recording_complete;
                            <<< "▶  LIVE PLAYBACK — beatbox freely, drums play automatically" >>>;
                        }
                    } else {
                        0 => playback_mode;
                        <<< "⏹  PLAYBACK STOPPED" >>>;
                    }
                }

                // R = Full reset — erase all samples, re-enable recording
                else if(key == 114 || key == 82) {
                    0 => label_counts[0] => label_counts[1] => label_counts[2];
                    sample_labels.clear();
                    sample_times.clear();
                    sample_features.clear();
                    0 => recording_complete;
                    0 => playback_mode;
                    "none" => current_label;
                    0 => instruction_state;
                    <<< "🔄 RESET — all samples cleared, recording re-enabled" >>>;
                    <<< "Press K / S / H to start recording again." >>>;
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

        // Playback/recording-complete states override the normal state machine
        if(playback_mode) {
            instruction_text.text("LIVE PLAYBACK — beatbox freely, drums play automatically");
            instruction_text.color(@(0.2, 1.0, 0.5));
            0.20 + 0.02 * Math.sin((now / second) * Math.PI * 2.0) => instruction_text.sca;
        } else if(recording_complete) {
            instruction_text.text("RECORDING COMPLETE — press P to test live playback");
            instruction_text.color(@(1.0, 0.8, 0.2));
            instruction_text.sca(0.20);

        // Determine current state
        } else if(label_counts[0] >= 10 && label_counts[1] >= 10 && label_counts[2] >= 10) {
            // State 4: All complete
            if(instruction_state != 4) {
                4 => instruction_state;
                instruction_text.text("TRAINING COMPLETE! PRESS E TO EXPORT (TOTAL: " + getTotalSamples() + ")");
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
                        instruction_text.text("PERFECT! PRESS E TO EXPORT");
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

        // === PLAYBACK MODE INDICATOR ===
        if(playback_mode) {
            0.18 + 0.03 * Math.sin((now / second) * Math.PI * 3.0) => float pb_pulse;
            test_mode_text.sca(pb_pulse);
            test_mode_text.text("LIVE PLAYBACK  —  beatbox freely");
            test_mode_text.color(@(0.2, 1.0, 0.5));
        } else if(recording_complete) {
            test_mode_text.sca(0.16);
            test_mode_text.text("RECORDING DONE  —  press P to test live");
            test_mode_text.color(@(1.0, 0.8, 0.2));
        } else {
            test_mode_text.text("");
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
<<< "  E / Q = Export training data (ends recording)" >>>;
<<< "  P = Live playback test (KNN classify → play drum sounds)" >>>;
<<< "  R = Full reset (erase samples, re-enable recording)" >>>;
<<< "  ESC = Close window" >>>;
<<< "" >>>;
<<< "WORKFLOW:" >>>;
<<< "  1. Press K — beatbox kicks (10+ samples)" >>>;
<<< "  2. Press S — beatbox snares (10+ samples)" >>>;
<<< "  3. Press H — beatbox hi-hats (10+ samples)" >>>;
<<< "  4. Press E to export, then P to test live playback" >>>;
<<< "  5. Press R to re-record if results are unsatisfactory" >>>;
<<< "" >>>;
<<< "TARGET: 10+ per drum type minimum (30+ total)" >>>;
<<< "         20+ per drum type recommended for best accuracy" >>>;
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
