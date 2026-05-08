#!/usr/bin/env python3
"""
eval_heatmap.py — CHULOOPA paper evaluation: variation coherence heatmap

For each test MIDI:
  1. Convert to DrumPattern (quantized 16-step grid)
  2. Run N_RUNS independent variation banks via the grid model
  3. Each bank: generate at 5 spice levels (0.2–1.0), sort by deviation score
  4. Build per-slot hit-probability heatmaps (N_RUNS observations per cell)
  5. Save figures + raw txt outputs

The hypothesis: original hit positions should be the darkest cells across all
5 slots, showing the model is anchored to the input rather than generating
randomly. Higher slots should additionally activate new positions.

Usage (from CHULOOPA/ root):
    cd "Code/CHULOOPA"
    python eval_heatmap.py

Outputs:
    eval_output/test1/run_01/slot1.txt … slot5.txt
    eval_output/test2/run_01/slot1.txt … slot5.txt
    eval_heatmap_test1.png
    eval_heatmap_test2.png
    eval_heatmap_combined.png
"""

import sys
import json
from pathlib import Path

# ── Path setup: add src/ so we can import the generator modules ───────────────
REPO_ROOT = Path(__file__).parent
SRC_DIR   = REPO_ROOT / "src"
sys.path.insert(0, str(SRC_DIR))

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

from drum_variation_generator import (
    DrumHit, DrumPattern,
    grid_model_variation, init_grid_model,
    compute_deviation_score,
)
from format_converters import quantize_to_steps

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

N_RUNS       = 10
N_STEPS      = 16
SPICE_LEVELS = [0.2, 0.4, 0.6, 0.8, 1.0]

EVALS_DIR = Path("/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/CHULOOPA_EVALS")
TEST_TXTS = {
    "test1": EVALS_DIR / "TEST 1 - track_0_drums.txt",
    "test2": EVALS_DIR / "TEST 2 - track_0_drums.txt",
}
TEST_LABELS = {
    "test1": "Test 1: Simple kick–snare groove",
    "test2": "Test 2: More complex groove",
}

OUT_DIR = REPO_ROOT / "eval_output"

# GM drum name map (expand as needed)
DRUM_NAMES = {
    35: "Kick 2",  36: "Kick",
    37: "Rim",     38: "Snare",  39: "Clap",  40: "El.Snare",
    41: "Lo Tom",  43: "Mid Tom", 45: "Hi Tom",
    42: "Cl.HH",   44: "Ped.HH", 46: "Op.HH",
    49: "Crash",   51: "Ride",   55: "Splash",
}


# ─────────────────────────────────────────────────────────────────────────────
# MIDI → CHULOOPA DrumPattern
# ─────────────────────────────────────────────────────────────────────────────

def txt_to_drum_pattern(txt_path: Path) -> DrumPattern:
    """
    Load a CHULOOPA track_0_drums.txt file directly into a DrumPattern.
    """
    loop_duration = None
    hits = []
    with open(txt_path) as f:
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

    if not hits:
        raise ValueError(f"No hits found in {txt_path}")
    if loop_duration is None:
        loop_duration = hits[-1].timestamp + hits[-1].delta_time

    pattern = DrumPattern(hits=hits, loop_duration=loop_duration,
                          source_file=str(txt_path))
    return pattern


def quantize_pattern(pattern: DrumPattern) -> DrumPattern:
    """
    Snap pattern to the 16-step grid — exactly what grid_model_variation does
    internally before encoding.  We use this for the 'Input' row of the figure
    so it reflects what the model actually saw.
    """
    loop_duration = pattern.loop_duration
    step_duration = loop_duration / N_STEPS
    raw_hits = [(h.timestamp, h.midi_note) for h in pattern.hits]
    events   = quantize_to_steps(raw_hits, loop_duration)

    q_hits = []
    for step, pitch in events:
        q_hits.append(DrumHit(
            midi_note=pitch,
            timestamp=step * step_duration,
            velocity=0.75,
            delta_time=0.0,
        ))

    q_pattern = DrumPattern(hits=q_hits, loop_duration=loop_duration,
                            source_file=pattern.source_file)
    q_pattern._recalculate_delta_times()
    return q_pattern


# ─────────────────────────────────────────────────────────────────────────────
# BANK GENERATION
# ─────────────────────────────────────────────────────────────────────────────

def run_bank(pattern: DrumPattern) -> list:
    """
    Generate one complete 5-slot variation bank from pattern.
    Each slot is generated at a different spice level (temperature),
    then the five outputs are sorted ascending by deviation score
    so slot 0 = least deviant, slot 4 = most deviant.

    Returns list of 5 DrumPatterns.
    """
    variations = []
    for spice in SPICE_LEVELS:
        var, _success = grid_model_variation(pattern, spice_level=spice)
        variations.append(var)

    scored = [(compute_deviation_score(var, pattern), var) for var in variations]
    scored.sort(key=lambda x: x[0])
    return [var for _, var in scored]


# ─────────────────────────────────────────────────────────────────────────────
# HEATMAP CONSTRUCTION
# ─────────────────────────────────────────────────────────────────────────────

def pattern_to_grid(pattern: DrumPattern, all_voices: list) -> np.ndarray:
    """
    Convert a DrumPattern to a binary (voices × steps) array.
    Timestamps are snapped to the nearest of N_STEPS sixteenth-note positions.
    """
    step_dur = pattern.loop_duration / N_STEPS
    grid = np.zeros((len(all_voices), N_STEPS), dtype=float)
    voice_idx = {v: i for i, v in enumerate(all_voices)}
    for hit in pattern.hits:
        if hit.midi_note in voice_idx:
            step = int(round(hit.timestamp / step_dur)) % N_STEPS
            grid[voice_idx[hit.midi_note], step] = 1.0
    return grid


def build_heatmaps(all_runs: list, q_pattern: DrumPattern) -> tuple:
    """
    Aggregate N_RUNS banks into per-slot hit-probability heatmaps.

    Args:
        all_runs:  list of N_RUNS lists, each containing 5 sorted DrumPatterns
        q_pattern: quantized input pattern (used for input grid + voice list)

    Returns:
        all_voices:    sorted list of MIDI note numbers present across input + all variations
        input_grid:    (voices × steps) binary array of quantized input
        slot_heatmaps: (5 × voices × steps) float array of hit probabilities
    """
    all_voices = set(h.midi_note for h in q_pattern.hits)
    for run in all_runs:
        for var in run:
            all_voices.update(h.midi_note for h in var.hits)
    all_voices = sorted(all_voices)

    input_grid    = pattern_to_grid(q_pattern, all_voices)
    slot_heatmaps = np.zeros((5, len(all_voices), N_STEPS))

    for run in all_runs:
        for slot_idx, var in enumerate(run):
            slot_heatmaps[slot_idx] += pattern_to_grid(var, all_voices)

    slot_heatmaps /= len(all_runs)
    return all_voices, input_grid, slot_heatmaps


# ─────────────────────────────────────────────────────────────────────────────
# FIGURE
# ─────────────────────────────────────────────────────────────────────────────

SLOT_LABELS = [
    "Slot 1 — least deviant",
    "Slot 2",
    "Slot 3",
    "Slot 4",
    "Slot 5 — most deviant",
]


def _draw_panel(ax, grid: np.ndarray, voice_labels: list,
                title: str, cmap: str, vmax: float,
                input_grid: np.ndarray = None, is_input: bool = False):
    """Draw a single heatmap panel."""
    n_voices, n_steps = grid.shape

    if is_input:
        im = ax.imshow(grid, aspect='auto', vmin=0, vmax=1,
                       cmap='Blues', interpolation='nearest')
        ax.set_facecolor('#f8f9fa')
    else:
        im = ax.imshow(grid, aspect='auto', vmin=0, vmax=vmax,
                       cmap=cmap, interpolation='nearest')
        # Mark original input positions with white circles
        if input_grid is not None:
            for vi in range(n_voices):
                for si in range(n_steps):
                    if input_grid[vi, si] > 0:
                        ax.plot(si, vi, 'o', color='white',
                                markersize=5, markeredgecolor='#334155',
                                markeredgewidth=0.8, alpha=0.9, zorder=4)

    ax.set_yticks(range(n_voices))
    ax.set_yticklabels(voice_labels, fontsize=7)
    ax.set_title(title, fontsize=8, fontweight='bold', pad=3)
    ax.set_xlim(-0.5, n_steps - 0.5)

    # Light vertical grid lines at every 4th step (beat boundaries)
    for beat in [4, 8, 12]:
        ax.axvline(beat - 0.5, color='white', linewidth=1.0, alpha=0.6, zorder=3)

    return im


def plot_single(test_name: str, test_label: str,
                all_voices: list, input_grid: np.ndarray,
                slot_heatmaps: np.ndarray, out_path: Path,
                n_runs: int):
    """Generate the 6-panel stacked heatmap figure for one test pattern."""
    voice_labels = [DRUM_NAMES.get(v, f"Note {v}") for v in all_voices]
    n_voices     = len(all_voices)

    fig, axes = plt.subplots(
        6, 1,
        figsize=(9, 1.0 + 1.1 * 6),
        gridspec_kw={'hspace': 0.55},
    )

    # Input panel
    _draw_panel(axes[0], input_grid, voice_labels,
                title="Input (quantized to 16-step grid)",
                cmap='Blues', vmax=1.0, is_input=True)

    # Slot panels
    vmax = float(slot_heatmaps.max()) or 1.0
    last_im = None
    for slot_idx in range(5):
        last_im = _draw_panel(
            axes[slot_idx + 1],
            slot_heatmaps[slot_idx],
            voice_labels,
            title=SLOT_LABELS[slot_idx],
            cmap='YlOrRd', vmax=vmax,
            input_grid=input_grid,
        )

    # X-axis ticks on bottom panel only
    axes[-1].set_xticks(range(N_STEPS))
    axes[-1].set_xticklabels([str(i + 1) for i in range(N_STEPS)], fontsize=7)
    axes[-1].set_xlabel("16th-note step", fontsize=8)
    for ax in axes[:-1]:
        ax.tick_params(labelbottom=False)

    # Shared colorbar for slot panels
    cbar = fig.colorbar(last_im, ax=axes[1:], shrink=0.6, pad=0.02)
    cbar.set_label("Hit probability", fontsize=8)
    cbar.ax.tick_params(labelsize=7)

    # Legend for input markers
    marker_handle = plt.Line2D([0], [0], marker='o', color='w',
                                markerfacecolor='white', markeredgecolor='#334155',
                                markersize=5, markeredgewidth=0.8,
                                label='Input position')
    axes[1].legend(handles=[marker_handle], fontsize=7, loc='upper right',
                   framealpha=0.8)

    fig.suptitle(
        f"{test_label}\n"
        f"Hit-probability heatmap over {n_runs} independent variation banks  "
        f"(white circles = input positions)",
        fontsize=9, y=1.01,
    )

    plt.savefig(out_path, dpi=200, bbox_inches='tight')
    plt.close(fig)
    print(f"  Saved → {out_path}")


def plot_combined(results: dict, out_path: Path, n_runs: int):
    """
    Two-pattern combined figure (double-column, paper-ready).
    Layout: 2 columns (test1, test2) × 6 rows (Input + Slot1-5).
    """
    test_keys    = list(results.keys())
    n_cols       = len(test_keys)
    voice_sets   = [results[k]['all_voices'] for k in test_keys]
    all_voices_u = sorted(set(v for vs in voice_sets for v in vs))
    voice_labels = [DRUM_NAMES.get(v, f"Note {v}") for v in all_voices_u]

    def pad_grid(grid, all_voices_src, all_voices_dst):
        """Pad a (len_src × steps) grid to (len_dst × steps) preserving voice order."""
        dst = np.zeros((len(all_voices_dst), N_STEPS))
        for vi_src, v in enumerate(all_voices_src):
            vi_dst = all_voices_dst.index(v)
            dst[vi_dst] = grid[vi_src]
        return dst

    fig, axes = plt.subplots(
        6, n_cols,
        figsize=(5.5 * n_cols, 1.0 + 1.1 * 6),
        gridspec_kw={'hspace': 0.55, 'wspace': 0.35},
    )

    for col, key in enumerate(test_keys):
        r          = results[key]
        av         = r['all_voices']
        inp_g      = pad_grid(r['input_grid'],    av, all_voices_u)
        slot_hm    = np.stack([pad_grid(r['slot_heatmaps'][s], av, all_voices_u) for s in range(5)])
        test_label = TEST_LABELS[key]
        vmax       = float(slot_hm.max()) or 1.0

        ax = axes[0, col]
        _draw_panel(ax, inp_g, voice_labels,
                    title=f"{test_label}\nInput",
                    cmap='Blues', vmax=1.0, is_input=True)

        last_im = None
        for slot_idx in range(5):
            ax = axes[slot_idx + 1, col]
            last_im = _draw_panel(
                ax, slot_hm[slot_idx], voice_labels,
                title=SLOT_LABELS[slot_idx],
                cmap='YlOrRd', vmax=vmax,
                input_grid=inp_g,
            )

        # X ticks on bottom row
        axes[-1, col].set_xticks(range(N_STEPS))
        axes[-1, col].set_xticklabels(
            [str(i + 1) for i in range(N_STEPS)], fontsize=6)
        axes[-1, col].set_xlabel("16th-note step", fontsize=7)
        for row in range(5):
            axes[row, col].tick_params(labelbottom=False)

    # Single colorbar on the right
    cbar = fig.colorbar(last_im, ax=axes[:, -1], shrink=0.5, pad=0.04)
    cbar.set_label("Hit probability", fontsize=8)
    cbar.ax.tick_params(labelsize=7)

    marker_handle = plt.Line2D([0], [0], marker='o', color='w',
                                markerfacecolor='white', markeredgecolor='#334155',
                                markersize=5, markeredgewidth=0.8,
                                label='Input position')
    axes[1, 0].legend(handles=[marker_handle], fontsize=7, loc='upper right',
                      framealpha=0.8)

    fig.suptitle(
        f"CHULOOPA: Variation cohesion heatmaps  "
        f"(N={n_runs} independent banks per pattern)\n"
        "White circles = input positions. "
        "Slot 1 = least deviant, Slot 5 = most deviant.",
        fontsize=9, y=1.01,
    )

    plt.savefig(out_path, dpi=200, bbox_inches='tight')
    plt.close(fig)
    print(f"  Saved → {out_path}")


# ─────────────────────────────────────────────────────────────────────────────
# STATISTICS REPORT
# ─────────────────────────────────────────────────────────────────────────────

def print_stats(test_name: str, all_voices: list, input_grid: np.ndarray,
                slot_heatmaps: np.ndarray):
    print(f"\n  [{test_name}] Heatmap statistics:")
    print(f"  {'Slot':<8} {'Avg density':>12} {'Orig-overlap':>14} {'New-cell prob':>14}")
    print(f"  {'-'*52}")
    orig_mask = input_grid > 0
    non_orig  = ~orig_mask

    for slot_idx in range(5):
        hm      = slot_heatmaps[slot_idx]
        density = hm.sum()
        overlap = hm[orig_mask].mean() if orig_mask.any() else 0.0
        new_act = hm[non_orig].mean() if non_orig.any() else 0.0
        label   = "least deviant" if slot_idx == 0 else ("most deviant" if slot_idx == 4 else "")
        print(f"  Slot {slot_idx+1:<3}  {density:>12.2f}  {overlap:>14.2f}  {new_act:>14.2f}  {label}")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  CHULOOPA Variation Heatmap Evaluation")
    print(f"  N_RUNS={N_RUNS}  N_STEPS={N_STEPS}")
    print("=" * 60)

    # Load grid model once
    print("\nLoading grid model...")
    if not init_grid_model():
        print("ERROR: Grid model failed to load.")
        print(f"  Expected checkpoint at: {SRC_DIR}/models/grid_barpair_best_epoch.pt")
        sys.exit(1)
    print("Grid model ready.\n")

    results = {}

    for test_name, txt_path in TEST_TXTS.items():
        print(f"\n{'─'*50}")
        print(f"  Pattern: {test_name}  ({txt_path.name})")
        print(f"{'─'*50}")

        # Load and quantize input
        raw_pattern = txt_to_drum_pattern(txt_path)
        q_pattern   = quantize_pattern(raw_pattern)
        q_voices    = sorted(set(h.midi_note for h in q_pattern.hits))
        print(f"  Raw:       {len(raw_pattern.hits)} hits, {raw_pattern.loop_duration:.3f}s")
        print(f"  Quantized: {len(q_pattern.hits)} hits, voices={q_voices}")

        # Output directory
        test_out_dir = OUT_DIR / test_name
        test_out_dir.mkdir(parents=True, exist_ok=True)

        # Run N banks
        all_runs = []
        for run_idx in range(N_RUNS):
            print(f"  Run {run_idx + 1:2d}/{N_RUNS}...", end=" ", flush=True)
            bank     = run_bank(q_pattern)
            all_runs.append(bank)

            # Save txt for each slot
            run_dir = test_out_dir / f"run_{run_idx + 1:02d}"
            run_dir.mkdir(exist_ok=True)
            for slot_idx, var in enumerate(bank):
                var.to_file(str(run_dir / f"slot{slot_idx + 1}.txt"), normalize=False)

            hits_per_slot = [len(var.hits) for var in bank]
            print(f"hits/slot: {hits_per_slot}")

        # Build heatmaps
        all_voices, input_grid, slot_heatmaps = build_heatmaps(all_runs, q_pattern)
        print_stats(test_name, all_voices, input_grid, slot_heatmaps)

        results[test_name] = {
            'all_voices':    all_voices,
            'input_grid':    input_grid,
            'slot_heatmaps': slot_heatmaps,
        }

        # Per-pattern figure
        out_path = REPO_ROOT / f"eval_heatmap_{test_name}.png"
        plot_single(test_name, TEST_LABELS[test_name],
                    all_voices, input_grid, slot_heatmaps,
                    out_path, n_runs=N_RUNS)

    # Combined figure (both patterns side by side)
    if len(results) == 2:
        combined_path = REPO_ROOT / "eval_heatmap_combined.png"
        plot_combined(results, combined_path, n_runs=N_RUNS)

    # Save stats as JSON for the paper
    stats_path = REPO_ROOT / "eval_heatmap_stats.json"
    stats = {}
    for test_name, r in results.items():
        av    = r['all_voices']
        ig    = r['input_grid']
        shm   = r['slot_heatmaps']
        orig_mask = ig > 0
        non_orig  = ~orig_mask
        stats[test_name] = {
            "voices": av,
            "slots": [
                {
                    "slot": slot_idx + 1,
                    "avg_density":   float(shm[slot_idx].sum()),
                    "orig_overlap":  float(shm[slot_idx][orig_mask].mean()) if orig_mask.any() else 0.0,
                    "new_cell_prob": float(shm[slot_idx][non_orig].mean()) if non_orig.any() else 0.0,
                }
                for slot_idx in range(5)
            ]
        }
    with open(stats_path, 'w') as f:
        json.dump(stats, f, indent=2)
    print(f"\n  Stats → {stats_path}")

    print(f"\n{'='*60}")
    print("  Done.")
    print(f"{'='*60}")


if __name__ == '__main__':
    main()
