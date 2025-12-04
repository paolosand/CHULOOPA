// Keys Player

// patch
Mandolin voc[4];
voc[0] => JCRev r => dac;
voc[1] => r;
voc[2] => r;
voc[3] => r;

// initial settings
.1 => r.gain;
.1 => r.mix;



// takes notes in midi
fun void freqs(float note1, float note2, float note3, float note4)
{
    Std.mtof(note1) => voc[0].freq;
    Std.mtof(note2) => voc[1].freq;
    Std.mtof(note3) => voc[2].freq;
    Std.mtof(note4) => voc[3].freq;
}

BPM tempo;
KEY k;

// our main time loop
while( 1 )
{ 
    tempo.quarterNote => dur quarter;
    
    // play I on 4 half notes
    for(0 => int i; i < 3; i++){
        freqs(k.four, k.one, k.three, k.five); // IVmaj7 add 2
        Math.random2f(0.4,0.6) => voc[0].noteOn;
        Math.random2f(0.4,0.6) => voc[1].noteOn;
        Math.random2f(0.4,0.6) => voc[2].noteOn;
        Math.random2f(0.4,0.6) => voc[3].noteOn;
    
        quarter*4 => now;

        freqs(k.one, k.five, k.seven, k.two); // Imaj7 add 2
        Math.random2f(0.4,0.6) => voc[0].noteOn;
        Math.random2f(0.4,0.6) => voc[1].noteOn;
        Math.random2f(0.4,0.6) => voc[2].noteOn;
        Math.random2f(0.4,0.6) => voc[3].noteOn;
    
        quarter*4 => now;
    }
}