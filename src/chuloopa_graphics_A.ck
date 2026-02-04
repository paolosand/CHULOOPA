//---------------------------------------------------------------------
// name: chuloopa_graphics_A.ck
// desc: CHULOOPA - Morphing polyhedron visualization
//       Clean, minimal geometric shape that responds to drum hits
//       Switches geometry between cube and dodecahedron
//
// Geometry:
//   - Normal Mode: Cube (simple, 6 faces)
//   - Variation Mode: Dodecahedron (complex, 12 pentagonal faces)
//
// Visual States:
//   - Idle: Gray cube with gentle morphing
//   - Recording: Pulsing red cube
//   - Looping: Steady red cube with organic deformations
//   - Variation Ready: Green pulsing cube
//   - Variation Playing: Blue DODECAHEDRON with spice-level intensity
//
// Drum Responses:
//   - Kick: Radial expansion (all axes)
//   - Snare: Vertical compression (squeeze Y, expand X/Z)
//   - Hat: Asymmetric wobble (X axis)
//
// Spice Level: Affects deformation intensity
//   - Low (0.0-0.3): Smooth, subtle morphing
//   - Med (0.4-0.6): Moderate deformations
//   - High (0.7-1.0): Intense, chaotic morphing
//
// Usage:
//   chuck src/chuloopa_graphics_A.ck
//---------------------------------------------------------------------

// === MOCK DATA CONFIGURATION ===
120.0 => float MOCK_BPM;
60.0 / MOCK_BPM => float BEAT_DURATION;
5.0 => float STATE_CHANGE_INTERVAL;

// === VISUAL CONFIGURATION ===
1.0 => float BASE_SCALE;
0.5 => float MAX_DEFORMATION;

// Noise parameters
0.5 => float NOISE_SPEED;
0.3 => float NOISE_AMOUNT;

// === CHUGL SETUP ===
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ camera;
camera.posZ(6.0);

// === LIGHTING ===
GDirLight main_light --> scene;
main_light.intensity(1.2);
main_light.rotX(-30);

GDirLight rim_light --> scene;
rim_light.intensity(0.6);
rim_light.rotY(180);
rim_light.rotX(30);

// Front light for bottle (fixes back-lit appearance)
GDirLight bottle_light --> scene;
bottle_light.intensity(0.8);
bottle_light.rotY(-45);  // From front-right
bottle_light.rotX(-15);  // Slightly from above

// === BLOOM EFFECT + ACES TONEMAP ===
GG.outputPass() @=> OutputPass output_pass;
GG.renderPass() --> BloomPass bloom_pass --> output_pass;
bloom_pass.input(GG.renderPass().colorOutput());
output_pass.input(bloom_pass.colorOutput());
bloom_pass.intensity(0.4);
bloom_pass.radius(0.8);
bloom_pass.levels(6);
bloom_pass.threshold(0.3);

// ACES tonemap for CRT old TV effect
output_pass.tonemap(4);  // 4 = ACES
output_pass.exposure(0.5);

// === CENTRAL POLYHEDRON (Spice-based geometry switching) ===
// More faces = more spice/complexity
GCube cube_shape --> scene;
cube_shape.sca(BASE_SCALE);
cube_shape.color(@(0.9, 0.2, 0.2));

GPolyhedron octahedron_shape(PolyhedronGeometry.OCTAHEDRON) --> scene;
octahedron_shape.sca(BASE_SCALE);
octahedron_shape.color(@(0.9, 0.2, 0.2));
octahedron_shape.posY(-100);  // Hide initially

GPolyhedron dodec_shape(PolyhedronGeometry.DODECAHEDRON) --> scene;
dodec_shape.sca(BASE_SCALE);
dodec_shape.color(@(0.9, 0.2, 0.2));
dodec_shape.posY(-100);  // Hide initially

GPolyhedron icosahedron_shape(PolyhedronGeometry.ICOSAHEDRON) --> scene;
icosahedron_shape.sca(BASE_SCALE);
icosahedron_shape.color(@(0.9, 0.2, 0.2));
icosahedron_shape.posY(-100);  // Hide initially

// Track which shape is active (0=cube, 1=octa, 2=dodec, 3=icosa)
0 => int active_shape_index;

// === HOT SAUCE BOTTLE (VARIATION STATE INDICATOR) ===
GModel bottle("assets/hot+sauce+bottle+3d+model.obj") --> scene;

// Auto-scale bottle to reasonable size (similar to gmodel.ck)
fun float max(vec3 v) {
    return Math.max(Math.max(v.x, v.y), v.z);
}

max(bottle.max - bottle.min) => float bottle_size;
0.35 / bottle_size => float bottle_scale;  // Small icon size (0.35 units)
bottle.sca(bottle_scale);

// Position bottle next to spice text (to the right of the percentage)
bottle.posX(1.2);  // To the right of "SPICE: XX%"
bottle.posY(-100);  // Start hidden
bottle.posZ(0.0);

// Tilt to the right
bottle.rotZ(-Math.PI / 8);  // Tilt right
bottle.rotY(Math.PI / 6);   // Face forward slightly

// Store base position for animation
2.0 => float bottle_base_y;

// Background particles removed - cleaner look

// === STATE VARIABLES ===
0 => int is_recording;
0 => int has_loop;
0 => int variation_mode_active;
0 => int variations_ready;
0.5 => float current_spice_level;

// Drum hit state
0.0 => float kick_impulse => float snare_impulse => float hat_impulse;

// Animation time
now => time start_time;

// === TEXT DISPLAYS ===
GText spice_text --> scene;
spice_text.text("SPICE: 50%");
spice_text.posX(0.0);
spice_text.posY(2.0);
spice_text.posZ(0.0);
spice_text.sca(0.25);
spice_text.color(@(1.0, 0.6, 0.0));

GText state_text --> scene;
state_text.text("STATE: Idle");
state_text.posX(0.0);
state_text.posY(1.6);
state_text.posZ(0.0);
state_text.sca(0.22);
state_text.color(@(0.8, 0.8, 0.8));

// === MOCK DATA GENERATOR ===
fun void mockDrumGenerator() {
    <<< "Mock drum generator started" >>>;

    while(true) {
        Math.random2f(0, 1) => float rand;

        if(has_loop) {
            if(rand > 0.7) {
                Math.random2f(0.5, 1.0) => kick_impulse;
                <<< "KICK", kick_impulse >>>;
            }
            else if(rand > 0.5) {
                Math.random2f(0.5, 1.0) => snare_impulse;
                <<< "SNARE", snare_impulse >>>;
            }
            else if(rand > 0.3) {
                Math.random2f(0.3, 0.8) => hat_impulse;
                <<< "HAT", hat_impulse >>>;
            }
        }

        (BEAT_DURATION / 4.0)::second => now;
    }
}

// === MOCK STATE CHANGER ===
fun void mockStateChanger() {
    <<< "Mock state changer started" >>>;
    STATE_CHANGE_INTERVAL::second => now;

    while(true) {
        <<< "STATE: Recording" >>>;
        1 => is_recording;
        0 => has_loop;
        0 => variations_ready;
        0 => variation_mode_active;
        STATE_CHANGE_INTERVAL::second => now;

        <<< "STATE: Looping (original)" >>>;
        0 => is_recording;
        1 => has_loop;
        0 => variations_ready;
        0 => variation_mode_active;
        STATE_CHANGE_INTERVAL::second => now;

        <<< "STATE: Variation ready" >>>;
        0 => is_recording;
        1 => has_loop;
        1 => variations_ready;
        0 => variation_mode_active;
        STATE_CHANGE_INTERVAL::second => now;

        <<< "STATE: Playing variation" >>>;
        0 => is_recording;
        1 => has_loop;
        1 => variations_ready;
        1 => variation_mode_active;
        STATE_CHANGE_INTERVAL::second => now;

        Math.random2f(0.0, 1.0) => current_spice_level;
        <<< "Spice level:", current_spice_level >>>;
    }
}

// === DEFORMATION FUNCTIONS ===
fun void updateShapeDeformations(float time_sec) {
    // Base organic morphing (noise-like)
    Math.sin(time_sec * NOISE_SPEED) => float noise_x;
    Math.cos(time_sec * NOISE_SPEED * 0.7) => float noise_y;
    Math.sin(time_sec * NOISE_SPEED * 1.3) => float noise_z;

    // Base scales with noise
    BASE_SCALE + noise_x * NOISE_AMOUNT => float scale_x;
    BASE_SCALE + noise_y * NOISE_AMOUNT => float scale_y;
    BASE_SCALE + noise_z * NOISE_AMOUNT => float scale_z;

    // Add drum hit deformations
    if(kick_impulse > 0.0) {
        // Kick: expand all axes (radial pulse)
        scale_x + kick_impulse * 0.4 => scale_x;
        scale_y + kick_impulse * 0.4 => scale_y;
        scale_z + kick_impulse * 0.4 => scale_z;
    }

    if(snare_impulse > 0.0) {
        // Snare: squeeze Y, expand X/Z (vertical compression)
        scale_y - snare_impulse * 0.3 => scale_y;
        scale_x + snare_impulse * 0.2 => scale_x;
        scale_z + snare_impulse * 0.2 => scale_z;
    }

    if(hat_impulse > 0.0) {
        // Hat: asymmetric wobble on X axis
        scale_x + hat_impulse * 0.3 => scale_x;
    }

    // Apply spice multiplier (makes deformations more extreme)
    if(current_spice_level > 0.5) {
        (current_spice_level - 0.5) * 2.0 => float spice_factor;
        scale_x * (1.0 + spice_factor * 0.4) => scale_x;
        scale_y * (1.0 + spice_factor * 0.4) => scale_y;
        scale_z * (1.0 + spice_factor * 0.4) => scale_z;
    }

    // Clamp scales
    Math.max(0.3, Math.min(2.5, scale_x)) => scale_x;
    Math.max(0.3, Math.min(2.5, scale_y)) => scale_y;
    Math.max(0.3, Math.min(2.5, scale_z)) => scale_z;

    // Apply scale to all shapes (only visible one matters)
    cube_shape.scaX(scale_x);
    cube_shape.scaY(scale_y);
    cube_shape.scaZ(scale_z);

    octahedron_shape.scaX(scale_x);
    octahedron_shape.scaY(scale_y);
    octahedron_shape.scaZ(scale_z);

    dodec_shape.scaX(scale_x);
    dodec_shape.scaY(scale_y);
    dodec_shape.scaZ(scale_z);

    icosahedron_shape.scaX(scale_x);
    icosahedron_shape.scaY(scale_y);
    icosahedron_shape.scaZ(scale_z);

    // Decay impulses
    kick_impulse * 0.9 => kick_impulse;
    if(kick_impulse < 0.01) 0.0 => kick_impulse;

    snare_impulse * 0.9 => snare_impulse;
    if(snare_impulse < 0.01) 0.0 => snare_impulse;

    hat_impulse * 0.9 => hat_impulse;
    if(hat_impulse < 0.01) 0.0 => hat_impulse;
}

// === MAIN VISUALIZATION LOOP ===
fun void visualizationLoop() {
    <<< "Visualization loop started" >>>;

    while(true) {
        GG.nextFrame() => now;
        (now - start_time) / second => float time_sec;

        // Update shape deformations
        updateShapeDeformations(time_sec);

        // Update colors based on state
        @(0.5, 0.5, 0.5) => vec3 target_color;  // Default gray
        0.4 => float target_bloom;

        // Add shine on drum hits (bloom boost)
        0.0 => float hit_shine;
        if(kick_impulse > 0.1 || snare_impulse > 0.1 || hat_impulse > 0.1) {
            Math.max(kick_impulse, Math.max(snare_impulse, hat_impulse)) => hit_shine;
        }

        if(is_recording) {
            // NO RECORDING AND WHILE RECORDING: Gray
            @(0.5, 0.5, 0.5) => target_color;
            0.3 => target_bloom;
        }
        else if(variation_mode_active) {
            // PLAYING VARIATION: Gradient based on spice
            // Blue (low) → Yellow (mid) → Red (high)
            if(current_spice_level < 0.5) {
                // Blue to Yellow gradient (0.0 - 0.5)
                current_spice_level * 2.0 => float t;
                @(0.2 + t * 0.8, 0.4 + t * 0.6, 0.9 - t * 0.9) => target_color;
            }
            else {
                // Yellow to Red gradient (0.5 - 1.0)
                (current_spice_level - 0.5) * 2.0 => float t;
                @(1.0, 1.0 - t * 0.1, 0.0) => target_color;
            }
            0.5 + current_spice_level * 0.3 => target_bloom;
        }
        else if(variations_ready && !variation_mode_active) {
            // VARIATION READY (not playing yet): Blue with green tint + extra glow
            @(0.2, 0.6, 0.7) => target_color;
            0.6 => target_bloom;
        }
        else if(has_loop) {
            // PLAYING INITIAL RECORDING: Blue
            @(0.2, 0.4, 0.9) => target_color;
            0.4 => target_bloom;
        }
        else {
            // Idle: Dim gray
            @(0.3, 0.3, 0.3) => target_color;
            0.2 => target_bloom;
        }

        // Add hit shine to bloom
        target_bloom + hit_shine * 0.4 => target_bloom;

        // Switch geometry based on spice level (only in variation mode)
        0 => int target_shape;  // Default to cube

        if(variation_mode_active) {
            // Determine shape based on spice level
            if(current_spice_level < 0.4) {
                0 => target_shape;  // Cube (6 faces)
            }
            else if(current_spice_level < 0.7) {
                1 => target_shape;  // Octahedron (8 faces)
            }
            else if(current_spice_level < 1.0) {
                2 => target_shape;  // Dodecahedron (12 faces)
            }
            else {
                3 => target_shape;  // Icosahedron (20 faces) - max spice!
            }
        }

        // Switch shapes if needed
        if(target_shape != active_shape_index) {
            // Hide current shape
            if(active_shape_index == 0) cube_shape.posY(-100);
            else if(active_shape_index == 1) octahedron_shape.posY(-100);
            else if(active_shape_index == 2) dodec_shape.posY(-100);
            else if(active_shape_index == 3) icosahedron_shape.posY(-100);

            // Show new shape
            target_shape => active_shape_index;
            if(active_shape_index == 0) cube_shape.posY(0);
            else if(active_shape_index == 1) octahedron_shape.posY(0);
            else if(active_shape_index == 2) dodec_shape.posY(0);
            else if(active_shape_index == 3) icosahedron_shape.posY(0);
        }

        // Apply color and rotation to all shapes (only visible one matters)
        cube_shape.color(target_color);
        octahedron_shape.color(target_color);
        dodec_shape.color(target_color);
        icosahedron_shape.color(target_color);

        cube_shape.rotY(time_sec * 0.2);
        cube_shape.rotX(Math.sin(time_sec * 0.3) * 0.3);

        octahedron_shape.rotY(time_sec * 0.2);
        octahedron_shape.rotX(Math.sin(time_sec * 0.3) * 0.3);

        dodec_shape.rotY(time_sec * 0.2);
        dodec_shape.rotX(Math.sin(time_sec * 0.3) * 0.3);

        icosahedron_shape.rotY(time_sec * 0.2);
        icosahedron_shape.rotX(Math.sin(time_sec * 0.3) * 0.3);

        bloom_pass.intensity(target_bloom);

        // Update text
        "SPICE: " + ((current_spice_level * 100) $ int) + "%" => spice_text.text;

        if(current_spice_level < 0.5) {
            current_spice_level * 2.0 => float t;
            spice_text.color(@(0.2 + t * 0.8, 0.5 + t * 0.5, 1.0 - t * 1.0));
        } else {
            (current_spice_level - 0.5) * 2.0 => float t;
            spice_text.color(@(1.0, 1.0 - t * 0.5, 0.0));
        }

        // STATE TEXT: Show state via color
        "STATE: " => string state_label;
        if(is_recording) {
            state_label + "Recording" => state_text.text;
            // BLINKING RED for recording
            Math.sin(time_sec * 8.0) => float blink;
            if(blink > 0) @(1.0, 0.2, 0.2) => state_text.color;
            else @(0.5, 0.1, 0.1) => state_text.color;
        }
        else if(variation_mode_active) {
            state_label + "Variation" => state_text.text;
            @(0.8, 0.8, 0.8) => state_text.color;  // Default
        }
        else if(has_loop) {
            state_label + "Original" => state_text.text;
            @(0.8, 0.8, 0.8) => state_text.color;  // Default
        }
        else {
            state_label + "Idle" => state_text.text;
            @(0.7, 0.7, 0.7) => state_text.color;  // White/gray for idle
        }

        // HOT SAUCE BOTTLE: Subtle floating animation + color changes
        // Gentle vertical bobbing
        Math.sin(time_sec * 1.2) * 0.05 => float bob_offset;
        bottle.posY(bottle_base_y + bob_offset);

        // Gentle rotation wobble
        Math.sin(time_sec * 0.8) * 0.05 => float wobble;
        bottle.rotZ(-Math.PI / 8 + wobble);

        // Color changes based on variation state
        if(!has_loop) {
            // No loop: hide bottle
            bottle.posY(-100);
        }
        else if(variations_ready && !variation_mode_active) {
            // Variation ready: BLINKING GREEN with high exposure
            bottle.posY(bottle_base_y + bob_offset);
            Math.sin(time_sec * 6.0) => float blink;

            // Blink between bright green and dim green
            if(bottle.materials.size() > 0) {
                bottle.materials[0] $ PhongMaterial @=> PhongMaterial @ mat;
                if(mat != null) {
                    if(blink > 0) {
                        // REALLY BRIGHT GREEN
                        mat.color(@(0.5, 2.0, 0.6));
                        mat.specular(@(0.8, 2.0, 1.0));
                        mat.emission(@(0.8, 3.0, 1.0));  // Extremely bright green emission
                    }
                    else {
                        // Dim green (was bright green)
                        mat.color(@(0.2, 1.0, 0.3));
                        mat.specular(@(0.4, 1.0, 0.5));
                        mat.emission(@(0.3, 1.5, 0.4));
                    }
                }
            }
        }
        else if(has_loop) {
            // Has loop but waiting for variation: White with pulsing exposure
            bottle.posY(bottle_base_y + bob_offset);
            Math.sin(time_sec * 2.0) * 0.3 + 0.7 => float pulse;

            // Keep bottle white with oscillating exposure
            if(bottle.materials.size() > 0) {
                bottle.materials[0] $ PhongMaterial @=> PhongMaterial @ mat;
                if(mat != null) {
                    mat.color(@(0.9, 0.9, 0.9));  // White base
                    mat.specular(@(1.0, 1.0, 1.0));
                    mat.emission(@(0.5 * pulse, 0.5 * pulse, 0.5 * pulse));  // White bloom pulse
                }
            }
        }
    }
}

// === STARTUP ===
<<< "" >>>;
<<< "╔═══════════════════════════════════════╗" >>>;
<<< "║  CHULOOPA BLOB VISUALIZATION         ║" >>>;
<<< "╚═══════════════════════════════════════╝" >>>;
<<< "" >>>;
<<< "Mock data mode - simulating drum hits and state changes" >>>;
<<< "" >>>;

spork ~ mockDrumGenerator();
spork ~ mockStateChanger();
spork ~ visualizationLoop();

while(true) {
    1::second => now;
}
