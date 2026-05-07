# Grid Model Integration Design
**Date:** 2026-04-22  
**Status:** Pending user review

---

## Context

Jake Chen has released an updated drum variation model (`grid_barpair_best_epoch.pt`). This replaces both the old Transformer-LSTM+FNN hybrid currently used in CHULOOPA and the intermediate grid model (`baseline_b_best_v2_transformer_GRID.pt`).

The goal of this work is:
1. Add a `notes.md` documenting the new token format
2. Write a standalone test script that runs the new model against a real CHULOOPA recording
3. If the test succeeds, swap the new model into the live pipeline

---

## New Model Summary

**Architecture:** `GPTBarPair` — GPT-style causal Transformer decoder (6 layers, 8 heads, 256 embd, 4.8M params). No LSTM, no type embeddings. Hand-rolled blocks identical to nanoGPT/GPT-2.

**Token format:**
```
<SOS> P{step} N{pitch} P{step} N{pitch} ... <SEP> P{step} N{pitch} ... <EOS>
```
- `P{step}`: 16th-note grid position, 0–15 (one bar = 16 steps)
- `N{pitch}`: MIDI note number
- `<SOS>` opens the sequence, `<SEP>` separates bar 1 (context) from bar 2 (target), `<EOS>` closes
- Vocab size: 42 tokens. `stoi`/`itos` embedded in checkpoint — no separate vocab file needed.

**Conditioning:** The model is trained exclusively to predict tokens after `<SEP>`. Given `<SOS> [bar1] <SEP>`, it generates `[bar2] <EOS>`. This is a proper bar-pair conditional model, not a continuation model.

**Block size:** 198 — can hold dense patterns without truncation.

**Checkpoint:** `checkpoints_grid_barpair/grid_barpair_best_epoch.pt`  
Best val loss: 0.8383 at epoch 15/30.

---

## Token Format Notes (for notes.md)

The dataset (`e-gmd-barpairs_v2`) ships two representations:
- `*_grid.txt` — P/N grid format (what the model uses)
- `*_tnd.txt` — T/N/D delta-time format (research comparison; NOT used by this model)

The model only uses the grid format. TIME_STEP and T/N/D tokens are irrelevant to this checkpoint.

---

## Design

### 1. File layout

```
rhythmic_creator/rhythmic_creator_grid_based/
├── 4:22:26 - updated/
│   ├── checkpoints_grid_barpair/
│   │   └── grid_barpair_best_epoch.pt        ← new checkpoint (source)
│   └── transformer_GRID_pair_epoch (1).ipynb ← Jake's training notebook
└── notes.md                                  ← NEW: token format documentation

CHULOOPA/src/
├── models/
│   ├── transformer_LSTM_FNN_hybrid.pt        ← existing (old model, stays for now)
│   ├── grid_barpair_best_epoch.pt            ← NEW: copied here as permanent home
│   └── rhythmic_creator_grid/
│       ├── __init__.py
│       └── grid_model.py                     ← NEW: RhythmicCreatorGridModel class
├── test_grid_model.py                        ← NEW: standalone test script
└── format_converters.py                      ← MODIFIED: add grid conversion helpers
```

---

### 2. `format_converters.py` additions

Two new functions added alongside the existing converters:

**`chuloopa_txt_to_grid_tokens(filepath, bpm) -> (list[str], float)`**
- Reads a `track_N_drums.txt` file
- Computes `step_duration = (60 / bpm) / 4` (16th note at given BPM)
- For each hit: `step = round(timestamp / step_duration)`, clamped to 0–15
- Returns `["P0", "N36", "P4", "N38", ...]` and the inferred `bar_duration`
- Skips any note whose `N{pitch}` token is not in the model vocab (logs a warning)
- Sorts by (step, pitch) to match training data ordering

**`grid_tokens_to_chuloopa_txt(tokens, bpm, output_filepath)`**
- Inverse: `["P0", "N36", ...]` → writes `track_N_drums.txt`
- Computes timestamp from step: `timestamp = step * step_duration`
- Recalculates delta_times from sorted timestamps
- Velocity: constant 0.75 (no velocity info in grid tokens)

---

### 3. `RhythmicCreatorGridModel` class

Located at `src/models/rhythmic_creator_grid/grid_model.py`.

```python
class RhythmicCreatorGridModel:
    def __init__(self, checkpoint_path: str, device: str = None)
    def generate_variation(
        self,
        context_tokens: list[str],
        temperature: float = 1.0,
        top_k: int = None,
        max_new_tokens: int = 64,
    ) -> list[str]
```

Responsibilities:
- Loads checkpoint; reconstructs `GPTBarPair` architecture from embedded config
- Loads `stoi`/`itos` from checkpoint (no external vocab file)
- `generate_variation` wraps `generate_next_bar_from_context` from Jake's notebook
- Returns only the target tokens (after `<SEP>`, before `<EOS>`)
- Auto-selects device (MPS → CUDA → CPU)

The class intentionally does **not** handle BPM or file I/O — those live in `format_converters.py` and the test/integration scripts.

---

### 4. `test_grid_model.py`

Standalone script. Run from `src/`:

```
python test_grid_model.py [--drums-file PATH] [--bpm BPM] [--temperature T] [--top-k K]
```

Defaults: `--drums-file tracks/track_0/track_0_drums.txt`, `--bpm auto`, `--temperature 1.0`

**BPM inference:**  
`bpm = (60 * 4) / loop_duration` — the full recording is always treated as exactly 1 bar. No override needed; no `--bpm` flag.

**Flow:**
1. Read `track_0_drums.txt` → parse loop_duration, hits
2. Infer BPM (or use provided value)
3. `chuloopa_txt_to_grid_tokens(...)` → context tokens; log any skipped notes
4. Load `RhythmicCreatorGridModel`
5. `model.generate_variation(context_tokens, temperature, top_k)`
6. Convert context tokens → quantized CHULOOPA file (`track_0_drums_quantized.txt`)
7. Convert target tokens → variation CHULOOPA file (`variations/track_0_drums_var_grid.txt`)
8. Print side-by-side: original timestamps vs quantized timestamps vs variation timestamps

**Outputs:**
- `src/tracks/track_0/track_0_drums_quantized.txt` — original recording snapped to grid (same loop duration)
- `src/tracks/track_0/variations/track_0_drums_var_grid.txt` — generated bar (same loop duration)

---

### 5. Quantization coherence

Both the quantized original and the variation share the same BPM and step grid, so switching between them at a loop boundary in ChucK will be seamless. The only feel change is the initial snap from the raw recording to the quantized version — which is expected to be subtle for tight beatbox input.

The raw recording file (`track_0_drums.txt`) is never modified. CHULOOPA can continue to use it as the "live" loop while the quantized pair is used for variation switching.

---

### 6. notes.md (in `rhythmic_creator_grid_based/`)

Short reference doc covering:
- P/N grid token format (what the model uses)
- T/N/D delta-time format (dataset alternative, not used by model)
- `<SEP>` conditioning structure
- BPM → step duration formula
- Vocab scope (P0–P15, standard GM drum pitches only)

---

## Out of scope (this iteration)

- Swapping the model into `drum_variation_generator.py` — happens only after test script validates output quality
- Multi-bar contexts — recording is always 1 bar in this version; no truncation logic needed
- Velocity in variation output — grid tokens carry no velocity; constant 0.75 used
- T/N/D model variant — dataset exists but no trained checkpoint provided

---

## Success criteria for test script

1. Script runs without error on `track_0_drums.txt`
2. Context tokens printed show a plausible quantized version of the recording
3. Variation tokens are valid P/N pairs within P0–P15
4. Both output `.txt` files load correctly in CHULOOPA (manual check)
5. Switching between quantized original and variation in ChucK sounds musically coherent
