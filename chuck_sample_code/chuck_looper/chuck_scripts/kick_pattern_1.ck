// kick.ck
// on the fly drumming with global BPM conducting
SndBuf kick => dac;
.5 => kick.gain;
me.dir(-2)+"/audio/kick_01.wav" => kick.read;

// make a conductor for our tempo 
// this is set and updated elsewhere
BPM tempo;

while (1)  {
    // update our basic beat each measure
    tempo.quarterNote => dur quarter;
    tempo.sixteenthNote => dur sixteenth;
    quarter*2 => dur half;

    // play a measure of half note kicks
    0 => kick.pos;
    half => now;

    0 => kick.pos;
    5*sixteenth => now;

    0 => kick.pos;
    3*sixteenth => now;
}
    
