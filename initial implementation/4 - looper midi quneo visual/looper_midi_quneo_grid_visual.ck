//---------------------------------------------------------------------
// name: looper_midi_quneo_grid_visual.ck
// desc: Multi-track looper with grid visualization and quantization
//       Shows loop position, bars, and beats visually
//
// Recording Behavior:
//   PRESS to start recording (quantized to next bar)
//   RELEASE to stop - quantized to nearest bar
//
// MIDI Mapping:
//   NOTES (for pad triggers):
//     C1, C#1, D1 (36-38):  Press to toggle record tracks 0-2
//     E1, F1, F#1 (40-42):  Press to clear tracks 0-2
//   
//   CCs (for continuous controls):
//     CC 45-47:    Volume control for tracks 0-2
//     CC 48:       BPM control (30-300 BPM)
//
// Visual Features:
//   - Grid showing bars and beats
//   - Playhead for each track showing loop position
//   - Track lanes with different colors
//   - Shapes pulse with audio amplitude
//
// Usage:
//   chuck looper_midi_quneo_grid_visual.ck
//---------------------------------------------------------------------

// === MIDI CONFIGURATION ===
36 => int NOTE_RECORD_TRACK_0;
37 => int NOTE_RECORD_TRACK_1;
38 => int NOTE_RECORD_TRACK_2;

40 => int NOTE_CLEAR_TRACK_0;
41 => int NOTE_CLEAR_TRACK_1;
42 => int NOTE_CLEAR_TRACK_2;

45 => int CC_VOLUME_TRACK_0;
46 => int CC_VOLUME_TRACK_1;
47 => int CC_VOLUME_TRACK_2;
48 => int CC_BPM;

0 => int MIDI_DEVICE;

// === CONFIGURATION ===
3 => int NUM_TRACKS;
4 => int beats_per_measure;
120.0 => float bpm;

// === CHUGL SETUP ===
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ camera;
camera.posZ(12.0);
camera.posY(1.0);

// Grid configuration
16 => int GRID_BEATS;  // Show 16 beats (4 bars)
6.0 => float GRID_WIDTH;  // Total width of grid
2.0 => float TRACK_HEIGHT;  // Height of each track lane
0.6 => float TRACK_SPACING;  // Vertical spacing between tracks

// Create grid lines (beats and bars)
GLines grid_lines --> scene;
grid_lines.posX(0);
grid_lines.posY(0);
grid_lines.color(@(0.3, 0.3, 0.3));

// Create bar emphasis lines
GLines bar_lines --> scene;
bar_lines.posX(0);
bar_lines.posY(0);
bar_lines.color(@(0.5, 0.5, 0.5));

// Create track background planes
GPlane track_bg[NUM_TRACKS];
for(0 => int i; i < NUM_TRACKS; i++) {
    track_bg[i] --> scene;
    track_bg[i].posX(0);
    track_bg[i].posY((NUM_TRACKS - 1 - i) * TRACK_SPACING);
    track_bg[i].sca(@(GRID_WIDTH, TRACK_HEIGHT * 0.4, 1.0));
    
    if(i == 0) track_bg[i].color(@(0.2, 0.1, 0.1));  // Red tint
    else if(i == 1) track_bg[i].color(@(0.1, 0.2, 0.1));  // Green tint
    else if(i == 2) track_bg[i].color(@(0.2, 0.2, 0.1));  // Yellow tint
}

// Create playheads for each track
GPlane playhead[NUM_TRACKS];
for(0 => int i; i < NUM_TRACKS; i++) {
    playhead[i] --> scene;
    playhead[i].posX(-GRID_WIDTH / 2.0);
    playhead[i].posY((NUM_TRACKS - 1 - i) * TRACK_SPACING);
    playhead[i].posZ(0.1);  // Slightly in front
    playhead[i].sca(@(0.05, TRACK_HEIGHT * 0.5, 1.0));
    
    if(i == 0) playhead[i].color(@(1.0, 0.3, 0.3));  // Red
    else if(i == 1) playhead[i].color(@(0.3, 1.0, 0.3));  // Green
    else if(i == 2) playhead[i].color(@(1.0, 1.0, 0.3));  // Yellow
}

// Create amplitude visualization cubes for each track (wireframe)
GCube amp_cube[NUM_TRACKS];
WireframeMaterial wireframe_mat[NUM_TRACKS];
for(0 => int i; i < NUM_TRACKS; i++) {
    amp_cube[i] --> scene;
    amp_cube[i].posX(GRID_WIDTH / 2.0 + 1.5);
    amp_cube[i].posY((NUM_TRACKS - 1 - i) * TRACK_SPACING);
    amp_cube[i].sca(0.5);
    
    // Apply wireframe material
    amp_cube[i].mat(wireframe_mat[i]);
    
    if(i == 0) wireframe_mat[i].color(@(1.0, 0.3, 0.3));  // Red
    else if(i == 1) wireframe_mat[i].color(@(0.3, 1.0, 0.3));  // Green
    else if(i == 2) wireframe_mat[i].color(@(1.0, 1.0, 0.3));  // Yellow
}

// Create countdown text for each track
GText countdown_text[NUM_TRACKS];
for(0 => int i; i < NUM_TRACKS; i++) {
    countdown_text[i] --> scene;
    countdown_text[i].posX(-GRID_WIDTH / 2.0 - 1.0);  // Left of grid
    countdown_text[i].posY((NUM_TRACKS - 1 - i) * TRACK_SPACING);
    countdown_text[i].posZ(0.2);  // In front
    countdown_text[i].sca(2.0);  // Large size
    countdown_text[i].text("");  // Start hidden
    countdown_text[i].color(@(1.0, 1.0, 1.0));  // White
}

// Add lighting
GDirLight light --> scene;
light.intensity(0.8);
light.rotX(-45);

// === AUDIO SETUP ===
adc => Gain input_gain => blackhole;
1.0 => input_gain.gain;

// Create array of LiSa loopers
LiSa lisa[NUM_TRACKS];
Gain output_gains[NUM_TRACKS];

// Track audio analysis
RMS track_rms[NUM_TRACKS];
Gain track_analysis_gain[NUM_TRACKS];

// Configure each track
10::second => dur max_duration;
for(0 => int i; i < NUM_TRACKS; i++) {
    max_duration => lisa[i].duration;
    1.0 => lisa[i].gain;
    adc => lisa[i];
    1.0 => lisa[i].rate;
    1 => lisa[i].loop;
    0 => lisa[i].bi;

    lisa[i] => output_gains[i] => dac;
    0.7 => output_gains[i].gain;
    
    lisa[i] => track_analysis_gain[i] => track_rms[i] => blackhole;
    1.0 => track_analysis_gain[i].gain;
}

// === STATE VARIABLES ===
int is_recording[NUM_TRACKS];
int is_playing[NUM_TRACKS];
int waiting_to_record[NUM_TRACKS];
float loop_length[NUM_TRACKS];
dur recorded_duration[NUM_TRACKS];
int has_loop[NUM_TRACKS];
int loop_bars[NUM_TRACKS];  // Number of bars in each loop
time record_start_time[NUM_TRACKS];
time tempo_start_time;
now => tempo_start_time;

// Master loop sync variables
0 => int has_master_loop;  // True when first track sets the loop length
4 => int master_loop_bars;  // All tracks sync to this length
dur master_loop_duration;
0::second => master_loop_duration;

// Initialize
for(0 => int i; i < NUM_TRACKS; i++) {
    0 => is_recording[i];
    0 => is_playing[i];
    0 => waiting_to_record[i];
    0.0 => loop_length[i];
    0::second => recorded_duration[i];
    0 => has_loop[i];
    4 => loop_bars[i];
}

// === TIMING FUNCTIONS ===
fun dur beatDuration() {
    return (60.0 / bpm)::second;
}

fun dur measureDuration() {
    return (60.0 / bpm * beats_per_measure)::second;
}

fun void setBPM(float new_bpm) {
    Math.max(30.0, Math.min(300.0, new_bpm)) => bpm;
    
    // Reset tempo clock to stay in sync
    now => tempo_start_time;
    
    if(has_master_loop) {
        <<< "BPM set to:", bpm, "(Warning: may affect loop sync)" >>>;
    } else {
        <<< "BPM set to:", bpm >>>;
    }
}

fun float getCurrentBeat() {
    (now - tempo_start_time) / beatDuration() => float beat;
    return beat;
}

fun int getCurrentBar() {
    getCurrentBeat() / beats_per_measure => float bar;
    return bar $ int;
}

fun float getBeatInBar() {
    getCurrentBeat() % beats_per_measure => float beat;
    return beat;
}

// Calculate next bar boundary
fun dur timeUntilNextBar() {
    getBeatInBar() => float current_beat;
    if(current_beat < 0.01) return 0::second;  // Already on a bar
    (beats_per_measure - current_beat) * beatDuration() => dur time_left;
    return time_left;
}

// Round duration to nearest bar
fun dur quantizeToBar(dur input_dur) {
    input_dur / measureDuration() => float bars;
    Math.round(bars) $ int => int rounded_bars;
    if(rounded_bars < 1) 1 => rounded_bars;  // Minimum 1 bar
    return rounded_bars * measureDuration();
}

// === TRACK FUNCTIONS ===

fun void startRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;
    if(is_recording[track]) return;

    <<< ">>> TRACK", track, "WAITING TO RECORD (will start on next bar) <<<" >>>;
    1 => waiting_to_record[track];
    spork ~ waitAndStartRecording(track);
}

fun void waitAndStartRecording(int track) {
    // If this is the very first recording, reset tempo clock and wait full bar
    if(!has_master_loop) {
        // Check if any other track is recording or has a loop
        1 => int is_first;
        for(0 => int i; i < NUM_TRACKS; i++) {
            if(i != track && (has_loop[i] || is_recording[i])) {
                0 => is_first;
                break;
            }
        }
        
        if(is_first) {
            // Reset tempo to start fresh - this ensures we get a full 4-count
            now => tempo_start_time;
            <<< "=== TEMPO CLOCK RESET - Starting 4-count ===" >>>;
            
            // Wait exactly one full bar (4 beats) for the count-in
            measureDuration() => now;
            
            if(!waiting_to_record[track]) return;  // Cancelled during count-in
            
            <<< ">>> TRACK", track, "RECORDING STARTED <<<" >>>;
            
            0 => lisa[track].play;
            lisa[track].clear();
            0::second => lisa[track].recPos;
            1 => lisa[track].record;
            
            1 => is_recording[track];
            0 => waiting_to_record[track];
            now => record_start_time[track];
            
            spork ~ recordingMonitor(track);
            return;
        }
    }
    
    // For subsequent recordings, wait until next bar to stay synced
    timeUntilNextBar() => now;
    
    if(!waiting_to_record[track]) return;  // Cancelled
    
    <<< ">>> TRACK", track, "RECORDING STARTED <<<" >>>;
    
    0 => lisa[track].play;
    lisa[track].clear();
    0::second => lisa[track].recPos;
    1 => lisa[track].record;
    
    1 => is_recording[track];
    0 => waiting_to_record[track];
    now => record_start_time[track];
    
    spork ~ recordingMonitor(track);
}

fun void stopRecording(int track) {
    if(track < 0 || track >= NUM_TRACKS) return;
    
    if(waiting_to_record[track]) {
        <<< ">>> TRACK", track, "RECORDING CANCELLED <<<" >>>;
        0 => waiting_to_record[track];
        return;
    }
    
    if(is_recording[track]) {
        0 => lisa[track].record;
        0 => is_recording[track];
        
        lisa[track].recPos() => dur raw_duration;
        
        // If this is the first track, set master loop length
        if(!has_master_loop) {
            quantizeToBar(raw_duration) => master_loop_duration;
            (master_loop_duration / measureDuration()) $ int => master_loop_bars;
            1 => has_master_loop;
            
            <<< "==================================================" >>>;
            <<< "MASTER LOOP SET:", master_loop_bars, "bars" >>>;
            <<< "Duration:", master_loop_duration / second, "seconds" >>>;
            <<< "All tracks will sync to this length" >>>;
            <<< "==================================================" >>>;
        }
        
        // All tracks use master loop duration for perfect sync
        master_loop_duration => recorded_duration[track];
        master_loop_bars => loop_bars[track];
        
        <<< ">>> TRACK", track, "RECORDING STOPPED <<<" >>>;
        <<< "Raw length:", raw_duration / second, "seconds" >>>;
        <<< "Synced to master:", recorded_duration[track] / second, "seconds" >>>;
        <<< "Loop bars:", loop_bars[track] >>>;
        
        if(recorded_duration[track] > 0.1::second) {
            0::second => lisa[track].playPos;
            recorded_duration[track] => lisa[track].loopEnd;
            0::second => lisa[track].loopStart;
            1 => lisa[track].loop;
            1 => lisa[track].play;
            1 => is_playing[track];
            1 => has_loop[track];
            
            <<< ">>> TRACK", track, "LOOPING (synced to master) <<<" >>>;
        } else {
            <<< "Track", track, "recording too short" >>>;
        }
    }
}

fun void toggleRecording(int track) {
    if(is_recording[track] || waiting_to_record[track]) {
        stopRecording(track);
    } else {
        startRecording(track);
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
    0 => waiting_to_record[track];
    0.0 => loop_length[track];
    0::second => recorded_duration[track];
    0 => has_loop[track];
    4 => loop_bars[track];
    
    // Check if all tracks are now empty - reset master loop
    1 => int all_empty;
    for(0 => int i; i < NUM_TRACKS; i++) {
        if(has_loop[i]) {
            0 => all_empty;
            break;
        }
    }
    
    if(all_empty) {
        0 => has_master_loop;
        0::second => master_loop_duration;
        <<< "=== MASTER LOOP RESET ===" >>>;
    }
}

fun void setTrackVolume(int track, float vol) {
    if(track < 0 || track >= NUM_TRACKS) return;
    Math.max(0.0, Math.min(1.0, vol)) => vol;
    vol => output_gains[track].gain;
    <<< "Track", track, "volume:", vol >>>;
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

// === GRID VISUALIZATION UPDATE ===
fun void updateGrid() {
    // Build grid geometry using vec3 positions
    vec3 grid_positions[0];
    
    // Vertical lines for beats
    for(0 => int beat; beat < GRID_BEATS + 1; beat++) {
        (beat $ float / GRID_BEATS) * GRID_WIDTH - (GRID_WIDTH / 2.0) => float x;
        -TRACK_SPACING => float y_bottom;
        (NUM_TRACKS - 1) * TRACK_SPACING + TRACK_SPACING => float y_top;
        
        // Add line vertices as vec3
        grid_positions << @(x, y_bottom, 0.0);
        grid_positions << @(x, y_top, 0.0);
    }
    
    // Horizontal lines for track separation
    for(0 => int t; t <= NUM_TRACKS; t++) {
        (t - 0.5) * TRACK_SPACING => float y;
        -GRID_WIDTH / 2.0 => float x_left;
        GRID_WIDTH / 2.0 => float x_right;
        
        grid_positions << @(x_left, y, 0.0);
        grid_positions << @(x_right, y, 0.0);
    }
    
    grid_lines.geo().positions(grid_positions);
    
    // Build bar emphasis lines (every 4 beats)
    vec3 bar_positions[0];
    for(0 => int bar; bar <= GRID_BEATS / beats_per_measure; bar++) {
        (bar * beats_per_measure $ float / GRID_BEATS) * GRID_WIDTH - (GRID_WIDTH / 2.0) => float x;
        -TRACK_SPACING => float y_bottom;
        (NUM_TRACKS - 1) * TRACK_SPACING + TRACK_SPACING => float y_top;
        
        bar_positions << @(x, y_bottom, 0.05);
        bar_positions << @(x, y_top, 0.05);
    }
    
    bar_lines.geo().positions(bar_positions);
}

// === VISUALIZATION LOOP ===
fun void visualizationLoop() {
    updateGrid();  // Build grid once
    
    while(true) {
        GG.nextFrame() => now;
        
        // Update each track
        for(0 => int i; i < NUM_TRACKS; i++) {
            if(has_loop[i]) {
                // Get track position (0.0 to 1.0)
                lisa[i].playPos() / recorded_duration[i] => float progress;
                
                // Move playhead across grid
                -GRID_WIDTH / 2.0 + (progress * GRID_WIDTH) => float playhead_x;
                playhead[i].posX(playhead_x);
                
                // Get audio level
                track_rms[i].upchuck();
                track_rms[i].fval(0) * 25.0 => float level;
                
                // Pulse amplitude cube
                (0.5 + level * 3.0) => float cube_scale;
                amp_cube[i].sca(cube_scale);
                amp_cube[i].rotY(0.03);
                amp_cube[i].rotX(0.02);
            } else {
                // No loop - hide playhead, keep cube small
                playhead[i].posX(-GRID_WIDTH);
                amp_cube[i].sca(0.3);
                amp_cube[i].rotY(0.01);
                amp_cube[i].rotX(0.005);
            }
            
            // Show countdown while waiting to record
            if(waiting_to_record[i]) {
                // Calculate beats until next bar
                getBeatInBar() => float current_beat;
                beats_per_measure - current_beat => float beats_until_bar;
                
                // Convert to countdown number (4, 3, 2, 1)
                Math.ceil(beats_until_bar) $ int => int countdown;
                
                // Display countdown
                if(countdown > 0 && countdown <= beats_per_measure) {
                    countdown_text[i].text(countdown + "");
                    
                    // Pulse the text size on each beat
                    (current_beat % 1.0) => float beat_phase;
                    2.0 + (1.0 - beat_phase) * 0.5 => float text_scale;
                    countdown_text[i].sca(text_scale);
                } else {
                    countdown_text[i].text("");
                }
                
                // Dim background while waiting
                if(i == 0) track_bg[i].color(@(0.25, 0.1, 0.1));
                else if(i == 1) track_bg[i].color(@(0.1, 0.25, 0.1));
                else if(i == 2) track_bg[i].color(@(0.25, 0.25, 0.1));
            }
            // Blink while recording
            else if(is_recording[i]) {
                countdown_text[i].text("");  // Hide countdown
                
                (now / second) % 0.5 => float blink;
                if(blink < 0.25) {
                    playhead[i].color(@(1.0, 0.0, 0.0));
                } else {
                    playhead[i].color(@(0.3, 0.3, 0.3));
                }
            } else {
                countdown_text[i].text("");  // Hide countdown
                
                // Restore normal colors
                if(i == 0) {
                    playhead[i].color(@(1.0, 0.3, 0.3));
                    track_bg[i].color(@(0.2, 0.1, 0.1));
                }
                else if(i == 1) {
                    playhead[i].color(@(0.3, 1.0, 0.3));
                    track_bg[i].color(@(0.1, 0.2, 0.1));
                }
                else if(i == 2) {
                    playhead[i].color(@(1.0, 1.0, 0.3));
                    track_bg[i].color(@(0.2, 0.2, 0.1));
                }
            }
        }
    }
}

// === MIDI SETUP ===
MidiIn min;
MidiMsg msg;

<<< "=====================================================" >>>;
<<< "ChucK Multi-Track Looper - Grid Visualization" >>>;
<<< "=====================================================" >>>;
<<< "Scanning MIDI devices..." >>>;

if(min.num() == 0) {
    <<< "ERROR: No MIDI devices found!" >>>;
    me.exit();
}

if(!min.open(MIDI_DEVICE)) {
    <<< "ERROR: Failed to open MIDI device", MIDI_DEVICE >>>;
    me.exit();
}

<<< "Opened MIDI device:", min.name() >>>;
<<< "Tracks:", NUM_TRACKS >>>;
<<< "BPM:", bpm >>>;
<<< "Time signature:", beats_per_measure + "/4" >>>;
<<< "" >>>;
<<< "MIDI Mapping:" >>>;
<<< "  RECORD (toggle): C1 (36) | C#1 (37) | D1 (38)" >>>;
<<< "  CLEAR:           E1 (40) | F1 (41)  | F#1 (42)" >>>;
<<< "  Volume:          CC 45-47" >>>;
<<< "  BPM:             CC 48" >>>;
<<< "" >>>;
<<< "Recording: Quantized to bars (bar-aligned sync)" >>>;
<<< "SYNC MODE: First track sets master loop length" >>>;
<<< "           All tracks sync to same length" >>>;
<<< "           Clear all tracks to reset master loop" >>>;
<<< "=====================================================" >>>;

// === MIDI LISTENER ===
int ignore_cc[128];
for(0 => int i; i < 32; i++) 1 => ignore_cc[i];
0 => ignore_cc[CC_VOLUME_TRACK_0];
0 => ignore_cc[CC_VOLUME_TRACK_1];
0 => ignore_cc[CC_VOLUME_TRACK_2];
0 => ignore_cc[CC_BPM];

fun void midiListener() {
    while(true) {
        min => now;
        
        while(min.recv(msg)) {
            msg.data1 => int status;
            msg.data2 => int data1;
            msg.data3 => int data2;
            status & 0xF0 => int messageType;
            
            // CC Messages
            if(messageType == 0xB0) {
                if(ignore_cc[data1]) continue;
                
                if(data1 == CC_VOLUME_TRACK_0) setTrackVolume(0, data2 / 127.0);
                else if(data1 == CC_VOLUME_TRACK_1) setTrackVolume(1, data2 / 127.0);
                else if(data1 == CC_VOLUME_TRACK_2) setTrackVolume(2, data2 / 127.0);
                else if(data1 == CC_BPM) {
                    30.0 + (data2 / 127.0 * 270.0) => float new_bpm;
                    setBPM(new_bpm);
                }
            }
            
            // Note ON
            else if(messageType == 0x90 && data2 > 0) {
                if(data1 == NOTE_RECORD_TRACK_0) toggleRecording(0);
                else if(data1 == NOTE_RECORD_TRACK_1) toggleRecording(1);
                else if(data1 == NOTE_RECORD_TRACK_2) toggleRecording(2);
                else if(data1 == NOTE_CLEAR_TRACK_0) clearTrack(0);
                else if(data1 == NOTE_CLEAR_TRACK_1) clearTrack(1);
                else if(data1 == NOTE_CLEAR_TRACK_2) clearTrack(2);
            }
        }
    }
}

// === MAIN PROGRAM ===
spork ~ midiListener();
spork ~ visualizationLoop();

while(true) {
    1::second => now;
}

