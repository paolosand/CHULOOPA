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
    # Input 2 from test data — all hits shifted ~0.1s late.
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
    # Input 4 from test data — last kick drifts to step 9 and last snare to step 13 under naive.
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
    assert result[0][0] == 15


def test_sorted_by_step_then_note():
    # Same-step hits sorted by midi note ascending (matches training data ordering)
    result = quantize_to_steps([(0.0, 42), (0.0, 36)], loop_duration=2.0)
    assert result == [(0, 36), (0, 42)]


def test_spread_warning_logged(capsys):
    # Wide fractional spread triggers a warning print (no behavior change)
    # step_duration=0.125s; fracs=[0.0, 0.09, 0.0, 0.09] → spread=0.09 > 0.25*0.125=0.03125
    hits = [(0.0, 36), (0.09, 38), (0.5, 36), (0.59, 38)]
    quantize_to_steps(hits, loop_duration=2.0)
    captured = capsys.readouterr()
    assert "loose timing" in captured.out
