// main.ck
// handle starting and stopping shreds

// get tempo and BPM data
BPM tempo;
tempo.tempo(94.0); // set tempo to 94BPM
KEY key;
key.get_scale(61); // scale set to C#

// Declare global variables
global int kickID;
global int snareID;
global int hatID;
global int bassID;
global int keysID;
global int sequencerID;

global int kickOn;
0 => kickOn;
global int snareOn;
0 => snareOn;
global int hatOn;
0 => hatOn;
global int bassOn;
0 => bassOn;
global int keysOn;
0 => keysOn;
global int sequencerOn;
0 => sequencerOn;
global int drumsOn;

// setup MIDI
MidiIn min;
MidiMsg msg;
0 => int port;

// check if port works
if (!min.open(port)){
    <<<"Error: MIDI port did not open on port ", port>>>;
    me.exit;
} else{
    <<<"On midi device: ", port>>>;
}

fun void start_kick(){
    Machine.add(me.dir()+"/kick_pattern_1.ck") => kickID;
}

fun void stop_kick(){
    Machine.remove(kickID);
}

fun void start_snare(){
    Machine.add(me.dir()+"/snare_pattern_1.ck") => snareID;
}

fun void stop_snare(){
    Machine.remove(snareID);
}

fun void start_hat(){
    Machine.add(me.dir()+"/hat_pattern_1.ck") => hatID;
}

fun void stop_hat(){
    Machine.remove(hatID);
}

fun void start_keys(){
    Machine.add(me.dir()+"/keys_pattern_1.ck") => keysID;
}

fun void stop_keys(){
    Machine.remove(keysID);
}

fun void start_bass(){
    Machine.add(me.dir()+"/bass_pattern_1.ck") => bassID;
}

fun void stop_bass(){
    Machine.remove(bassID);
}

fun void start_sequencer(){
    Machine.add(me.dir()+"/sequencer_pattern_1.ck") => sequencerID;
}

fun void stop_sequencer(){
    Machine.remove(sequencerID);
}

// print array
fun void print_array(int midi_actions[]){
    <<<"here", midi_actions.size()>>>;
    for(0 => int i; i < midi_actions.size(); i++){
        <<<"msg ", i,": ", midi_actions[i]>>>; 
    }
}

fun void clear(int midi_actions[]){
    <<<"here", midi_actions.size()>>>;
    for(0 => int i; i < midi_actions.size(); i++){
        0 => midi_actions[i];
    }
}

// New function to process a single action
fun void processAction(int data2) {
    if(data2){
        <<<"executing ", data2>>>;
        if(data2 == 36){
            // start kick
            if(kickOn){
                0 => kickOn;
                stop_kick();
            } else{
                1 => kickOn;
                start_kick();
            }
        } else if(data2 == 37){
            // start snare
            if(snareOn){
                0 => snareOn;
                stop_snare();
            } else{
                1 => snareOn;
                start_snare();
            }
        } else if(data2 == 38){
            // start hat
            if(hatOn){
                0 => hatOn;
                stop_hat();
            } else{
                1 => hatOn;
                start_hat();
            }
        } else if(data2 == 39){
            // start bass
            if(bassOn){
                0 => bassOn;
                stop_bass();
            } else{
                1 => bassOn;
                start_bass();
            }
        } else if(data2 == 40){
            // start keys
            if(keysOn){
                0 => keysOn;
                stop_keys();
            } else{
                1 => keysOn;
                start_keys();
            }
        } else if(data2 == 41){
            // start sequencer
            if(sequencerOn){
                0 => sequencerOn;
                stop_sequencer();
            } else{
                1 => sequencerOn;
                start_sequencer();
            }
        }
    }
}

[0,0,0,0,0,0,0] @=> int midi_actions[];

// start event loop
min => now;
// Modify your main loop
while(true) {
    <<<"New bar starting">>>;
    
    // Process actions from the previous bar
    for (0 => int i; i < midi_actions.size(); i++) {
        processAction(midi_actions[i]);
    }
    
    // Clear the actions array for the next bar
    clear(midi_actions);
    
    // Listen for MIDI messages for one bar
    0 => int msg_count;
    for(0 => int i; i < 16; i++) {
        if(min.recv(msg)) {
            if (msg.data1 == 153) {  // Only process note on messages
                <<<"msg received">>>;
                msg.data2 => midi_actions[msg_count];  // Add action to the array
                // msg.data2 => test[msg_count];
                <<<midi_actions[msg_count], midi_actions.size()>>>;

                <<<"new msg array">>>;
                print_array(midi_actions);
                msg_count++;
                <<<midi_actions[msg_count-1]>>>;
            }
        }
        tempo.sixteenthNote => now;
    }
}
