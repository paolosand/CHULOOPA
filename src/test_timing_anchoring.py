#!/usr/bin/env python3
"""
Tests for timing anchoring functionality.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumHit, DrumPattern, timing_anchor, fit_to_loop_duration


def test_timing_anchor_basic():
    """Test basic timing anchoring with low spice."""
    # Original pattern: 3 hits at 0.0s, 0.5s, 1.0s
    original = DrumPattern(
        hits=[
            DrumHit(drum_class=0, timestamp=0.0, velocity=0.8, delta_time=0.5),
            DrumHit(drum_class=1, timestamp=0.5, velocity=0.8, delta_time=0.5),
            DrumHit(drum_class=2, timestamp=1.0, velocity=0.8, delta_time=0.5),
        ],
        loop_duration=1.5
    )

    # Model output: 3 hits near original positions
    model_output = DrumPattern(
        hits=[
            DrumHit(drum_class=0, timestamp=0.02, velocity=0.8, delta_time=0.5),
            DrumHit(drum_class=1, timestamp=0.48, velocity=0.8, delta_time=0.5),
            DrumHit(drum_class=2, timestamp=1.03, velocity=0.8, delta_time=0.5),
        ],
        loop_duration=1.5
    )

    # Low spice: should anchor tightly (max_drift=30ms)
    anchored = timing_anchor(model_output, original, spice_level=0.2)

    # All hits should be anchored to exact grid positions
    assert len(anchored.hits) == 3
    assert anchored.hits[0].timestamp == 0.0
    assert anchored.hits[1].timestamp == 0.5
    assert anchored.hits[2].timestamp == 1.0


def test_timing_anchor_deduplication():
    """Test deduplication when multiple hits map to same grid position."""
    original = DrumPattern(
        hits=[
            DrumHit(drum_class=0, timestamp=0.0, velocity=0.8, delta_time=0.5),
            DrumHit(drum_class=1, timestamp=0.5, velocity=0.8, delta_time=0.5),
        ],
        loop_duration=1.0
    )

    # Model output: 3 hits, two near position 0.0
    model_output = DrumPattern(
        hits=[
            DrumHit(drum_class=0, timestamp=0.01, velocity=0.6, delta_time=0.0),
            DrumHit(drum_class=2, timestamp=0.02, velocity=0.9, delta_time=0.0),  # Higher velocity
            DrumHit(drum_class=1, timestamp=0.51, velocity=0.8, delta_time=0.0),
        ],
        loop_duration=1.0
    )

    # Should keep higher velocity hit at 0.0
    anchored = timing_anchor(model_output, original, spice_level=0.3)

    assert len(anchored.hits) == 2  # Deduplicated
    # Find hit at position 0.0
    hit_at_zero = [h for h in anchored.hits if h.timestamp == 0.0][0]
    assert hit_at_zero.velocity == 0.9  # Kept higher velocity
    assert hit_at_zero.drum_class == 2


def test_fit_to_loop_duration():
    """Test time-warping to exact loop duration."""
    # Pattern with 3 hits spanning 1.5 seconds
    pattern = DrumPattern(
        hits=[
            DrumHit(drum_class=0, timestamp=0.0, velocity=0.8, delta_time=0.0),
            DrumHit(drum_class=1, timestamp=0.75, velocity=0.8, delta_time=0.0),
            DrumHit(drum_class=2, timestamp=1.5, velocity=0.8, delta_time=0.0),
        ],
        loop_duration=1.5
    )

    # Warp to 2.25 seconds (1.5x scale)
    fitted = fit_to_loop_duration(pattern, target_duration=2.25)

    assert fitted.loop_duration == 2.25
    assert len(fitted.hits) == 3
    assert fitted.hits[0].timestamp == 0.0    # 0.0 * 1.5
    assert fitted.hits[1].timestamp == 1.125  # 0.75 * 1.5
    assert fitted.hits[2].timestamp == 2.25   # 1.5 * 1.5


def test_fit_to_loop_duration_removes_overflow():
    """Test that hits exceeding target duration are removed."""
    pattern = DrumPattern(
        hits=[
            DrumHit(drum_class=0, timestamp=0.0, velocity=0.8, delta_time=0.0),
            DrumHit(drum_class=1, timestamp=2.5, velocity=0.8, delta_time=0.0),
            DrumHit(drum_class=2, timestamp=3.0, velocity=0.8, delta_time=0.0),
        ],
        loop_duration=3.0
    )

    # Warp to 2.0 seconds - hit at 2.5 exceeds target, hit at 3.0 exceeds target
    fitted = fit_to_loop_duration(pattern, target_duration=2.0)

    # scale_factor = 2.0 / 3.0 = 0.667
    # Hit 1: 2.5 * 0.667 = 1.667 (kept)
    # Hit 2: 3.0 * 0.667 = 2.0 (kept at boundary)

    assert fitted.loop_duration == 2.0
    assert len(fitted.hits) == 3  # All kept (last one at boundary)
    assert fitted.hits[0].timestamp == 0.0
    assert abs(fitted.hits[1].timestamp - 1.667) < 0.01
    assert fitted.hits[2].timestamp == 2.0


if __name__ == '__main__':
    test_timing_anchor_basic()
    test_timing_anchor_deduplication()
    test_fit_to_loop_duration()
    test_fit_to_loop_duration_removes_overflow()
    print("✓ All timing tests passed")
