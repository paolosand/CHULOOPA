# Rhythmic Creator SUMMARY.md + INTEGRATION.md Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write two concise reference docs — a model variant registry + eval guide for the `rhythmic_creator` repo, and a model-swapping guide for CHULOOPA.

**Architecture:** Two standalone markdown files with no code changes. SUMMARY.md lives in the rhythmic_creator repo as a living doc updated as Jake sends new checkpoints. INTEGRATION.md lives in CHULOOPA/src/models/ as a quick swap/test reference.

**Tech Stack:** Markdown only.

---

## Files

| Action | Path | Purpose |
|--------|------|---------|
| Create | `/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/rhythmic_creator/SUMMARY.md` | Model registry + eval dimensions |
| Create | `/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src/models/INTEGRATION.md` | Swap/test guide for CHULOOPA |

---

## Task 1: Write SUMMARY.md

**Files:**
- Create: `/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/rhythmic_creator/SUMMARY.md`

- [ ] **Step 1: Write SUMMARY.md**

Write the following content exactly to `rhythmic_creator/SUMMARY.md`:

```markdown
# Rhythmic Creator — Model Summary

Personal dev reference for evaluation work. Add rows as Jake sends new checkpoints.

---

## Model Variant Registry

| Variant | Format | Context | Output | Dataset | Checkpoint | Status |
|---------|--------|---------|--------|---------|------------|--------|
| Grid 1-in-1-out v1 (baseline) | GRID | 1 bar | 1 bar | no-repeat | `rhythmic_creator_grid_based/baseline_b_best_v2_transformer_GRID.pt` | ✅ |
| Grid 1-in-1-out v2 (updated) | GRID | 1 bar | 1 bar | no-repeat | `rhythmic_creator_grid_based/4:22:26 - updated/checkpoints_inspect/checkpoints_grid_barpair/grid_barpair_best_epoch.pt` | ✅ |
| Grid 2-in-1-out | GRID | 2 bars | 1 bar | no-repeat | — | ⏳ |
| Grid 4-in-1-out | GRID | 4 bars | 1 bar | no-repeat | — | ⏳ |
| TND 1-in-1-out | TND | 1 bar | 1 bar | no-repeat | — | ⏳ |
| TND 2-in-2-out | TND | 2 bars | 2 bars | no-repeat | — | ⏳ |
| Grid 1-in-1-out (repeat dataset) | GRID | 1 bar | 1 bar | repeat | — | ⏳ |
| Grid 2-in-1-out (repeat dataset) | GRID | 2 bars | 1 bar | repeat | — | ⏳ |
| Grid 4-in-1-out (repeat dataset) | GRID | 4 bars | 1 bar | repeat | — | ⏳ |

---

## Format Reference

### GRID

- Token pairs: `P{step} N{pitch}` — position (P0–P15 = 16th-note grid) + MIDI note
- Sequence: `<SOS> [context bar(s)] <SEP> [output bar] <EOS>`
- Vocab: 42 tokens; embedded in checkpoint (no separate vocab file needed)
- BPM → step duration: `step = (60.0 / bpm) / 4.0`; bar = `step * 16`
- Key CHULOOPA pitches: N36=kick, N38=snare, N42=closed hat

### TND (delta-time)

- Token triplets: `T{delta} N{pitch} D{duration}` — TIME_STEP = 0.01s (T11 = 110ms)
- Sequence: `<SOS> [context] <SEP> [output] <EOS>`
- Preserves micro-timing nuance; no grid quantization
- Dataset files exist (`*_tnd.txt` in `e-gmd-barpairs_v2`) but no checkpoint available yet

---

## Evaluation Dimensions

### Latency (CPU)

- Target: <500ms for real-time use (generation can overlap with loop playback in CHULOOPA)
- Measure: wall-clock time from inference call → full bar returned
- Test device: MacBook, no GPU — see `CHULOOPA/src/models/INTEGRATION.md` for timing script

### Real-time Co-creation Suitability

- Generation speed is the primary constraint for live use
- Longer context (2-bar, 4-bar) may improve rhythmic coherence at the cost of latency
- GRID snaps timing to 16th-note grid; TND preserves micro-timing when available

### Musician Evaluation

- Criteria to be defined with Jake
- Expected dimensions: rhythmic coherence, stylistic consistency, performance feel
```

- [ ] **Step 2: Verify the file was written**

```bash
head -5 "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/rhythmic_creator/SUMMARY.md"
```

Expected output:
```
# Rhythmic Creator — Model Summary

Personal dev reference for evaluation work. Add rows as Jake sends new checkpoints.
```

---

## Task 2: Write INTEGRATION.md

**Files:**
- Create: `/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src/models/INTEGRATION.md`

- [ ] **Step 1: Write INTEGRATION.md**

Write the following content exactly to `CHULOOPA/src/models/INTEGRATION.md`:

```markdown
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

Currently only GRID is implemented (`grid_model_variation` at line 979).

When a TND wrapper is added, swap it in at line 1804 in `drum_variation_generator.py`:

```python
# line 1804 — currently:
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
```

- [ ] **Step 2: Verify the file was written**

```bash
head -5 "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src/models/INTEGRATION.md"
```

Expected output:
```
# Rhythmic Creator — CHULOOPA Integration

Quick reference for swapping model variants and timing generation on CPU.
```

---

## Task 3: Commit both files

- [ ] **Step 1: Stage and commit SUMMARY.md**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/rhythmic_creator"
git add SUMMARY.md
git commit -m "docs: add model variant registry and evaluation guide"
```

- [ ] **Step 2: Stage and commit INTEGRATION.md**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/models/INTEGRATION.md
git commit -m "docs: add rhythmic creator model swap and latency guide"
```

- [ ] **Step 3: Verify both commits**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/rhythmic_creator" && git log --oneline -1
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA" && git log --oneline -1
```

Expected: both repos show the new commit at HEAD.
