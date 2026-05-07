"""
Generate a 3-pair grid chart showing Original vs Var 1, 3, and 5 only.

Usage:
    python drum_grid_chart_135.py <path_to_track_folder>
"""

import sys
import os

# Import shared helpers from drum_grid_chart
sys.path.insert(0, os.path.dirname(__file__))
from drum_grid_chart import (
    load_track_folder, drum_rows, draw_pair_panel,
    PAIR_VAR_COLORS,
)

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


SUBSET = [0, 2, 4]   # Var 1, Var 3, Var 5 (0-indexed)
LABELS = ["Var 1  (Low Spice)", "Var 3  (Medium Spice)", "Var 5  (High Spice)"]


def make_pairs_135(folder, out_path):
    orig_steps, var_steps = load_track_folder(folder)
    all_steps = [orig_steps] + var_steps
    drums = drum_rows(all_steps)

    panel_h = max(1.6, len(drums) * 0.6 + 0.8)
    n_panels = len(SUBSET)

    fig, axes = plt.subplots(n_panels, 1,
                             figsize=(14, panel_h * n_panels + 0.8),
                             sharex=False)
    if n_panels == 1:
        axes = [axes]
    fig.patch.set_facecolor("white")

    for plot_idx, (ax, var_idx) in enumerate(zip(axes, SUBSET)):
        vsteps = var_steps[var_idx] if var_idx < len(var_steps) else {}
        draw_pair_panel(
            ax, orig_steps, vsteps,
            PAIR_VAR_COLORS[var_idx],
            LABELS[plot_idx],
            drums,
            show_xlabel=(plot_idx == n_panels - 1),
        )

    fig.suptitle("Original vs Variation — Spice Low / Mid / High",
                 fontsize=12, fontweight="bold", y=1.01)
    fig.tight_layout(pad=0.8, h_pad=1.2)
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  -> {out_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python drum_grid_chart_135.py <track_folder>")
        sys.exit(1)

    folder = sys.argv[1]
    if os.path.isdir(os.path.join(folder, "track_0")):
        folder = os.path.join(folder, "track_0")

    out = os.path.join(folder, "grid_pairs_135.png")
    print(f"Generating 3-pair chart for: {folder}")
    make_pairs_135(folder, out)
    print("Done.")
