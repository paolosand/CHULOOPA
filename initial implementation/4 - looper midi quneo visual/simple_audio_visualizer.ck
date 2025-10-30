//---------------------------------------------------------------------
// name: simple_audio_visualizer.ck
// desc: Simple audio visualizer - circle reacts to mic input
//       - SIZE: controlled by amplitude (RMS)
//       - COLOR: controlled by dominant frequency (FFT)
//
// Usage:
//   chuck simple_audio_visualizer.ck
//---------------------------------------------------------------------

// === CHUGL SETUP ===
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ camera;
camera.posZ(5.0);

// Create central sphere
GSphere circle --> scene;
circle.posX(0.0);
circle.posY(0.0);
circle.posZ(0.0);
circle.sca(1.0);
circle.color(@(0.5, 0.5, 0.8));  // Start with blue-ish

// Add lighting for better 3D effect
GDirLight light --> scene;
light.intensity(1.0);
light.rotX(-30);
light.rotY(45);

// === AUDIO SETUP ===
adc => Gain input_gain => blackhole;
5.0 => input_gain.gain;  // Boost input gain

// RMS for amplitude detection - use same chain as FFT
adc => Gain amp_analysis => FFT fft_analyzer =^ RMS rms_analyzer => blackhole;
5.0 => amp_analysis.gain;  // Boost gain
2048 => fft_analyzer.size;
Windowing.hann(2048) => fft_analyzer.window;

// Spectrum array for FFT results
complex spectrum[fft_analyzer.size() / 2];

// === CONFIGURATION ===
0.3 => float MIN_SCALE;      // Minimum circle size
3.0 => float MAX_SCALE;      // Maximum circle size
20.0 => float AMP_MULTIPLIER; // Amplitude sensitivity

// Frequency to color mapping ranges (Hz) - optimized for vocal range
80.0 => float VOCAL_LOW;      // Lowest vocal frequency (bass/low notes)
500.0 => float VOCAL_MID;     // Middle vocal frequency
1000.0 => float VOCAL_HIGH;   // Highest vocal frequency (soprano/high notes)

<<< "=====================================================" >>>;
<<< "    Simple Audio Visualizer" >>>;
<<< "=====================================================" >>>;
<<< "Sample rate:", second / samp, "Hz" >>>;
<<< "FFT size:", fft_analyzer.size() >>>;
<<< "" >>>;
<<< "Circle SIZE: Reacts to amplitude (volume)" >>>;
<<< "Circle COLOR: Reacts to dominant frequency (vocal range)" >>>;
<<< "  Blue:   Low notes (~80-300 Hz)" >>>;
<<< "  Cyan/Green: Mid notes (~300-500 Hz)" >>>;
<<< "  Yellow/Orange: High-mid notes (~500-800 Hz)" >>>;
<<< "  Red:    High notes (~800-1000 Hz)" >>>;
<<< "" >>>;
<<< "Sing or hum into your microphone!" >>>;
<<< "Try different pitches to see the color gradient." >>>;
<<< "=====================================================" >>>;

// === HELPER FUNCTION: Find dominant frequency ===
fun float getDominantFrequency() {
    fft_analyzer.upchuck() @=> UAnaBlob @ blob;
    blob.fvals() @=> float fvals[];
    
    0.0 => float max_magnitude;
    0 => int max_bin;
    
    // Skip first few bins (DC and very low frequencies)
    for(3 => int i; i < fvals.size(); i++) {
        if(fvals[i] > max_magnitude) {
            fvals[i] => max_magnitude;
            i => max_bin;
        }
    }
    
    // Convert bin number to frequency
    // frequency = bin * (sample_rate / fft_size)
    max_bin * (second / samp => float sr) / fft_analyzer.size() => float freq;
    
    return freq;
}

// === HELPER FUNCTION: Map frequency to color ===
// Low notes = BLUE (cool), High notes = RED (warm)
fun void setColorFromFrequency(float freq) {
    // Clamp frequency to vocal range
    Math.max(VOCAL_LOW, Math.min(VOCAL_HIGH, freq)) => freq;
    
    if(freq < VOCAL_MID) {
        // LOW TO MID: Blue → Cyan → Green
        (freq - VOCAL_LOW) / (VOCAL_MID - VOCAL_LOW) => float t;
        
        // Interpolate from Blue (0,0.3,1) to Green (0.2,0.9,0.4)
        0.0 + (t * 0.2) => float r;
        0.3 + (t * 0.6) => float g;
        1.0 - (t * 0.6) => float b;
        
        circle.color(@(r, g, b));
    }
    else {
        // MID TO HIGH: Green → Yellow → Orange → Red
        (freq - VOCAL_MID) / (VOCAL_HIGH - VOCAL_MID) => float t;
        
        // Interpolate from Green (0.2,0.9,0.4) to Red (1,0.2,0.1)
        0.2 + (t * 0.8) => float r;
        0.9 - (t * 0.7) => float g;
        0.4 - (t * 0.3) => float b;
        
        circle.color(@(r, g, b));
    }
}

// === VISUALIZATION LOOP ===
fun void visualizationLoop() {
    0.0 => float smoothed_scale;
    0.0 => float smoothed_freq;
    0.15 => float SMOOTHING;  // Lower = smoother, higher = more responsive
    
    0 => int frame_count;
    
    while(true) {
        GG.nextFrame() => now;
        
        // Get amplitude
        rms_analyzer.upchuck();
        rms_analyzer.fval(0) => float amplitude;
        amplitude * AMP_MULTIPLIER => amplitude;
        
        // Calculate target scale
        MIN_SCALE + (amplitude * (MAX_SCALE - MIN_SCALE)) => float target_scale;
        Math.min(MAX_SCALE, target_scale) => target_scale;
        
        // Smooth the scale changes
        smoothed_scale + (target_scale - smoothed_scale) * SMOOTHING => smoothed_scale;
        circle.sca(smoothed_scale);
        
        // Get dominant frequency
        getDominantFrequency() => float freq;
        
        // Smooth frequency changes
        smoothed_freq + (freq - smoothed_freq) * (SMOOTHING * 0.5) => smoothed_freq;
        
        // Set color based on frequency
        if(amplitude > 0.01) {  // Only change color when there's actual sound
            setColorFromFrequency(smoothed_freq);
        }
        
        // Add subtle rotation for visual interest
        circle.rotY(0.01);
        circle.rotX(0.005);
        
        // DEBUG OUTPUT - print every 30 frames (~0.5 seconds at 60fps)
        frame_count++;
        if(frame_count % 30 == 0) {
            // Get FFT magnitudes for debugging
            fft_analyzer.upchuck() @=> UAnaBlob @ blob;
            blob.fvals() @=> float fvals[];
            
            // Find max FFT magnitude
            0.0 => float max_fft;
            for(0 => int i; i < fvals.size(); i++) {
                if(fvals[i] > max_fft) fvals[i] => max_fft;
            }
            
            <<< "=== AUDIO DEBUG ===" >>>;
            <<< "Raw amplitude:", rms_analyzer.fval(0) >>>;
            <<< "Scaled amplitude:", amplitude >>>;
            <<< "Max FFT magnitude:", max_fft >>>;
            <<< "Circle scale:", smoothed_scale >>>;
            <<< "Dominant frequency:", smoothed_freq, "Hz" >>>;
            <<< "" >>>;
        }
    }
}

// === MAIN PROGRAM ===
spork ~ visualizationLoop();

// Keep running
while(true) {
    1::second => now;
}

