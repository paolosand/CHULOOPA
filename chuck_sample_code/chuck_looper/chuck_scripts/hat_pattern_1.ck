// hat.ck
// on the fly drumming with global BPM conducting
SndBuf hat => dac;
me.dir(-2)+"/audio/hihat_02.wav" => hat.read;
hat.samples() => hat.pos;

.5 => hat.gain;

// make a conductor for our tempo 
// this is set and updated elsewhere
BPM tempo;

while (1)  {
    // update our basic beat each measure
    tempo.quarterNote => dur quarter;
    tempo.eighthNote => dur eighth;
    
    // add delay of 1 eigth note
    eighth => now;
    
    // play a measure of quarter notes
    for (0 => int beat; beat < 7; beat++)  {
        0 => hat.pos;
        quarter => now;
    }
    
    eighth => now;
}    
    
