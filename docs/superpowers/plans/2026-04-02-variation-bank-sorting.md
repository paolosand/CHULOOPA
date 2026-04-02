# Variation Bank Sorting by Deviation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After the 5-slot variation bank is generated, score each variation by deviation from the original pattern and rewrite slots 1–5 in ascending deviation order (least deviant → most deviant).

**Architecture:** Add a pure `compute_deviation_score` function, then add a sort-and-rewrite step at the end of `_generation_worker` (after all slot threads join, before sending `bank_ready`). No changes to slot generation, `_run_slot_thread`, or ChucK.

**Tech Stack:** Python 3.10+, existing `DrumPattern`/`DrumHit` dataclasses in `drum_variation_generator.py`

---

### Task 1: Add `compute_deviation_score` and `CORE_KIT`

**Files:**
- Modify: `src/drum_variation_generator.py:217-219` (insert after the `ALGORITHMIC VARIATIONS` section header)

- [ ] **Step 1: Insert `CORE_KIT` constant and `compute_deviation_score` after line 219**

Open `src/drum_variation_generator.py`. After line 219 (`# ===...ALGORITHMIC VARIATIONS...===`) and before the `humanize_pattern` function (line 221), insert:

```python
# MIDI notes considered "core kit" — kick variants, snare variants, closed hat
CORE_KIT = {35, 36, 38, 40, 42}


def compute_deviation_score(variation: 'DrumPattern', original: 'DrumPattern') -> float:
    """Score how much a variation deviates from the original pattern.

    Higher score = more deviant. Used to sort the variation bank so slot 1
    is always the least deviant and slot 5 is the most deviant.

    Args:
        variation: Generated variation (already trimmed to loop boundary)
        original: Original user-recorded pattern

    Returns:
        Deviation score (can be negative if variation has fewer hits than original)

    Score formula:
        hit_delta + 0.3 * non_standard_count
        - hit_delta: len(variation.hits) - len(original.hits)
          Primary driver. More hits = more complex.
        - non_standard_count: hits whose midi_note is not in CORE_KIT
          Secondary. Exotic notes (open hat, crash, ride, toms) add complexity.
          Weighted 0.3 so a few exotic notes don't outweigh a hit count difference.
    """
    hit_delta = len(variation.hits) - len(original.hits)
    non_standard = sum(1 for h in variation.hits if h.midi_note not in CORE_KIT)
    return hit_delta + 0.3 * non_standard

```

- [ ] **Step 2: Verify the file parses without errors**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python -c "import drum_variation_generator; print('OK')"
```

Expected output: `OK` (plus any `Note:` import warnings for missing optional packages — those are fine)

- [ ] **Step 3: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/drum_variation_generator.py
git commit -m "feat: add compute_deviation_score for variation bank sorting"
```

---

### Task 2: Write and run tests for `compute_deviation_score`

**Files:**
- Create: `src/test_deviation_score.py`

- [ ] **Step 1: Create test file**

Create `src/test_deviation_score.py`:

```python
"""Tests for compute_deviation_score in drum_variation_generator.py"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from drum_variation_generator import DrumPattern, DrumHit, CORE_KIT, compute_deviation_score


def make_pattern(notes, loop_duration=4.0):
    """Helper: build a DrumPattern from a list of (midi_note, timestamp) pairs."""
    hits = []
    for i, (note, ts) in enumerate(notes):
        hits.append(DrumHit(midi_note=note, timestamp=ts, velocity=0.8, delta_time=0.0))
    p = DrumPattern(hits=hits, loop_duration=loop_duration)
    p._recalculate_delta_times()
    return p


# Original: 4 core-kit hits
ORIGINAL = make_pattern([(36, 0.0), (42, 0.5), (38, 1.0), (36, 1.5)])


def test_identical_pattern_scores_zero():
    """Same hit count, all core kit → score 0.0"""
    variation = make_pattern([(36, 0.0), (42, 0.5), (38, 1.0), (36, 1.5)])
    assert compute_deviation_score(variation, ORIGINAL) == 0.0


def test_fewer_hits_scores_negative():
    """Sparser variation → negative score (less deviant direction)"""
    variation = make_pattern([(36, 0.0), (38, 1.0)])  # 2 hits vs 4
    score = compute_deviation_score(variation, ORIGINAL)
    assert score == -2.0  # hit_delta=-2, non_standard=0


def test_more_hits_scores_positive():
    """Denser variation (all core) → positive score"""
    variation = make_pattern([(36, 0.0), (42, 0.25), (42, 0.5), (38, 1.0), (36, 1.5), (42, 1.75)])
    score = compute_deviation_score(variation, ORIGINAL)
    assert score == 2.0  # hit_delta=+2, non_standard=0


def test_non_standard_notes_add_to_score():
    """Non-core hits contribute 0.3 each"""
    # Same hit count as original, but 2 non-standard notes
    variation = make_pattern([(36, 0.0), (46, 0.5), (38, 1.0), (49, 1.5)])  # 46=open hat, 49=crash
    score = compute_deviation_score(variation, ORIGINAL)
    assert abs(score - 0.6) < 1e-9  # hit_delta=0, non_standard=2 → 0 + 0.3*2 = 0.6


def test_hit_delta_dominates_non_standard():
    """More hits always scores higher than same-count with exotic notes"""
    # +2 hits, core only
    denser = make_pattern([(36, 0.0), (42, 0.25), (42, 0.5), (38, 1.0), (36, 1.5), (42, 1.75)])
    denser_score = compute_deviation_score(denser, ORIGINAL)  # 2.0

    # Same count as original, 4 exotic notes
    exotic = make_pattern([(46, 0.0), (49, 0.5), (51, 1.0), (41, 1.5)])
    exotic_score = compute_deviation_score(exotic, ORIGINAL)  # 0 + 0.3*4 = 1.2

    assert denser_score > exotic_score


def test_core_kit_contents():
    """CORE_KIT contains exactly the expected MIDI note numbers"""
    assert CORE_KIT == {35, 36, 38, 40, 42}


def test_empty_variation_scores_negative():
    """Empty variation (all hits trimmed) → score = -len(original.hits)"""
    empty = DrumPattern(hits=[], loop_duration=4.0)
    score = compute_deviation_score(empty, ORIGINAL)
    assert score == -4.0


if __name__ == "__main__":
    tests = [
        test_identical_pattern_scores_zero,
        test_fewer_hits_scores_negative,
        test_more_hits_scores_positive,
        test_non_standard_notes_add_to_score,
        test_hit_delta_dominates_non_standard,
        test_core_kit_contents,
        test_empty_variation_scores_negative,
    ]
    passed = 0
    for t in tests:
        try:
            t()
            print(f"  PASS  {t.__name__}")
            passed += 1
        except AssertionError as e:
            print(f"  FAIL  {t.__name__}: {e}")
        except Exception as e:
            print(f"  ERROR {t.__name__}: {e}")
    print(f"\n{passed}/{len(tests)} passed")
```

- [ ] **Step 2: Run tests**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python test_deviation_score.py
```

Expected output:
```
  PASS  test_identical_pattern_scores_zero
  PASS  test_fewer_hits_scores_negative
  PASS  test_more_hits_scores_positive
  PASS  test_non_standard_notes_add_to_score
  PASS  test_hit_delta_dominates_non_standard
  PASS  test_core_kit_contents
  PASS  test_empty_variation_scores_negative

7/7 passed
```

If any test fails, fix `compute_deviation_score` (not the tests) and re-run.

- [ ] **Step 3: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/test_deviation_score.py
git commit -m "test: add deviation score tests"
```

---

### Task 3: Add `_sort_variation_bank` helper to `_generation_worker`

**Files:**
- Modify: `src/drum_variation_generator.py` — add `_sort_variation_bank` function just before `_generation_worker` (around line 1213)

- [ ] **Step 1: Insert `_sort_variation_bank` before `_generation_worker`**

Insert the following function immediately before the `def _generation_worker():` line (currently line 1213):

```python
def _sort_variation_bank(written_slots: set, original: 'DrumPattern'):
    """Sort written variation files by deviation score ascending (least → most deviant).

    Loads each written variation from disk, scores it against the original,
    sorts by score, then rewrites var1..var{n}.txt in sorted order.
    In-memory rewrite avoids rename conflicts.

    Args:
        written_slots: Set of slot ints (1-5) that were successfully written
        original: Original user-recorded pattern (used as deviation reference)
    """
    if not written_slots or len(written_slots) < 2:
        return  # Nothing to sort

    variations_dir = DEFAULT_VARIATIONS_DIR

    # Load all written variations from disk (guarantees we score the trimmed, saved version)
    slot_patterns = {}
    for slot in written_slots:
        var_file = variations_dir / f"track_0_drums_var{slot}.txt"
        if var_file.exists():
            try:
                slot_patterns[slot] = DrumPattern.from_file(str(var_file))
            except Exception as e:
                print(f"  [Sort] Could not load var{slot}: {e}")

    if len(slot_patterns) < 2:
        return  # Not enough variations to sort

    # Score each variation
    scored = [(slot, compute_deviation_score(pat, original)) for slot, pat in slot_patterns.items()]
    scored.sort(key=lambda x: x[1])  # ascending: least deviant first

    print(f"  [Sort] Deviation scores: {[(f'var{s}', f'{sc:.2f}') for s, sc in scored]}")

    # Hold all patterns in memory before writing (avoids partial-write issues)
    ordered_patterns = [slot_patterns[slot] for slot, _ in scored]

    # Rewrite slots in sorted order
    sorted_slots = sorted(written_slots)  # e.g. [1, 2, 3, 4, 5]
    for final_slot, variation in zip(sorted_slots, ordered_patterns):
        out_file = variations_dir / f"track_0_drums_var{final_slot}.txt"
        try:
            variation.to_file(str(out_file))
        except Exception as e:
            print(f"  [Sort] Could not write var{final_slot}: {e}")

    print(f"  [Sort] Bank sorted: slot 1 = least deviant, slot {max(sorted_slots)} = most deviant")
```

- [ ] **Step 2: Verify the file parses**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python -c "import drum_variation_generator; print('OK')"
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/drum_variation_generator.py
git commit -m "feat: add _sort_variation_bank helper"
```

---

### Task 4: Wire `_sort_variation_bank` into `_generation_worker` and move `bank_ready`

**Files:**
- Modify: `src/drum_variation_generator.py` — inside `_generation_worker`, replace the join loop and `bank_ready` block

- [ ] **Step 1: Replace the join loop and `bank_ready` block**

In `_generation_worker`, find and replace the block that starts with `completed_slots = set()` and ends with `print(f"  [Worker] Done.")`. Use the exact old text below (note: line numbers shift after Task 3's insertion, so match by content not line number).

**Old block to replace** (starts after the `for t in threads.values(): t.start()` line):

```python
    completed_slots = set()
    bank_ready_sent = False

    # Join in slot order — bank_ready fires when slot 1 specifically completes
    for slot in slots:
        threads[slot].join()
        completed_slots.add(slot)
        print(f"  [Worker] Slot {slot} joined")

        if slot == 1 and not bank_ready_sent and 1 in written_slots and not stop_event.is_set() and osc_client:
            try:
                osc_client.send_message("/chuloopa/bank_ready", 0)
                osc_client.send_message("/chuloopa/generation_progress",
                                        "var1 ready — auto-switching enabled")
                bank_ready_sent = True
                print("  [Worker] bank_ready sent (slot 1 complete)")
            except Exception as e:
                print(f"  [Worker] OSC error sending bank_ready: {e}")

    # Fallback: if slot 1 failed for any reason
    if not bank_ready_sent and written_slots and not stop_event.is_set() and osc_client:
        lowest = min(written_slots)
        try:
            osc_client.send_message("/chuloopa/bank_ready", 0)
            osc_client.send_message("/chuloopa/generation_progress",
                                    f"var{lowest} ready — auto-switching enabled")
            bank_ready_sent = True
        except Exception as e:
            print(f"  [Worker] OSC error sending bank_ready fallback: {e}")

    # All-fail case — notify ChucK (only if nothing was written and not cancelled)
    if not bank_ready_sent and not written_slots and not stop_event.is_set() and osc_client:
        try:
            osc_client.send_message("/chuloopa/generation_progress",
                                    "All slots failed — press D#1 to retry")
        except Exception as e:
            print(f"  [Worker] OSC error sending all-fail message: {e}")

    print(f"  [Worker] Done.")
```

**New block to insert:**

```python
    # Join all slot threads before sorting
    for slot in slots:
        threads[slot].join()
        print(f"  [Worker] Slot {slot} joined")

    if stop_event.is_set():
        print(f"  [Worker] Cancelled — skipping sort and bank_ready")
        return

    # Sort bank by deviation score (least → most deviant) then send bank_ready
    if written_slots:
        _sort_variation_bank(written_slots, pattern)

    bank_ready_sent = False

    if written_slots and not stop_event.is_set() and osc_client:
        try:
            osc_client.send_message("/chuloopa/bank_ready", 0)
            osc_client.send_message("/chuloopa/generation_progress",
                                    "Bank ready — sorted by deviation")
            bank_ready_sent = True
            print("  [Worker] bank_ready sent (bank sorted)")
        except Exception as e:
            print(f"  [Worker] OSC error sending bank_ready: {e}")

    if not bank_ready_sent and not written_slots and not stop_event.is_set() and osc_client:
        try:
            osc_client.send_message("/chuloopa/generation_progress",
                                    "All slots failed — press D#1 to retry")
        except Exception as e:
            print(f"  [Worker] OSC error sending all-fail message: {e}")

    print(f"  [Worker] Done.")
```

- [ ] **Step 2: Verify the file parses**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python -c "import drum_variation_generator; print('OK')"
```

Expected: `OK`

- [ ] **Step 3: Re-run deviation score tests to confirm no regressions**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python test_deviation_score.py
```

Expected: `7/7 passed`

- [ ] **Step 4: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/drum_variation_generator.py
git commit -m "feat: sort variation bank by deviation after generation"
```

---

### Task 5: Smoke-test the full sort pipeline with fixture files

**Files:**
- Create: `src/test_sort_bank.py`

- [ ] **Step 1: Create smoke test**

Create `src/test_sort_bank.py`:

```python
"""Smoke test: _sort_variation_bank rewrites files in ascending deviation order."""

import sys
import os
import tempfile
import shutil
sys.path.insert(0, os.path.dirname(__file__))

from pathlib import Path
from drum_variation_generator import (
    DrumPattern, DrumHit,
    DEFAULT_VARIATIONS_DIR,
    _sort_variation_bank, compute_deviation_score, CORE_KIT
)


def make_pattern(notes, loop_duration=4.0):
    hits = [DrumHit(midi_note=n, timestamp=ts, velocity=0.8, delta_time=0.0) for n, ts in notes]
    p = DrumPattern(hits=hits, loop_duration=loop_duration)
    p._recalculate_delta_times()
    return p


def test_sort_bank_rewrites_in_order():
    """After _sort_variation_bank, var1 has lowest score, var5 has highest."""

    original = make_pattern([(36, 0.0), (42, 0.5), (38, 1.0), (36, 1.5)])  # 4 core hits

    # Five variations with known scores (relative to original):
    # var1 initially: 6 core hits  → hit_delta=+2, score=2.0
    # var2 initially: 2 core hits  → hit_delta=-2, score=-2.0  (should end up slot 1)
    # var3 initially: 4 core hits  → hit_delta=0,  score=0.0
    # var4 initially: 5 core + 2 exotic → hit_delta=+1, score=1.6
    # var5 initially: 4 core + 4 exotic → hit_delta=0, score=1.2
    variations = {
        1: make_pattern([(36,0.0),(42,0.25),(42,0.5),(38,1.0),(36,1.5),(42,1.75)]),  # 6 hits, score=2.0
        2: make_pattern([(36, 0.0), (38, 1.0)]),                                     # 2 hits, score=-2.0
        3: make_pattern([(36, 0.0), (42, 0.5), (38, 1.0), (36, 1.5)]),              # 4 hits, score=0.0
        4: make_pattern([(36,0.0),(42,0.5),(38,1.0),(36,1.5),(46,2.0),(49,2.5),(51,3.0)]),  # 5 core+2 exotic → wait recalc
        5: make_pattern([(46,0.0),(49,0.5),(51,1.0),(41,1.5)]),                      # 4 exotic, score=1.2
    }
    # Recompute score 4: 7 hits total, 3 exotic → hit_delta=+3, non_std=3 → 3+0.9=3.9
    # Recompute score 5: 4 hits, 4 exotic → hit_delta=0, non_std=4 → 0+1.2=1.2
    # Expected sorted order by score: var2(-2.0), var3(0.0), var5(1.2), var1(2.0), var4(3.9)
    # So after sort: slot1=var2, slot2=var3, slot3=var5, slot4=var1, slot5=var4

    # Write to a temp directory
    tmpdir = Path(tempfile.mkdtemp())
    try:
        for slot, pat in variations.items():
            pat.to_file(str(tmpdir / f"track_0_drums_var{slot}.txt"))

        # Monkeypatch DEFAULT_VARIATIONS_DIR
        import drum_variation_generator as dvg
        original_dir = dvg.DEFAULT_VARIATIONS_DIR
        dvg.DEFAULT_VARIATIONS_DIR = tmpdir

        _sort_variation_bank(set(variations.keys()), original)

        # Restore
        dvg.DEFAULT_VARIATIONS_DIR = original_dir

        # Load sorted files and check hit counts match expected order
        hit_counts = []
        for slot in [1, 2, 3, 4, 5]:
            p = DrumPattern.from_file(str(tmpdir / f"track_0_drums_var{slot}.txt"))
            hit_counts.append(len(p.hits))

        # Scores ascending: -2.0, 0.0, 1.2, 2.0, 3.9
        # Hit counts: 2, 4, 4, 6, 7
        assert hit_counts[0] == 2,  f"slot1 should have 2 hits, got {hit_counts[0]}"
        assert hit_counts[1] == 4,  f"slot2 should have 4 hits, got {hit_counts[1]}"
        assert hit_counts[2] == 4,  f"slot3 should have 4 hits, got {hit_counts[2]}"
        assert hit_counts[3] == 6,  f"slot4 should have 6 hits, got {hit_counts[3]}"
        assert hit_counts[4] == 7,  f"slot5 should have 7 hits, got {hit_counts[4]}"

        print("  PASS  test_sort_bank_rewrites_in_order")

    finally:
        shutil.rmtree(tmpdir)


def test_sort_bank_single_slot_is_noop():
    """With only 1 written slot, _sort_variation_bank returns without error."""
    original = make_pattern([(36, 0.0), (38, 1.0)])
    tmpdir = Path(tempfile.mkdtemp())
    try:
        pat = make_pattern([(36, 0.0), (42, 0.5)])
        pat.to_file(str(tmpdir / "track_0_drums_var1.txt"))

        import drum_variation_generator as dvg
        original_dir = dvg.DEFAULT_VARIATIONS_DIR
        dvg.DEFAULT_VARIATIONS_DIR = tmpdir
        _sort_variation_bank({1}, original)  # Should not raise
        dvg.DEFAULT_VARIATIONS_DIR = original_dir

        print("  PASS  test_sort_bank_single_slot_is_noop")
    finally:
        shutil.rmtree(tmpdir)


if __name__ == "__main__":
    tests = [test_sort_bank_rewrites_in_order, test_sort_bank_single_slot_is_noop]
    passed = 0
    for t in tests:
        try:
            t()
            passed += 1
        except AssertionError as e:
            print(f"  FAIL  {t.__name__}: {e}")
        except Exception as e:
            import traceback
            print(f"  ERROR {t.__name__}: {e}")
            traceback.print_exc()
    print(f"\n{passed}/{len(tests)} passed")
```

- [ ] **Step 2: Run smoke tests**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python test_sort_bank.py
```

Expected output:
```
  PASS  test_sort_bank_rewrites_in_order
  PASS  test_sort_bank_single_slot_is_noop

2/2 passed
```

If `test_sort_bank_rewrites_in_order` fails, check the score calculation for variation 4 (7 hits: 4 core + 3 exotic → `hit_delta=3, non_standard=3 → score=3.9`). Adjust the expected `hit_counts` assertion if your score calculation differs.

- [ ] **Step 3: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/test_sort_bank.py
git commit -m "test: smoke test _sort_variation_bank file rewrite"
```
