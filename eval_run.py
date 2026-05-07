#!/usr/bin/env python3
"""
eval_run.py — Generate variation banks + heatmap PNGs from a single CHULOOPA txt file.

Usage:
    python eval_run.py path/to/track_0_drums.txt
    python eval_run.py path/to/track_0_drums.txt --runs 10 --name mytest

Outputs:
    eval_output/<name>/run_01/slot1.txt … run_N/slot5.txt
    eval_heatmap_<name>_slot1.png … eval_heatmap_<name>_slot5.png
"""

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent
SRC_DIR   = REPO_ROOT / "src"
sys.path.insert(0, str(SRC_DIR))

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

from drum_variation_generator import (
    DrumHit, DrumPattern,
    grid_model_variation, init_grid_model,
    compute_deviation_score,
)
from format_converters import quantize_to_steps

# ── Config ────────────────────────────────────────────────────────────────────

N_STEPS      = 16
SPICE_LEVELS = [0.2, 0.4, 0.6, 0.8, 1.0]

DRUM_NAMES = {
    35: "Kick 2",  39: "Clap",  41: "Lo Tom",
    22: "HH Cls Edge",  26: "HH Opn Edge",  27: "AUX1 Head",  28: "AUX1 Rim",
    36: "Kick",    37: "X-Stick",  38: "Snare",   40: "Snare Rim",
    42: "HH Cls Bow",  43: "Tom 3",   44: "HH Pedal",  45: "Tom 2",
    46: "HH Opn Bow",  47: "Tom 2 Rim",  48: "Tom 1",   49: "Crash 1",
    50: "Tom 1 Rim",   51: "Ride Bow",   52: "Crash 2 Edge",  53: "Ride Bell",
    55: "Crash 1 Edge", 57: "Crash 2",   58: "Tom 3 Rim",  59: "Ride Edge",
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
    35: (0, 0),  36: (0, 1),
    38: (1, 0),  40: (1, 1),  37: (1, 2),
    44: (2, 0),  42: (2, 1),  22: (2, 2),  46: (2, 3),  26: (2, 4),
    41: (3, 0),  43: (3, 1),  58: (3, 2),  45: (3, 3),
    47: (3, 4),  48: (3, 5),  50: (3, 6),
    49: (4, 0),  55: (4, 1),  57: (4, 2),  52: (4, 3),
    51: (5, 0),  53: (5, 1),  59: (5, 2),
    39: (6, 0),  27: (6, 1),  28: (6, 2),
}

def _voice_sort_key(v):
    group, within = VOICE_ORDER.get(v, (7, v))
    return (-group, within)


# ── I/O ───────────────────────────────────────────────────────────────────────

def load_txt(path: Path) -> DrumPattern:
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
                midi_note=int(parts[0]),   timestamp=float(parts[1]),
                velocity=float(parts[2]),  delta_time=float(parts[3]),
            ))
    if not hits:
        raise ValueError(f"No hits found in {path}")
    if loop_duration is None:
        loop_duration = hits[-1].timestamp + hits[-1].delta_time
    return DrumPattern(hits=hits, loop_duration=loop_duration, source_file=str(path))


def quantize_pattern(pattern: DrumPattern) -> DrumPattern:
    step_dur = pattern.loop_duration / N_STEPS
    events   = quantize_to_steps(
        [(h.timestamp, h.midi_note) for h in pattern.hits],
        pattern.loop_duration,
    )
    q_hits = [
        DrumHit(midi_note=pitch, timestamp=step * step_dur, velocity=0.75, delta_time=0.0)
        for step, pitch in events
    ]
    q = DrumPattern(hits=q_hits, loop_duration=pattern.loop_duration,
                    source_file=pattern.source_file)
    q._recalculate_delta_times()
    return q


# ── Generation ────────────────────────────────────────────────────────────────

def run_bank(pattern: DrumPattern) -> list:
    """Generate 5 variations at increasing spice, sorted by deviation (low→high)."""
    variations = []
    for spice in SPICE_LEVELS:
        var, _ = grid_model_variation(pattern, spice_level=spice)
        variations.append(var)
    scored = [(compute_deviation_score(var, pattern), var) for var in variations]
    scored.sort(key=lambda x: x[0])
    return [var for _, var in scored]


# ── Heatmap construction ───────────────────────────────────────────────────────

def pattern_to_grid(pattern: DrumPattern, voices: list) -> np.ndarray:
    step_dur  = pattern.loop_duration / N_STEPS
    voice_idx = {v: i for i, v in enumerate(voices)}
    grid = np.zeros((len(voices), N_STEPS))
    for h in pattern.hits:
        if h.midi_note in voice_idx:
            step = int(round(h.timestamp / step_dur)) % N_STEPS
            grid[voice_idx[h.midi_note], step] = 1.0
    return grid


def build_heatmaps(all_runs: list, q_pattern: DrumPattern):
    all_voices = set(h.midi_note for h in q_pattern.hits)
    for run in all_runs:
        for var in run:
            all_voices.update(h.midi_note for h in var.hits)
    all_voices = sorted(all_voices, key=_voice_sort_key)

    input_grid    = pattern_to_grid(q_pattern, all_voices)
    slot_heatmaps = np.zeros((5, len(all_voices), N_STEPS))
    for run in all_runs:
        for slot_idx, var in enumerate(run):
            slot_heatmaps[slot_idx] += pattern_to_grid(var, all_voices)
    slot_heatmaps /= len(all_runs)
    return all_voices, input_grid, slot_heatmaps


# ── Plotting ──────────────────────────────────────────────────────────────────

def plot_slot(slot_idx: int, all_voices: list, input_grid: np.ndarray,
              slot_hm: np.ndarray, vmax: float, out_path: Path):
    active_mask = (input_grid.max(axis=1) > 0) | (slot_hm.max(axis=1) > 0)
    active_idx  = np.where(active_mask)[0]
    voices_here = [all_voices[i] for i in active_idx]
    grid_here   = slot_hm[active_idx]
    inp_here    = input_grid[active_idx]

    n_voices = len(voices_here)
    ylabels  = [DRUM_NAMES.get(v, f"Note {v}") for v in voices_here]

    fig_h = max(3.5, 1.0 + 0.45 * n_voices)
    fig, ax = plt.subplots(figsize=(11, fig_h))

    im = ax.imshow(grid_here, aspect='auto', vmin=0, vmax=vmax,
                   cmap='YlOrRd', interpolation='nearest')

    for vi in range(n_voices):
        for si in range(N_STEPS):
            if inp_here[vi, si] > 0:
                ax.plot(si, vi, 'o', color='white', markersize=7,
                        markeredgecolor='#1e293b', markeredgewidth=1.0,
                        alpha=0.95, zorder=5)

    for beat in [3.5, 7.5, 11.5]:
        ax.axvline(beat, color='#94a3b8', linewidth=0.8, linestyle='--',
                   alpha=0.7, zorder=3)

    ax.set_yticks(range(n_voices))
    ax.set_yticklabels(ylabels, fontsize=10)
    ax.set_xticks(range(N_STEPS))
    ax.set_xticklabels([str(i + 1) for i in range(N_STEPS)], fontsize=9)
    ax.set_xlabel("16th-note step", fontsize=10)

    cbar = fig.colorbar(im, ax=ax, pad=0.01, fraction=0.025)
    cbar.set_label("Hit probability", fontsize=9)
    cbar.ax.tick_params(labelsize=8)

    legend_handle = plt.Line2D(
        [0], [0], marker='o', color='w', markerfacecolor='white',
        markeredgecolor='#1e293b', markersize=7, markeredgewidth=1.0,
        label='Input Pattern',
    )
    ax.legend(handles=[legend_handle], fontsize=9, loc='upper right',
              framealpha=0.85, edgecolor='#cbd5e1')

    density = float(slot_hm.sum())
    ax.text(0.01, 0.02, f"avg hits/bar: {density:.1f}",
            transform=ax.transAxes, fontsize=8.5, color='#475569', va='bottom')

    spice_name, spice_val = SPICE_LABELS[slot_idx]
    ax.set_title(
        f"Var {slot_idx + 1} — {spice_name} Spice ({spice_val}) · Hit Probability",
        fontsize=11, fontweight='bold', pad=8,
    )

    plt.tight_layout()
    plt.savefig(out_path, dpi=220, bbox_inches='tight')
    plt.close(fig)
    print(f"  Saved → {out_path.name}")


# ── Stats ─────────────────────────────────────────────────────────────────────

def print_stats(all_voices, input_grid, slot_heatmaps):
    orig_mask = input_grid > 0
    non_orig  = ~orig_mask
    print(f"\n  {'Slot':<8} {'Avg density':>12} {'Orig-overlap':>14} {'New-cell prob':>14}")
    print(f"  {'-'*52}")
    for slot_idx in range(5):
        hm      = slot_heatmaps[slot_idx]
        density = hm.sum()
        overlap = hm[orig_mask].mean() if orig_mask.any() else 0.0
        new_act = hm[non_orig].mean() if non_orig.any() else 0.0
        tag     = "  ← least deviant" if slot_idx == 0 else ("  ← most deviant" if slot_idx == 4 else "")
        print(f"  Var {slot_idx+1:<4} {density:>12.2f}  {overlap:>14.2f}  {new_act:>14.2f}{tag}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Generate CHULOOPA variation banks + heatmap PNGs for one input pattern."
    )
    parser.add_argument("input", type=Path,
                        help="Path to a CHULOOPA track_0_drums.txt file")
    parser.add_argument("--runs", type=int, default=10,
                        help="Number of independent generation banks (default: 10)")
    parser.add_argument("--name", type=str, default=None,
                        help="Label used for output filenames/dirs (default: input filename stem)")
    args = parser.parse_args()

    txt_path = args.input.resolve()
    if not txt_path.exists():
        print(f"ERROR: File not found: {txt_path}")
        sys.exit(1)

    name    = args.name or txt_path.stem.replace(" ", "_")
    n_runs  = args.runs
    out_dir = REPO_ROOT / "eval_output" / name

    print(f"\nInput:  {txt_path}")
    print(f"Name:   {name}")
    print(f"Runs:   {n_runs}")
    print(f"Output: {out_dir}\n")

    print("Loading grid model...")
    if not init_grid_model():
        print(f"ERROR: Grid model failed to load.")
        print(f"  Expected: {SRC_DIR}/models/grid_barpair_best_epoch.pt")
        sys.exit(1)
    print("Grid model ready.\n")

    raw = load_txt(txt_path)
    q   = quantize_pattern(raw)
    print(f"Loaded:    {len(raw.hits)} hits, {raw.loop_duration:.3f}s loop")
    print(f"Quantized: {len(q.hits)} hits, voices={sorted(set(h.midi_note for h in q.hits))}\n")

    out_dir.mkdir(parents=True, exist_ok=True)
    all_runs = []
    for run_idx in range(n_runs):
        print(f"Run {run_idx + 1:2d}/{n_runs}...", end=" ", flush=True)
        bank = run_bank(q)
        all_runs.append(bank)

        run_dir = out_dir / f"run_{run_idx + 1:02d}"
        run_dir.mkdir(exist_ok=True)
        for slot_idx, var in enumerate(bank):
            var.to_file(str(run_dir / f"slot{slot_idx + 1}.txt"), normalize=False)

        print(f"hits/slot: {[len(var.hits) for var in bank]}")

    all_voices, input_grid, slot_heatmaps = build_heatmaps(all_runs, q)
    print_stats(all_voices, input_grid, slot_heatmaps)

    plt.rcParams.update({
        'font.family':       'sans-serif',
        'axes.spines.top':   False,
        'axes.spines.right': False,
    })

    vmax = float(slot_heatmaps.max()) or 1.0
    print("\nGenerating plots...")
    for slot_idx in range(5):
        out_path = REPO_ROOT / f"eval_heatmap_{name}_slot{slot_idx + 1}.png"
        plot_slot(slot_idx, all_voices, input_grid, slot_heatmaps[slot_idx], vmax, out_path)

    print("\nDone.")


if __name__ == "__main__":
    main()
