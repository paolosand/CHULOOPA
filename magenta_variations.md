# Magenta/GrooVAE Drum Variations for CHULOOPA

This document describes the AI-powered drum variation system using Google Magenta's GrooVAE model, including setup instructions for Apple Silicon Macs.

## Overview

The `drum_variation_ai.py` script generates musical variations of drum patterns using GrooVAE (Groove Variational Autoencoder), a neural network trained on thousands of drum performances. It learns the "feel" of human drumming and can transform patterns while maintaining musical coherence.

**Key Features:**
- Latent space interpolation for controllable variation amount
- Adaptive BPM estimation from loop duration
- Exact loop duration preservation
- Fallback algorithmic variations when GrooVAE unavailable

## Setup on Apple Silicon (M1/M2/M3)

Magenta was designed for older TensorFlow versions and x86 architecture. Getting it to run on Apple Silicon requires specific package versions.

### Prerequisites

- Python 3.10 (recommended)
- Homebrew (for dependencies)

### Option A: Using Requirements File (Recommended)

A community-maintained requirements file for Apple Silicon is available:

**Source:** [requirements-magenta-cpu-apple-m1-m2.txt](https://gist.github.com/xstasi/30123f5976abb5b6c90114b92986a155#file-requirements-magenta-cpu-apple-m1-m2-txt)

```bash
cd /path/to/CHULOOPA

# Create virtual environment
python3.10 -m venv venv_magenta
source venv_magenta/bin/activate

# Download and install from requirements file
curl -O https://gist.githubusercontent.com/xstasi/30123f5976abb5b6c90114b92986a155/raw/requirements-magenta-cpu-apple-m1-m2.txt
pip install -r requirements-magenta-cpu-apple-m1-m2.txt
```

**Key packages from the requirements file:**
- `magenta==2.1.4`
- `tensorflow-macos==2.9.1`
- `keras==2.9.0`
- `note-seq==0.0.3`
- `numpy==1.23.0`
- `librosa==0.9.2`

### Option B: Manual Installation

If you need more control or encounter issues:

```bash
cd /path/to/CHULOOPA
python3.10 -m venv venv_magenta
source venv_magenta/bin/activate

# Use older pip/setuptools for compatibility
pip install pip==23.3.1 setuptools==68.0.0

# Core TensorFlow for Apple Silicon
pip install tensorflow-macos==2.9.1
pip install keras==2.9.0

# Scientific computing
pip install numpy==1.23.0
pip install scipy==1.8.1

# Numba/LLVM (specific versions for ARM64)
pip install llvmlite==0.39.1
pip install numba==0.56.4

# Protocol buffers (must be 3.x for Magenta)
pip install protobuf==3.20.3

# TensorFlow extras
pip install tensorflow-metadata==1.12.0
pip install tensorflow-probability==0.7.0rc0
pip install tf-slim==1.1.0

# Note sequence library
pip install note-seq==0.0.3

# Install magenta without deps to avoid conflicts
pip install magenta==2.1.4 --no-deps
```

### Download GrooVAE Checkpoint

```bash
mkdir -p models
cd models
curl -O https://storage.googleapis.com/magentadata/models/music_vae/checkpoints/groovae_2bar_humanize.tar
tar -xf groovae_2bar_humanize.tar
cd ..
```

The checkpoint files should be at:
```
models/groovae_2bar_humanize/
├── model.ckpt-3061.data-00000-of-00001
├── model.ckpt-3061.index
└── model.ckpt-3061.meta
```

### Verify Installation

```bash
source venv_magenta/bin/activate
python3 -c "
from magenta.models.music_vae import configs
print('Available GrooVAE configs:')
for name in configs.CONFIG_MAP:
    if 'groove' in name.lower():
        print(f'  - {name}')
"
```

Expected output:
```
Available GrooVAE configs:
  - groovae_2bar_humanize
  - groovae_2bar_tap_fixed_velocity
  - groovae_2bar_add_closed_hh
  - groovae_4bar
```

## Usage

### Basic Usage

```bash
# Activate the environment
source venv_magenta/bin/activate

# Generate variation for track 0
python src/drum_variation_ai.py --track 0 --type groove_vae

# Generate with backup of original
python src/drum_variation_ai.py --track 0 --type groove_vae --backup

# Specify a file directly
python src/drum_variation_ai.py --file track_0_drums.txt --type groove_vae
```

### Controlling Variation Amount

The `--temperature` parameter controls how different the output is from the input:

```bash
# Subtle variation (default)
python src/drum_variation_ai.py --track 0 --type groove_vae --temperature 0.2

# Moderate variation
python src/drum_variation_ai.py --track 0 --type groove_vae --temperature 0.5

# Strong variation
python src/drum_variation_ai.py --track 0 --type groove_vae --temperature 0.8
```

- `0.0` = Nearly identical to input
- `0.3` = Default, subtle musical variations
- `0.5` = Noticeable changes while keeping feel
- `0.8+` = Significant transformation

### Watch Mode (Auto-generate on file changes)

```bash
python src/drum_variation_ai.py --watch --type groove_vae
```

This monitors the CHULOOPA directory and generates variations when drum files change.

## How It Works

### 1. BPM Estimation

Since CHULOOPA patterns have arbitrary durations, the script estimates the tempo by assuming the loop is 1, 2, or 4 bars and picking whichever gives a BPM in the 60-180 range:

```python
def estimate_bpm_from_duration(duration, min_bpm=60, max_bpm=180):
    for bars in [2, 1, 4]:  # Try 2 bars first (most common)
        bpm = (bars * 4 * 60) / duration
        if min_bpm <= bpm <= max_bpm:
            return bpm, bars
```

Example: A 5.1 second loop is estimated as 2 bars at ~94 BPM.

### 2. Latent Space Interpolation

GrooVAE encodes drum patterns into a 256-dimensional latent space. Variations are created by:

1. Encode input pattern to latent vector `z`
2. Generate random latent vector `z_random`
3. Interpolate: `z_varied = z + temperature * (z_random - z)`
4. Decode `z_varied` back to drum pattern

This produces musically coherent variations because the latent space captures learned drum patterns.

### 3. Duration Preservation

The output is scaled to exactly match the input loop duration:

1. Find the time span of output notes
2. Calculate scale factor: `target_duration / output_span`
3. Apply scaling to all timestamps
4. Recalculate delta_times for CHULOOPA format

## File Format

Input/output uses CHULOOPA's drum format:

```
# Track Drum Data (AI Generated Variation)
# Format: DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME
# Classes: 0=kick, 1=snare, 2=hat
# Total loop duration: 5.114195 seconds
0,0.385210,0.157480,0.541332
1,0.926542,0.622047,0.396828
2,1.323370,0.503937,0.737898
```

- `DRUM_CLASS`: 0=kick, 1=snare, 2=hat
- `TIMESTAMP`: Seconds from loop start
- `VELOCITY`: 0.0-1.0
- `DELTA_TIME`: Seconds until next hit (last hit: time to loop end)

## Available GrooVAE Models

| Model | Description |
|-------|-------------|
| `groovae_2bar_humanize` | Adds human-like timing/velocity variations (default) |
| `groovae_2bar_add_closed_hh` | Adds hi-hat patterns to sparse inputs |
| `groovae_2bar_tap_fixed_velocity` | Converts tapped rhythm to full drum pattern |
| `groovae_4bar` | 4-bar patterns (longer context) |

To use a different model, download its checkpoint and update the path in the script.

## Troubleshooting

### "GrooVAE not available - magenta not installed"

Ensure you're using the correct virtual environment:
```bash
source venv_magenta/bin/activate
which python  # Should show venv_magenta path
```

### "Failed to load GrooVAE checkpoint"

The checkpoint path must be the file prefix, not the directory:
```
Correct:   models/groovae_2bar_humanize/model.ckpt-3061
Incorrect: models/groovae_2bar_humanize/
```

### TensorFlow warnings

The deprecation warnings are normal and don't affect functionality. They occur because Magenta uses older TensorFlow APIs.

### Memory issues

GrooVAE loads a large model (~100MB). If you encounter memory issues:
1. Close other applications
2. Use `--temperature` closer to 0 (less computation)
3. Process one file at a time

## Integration with CHULOOPA

1. Record a drum pattern in CHULOOPA (exports to `track_N_drums.txt`)
2. Run the variation script to overwrite the file
3. Use MIDI trigger (G1/G#1/A1) in CHULOOPA to load the variation
4. The new pattern plays with the same loop duration

## References

- [Apple Silicon Magenta Requirements](https://gist.github.com/xstasi/30123f5976abb5b6c90114b92986a155) - Community requirements file for M1/M2
- [GrooVAE Paper](https://arxiv.org/abs/1905.06118) - "Learning to Groove with Inverse Sequence Transformations"
- [Magenta GitHub](https://github.com/magenta/magenta)
- [MusicVAE](https://magenta.tensorflow.org/music-vae) - The underlying VAE architecture
