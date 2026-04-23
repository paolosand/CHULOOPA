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
    random.seed(42)
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
    kick_hits = [(36, i * 0.25, 0.72) for i in range(8)]
    hat_hits  = [(42, i * 0.25 + 0.125, 0.72) for i in range(8)]
    original  = _make_pattern(kick_hits + hat_hits, loop_duration=2.0)
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
