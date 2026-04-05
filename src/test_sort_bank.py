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
    # var4 initially: 7 hits (4 core+3 exotic) → hit_delta=+3, non_std=3 → score=3.9
    # var5 initially: 4 exotic hits → hit_delta=0, non_std=4 → score=1.2
    variations = {
        1: make_pattern([(36,0.0),(42,0.25),(42,0.5),(38,1.0),(36,1.5),(42,1.75)]),  # 6 hits, score=2.0
        2: make_pattern([(36, 0.0), (38, 1.0)]),                                     # 2 hits, score=-2.0
        3: make_pattern([(36, 0.0), (42, 0.5), (38, 1.0), (36, 1.5)]),              # 4 hits, score=0.0
        4: make_pattern([(36,0.0),(42,0.5),(38,1.0),(36,1.5),(46,2.0),(49,2.5),(51,3.0)]),  # 7 hits, score=3.9
        5: make_pattern([(46,0.0),(49,0.5),(51,1.0),(41,1.5)]),                      # 4 exotic, score=1.2
    }
    # Expected sorted order by score: var2(-2.0), var3(0.0), var5(1.2), var1(2.0), var4(3.9)
    # So after sort: slot1=var2(2 hits), slot2=var3(4 hits), slot3=var5(4 hits), slot4=var1(6 hits), slot5=var4(7 hits)

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
