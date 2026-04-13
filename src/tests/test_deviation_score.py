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
