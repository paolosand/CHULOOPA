//---------------------------------------------------------------------
// name: looper_gui_vocoder.ck
// desc: ChuGL GUI for vocoder multi-track looper
//       Provides independent controls for each track including instrument selection
//
// Usage:
//    Run alongside looper_vocoder.ck:
//    chuck looper_vocoder.ck looper_gui_vocoder.ck
//---------------------------------------------------------------------

// Setup GWindow
GWindow.windowed(550, 650);
GWindow.center();
GWindow.title("ChucK Vocoder Multi-Track Looper");

// === CONFIGURATION ===
3 => int NUM_TRACKS;

// OSC client for sending messages to looper
OscOut xmit;
xmit.dest("127.0.0.1", 6450);

// OSC receiver for tempo pulses and track state from looper
OscIn oin;
OscMsg msg;
6451 => int OSC_IN_PORT;
OSC_IN_PORT => oin.port;
oin.listenAll();

// === STATE TRACKING (per track) ===
int is_recording[NUM_TRACKS];
int is_playing[NUM_TRACKS];
int waiting_to_record[NUM_TRACKS];
int has_loop[NUM_TRACKS];
float volume[NUM_TRACKS];
int track_instrument[NUM_TRACKS];

// Initialize track states
for(0 => int i; i < NUM_TRACKS; i++) {
    0 => is_recording[i];
    0 => is_playing[i];
    0 => waiting_to_record[i];
    0 => has_loop[i];
    0.7 => volume[i];
    1 => track_instrument[i];  // Default to sine
}

// === GLOBAL STATE ===
120.0 => float bpm;
["", "Sine", "Square", "Mandolin", "Flute", "Brass", "HnkyTonk"] @=> string instrument_names[];

// Tempo visual state
0 => int beat_on;
0 => int current_beat;

// === OSC SEND FUNCTIONS ===

fun void startRecording(int track) {
    xmit.start("/loop/record");
    xmit.add(track);
    xmit.add(1);
    xmit.send();
    <<< "GUI: Track", track, "start recording (waiting for measure)" >>>;
}

fun void stopRecording(int track) {
    xmit.start("/loop/record");
    xmit.add(track);
    xmit.add(0);
    xmit.send();
    <<< "GUI: Track", track, "stop recording" >>>;
}

fun void clearTrack(int track) {
    xmit.start("/loop/clear");
    xmit.add(track);
    xmit.send();
    <<< "GUI: Track", track, "clear" >>>;
}

fun void setTrackVolume(int track, float vol) {
    vol => volume[track];
    xmit.start("/loop/volume");
    xmit.add(track);
    xmit.add(vol);
    xmit.send();
}

fun void setTrackInstrument(int track, int inst) {
    if(inst >= 1 && inst <= 6) {
        inst => track_instrument[track];
        xmit.start("/loop/instrument");
        xmit.add(track);
        xmit.add(inst);
        xmit.send();
        <<< "GUI: Track", track, "instrument:", instrument_names[inst] >>>;
    }
}

fun void setBPM(float new_bpm) {
    Math.max(30.0, Math.min(300.0, new_bpm)) => bpm;
    xmit.start("/loop/bpm");
    xmit.add(bpm);
    xmit.send();
    <<< "GUI: BPM set to", bpm >>>;
}

// === OSC LISTENER ===
fun void oscListener() {
    while(true) {
        oin => now;
        while(oin.recv(msg)) {
            // Tempo beat
            if(msg.address == "/tempo/beat") {
                1 => beat_on;
                msg.getInt(0) => current_beat;
                spork ~ beatFlash();
            }

            // Track state update
            else if(msg.address == "/track/state") {
                msg.getInt(0) => int track;
                msg.getInt(1) => is_recording[track];
                msg.getInt(2) => is_playing[track];
                msg.getInt(3) => waiting_to_record[track];
                msg.getInt(4) => track_instrument[track];

                if(is_playing[track]) {
                    1 => has_loop[track];
                }
                if(!is_playing[track] && !is_recording[track] && !waiting_to_record[track]) {
                    0 => has_loop[track];
                }
            }
        }
    }
}

fun void beatFlash() {
    50::ms => now;
    0 => beat_on;
}

<<< "ChucK Vocoder Multi-Track Looper GUI Started" >>>;
<<< "OSC sending to localhost:6450" >>>;
<<< "OSC receiving on localhost:6451" >>>;
<<< "Number of tracks:", NUM_TRACKS >>>;

spork ~ oscListener();

// === MAIN GUI LOOP ===
while(true) {
    if(UI.begin("Vocoder Multi-Track Looper")) {

        UI.text("Vocoder Multi-Track Looper");
        UI.separator();
        UI.spacing();

        // === TEMPO SECTION ===
        UI.text("Tempo:");
        UI.spacing();

        // Tempo indicator
        if(beat_on) {
            if(current_beat == 0) {
                UI.pushStyleColor(UI_Color.Button, @(1.0, 0.3, 0.3, 1.0));
            } else {
                UI.pushStyleColor(UI_Color.Button, @(0.3, 1.0, 0.3, 1.0));
            }
            UI.pushStyleColor(UI_Color.ButtonHovered, @(0.3, 1.0, 0.3, 1.0));
        } else {
            UI.pushStyleColor(UI_Color.Button, @(0.3, 0.3, 0.3, 1.0));
            UI.pushStyleColor(UI_Color.ButtonHovered, @(0.3, 0.3, 0.3, 1.0));
        }

        UI.button("●");
        UI.popStyleColor(2);

        UI.sameLine();
        UI.text("BPM: " + (bpm $ int));

        // BPM controls
        if(UI.button("-5##bpm")) {
            setBPM(bpm - 5);
        }
        UI.sameLine();

        if(UI.button("-1##bpm")) {
            setBPM(bpm - 1);
        }
        UI.sameLine();

        if(UI.button("+1##bpm")) {
            setBPM(bpm + 1);
        }
        UI.sameLine();

        if(UI.button("+5##bpm")) {
            setBPM(bpm + 5);
        }

        UI.spacing();
        UI.separator();
        UI.spacing();

        // === TRACK CONTROLS ===
        for(0 => int track; track < NUM_TRACKS; track++) {
            // Track header
            UI.text("Track " + (track + 1) + ":");
            UI.spacing();

            // Status indicator
            if(waiting_to_record[track]) {
                UI.textColored(@(1.0, 0.7, 0.0, 1.0), "⏱ WAITING...");
            } else if(is_recording[track]) {
                UI.textColored(@(1.0, 0.2, 0.2, 1.0), "● RECORDING");
            } else if(is_playing[track]) {
                UI.textColored(@(0.2, 0.8, 0.2, 1.0), "▶ PLAYING");
            } else {
                UI.textColored(@(0.5, 0.5, 0.5, 1.0), "○ Empty");
            }

            UI.spacing();

            // Instrument display and selection
            UI.text("Instrument: " + instrument_names[track_instrument[track]]);

            // Instrument buttons (compact layout)
            if(UI.button("1##inst" + track)) setTrackInstrument(track, 1);
            UI.sameLine();
            if(UI.button("2##inst" + track)) setTrackInstrument(track, 2);
            UI.sameLine();
            if(UI.button("3##inst" + track)) setTrackInstrument(track, 3);
            UI.sameLine();
            if(UI.button("4##inst" + track)) setTrackInstrument(track, 4);
            UI.sameLine();
            if(UI.button("5##inst" + track)) setTrackInstrument(track, 5);
            UI.sameLine();
            if(UI.button("6##inst" + track)) setTrackInstrument(track, 6);

            UI.spacing();

            // Record button
            if(waiting_to_record[track]) {
                // Waiting - show Cancel button (orange/yellow)
                UI.pushStyleColor(UI_Color.Button, @(1.0, 0.7, 0.0, 1.0));
                UI.pushStyleColor(UI_Color.ButtonHovered, @(1.0, 0.8, 0.2, 1.0));

                if(UI.button("Cancel##track" + track)) {
                    clearTrack(track);
                }

                UI.popStyleColor(2);
            } else if(is_recording[track]) {
                // Recording - show Stop button
                UI.pushStyleColor(UI_Color.Button, @(0.8, 0.2, 0.2, 1.0));
                UI.pushStyleColor(UI_Color.ButtonHovered, @(0.9, 0.3, 0.3, 1.0));

                if(UI.button("Stop##track" + track)) {
                    stopRecording(track);
                }

                UI.popStyleColor(2);
            } else {
                // Not recording - show Record button
                if(UI.button("Record##track" + track)) {
                    startRecording(track);
                }
            }

            UI.sameLine();

            // Clear button
            if(UI.button("Clear##track" + track)) {
                clearTrack(track);
            }

            // Volume control
            UI.spacing();
            UI.text("Volume: " + (volume[track] * 100) $ int + "%");

            if(UI.button("-##vol" + track)) {
                Math.max(0.0, volume[track] - 0.1) => float new_vol;
                setTrackVolume(track, new_vol);
            }
            UI.sameLine();

            if(UI.button("+##vol" + track)) {
                Math.min(1.0, volume[track] + 0.1) => float new_vol;
                setTrackVolume(track, new_vol);
            }

            UI.spacing();
            UI.separator();
            UI.spacing();
        }

        // === INFO ===
        UI.textDisabled("Instruments: 1=Sine 2=Square 3=Mandolin");
        UI.textDisabled("            4=Flute 5=Brass 6=HnkyTonk");
        UI.textDisabled("Speak or sing into your microphone!");
        UI.spacing();
        UI.textDisabled("OSC: localhost:6450");
        UI.textDisabled("Max loop: 10 seconds");
        UI.textDisabled("Quantization: Nearest measure");

        UI.end();
    }

    GG.nextFrame() => now;
}
