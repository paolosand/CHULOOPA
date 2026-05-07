# Grid Model Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Jake Chen's new `GPTBarPair` grid-based drum variation model into CHULOOPA with a standalone test script that reads a live recording, generates a variation, and writes both a quantized original and a generated bar as CHULOOPA-compatible `.txt` files.

**Architecture:** A new `RhythmicCreatorGridModel` wrapper class loads the checkpoint (which embeds its own vocab), a pair of converter functions in `format_converters.py` handle CHULOOPA-txt ↔ P/N-token conversion, and a standalone `test_grid_model.py` script wires them together. BPM is always inferred from loop duration (recording = exactly 1 bar).

**Tech Stack:** Python 3.10+, PyTorch, pytest. No new pip dependencies beyond what CHULOOPA already uses.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `src/models/grid_barpair_best_epoch.pt` | Copy from Jake's folder | Permanent home for new checkpoint |
| `rhythmic_creator/rhythmic_creator_grid_based/notes.md` | Create | Token format documentation |
| `src/models/rhythmic_creator_grid/__init__.py` | Create | Package marker |
| `src/models/rhythmic_creator_grid/grid_model.py` | Create | `GPTBarPair` nn.Module + `RhythmicCreatorGridModel` wrapper |
| `src/format_converters.py` | Modify | Add `chuloopa_txt_to_grid_tokens` + `grid_tokens_to_chuloopa_txt` |
| `src/tests/test_grid_converters.py` | Create | Unit tests for the two converter functions |
| `src/test_grid_model.py` | Create | End-to-end CLI test script |

---

## Task 1: Copy checkpoint and write notes.md

**Files:**
- Copy: `src/models/grid_barpair_best_epoch.pt`
- Create: `rhythmic_creator/rhythmic_creator_grid_based/notes.md`

- [ ] **Step 1: Copy the checkpoint to its permanent location**

```bash
cp "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/rhythmic_creator/rhythmic_creator_grid_based/4:22:26 - updated/checkpoints_inspect/checkpoints_grid_barpair/grid_barpair_best_epoch.pt" \
   "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src/models/grid_barpair_best_epoch.pt"
```

Verify: `ls -lh "src/models/grid_barpair_best_epoch.pt"` — should show ~19MB.

- [ ] **Step 2: Verify the checkpoint loads correctly**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python3 -c "
import torch
ckpt = torch.load('models/grid_barpair_best_epoch.pt', map_location='cpu', weights_only=False)
print('vocab size:', len(ckpt['vocab']))
print('config:', ckpt['config'])
print('sample vocab:', ckpt['vocab'][:10])
assert len(ckpt['vocab']) == 42
assert '<SEP>' in ckpt['stoi']
print('OK')
"
```

Expected output:
```
vocab size: 42
config: {'block_size': 199, 'vocab_size': 42, 'n_embd': 256, 'n_head': 8, 'n_layer': 6, 'dropout': 0.2}
sample vocab: ['<EOS>', '<PAD>', '<SEP>', '<SOS>', 'N22', ...]
OK
```

- [ ] **Step 3: Write notes.md**

Create `/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/rhythmic_creator/rhythmic_creator_grid_based/notes.md`:

```markdown
# rhythmic_creator_grid_based — Token Format Notes

## Active model

`4:22:26 - updated/checkpoints_grid_barpair/grid_barpair_best_epoch.pt`

Architecture: GPTBarPair — GPT-style causal Transformer decoder (6 layers, 8 heads,
256 embd, 4.8M params). No LSTM. Vocab and config are embedded in the checkpoint;
no separate vocab file is needed.

---

## Token format used by the model: P/N grid

One bar = 16 16th-note steps (P0–P15). Each note is a pair:

```
P{step}  N{pitch}
```

- `P{step}` — 16th-note grid position, 0–15
- `N{pitch}` — MIDI note number (GM percussion range)

A full bar-pair sequence looks like:

```
<SOS> P0 N36 P4 N38 P8 N36 P12 N38 <SEP> P2 N36 P4 N38 P6 N42 <EOS>
```

- `<SOS>` — opens the sequence
- `<SEP>` — separates bar 1 (context/input) from bar 2 (target/output)
- `<EOS>` — closes the sequence
- `<PAD>` — padding token used during training only; never generated

The model is trained to predict tokens **after** `<SEP>` only (masked loss on context side).
At inference: feed `<SOS> [bar1 tokens] <SEP>`, model generates `[bar2 tokens] <EOS>`.

### BPM → step duration formula

```
step_duration = (60.0 / bpm) / 4.0   # duration of one 16th note in seconds
bar_duration  = step_duration * 16    # = (60.0 / bpm) * 4
```

Example at 120 BPM: step_duration = 0.125s, bar_duration = 2.0s.

### Vocab scope

42 tokens total: `<EOS>`, `<PAD>`, `<SEP>`, `<SOS>`, `N22`–`N59` (GM percussion subset),
`P0`–`P15`.

Notes in vocab: 22, 26, 36, 37, 38, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52,
53, 55, 57, 58, 59. CHULOOPA's primary notes (36=kick, 38=snare, 42=hat) are all present.

---

## Alternative format in dataset: T/N/D delta-time

The dataset (`e-gmd-barpairs_v2`) also ships `*_tnd.txt` files using a different
representation:

```
<SOS> T{delta} N{pitch} D{duration} T{delta} N{pitch} D{duration} ... <EOS>
```

- `T{n}` — time since previous note, in units of TIME_STEP = 0.01s (so T11 = 110ms)
- `N{pitch}` — MIDI note number
- `D{n}` — note duration, in units of TIME_STEP

**This format is NOT used by the current checkpoint.** No T or D tokens appear in the
model vocab. The T/N/D files exist for research comparison only.

---

## Dataset

`e-gmd-barpairs_v2` — Expanded Groove MIDI Dataset, preprocessed into consecutive
1-bar pairs. Train: 12,085 pairs. Val: 1,875. Test: 1,654. BPM range: 75–132.
```

- [ ] **Step 4: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/models/grid_barpair_best_epoch.pt
git add "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/rhythmic_creator/rhythmic_creator_grid_based/notes.md"
git commit -m "feat: add grid model checkpoint and token format notes"
```

---

## Task 2: Add grid converter functions to format_converters.py (TDD)

**Files:**
- Modify: `src/format_converters.py`
- Create: `src/tests/test_grid_converters.py`

- [ ] **Step 1: Write failing tests**

Create `src/tests/test_grid_converters.py`:

```python
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from format_converters import chuloopa_txt_to_grid_tokens, grid_tokens_to_chuloopa_txt


# ── fixtures ──────────────────────────────────────────────────────────────────

SIMPLE_DRUMS = """\
# Track 0 Drum Data
# Format: MIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME
# MIDI_NOTE: GM MIDI note number (36=kick, 38=snare, 42=hat, etc.)
# DELTA_TIME: Duration until next hit (for last hit: time until loop end)
# Total loop duration: 2.000000 seconds
36,0.000000,0.770000,0.500000
38,0.500000,0.740000,0.500000
36,1.000000,0.725000,0.500000
38,1.500000,0.787000,0.500000
"""

SLIGHTLY_OFF_DRUMS = """\
# Total loop duration: 2.000000 seconds
36,0.010000,0.750000,0.490000
38,0.515000,0.750000,0.485000
36,1.005000,0.750000,0.495000
38,1.490000,0.750000,0.510000
"""


def make_temp_file(content: str) -> str:
    f = tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False)
    f.write(content)
    f.close()
    return f.name


# ── chuloopa_txt_to_grid_tokens ───────────────────────────────────────────────

def test_on_grid_hits_snap_exactly():
    path = make_temp_file(SIMPLE_DRUMS)
    try:
        # At 120 BPM: step_duration = 0.125s
        # 0.0s→P0, 0.5s→P4, 1.0s→P8, 1.5s→P12
        tokens, loop_duration = chuloopa_txt_to_grid_tokens(path, bpm=120.0)
        assert tokens == ["P0", "N36", "P4", "N38", "P8", "N36", "P12", "N38"]
        assert loop_duration == 2.0
    finally:
        os.unlink(path)


def test_slightly_off_grid_hits_snap_to_nearest_step():
    path = make_temp_file(SLIGHTLY_OFF_DRUMS)
    try:
        # step_duration = 0.125s
        # 0.010 → round(0.010/0.125)=0 → P0
        # 0.515 → round(0.515/0.125)=4 → P4
        # 1.005 → round(1.005/0.125)=8 → P8
        # 1.490 → round(1.490/0.125)=12 → P12
        tokens, loop_duration = chuloopa_txt_to_grid_tokens(path, bpm=120.0)
        assert tokens == ["P0", "N36", "P4", "N38", "P8", "N36", "P12", "N38"]
    finally:
        os.unlink(path)


def test_step_clamped_to_15():
    # A hit right at or after loop end should clamp to P15, not overflow
    content = "# Total loop duration: 2.000000 seconds\n36,1.990000,0.750000,0.010000\n"
    path = make_temp_file(content)
    try:
        tokens, _ = chuloopa_txt_to_grid_tokens(path, bpm=120.0)
        # 1.990 / 0.125 = 15.92 → round → 16 → clamped to 15
        assert tokens == ["P15", "N36"]
    finally:
        os.unlink(path)


def test_tokens_sorted_by_step_then_pitch():
    # Two notes at the same step should be sorted by pitch (ascending)
    content = "# Total loop duration: 2.000000 seconds\n42,0.000000,0.75,0.5\n36,0.000000,0.75,0.5\n"
    path = make_temp_file(content)
    try:
        tokens, _ = chuloopa_txt_to_grid_tokens(path, bpm=120.0)
        # pitch 36 < pitch 42, so N36 should come before N42 at same step
        assert tokens == ["P0", "N36", "P0", "N42"]
    finally:
        os.unlink(path)


def test_returns_loop_duration():
    path = make_temp_file(SIMPLE_DRUMS)
    try:
        _, loop_duration = chuloopa_txt_to_grid_tokens(path, bpm=120.0)
        assert abs(loop_duration - 2.0) < 1e-9
    finally:
        os.unlink(path)


# ── grid_tokens_to_chuloopa_txt ───────────────────────────────────────────────

def test_timestamps_computed_from_steps():
    tokens = ["P0", "N36", "P4", "N38", "P8", "N36", "P12", "N38"]
    bpm = 120.0
    loop_duration = 2.0
    path = tempfile.mktemp(suffix='.txt')
    try:
        grid_tokens_to_chuloopa_txt(tokens, bpm=bpm, loop_duration=loop_duration, output_filepath=path)
        hits = []
        with open(path) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    parts = line.strip().split(',')
                    hits.append((int(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])))

        assert len(hits) == 4
        # step_duration = 0.125s
        assert abs(hits[0][1] - 0.0) < 1e-6    # P0 → 0.0s
        assert abs(hits[1][1] - 0.5) < 1e-6    # P4 → 0.5s
        assert abs(hits[2][1] - 1.0) < 1e-6    # P8 → 1.0s
        assert abs(hits[3][1] - 1.5) < 1e-6    # P12 → 1.5s
    finally:
        if os.path.exists(path):
            os.unlink(path)


def test_delta_times_correct():
    tokens = ["P0", "N36", "P4", "N38", "P8", "N36", "P12", "N38"]
    bpm = 120.0
    loop_duration = 2.0
    path = tempfile.mktemp(suffix='.txt')
    try:
        grid_tokens_to_chuloopa_txt(tokens, bpm=bpm, loop_duration=loop_duration, output_filepath=path)
        deltas = []
        with open(path) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    deltas.append(float(line.strip().split(',')[3]))

        # Each hit 0.5s apart; last delta = loop_duration - 1.5s = 0.5s
        assert all(abs(d - 0.5) < 1e-6 for d in deltas)
    finally:
        if os.path.exists(path):
            os.unlink(path)


def test_velocity_is_constant_0_75():
    tokens = ["P0", "N36", "P8", "N38"]
    path = tempfile.mktemp(suffix='.txt')
    try:
        grid_tokens_to_chuloopa_txt(tokens, bpm=120.0, loop_duration=2.0, output_filepath=path)
        with open(path) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    vel = float(line.strip().split(',')[2])
                    assert abs(vel - 0.75) < 1e-6
    finally:
        if os.path.exists(path):
            os.unlink(path)


def test_loop_duration_in_header():
    tokens = ["P0", "N36"]
    path = tempfile.mktemp(suffix='.txt')
    try:
        grid_tokens_to_chuloopa_txt(tokens, bpm=120.0, loop_duration=3.141593, output_filepath=path)
        with open(path) as f:
            content = f.read()
        assert "3.141593" in content
    finally:
        if os.path.exists(path):
            os.unlink(path)


def test_roundtrip_snaps_cleanly():
    # Off-grid input → quantize → write → read back and confirm timestamps are on grid
    path_in = make_temp_file(SLIGHTLY_OFF_DRUMS)
    path_out = tempfile.mktemp(suffix='.txt')
    try:
        tokens, loop_duration = chuloopa_txt_to_grid_tokens(path_in, bpm=120.0)
        grid_tokens_to_chuloopa_txt(tokens, bpm=120.0, loop_duration=loop_duration, output_filepath=path_out)

        step_duration = (60.0 / 120.0) / 4.0
        with open(path_out) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    ts = float(line.strip().split(',')[1])
                    remainder = ts % step_duration
                    assert remainder < 1e-9 or abs(remainder - step_duration) < 1e-9, \
                        f"Timestamp {ts} is not on the 16th-note grid"
    finally:
        os.unlink(path_in)
        if os.path.exists(path_out):
            os.unlink(path_out)
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python -m pytest tests/test_grid_converters.py -v 2>&1 | head -30
```

Expected: `ImportError: cannot import name 'chuloopa_txt_to_grid_tokens' from 'format_converters'`

- [ ] **Step 3: Add `chuloopa_txt_to_grid_tokens` to `format_converters.py`**

Append at the end of `src/format_converters.py`:

```python

# ── Grid model converters ──────────────────────────────────────────────────────

def chuloopa_txt_to_grid_tokens(filepath: str, bpm: float) -> tuple:
    """
    Convert a CHULOOPA drum txt file to P/N grid tokens for GPTBarPair.

    Returns:
        tokens:        list[str] of alternating "P{step}" and "N{pitch}" tokens,
                       sorted by (step, pitch) to match training-data ordering.
        loop_duration: float, total loop duration in seconds (= one bar duration).
    """
    hits = []
    loop_duration = None

    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if line.startswith('# Total loop duration:'):
                loop_duration = float(line.split(':')[1].strip().split()[0])
            elif line and not line.startswith('#'):
                parts = line.split(',')
                midi_note = int(parts[0])
                timestamp = float(parts[1])
                hits.append((timestamp, midi_note))

    if loop_duration is None:
        raise ValueError(f"No '# Total loop duration:' header found in {filepath}")

    step_duration = (60.0 / bpm) / 4.0

    events = []
    for timestamp, midi_note in hits:
        step = int(round(timestamp / step_duration))
        step = max(0, min(15, step))
        events.append((step, midi_note))

    events.sort(key=lambda x: (x[0], x[1]))

    tokens = []
    for step, pitch in events:
        tokens.append(f"P{step}")
        tokens.append(f"N{pitch}")

    return tokens, loop_duration


def grid_tokens_to_chuloopa_txt(
    tokens: list,
    bpm: float,
    loop_duration: float,
    output_filepath: str,
) -> None:
    """
    Convert P/N grid tokens back to CHULOOPA drum txt format.

    Timestamps are derived from step positions: timestamp = step * step_duration.
    Velocity is fixed at 0.75 (grid tokens carry no velocity information).
    Delta times are recalculated from sorted timestamps.
    """
    step_duration = (60.0 / bpm) / 4.0

    hits = []
    i = 0
    while i < len(tokens) - 1:
        if tokens[i].startswith('P') and tokens[i + 1].startswith('N'):
            step = int(tokens[i][1:])
            pitch = int(tokens[i + 1][1:])
            timestamp = step * step_duration
            hits.append((timestamp, pitch))
            i += 2
        else:
            i += 1

    hits.sort(key=lambda x: (x[0], x[1]))

    delta_times = []
    for j, (ts, _) in enumerate(hits):
        if j < len(hits) - 1:
            delta_times.append(hits[j + 1][0] - ts)
        else:
            delta_times.append(loop_duration - ts)

    with open(output_filepath, 'w') as f:
        f.write("# Track Drum Data\n")
        f.write("# Format: MIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME\n")
        f.write("# MIDI_NOTE: GM MIDI note number (36=kick, 38=snare, 42=hat, etc.)\n")
        f.write("# DELTA_TIME: Duration until next hit (for last hit: time until loop end)\n")
        f.write(f"# Total loop duration: {loop_duration:.6f} seconds\n")
        for (ts, pitch), dt in zip(hits, delta_times):
            f.write(f"{pitch},{ts:.6f},0.750000,{dt:.6f}\n")
```

- [ ] **Step 4: Run tests — all should pass**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python -m pytest tests/test_grid_converters.py -v
```

Expected:
```
PASSED tests/test_grid_converters.py::test_on_grid_hits_snap_exactly
PASSED tests/test_grid_converters.py::test_slightly_off_grid_hits_snap_to_nearest_step
PASSED tests/test_grid_converters.py::test_step_clamped_to_15
PASSED tests/test_grid_converters.py::test_tokens_sorted_by_step_then_pitch
PASSED tests/test_grid_converters.py::test_returns_loop_duration
PASSED tests/test_grid_converters.py::test_timestamps_computed_from_steps
PASSED tests/test_grid_converters.py::test_delta_times_correct
PASSED tests/test_grid_converters.py::test_velocity_is_constant_0_75
PASSED tests/test_grid_converters.py::test_loop_duration_in_header
PASSED tests/test_grid_converters.py::test_roundtrip_snaps_cleanly
10 passed
```

- [ ] **Step 5: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/format_converters.py src/tests/test_grid_converters.py
git commit -m "feat: add grid token converters to format_converters"
```

---

## Task 3: Implement GPTBarPair and RhythmicCreatorGridModel

**Files:**
- Create: `src/models/rhythmic_creator_grid/__init__.py`
- Create: `src/models/rhythmic_creator_grid/grid_model.py`

- [ ] **Step 1: Create the package init**

Create `src/models/rhythmic_creator_grid/__init__.py` (empty file):

```python
```

- [ ] **Step 2: Write a failing load test**

Append to `src/tests/test_grid_converters.py` (or create a separate file `src/tests/test_grid_model_class.py`):

Create `src/tests/test_grid_model_class.py`:

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from models.rhythmic_creator_grid.grid_model import RhythmicCreatorGridModel

CKPT = str(Path(__file__).parent.parent / "models" / "grid_barpair_best_epoch.pt")


def test_model_loads():
    model = RhythmicCreatorGridModel(CKPT, device='cpu')
    assert '<SOS>' in model.stoi
    assert '<SEP>' in model.stoi
    assert '<EOS>' in model.stoi
    assert 'P0' in model.stoi
    assert 'P15' in model.stoi
    assert 'N36' in model.stoi
    assert 'N38' in model.stoi
    assert 'N42' in model.stoi


def test_generate_returns_valid_pn_pairs():
    model = RhythmicCreatorGridModel(CKPT, device='cpu')
    context = ['P0', 'N36', 'P4', 'N38', 'P8', 'N36', 'P12', 'N38']
    result = model.generate_variation(context, temperature=1.0, max_new_tokens=64)

    assert len(result) > 0
    assert len(result) % 2 == 0, f"Expected even number of tokens, got {len(result)}: {result}"

    for i in range(0, len(result), 2):
        assert result[i].startswith('P'), f"Position {i} should be P token, got {result[i]}"
        assert result[i + 1].startswith('N'), f"Position {i+1} should be N token, got {result[i+1]}"
        step = int(result[i][1:])
        assert 0 <= step <= 15, f"Step {step} out of 0-15 range at position {i}"


def test_generate_no_special_tokens_in_output():
    model = RhythmicCreatorGridModel(CKPT, device='cpu')
    context = ['P0', 'N36', 'P8', 'N38']
    result = model.generate_variation(context, temperature=1.0, max_new_tokens=64)
    for tok in result:
        assert tok not in ('<SOS>', '<SEP>', '<EOS>', '<PAD>'), \
            f"Special token {tok} leaked into output"
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python -m pytest tests/test_grid_model_class.py -v 2>&1 | head -10
```

Expected: `ModuleNotFoundError: No module named 'models.rhythmic_creator_grid.grid_model'`

- [ ] **Step 4: Implement `grid_model.py`**

Create `src/models/rhythmic_creator_grid/grid_model.py`:

```python
import math
from pathlib import Path
from typing import Optional

import torch
import torch.nn as nn
import torch.nn.functional as F


class CausalSelfAttention(nn.Module):
    def __init__(self, n_embd: int, n_head: int, block_size: int, dropout: float):
        super().__init__()
        assert n_embd % n_head == 0
        self.n_head = n_head
        self.head_dim = n_embd // n_head

        self.qkv = nn.Linear(n_embd, 3 * n_embd)
        self.proj = nn.Linear(n_embd, n_embd)
        self.attn_drop = nn.Dropout(dropout)
        self.resid_drop = nn.Dropout(dropout)

        mask = torch.tril(torch.ones(block_size - 1, block_size - 1))
        self.register_buffer("mask", mask.view(1, 1, block_size - 1, block_size - 1))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        B, T, C = x.shape
        qkv = self.qkv(x)
        q, k, v = qkv.split(C, dim=2)

        q = q.view(B, T, self.n_head, self.head_dim).transpose(1, 2)
        k = k.view(B, T, self.n_head, self.head_dim).transpose(1, 2)
        v = v.view(B, T, self.n_head, self.head_dim).transpose(1, 2)

        att = (q @ k.transpose(-2, -1)) / math.sqrt(self.head_dim)
        att = att.masked_fill(self.mask[:, :, :T, :T] == 0, float("-inf"))
        att = F.softmax(att, dim=-1)
        att = self.attn_drop(att)

        y = att @ v
        y = y.transpose(1, 2).contiguous().view(B, T, C)
        return self.resid_drop(self.proj(y))


class MLP(nn.Module):
    def __init__(self, n_embd: int, dropout: float):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(n_embd, 4 * n_embd),
            nn.GELU(),
            nn.Linear(4 * n_embd, n_embd),
            nn.Dropout(dropout),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)


class Block(nn.Module):
    def __init__(self, n_embd: int, n_head: int, block_size: int, dropout: float):
        super().__init__()
        self.ln1 = nn.LayerNorm(n_embd)
        self.attn = CausalSelfAttention(n_embd, n_head, block_size, dropout)
        self.ln2 = nn.LayerNorm(n_embd)
        self.mlp = MLP(n_embd, dropout)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = x + self.attn(self.ln1(x))
        x = x + self.mlp(self.ln2(x))
        return x


class GPTBarPair(nn.Module):
    """GPT-style causal Transformer decoder trained on consecutive bar pairs."""

    def __init__(
        self,
        vocab_size: int,
        block_size: int,
        n_embd: int,
        n_head: int,
        n_layer: int,
        dropout: float,
    ):
        super().__init__()
        self.block_size = block_size - 1

        self.token_emb = nn.Embedding(vocab_size, n_embd)
        self.pos_emb = nn.Embedding(self.block_size, n_embd)
        self.drop = nn.Dropout(dropout)

        self.blocks = nn.ModuleList([
            Block(n_embd, n_head, block_size, dropout) for _ in range(n_layer)
        ])
        self.ln_f = nn.LayerNorm(n_embd)
        self.head = nn.Linear(n_embd, vocab_size)

    def forward(self, idx: torch.Tensor) -> torch.Tensor:
        B, T = idx.shape
        pos = torch.arange(0, T, device=idx.device)
        x = self.token_emb(idx) + self.pos_emb(pos)[None, :, :]
        x = self.drop(x)
        for block in self.blocks:
            x = block(x)
        x = self.ln_f(x)
        return self.head(x)


class RhythmicCreatorGridModel:
    """
    Wrapper for Jake Chen's GPTBarPair drum variation model.

    Given a list of P/N tokens representing one bar of context, generates
    a new bar as a list of P/N tokens.

    Usage:
        model = RhythmicCreatorGridModel("path/to/grid_barpair_best_epoch.pt")
        variation = model.generate_variation(["P0", "N36", "P4", "N38", ...])
    """

    def __init__(self, checkpoint_path: str, device: Optional[str] = None):
        if device:
            self.device = device
        elif torch.cuda.is_available():
            self.device = 'cuda'
        elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            self.device = 'mps'
        else:
            self.device = 'cpu'

        ckpt = torch.load(checkpoint_path, map_location=self.device, weights_only=False)

        self.stoi: dict = ckpt['stoi']
        self.itos: dict = ckpt['itos']
        config: dict = ckpt['config']

        self._model = GPTBarPair(
            vocab_size=config['vocab_size'],
            block_size=config['block_size'],
            n_embd=config['n_embd'],
            n_head=config['n_head'],
            n_layer=config['n_layer'],
            dropout=config['dropout'],
        ).to(self.device)

        self._model.load_state_dict(ckpt['model_state_dict'])
        self._model.eval()

    def generate_variation(
        self,
        context_tokens: list,
        temperature: float = 1.0,
        top_k: Optional[int] = None,
        max_new_tokens: int = 64,
    ) -> list:
        """
        Generate a new bar from a list of P/N context tokens.

        Args:
            context_tokens: e.g. ["P0", "N36", "P4", "N38", ...]
            temperature:    sampling temperature (lower = more conservative)
            top_k:          if set, restricts sampling to top-k logits
            max_new_tokens: generation budget (stops earlier at <EOS>)

        Returns:
            list[str] of P/N tokens for the generated bar, e.g.
            ["P2", "N36", "P4", "N38", "P6", "N42", ...]
        """
        unknown = [t for t in context_tokens if t not in self.stoi]
        if unknown:
            raise ValueError(f"Tokens not in model vocab: {unknown}")

        seq = ['<SOS>'] + context_tokens + ['<SEP>']
        ids = [self.stoi[t] for t in seq]
        idx = torch.tensor([ids], dtype=torch.long, device=self.device)

        eos_id = self.stoi['<EOS>']

        with torch.no_grad():
            for _ in range(max_new_tokens):
                idx_crop = idx[:, -self._model.block_size:]
                logits = self._model(idx_crop)
                logits = logits[:, -1, :] / temperature

                if top_k is not None:
                    v, _ = torch.topk(logits, min(top_k, logits.size(-1)))
                    logits[logits < v[:, [-1]]] = float('-inf')

                probs = F.softmax(logits, dim=-1)
                idx_next = torch.multinomial(probs, num_samples=1)
                idx = torch.cat([idx, idx_next], dim=1)

                if int(idx_next.item()) == eos_id:
                    break

        all_tokens = [self.itos[int(i)] for i in idx[0].tolist()]

        sep_idx = all_tokens.index('<SEP>') if '<SEP>' in all_tokens else -1
        target = all_tokens[sep_idx + 1:]
        if '<EOS>' in target:
            target = target[:target.index('<EOS>')]

        return target
```

- [ ] **Step 5: Run the model tests — all should pass**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python -m pytest tests/test_grid_model_class.py -v
```

Expected:
```
PASSED tests/test_grid_model_class.py::test_model_loads
PASSED tests/test_grid_model_class.py::test_generate_returns_valid_pn_pairs
PASSED tests/test_grid_model_class.py::test_generate_no_special_tokens_in_output
3 passed
```

- [ ] **Step 6: Run the full test suite to confirm no regressions**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python -m pytest tests/ -v
```

All previously passing tests should still pass.

- [ ] **Step 7: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/models/rhythmic_creator_grid/ src/tests/test_grid_model_class.py
git commit -m "feat: add RhythmicCreatorGridModel (GPTBarPair) wrapper"
```

---

## Task 4: Write and run test_grid_model.py

**Files:**
- Create: `src/test_grid_model.py`

- [ ] **Step 1: Create the test script**

Create `src/test_grid_model.py`:

```python
#!/usr/bin/env python3
"""
test_grid_model.py - Test the GPTBarPair grid model with a CHULOOPA drum recording.

Reads track_0_drums.txt, quantizes it to a 16th-note grid, generates a variation,
and writes both files so ChucK can switch between them seamlessly.

Usage (run from src/):
    python test_grid_model.py
    python test_grid_model.py --drums-file tracks/track_0/track_0_drums.txt
    python test_grid_model.py --temperature 0.8
    python test_grid_model.py --temperature 0.6 --top-k 10

Outputs:
    tracks/track_0/track_0_drums_quantized.txt        (quantized original)
    tracks/track_0/variations/track_0_drums_var_grid.txt  (generated variation)
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from format_converters import chuloopa_txt_to_grid_tokens, grid_tokens_to_chuloopa_txt
from models.rhythmic_creator_grid.grid_model import RhythmicCreatorGridModel

DEFAULT_DRUMS = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
DEFAULT_MODEL = Path(__file__).parent / "models" / "grid_barpair_best_epoch.pt"


def parse_loop_duration(filepath: Path) -> float:
    with open(filepath) as f:
        for line in f:
            if line.startswith("# Total loop duration:"):
                return float(line.split(":")[1].strip().split()[0])
    raise ValueError(f"No loop duration header in {filepath}")


def main():
    parser = argparse.ArgumentParser(description="Test GPTBarPair grid model with CHULOOPA drums")
    parser.add_argument("--drums-file", type=Path, default=DEFAULT_DRUMS,
                        help="Path to track_N_drums.txt (default: track_0_drums.txt)")
    parser.add_argument("--temperature", type=float, default=1.0,
                        help="Sampling temperature (default: 1.0)")
    parser.add_argument("--top-k", type=int, default=None,
                        help="Top-k sampling cutoff (default: None = unrestricted)")
    args = parser.parse_args()

    drums_file = args.drums_file
    if not drums_file.exists():
        print(f"ERROR: {drums_file} not found.")
        sys.exit(1)

    if not DEFAULT_MODEL.exists():
        print(f"ERROR: Model checkpoint not found at {DEFAULT_MODEL}")
        print("Run Task 1 to copy the checkpoint.")
        sys.exit(1)

    # ── BPM inference ──────────────────────────────────────────────────────────
    loop_duration = parse_loop_duration(drums_file)
    bpm = (60.0 * 4) / loop_duration
    step_duration = (60.0 / bpm) / 4.0

    print("=" * 60)
    print("CHULOOPA Grid Model Test")
    print("=" * 60)
    print(f"Input file:    {drums_file}")
    print(f"Loop duration: {loop_duration:.4f}s  (treated as 1 bar)")
    print(f"Inferred BPM:  {bpm:.1f}")
    print(f"Step duration: {step_duration * 1000:.1f}ms  (16th note)")
    print(f"Temperature:   {args.temperature}")
    print(f"Top-k:         {args.top_k}")
    print()

    # ── Convert to grid tokens ─────────────────────────────────────────────────
    context_tokens, _ = chuloopa_txt_to_grid_tokens(str(drums_file), bpm=bpm)

    print(f"Context ({len(context_tokens) // 2} hits):")
    print("  " + " ".join(context_tokens))
    print()

    # ── Load model and generate ────────────────────────────────────────────────
    print(f"Loading model from {DEFAULT_MODEL.name}...")
    model = RhythmicCreatorGridModel(str(DEFAULT_MODEL))
    print(f"Device: {model.device}")
    print()

    print("Generating variation...")
    variation_tokens = model.generate_variation(
        context_tokens,
        temperature=args.temperature,
        top_k=args.top_k,
    )

    print(f"Variation ({len(variation_tokens) // 2} hits):")
    print("  " + " ".join(variation_tokens))
    print()

    # ── Write output files ─────────────────────────────────────────────────────
    quantized_path = drums_file.parent / f"{drums_file.stem}_quantized.txt"
    grid_tokens_to_chuloopa_txt(
        context_tokens, bpm=bpm, loop_duration=loop_duration,
        output_filepath=str(quantized_path)
    )
    print(f"Wrote quantized original → {quantized_path}")

    variations_dir = drums_file.parent / "variations"
    variations_dir.mkdir(exist_ok=True)
    variation_path = variations_dir / f"{drums_file.stem}_var_grid.txt"
    grid_tokens_to_chuloopa_txt(
        variation_tokens, bpm=bpm, loop_duration=loop_duration,
        output_filepath=str(variation_path)
    )
    print(f"Wrote variation          → {variation_path}")
    print()

    # ── Side-by-side comparison ────────────────────────────────────────────────
    ctx_by_step = {}
    for i in range(0, len(context_tokens), 2):
        step = int(context_tokens[i][1:])
        pitch = int(context_tokens[i + 1][1:])
        ctx_by_step.setdefault(step, []).append(pitch)

    var_by_step = {}
    for i in range(0, len(variation_tokens), 2):
        step = int(variation_tokens[i][1:])
        pitch = int(variation_tokens[i + 1][1:])
        var_by_step.setdefault(step, []).append(pitch)

    all_steps = sorted(set(ctx_by_step) | set(var_by_step))

    print(f"{'Step':<6} {'Time (ms)':<12} {'Quantized original':<28} {'Generated variation'}")
    print("-" * 72)
    for step in all_steps:
        ts_ms = step * step_duration * 1000
        ctx_str = " ".join(f"N{p}" for p in sorted(ctx_by_step.get(step, []))) or "-"
        var_str = " ".join(f"N{p}" for p in sorted(var_by_step.get(step, []))) or "-"
        print(f"P{step:<5} {ts_ms:<12.1f} {ctx_str:<28} {var_str}")

    print()
    print("Done. Both files use the same loop duration — safe to switch in ChucK.")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the script end-to-end**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python test_grid_model.py
```

Expected output (values will vary):
```
============================================================
CHULOOPA Grid Model Test
============================================================
Input file:    .../tracks/track_0/track_0_drums.txt
Loop duration: 5.9791s  (treated as 1 bar)
Inferred BPM:  40.1
Step duration: 373.7ms  (16th note)
Temperature:   1.0
Top-k:         None

Context (11 hits):
  P0 N36 P2 N38 P3 N36 ...

Loading model from grid_barpair_best_epoch.pt...
Device: mps  (or cpu)

Generating variation...
Variation (N hits):
  P0 N36 P2 N38 ...

Wrote quantized original → .../tracks/track_0/track_0_drums_quantized.txt
Wrote variation          → .../tracks/track_0/variations/track_0_drums_var_grid.txt

Step   Time (ms)    Quantized original           Generated variation
------------------------------------------------------------------------
P0     0.0          N36                          N36
...
Done. Both files use the same loop duration — safe to switch in ChucK.
```

If the script fails, check:
- Model checkpoint present: `ls src/models/grid_barpair_best_epoch.pt`
- Drum file present: `ls src/tracks/track_0/track_0_drums.txt`
- Python path correct (must run from `src/`)

- [ ] **Step 3: Manually verify the output files**

```bash
cat "tracks/track_0/track_0_drums_quantized.txt"
cat "tracks/track_0/variations/track_0_drums_var_grid.txt"
```

Checks:
- Both files start with `# Total loop duration:` matching the original
- All timestamps in the quantized file are exact multiples of `step_duration`
- Both files have sensible MIDI notes (36, 38, 42 expected for CHULOOPA)

- [ ] **Step 4: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/test_grid_model.py
git commit -m "feat: add test_grid_model.py end-to-end test script"
```

---

## Self-Review

**Spec coverage:**
- ✅ notes.md — Task 1 Step 3
- ✅ Checkpoint copied to permanent location — Task 1 Steps 1-2
- ✅ `chuloopa_txt_to_grid_tokens` — Task 2 Step 3
- ✅ `grid_tokens_to_chuloopa_txt` — Task 2 Step 3
- ✅ `RhythmicCreatorGridModel` + `GPTBarPair` — Task 3 Step 4
- ✅ `test_grid_model.py` — Task 4 Step 1
- ✅ BPM always inferred from loop_duration (1 bar) — Task 4 Steps 1-2
- ✅ Both output files use same loop_duration — Task 4 Step 1
- ✅ Quantized original + variation written — Task 4 Steps 1-2

**Type consistency:**
- `chuloopa_txt_to_grid_tokens` returns `(list[str], float)` — used that way in Task 4 ✅
- `grid_tokens_to_chuloopa_txt` takes `(list, float, float, str)` — consistent across Task 2 tests and Task 4 ✅
- `RhythmicCreatorGridModel.generate_variation` takes `list`, returns `list` — consistent ✅
- `model.device` attribute referenced in test_grid_model.py — defined in `__init__` ✅
- `model._model.block_size` used in generation loop — set to `block_size - 1` in `GPTBarPair.__init__` ✅
