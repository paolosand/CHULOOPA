# TND Model Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Jake's TND bar-pair model into CHULOOPA's variation pipeline as `tnd_model_variation()`, runnable alongside the existing time-based and grid models.

**Architecture:** Two new pieces: (1) two converter functions in `format_converters.py` that translate between CHULOOPA's DrumPattern and T/N/D token sequences; (2) `tnd_model_variation()` in `drum_variation_generator.py` wired up with the same init/fallback pattern as `grid_model_variation()`. There is no new model class — `RhythmicCreatorGridModel` loads the TND checkpoint directly because both checkpoints share the identical `{stoi, itos, config, model_state_dict}` format and GPTBarPair architecture. The checkpoint (`tnd_barpair_best_epoch.pt`) is already present in `src/models/` (copied manually — `.pt` files are gitignored).

**Tech Stack:** Python, PyTorch, existing DrumPattern/DrumHit dataclasses.

**Worktree:** `/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/`
All paths below are relative to this worktree root.

**Baseline:** 31/31 tests passing on this branch before any changes.

**Checkpoint facts (verified):**
- Path in worktree: `src/models/tnd_barpair_best_epoch.pt` (21 MB, already copied)
- Keys: `stoi`, `itos`, `config`, `model_state_dict`, `best_val`, `best_epoch`
- Config: `block_size=297, vocab_size=80, n_embd=256, n_head=8, n_layer=6, dropout=0.2`
- T tokens: T0–T34, T36–T39, T41–T48, T56, T62, T72 (max gap = 720ms)
- D tokens: D1, D2, D3, D9 — use D2 (20ms) as default for all percussion
- N tokens: N22, N26, N36–N59 (standard GM percussion)

---

## Files

| Action | Path | Purpose |
|--------|------|---------|
| Modify | `src/format_converters.py` | Add `chuloopa_to_tnd_tokens` + `tnd_tokens_to_chuloopa` |
| Create | `src/tests/test_tnd_converters.py` | Unit tests for converter functions |
| Modify | `src/drum_variation_generator.py` | Add `_TND_MODEL_PATH`, `tnd_model` global, `init_tnd_model`, `tnd_model_variation` |
| Create | `src/tests/test_tnd_integration.py` | Integration test: load model + generate variation |

No new model class needed — `RhythmicCreatorGridModel` (already in `src/models/rhythmic_creator_grid/grid_model.py`) loads the TND checkpoint directly.

---

## Task 1: Add TND converters to format_converters.py

**Files:**
- Modify: `src/format_converters.py` (append two functions at end of file)
- Create: `src/tests/test_tnd_converters.py`

- [ ] **Step 1: Write the failing tests**

Create `src/tests/test_tnd_converters.py`:

```python
"""Unit tests for TND token converters."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from format_converters import chuloopa_to_tnd_tokens, tnd_tokens_to_chuloopa
from drum_variation_generator import DrumPattern, DrumHit

# Minimal stoi covering what the tests need (mirrors real TND vocab structure)
MOCK_STOI = {
    '<SOS>': 0, '<EOS>': 1, '<SEP>': 2, '<PAD>': 3,
    **{f'T{i}': 4 + i for i in range(73)},  # T0–T72
    'D1': 77, 'D2': 78, 'D3': 79, 'D9': 80,
    'N36': 81, 'N38': 82, 'N42': 83,
}


def make_pattern(hits_list, loop_duration=2.0):
    hits = [DrumHit(midi_note=n, timestamp=t, velocity=0.8, delta_time=0.0)
            for n, t in hits_list]
    p = DrumPattern(hits=hits, loop_duration=loop_duration)
    p._recalculate_delta_times()
    return p


def test_single_hit_at_zero():
    """Kick at t=0 should produce T0 N36 D2."""
    pattern = make_pattern([(36, 0.0)])
    tokens = chuloopa_to_tnd_tokens(pattern, MOCK_STOI)
    assert tokens == ['T0', 'N36', 'D2']


def test_two_hits_delta_encoding():
    """Kick at 0.0, snare at 0.5 → T0 N36 D2, T50 N38 D2."""
    pattern = make_pattern([(36, 0.0), (38, 0.5)])
    tokens = chuloopa_to_tnd_tokens(pattern, MOCK_STOI)
    assert tokens == ['T0', 'N36', 'D2', 'T50', 'N38', 'D2']


def test_t_value_clamped_when_gap_exceeds_max():
    """Gap of 1.0s (T100) should clamp to T72 (max in vocab)."""
    pattern = make_pattern([(36, 0.0), (38, 1.0)])  # delta = 1.0s = T100
    tokens = chuloopa_to_tnd_tokens(pattern, MOCK_STOI)
    assert tokens[3] == 'T72'  # clamped to max available T


def test_note_not_in_vocab_is_skipped():
    """Note N99 (not in vocab) should be skipped entirely."""
    pattern = make_pattern([(99, 0.0), (36, 0.5)])
    tokens = chuloopa_to_tnd_tokens(pattern, MOCK_STOI)
    assert 'N99' not in tokens
    assert 'N36' in tokens


def test_roundtrip_two_hits():
    """Tokens → DrumPattern should recover correct timestamps."""
    tokens = ['T0', 'N36', 'D2', 'T50', 'N38', 'D2']
    pattern = tnd_tokens_to_chuloopa(tokens, loop_duration=2.0)
    assert len(pattern.hits) == 2
    assert pattern.hits[0].midi_note == 36
    assert abs(pattern.hits[0].timestamp - 0.0) < 0.001
    assert pattern.hits[1].midi_note == 38
    assert abs(pattern.hits[1].timestamp - 0.5) < 0.001


def test_roundtrip_delta_times_set():
    """tnd_tokens_to_chuloopa must set correct delta_times via _recalculate_delta_times."""
    tokens = ['T0', 'N36', 'D2', 'T50', 'N38', 'D2']
    pattern = tnd_tokens_to_chuloopa(tokens, loop_duration=2.0)
    assert abs(pattern.hits[0].delta_time - 0.5) < 0.001   # kick → snare gap
    assert abs(pattern.hits[1].delta_time - 1.5) < 0.001   # snare → loop end


def test_hits_at_loop_boundary_dropped():
    """Hit whose accumulated time == loop_duration should be dropped (< not <=)."""
    # T0 N36 D2 at t=0.0, then T200 at t=2.0s — exactly at boundary, should drop
    tokens = ['T0', 'N36', 'D2', 'T200', 'N38', 'D2']
    pattern = tnd_tokens_to_chuloopa(tokens, loop_duration=2.0)
    assert len(pattern.hits) == 1
    assert pattern.hits[0].midi_note == 36


def test_empty_pattern_returns_empty_tokens():
    pattern = DrumPattern(hits=[], loop_duration=2.0)
    tokens = chuloopa_to_tnd_tokens(pattern, MOCK_STOI)
    assert tokens == []


def test_empty_tokens_returns_empty_pattern():
    pattern = tnd_tokens_to_chuloopa([], loop_duration=2.0)
    assert pattern.hits == []
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/test_tnd_converters.py -v
```

Expected: `ImportError: cannot import name 'chuloopa_to_tnd_tokens'`

- [ ] **Step 3: Append converters to format_converters.py**

Append this block at the end of `src/format_converters.py`:

```python

# =============================================================================
# TND TOKEN CONVERTERS
# =============================================================================

_TND_TIME_STEP = 0.01  # seconds per T/D unit (TIME_STEP used by TND model)


def chuloopa_to_tnd_tokens(pattern, stoi: dict) -> list:
    """
    Convert a CHULOOPA DrumPattern to a list of T/N/D token strings.

    T encodes inter-onset interval from the previous hit (or bar start).
    D is fixed at D2 (20ms) for all percussion hits.
    Notes not in the model vocab are skipped.

    Args:
        pattern: DrumPattern
        stoi:    model vocab dict (RhythmicCreatorGridModel.stoi from TND checkpoint)

    Returns:
        list of strings e.g. ['T0', 'N36', 'D2', 'T50', 'N38', 'D2']
    """
    if not pattern.hits:
        return []

    available_t = sorted(int(tok[1:]) for tok in stoi if tok.startswith('T'))
    max_t = available_t[-1] if available_t else 0
    t_set = set(available_t)

    d_tok = 'D2' if 'D2' in stoi else next((t for t in sorted(stoi) if t.startswith('D')), None)
    if d_tok is None:
        return []

    tokens = []
    prev_time = 0.0

    for hit in sorted(pattern.hits, key=lambda h: h.timestamp):
        n_tok = f'N{hit.midi_note}'
        if n_tok not in stoi:
            prev_time = hit.timestamp
            continue

        t_val = round((hit.timestamp - prev_time) / _TND_TIME_STEP)
        t_val = min(t_val, max_t)
        if t_val not in t_set:
            t_val = min(available_t, key=lambda x: abs(x - t_val))

        tokens.extend([f'T{t_val}', n_tok, d_tok])
        prev_time = hit.timestamp

    return tokens


def tnd_tokens_to_chuloopa(tokens: list, loop_duration: float):
    """
    Convert T/N/D token strings back to a CHULOOPA DrumPattern.

    Accumulates inter-onset intervals to recover absolute timestamps.
    Hits at or beyond loop_duration are dropped.

    Args:
        tokens:        output of RhythmicCreatorGridModel.generate_variation (TND checkpoint)
        loop_duration: total loop length in seconds

    Returns:
        DrumPattern with hits and delta_times set
    """
    from drum_variation_generator import DrumPattern, DrumHit

    hits = []
    current_time = 0.0
    i = 0

    while i + 2 < len(tokens):
        t_tok, n_tok, d_tok = tokens[i], tokens[i + 1], tokens[i + 2]
        if t_tok.startswith('T') and n_tok.startswith('N') and d_tok.startswith('D'):
            current_time += int(t_tok[1:]) * _TND_TIME_STEP
            pitch = int(n_tok[1:])
            if current_time < loop_duration:
                hits.append(DrumHit(
                    midi_note=pitch,
                    timestamp=round(current_time, 4),
                    velocity=assign_velocity(current_time, loop_duration),
                    delta_time=0.0,
                ))
            i += 3
        else:
            i += 1

    if not hits:
        return DrumPattern(hits=[], loop_duration=loop_duration)

    pattern = DrumPattern(hits=hits, loop_duration=loop_duration)
    pattern._recalculate_delta_times()
    return pattern
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/test_tnd_converters.py -v
```

Expected: `9 passed`

- [ ] **Step 5: Run full suite to check nothing broken**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/ -v 2>&1 | tail -5
```

Expected: `40 passed` (31 existing + 9 new)

- [ ] **Step 6: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration"
git add src/format_converters.py src/tests/test_tnd_converters.py
git commit -m "feat: add TND token converters (chuloopa_to_tnd_tokens, tnd_tokens_to_chuloopa)"
```

---

## Task 2: Add tnd_model_variation to drum_variation_generator.py

**Files:**
- Modify: `src/drum_variation_generator.py` (append after the grid model section)
- Create: `src/tests/test_tnd_integration.py`

The TND model loads via `RhythmicCreatorGridModel` — already imported at line 800. We just add a second global + init + variation function pointing at the TND checkpoint.

- [ ] **Step 1: Write the failing integration test**

Create `src/tests/test_tnd_integration.py`:

```python
"""Integration test: TND model loads and generates a variation end-to-end."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from drum_variation_generator import DrumPattern, DrumHit, tnd_model_variation


def make_pattern():
    hits = [
        DrumHit(midi_note=36, timestamp=0.0,  velocity=0.8, delta_time=0.5),
        DrumHit(midi_note=38, timestamp=0.5,  velocity=0.7, delta_time=0.5),
        DrumHit(midi_note=36, timestamp=1.0,  velocity=0.8, delta_time=0.5),
        DrumHit(midi_note=38, timestamp=1.5,  velocity=0.7, delta_time=0.5),
    ]
    return DrumPattern(hits=hits, loop_duration=2.0)


def test_tnd_variation_returns_drum_pattern():
    pattern = make_pattern()
    result, success = tnd_model_variation(pattern, spice_level=0.5)
    assert isinstance(result, DrumPattern)
    assert success is True
    assert len(result.hits) >= 1
    assert result.loop_duration == 2.0


def test_tnd_variation_hits_within_loop():
    pattern = make_pattern()
    result, _ = tnd_model_variation(pattern, spice_level=0.5)
    for hit in result.hits:
        assert hit.timestamp < result.loop_duration


def test_tnd_variation_delta_times_set():
    pattern = make_pattern()
    result, _ = tnd_model_variation(pattern, spice_level=0.5)
    for hit in result.hits:
        assert hit.delta_time > 0
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/test_tnd_integration.py -v
```

Expected: `ImportError: cannot import name 'tnd_model_variation'`

- [ ] **Step 3: Add tnd_model_variation to drum_variation_generator.py**

Find the line in `src/drum_variation_generator.py` that reads:
```python
_GRID_MODEL_PATH = Path(__file__).parent / "models" / "grid_barpair_best_epoch.pt"
```
(currently line 806). Append the following block immediately **after** the closing of `grid_model_variation` (after its final `except Exception` block, around line 1095). The exact anchor to insert after is the last line of `grid_model_variation`:

```python
        return generate_musical_variation(pattern, spice_level), False
```

Insert this entire block after it:

```python

# =============================================================================
# TND BAR-PAIR MODEL VARIATION GENERATOR
# =============================================================================

_TND_MODEL_PATH = Path(__file__).parent / "models" / "tnd_barpair_best_epoch.pt"

tnd_model = None
_tnd_model_lock = threading.Lock()


def init_tnd_model():
    """Initialize TND bar-pair model. Uses RhythmicCreatorGridModel — same architecture."""
    global tnd_model, force_cpu

    if not HAVE_GRID_MODEL:
        print("  TND model not available: grid model imports missing")
        return False

    with _tnd_model_lock:
        if tnd_model is not None:
            return True

        if not _TND_MODEL_PATH.exists():
            print(f"  TND checkpoint not found at {_TND_MODEL_PATH}")
            return False

        try:
            device = "cpu" if force_cpu else ("mps" if torch.backends.mps.is_available() else "cpu")
            tnd_model = RhythmicCreatorGridModel(str(_TND_MODEL_PATH), device=device)
            print(f"  TND model loaded on {device} (vocab={len(tnd_model.stoi)} tokens)")
            return True
        except Exception as e:
            print(f"  TND model load failed: {e}")
            return False


def tnd_model_variation(pattern: DrumPattern, spice_level: float = 0.5) -> tuple:
    """
    Generate a variation using the TND bar-pair model.

    Converts CHULOOPA hits to T/N/D tokens, runs inference via GPTBarPair,
    converts back to DrumPattern. Spice maps to temperature: 0.0→0.7, 1.0→1.4.

    Returns:
        Tuple of (DrumPattern, success: bool)
    """
    global tnd_model

    from format_converters import chuloopa_to_tnd_tokens, tnd_tokens_to_chuloopa

    if tnd_model is None:
        if not init_tnd_model():
            print("  TND model not available, falling back to groove_preserve")
            return generate_musical_variation(pattern, spice_level), False

    try:
        loop_duration = pattern.loop_duration
        context_tokens = chuloopa_to_tnd_tokens(pattern, tnd_model.stoi)

        if not context_tokens:
            print("  Warning: No valid TND tokens from pattern, falling back")
            return generate_musical_variation(pattern, spice_level), False

        temperature = 0.7 + (spice_level * 0.7)
        n_hits = len(context_tokens) // 3
        print(f"  Generating TND variation (spice={spice_level:.2f}, temp={temperature:.2f})...")
        print(f"    Context: {n_hits} hits, loop={loop_duration:.2f}s")

        variation_tokens = tnd_model.generate_variation(
            context_tokens,
            temperature=temperature,
        )

        if not variation_tokens:
            print("  Warning: TND model returned empty output, falling back")
            return generate_musical_variation(pattern, spice_level), False

        variation = tnd_tokens_to_chuloopa(variation_tokens, loop_duration)

        if not variation.hits or len(variation.hits) < 2:
            print("  Warning: TND model produced < 2 hits, falling back")
            return generate_musical_variation(pattern, spice_level), False

        print(f"    Variation: {len(variation.hits)} hits")
        return variation, True

    except Exception as e:
        print(f"  TND model error: {e}, falling back")
        return generate_musical_variation(pattern, spice_level), False
```

- [ ] **Step 4: Verify HAVE_GRID_MODEL and RhythmicCreatorGridModel are in scope**

```bash
grep -n "HAVE_GRID_MODEL\|RhythmicCreatorGridModel" "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src/drum_variation_generator.py" | head -5
```

Expected: lines showing `HAVE_GRID_MODEL = True/False` and `from models.rhythmic_creator_grid.grid_model import RhythmicCreatorGridModel`

- [ ] **Step 5: Run integration tests**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/test_tnd_integration.py -v
```

Expected: `3 passed` (model inference on CPU takes ~15–30s per call)

- [ ] **Step 6: Run full test suite**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/ -v 2>&1 | tail -5
```

Expected: `43 passed`

- [ ] **Step 7: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration"
git add src/drum_variation_generator.py src/tests/test_tnd_integration.py
git commit -m "feat: add tnd_model_variation() — TND bar-pair model via RhythmicCreatorGridModel"
```
