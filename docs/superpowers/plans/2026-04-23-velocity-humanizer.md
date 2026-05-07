# Velocity Humanizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `humanize_velocity_relative()` to replace flat 0.75 velocities in grid model output with input-anchored, per-instrument Gaussian draws.

**Architecture:** One new pure function added near existing humanization utilities, called once at the end of `grid_model_variation()` before returning. No changes to existing humanization paths or the quantized-original write-back.

**Tech Stack:** Python 3.10, `random` stdlib (Gaussian draws), existing `DrumPattern`/`DrumHit` dataclasses in `drum_variation_generator.py`.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `src/drum_variation_generator.py` | Modify | Add `humanize_velocity_relative()` after `groove_preserve()` (line ~795); call it at line 1064 |
| `tests/test_velocity_humanizer.py` | Create | Unit tests for the new function |

---

### Task 1: Create failing tests

**Files:**
- Create: `tests/test_velocity_humanizer.py`

- [ ] **Step 1: Create the tests file**

```python
# tests/test_velocity_humanizer.py
import sys, os, random
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from drum_variation_generator import DrumHit, DrumPattern, humanize_velocity_relative


def _make_pattern(hits_spec, loop_duration=2.0):
    """hits_spec: list of (midi_note, timestamp, velocity)"""
    hits = [DrumHit(midi_note=n, timestamp=t, velocity=v, delta_time=0.0)
            for n, t, v in hits_spec]
    p = DrumPattern(hits=hits, loop_duration=loop_duration, source_file="test")
    p._recalculate_delta_times()
    return p


def test_velocities_are_no_longer_flat():
    """All grid hits start at 0.75 — after humanization they should differ."""
    original = _make_pattern([(36, 0.0, 0.75), (38, 0.5, 0.75), (42, 1.0, 0.75)])
    variation = _make_pattern([(36, 0.0, 0.75), (38, 0.5, 0.75), (42, 1.0, 0.75)])
    result = humanize_velocity_relative(variation, original)
    velocities = [h.velocity for h in result.hits]
    assert len(set(round(v, 4) for v in velocities)) > 1, "All velocities still equal"


def test_soft_input_produces_soft_output():
    """Mean input velocity 0.30 → all output velocities should stay below 0.65."""
    random.seed(42)
    original = _make_pattern([(36, 0.0, 0.30), (38, 0.5, 0.30), (42, 1.0, 0.30)])
    variation = _make_pattern([(36, 0.0, 0.75), (38, 0.5, 0.75), (42, 1.0, 0.75)])
    result = humanize_velocity_relative(variation, original)
    for hit in result.hits:
        assert hit.velocity < 0.65, f"Velocity {hit.velocity:.3f} too loud for soft input"


def test_loud_input_produces_loud_output():
    """Mean input velocity 0.90 → velocities should generally stay above 0.50."""
    random.seed(42)
    original = _make_pattern([(36, 0.0, 0.90), (38, 0.5, 0.90), (42, 1.0, 0.90)])
    variation = _make_pattern([(36, 0.0, 0.75), (38, 0.5, 0.75), (42, 1.0, 0.75)])
    result = humanize_velocity_relative(variation, original)
    for hit in result.hits:
        assert hit.velocity > 0.50, f"Velocity {hit.velocity:.3f} too soft for loud input"


def test_kicks_louder_than_hats_on_average():
    """Kicks should average higher velocity than hats."""
    random.seed(0)
    original = _make_pattern([(36, 0.0, 0.72)] * 8 + [(42, 0.25, 0.72)] * 8)
    # Variation: 16 kicks + 16 hats
    variation_hits = [(36, i * 0.1, 0.75) for i in range(16)] + \
                     [(42, i * 0.1 + 0.05, 0.75) for i in range(16)]
    variation = _make_pattern(variation_hits, loop_duration=2.0)
    result = humanize_velocity_relative(variation, original)

    kick_vels = [h.velocity for h in result.hits if h.midi_note == 36]
    hat_vels  = [h.velocity for h in result.hits if h.midi_note == 42]
    assert sum(kick_vels) / len(kick_vels) > sum(hat_vels) / len(hat_vels), \
        "Kicks should average louder than hats"


def test_velocities_clamped():
    """No velocity should fall outside [0.10, 1.0]."""
    random.seed(99)
    original = _make_pattern([(36, 0.0, 0.72), (38, 0.5, 0.72)])
    variation = _make_pattern([(36, 0.0, 0.75)] * 20 + [(38, 0.1 * i, 0.75) for i in range(20)])
    result = humanize_velocity_relative(variation, original)
    for hit in result.hits:
        assert 0.10 <= hit.velocity <= 1.0, f"Velocity {hit.velocity} out of [0.10, 1.0]"


def test_empty_original_uses_fallback_base():
    """Empty original should not crash; fallback base=0.72 applied."""
    random.seed(7)
    original = _make_pattern([])
    variation = _make_pattern([(36, 0.0, 0.75), (38, 0.5, 0.75)])
    result = humanize_velocity_relative(variation, original)
    assert len(result.hits) == 2
    for hit in result.hits:
        assert 0.10 <= hit.velocity <= 1.0


def test_original_pattern_not_mutated():
    """humanize_velocity_relative must not modify the original pattern."""
    original = _make_pattern([(36, 0.0, 0.72), (38, 0.5, 0.68)])
    variation = _make_pattern([(36, 0.0, 0.75), (38, 0.5, 0.75)])
    orig_vels_before = [h.velocity for h in original.hits]
    humanize_velocity_relative(variation, original)
    orig_vels_after = [h.velocity for h in original.hits]
    assert orig_vels_before == orig_vels_after, "Original pattern was mutated"
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/paolosandejas/Documents/CALARTS\ -\ Music\ Tech/MFA\ Thesis/Code/CHULOOPA/.worktrees/feat/velocity-humanizer
python -m pytest tests/test_velocity_humanizer.py -v 2>&1 | head -30
```

Expected: `ImportError: cannot import name 'humanize_velocity_relative'`

---

### Task 2: Implement `humanize_velocity_relative()`

**Files:**
- Modify: `src/drum_variation_generator.py` — insert after `groove_preserve()` which ends around line 795

- [ ] **Step 1: Find the exact line after `groove_preserve` ends**

```bash
grep -n "^def \|^class " src/drum_variation_generator.py | head -30
```

Look for the line number of the function defined immediately after `groove_preserve`. Insert the new function just before it.

- [ ] **Step 2: Add the function**

Insert the following block immediately after the closing line of `groove_preserve()` (the blank line after the `return result` at the end of that function):

```python
# Per-instrument velocity table: (offset_from_base, sigma)
_INSTRUMENT_VEL_PARAMS = {
    # Kick
    35: (0.05, 0.05),
    36: (0.05, 0.05),
    # Snare
    37: (0.00, 0.06),
    38: (0.00, 0.06),
    39: (0.00, 0.06),
    40: (0.00, 0.06),
    # Hi-hat
    42: (-0.15, 0.08),
    44: (-0.15, 0.08),
    46: (-0.15, 0.08),
}
_INSTRUMENT_VEL_DEFAULT = (0.00, 0.06)


def humanize_velocity_relative(variation: DrumPattern,
                                original: DrumPattern) -> DrumPattern:
    """Assign fresh per-instrument velocities anchored to the original's mean.

    Replaces the flat 0.75 that the grid model writes for every hit with a
    Gaussian draw whose center is (original_mean + instrument_offset) and
    whose spread is instrument-specific sigma.

    Args:
        variation: Grid model output (all velocities typically 0.75).
        original:  The recorded beatbox pattern — provides the dynamic anchor.

    Returns:
        A copy of variation with humanized velocities. original is not mutated.
    """
    result = variation.copy()

    if original.hits:
        base = sum(h.velocity for h in original.hits) / len(original.hits)
    else:
        base = 0.72  # neutral fallback

    for hit in result.hits:
        offset, sigma = _INSTRUMENT_VEL_PARAMS.get(hit.midi_note, _INSTRUMENT_VEL_DEFAULT)
        center = base + offset
        hit.velocity = max(0.10, min(1.0, random.gauss(center, sigma)))

    return result
```

- [ ] **Step 3: Run the tests**

```bash
cd /Users/paolosandejas/Documents/CALARTS\ -\ Music\ Tech/MFA\ Thesis/Code/CHULOOPA/.worktrees/feat/velocity-humanizer
python -m pytest tests/test_velocity_humanizer.py -v
```

Expected: all 7 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add src/drum_variation_generator.py tests/test_velocity_humanizer.py
git commit -m "feat: add humanize_velocity_relative for grid model output"
```

---

### Task 3: Wire the call in `grid_model_variation()`

**Files:**
- Modify: `src/drum_variation_generator.py:1062-1065`

- [ ] **Step 1: Locate the insertion point**

```bash
grep -n "variation._recalculate_delta_times\|return variation, True" src/drum_variation_generator.py | head -10
```

Find the block inside `grid_model_variation()` that reads:

```python
        variation._recalculate_delta_times()

        print(f"    Variation: {len(variation.hits)} hits, loop={loop_duration:.2f}s")
        return variation, True
```

- [ ] **Step 2: Insert the humanization call**

Change that block to:

```python
        variation._recalculate_delta_times()
        variation = humanize_velocity_relative(variation, pattern)

        print(f"    Variation: {len(variation.hits)} hits, loop={loop_duration:.2f}s")
        return variation, True
```

(`pattern` is the original `DrumPattern` argument passed to `grid_model_variation()`.)

- [ ] **Step 3: Run tests again to confirm nothing broken**

```bash
cd /Users/paolosandejas/Documents/CALARTS\ -\ Music\ Tech/MFA\ Thesis/Code/CHULOOPA/.worktrees/feat/velocity-humanizer
python -m pytest tests/test_velocity_humanizer.py -v
```

Expected: all 7 tests PASS.

- [ ] **Step 4: Smoke test — inspect a generated variation file**

With the system running, generate a variation and check the velocity column is no longer flat:

```bash
cd /Users/paolosandejas/Documents/CALARTS\ -\ Music\ Tech/MFA\ Thesis/Code/CHULOOPA/.worktrees/feat/velocity-humanizer/src
python -c "
import sys; sys.path.insert(0, '.')
from drum_variation_generator import DrumPattern, grid_model_variation, init_grid_model
init_grid_model()
p = DrumPattern.from_file('tracks/track_0/track_0_drums.txt')
var, ok = grid_model_variation(p, spice_level=0.5)
print('ok:', ok)
for h in var.hits:
    print(f'  note={h.midi_note:3d}  vel={h.velocity:.3f}')
"
```

Expected: velocities vary across hits; kicks cluster higher than hats.

- [ ] **Step 5: Commit**

```bash
git add src/drum_variation_generator.py
git commit -m "feat: wire humanize_velocity_relative into grid_model_variation"
```
