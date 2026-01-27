// bass

// patch
SinOsc bass => JCRev r => dac;

// initial settings
.3 => r.gain;
.1 => r.mix;

.2 => bass.gain;

BPM tempo;
KEY k;

// our main time loop
while( true )
{
    tempo.quarterNote => dur quarter;
    
    for(0 => int i; i < 3; i++){
        for(0 => int j; j < 3; j++){
            Std.mtof(k.four - 24) => bass.freq;
            quarter => now;
        }
        Std.mtof(k.five - 24) => bass.freq;
        quarter => now;

        for(0 => int j; j < 4; j++){
            Std.mtof(k.one - 24) => bass.freq;
            quarter => now;
        }
    }
    for(0 => int i; i < 3; i++){
        Std.mtof(k.two - 24) => bass.freq;
        quarter => now;
    }

    Std.mtof(k.three - 24) => bass.freq;
    quarter => now;

    for(0 => int i; i < 4; i++){
        Std.mtof(k.one - 24) => bass.freq;
        quarter => now;
    }
}