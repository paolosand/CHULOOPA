//---------------------------------------------------------------------
// name: feature_extraction.ck
// desc: Shared feature extraction for drum classification
//       25 features: 12 spectral + 13 MFCC
//---------------------------------------------------------------------

// This is a shared module - include in your classifier files

public class DrumFeatures {
    512 => static int FRAME_SIZE;

    // Analysis units
    FFT @ fft;
    RMS @ rms;
    MFCC @ mfcc;

    float prev_spectrum[FRAME_SIZE/2];

    fun void init(FFT _fft, RMS _rms, MFCC _mfcc) {
        _fft @=> fft;
        _rms @=> rms;
        _mfcc @=> mfcc;
    }

    fun float[] extract(float flux) {
        float features[25];

        // Get analysis blobs
        fft.upchuck() @=> UAnaBlob @ blob;
        rms.upchuck();
        mfcc.upchuck() @=> UAnaBlob @ mfcc_blob;

        // RMS energy
        rms.fval(0) => float energy;

        // Frequency bands
        0.0 => float band1 => float band2 => float band3 => float band4 => float band5;

        for(0 => int i; i < FRAME_SIZE/2; i++) {
            blob.fval(i) => float mag;

            if(i < FRAME_SIZE/32) mag +=> band1;
            else if(i < FRAME_SIZE/8) mag +=> band2;
            else if(i < FRAME_SIZE/4) mag +=> band3;
            else if(i < FRAME_SIZE/2.5) mag +=> band4;
            else mag +=> band5;
        }

        // Spectral centroid
        0.0 => float centroid_num => float centroid_den;
        for(0 => int i; i < FRAME_SIZE/2; i++) {
            blob.fval(i) => float mag;
            i * mag +=> centroid_num;
            mag +=> centroid_den;
        }
        centroid_num / (centroid_den + 0.0001) => float centroid;

        // Spectral rolloff
        0.0 => float total_energy;
        for(0 => int i; i < FRAME_SIZE/2; i++) {
            blob.fval(i) +=> total_energy;
        }

        total_energy * 0.9 => float rolloff_threshold;
        0.0 => float running_sum;
        0 => int rolloff;
        for(0 => int i; i < FRAME_SIZE/2; i++) {
            blob.fval(i) +=> running_sum;
            if(running_sum >= rolloff_threshold && rolloff == 0) {
                i => rolloff;
            }
        }

        // Spectral flatness
        0.0 => float geometric_mean => float arithmetic_mean;
        for(0 => int i; i < FRAME_SIZE/2; i++) {
            blob.fval(i) => float mag;
            Math.log(mag + 0.0001) +=> geometric_mean;
            mag +=> arithmetic_mean;
        }
        geometric_mean / (FRAME_SIZE/2.0) => geometric_mean;
        Math.exp(geometric_mean) => geometric_mean;
        arithmetic_mean / (FRAME_SIZE/2.0) => arithmetic_mean;
        geometric_mean / (arithmetic_mean + 0.0001) => float flatness;

        // Energy ratios
        band1 / (energy + 0.0001) => float low_ratio;
        band5 / (energy + 0.0001) => float high_ratio;

        // Pack features
        flux => features[0];
        energy => features[1];
        band1 => features[2];
        band2 => features[3];
        band3 => features[4];
        band4 => features[5];
        band5 => features[6];
        centroid => features[7];
        rolloff => features[8];
        flatness => features[9];
        low_ratio => features[10];
        high_ratio => features[11];

        // Add MFCCs
        for(0 => int i; i < 13; i++) {
            mfcc_blob.fval(i) => features[12 + i];
        }

        return features;
    }
}
