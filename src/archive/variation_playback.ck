//---------------------------------------------------------------------
// name: variation_playback.ck
// desc: Plays back AI-generated MIDI variations from CHULOOPA
//       Can loop variations and blend between them
//
// Usage:
//   chuck src/variation_playback.ck:variation_0_midi.txt
//   chuck src/variation_playback.ck:variation_0_midi.txt:sine
//   chuck src/variation_playback.ck:variation_0_midi.txt:mandolin:loop
//
// Arguments:
//   arg 0: MIDI file to play (default: variation_0_midi.txt)
//   arg 1: Synth type: sine, square, saw, mandolin, flute, brass (default: sine)
//   arg 2: loop (optional - if present, loops the variation)
//---------------------------------------------------------------------

// === PARSE ARGUMENTS ===
me.arg(0) => string input_file;
me.arg(1) => string synth_type;
me.arg(2) => string loop_mode;

if(input_file == "" || input_file == "variation_playback.ck") {
    "variation_0_midi.txt" => input_file;
}
if(synth_type == "") {
    "sine" => synth_type;
}

0 => int should_loop;
if(loop_mode == "loop") {
    1 => should_loop;
}

<<< "" >>>;
<<< "╔═══════════════════════════════════════════════════╗" >>>;
<<< "║         CHULOOPA VARIATION PLAYBACK             ║" >>>;
<<< "╚═══════════════════════════════════════════════════╝" >>>;
<<< "" >>>;
<<< "Input file:", input_file >>>;
<<< "Synthesizer:", synth_type >>>;
<<< "Loop mode:", should_loop >>>;
<<< "" >>>;

// === SYNTHESIS SETUP ===
// Support multiple synthesis types
SinOsc sine_osc;
SqrOsc square_osc;
SawOsc saw_osc;
Mandolin mandolin_osc;
Flute flute_osc;
Brass brass_osc;

ADSR env;
Gain output;
JCRev rev;

// Connect to output
output => rev => dac;

// Connect chosen oscillator/instrument
if(synth_type == "square") {
    square_osc => env;
} else if(synth_type == "saw") {
    saw_osc => env;
} else if(synth_type == "mandolin") {
    mandolin_osc => env;
} else if(synth_type == "flute") {
    flute_osc => env;
} else if(synth_type == "brass") {
    brass_osc => env;
} else {
    sine_osc => env;
    "sine" => synth_type;  // Force default
}

env => output;

// Set parameters
0.4 => output.gain;
0.15 => rev.mix;

// Envelope for smooth notes
env.set(20::ms, 50::ms, 0.8, 150::ms);

// === DATA STRUCTURES ===
float midi_notes[0];
float start_times[0];
float durations[0];
float velocities[0];

// === LOAD MIDI DATA ===
fun int loadMidiData(string filename) {
    FileIO fin;
    fin.open(filename, FileIO.READ);

    if(!fin.good()) {
        <<< "ERROR: Could not open file:", filename >>>;
        return 0;
    }

    <<< "Loading MIDI data..." >>>;

    while(fin.more()) {
        fin.readLine() => string line;

        // Skip comments and empty lines
        if(line.length() == 0 || line.substring(0, 1) == "#") {
            continue;
        }

        // Parse CSV
        parseCSVLine(line);
    }

    fin.close();

    <<< "Loaded", midi_notes.size(), "notes" >>>;
    return 1;
}

fun void parseCSVLine(string line) {
    string parts[5];
    0 => int part_index;
    "" => string current;

    for(0 => int i; i < line.length(); i++) {
        line.substring(i, 1) => string char;

        if(char == ",") {
            current => parts[part_index];
            part_index++;
            "" => current;
        } else {
            current + char => current;
        }
    }
    current => parts[part_index];

    if(part_index >= 4) {
        midi_notes << Std.atof(parts[0]);
        velocities << Std.atof(parts[2]);
        start_times << Std.atof(parts[3]);
        durations << Std.atof(parts[4]);
    }
}

// === PLAYBACK FUNCTIONS ===
fun void playNote(float midi, float velocity, float duration) {
    // Convert MIDI to frequency
    Std.mtof(midi $ int) => float freq;

    // Set frequency based on synth type
    if(synth_type == "square") {
        freq => square_osc.freq;
    } else if(synth_type == "saw") {
        freq => saw_osc.freq;
    } else if(synth_type == "mandolin") {
        freq => mandolin_osc.freq;
        velocity / 127.0 => mandolin_osc.noteOn;
    } else if(synth_type == "flute") {
        freq => flute_osc.freq;
        velocity / 127.0 => flute_osc.noteOn;
    } else if(synth_type == "brass") {
        freq => brass_osc.freq;
        velocity / 127.0 => brass_osc.noteOn;
    } else {
        freq => sine_osc.freq;
    }

    // Set gain based on velocity
    ((velocity - 27.0) / 100.0) * 0.8 => float gain;
    Math.max(0.1, Math.min(1.0, gain)) => output.gain;

    // Trigger envelope
    env.keyOn();

    // Hold for duration
    Math.max(0.05, duration - 0.15) => float hold_time;
    hold_time::second => now;

    // Release
    env.keyOff();
    0.01::second => now;
}

fun void playSequence() {
    if(midi_notes.size() == 0) {
        <<< "No notes to play!" >>>;
        return;
    }

    <<< "Starting playback..." >>>;
    <<< "Press Ctrl+C to stop" >>>;
    <<< "" >>>;

    now => time playback_start;

    for(0 => int i; i < midi_notes.size(); i++) {
        // Wait until it's time to play this note
        playback_start + start_times[i]::second => time note_time;
        note_time - now => dur wait_time;

        if(wait_time > 0::second) {
            wait_time => now;
        }

        // Play the note
        playNote(midi_notes[i], velocities[i], durations[i]);

        <<< "Note", i+1, "/", midi_notes.size(),
            "| MIDI:", midi_notes[i],
            "| Duration:", durations[i], "sec" >>>;
    }

    <<< "" >>>;
    <<< "Sequence complete!" >>>;
}

fun void playLooped() {
    if(midi_notes.size() == 0) {
        <<< "No notes to play!" >>>;
        return;
    }

    // Calculate total duration
    0.0 => float total_duration;
    for(0 => int i; i < start_times.size(); i++) {
        if(start_times[i] + durations[i] > total_duration) {
            start_times[i] + durations[i] => total_duration;
        }
    }

    <<< "Total duration:", total_duration, "seconds" >>>;
    <<< "Starting looped playback..." >>>;
    <<< "Press Ctrl+C to stop" >>>;
    <<< "" >>>;

    1 => int loop_count;

    while(true) {
        <<< "=== Loop", loop_count, "===" >>>;
        now => time loop_start;

        for(0 => int i; i < midi_notes.size(); i++) {
            loop_start + start_times[i]::second => time note_time;
            note_time - now => dur wait_time;

            if(wait_time > 0::second) {
                wait_time => now;
            }

            playNote(midi_notes[i], velocities[i], durations[i]);
        }

        // Wait for loop to complete
        loop_start + total_duration::second => time loop_end;
        loop_end - now => dur remaining;

        if(remaining > 0::second) {
            remaining => now;
        }

        loop_count++;
    }
}

// === MAIN PROGRAM ===
if(loadMidiData(input_file)) {
    <<< "" >>>;

    if(should_loop) {
        playLooped();
    } else {
        playSequence();

        // Let final note ring out
        0.2::second => now;
    }

    <<< "" >>>;
    <<< "╔═══════════════════════════════════════════════════╗" >>>;
    <<< "║              PLAYBACK COMPLETE                  ║" >>>;
    <<< "╚═══════════════════════════════════════════════════╝" >>>;
    <<< "" >>>;
} else {
    <<< "Failed to load MIDI data!" >>>;
    <<< "" >>>;
}
