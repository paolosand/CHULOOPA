#!/usr/bin/env python3
"""
Tests for timing anchoring functionality.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumHit, DrumPattern, timing_anchor


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


if __name__ == '__main__':
    test_timing_anchor_basic()
    test_timing_anchor_deduplication()
    print("✓ All timing_anchor tests passed")
