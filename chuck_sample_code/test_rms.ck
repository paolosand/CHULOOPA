// Simple RMS test
adc => RMS rms => blackhole;

<<< "Testing RMS..." >>>;

while(true) {
    rms.upchuck() @=> UAnaBlob @ blob;
    blob.fval(0) => float energy;
    
    if(energy > 0.0001) {
        <<< "RMS Energy:", energy >>>;
    }
    
    100::ms => now;
}
