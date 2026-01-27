// snare.ck
// on the fly drumming with global BPM conducting
SndBuf snare => dac;
me.dir(-2)+"/audio/snare_01.wav" => snare.read;
.5 => snare.gain;
snare.samples() => snare.pos;

// make a conductor for our tempo 
// this is set and updated elsewhere
BPM tempo;

while (1)  {
    // update our basic beat each measure
    tempo.quarterNote => dur quarter;

    // play measure of: rest, snare, rest, sna-snare
    quarter => now; // rest
    0 => snare.pos;
    2.0*quarter => now; // play
    
    0 => snare.pos;
    2.0*quarter => now; // play
    
    0 => snare.pos;
    1.5*quarter => now; // play
    
    0 => snare.pos;
    quarter => now; // play
    0 => snare.pos;
    quarter/2 => now; // play
}    
    
