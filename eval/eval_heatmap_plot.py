#!/usr/bin/env python3
"""
eval_heatmap_plot.py — regenerate per-slot heatmap PNGs from saved eval_output/ txt files.

Produces: eval_heatmap_test1_slot1.png … test2_slot5.png  (10 files total)
No input panel; one figure per variation slot.

Usage:
    cd "Code/CHULOOPA"
    python eval_heatmap_plot.py
"""

import sys
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pretty_midi

REPO_ROOT = Path(__file__).parent
SRC_DIR   = REPO_ROOT / "src"
sys.path.insert(0, str(SRC_DIR))

from drum_variation_generator import DrumHit, DrumPattern
from format_converters import quantize_to_steps

# ── Config ────────────────────────────────────────────────────────────────────

N_RUNS  = 10
N_STEPS = 16
OUT_DIR = REPO_ROOT / "eval_output"

EVALS_DIR = Path(
    "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/CHULOOPA_EVALS"
)
TEST_TXTS = {
    "test1": EVALS_DIR / "TEST 1 - track_0_drums.txt",
    "test2": EVALS_DIR / "TEST 2 - track_0_drums.txt",
}
TEST_LABELS = {
    "test1": "Test 1: Simple kick–snare groove",
    "test2": "Test 2: More complex groove",
}
SLOT_LABELS = {
    1: "Slot 1 — least deviant",
    2: "Slot 2",
    3: "Slot 3",
    4: "Slot 4",
    5: "Slot 5 — most deviant",
}
SPICE_LABELS = {
    0: ("Low",      0.2),
    1: ("Med-Low",  0.4),
    2: ("Medium",   0.6),
    3: ("Med-High", 0.8),
    4: ("High",     1.0),
}

# Drum family ordering: lower group → bottom of chart (kick=0, others=6)
VOICE_ORDER = {
    35: (0, 0), 36: (0, 1),                                          # Kick
    38: (1, 0), 40: (1, 1), 37: (1, 2),                             # Snare
    44: (2, 0), 42: (2, 1), 22: (2, 2), 46: (2, 3), 26: (2, 4),    # Hi-hats
    41: (3, 0), 43: (3, 1), 58: (3, 2), 45: (3, 3),                 # Toms (low→high)
    47: (3, 4), 48: (3, 5), 50: (3, 6),
    49: (4, 0), 55: (4, 1), 57: (4, 2), 52: (4, 3),                 # Crashes
    51: (5, 0), 53: (5, 1), 59: (5, 2),                             # Ride
    39: (6, 0), 27: (6, 1), 28: (6, 2),                             # Others
}

def _voice_sort_key(v):
    group, within = VOICE_ORDER.get(v, (7, v))
    return (-group, within)  # negate group so group 0 (kick) sorts last → bottom row
DRUM_NAMES = {
    # Standard GM
    35: "Kick 2",
    39: "Clap",
    41: "Lo Tom",
    # Roland TD-17 default note map
    22: "HH Cls Edge",
    26: "HH Opn Edge",
    27: "AUX1 Head",
    28: "AUX1 Rim",
    36: "Kick",
    37: "X-Stick",
    38: "Snare",
    40: "Snare Rim",
    42: "HH Cls Bow",
    43: "Tom 3",
    44: "HH Pedal",
    45: "Tom 2",
    46: "HH Opn Bow",
    47: "Tom 2 Rim",
    48: "Tom 1",
    49: "Crash 1",
    50: "Tom 1 Rim",
    51: "Ride Bow",
    52: "Crash 2 Edge",
    53: "Ride Bell",
    55: "Crash 1 Edge",
    57: "Crash 2",
    58: "Tom 3 Rim",
    59: "Ride Edge",
}


# ── I/O helpers ──────────────────────────────────────────────────────────────

def midi_to_drum_pattern(midi_path: Path) -> DrumPattern:
    pm   = pretty_midi.PrettyMIDI(str(midi_path))
    hits = []
    for inst in pm.instruments:
        for note in inst.notes:
            hits.append(DrumHit(
                midi_note=note.pitch, timestamp=note.start,
                velocity=note.velocity / 127.0, delta_time=0.0,
            ))
    hits.sort(key=lambda h: h.timestamp)
    pattern = DrumPattern(hits=hits, loop_duration=pm.get_end_time(),
                          source_file=str(midi_path))
    pattern._recalculate_delta_times()
    return pattern


def quantize_pattern(pattern: DrumPattern) -> DrumPattern:
    step_dur = pattern.loop_duration / N_STEPS
    events   = quantize_to_steps(
        [(h.timestamp, h.midi_note) for h in pattern.hits],
        pattern.loop_duration,
    )
    q_hits = [
        DrumHit(midi_note=pitch, timestamp=step * step_dur,
                velocity=0.75, delta_time=0.0)
        for step, pitch in events
    ]
    q = DrumPattern(hits=q_hits, loop_duration=pattern.loop_duration,
                    source_file=pattern.source_file)
    q._recalculate_delta_times()
    return q


def load_slot_txt(path: Path) -> DrumPattern:
    """Parse a saved slot txt file back into a DrumPattern."""
    loop_duration = None
    hits = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('#'):
                if 'Total loop duration:' in line:
                    loop_duration = float(line.split(':')[1].strip().split()[0])
                continue
            parts = line.split(',')
            if len(parts) < 4:
                continue
            hits.append(DrumHit(
                midi_note=int(parts[0]),
                timestamp=float(parts[1]),
                velocity=float(parts[2]),
                delta_time=float(parts[3]),
            ))
    if loop_duration is None:
        loop_duration = hits[-1].timestamp + hits[-1].delta_time if hits else 1.0
    return DrumPattern(hits=hits, loop_duration=loop_duration)


def pattern_to_grid(pattern: DrumPattern, voices: list) -> np.ndarray:
    step_dur  = pattern.loop_duration / N_STEPS
    voice_idx = {v: i for i, v in enumerate(voices)}
    grid = np.zeros((len(voices), N_STEPS))
    for h in pattern.hits:
        if h.midi_note in voice_idx:
            step = int(round(h.timestamp / step_dur)) % N_STEPS
            grid[voice_idx[h.midi_note], step] = 1.0
    return grid


# ── Heatmap builder ───────────────────────────────────────────────────────────

def build_heatmaps_from_files(test_name: str, q_pattern: DrumPattern):
    """
    Load saved txt outputs and aggregate into per-slot hit-probability heatmaps.

    Returns:
        all_voices    — sorted list of MIDI notes active across input + all slots
        input_grid    — (voices × steps) binary array
        slot_heatmaps — (5 × voices × steps) hit-probability arrays
    """
    # Collect all active voices across runs
    all_voices = set(h.midi_note for h in q_pattern.hits)
    for run_idx in range(1, N_RUNS + 1):
        for slot_idx in range(1, 6):
            txt = OUT_DIR / test_name / f"run_{run_idx:02d}" / f"slot{slot_idx}.txt"
            if txt.exists():
                p = load_slot_txt(txt)
                all_voices.update(h.midi_note for h in p.hits)
    all_voices = sorted(all_voices, key=_voice_sort_key)

    input_grid    = pattern_to_grid(q_pattern, all_voices)
    slot_heatmaps = np.zeros((5, len(all_voices), N_STEPS))

    for run_idx in range(1, N_RUNS + 1):
        for slot_idx in range(1, 6):
            txt = OUT_DIR / test_name / f"run_{run_idx:02d}" / f"slot{slot_idx}.txt"
            if txt.exists():
                p = load_slot_txt(txt)
                slot_heatmaps[slot_idx - 1] += pattern_to_grid(p, all_voices)

    slot_heatmaps /= N_RUNS
    return all_voices, input_grid, slot_heatmaps


# ── Plotting ──────────────────────────────────────────────────────────────────

def plot_slot(test_name: str, test_label: str, slot_idx: int,
              all_voices: list, input_grid: np.ndarray,
              slot_hm: np.ndarray, vmax: float, out_path: Path):
    """
    One clean heatmap figure for a single slot.
    Only voices with any activity in input OR this slot are shown.
    """
    # Filter to active voices for this slot
    active_mask = (input_grid.max(axis=1) > 0) | (slot_hm.max(axis=1) > 0)
    active_idx  = np.where(active_mask)[0]
    voices_here = [all_voices[i] for i in active_idx]
    grid_here   = slot_hm[active_idx]
    inp_here    = input_grid[active_idx]

    n_voices = len(voices_here)
    ylabels  = [DRUM_NAMES.get(v, f"Note {v}") for v in voices_here]

    # Figure: 11 × (1.0 + 0.45 × n_voices), min height 3.5
    fig_h = max(3.5, 1.0 + 0.45 * n_voices)
    fig, ax = plt.subplots(figsize=(11, fig_h))

    im = ax.imshow(
        grid_here, aspect='auto', vmin=0, vmax=vmax,
        cmap='YlOrRd', interpolation='nearest',
    )

    # White circles at input positions
    for vi in range(n_voices):
        for si in range(N_STEPS):
            if inp_here[vi, si] > 0:
                ax.plot(si, vi, 'o', color='white', markersize=7,
                        markeredgecolor='#1e293b', markeredgewidth=1.0,
                        alpha=0.95, zorder=5)

    # Beat-boundary grid lines
    for beat in [3.5, 7.5, 11.5]:
        ax.axvline(beat, color='#94a3b8', linewidth=0.8, linestyle='--',
                   alpha=0.7, zorder=3)

    # Axis labels
    ax.set_yticks(range(n_voices))
    ax.set_yticklabels(ylabels, fontsize=10)
    ax.set_xticks(range(N_STEPS))
    ax.set_xticklabels([str(i + 1) for i in range(N_STEPS)], fontsize=9)
    ax.set_xlabel("16th-note step", fontsize=10)

    # Colorbar
    cbar = fig.colorbar(im, ax=ax, pad=0.01, fraction=0.025)
    cbar.set_label("Hit probability", fontsize=9)
    cbar.ax.tick_params(labelsize=8)

    # Input position legend
    legend_handle = plt.Line2D(
        [0], [0], marker='o', color='w', markerfacecolor='white',
        markeredgecolor='#1e293b', markersize=7, markeredgewidth=1.0,
        label='Input Pattern',
    )
    ax.legend(handles=[legend_handle], fontsize=9, loc='upper right',
              framealpha=0.85, edgecolor='#cbd5e1')

    # Density annotation
    density = float(slot_hm.sum())
    ax.text(0.01, 0.02, f"avg hits/bar: {density:.1f}",
            transform=ax.transAxes, fontsize=8.5, color='#475569',
            va='bottom')

    spice_name, spice_val = SPICE_LABELS[slot_idx]
    ax.set_title(
        f"Var {slot_idx + 1} — {spice_name} Spice ({spice_val}) · Hit Probability",
        fontsize=11, fontweight='bold', pad=8,
    )

    plt.tight_layout()
    plt.savefig(out_path, dpi=220, bbox_inches='tight')
    plt.close(fig)
    print(f"  Saved → {out_path.name}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    plt.rcParams.update({
        'font.family':       'sans-serif',
        'axes.spines.top':   False,
        'axes.spines.right': False,
    })

    for test_name, txt_path in TEST_TXTS.items():
        print(f"\n{test_name}: loading txt files from eval_output/{test_name}/")
        raw     = load_slot_txt(txt_path)
        q_pat   = quantize_pattern(raw)
        all_voices, input_grid, slot_heatmaps = build_heatmaps_from_files(test_name, q_pat)

        vmax = float(slot_heatmaps.max()) or 1.0

        for slot_idx in range(5):
            out_path = REPO_ROOT / f"eval_heatmap_{test_name}_slot{slot_idx + 1}.png"
            plot_slot(
                test_name, TEST_LABELS[test_name],
                slot_idx, all_voices, input_grid,
                slot_heatmaps[slot_idx], vmax, out_path,
            )

    print("\nDone.")


if __name__ == "__main__":
    main()
