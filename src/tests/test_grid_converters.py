import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from format_converters import chuloopa_txt_to_grid_tokens, grid_tokens_to_chuloopa_txt


# ── fixtures ──────────────────────────────────────────────────────────────────

SIMPLE_DRUMS = """\
# Track 0 Drum Data
# Format: MIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME
# MIDI_NOTE: GM MIDI note number (36=kick, 38=snare, 42=hat, etc.)
# DELTA_TIME: Duration until next hit (for last hit: time until loop end)
# Total loop duration: 2.000000 seconds
36,0.000000,0.770000,0.500000
38,0.500000,0.740000,0.500000
36,1.000000,0.725000,0.500000
38,1.500000,0.787000,0.500000
"""

SLIGHTLY_OFF_DRUMS = """\
# Total loop duration: 2.000000 seconds
36,0.010000,0.750000,0.490000
38,0.515000,0.750000,0.485000
36,1.005000,0.750000,0.495000
38,1.490000,0.750000,0.510000
"""


def make_temp_file(content: str) -> str:
    f = tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False)
    f.write(content)
    f.close()
    return f.name


# ── chuloopa_txt_to_grid_tokens ───────────────────────────────────────────────

def test_on_grid_hits_snap_exactly():
    path = make_temp_file(SIMPLE_DRUMS)
    try:
        # At 120 BPM: step_duration = 0.125s
        # 0.0s→P0, 0.5s→P4, 1.0s→P8, 1.5s→P12
        tokens, loop_duration = chuloopa_txt_to_grid_tokens(path, bpm=120.0)
        assert tokens == ["P0", "N36", "P4", "N38", "P8", "N36", "P12", "N38"]
        assert loop_duration == 2.0
    finally:
        os.unlink(path)


def test_slightly_off_grid_hits_snap_to_nearest_step():
    path = make_temp_file(SLIGHTLY_OFF_DRUMS)
    try:
        # step_duration = 0.125s
        # 0.010 → round(0.010/0.125)=0 → P0
        # 0.515 → round(0.515/0.125)=4 → P4
        # 1.005 → round(1.005/0.125)=8 → P8
        # 1.490 → round(1.490/0.125)=12 → P12
        tokens, loop_duration = chuloopa_txt_to_grid_tokens(path, bpm=120.0)
        assert tokens == ["P0", "N36", "P4", "N38", "P8", "N36", "P12", "N38"]
    finally:
        os.unlink(path)


def test_step_clamped_to_15():
    # A hit right at or after loop end should clamp to P15, not overflow
    content = "# Total loop duration: 2.000000 seconds\n36,1.990000,0.750000,0.010000\n"
    path = make_temp_file(content)
    try:
        tokens, _ = chuloopa_txt_to_grid_tokens(path, bpm=120.0)
        # 1.990 / 0.125 = 15.92 → round → 16 → clamped to 15
        assert tokens == ["P15", "N36"]
    finally:
        os.unlink(path)


def test_tokens_sorted_by_step_then_pitch():
    # Two notes at the same step should be sorted by pitch (ascending)
    content = "# Total loop duration: 2.000000 seconds\n42,0.000000,0.75,0.5\n36,0.000000,0.75,0.5\n"
    path = make_temp_file(content)
    try:
        tokens, _ = chuloopa_txt_to_grid_tokens(path, bpm=120.0)
        # pitch 36 < pitch 42, so N36 should come before N42 at same step
        assert tokens == ["P0", "N36", "P0", "N42"]
    finally:
        os.unlink(path)


def test_returns_loop_duration():
    path = make_temp_file(SIMPLE_DRUMS)
    try:
        _, loop_duration = chuloopa_txt_to_grid_tokens(path, bpm=120.0)
        assert abs(loop_duration - 2.0) < 1e-9
    finally:
        os.unlink(path)


# ── grid_tokens_to_chuloopa_txt ───────────────────────────────────────────────

def test_timestamps_computed_from_steps():
    tokens = ["P0", "N36", "P4", "N38", "P8", "N36", "P12", "N38"]
    bpm = 120.0
    loop_duration = 2.0
    path = tempfile.mktemp(suffix='.txt')
    try:
        grid_tokens_to_chuloopa_txt(tokens, bpm=bpm, loop_duration=loop_duration, output_filepath=path)
        hits = []
        with open(path) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    parts = line.strip().split(',')
                    hits.append((int(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])))

        assert len(hits) == 4
        # step_duration = 0.125s
        assert abs(hits[0][1] - 0.0) < 1e-6    # P0 → 0.0s
        assert abs(hits[1][1] - 0.5) < 1e-6    # P4 → 0.5s
        assert abs(hits[2][1] - 1.0) < 1e-6    # P8 → 1.0s
        assert abs(hits[3][1] - 1.5) < 1e-6    # P12 → 1.5s
    finally:
        if os.path.exists(path):
            os.unlink(path)


def test_delta_times_correct():
    tokens = ["P0", "N36", "P4", "N38", "P8", "N36", "P12", "N38"]
    bpm = 120.0
    loop_duration = 2.0
    path = tempfile.mktemp(suffix='.txt')
    try:
        grid_tokens_to_chuloopa_txt(tokens, bpm=bpm, loop_duration=loop_duration, output_filepath=path)
        deltas = []
        with open(path) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    deltas.append(float(line.strip().split(',')[3]))

        # Each hit 0.5s apart; last delta = loop_duration - 1.5s = 0.5s
        assert all(abs(d - 0.5) < 1e-6 for d in deltas)
    finally:
        if os.path.exists(path):
            os.unlink(path)


def test_velocity_is_constant_0_75():
    tokens = ["P0", "N36", "P8", "N38"]
    path = tempfile.mktemp(suffix='.txt')
    try:
        grid_tokens_to_chuloopa_txt(tokens, bpm=120.0, loop_duration=2.0, output_filepath=path)
        with open(path) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    vel = float(line.strip().split(',')[2])
                    assert abs(vel - 0.75) < 1e-6
    finally:
        if os.path.exists(path):
            os.unlink(path)


def test_loop_duration_in_header():
    tokens = ["P0", "N36"]
    path = tempfile.mktemp(suffix='.txt')
    try:
        grid_tokens_to_chuloopa_txt(tokens, bpm=120.0, loop_duration=3.141593, output_filepath=path)
        with open(path) as f:
            content = f.read()
        assert "3.141593" in content
    finally:
        if os.path.exists(path):
            os.unlink(path)


def test_roundtrip_snaps_cleanly():
    # Off-grid input → quantize → write → read back and confirm timestamps are on grid
    path_in = make_temp_file(SLIGHTLY_OFF_DRUMS)
    path_out = tempfile.mktemp(suffix='.txt')
    try:
        tokens, loop_duration = chuloopa_txt_to_grid_tokens(path_in, bpm=120.0)
        grid_tokens_to_chuloopa_txt(tokens, bpm=120.0, loop_duration=loop_duration, output_filepath=path_out)

        step_duration = (60.0 / 120.0) / 4.0
        with open(path_out) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    ts = float(line.strip().split(',')[1])
                    remainder = ts % step_duration
                    assert remainder < 1e-9 or abs(remainder - step_duration) < 1e-9, \
                        f"Timestamp {ts} is not on the 16th-note grid"
    finally:
        os.unlink(path_in)
        if os.path.exists(path_out):
            os.unlink(path_out)


def test_phase_shifted_input_snaps_correctly(capsys):
    # Simulates a recording where all hits are shifted ~0.1s late.
    # Naive quantization gives wrong steps [1,5,7,9,12];
    # median phase must recover the correct [0,4,6,8,12] pattern.
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
