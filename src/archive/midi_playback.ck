//---------------------------------------------------------------------
// name: midi_playback.ck
// desc: Plays back symbolic MIDI data from text file
//       Reads text files created by pitch_detector scripts and performs them
//
// Usage: chuck midi_playback.ck:output.txt
//        chuck midi_playback.ck:output.txt:sine (use sine wave)
//        chuck midi_playback.ck:output.txt:square (use square wave)
//        chuck midi_playback.ck:output.txt:saw (use sawtooth)
//
// If no arguments provided, uses "midi_recording.txt" with sine wave
//---------------------------------------------------------------------

// Get command line arguments
me.arg(0) => string input_file;
me.arg(1) => string synth_type;

// Set defaults if no arguments provided
if(input_file == "" || input_file == "midi_playback.ck") {
    "midi_recording.txt" => input_file;
}
if(synth_type == "") {
    "sine" => synth_type;
}

<<< "=== MIDI Playback from Text File ===" >>>;
<<< "Input file:", input_file >>>;
<<< "Synthesizer:", synth_type >>>;
<<< "" >>>;

// Create synthesis chain components
SinOsc sine_osc;
SqrOsc square_osc;
SawOsc saw_osc;
ADSR env;
Gain output;
JCRev rev;

// Connect to output
output => rev => dac;

// Connect the chosen oscillator
Osc @ osc;
if(synth_type == "square") {
    square_osc => env;
    square_osc @=> osc;
} else if(synth_type == "saw") {
    saw_osc => env;
    saw_osc @=> osc;
} else {
    sine_osc => env;
    sine_osc @=> osc;
}

// Connect envelope to output
env => output;

// Set parameters
0.4 => output.gain;
0.15 => rev.mix;

// Envelope for smooth notes
env.set(20::ms, 50::ms, 0.8, 150::ms);

// Read text file
FileIO fin;
fin.open(input_file, FileIO.READ);

if(!fin.good()) {
    <<< "ERROR: Could not open file:", input_file >>>;
    me.exit();
}

<<< "Reading text file..." >>>;

// Arrays to store note data
float note_midi_numbers[0];
float note_start_times[0];
float note_durations[0];
float note_velocities[0];

// Parse text file: each line is "MIDI_NOTE, FREQUENCY, VELOCITY, START_TIME, DURATION"
while(fin.more()) {
    fin.readLine() => string line;
    
    // Skip empty lines
    if(line.length() == 0) {
        continue;
    }
    
    // Parse comma-separated values
    parseCSVLine(line, note_midi_numbers, note_start_times, note_durations, note_velocities);
}
fin.close();

// Function to parse a CSV line and add to arrays
fun void parseCSVLine(string line, float midi_notes[], float start_times[], float durations[], float velocities[]) {
    // Split by comma
    string parts[5];
    0 => int part_index;
    "" => string current;

    <<< "line length:", line.length() >>>;
    
    // Manual string splitting by comma
    for(0 => int i; i < line.length(); i++) {
        line.substring(i, 1) => string char;
        
        if(char == ",") {
            <<< "current:", current >>>;
            current => parts[part_index];
            part_index++;
            "" => current;
        } else {
            current + char => current;
        }
    }
    // Add last part
    current => parts[part_index];
    
    // Parse values and convert
    if(part_index >= 4) {
        Std.atof(parts[0]) => float midi;
        // parts[1] is frequency (we'll recalculate it, so skip)
        Std.atof(parts[2]) => float velocity;
        Std.atof(parts[3]) => float start;
        Std.atof(parts[4]) => float duration;
        
        // Add to arrays
        midi_notes << midi;
        start_times << start;
        durations << duration;
        velocities << velocity;
    }
}

<<< "Parsed", note_midi_numbers.size(), "notes from text file" >>>;

if(note_midi_numbers.size() == 0) {
    <<< "ERROR: No notes found in file!" >>>;
    me.exit();
}

<<< "" >>>;
<<< "Starting playback..." >>>;
<<< "Press Ctrl+C to stop" >>>;
<<< "" >>>;

// Playback loop
now => time playback_start;

for(0 => int i; i < note_midi_numbers.size(); i++) {
    // Wait until it's time to play this note
    playback_start + note_start_times[i]::second => time note_time;
    note_time - now => dur wait_time;
    
    if(wait_time > 0::second) {
        wait_time => now;
    }
    
    // Convert MIDI to frequency
    Std.mtof(note_midi_numbers[i] $ int) => float freq;
    freq => osc.freq;
    
    // Set gain based on velocity (velocity is 27-127, normalize to 0.0-1.0)
    ((note_velocities[i] - 27.0) / 100.0) * 0.8 => float gain;
    Math.max(0.1, Math.min(1.0, gain)) => output.gain;
    
    // Trigger note
    env.keyOn();
    
    <<< "Note", i+1, "/", note_midi_numbers.size(), 
        "| MIDI:", note_midi_numbers[i], 
        "| Freq:", freq, "Hz",
        "| Duration:", note_durations[i], "sec",
        "| Velocity:", note_velocities[i] >>>;
    
    // Hold for duration (minus release time)
    Math.max(0.05, note_durations[i] - 0.15) => float hold_time;
    hold_time::second => now;
    
    // Release
    env.keyOff();
    
    // Let release complete before next note if needed
    0.01::second => now;
}

// Let final note ring out
0.2::second => now;

<<< "" >>>;
<<< "=== Playback Complete ===" >>>;
<<< "Played", note_midi_numbers.size(), "notes" >>>;

