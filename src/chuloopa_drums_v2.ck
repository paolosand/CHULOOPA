//---------------------------------------------------------------------
// name: chuloopa_drums_v2.ck
// desc: CHULOOPA - Drum-based looper with real-time beatbox classification
//       Multi-track looper that transcribes beatbox to drum patterns
//       V2: Adds ability to load and play drum patterns from txt files
//
// Architecture:
//   1. Record audio loops (with master sync to prevent drift)
//   2. Real-time onset detection + classification → symbolic drum data
//   3. AUTO-EXPORT: Symbolic data saved to track_N_drums.txt files
//   4. DRUM PLAYBACK: Transcribed drums played as samples
//   5. LOAD FROM FILE: Swap buffer playback with saved txt patterns
//   6. Visual feedback (ChuGL) reacts to drum hits
//
// MIDI Mapping (Single Track):
//   RECORDING:
//     C1 (36):                Press & hold to record track
//                             Release to stop recording (auto-exports)
//
//   CLEARING:
//     C#1 (37):               Clear track and reset variation state
//
//   VARIATION CONTROL:
//     D1 (38):                Toggle variation mode ON/OFF (queued at loop boundary)
//     D#1 (39):               Generate variation with current spice level
//
//   SPICE CONTROL:
//     CC 18:                  Spice level knob (0-127 -> 0.0-1.0)
//                             Adjusts creativity of AI variations
//
// Usage:
//   chuck src/chuloopa_drums_v2.ck
//---------------------------------------------------------------------

// === VARIATION MODE CONFIGURATION ===
0.5 => float DEFAULT_SPICE_LEVEL;    // Default spice level (0.0-1.0)

// === MIDI CONFIGURATION (SINGLE TRACK FOCUS) ===
36 => int NOTE_RECORD_TRACK;     // C1 - Record track (press & hold)
37 => int NOTE_CLEAR_TRACK;      // C#1 - Clear track
38 => int NOTE_TOGGLE_VARIATION; // D1 - Toggle variation mode ON/OFF
39 => int NOTE_REGENERATE;       // D#1 - Regenerate variations with current spice

18 => int CC_SPICE_LEVEL;        // CC 18 - Spice level knob (0-127 -> 0.0-1.0)

0 => int MIDI_DEVICE;

// === OSC CONFIGURATION ===
5000 => int OSC_SEND_PORT;       // Send to Python on port 5000
5001 => int OSC_RECEIVE_PORT;    // Receive from Python on port 5001

// === CONFIGURATION ===
1 => int NUM_TRACKS;  // Single track focus for now
30::second => dur MAX_LOOP_DURATION;

// === VOLUME SETTINGS ===
0.0 => float AUDIO_LOOP_VOLUME;   // Original beatbox audio (DISABLED - drums only!)
0.8 => float DRUM_SAMPLE_VOLUME;  // Transcribed drum samples (0.0-1.0)

// === ONSET DETECTION PARAMETERS ===
512 => int FRAME_SIZE;
FRAME_SIZE/4 => int HOP_SIZE;
HOP_SIZE::samp => dur HOP;

1.5 => float ONSET_THRESHOLD_MULTIPLIER;
0.01 => float MIN_ONSET_STRENGTH;
150::ms => dur MIN_ONSET_INTERVAL;  // Debounce time between onsets

// === QUANTIZATION PARAMETERS ===
false => int ENABLE_QUANTIZATION;    // Enable/disable quantization
16 => int QUANTIZE_DIVISION;        // Quantize to 16th notes (4=quarter, 8=eighth, 16=sixteenth)
60.0 => float MIN_BPM;              // Valid BPM range
200.0 => float MAX_BPM;

// === MASTER LOOP SYNC SYSTEM ===
-1 => int master_track;
0::second => dur master_duration;
0 => int has_master;

// Valid multipliers for sync (most common musical ratios)
[0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0] @=> float valid_multipliers[];

// Find best multiplier to sync with master loop
fun dur findBestMultiplier(dur recorded_duration, dur master_duration) {
    1000000.0 => float best_error;
    1.0 => float best_multiplier;

    for(0 => int i; i < valid_multipliers.size(); i++) {
        valid_multipliers[i] => float mult;
        master_duration * mult => dur target;
        Math.fabs((recorded_duration - target) / second) => float error;

        if(error < best_error) {
            error => best_error;
            mult => best_multiplier;
        }
    }

    return master_duration * best_multiplier;
}

// Check if any loops exist
fun int anyLoopsExist() {
    for(0 => int i; i < NUM_TRACKS; i++) {
        if(has_loop[i]) return 1;
    }
    return 0;
}

// === QUANTIZATION SYSTEM ===

// Estimate BPM from inter-onset intervals
fun float estimateBPM(int track) {
    if(track_drum_timestamps[track].size() < 2) {
        return 120.0;  // Default BPM if not enough hits
    }

    // Calculate all inter-onset intervals
    float intervals[0];
    for(1 => int i; i < track_drum_timestamps[track].size(); i++) {
        track_drum_timestamps[track][i] - track_drum_timestamps[track][i-1] => float interval;
        if(interval > 0.1) {  // Ignore very short intervals (likely flams/doubles)
            intervals << interval;
        }
    }

    if(intervals.size() == 0) return 120.0;

    // Find median interval (more robust than mean)
    // Sort intervals
    for(0 => int i; i < intervals.size()-1; i++) {
        for(i+1 => int j; j < intervals.size(); j++) {
            if(intervals[j] < intervals[i]) {
                intervals[i] => float temp;
                intervals[j] => intervals[i];
                temp => intervals[j];
            }
        }
    }

    // Get median
    intervals[intervals.size() / 2] => float median_interval;

    // Convert to BPM (assuming the median interval represents one beat or subdivision)
    // Try different subdivisions and pick the one that results in reasonable BPM
    60.0 / median_interval => float bpm_if_beat;
    60.0 / (median_interval * 2) => float bpm_if_eighth;
    60.0 / (median_interval * 4) => float bpm_if_sixteenth;

    // Choose the BPM that falls in reasonable range
    if(bpm_if_beat >= MIN_BPM && bpm_if_beat <= MAX_BPM) return bpm_if_beat;
    if(bpm_if_eighth >= MIN_BPM && bpm_if_eighth <= MAX_BPM) return bpm_if_eighth;
    if(bpm_if_sixteenth >= MIN_BPM && bpm_if_sixteenth <= MAX_BPM) return bpm_if_sixteenth;

    // If none in range, clamp to range
    if(bpm_if_beat < MIN_BPM) return MIN_BPM;
    if(bpm_if_beat > MAX_BPM) return MAX_BPM;
    return bpm_if_beat;
}

// Quantize timestamps to grid
fun void quantizeTrack(int track) {
    if(!ENABLE_QUANTIZATION) return;
    if(track_drum_timestamps[track].size() == 0) return;

    // Estimate BPM
    estimateBPM(track) => float bpm;
    <<< "Track", track, "- Estimated BPM:", bpm >>>;

    // Calculate grid size (time between quantization points)
    60.0 / bpm / (QUANTIZE_DIVISION / 4.0) => float grid_size;  // (QUANTIZE_DIVISION/4) converts to beats
    <<< "  Quantizing to", QUANTIZE_DIVISION + "th", "notes (grid size:", grid_size, "sec)" >>>;

    // Quantize each timestamp
    0 => int moves_count;
    for(0 => int i; i < track_drum_timestamps[track].size(); i++) {
        track_drum_timestamps[track][i] => float original_time;

        // Find nearest grid point
        Math.round(original_time / grid_size) => float grid_point;
        grid_point * grid_size => float quantized_time;

        // Update timestamp
        quantized_time => track_drum_timestamps[track][i];

        // Track how many were moved
        if(Math.fabs(original_time - quantized_time) > 0.001) {
            moves_count++;
        }
    }

    <<< "  Quantized", moves_count, "hits" >>>;
}

// === OSC SETUP ===
OscIn oin;
OscMsg msg;
OSC_RECEIVE_PORT => oin.port;
oin.listenAll();  // Listen to all OSC addresses

OscOut oout;
oout.dest("localhost", OSC_SEND_PORT);

// OSC sender functions
fun void sendSpiceLevel(float spice) {
    oout.start("/chuloopa/spice");
    spice => oout.add;
    oout.send();
}

fun void sendRegenerate() {
    oout.start("/chuloopa/regenerate");
    oout.send();
    <<< "Sent regenerate request to Python" >>>;
}

fun void sendTrackCleared() {
    oout.start("/chuloopa/track_cleared");
    oout.send();
}

fun void sendRecordingStarted() {
    oout.start("/chuloopa/recording_started");
    oout.send();
}

// === CHUGL VISUALIZATION SETUP ===
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ camera;
camera.posZ(6.0);

// === LIGHTING ===
GDirLight main_light --> scene;
main_light.intensity(1.2);
main_light.rotX(-30);

GDirLight rim_light --> scene;
rim_light.intensity(0.6);
rim_light.rotY(180);
rim_light.rotX(30);

// Front light for bottle (fixes back-lit appearance)
GDirLight bottle_light --> scene;
bottle_light.intensity(0.8);
bottle_light.rotY(-45);  // From front-right
bottle_light.rotX(-15);  // Slightly from above

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

// === CENTRAL POLYHEDRON (Spice-based geometry switching) ===
// More faces = more spice/complexity
1.0 => float BASE_SCALE;

GCube cube_shape --> scene;
cube_shape.sca(BASE_SCALE);
cube_shape.color(@(0.9, 0.2, 0.2));

GPolyhedron octahedron_shape(PolyhedronGeometry.OCTAHEDRON) --> scene;
octahedron_shape.sca(BASE_SCALE);
octahedron_shape.color(@(0.9, 0.2, 0.2));
octahedron_shape.posY(-100);  // Hide initially

GPolyhedron dodec_shape(PolyhedronGeometry.DODECAHEDRON) --> scene;
dodec_shape.sca(BASE_SCALE);
dodec_shape.color(@(0.9, 0.2, 0.2));
dodec_shape.posY(-100);  // Hide initially

GPolyhedron icosahedron_shape(PolyhedronGeometry.ICOSAHEDRON) --> scene;
icosahedron_shape.sca(BASE_SCALE);
icosahedron_shape.color(@(0.9, 0.2, 0.2));
icosahedron_shape.posY(-100);  // Hide initially

// Track which shape is active (0=cube, 1=octa, 2=dodec, 3=icosa)
0 => int active_shape_index;

// === HOT SAUCE BOTTLE (VARIATION STATE INDICATOR) ===
GModel bottle(me.dir() + "/assets/hot+sauce+bottle+3d+model.obj") --> scene;

// Auto-scale bottle to reasonable size (similar to gmodel.ck)
fun float max(vec3 v) {
    return Math.max(Math.max(v.x, v.y), v.z);
}

max(bottle.max - bottle.min) => float bottle_size;
0.35 / bottle_size => float bottle_scale;  // Small icon size (0.35 units)
bottle.sca(bottle_scale);

// Position bottle next to spice text (to the right of the percentage)
bottle.posX(1.2);  // To the right of "SPICE: XX%"
bottle.posY(-100);  // Start hidden
bottle.posZ(0.0);

// Tilt to the right
bottle.rotZ(-Math.PI / 8);  // Tilt right
bottle.rotY(Math.PI / 6);   // Face forward slightly

// Store base position for animation
2.0 => float bottle_base_y;

// === DROP ZONE STATE VARIABLES ===
// For drag-and-drop detection
GWindow.files() @=> string files[];

// Drop zone visual elements
GMesh drop_zones[3];
PhongMaterial drop_zone_mats[3];
GText zone_labels[3];

// Flash effect state
float zone_flash_intensity[3];
time zone_flash_start[3];

// Zone configuration
float zone_x_positions[3];
-1.5 => zone_x_positions[0];  // Kick (left)
0.0 => zone_x_positions[1];   // Snare (center)
1.5 => zone_x_positions[2];   // Hat (right)

vec3 zone_colors[3];
@(0.9, 0.2, 0.2) => zone_colors[0];  // Red (kick)
@(1.0, 0.6, 0.1) => zone_colors[1];  // Orange (snare)
@(0.2, 0.8, 0.9) => zone_colors[2];  // Cyan (hat)

string zone_drum_names[3];
"KICK" => zone_drum_names[0];
"SNARE" => zone_drum_names[1];
"HAT" => zone_drum_names[2];

string current_sample_names[3];

// === CREATE DROP ZONES ===
for(0 => int i; i < 3; i++) {
    // Create drop zone square
    GMesh zone(new CubeGeometry, new PhongMaterial) --> scene;
    zone @=> drop_zones[i];
    drop_zones[i].sca(0.4);  // Small square
    drop_zones[i].posX(zone_x_positions[i]);
    drop_zones[i].posY(-1.5);  // Moved up from -2.0
    drop_zones[i].posZ(0.0);

    // Get material reference
    drop_zones[i].mat() $ PhongMaterial @=> drop_zone_mats[i];
    drop_zone_mats[i].color(zone_colors[i] * 0.6);  // Dim initially
    drop_zone_mats[i].specular(zone_colors[i] * 0.3);
    drop_zone_mats[i].emission(@(0.0, 0.0, 0.0));

    // Create text label
    GText label --> scene;
    label @=> zone_labels[i];
    zone_labels[i].text("DROP " + zone_drum_names[i]);
    zone_labels[i].posX(zone_x_positions[i]);
    zone_labels[i].posY(-2.0);  // Moved up from -2.5
    zone_labels[i].posZ(0.0);
    zone_labels[i].sca(0.15);
    zone_labels[i].color(@(0.7, 0.7, 0.7));

    // Initialize flash state
    0.0 => zone_flash_intensity[i];
    now => zone_flash_start[i];
}

// === TEXT DISPLAYS ===
GText spice_text --> scene;
spice_text.text("SPICE: 50%");
spice_text.posX(0.0);
spice_text.posY(2.0);
spice_text.posZ(0.0);
spice_text.sca(0.25);
spice_text.color(@(1.0, 0.6, 0.0));

GText state_text --> scene;
state_text.text("STATE: Idle");
state_text.posX(0.0);
state_text.posY(1.6);
state_text.posZ(0.0);
state_text.sca(0.22);
state_text.color(@(0.8, 0.8, 0.8));

// === AUDIO SETUP ===
adc => Gain input_gain => blackhole;
1.0 => input_gain.gain;

// Create array of LiSa loopers (one per track)
LiSa lisa[NUM_TRACKS];
Gain output_gains[NUM_TRACKS];

// === ANALYSIS CHAINS (per track, active only during recording) ===
FFT track_fft[NUM_TRACKS];
RMS track_rms[NUM_TRACKS];
MFCC track_mfcc[NUM_TRACKS];

// Configure each track
for(0 => int i; i < NUM_TRACKS; i++) {
    // Setup LiSa
    MAX_LOOP_DURATION => lisa[i].duration;
    1.0 => lisa[i].gain;
    adc => lisa[i];
    1.0 => lisa[i].rate;
    1 => lisa[i].loop;
    0 => lisa[i].bi;

    // Setup output gain for audio loops (DISABLED - drums only mode)
    lisa[i] => output_gains[i] => blackhole;  // Send to blackhole, not dac
    0.0 => output_gains[i].gain;  // Zero gain

    // Setup analysis chains (connected to adc, but only upchucked during recording)
    // Note: MFCC must be chained from FFT
    adc => track_fft[i] =^ track_mfcc[i] => blackhole;
    adc => track_rms[i] => blackhole;

    FRAME_SIZE => track_fft[i].size;
    Windowing.hann(FRAME_SIZE) => track_fft[i].window;

    // MFCC configuration
    10 => track_mfcc[i].numFilters;  // Number of MEL filters
    13 => track_mfcc[i].numCoeffs;   // Number of MFCC coefficients
}

// === DRUM SAMPLE PLAYBACK ===
// Each track plays back its transcribed drums using the same 3 samples
SndBuf kick_sample[NUM_TRACKS];
SndBuf snare_sample[NUM_TRACKS];
SndBuf hat_sample[NUM_TRACKS];
Gain drum_gain[NUM_TRACKS];

// Sample paths (work from project root or src directory)
me.dir() + "/samples/kick.wav" => string KICK_SAMPLE;
me.dir() + "/samples/snare.wav" => string SNARE_SAMPLE;
me.dir() + "/samples/hat.WAV" => string HAT_SAMPLE;  // Note: uppercase .WAV

for(0 => int i; i < NUM_TRACKS; i++) {
    // Setup drum sample players WITHOUT envelopes
    // Each sample gets its own path to the master gain
    kick_sample[i] => drum_gain[i] => dac;
    snare_sample[i] => drum_gain[i];
    hat_sample[i] => drum_gain[i];

    DRUM_SAMPLE_VOLUME => drum_gain[i].gain;  // Master drum volume

    // Load samples
    KICK_SAMPLE => kick_sample[i].read;
    SNARE_SAMPLE => snare_sample[i].read;
    HAT_SAMPLE => hat_sample[i].read;

    // CRITICAL: Set all samples to NOT play on startup
    kick_sample[i].samples() => kick_sample[i].pos;  // Move to end
    snare_sample[i].samples() => snare_sample[i].pos;
    hat_sample[i].samples() => hat_sample[i].pos;

    // Verify samples loaded
    if(kick_sample[i].samples() == 0) {
        <<< "WARNING: Could not load", KICK_SAMPLE >>>;
    }
    if(snare_sample[i].samples() == 0) {
        <<< "WARNING: Could not load", SNARE_SAMPLE >>>;
    }
    if(hat_sample[i].samples() == 0) {
        <<< "WARNING: Could not load", HAT_SAMPLE >>>;
    }
}

// Set initial sample names for drop zone labels
getFilename(KICK_SAMPLE) => current_sample_names[0];
getFilename(SNARE_SAMPLE) => current_sample_names[1];
getFilename(HAT_SAMPLE) => current_sample_names[2];

// Update zone labels with default samples
current_sample_names[0] => zone_labels[0].text;
current_sample_names[1] => zone_labels[1].text;
current_sample_names[2] => zone_labels[2].text;

// === STATE VARIABLES (per track) ===
int is_recording[NUM_TRACKS];
int is_playing[NUM_TRACKS];
float loop_length[NUM_TRACKS];
dur recorded_duration[NUM_TRACKS];
int has_loop[NUM_TRACKS];
time record_start_time[NUM_TRACKS];

// Drum playback state
time loop_start_time[NUM_TRACKS];
int drum_playback_active[NUM_TRACKS];
int drum_playback_id[NUM_TRACKS];  // Unique ID for each playback session to prevent old hits from playing

// Mix control state
float track_audio_drum_mix[NUM_TRACKS]; // 0.0 = all audio, 1.0 = all drums

// NEW: Track whether data came from file or live recording
int track_loaded_from_file[NUM_TRACKS];

// NEW: Queued action system for smooth transitions
int queued_load_track[NUM_TRACKS];  // Which tracks should load from file at next cycle
int queued_clear_track[NUM_TRACKS]; // Which tracks should clear at next cycle
int queued_toggle_variation;        // Toggle variation mode at next cycle

// === VARIATION MODE STATE ===
int variation_mode_active;           // 0 = playing original, 1 = playing variation
int variations_ready;                // 0 = not ready, 1 = ready to use
int generation_requested;            // 0 = not requested, 1 = user pressed generate
int generation_failed;               // 0 = no failure, 1 = last generation failed
float current_spice_level;           // 0.0-1.0
string variation_status_message;     // Status message from Python

// Initialize variation mode state
0 => variation_mode_active;
0 => variations_ready;
0 => generation_requested;
0 => generation_failed;
DEFAULT_SPICE_LEVEL => current_spice_level;
"" => variation_status_message;
0 => queued_toggle_variation;

// === DEFORMATION & ANIMATION STATE ===
0.5 => float MAX_DEFORMATION;
0.5 => float NOISE_SPEED;
0.3 => float NOISE_AMOUNT;

// Drum hit impulses for visual feedback
0.0 => float kick_impulse => float snare_impulse => float hat_impulse;

// Animation time
now => time start_time;

// Initialize track states
for(0 => int i; i < NUM_TRACKS; i++) {
    0 => is_recording[i];
    0 => is_playing[i];
    0.0 => loop_length[i];
    0::second => recorded_duration[i];
    0 => has_loop[i];
    0 => drum_playback_active[i];
    0 => drum_playback_id[i];
    0.6 => track_audio_drum_mix[i];     // 60% drums by default (40% audio)
    0 => track_loaded_from_file[i];
    0 => queued_load_track[i];
    0 => queued_clear_track[i];
}

// === SYMBOLIC DRUM DATA STORAGE (per track) ===
// Each track stores drum hits: [class, velocity, timestamp]
int track_drum_classes[NUM_TRACKS][0];      // 0=kick, 1=snare, 2=hat
float track_drum_timestamps[NUM_TRACKS][0]; // Start times (seconds from loop start)
float track_drum_velocities[NUM_TRACKS][0]; // Velocities (0-1.0)

// Onset detection state (per track)
float prev_spectrum[NUM_TRACKS][FRAME_SIZE/2];
float flux_history[NUM_TRACKS][50];
int flux_history_idx[NUM_TRACKS];
int flux_history_filled[NUM_TRACKS];
time last_onset_time[NUM_TRACKS];

// Initialize onset detection state
for(0 => int i; i < NUM_TRACKS; i++) {
    0 => flux_history_idx[i];
    0 => flux_history_filled[i];
    now => last_onset_time[i];

    for(0 => int j; j < FRAME_SIZE/2; j++) {
        0.0 => prev_spectrum[i][j];
    }
}

// === ONSET DETECTION FUNCTIONS ===

fun float spectralFlux(int track) {
    track_fft[track].upchuck() @=> UAnaBlob @ blob;
    0.0 => float flux;

    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float current_mag;
        Math.max(0.0, current_mag - prev_spectrum[track][i]) => float diff;
        diff +=> flux;
        current_mag => prev_spectrum[track][i];
    }

    return flux;
}

fun void updateFluxHistory(int track, float flux) {
    flux => flux_history[track][flux_history_idx[track]];
    (flux_history_idx[track] + 1) % 50 => flux_history_idx[track];

    if(!flux_history_filled[track] && flux_history_idx[track] == 0) {
        1 => flux_history_filled[track];
    }
}

fun float getAdaptiveThreshold(int track) {
    if(!flux_history_filled[track] && flux_history_idx[track] < 10) {
        return MIN_ONSET_STRENGTH * 2.0;
    }

    0.0 => float mean;
    50 => int count;
    if(!flux_history_filled[track]) {
        flux_history_idx[track] => count;
    }

    for(0 => int i; i < count; i++) {
        flux_history[track][i] +=> mean;
    }
    mean / count => mean;

    return mean * ONSET_THRESHOLD_MULTIPLIER;
}

fun int detectOnset(int track, float flux, float threshold) {
    if(flux < threshold) return 0;
    if(flux < MIN_ONSET_STRENGTH) return 0;

    now - last_onset_time[track] => dur time_since_last;
    if(time_since_last < MIN_ONSET_INTERVAL) return 0;

    now => last_onset_time[track];
    return 1;
}

// === KNN CLASSIFIER SETUP ===
KNN2 knn;
int knn_trained;
0 => knn_trained;
3 => int K_NEIGHBORS;  // Number of neighbors to use

// Label names
["kick", "snare", "hat"] @=> string label_names[];

// Train KNN from CSV file
fun int trainKNNFromCSV(string filename) {
    <<< "" >>>;
    <<< "╔═══════════════════════════════════════╗" >>>;
    <<< "║  TRAINING KNN FROM CSV               ║" >>>;
    <<< "╚═══════════════════════════════════════╝" >>>;
    <<< "" >>>;

    FileIO fin;
    fin.open(filename, FileIO.READ);

    if(!fin.good()) {
        <<< "ERROR: Could not open training file:", filename >>>;
        <<< "Falling back to heuristic classifier" >>>;
        return 0;
    }

    // Skip header line
    fin.readLine() => string header;

    // Count samples first
    0 => int num_samples;
    while(fin.more()) {
        fin.readLine();
        num_samples++;
    }

    if(num_samples == 0) {
        <<< "ERROR: No training samples found" >>>;
        fin.close();
        return 0;
    }

    <<< "Found", num_samples, "training samples" >>>;

    // Reset file
    fin.close();
    fin.open(filename, FileIO.READ);
    fin.readLine();  // Skip header again

    // Allocate arrays for training data
    // We'll use 5 features: flux, energy, band1, band2, band5
    float training_features[num_samples][5];
    int training_labels[num_samples];

    // Read data
    0 => int sample_idx;
    int label_counts[3];
    0 => label_counts[0] => label_counts[1] => label_counts[2];

    while(fin.more()) {
        fin.readLine() => string line;
        if(line.length() == 0) continue;

        StringTokenizer tok;
        tok.set(line);
        tok.delims(",");  // CRITICAL: CSV uses comma delimiters!

        // Parse CSV: label,timestamp,flux,energy,band1,band2,band3,band4,band5,...
        tok.next() => string label;

        // Convert label to int (0=kick, 1=snare, 2=hat)
        0 => int label_val;
        if(label == "kick") {
            0 => label_val;
            label_counts[0]++;
        }
        else if(label == "snare") {
            1 => label_val;
            label_counts[1]++;
        }
        else if(label == "hat") {
            2 => label_val;
            label_counts[2]++;
        }

        label_val => training_labels[sample_idx];

        // Skip timestamp
        tok.next();

        // Read features: flux, energy, band1, band2, (skip band3, band4), band5
        Std.atof(tok.next()) => training_features[sample_idx][0];  // flux
        Std.atof(tok.next()) => training_features[sample_idx][1];  // energy
        Std.atof(tok.next()) => training_features[sample_idx][2];  // band1
        Std.atof(tok.next()) => training_features[sample_idx][3];  // band2
        tok.next();  // skip band3
        tok.next();  // skip band4
        Std.atof(tok.next()) => training_features[sample_idx][4];  // band5

        sample_idx++;
    }

    fin.close();

    <<< "Training samples per class:" >>>;
    <<< "  Kicks:", label_counts[0] >>>;
    <<< "  Snares:", label_counts[1] >>>;
    <<< "  Hats:", label_counts[2] >>>;
    <<< "" >>>;

    // Train KNN
    <<< "Training KNN classifier..." >>>;
    knn.train(training_features, training_labels);

    // Optional: Set feature weights (can be tuned based on importance)
    // Equal weights for now
    [1.0, 1.0, 1.0, 1.0, 1.0] @=> float weights[];
    knn.weigh(weights);

    <<< "✓ KNN training complete!" >>>;
    <<< "Using k =", K_NEIGHBORS, "neighbors" >>>;
    <<< "" >>>;

    return 1;
}

// === FEATURE EXTRACTION & CLASSIFICATION ===

fun int classifyOnset(int track, float flux) {
    // Extract same features as training data
    track_rms[track].upchuck() @=> UAnaBlob @ rms_blob;
    rms_blob.fval(0) => float energy;

    track_fft[track].upchuck() @=> UAnaBlob @ blob;

    // Frequency band energies (matching training data format)
    0.0 => float band1 => float band2 => float band3 => float band4 => float band5;
    for(0 => int i; i < FRAME_SIZE/2; i++) {
        blob.fval(i) => float mag;
        if(i < FRAME_SIZE/32) mag +=> band1;           // 0-344 Hz
        else if(i < FRAME_SIZE/8) mag +=> band2;       // 344-1378 Hz
        else if(i < FRAME_SIZE/4) mag +=> band3;       // 1378-2756 Hz
        else if(i < FRAME_SIZE/2.5) mag +=> band4;     // 2756-4410 Hz
        else mag +=> band5;                            // 4410+ Hz
    }

    if(knn_trained) {
        // Use trained KNN classifier
        float query[5];
        flux => query[0];
        energy => query[1];
        band1 => query[2];
        band2 => query[3];
        band5 => query[4];

        // Get probabilities for each class
        float probs[3];
        knn.predict(query, K_NEIGHBORS, probs);

        // Find class with highest probability
        0 => int best_class;
        probs[0] => float best_prob;
        for(1 => int i; i < 3; i++) {
            if(probs[i] > best_prob) {
                i => best_class;
                probs[i] => best_prob;
            }
        }

        return best_class;
    }
    else {
        // Fallback: Simple heuristic classifier
        band1 / (energy + 0.0001) => float low_ratio;
        band5 / (energy + 0.0001) => float high_ratio;

        if(low_ratio > 0.5) return 0;      // Kick
        else if(high_ratio > 0.3) return 2; // Hat
        else return 1;                      // Snare
    }
}

// === SYMBOLIC DATA FUNCTIONS ===

fun void saveDrumHit(int track, int drum_class, float velocity) {
    if(is_recording[track]) {
        // Calculate timestamp relative to loop start
        (now - record_start_time[track]) / second => float timestamp;

        // Store drum hit
        track_drum_classes[track] << drum_class;
        track_drum_timestamps[track] << timestamp;
        track_drum_velocities[track] << velocity;

        // Play drum hit immediately for real-time feedback during recording
        playDrumHit(track, drum_class, velocity);

        ["KICK", "SNARE", "HAT"] @=> string class_names[];
        <<< "Track", track, "-", class_names[drum_class], "at", timestamp, "sec |",
            "Total hits:", track_drum_classes[track].size() >>>;
    }
}

// Clear symbolic data for a track
fun void clearSymbolicData(int track) {
    track_drum_classes[track].clear();
    track_drum_timestamps[track].clear();
    track_drum_velocities[track].clear();

    <<< "Track", track, "drum data cleared" >>>;
}

// Export symbolic data to file
fun void exportSymbolicData(int track) {
    if(track_drum_classes[track].size() == 0) {
        <<< "Track", track, "has no drum data to export" >>>;
        return;
    }

    me.dir() + "/tracks/track_" + track + "/track_" + track + "_drums.txt" => string filename;
    FileIO fout;
    fout.open(filename, FileIO.WRITE);

    if(!fout.good()) {
        <<< "ERROR: Could not open file for writing:", filename >>>;
        return;
    }

    // Write header
    fout.write("# Track " + track + " Drum Data\n");
    fout.write("# Format: DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME\n");
    fout.write("# Classes: 0=kick, 1=snare, 2=hat\n");
    fout.write("# DELTA_TIME: Duration until next hit (for last hit: time until loop end)\n");
    fout.write("# Total loop duration: " + loop_length[track] + " seconds\n");

    // Write each hit with delta_time
    for(0 => int i; i < track_drum_classes[track].size(); i++) {
        track_drum_classes[track][i] => int drum_class;
        track_drum_timestamps[track][i] => float timestamp;
        track_drum_velocities[track][i] => float velocity;

        // Calculate delta_time (time until next hit, or until loop end)
        0.0 => float delta_time;
        if(i < track_drum_classes[track].size() - 1) {
            // Time to next hit
            track_drum_timestamps[track][i+1] - timestamp => delta_time;
        } else {
            // Last hit: time until loop wraps around
            loop_length[track] - timestamp => delta_time;
        }

        fout.write(drum_class + "," + timestamp + "," + velocity + "," + delta_time + "\n");
    }

    fout.close();

    <<< ">>> Track", track, "exported to", filename, "(" + track_drum_classes[track].size(), "hits) <<<" >>>;
    <<< "    Total loop duration:", loop_length[track], "seconds" >>>;
}

// Export all tracks
fun void exportAllSymbolicData() {
    <<< "" >>>;
    <<< "╔═══════════════════════════════════════╗" >>>;
    <<< "║  EXPORTING ALL DRUM DATA            ║" >>>;
    <<< "╚═══════════════════════════════════════╝" >>>;

    for(0 => int i; i < NUM_TRACKS; i++) {
        if(has_loop[i]) {
            exportSymbolicData(i);
        }
    }

    <<< "Export complete!" >>>;
}

// === NEW: LOAD DRUM DATA FROM FILE ===

// Queue a file load action (executed at next loop cycle)
fun void queueLoadFromFile(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;

    <<< "" >>>;
    <<< ">>> QUEUED: Track", track, "will load from file at next loop cycle <<<" >>>;
    1 => queued_load_track[track];
}

// Internal function: Actually load the drum data (called at loop boundary)
fun int loadDrumDataFromFile(int track) {
    if(track < 0 || track >= NUM_TRACKS) return 0;

    me.dir() + "/tracks/track_" + track + "/track_" + track + "_drums.txt" => string filename;

    <<< "" >>>;
    <<< "╔═══════════════════════════════════════╗" >>>;
    <<< "║  LOADING DRUM DATA FROM FILE         ║" >>>;
    <<< "╚═══════════════════════════════════════╝" >>>;
    <<< "Loading:", filename >>>;

    FileIO fin;
    fin.open(filename, FileIO.READ);

    if(!fin.good()) {
        <<< "ERROR: Could not open file:", filename >>>;
        <<< "Make sure the file exists!" >>>;
        return 0;
    }

    // CRITICAL: Stop existing drum playback for this track IMMEDIATELY
    // Note: This is called at loop boundary by coordinator, so timing is perfect
    // Increment playback ID to invalidate ALL old scheduled drum hits
    drum_playback_id[track] + 1 => drum_playback_id[track];

    // Stop flags
    0 => drum_playback_active[track];

    // NO WAIT - we're already at the loop boundary, start immediately!

    // Clear existing data
    clearSymbolicData(track);

    // Temporary storage for loaded data
    int loaded_classes[0];
    float loaded_timestamps[0];
    float loaded_velocities[0];
    float loaded_delta_times[0];

    0.0 => float max_timestamp;
    0.0 => float last_delta_time;  // Will store the final delta_time (time to loop end)
    0 => int line_count;
    0 => int has_delta_time_column;  // Track if file has new format

    // Read file
    while(fin.more()) {
        fin.readLine() => string line;
        line_count++;

        // Skip comments and empty lines
        if(line.length() == 0) continue;
        if(line.substring(0, 1) == "#") continue;

        // Parse CSV line: DRUM_CLASS,TIMESTAMP,VELOCITY[,DELTA_TIME]
        StringTokenizer tok;
        tok.set(line);
        tok.delims(",");

        // Check if we have enough tokens by trying to parse
        if(!tok.more()) {
            <<< "WARNING: Skipping malformed line", line_count >>>;
            continue;
        }

        // Parse values
        Std.atoi(tok.next()) => int drum_class;

        if(!tok.more()) {
            <<< "WARNING: Skipping malformed line", line_count, "(missing timestamp)" >>>;
            continue;
        }
        Std.atof(tok.next()) => float timestamp;

        if(!tok.more()) {
            <<< "WARNING: Skipping malformed line", line_count, "(missing velocity)" >>>;
            continue;
        }
        Std.atof(tok.next()) => float velocity;

        // Try to read delta_time (optional, for backwards compatibility)
        0.0 => float delta_time;
        if(tok.more()) {
            Std.atof(tok.next()) => delta_time;
            1 => has_delta_time_column;
            delta_time => last_delta_time;  // Keep updating, last one is important
        }

        // Validate
        if(drum_class < 0 || drum_class > 2) {
            <<< "WARNING: Invalid drum class", drum_class, "on line", line_count >>>;
            continue;
        }

        // Store
        loaded_classes << drum_class;
        loaded_timestamps << timestamp;
        loaded_velocities << velocity;
        loaded_delta_times << delta_time;

        // Track max timestamp for loop length
        if(timestamp > max_timestamp) {
            timestamp => max_timestamp;
        }
    }

    fin.close();

    if(loaded_classes.size() == 0) {
        <<< "ERROR: No valid drum data found in file" >>>;
        return 0;
    }

    // Copy loaded data to track arrays
    for(0 => int i; i < loaded_classes.size(); i++) {
        track_drum_classes[track] << loaded_classes[i];
        track_drum_timestamps[track] << loaded_timestamps[i];
        track_drum_velocities[track] << loaded_velocities[i];
    }

    // CRITICAL: Calculate precise loop duration using delta_time from last hit
    0.0 => float file_loop_duration;

    if(has_delta_time_column && last_delta_time > 0.0) {
        // NEW: Use precise duration from last hit's delta_time
        max_timestamp + last_delta_time => file_loop_duration;
        <<< "Using precise loop duration from file:", file_loop_duration, "sec" >>>;
    } else {
        // FALLBACK: Old method - estimate with buffer
        max_timestamp + 0.5 => file_loop_duration;
        <<< "No delta_time found - using estimated duration:", file_loop_duration, "sec" >>>;
    }

    // Use master loop duration if it exists, otherwise use file's duration
    if(has_master) {
        // Scale timestamps to fit master loop duration
        master_duration / second => float target_duration;
        file_loop_duration => float original_duration;

        if(original_duration > 0.001) {
            target_duration / original_duration => float scale_ratio;

            <<< "Scaling timestamps to match master loop..." >>>;
            <<< "  Original duration:", original_duration, "sec" >>>;
            <<< "  Target duration:", target_duration, "sec" >>>;
            <<< "  Scale ratio:", scale_ratio >>>;

            // Scale all timestamps
            for(0 => int i; i < track_drum_timestamps[track].size(); i++) {
                track_drum_timestamps[track][i] * scale_ratio => track_drum_timestamps[track][i];
            }
        }

        // Use master loop duration
        master_duration / second => loop_length[track];
        master_duration => recorded_duration[track];
    } else {
        // No master loop yet - use file's precise duration
        file_loop_duration => loop_length[track];
        loop_length[track]::second => recorded_duration[track];
    }

    <<< "✓ Loaded", track_drum_classes[track].size(), "drum hits" >>>;
    <<< "✓ Loop length:", loop_length[track], "seconds" >>>;

    // Mark track as loaded from file
    1 => track_loaded_from_file[track];
    1 => has_loop[track];

    // Enable drum-only playback
    1 => drum_playback_active[track];
    0.8 => drum_gain[track].gain;

    // Start drum playback with NEW playback ID (old scheduled hits are invalidated)
    spork ~ drumPlaybackLoop(track);

    <<< ">>> TRACK", track, "LOADED FROM FILE (DRUM-ONLY MODE, Playback ID:", drum_playback_id[track], ") <<<" >>>;
    <<< "" >>>;

    return 1;
}

// Load a specific variation file
fun int loadVariationFile(int track, int var_num) {
    if(track < 0 || track >= NUM_TRACKS) return 0;
    if(var_num < 1 || var_num > 3) return 0;

    me.dir() + "/tracks/track_" + track + "/variations/track_" + track + "_drums_var" + var_num + ".txt" => string filename;

    <<< "" >>>;
    <<< "╔═══════════════════════════════════════╗" >>>;
    <<< "║  LOADING VARIATION", var_num, "                 ║" >>>;
    <<< "╚═══════════════════════════════════════╝" >>>;
    <<< "Loading:", filename >>>;

    FileIO fin;
    fin.open(filename, FileIO.READ);

    if(!fin.good()) {
        <<< "ERROR: Could not open file:", filename >>>;
        return 0;
    }

    // Stop existing drum playback
    drum_playback_id[track] + 1 => drum_playback_id[track];
    0 => drum_playback_active[track];

    // Clear existing data
    clearSymbolicData(track);

    // Load data (same logic as loadDrumDataFromFile)
    int loaded_classes[0];
    float loaded_timestamps[0];
    float loaded_velocities[0];
    float loaded_delta_times[0];

    0.0 => float max_timestamp;
    0.0 => float last_delta_time;
    0 => int line_count;
    0 => int has_delta_time_column;

    while(fin.more()) {
        fin.readLine() => string line;
        line_count++;

        if(line.length() == 0) continue;
        if(line.substring(0, 1) == "#") continue;

        StringTokenizer tok;
        tok.set(line);
        tok.delims(",");

        if(!tok.more()) continue;

        Std.atoi(tok.next()) => int drum_class;
        if(!tok.more()) continue;
        Std.atof(tok.next()) => float timestamp;
        if(!tok.more()) continue;
        Std.atof(tok.next()) => float velocity;

        0.0 => float delta_time;
        if(tok.more()) {
            Std.atof(tok.next()) => delta_time;
            1 => has_delta_time_column;
            delta_time => last_delta_time;
        }

        if(drum_class < 0 || drum_class > 2) continue;

        loaded_classes << drum_class;
        loaded_timestamps << timestamp;
        loaded_velocities << velocity;
        loaded_delta_times << delta_time;

        if(timestamp > max_timestamp) {
            timestamp => max_timestamp;
        }
    }

    fin.close();

    if(loaded_classes.size() == 0) {
        <<< "ERROR: No valid drum data found in variation file" >>>;
        return 0;
    }

    // Copy to track arrays
    for(0 => int i; i < loaded_classes.size(); i++) {
        track_drum_classes[track] << loaded_classes[i];
        track_drum_timestamps[track] << loaded_timestamps[i];
        track_drum_velocities[track] << loaded_velocities[i];
    }

    // Calculate loop duration
    0.0 => float file_loop_duration;
    if(has_delta_time_column && last_delta_time > 0.0) {
        max_timestamp + last_delta_time => file_loop_duration;
    } else {
        max_timestamp + 0.5 => file_loop_duration;
    }

    // Use existing loop duration if set
    if(has_loop[track] && loop_length[track] > 0.0) {
        loop_length[track] => float target_duration;
        file_loop_duration => float original_duration;

        if(original_duration > 0.001) {
            target_duration / original_duration => float scale_ratio;
            for(0 => int i; i < track_drum_timestamps[track].size(); i++) {
                track_drum_timestamps[track][i] * scale_ratio => track_drum_timestamps[track][i];
            }
        }
    } else {
        file_loop_duration => loop_length[track];
        loop_length[track]::second => recorded_duration[track];
    }

    <<< "✓ Loaded", track_drum_classes[track].size(), "drum hits" >>>;
    <<< "✓ Loop length:", loop_length[track], "seconds" >>>;

    1 => track_loaded_from_file[track];
    1 => has_loop[track];
    1 => drum_playback_active[track];
    0.8 => drum_gain[track].gain;

    spork ~ drumPlaybackLoop(track);

    <<< ">>> VARIATION LOADED (Playback ID:", drum_playback_id[track], ") <<<" >>>;
    <<< "" >>>;

    return 1;
}

// === DRUM PLAYBACK FUNCTIONS ===

fun void playDrumHit(int track, int drum_class, float velocity) {
    // Map velocity (0.0-1.0) to gain multiplier
    Math.max(0.3, Math.min(1.0, velocity)) => float vel_gain;

    // Trigger appropriate sample - they'll play to completion naturally
    if(drum_class == 0) {  // Kick
        0 => kick_sample[track].pos;  // Reset to beginning
        vel_gain * 0.6 => kick_sample[track].gain;  // Apply velocity
        // Trigger visual impulse
        vel_gain => kick_impulse;
    }
    else if(drum_class == 1) {  // Snare
        0 => snare_sample[track].pos;
        vel_gain * 0.5 => snare_sample[track].gain;
        // Trigger visual impulse
        vel_gain => snare_impulse;
    }
    else if(drum_class == 2) {  // Hat
        0 => hat_sample[track].pos;
        vel_gain * 0.4 => hat_sample[track].gain;
        // Trigger visual impulse
        vel_gain => hat_impulse;
    }
}

// Scheduled drum playback
fun void playScheduledDrumHit(int track, int drum_class, float velocity,
                              time scheduled_time, int my_playback_id) {
    // Wait until scheduled time
    scheduled_time - now => dur wait_time;
    if(wait_time > 0::second) {
        wait_time => now;
    }

    // CRITICAL: Check if this is still the current playback session
    // If playback_id changed, this is an old session - don't play!
    if(!drum_playback_active[track] || !has_loop[track] || drum_playback_id[track] != my_playback_id) {
        return;  // Old session, abort
    }

    // Play the drum hit
    playDrumHit(track, drum_class, velocity);
}

// Main drum playback loop for a track
fun void drumPlaybackLoop(int track) {
    if(track_drum_classes[track].size() == 0) {
        <<< "Track", track, "- No drum hits to play" >>>;
        return;
    }

    // Get a unique ID for THIS playback session
    drum_playback_id[track] => int my_playback_id;

    loop_length[track] => float total_duration;

    <<< "Track", track, "- Drum playback started (ID:", my_playback_id, ")" >>>;
    <<< "  Loop duration:", total_duration, "sec" >>>;
    <<< "  Drum hits:", track_drum_classes[track].size() >>>;

    // NOTE: Sync is handled by masterSyncCoordinator - we start immediately
    // The coordinator ensures we only start at loop boundaries

    // Continuous loop playback
    0 => int loop_count;
    while(drum_playback_active[track] && has_loop[track] && drum_playback_id[track] == my_playback_id) {
        loop_count++;
        now => loop_start_time[track];

        // Schedule all drum hits for this loop iteration
        for(0 => int i; i < track_drum_classes[track].size(); i++) {
            if(!drum_playback_active[track] || !has_loop[track] || drum_playback_id[track] != my_playback_id) break;

            loop_start_time[track] + track_drum_timestamps[track][i]::second => time hit_time;

            spork ~ playScheduledDrumHit(track,
                                        track_drum_classes[track][i],
                                        track_drum_velocities[track][i],
                                        hit_time,
                                        my_playback_id);  // Pass session ID
        }

        // Wait for loop to complete
        loop_start_time[track] + total_duration::second => time loop_end;
        loop_end - now => dur remaining;

        if(remaining > 0::second) {
            remaining => now;
        }
    }

    <<< "Track", track, "- Drum playback stopped" >>>;
}

// === MASTER SYNC COORDINATOR ===
// This loop watches for loop boundaries and executes queued actions
fun void masterSyncCoordinator() {
    <<< "Master sync coordinator started" >>>;

    while(true) {
        // Find a reference track that's playing (to sync with)
        -1 => int ref_track;
        for(0 => int i; i < NUM_TRACKS; i++) {
            if(has_loop[i] && drum_playback_active[i] && loop_length[i] > 0.0) {
                i => ref_track;
                break;
            }
        }

        if(ref_track >= 0) {
            // Calculate time to next loop boundary
            loop_start_time[ref_track] + loop_length[ref_track]::second => time next_boundary;
            next_boundary - now => dur time_to_boundary;

            // If we're close to the boundary (within this loop's duration), wait for it
            if(time_to_boundary > 0::second && time_to_boundary < loop_length[ref_track]::second) {
                time_to_boundary => now;

                <<< "" >>>;
                <<< "=== LOOP BOUNDARY: Processing queued actions ===" >>>;

                // Process queued variation toggle
                if(queued_toggle_variation) {
                    <<< "Executing queued variation toggle" >>>;
                    executeToggleVariation();
                    0 => queued_toggle_variation;  // Clear queue
                }

                // Process all queued loads
                for(0 => int i; i < NUM_TRACKS; i++) {
                    if(queued_load_track[i]) {
                        <<< "Executing queued load for track", i >>>;
                        loadDrumDataFromFile(i);
                        0 => queued_load_track[i];  // Clear queue
                    }
                }

                // Process all queued clears
                for(0 => int i; i < NUM_TRACKS; i++) {
                    if(queued_clear_track[i]) {
                        <<< "Executing queued clear for track", i >>>;
                        clearTrack(i);
                        0 => queued_clear_track[i];  // Clear queue
                    }
                }
            } else {
                // Not close to boundary, wait a bit
                100::ms => now;
            }
        } else {
            // No reference track playing yet, wait
            100::ms => now;
        }
    }
}

// === OSC LISTENER ===
fun void oscListener() {
    <<< "" >>>;
    <<< "╔═══════════════════════════════════════╗" >>>;
    <<< "║  OSC LISTENER READY                  ║" >>>;
    <<< "╚═══════════════════════════════════════╝" >>>;
    <<< "Listening on port:", OSC_RECEIVE_PORT >>>;
    <<< "Waiting for messages from Python..." >>>;
    <<< "" >>>;

    while(true) {
        oin => now;

        while(oin.recv(msg)) {
            // Debug: print all received messages
            <<< "" >>>;
            <<< ">>> OSC RECEIVED:", msg.address, "<<<" >>>;

            if(msg.address == "/chuloopa/variations_ready") {
                msg.getInt(0) => int num_variations;
                1 => variations_ready;
                0 => generation_failed;  // Clear failure flag on success
                <<< "" >>>;
                <<< "✓ Python: Variation ready!" >>>;
                <<< "  Press D1 (Note 38) to load variation" >>>;
                <<< "" >>>;
            }
            else if(msg.address == "/chuloopa/generation_failed") {
                msg.getString(0) => string reason;
                0 => variations_ready;  // Mark as not ready
                1 => generation_failed;  // Set failure flag
                // Keep generation_requested = 1 so user can try again
                <<< "" >>>;
                <<< "✗ Python: Generation FAILED!" >>>;
                <<< "  Reason:", reason >>>;
                <<< "  Press D#1 (Note 39) to try again" >>>;
                <<< "" >>>;
            }
            else if(msg.address == "/chuloopa/generation_progress") {
                msg.getString(0) => string status;
                status => variation_status_message;
                <<< "Python:", status >>>;
            }
            else if(msg.address == "/chuloopa/error") {
                msg.getString(0) => string error;
                <<< "ERROR from Python:", error >>>;
            }
            else {
                <<< "Unknown OSC message:", msg.address >>>;
            }
        }
    }
}

// === VARIATION MODE FUNCTIONS ===
fun void toggleVariationMode() {
    if(!has_loop[0]) {
        <<< "Cannot toggle variation mode: no loop recorded" >>>;
        return;
    }

    if(!variations_ready && variation_mode_active == 0) {
        <<< "Cannot toggle variation mode: variation not ready" >>>;
        <<< "Record a loop or press D#1 (Note 39) to regenerate" >>>;
        return;
    }

    // Queue the toggle for next loop boundary
    1 => queued_toggle_variation;
    <<< "" >>>;
    <<< ">>> QUEUED: Variation toggle will occur at next loop boundary <<<" >>>;
    <<< "" >>>;
}

// Internal function: Actually toggle variation (called at loop boundary)
fun void executeToggleVariation() {
    if(variation_mode_active == 0) {
        // Switch to variation mode
        <<< "" >>>;
        <<< "╔═══════════════════════════════════════╗" >>>;
        <<< "║  LOADING VARIATION                   ║" >>>;
        <<< "╚═══════════════════════════════════════╝" >>>;

        1 => variation_mode_active;

        // Load the variation
        loadVariationFile(0, 1);

        <<< "" >>>;
    }
    else {
        // Switch back to original
        <<< "" >>>;
        <<< "╔═══════════════════════════════════════╗" >>>;
        <<< "║  LOADING ORIGINAL                    ║" >>>;
        <<< "╚═══════════════════════════════════════╝" >>>;

        0 => variation_mode_active;

        // Load original file
        loadDrumDataFromFile(0);

        <<< "Playing original loop" >>>;
        <<< "" >>>;
    }
}

// === MAIN ONSET DETECTION LOOP ===
fun void mainOnsetDetectionLoop() {
    FRAME_SIZE::samp => now;

    <<< "Main onset detection loop started" >>>;

    while(true) {
        // Check which track is recording
        -1 => int active_track;
        for(0 => int i; i < NUM_TRACKS; i++) {
            if(is_recording[i]) {
                i => active_track;
                break;
            }
        }

        // If a track is recording, perform onset detection
        if(active_track >= 0) {
            spectralFlux(active_track) => float flux;
            updateFluxHistory(active_track, flux);
            getAdaptiveThreshold(active_track) => float threshold;

            if(detectOnset(active_track, flux, threshold)) {
                // Classify the onset
                classifyOnset(active_track, flux) => int drum_class;

                // Calculate velocity from flux
                Math.min(1.0, flux / 0.1) => float velocity;

                // Save to symbolic data
                saveDrumHit(active_track, drum_class, velocity);
            }
        }

        HOP => now;
    }
}

// === TRACK CONTROL FUNCTIONS ===

fun void startRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;
    if(is_recording[track]) return;

    <<< "" >>>;
    <<< ">>> TRACK", track, "RECORDING STARTED <<<" >>>;

    // If this track was loaded from file, stop its playback first
    if(track_loaded_from_file[track]) {
        0 => drum_playback_active[track];
        0 => track_loaded_from_file[track];
        100::ms => now;  // Brief pause to stop playback
    }

    // Clear previous drum data
    clearSymbolicData(track);

    // Setup LiSa for recording
    0 => lisa[track].play;
    lisa[track].clear();
    0::second => lisa[track].recPos;
    1 => lisa[track].record;

    1 => is_recording[track];
    now => record_start_time[track];

    <<< "Recording... onset detection active" >>>;
}

fun void stopRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;
    if(!is_recording[track]) return;

    0 => lisa[track].record;
    0 => is_recording[track];

    lisa[track].recPos() => recorded_duration[track];

    // === MASTER LOOP SYNC ===
    if(!has_master) {
        track => master_track;
        recorded_duration[track] => master_duration;
        1 => has_master;

        <<< "" >>>;
        <<< "╔═══════════════════════════════════════╗" >>>;
        <<< "║  MASTER LOOP SET: Track", track, "          ║" >>>;
        <<< "╚═══════════════════════════════════════╝" >>>;
        <<< "Duration:", master_duration / second, "seconds" >>>;
    } else {
        findBestMultiplier(recorded_duration[track], master_duration) => dur adjusted;
        (adjusted / master_duration) $ float => float multiplier;

        // Store original duration
        recorded_duration[track] / second => float original_duration;
        adjusted => recorded_duration[track];
        adjusted / second => float adjusted_duration;

        // Scale drum timings if duration was adjusted
        if(Math.fabs(adjusted_duration - original_duration) > 0.001 &&
           track_drum_classes[track].size() > 0) {
            adjusted_duration / original_duration => float scale_ratio;

            for(0 => int i; i < track_drum_timestamps[track].size(); i++) {
                track_drum_timestamps[track][i] * scale_ratio => track_drum_timestamps[track][i];
            }
        }

        <<< "" >>>;
        <<< ">>> TRACK", track, "SYNCED TO MASTER <<<" >>>;
        <<< "Adjusted to", multiplier, "× master length" >>>;
        <<< "Final length:", recorded_duration[track] / second, "seconds" >>>;
    }

    recorded_duration[track] / second => loop_length[track];

    if(loop_length[track] > 0.1) {
        0::second => lisa[track].playPos;
        recorded_duration[track] => lisa[track].loopEnd;
        0::second => lisa[track].loopStart;
        1 => lisa[track].loop;
        1 => lisa[track].play;
        1 => is_playing[track];
        1 => has_loop[track];
        0 => track_loaded_from_file[track];  // Mark as recorded (not loaded)

        <<< ">>> TRACK", track, "LOOPING <<<" >>>;
        <<< ">>> Captured", track_drum_classes[track].size(), "drum hits <<<" >>>;

        // === QUANTIZATION ===
        if(track_drum_classes[track].size() > 0) {
            quantizeTrack(track);
        }

        // === AUTO-EXPORT ===
        if(track_drum_classes[track].size() > 0) {
            exportSymbolicData(track);
        }

        // === ENABLE DRUM PLAYBACK ===
        if(track_drum_classes[track].size() > 0) {
            1 => drum_playback_active[track];

            // Drums-only mode
            0.8 => drum_gain[track].gain;

            spork ~ drumPlaybackLoop(track);
            <<< ">>> DRUM PLAYBACK ENABLED (Drums Only Mode) <<<" >>>;
        } else {
            <<< ">>> No drum hits detected <<<" >>>;
        }
    }
}

fun void clearTrack(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;

    <<< ">>> CLEARING TRACK", track, "<<<" >>>;

    0 => lisa[track].play;
    0 => lisa[track].record;
    lisa[track].clear();
    0 => is_recording[track];
    0 => is_playing[track];
    0 => has_loop[track];

    // Stop drum playback
    0 => drum_playback_active[track];

    clearSymbolicData(track);

    // Reset file-loaded flag
    0 => track_loaded_from_file[track];

    // Reset master if needed
    if(track == master_track && !anyLoopsExist()) {
        <<< "╔═══════════════════════════════════════╗" >>>;
        <<< "║  MASTER LOOP CLEARED               ║" >>>;
        <<< "╚═══════════════════════════════════════╝" >>>;

        -1 => master_track;
        0::second => master_duration;
        0 => has_master;
    }
}

fun void setTrackVolume(int track, float vol) {
    if(track < 0 || track >= NUM_TRACKS) return;
    Math.max(0.0, Math.min(1.0, vol)) => float master_vol;

    // Drums-only mode - adjust drum volume
    if(has_loop[track] && drum_playback_active[track]) {
        master_vol * 0.8 => drum_gain[track].gain;
        <<< "Track", track, "Volume:", (master_vol * 100) $ int, "%" >>>;
    }
}

fun void setTrackAudioDrumMix(int track, float mix) {
    // DEPRECATED: Drums-only mode, no mix needed
    // Keep function for backwards compatibility with MIDI controls
    <<< "Track", track, "- Drums Only Mode (mix control disabled)" >>>;
}

// === DEFORMATION FUNCTIONS ===
fun void updateShapeDeformations(float time_sec) {
    // Base organic morphing (noise-like)
    Math.sin(time_sec * NOISE_SPEED) => float noise_x;
    Math.cos(time_sec * NOISE_SPEED * 0.7) => float noise_y;
    Math.sin(time_sec * NOISE_SPEED * 1.3) => float noise_z;

    // Base scales with noise
    BASE_SCALE + noise_x * NOISE_AMOUNT => float scale_x;
    BASE_SCALE + noise_y * NOISE_AMOUNT => float scale_y;
    BASE_SCALE + noise_z * NOISE_AMOUNT => float scale_z;

    // Add drum hit deformations
    if(kick_impulse > 0.0) {
        // Kick: expand all axes (radial pulse)
        scale_x + kick_impulse * 0.4 => scale_x;
        scale_y + kick_impulse * 0.4 => scale_y;
        scale_z + kick_impulse * 0.4 => scale_z;
    }

    if(snare_impulse > 0.0) {
        // Snare: squeeze Y, expand X/Z (vertical compression)
        scale_y - snare_impulse * 0.3 => scale_y;
        scale_x + snare_impulse * 0.2 => scale_x;
        scale_z + snare_impulse * 0.2 => scale_z;
    }

    if(hat_impulse > 0.0) {
        // Hat: asymmetric wobble on X axis
        scale_x + hat_impulse * 0.3 => scale_x;
    }

    // Apply spice multiplier (makes deformations more extreme)
    if(current_spice_level > 0.5) {
        (current_spice_level - 0.5) * 2.0 => float spice_factor;
        scale_x * (1.0 + spice_factor * 0.4) => scale_x;
        scale_y * (1.0 + spice_factor * 0.4) => scale_y;
        scale_z * (1.0 + spice_factor * 0.4) => scale_z;
    }

    // Clamp scales
    Math.max(0.3, Math.min(2.5, scale_x)) => scale_x;
    Math.max(0.3, Math.min(2.5, scale_y)) => scale_y;
    Math.max(0.3, Math.min(2.5, scale_z)) => scale_z;

    // Apply scale to all shapes (only visible one matters)
    cube_shape.scaX(scale_x);
    cube_shape.scaY(scale_y);
    cube_shape.scaZ(scale_z);

    octahedron_shape.scaX(scale_x);
    octahedron_shape.scaY(scale_y);
    octahedron_shape.scaZ(scale_z);

    dodec_shape.scaX(scale_x);
    dodec_shape.scaY(scale_y);
    dodec_shape.scaZ(scale_z);

    icosahedron_shape.scaX(scale_x);
    icosahedron_shape.scaY(scale_y);
    icosahedron_shape.scaZ(scale_z);

    // Decay impulses
    kick_impulse * 0.9 => kick_impulse;
    if(kick_impulse < 0.01) 0.0 => kick_impulse;

    snare_impulse * 0.9 => snare_impulse;
    if(snare_impulse < 0.01) 0.0 => snare_impulse;

    hat_impulse * 0.9 => hat_impulse;
    if(hat_impulse < 0.01) 0.0 => hat_impulse;
}

// === VISUALIZATION ===
fun void visualizationLoop() {
    <<< "Visualization loop started" >>>;

    while(true) {
        GG.nextFrame() => now;
        (now - start_time) / second => float time_sec;

        // Update shape deformations
        updateShapeDeformations(time_sec);

        // Update colors based on state
        @(0.5, 0.5, 0.5) => vec3 target_color;  // Default gray
        0.4 => float target_bloom;

        // Add shine on drum hits (bloom boost)
        0.0 => float hit_shine;
        if(kick_impulse > 0.1 || snare_impulse > 0.1 || hat_impulse > 0.1) {
            Math.max(kick_impulse, Math.max(snare_impulse, hat_impulse)) => hit_shine;
        }

        if(is_recording[0]) {
            // NO RECORDING AND WHILE RECORDING: Gray
            @(0.5, 0.5, 0.5) => target_color;
            0.3 => target_bloom;
        }
        else if(variation_mode_active) {
            // PLAYING VARIATION: Gradient based on spice
            // Blue (low) → Yellow (mid) → Red (high)
            if(current_spice_level < 0.5) {
                // Blue to Yellow gradient (0.0 - 0.5)
                current_spice_level * 2.0 => float t;
                @(0.2 + t * 0.8, 0.4 + t * 0.6, 0.9 - t * 0.9) => target_color;
            }
            else {
                // Yellow to Red gradient (0.5 - 1.0)
                (current_spice_level - 0.5) * 2.0 => float t;
                @(1.0, 1.0 - t * 0.1, 0.0) => target_color;
            }
            0.5 + current_spice_level * 0.3 => target_bloom;
        }
        else if(variations_ready && !variation_mode_active) {
            // VARIATION READY (not playing yet): Blue with green tint + extra glow
            @(0.2, 0.6, 0.7) => target_color;
            0.6 => target_bloom;
        }
        else if(has_loop[0]) {
            // PLAYING INITIAL RECORDING: Blue
            @(0.2, 0.4, 0.9) => target_color;
            0.4 => target_bloom;
        }
        else {
            // Idle: Dim gray
            @(0.3, 0.3, 0.3) => target_color;
            0.2 => target_bloom;
        }

        // Add hit shine to bloom
        target_bloom + hit_shine * 0.4 => target_bloom;

        // Switch geometry based on spice level (only in variation mode)
        0 => int target_shape;  // Default to cube

        if(variation_mode_active) {
            // Determine shape based on spice level
            if(current_spice_level < 0.4) {
                0 => target_shape;  // Cube (6 faces)
            }
            else if(current_spice_level < 0.7) {
                1 => target_shape;  // Octahedron (8 faces)
            }
            else if(current_spice_level < 1.0) {
                2 => target_shape;  // Dodecahedron (12 faces)
            }
            else {
                3 => target_shape;  // Icosahedron (20 faces) - max spice!
            }
        }

        // Switch shapes if needed
        if(target_shape != active_shape_index) {
            // Hide current shape
            if(active_shape_index == 0) cube_shape.posY(-100);
            else if(active_shape_index == 1) octahedron_shape.posY(-100);
            else if(active_shape_index == 2) dodec_shape.posY(-100);
            else if(active_shape_index == 3) icosahedron_shape.posY(-100);

            // Show new shape
            target_shape => active_shape_index;
            if(active_shape_index == 0) cube_shape.posY(0);
            else if(active_shape_index == 1) octahedron_shape.posY(0);
            else if(active_shape_index == 2) dodec_shape.posY(0);
            else if(active_shape_index == 3) icosahedron_shape.posY(0);
        }

        // Apply color and rotation to all shapes (only visible one matters)
        cube_shape.color(target_color);
        octahedron_shape.color(target_color);
        dodec_shape.color(target_color);
        icosahedron_shape.color(target_color);

        cube_shape.rotY(time_sec * 0.2);
        cube_shape.rotX(Math.sin(time_sec * 0.3) * 0.3);

        octahedron_shape.rotY(time_sec * 0.2);
        octahedron_shape.rotX(Math.sin(time_sec * 0.3) * 0.3);

        dodec_shape.rotY(time_sec * 0.2);
        dodec_shape.rotX(Math.sin(time_sec * 0.3) * 0.3);

        icosahedron_shape.rotY(time_sec * 0.2);
        icosahedron_shape.rotX(Math.sin(time_sec * 0.3) * 0.3);

        bloom_pass.intensity(target_bloom);

        // Update text
        "SPICE: " + ((current_spice_level * 100) $ int) + "%" => spice_text.text;

        if(current_spice_level < 0.5) {
            current_spice_level * 2.0 => float t;
            spice_text.color(@(0.2 + t * 0.8, 0.5 + t * 0.5, 1.0 - t * 1.0));
        } else {
            (current_spice_level - 0.5) * 2.0 => float t;
            spice_text.color(@(1.0, 1.0 - t * 0.5, 0.0));
        }

        // STATE TEXT: Show state via color
        "STATE: " => string state_label;
        if(is_recording[0]) {
            state_label + "Recording" => state_text.text;
            // BLINKING RED for recording
            Math.sin(time_sec * 8.0) => float blink;
            if(blink > 0) @(1.0, 0.2, 0.2) => state_text.color;
            else @(0.5, 0.1, 0.1) => state_text.color;
        }
        else if(variation_mode_active) {
            state_label + "Variation" => state_text.text;
            @(0.8, 0.8, 0.8) => state_text.color;  // Default
        }
        else if(has_loop[0]) {
            state_label + "Original" => state_text.text;
            @(0.8, 0.8, 0.8) => state_text.color;  // Default
        }
        else {
            state_label + "Idle" => state_text.text;
            @(0.7, 0.7, 0.7) => state_text.color;  // White/gray for idle
        }

        // HOT SAUCE BOTTLE: Subtle floating animation + color changes
        // Gentle vertical bobbing
        Math.sin(time_sec * 1.2) * 0.05 => float bob_offset;
        bottle.posY(bottle_base_y + bob_offset);

        // Gentle rotation wobble
        Math.sin(time_sec * 0.8) * 0.05 => float wobble;
        bottle.rotZ(-Math.PI / 8 + wobble);

        // Color changes based on variation state
        if(!has_loop[0] || !generation_requested) {
            // No loop OR generation not requested: hide bottle
            bottle.posY(-100);
        }
        else if(generation_failed) {
            // Generation FAILED: BLINKING RED (urgent - try again!)
            bottle.posY(bottle_base_y + bob_offset);
            Math.sin(time_sec * 8.0) => float blink;  // Faster blink for urgency

            // Blink between bright red and dim red
            if(bottle.materials.size() > 0) {
                bottle.materials[0] $ PhongMaterial @=> PhongMaterial @ mat;
                if(mat != null) {
                    if(blink > 0) {
                        // REALLY BRIGHT RED
                        mat.color(@(2.0, 0.3, 0.3));
                        mat.specular(@(2.0, 0.5, 0.5));
                        mat.emission(@(3.0, 0.5, 0.5));  // Extremely bright red emission
                    }
                    else {
                        // Dim red
                        mat.color(@(1.0, 0.2, 0.2));
                        mat.specular(@(1.0, 0.3, 0.3));
                        mat.emission(@(1.5, 0.3, 0.3));
                    }
                }
            }
        }
        else if(variations_ready && !variation_mode_active) {
            // Variation ready: BLINKING GREEN with high exposure
            bottle.posY(bottle_base_y + bob_offset);
            Math.sin(time_sec * 6.0) => float blink;

            // Blink between bright green and dim green
            if(bottle.materials.size() > 0) {
                bottle.materials[0] $ PhongMaterial @=> PhongMaterial @ mat;
                if(mat != null) {
                    if(blink > 0) {
                        // REALLY BRIGHT GREEN
                        mat.color(@(0.5, 2.0, 0.6));
                        mat.specular(@(0.8, 2.0, 1.0));
                        mat.emission(@(0.8, 3.0, 1.0));  // Extremely bright green emission
                    }
                    else {
                        // Dim green (was bright green)
                        mat.color(@(0.2, 1.0, 0.3));
                        mat.specular(@(0.4, 1.0, 0.5));
                        mat.emission(@(0.3, 1.5, 0.4));
                    }
                }
            }
        }
        else if(generation_requested && !variations_ready) {
            // Generation requested but not ready: White with pulsing exposure
            bottle.posY(bottle_base_y + bob_offset);
            Math.sin(time_sec * 2.0) * 0.3 + 0.7 => float pulse;

            // Keep bottle white with oscillating exposure
            if(bottle.materials.size() > 0) {
                bottle.materials[0] $ PhongMaterial @=> PhongMaterial @ mat;
                if(mat != null) {
                    mat.color(@(0.9, 0.9, 0.9));  // White base
                    mat.specular(@(1.0, 1.0, 1.0));
                    mat.emission(@(0.5 * pulse, 0.5 * pulse, 0.5 * pulse));  // White bloom pulse
                }
            }
        }

        // === UPDATE DROP ZONE VISUALS ===
        for(0 => int i; i < 3; i++) {
            // Decay flash intensity (200ms flash duration)
            zone_flash_intensity[i] * 0.85 => zone_flash_intensity[i];

            // Apply flash effect to material
            if(zone_flash_intensity[i] > 0.1) {
                // Success flash (green)
                drop_zone_mats[i].color(zone_colors[i]);
                drop_zone_mats[i].emission(@(0.5, 1.5, 0.5) * zone_flash_intensity[i]);
            }
            else if(zone_flash_intensity[i] < -0.1) {
                // Error flash (red)
                drop_zone_mats[i].color(@(1.0, 0.2, 0.2));
                drop_zone_mats[i].emission(@(2.0, 0.3, 0.3) * Math.fabs(zone_flash_intensity[i]));
            }
            else {
                // Normal state (dim, no emission)
                drop_zone_mats[i].color(zone_colors[i] * 0.6);
                drop_zone_mats[i].emission(@(0.0, 0.0, 0.0));
            }
        }

        // === DRAG-AND-DROP DETECTION ===
        if(GWindow.files() != files) {
            GWindow.files() @=> files;

            if(files.size() > 0) {
                // Detect drop zone from mouse position
                UI.getMousePos() => vec2 mousePos;
                detectZoneFromMouse(mousePos) => int target_zone;

                <<< "" >>>;
                <<< ">>> FILE DROPPED into", zone_drum_names[target_zone], "zone <<<" >>>;

                // Load sample (hot-swap)
                loadDrumSample(target_zone, files[0]);
            }
        }
    }
}

// === MIDI LISTENER ===
MidiIn min;
MidiMsg midi_msg;

<<< "" >>>;
<<< "=====================================================" >>>;
<<< "      CHULOOPA - AI Drum Variation System" >>>;
<<< "=====================================================" >>>;

if(min.num() == 0) {
    <<< "WARNING: No MIDI devices found!" >>>;
} else {
    if(min.open(MIDI_DEVICE)) {
        <<< "MIDI Device:", min.name() >>>;
    }
}

<<< "" >>>;
<<< "Drum Samples Loaded:" >>>;
<<< "  Kick:", kick_sample[0].samples(), "samples" >>>;
<<< "  Snare:", snare_sample[0].samples(), "samples" >>>;
<<< "  Hat:", hat_sample[0].samples(), "samples" >>>;
<<< "" >>>;
<<< "MIDI Controls (Single Track):" >>>;
<<< "  C1  (36): Record track (press & hold)" >>>;
<<< "  C#1 (37): Clear track" >>>;
<<< "  D#1 (39): Generate variation (hot sauce icon appears)" >>>;
<<< "  D1  (38): Toggle variation ON/OFF (after generation ready)" >>>;
<<< "  CC  18:   Spice level knob (0.0-1.0, adjust before generating)" >>>;
<<< "" >>>;
<<< "OSC Communication:" >>>;
<<< "  Sending to: localhost:", OSC_SEND_PORT >>>;
<<< "  Receiving on:", OSC_RECEIVE_PORT >>>;
<<< "" >>>;
<<< "Variation Settings:" >>>;
<<< "  Default spice:", DEFAULT_SPICE_LEVEL >>>;
<<< "" >>>;
<<< "MODE: DRUMS ONLY (Real-time drum feedback)" >>>;
<<< "=====================================================" >>>;

int ignore_cc[128];
for(0 => int i; i < 128; i++) 1 => ignore_cc[i];

0 => ignore_cc[CC_SPICE_LEVEL];  // Only listen to CC 18 (spice)

fun void midiListener() {
    while(true) {
        min => now;

        while(min.recv(midi_msg)) {
            midi_msg.data1 => int status;
            midi_msg.data2 => int data1;
            midi_msg.data3 => int data2;
            status & 0xF0 => int messageType;

            // Control Change
            if(messageType == 0xB0) {
                if(!ignore_cc[data1]) {
                    // Spice level knob
                    if(data1 == CC_SPICE_LEVEL) {
                        data2 / 127.0 => current_spice_level;
                        sendSpiceLevel(current_spice_level);
                        <<< "Spice level:", (current_spice_level * 100) $ int, "%" >>>;
                    }
                }
            }

            // Note On
            else if(messageType == 0x90 && data2 > 0) {
                // Recording (C1)
                if(data1 == NOTE_RECORD_TRACK) {
                    startRecording(0);
                    sendRecordingStarted();
                }

                // Clear track (C#1)
                else if(data1 == NOTE_CLEAR_TRACK) {
                    clearTrack(0);
                    sendTrackCleared();
                    0 => variations_ready;          // Variations no longer valid
                    0 => variation_mode_active;     // Exit variation mode
                    0 => generation_requested;      // Reset generation request
                }

                // Toggle variation mode (D1)
                else if(data1 == NOTE_TOGGLE_VARIATION) {
                    toggleVariationMode();
                }

                // Regenerate variations (D#1)
                else if(data1 == NOTE_REGENERATE) {
                    1 => generation_requested;     // Mark that generation was requested
                    0 => variations_ready;          // Reset ready flag (waiting for Python)
                    0 => generation_failed;         // Clear failure flag (trying again)
                    sendRegenerate();
                    <<< "Generation requested - waiting for Python to generate variation..." >>>;
                }
            }

            // Note Off
            else if(messageType == 0x80 || (messageType == 0x90 && data2 == 0)) {
                // Stop recording (C1)
                if(data1 == NOTE_RECORD_TRACK) {
                    stopRecording(0);
                }
            }
        }
    }
}

// === DROP ZONE HELPER FUNCTIONS ===

fun int detectZoneFromMouse(vec2 mousePos) {
    // Divide screen into thirds based on mouse X position
    GG.windowWidth() => float windowWidth;
    mousePos.x => float mouseX;
    windowWidth / 3.0 => float zoneWidth;

    if(mouseX < zoneWidth) return 0;        // KICK (left third)
    else if(mouseX < zoneWidth * 2.0) return 1;  // SNARE (middle third)
    else return 2;                          // HAT (right third)
}

fun string getFilename(string filepath) {
    // Extract just filename from full path
    -1 => int last_slash;
    for(0 => int i; i < filepath.length(); i++) {
        if(filepath.substring(i, 1) == "/") {
            i => last_slash;
        }
    }
    if(last_slash >= 0 && last_slash < filepath.length() - 1) {
        return filepath.substring(last_slash + 1, filepath.length() - last_slash - 1);
    }
    return filepath;
}

fun void triggerZoneFlash(int zone, int success) {
    // success: 1=green flash, 0=red error flash
    now => zone_flash_start[zone];

    if(success) {
        3.0 => zone_flash_intensity[zone];  // Bright green emission
    } else {
        -1.0 => zone_flash_intensity[zone];  // Negative = red error flag
    }
}

fun int loadDrumSample(int zone, string filepath) {
    // Validate zone parameter
    if(zone < 0 || zone >= 3) {
        <<< "ERROR: Invalid zone", zone, "(must be 0-2)" >>>;
        return 0;
    }

    // Validate filepath
    if(filepath == "") {
        <<< "ERROR: Empty filepath" >>>;
        return 0;
    }

    // zone: 0=kick, 1=snare, 2=hat
    <<< "" >>>;
    <<< ">>> LOADING SAMPLE:", zone_drum_names[zone], "<<<" >>>;
    <<< "File:", filepath >>>;

    // Test load to validate file
    SndBuf test;
    filepath => test.read;

    if(test.samples() == 0) {
        <<< "ERROR: Invalid audio file or file not found" >>>;
        triggerZoneFlash(zone, 0);  // Red error flash
        "INVALID FILE" => zone_labels[zone].text;
        "INVALID" => current_sample_names[zone];
        return 0;
    }

    <<< "Valid file, loading into all tracks..." >>>;

    // Hot-swap: reload all track SndBufs for this drum type
    for(0 => int i; i < NUM_TRACKS; i++) {
        if(zone == 0) {
            // KICK
            filepath => kick_sample[i].read;
            kick_sample[i].samples() => kick_sample[i].pos;  // Reset to end (silent)
        }
        else if(zone == 1) {
            // SNARE
            filepath => snare_sample[i].read;
            snare_sample[i].samples() => snare_sample[i].pos;
        }
        else if(zone == 2) {
            // HAT
            filepath => hat_sample[i].read;
            hat_sample[i].samples() => hat_sample[i].pos;
        }
    }

    // Success feedback
    triggerZoneFlash(zone, 1);  // Green success flash
    getFilename(filepath) => string fname;
    fname => current_sample_names[zone];
    fname + " | LOADED!" => zone_labels[zone].text;

    <<< "[OK] Sample loaded successfully!" >>>;
    <<< "  Duration:", (test.length() / second) $ float, "sec" >>>;
    <<< "" >>>;

    return 1;
}

// === MAIN PROGRAM ===

// Try to load and train KNN classifier from CSV
if(trainKNNFromCSV(me.dir() + "/training_samples.csv")) {
    1 => knn_trained;
    <<< "╔═══════════════════════════════════════╗" >>>;
    <<< "║  KNN CLASSIFIER READY                ║" >>>;
    <<< "╚═══════════════════════════════════════╝" >>>;
} else {
    <<< "⚠ Using fallback heuristic classifier" >>>;
    <<< "  (Run drum_sample_recorder.ck to create training_samples.csv)" >>>;
}

<<< "" >>>;

spork ~ midiListener();
spork ~ visualizationLoop();
spork ~ mainOnsetDetectionLoop();
spork ~ masterSyncCoordinator();
spork ~ oscListener();  // NEW: Listen for OSC messages from Python

// Give OSC listener time to start
100::ms => now;

// Send test message to Python to verify OSC connection
<<< "" >>>;
<<< "Sending OSC test message to Python..." >>>;
sendSpiceLevel(DEFAULT_SPICE_LEVEL);  // Send initial spice level as test
<<< "" >>>;

<<< "" >>>;
<<< "✓ CHULOOPA ready!" >>>;
<<< "" >>>;
<<< "Quick Start:" >>>;
<<< "  1. Press C1 to record a beatbox loop" >>>;
<<< "  2. Press D#1 to generate variation (hot sauce icon appears)" >>>;
<<< "  3. Wait for green blinking icon (variation ready)" >>>;
<<< "  4. Press D1 to toggle variation ON/OFF" >>>;
<<< "  5. Adjust CC 18 knob to change spice, press D#1 to regenerate" >>>;
<<< "" >>>;
<<< "Make sure drum_variation_ai.py is running in watch mode!" >>>;
<<< "" >>>;

while(true) {
    1::second => now;
}
