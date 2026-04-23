# Rhythmic Creator — CHULOOPA Integration

Quick reference for swapping model variants and timing generation on CPU.

---

## Swapping the grid model checkpoint

The active checkpoint path is a single constant in `src/drum_variation_generator.py:806`:

```python
_GRID_MODEL_PATH = Path(__file__).parent / "models" / "grid_barpair_best_epoch.pt"
```

To test a different checkpoint:
1. Copy the `.pt` file into `src/models/`
2. Edit line 806 to use the new filename
3. Restart the Python watch process

Available checkpoints (see `rhythmic_creator/SUMMARY.md` for full list):
- `grid_barpair_best_epoch.pt` — Grid 1-in-1-out v2 (currently active)
- `baseline_b_best_v2_transformer_GRID.pt` — Grid 1-in-1-out v1 baseline

---

## Switching between GRID and TND inference

Currently only GRID is implemented (`grid_model_variation` at line 981).

When a TND wrapper is added, swap it in at line 1793 in `drum_variation_generator.py`:

```python
# line 1793 — currently:
return grid_model_variation(pattern, spice_level=kwargs.get('temperature', 0.5))

# change to TND wrapper when available:
return tnd_model_variation(pattern, spice_level=kwargs.get('temperature', 0.5))
```

---

## CPU latency timing script

Run from the `src/` directory:

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python - <<'EOF'
import time
from drum_variation_generator import grid_model_variation, DrumPattern, DrumHit

# Minimal 1-bar kick/snare at 120 BPM (loop_duration = 2.0s)
pattern = DrumPattern(
    hits=[
        DrumHit(midi_note=36, timestamp=0.0,  velocity=0.8, delta_time=0.5),
        DrumHit(midi_note=38, timestamp=0.5,  velocity=0.7, delta_time=0.5),
        DrumHit(midi_note=36, timestamp=1.0,  velocity=0.8, delta_time=0.5),
        DrumHit(midi_note=38, timestamp=1.5,  velocity=0.7, delta_time=0.5),
    ],
    loop_duration=2.0
)

print("Warming up...")
grid_model_variation(pattern, spice_level=0.5)  # discard first run (model load)

print("Timing 3 runs...")
times = []
for i in range(3):
    t0 = time.perf_counter()
    grid_model_variation(pattern, spice_level=0.5)
    elapsed = time.perf_counter() - t0
    times.append(elapsed)
    print(f"  Run {i+1}: {elapsed:.3f}s")

print(f"Mean: {sum(times)/len(times):.3f}s  Min: {min(times):.3f}s  Max: {max(times):.3f}s")
EOF
```
