//---------------------------------------------------------------------
// name: pitch_detector_file.ck
// desc: Pitch detection from audio FILE with MIDI data recording
//       Processes a WAV file and extracts symbolic MIDI data
//
// Usage: chuck pitch_detector_file.ck:input.wav:output.json
//        Example: chuck pitch_detector_file.ck:"my_audio.wav":"my_midi.json"
//
// If no arguments provided, uses defaults:
//   Input: "input.wav"
//   Output: "midi_from_file.json"
//---------------------------------------------------------------------

// Get command line arguments
me.arg(0) => string input_file;
me.arg(1) => string output_file;

// Set defaults if no arguments provided
if(input_file == "" || input_file == "pitch_detector_file.ck") {
    "input.wav" => input_file;
}
if(output_file == "") {
    "midi_from_file.txt" => output_file;
}

<<< "=== Audio File to MIDI Transcription ===" >>>;
<<< "Input file:", input_file >>>;
<<< "Output file:", output_file >>>;
<<< "" >>>;

// Audio file reader
SndBuf file_input => blackhole;

// Try to load the file
file_input.read(input_file);

// Check if file loaded successfully
if(file_input.samples() == 0) {
    <<< "ERROR: Could not load audio file:", input_file >>>;
    <<< "Please check that:" >>>;
    <<< "  1. The file exists" >>>;
    <<< "  2. The file is a valid WAV format" >>>;
    <<< "  3. The path is correct" >>>;
    me.exit();
}

<<< "File loaded successfully!" >>>;
<<< "Duration:", file_input.length()/second, "seconds" >>>;
<<< "Samples:", file_input.samples() >>>;
<<< "Channels:", file_input.channels() >>>;
<<< "" >>>;

// Reset playback to beginning
0 => file_input.pos;
1.0 => file_input.gain;
0 => file_input.loop; // Don't loop

// Optional: Monitor the audio while processing
// Uncomment the next line to hear the file during processing
// file_input => dac;

// Square wave synthesizer for audio feedback (optional)
SqrOsc square => ADSR env => Gain output_gain => JCRev rev => dac;
0.3 => output_gain.gain;
0.1 => rev.mix;
0.0 => square.gain;
env.set(10::ms, 50::ms, 0.7, 100::ms);

// Analysis chain for pitch detection
file_input => Flip flip =^ AutoCorr autocorr => blackhole;

// Separate chain for amplitude detection  
file_input => Flip flip_rms =^ RMS rms => blackhole;

// Analysis parameters
1024 => int FRAME_SIZE;
FRAME_SIZE => flip.size => flip_rms.size;

// Set window for better analysis
Windowing.hann(FRAME_SIZE) => flip.window;
Windowing.hann(FRAME_SIZE) => flip_rms.window;

// Hop size (how often to analyze)
FRAME_SIZE/4 => int HOP_SIZE;
HOP_SIZE::samp => dur HOP;

// Pitch detection parameters
0.009 => float AMPLITUDE_THRESHOLD;
44100.0 => float SAMPLE_RATE; // Chuck's sample rate
1 => autocorr.normalize;

// Synthesis control variables
0 => int note_playing;
0.0 => float current_freq;
0.0 => float target_freq;
0.0 => float current_volume;
0.0 => float target_volume;

// Volume mapping parameters
AMPLITUDE_THRESHOLD => float MIN_AMPLITUDE;
0.2 => float MAX_AMPLITUDE;
0.1 => float MIN_VOLUME;
0.8 => float MAX_VOLUME;

// ============ MIDI RECORDING DATA STRUCTURES ============

// Arrays to store note events
float note_midi_numbers[0];
dur note_start_times[0];
dur note_durations[0];
float note_velocities[0];

// Current note tracking
0.0 => float current_midi_note;
now => time current_note_start;
0.0 => float current_velocity;

// Recording state
now => time recording_start_time;
1 => int is_recording;

// Minimum note duration to filter out noise
50::ms => dur MIN_NOTE_DURATION;

// Function to map amplitude to volume
fun float mapAmplitudeToVolume(float amplitude) {
    Math.max(MIN_AMPLITUDE, Math.min(MAX_AMPLITUDE, amplitude)) => float clamped_amp;
    (clamped_amp - MIN_AMPLITUDE) / (MAX_AMPLITUDE - MIN_AMPLITUDE) => float normalized;
    Math.sqrt(normalized) => float curved;
    return MIN_VOLUME + (curved * (MAX_VOLUME - MIN_VOLUME));
}

// Function to map amplitude to MIDI velocity (0-127)
fun int mapAmplitudeToVelocity(float amplitude) {
    Math.max(MIN_AMPLITUDE, Math.min(MAX_AMPLITUDE, amplitude)) => float clamped_amp;
    (clamped_amp - MIN_AMPLITUDE) / (MAX_AMPLITUDE - MIN_AMPLITUDE) => float normalized;
    return (normalized * 100 + 27) $ int; // Range: 27-127
}

// Function to save the current note
fun void saveCurrentNote() {
    if(note_playing) {
        now - current_note_start => dur note_length;
        
        // Only save notes longer than minimum duration
        if(note_length >= MIN_NOTE_DURATION) {
            note_midi_numbers << current_midi_note;
            note_start_times << (current_note_start - recording_start_time);
            note_durations << note_length;
            note_velocities << current_velocity;
            
            <<< "Saved note: MIDI", current_midi_note, 
                "Duration:", note_length/second, "sec",
                "Velocity:", current_velocity >>>;
        }
    }
}

// Function to write simple text output
fun void writeTextOutput() {
    <<< "\n=== Writing MIDI data to", output_file, "===" >>>;
    
    FileIO fout;
    fout.open(output_file, FileIO.WRITE);
    
    if(!fout.good()) {
        <<< "Error: Could not open file for writing!" >>>;
        return;
    }
    
    // Write each note as: MIDI_NOTE,FREQUENCY,VELOCITY,START_TIME,DURATION
    for(0 => int i; i < note_midi_numbers.size(); i++) {
        note_midi_numbers[i] $ int => int midi_note;
        Std.mtof(midi_note) => float frequency;
        note_velocities[i] => float velocity;
        note_start_times[i]/second => float start_time;
        note_durations[i]/second => float duration;
        
        // Write line: midi,frequency,velocity,start_time,duration
        fout.write(midi_note + "," + frequency + "," + velocity + "," + start_time + "," + duration + "\n");
    }
    
    fout.close();
    <<< "Successfully wrote", note_midi_numbers.size(), "notes to", output_file >>>;
}

// Let initial buffer fill
FRAME_SIZE::samp => now;

<<< "Starting analysis..." >>>;
<<< "Amplitude threshold:", AMPLITUDE_THRESHOLD >>>;
<<< "Minimum note duration:", MIN_NOTE_DURATION/ms, "ms" >>>;
<<< "" >>>;

// Calculate total frames to process
file_input.samples() => int total_samples;
(total_samples / HOP_SIZE) $ int => int total_hops;
0 => int current_hop;

// Progress reporting
10 => int progress_percent_step;
0 => int last_reported_percent;

// Main analysis loop - process until file ends
while(file_input.pos() < file_input.samples() - 1 && is_recording) 
{
    // Progress reporting
    current_hop++;
    (current_hop * 100.0 / total_hops) $ int => int current_percent;
    if(current_percent >= last_reported_percent + progress_percent_step) {
        current_percent => last_reported_percent;
        <<< "Progress:", current_percent, "%" >>>;
    }
    
    // Get current amplitude level
    rms.upchuck();
    rms.fval(0) => float amplitude;
    
    // Only detect pitch if amplitude is above threshold
    if(amplitude > AMPLITUDE_THRESHOLD) 
    {
        // Perform autocorrelation analysis
        autocorr.upchuck();
        autocorr.fvals() @=> float correlation[];
        
        // Find the peak in autocorrelation
        0.0 => float max_corr;
        0 => int best_lag;
        
        Math.max(20, SAMPLE_RATE/800) $ int => int min_lag;
        Math.min(correlation.size()-1, SAMPLE_RATE/80) $ int => int max_lag;
        
        for(min_lag => int lag; lag <= max_lag; lag++) 
        {
            if(correlation[lag] > max_corr) 
            {
                correlation[lag] => max_corr;
                lag => best_lag;
            }
        }
        
        // Convert lag to frequency if we found a good peak
        if(max_corr > 0.3 && best_lag > 0)
        {
            SAMPLE_RATE / best_lag => float detected_freq;
            12.0 * Math.log2(detected_freq / 440.0) + 69.0 => float detected_midi;
            
            // Round to nearest semitone
            Math.round(detected_midi) => float rounded_midi;
            
            detected_freq => target_freq;
            mapAmplitudeToVolume(amplitude) => target_volume;
            
            // Check if this is a new note (different pitch)
            if(!note_playing || Math.fabs(rounded_midi - current_midi_note) >= 1.0) 
            {
                // Save previous note if one was playing
                saveCurrentNote();
                
                // Start new note
                rounded_midi => current_midi_note;
                now => current_note_start;
                mapAmplitudeToVelocity(amplitude) => current_velocity;
                
                target_freq => square.freq;
                target_freq => current_freq;
                target_volume => square.gain;
                target_volume => current_volume;
                env.keyOn();
                1 => note_playing;
            }
            else
            {
                // Continue current note with smooth transitions
                current_freq + (target_freq - current_freq) * 0.1 => current_freq;
                current_freq => square.freq;
                current_volume + (target_volume - current_volume) * 0.3 => current_volume;
                current_volume => square.gain;
            }
        }
    }
    else 
    {
        // No signal - end current note if playing
        if(note_playing) {
            saveCurrentNote();
            env.keyOff();
            0 => note_playing;
        }
    }
    
    // Advance time
    HOP => now;
}

// Save final note and write output
saveCurrentNote();
writeTextOutput();

<<< "\n=== Processing Complete ===" >>>;
<<< "Total notes recorded:", note_midi_numbers.size() >>>;
<<< "Input file:", input_file >>>;
<<< "Output file:", output_file >>>;
<<< "" >>>;
<<< "Format: MIDI_NOTE, FREQUENCY, VELOCITY, START_TIME, DURATION" >>>;

