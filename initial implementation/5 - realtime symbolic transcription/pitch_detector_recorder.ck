//---------------------------------------------------------------------
// name: pitch_detector_recorder.ck
// desc: Real-time pitch detection with MIDI data recording
//       Captures pitches, durations, and silences as symbolic MIDI data
//       Saves to JSON format for easy parsing
//
// Usage: Run the script, perform into microphone, press Ctrl+C to stop
//        Output will be saved to "midi_recording.json"
//---------------------------------------------------------------------

// Square wave synthesizer setup
SqrOsc square => ADSR env => Gain output_gain => JCRev rev => dac;
0.3 => output_gain.gain;
0.1 => rev.mix;
0.0 => square.gain;

// ADSR envelope
env.set(10::ms, 50::ms, 0.7, 100::ms);

// Microphone input setup
adc => Gain input_gain => blackhole;
2.0 => input_gain.gain;

// Analysis chain
adc => Flip flip =^ AutoCorr autocorr => blackhole;
adc => Flip flip_rms =^ RMS rms => blackhole;

// Analysis parameters
1024 => int FRAME_SIZE;
FRAME_SIZE => flip.size => flip_rms.size;
Windowing.hann(FRAME_SIZE) => flip.window;
Windowing.hann(FRAME_SIZE) => flip_rms.window;
FRAME_SIZE/4 => int HOP_SIZE;
HOP_SIZE::samp => dur HOP;

// Pitch detection parameters
0.009 => float AMPLITUDE_THRESHOLD;
44100.0 => float SAMPLE_RATE;
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
float note_midi_numbers[0];    // MIDI note numbers
dur note_start_times[0];       // When each note started
dur note_durations[0];         // Duration of each note
float note_velocities[0];      // Velocity (based on amplitude)

// Current note tracking
0.0 => float current_midi_note;
now => time current_note_start;
0.0 => float current_velocity;

// Recording state
now => time recording_start_time;
1 => int is_recording;

// Minimum note duration to filter out noise
50::ms => dur MIN_NOTE_DURATION;

// File output
"midi_recording.txt" => string OUTPUT_FILE;

// Open file for writing (in append mode so we can write as we go)
FileIO fout;
fout.open(OUTPUT_FILE, FileIO.WRITE);

if(!fout.good()) {
    <<< "ERROR: Could not open file for writing!" >>>;
    me.exit();
}

<<< "Opened file for writing:", OUTPUT_FILE >>>;

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

// Function to save the current note (writes immediately to file)
fun void saveCurrentNote() {
    if(note_playing) {
        now - current_note_start => dur note_length;
        
        // Only save notes longer than minimum duration
        if(note_length >= MIN_NOTE_DURATION) {
            // Add to arrays (for counting)
            note_midi_numbers << current_midi_note;
            note_start_times << (current_note_start - recording_start_time);
            note_durations << note_length;
            note_velocities << current_velocity;
            
            // Write immediately to file (so it's saved even if we Ctrl+C)
            current_midi_note $ int => int midi_note;
            Std.mtof(midi_note) => float frequency;
            current_velocity => float velocity;
            (current_note_start - recording_start_time)/second => float start_time;
            note_length/second => float duration;
            
            // Write line: midi,frequency,velocity,start_time,duration
            fout.write(midi_note + "," + frequency + "," + velocity + "," + start_time + "," + duration + "\n");
            
            <<< "Saved note: MIDI", current_midi_note, 
                "Duration:", note_length/second, "sec",
                "Velocity:", current_velocity >>>;
        }
    }
}

// Let initial buffer fill
FRAME_SIZE::samp => now;

<<< "=== Real-time Pitch Detector + MIDI Recorder ===" >>>;
<<< "Speak or sing into your microphone..." >>>;
<<< "Recording will be saved to:", OUTPUT_FILE >>>;
<<< "Press Ctrl+C to stop and save" >>>;
<<< "Amplitude threshold:", AMPLITUDE_THRESHOLD >>>;
<<< "Minimum note duration:", MIN_NOTE_DURATION/ms, "ms" >>>;
<<< "" >>>;

// Main analysis loop
while(is_recording) 
{
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
            
            // Round to nearest semitone for cleaner MIDI output
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
                
                <<< "New note: MIDI", current_midi_note, 
                    "Freq:", detected_freq, "Hz",
                    "Velocity:", current_velocity >>>;
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
    
    HOP => now;
}

// Save final note and close file
saveCurrentNote();
fout.close();

<<< "\n=== Recording Complete ===" >>>;
<<< "Total notes recorded:", note_midi_numbers.size() >>>;
<<< "Output file:", OUTPUT_FILE >>>;
<<< "Format: MIDI_NOTE,FREQUENCY,VELOCITY,START_TIME,DURATION" >>>;

