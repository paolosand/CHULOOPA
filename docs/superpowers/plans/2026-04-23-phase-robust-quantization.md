# Phase-Robust Grid Quantization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace naive `round(timestamp / step_duration)` quantization with median-phase estimation so beatbox recordings that start slightly late still snap to the correct 16-step grid.

**Architecture:** Extract a single `quantize_to_steps()` function in `format_converters.py` that uses median fractional-position phase estimation, then wire it into the three call sites that currently do inline rounding: `chuloopa_txt_to_grid_tokens()`, `grid_model_variation()`, and `_generation_worker()`. The generator is also refactored to quantize and write to disk immediately (before generating variations) so ChucK gets the corrected loop ASAP.

**Tech Stack:** Python 3.10+, `statistics` stdlib module (no new dependencies). All work in `.worktrees/feat/grid-model-integration/src/`.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `src/format_converters.py` | Modify | Add `quantize_to_steps()`; update `chuloopa_txt_to_grid_tokens()` to call it |
| `src/drum_variation_generator.py` | Modify | Import + use `quantize_to_steps()` in `grid_model_variation()`; refactor `_generation_worker()` to quantize upfront and write immediately; delete `_write_quantized_original()` |
| `src/tests/test_quantize_to_steps.py` | Create | Unit tests for `quantize_to_steps()` |
| `src/tests/test_grid_converters.py` | Modify | Add phase-shift regression test for `chuloopa_txt_to_grid_tokens()` |

---

## Task 1: Add `quantize_to_steps()` to `format_converters.py`

**Files:**
- Create: `src/tests/test_quantize_to_steps.py`
- Modify: `src/format_converters.py`

- [ ] **Step 1: Write the failing tests**

Create `src/tests/test_quantize_to_steps.py`:

```python
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from format_converters import quantize_to_steps


def test_on_grid_hits_no_phase():
    # Perfect on-grid hits at 120 BPM (step=0.125s, loop=2.0s)
    hits = [(0.0, 36), (0.5, 38), (1.0, 36), (1.5, 38)]
    result = quantize_to_steps(hits, loop_duration=2.0)
    assert result == [(0, 36), (4, 38), (8, 36), (12, 38)]


def test_constant_phase_shift_corrected():
    # Input 2 from SAME INPUT DIFFERENT QUANTIZED — all hits shifted ~0.1s late.
    # Naive algorithm gives steps 1,5,7,9,12; median phase must give 0,4,6,8,12.
    hits = [
        (0.103311, 36),
        (0.710590, 38),
        (0.989887, 36),
        (1.292404, 36),
        (1.864853, 38),
    ]
    result = quantize_to_steps(hits, loop_duration=2.391655)
    steps = [s for s, _ in result]
    assert steps == [0, 4, 6, 8, 12]


def test_small_drift_last_hit_corrected():
    # Input 4 from SAME INPUT DIFFERENT QUANTIZED — last kick drifts to step 9
    # and last snare to step 13 under naive algorithm.
    hits = [
        (0.060544, 36),
        (0.632993, 38),
        (0.915193, 36),
        (1.203197, 36),
        (1.790159, 38),
    ]
    result = quantize_to_steps(hits, loop_duration=2.255215)
    steps = [s for s, _ in result]
    assert steps == [0, 4, 6, 8, 12]


def test_empty_returns_empty():
    assert quantize_to_steps([], loop_duration=2.0) == []


def test_single_hit_snaps_to_step_0():
    # One hit — phase equals that hit's fractional position, adjusted = 0 → step 0
    result = quantize_to_steps([(0.06, 36)], loop_duration=2.0)
    assert result == [(0, 36)]


def test_step_clamped_to_15():
    # A hit right at loop end must not overflow to step 16
    result = quantize_to_steps([(1.99, 36)], loop_duration=2.0)
    assert result[0][0] <= 15


def test_sorted_by_step_then_note():
    # Same-step hits sorted by midi note ascending (matches training data ordering)
    result = quantize_to_steps([(0.0, 42), (0.0, 36)], loop_duration=2.0)
    assert result == [(0, 36), (0, 42)]


def test_spread_warning_logged(capsys):
    # Wide fractional spread triggers a warning print (no behavior change)
    # Hits at 0.0 and 0.13 out of step_duration=0.125 → spread = 0.13 > 0.25*0.125=0.03125
    hits = [(0.0, 36), (0.13, 38), (0.5, 36), (0.63, 38)]
    quantize_to_steps(hits, loop_duration=2.0)
    captured = capsys.readouterr()
    assert "loose timing" in captured.out
```

- [ ] **Step 2: Run tests — confirm they all fail**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/grid-model-integration/src"
python -m pytest tests/test_quantize_to_steps.py -v
```

Expected: `ImportError: cannot import name 'quantize_to_steps' from 'format_converters'`

- [ ] **Step 3: Implement `quantize_to_steps()` in `format_converters.py`**

Add `import statistics` at the top of `src/format_converters.py` (currently only has `import random`):

```python
import random
import statistics
```

Add the function **before** `chuloopa_txt_to_grid_tokens` (i.e., before line 202):

```python
def quantize_to_steps(hits: list, loop_duration: float) -> list:
    """Snap (timestamp, midi_note) pairs to a 16-step grid.

    Uses median phase estimation to correct for constant timing offsets,
    e.g. the user starts playing slightly late in the recording window.

    Args:
        hits:          list of (timestamp_seconds: float, midi_note: int)
        loop_duration: total loop duration in seconds (one 4/4 bar)

    Returns:
        list of (step: int, midi_note: int) sorted by (step, midi_note),
        steps clamped to [0, 15].
    """
    if not hits:
        return []

    step_duration = loop_duration / 16
    fracs = [ts % step_duration for ts, _ in hits]
    phase = statistics.median(fracs)

    spread = max(fracs) - min(fracs)
    if spread > 0.25 * step_duration:
        print(f"  [Quantize] Warning: loose timing "
              f"(spread={spread:.4f}s = {spread / step_duration:.2f} steps)"
              f" — best approximation")

    events = []
    for ts, note in hits:
        step = max(0, min(15, round((ts - phase) / step_duration)))
        events.append((step, note))

    return sorted(events)
```

- [ ] **Step 4: Run tests — confirm they all pass**

```bash
python -m pytest tests/test_quantize_to_steps.py -v
```

Expected: all 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/grid-model-integration"
git add src/format_converters.py src/tests/test_quantize_to_steps.py
git commit -m "feat: add quantize_to_steps() with median phase estimation

Replaces naive round(timestamp/step_duration) with a phase-corrected
version: compute median fractional grid position across all hits,
subtract as phase offset before rounding. Corrects for constant timing
offsets caused by the user starting to play slightly late in the
recording window."
```

---

## Task 2: Update `chuloopa_txt_to_grid_tokens()` to use `quantize_to_steps()`

**Files:**
- Modify: `src/format_converters.py:202-243`
- Modify: `src/tests/test_grid_converters.py`

- [ ] **Step 1: Add a failing phase-shift test to `test_grid_converters.py`**

Append to `src/tests/test_grid_converters.py`:

```python
def test_phase_shifted_input_snaps_correctly():
    # Simulates Input 2 from SAME INPUT DIFFERENT QUANTIZED:
    # all hits shifted ~0.1s late. Naive quantization gives wrong steps;
    # median phase must recover the correct 0,4,6,8,12 pattern.
    content = """\
# Track 0 Drum Data
# Format: MIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME
# MIDI_NOTE: GM MIDI note number (36=kick, 38=snare, 42=hat, etc.)
# DELTA_TIME: Duration until next hit (for last hit: time until loop end)
# Total loop duration: 2.391655 seconds
36,0.103311,0.737,1.000000
38,0.710590,0.757,1.000000
36,0.989887,0.742,1.000000
36,1.292404,0.731,1.000000
38,1.864853,0.803,1.000000
"""
    path = make_temp_file(content)
    try:
        # bpm is ignored for step calculation — loop_duration from header is used
        tokens, _ = chuloopa_txt_to_grid_tokens(path, bpm=100.5)
        steps = [int(t[1:]) for t in tokens if t.startswith('P')]
        assert steps == [0, 4, 6, 8, 12], f"Expected [0,4,6,8,12], got {steps}"
    finally:
        os.unlink(path)
```

- [ ] **Step 2: Run the new test — confirm it fails**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/grid-model-integration/src"
python -m pytest tests/test_grid_converters.py::test_phase_shifted_input_snaps_correctly -v
```

Expected: FAIL — the naive algorithm returns steps `[1, 5, 7, 9, 12]`.

- [ ] **Step 3: Update `chuloopa_txt_to_grid_tokens()` in `format_converters.py`**

Replace lines 228–242 (the `step_duration`, `events`, sort, and token-building block):

```python
    # Old code (remove):
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
```

Replace with:

```python
    # bpm parameter retained for API compatibility but step calculation
    # now uses loop_duration from the file header (equivalent for 4/4 one-bar loops,
    # and more robust to phase offsets via quantize_to_steps).
    events = quantize_to_steps(hits, loop_duration)

    tokens = []
    for step, pitch in events:
        tokens.append(f"P{step}")
        tokens.append(f"N{pitch}")

    return tokens, loop_duration
```

- [ ] **Step 4: Run all converter tests — confirm all pass**

```bash
python -m pytest tests/test_grid_converters.py -v
```

Expected: all tests PASS including the new phase-shift test.

Note: `test_slightly_off_grid_hits_snap_to_nearest_step` uses hits that are only ±0.01s off-grid — the median phase (~0.006s) is small enough that all steps still round correctly.

- [ ] **Step 5: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/grid-model-integration"
git add src/format_converters.py src/tests/test_grid_converters.py
git commit -m "fix: use quantize_to_steps() in chuloopa_txt_to_grid_tokens

Phase-shifted inputs now quantize to correct steps. Step calculation
derived from loop_duration (file header) rather than bpm parameter,
which is kept for API compatibility."
```

---

## Task 3: Update `grid_model_variation()` to use `quantize_to_steps()`

**Files:**
- Modify: `src/drum_variation_generator.py:978-1018`

No new tests for this task — `grid_model_variation()` requires the live grid model checkpoint which is not available in CI. The change is mechanical: replace the inline rounding loop with a call to `quantize_to_steps()`.

- [ ] **Step 1: Add the import to `drum_variation_generator.py`**

At the top of `src/drum_variation_generator.py`, after the existing imports (around line 30), add:

```python
from format_converters import quantize_to_steps
```

- [ ] **Step 2: Replace inline quantization in `grid_model_variation()`**

In `src/drum_variation_generator.py`, replace lines 994–1013 (the BPM/step_duration block and the events loop):

```python
    # Old code (remove):
        loop_duration = pattern.loop_duration
        bpm = (60.0 * 4) / loop_duration
        step_duration = (60.0 / bpm) / 4.0

        # Convert DrumPattern hits to P/N grid tokens
        events = []
        for hit in pattern.hits:
            step = max(0, min(15, int(round(hit.timestamp / step_duration))))
            n_tok = f"N{hit.midi_note}"
            if n_tok not in grid_model.stoi:
                print(f"  Skipping N{hit.midi_note} (not in model vocab)")
                continue
            events.append((step, hit.midi_note))

        if not events:
            print("  Warning: No valid grid tokens from pattern, falling back")
            return generate_musical_variation(pattern, spice_level), False

        events.sort(key=lambda x: (x[0], x[1]))
```

Replace with:

```python
        loop_duration = pattern.loop_duration
        bpm = (60.0 * 4) / loop_duration
        step_duration = loop_duration / 16

        raw_hits = [(h.timestamp, h.midi_note) for h in pattern.hits]
        all_events = quantize_to_steps(raw_hits, loop_duration)

        # Filter out notes not in model vocab
        events = [
            (step, pitch) for step, pitch in all_events
            if f"N{pitch}" in grid_model.stoi
        ]
        skipped = len(all_events) - len(events)
        if skipped:
            print(f"  Skipping {skipped} hit(s) not in model vocab")

        if not events:
            print("  Warning: No valid grid tokens from pattern, falling back")
            return generate_musical_variation(pattern, spice_level), False
```

- [ ] **Step 3: Verify the file imports cleanly**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/grid-model-integration/src"
python -c "from drum_variation_generator import grid_model_variation; print('OK')"
```

Expected output: `OK` (the `rhythmic_creator` warning is fine, it's a separate optional model).

- [ ] **Step 4: Run the full test suite**

```bash
python -m pytest tests/ -v
```

Expected: all existing tests pass.

- [ ] **Step 5: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/grid-model-integration"
git add src/drum_variation_generator.py
git commit -m "fix: use quantize_to_steps() in grid_model_variation

Replaces inline rounding with phase-corrected quantization. Vocab
filtering now happens after quantization so all steps benefit from
phase correction."
```

---

## Task 4: Refactor `_generation_worker()` — quantize upfront, write immediately

**Files:**
- Modify: `src/drum_variation_generator.py:1419-1528`

This task:
1. Moves quantize+write to the **top** of `_generation_worker()` so ChucK gets the clean loop before variation generation starts
2. Passes the quantized `DrumPattern` to slot threads (so variations are generated from the corrected groove)
3. Adds the `# quantized` file marker (so the watchdog skips re-triggering on this write)
4. Removes the end-of-worker `_write_quantized_original` call and deletes the now-redundant function

- [ ] **Step 1: Replace `_write_quantized_original()` and update `_generation_worker()`**

Delete the entire `_write_quantized_original()` function (lines 1419–1452) and replace `_generation_worker()` (lines 1455–1528) with the following. The full replacement for both is:

```python
def _generation_worker():
    """Coordinator: quantizes original immediately, then spawns one thread per slot,
    joins all, sorts bank by deviation, fires bank_ready."""
    variations_dir = DEFAULT_VARIATIONS_DIR
    variations_dir.mkdir(parents=True, exist_ok=True)

    track_file = DEFAULT_TRACK_DIR / "track_0_drums.txt"
    if not track_file.exists():
        print("  Worker: track file not found, aborting")
        return

    raw_pattern = DrumPattern.from_file(str(track_file))
    if not raw_pattern.hits:
        print("  Worker: no hits in pattern, aborting")
        return

    # ── Quantize and write back immediately ──────────────────────────────────
    # ChucK starts playing the corrected loop before variations are ready.
    # The '# quantized' marker tells the watchdog to ignore this write.
    if current_variation_type == 'grid':
        loop_duration = raw_pattern.loop_duration
        step_duration = loop_duration / 16
        raw_hits = [(h.timestamp, h.midi_note) for h in raw_pattern.hits]
        events = quantize_to_steps(raw_hits, loop_duration)

        q_hits = []
        for step, pitch in events:
            ts = step * step_duration
            q_hits.append(DrumHit(midi_note=pitch, timestamp=ts,
                                  velocity=0.75, delta_time=0.0))
        pattern = DrumPattern(hits=q_hits, loop_duration=loop_duration,
                              source_file=str(track_file))
        pattern._recalculate_delta_times()

        bpm = (60.0 * 4) / loop_duration
        try:
            with open(track_file, 'w') as f:
                f.write("# Track 0 Drum Data\n")
                f.write("# quantized\n")
                f.write("# Format: MIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME\n")
                f.write("# MIDI_NOTE: GM MIDI note number (36=kick, 38=snare, 42=hat, etc.)\n")
                f.write("# DELTA_TIME: Duration until next hit (for last hit: time until loop end)\n")
                f.write(f"# Total loop duration: {loop_duration:.6f} seconds\n")
                for hit in pattern.hits:
                    vel = 0.7 + (hit.velocity * 0.2)
                    f.write(f"{hit.midi_note},{hit.timestamp:.6f},{vel:.6f},{hit.delta_time:.6f}\n")
            print(f"  [Quantize] Original snapped to grid → {track_file.name} "
                  f"({len(q_hits)} hits, BPM={bpm:.1f})")
        except Exception as e:
            print(f"  [Quantize] Warning: could not write quantized original: {e}")
            pattern = raw_pattern  # fall back to raw pattern for variation generation
    else:
        pattern = raw_pattern

    # ── Snapshot and clear generation queue ──────────────────────────────────
    with generation_lock:
        slots = list(generation_queue)
        generation_queue.clear()

    if not slots:
        return

    print(f"\n  [Worker] Starting parallel generation: slots={slots}")

    # Pre-load grid model once before threads start (avoids 5 simultaneous loads)
    if current_variation_type == 'grid' and HAVE_GRID_MODEL and grid_model is None:
        init_grid_model()

    written_slots = set()

    threads = {
        slot: threading.Thread(
            target=_run_slot_thread,
            args=(slot, pattern, written_slots),
            daemon=True,
            name=f"slot-{slot}"
        )
        for slot in slots
    }
    for t in threads.values():
        t.start()

    for slot in slots:
        threads[slot].join()
        print(f"  [Worker] Slot {slot} joined")

    if stop_event.is_set():
        print(f"  [Worker] Cancelled — skipping sort and bank_ready")
        return

    if written_slots:
        _sort_variation_bank(written_slots, pattern)

    if written_slots and not stop_event.is_set() and osc_client:
        try:
            osc_client.send_message("/chuloopa/bank_ready", 0)
            osc_client.send_message("/chuloopa/generation_progress",
                                    "Bank ready — sorted by deviation")
            print("  [Worker] bank_ready sent (bank sorted)")
        except Exception as e:
            print(f"  [Worker] OSC error sending bank_ready: {e}")
```

- [ ] **Step 2: Check the watchdog `on_modified` has the `# quantized` guard**

Search for the guard in `drum_variation_generator.py`:

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/grid-model-integration/src"
grep -n "quantized" drum_variation_generator.py
```

If the output does **not** include an `on_modified` handler that checks `'# quantized' in header`, add it now. Find `on_modified` and add the guard at the top of its body, before the debounce check:

```python
# Ignore our own quantize write-back (file contains '# quantized' marker)
try:
    with open(filepath, 'r') as f:
        header = f.read(256)
    if '# quantized' in header:
        return
except OSError:
    pass
```

If the guard is already present (from a prior commit), skip this sub-step.

- [ ] **Step 3: Verify import and syntax**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/grid-model-integration/src"
python -c "import drum_variation_generator; print('OK')"
```

Expected: `OK`

- [ ] **Step 4: Run the full test suite**

```bash
python -m pytest tests/ -v
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/grid-model-integration"
git add src/drum_variation_generator.py
git commit -m "refactor: quantize original immediately in _generation_worker

ChucK now receives the grid-corrected loop before variation generation
starts. Quantized pattern is passed to slot threads so variations are
generated from the corrected groove. _write_quantized_original() removed
— logic inlined at top of worker."
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| `quantize_to_steps()` with median phase + spread diagnostic | Task 1 |
| `chuloopa_txt_to_grid_tokens()` uses shared function | Task 2 |
| `grid_model_variation()` uses shared function | Task 3 |
| Quantize upfront, write immediately with `# quantized` marker | Task 4 |
| `_write_quantized_original()` folded into worker | Task 4 |
| Variations generated from quantized pattern | Task 4 |

All spec requirements covered. ✓

**Placeholder scan:** No TBDs, no "implement later", no vague error handling. ✓

**Type consistency:** `quantize_to_steps` takes `list[tuple[float, int]]` throughout. Task 3 converts DrumHit → `(timestamp, midi_note)` tuples before calling it. Task 4 same conversion. ✓

**`step_duration` in Task 3:** The print line `step_duration = loop_duration / 16` is needed for the `print` context line below it — kept intentionally. ✓
