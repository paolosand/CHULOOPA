"""
Generate step-wise drum grid charts for CHULOOPA track folders.

Outputs two PNG files per track folder:
  - grid_all_stacked.png  : one panel per pattern, stacked vertically
                            Original / Var1 / Var2 / Var3 / Var4 / Var5
  - grid_pairs_stacked.png: 5 figures (2 panels each) — Original + VarN

Usage:
    python drum_grid_chart.py <path_to_track_folder>
"""

import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

DRUM_NAMES = {
    22: "HH Closed (Edge)",
    26: "HH Open (Edge)",
    36: "Kick",
    37: "X-Stick",
    38: "Snare",
    40: "Snare (Rim)",
    42: "Closed HH",
    43: "Floor Tom",
    44: "HH Pedal",
    45: "Low Tom",
    46: "Open HH",
    47: "Mid Tom (Rim)",
    48: "Hi Tom",
    49: "Crash",
    50: "Hi Tom (Rim)",
    51: "Ride",
    52: "Crash 2 (Edge)",
    53: "Ride (Bell)",
    55: "Crash (Edge)",
    57: "Crash 2",
    58: "Floor Tom (Rim)",
    59: "Ride (Edge)",
}
DRUM_ORDER = [36, 38, 42, 46, 22, 49, 51, 55]

N_STEPS = 16

ALL_COLORS = [
    "#C0392B",  # original — crimson
    "#E67E22",  # var 1    — orange
    "#27AE60",  # var 2    — green
    "#2980B9",  # var 3    — blue
    "#8E44AD",  # var 4    — purple
    "#16A085",  # var 5    — teal
]
ORIG_COLOR = "#C0392B"
PAIR_VAR_COLORS = ["#E67E22", "#2980B9", "#27AE60", "#8E44AD", "#16A085"]


# ── parse ─────────────────────────────────────────────────────────────────────

def parse_txt(path):
    loop_dur = None
    hits = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("# Total loop duration:"):
                loop_dur = float(line.split(":")[1].strip().split()[0])
            elif line and not line.startswith("#"):
                parts = line.split(",")
                if len(parts) == 4:
                    hits.append((int(parts[0]), float(parts[1]), float(parts[2])))
    return loop_dur, hits


def hits_to_steps(hits, loop_dur, n_steps=N_STEPS):
    step_dur = loop_dur / n_steps
    grid = {}
    for note, ts, vel in hits:
        step = min(round(ts / step_dur), n_steps - 1)
        grid[(note, step)] = max(grid.get((note, step), 0), vel)
    return grid


def drum_rows(all_patterns):
    """Ordered drum list across all patterns, standard GM order."""
    notes = set()
    for p in all_patterns:
        notes.update(n for n, _ in p.keys())
    ordered = [n for n in DRUM_ORDER if n in notes]
    extra = sorted(notes - set(DRUM_ORDER))
    return ordered + extra


def load_track_folder(folder):
    orig_path = os.path.join(folder, "track_0_drums.txt")
    var_dir = os.path.join(folder, "variations")
    loop_dur, orig_hits = parse_txt(orig_path)
    orig_steps = hits_to_steps(orig_hits, loop_dur)
    var_steps = []
    for i in range(1, 6):
        vp = os.path.join(var_dir, f"track_0_drums_var{i}.txt")
        if os.path.exists(vp):
            ld, vh = parse_txt(vp)
            var_steps.append(hits_to_steps(vh, ld))
        else:
            var_steps.append({})
    return orig_steps, var_steps


# ── single panel ──────────────────────────────────────────────────────────────

def draw_panel(ax, steps, color, drums, label, n_steps=N_STEPS,
               show_xlabel=False):
    n_drums = len(drums)

    # alternating bar background
    for col in range(n_steps):
        bg = "#F2F2F2" if (col // 4) % 2 == 0 else "#E6E6E6"
        ax.add_patch(mpatches.Rectangle(
            (col, 0), 1, n_drums, linewidth=0, facecolor=bg, zorder=0))

    # hit blocks
    for (note, step), vel in steps.items():
        if note not in drums:
            continue
        row = drums.index(note)
        alpha = 0.5 + 0.45 * vel
        ax.add_patch(mpatches.Rectangle(
            (step + 0.05, row + 0.08), 0.9, 0.84,
            linewidth=0, facecolor=color, alpha=alpha, zorder=1))

    # grid lines
    for col in range(n_steps + 1):
        lw = 1.5 if col % 4 == 0 else 0.4
        ax.axvline(col, color="black", linewidth=lw, zorder=2)
    for row in range(n_drums + 1):
        ax.axhline(row, color="#999999", linewidth=0.4, zorder=2)

    ax.set_xlim(0, n_steps)
    ax.set_ylim(0, n_drums)
    ax.set_yticks(np.arange(n_drums) + 0.5)
    ax.set_yticklabels([DRUM_NAMES.get(d, f"Note {d}") for d in drums],
                       fontsize=9)
    ax.tick_params(axis="both", length=0)

    if show_xlabel:
        ax.set_xticks(np.arange(n_steps) + 0.5)
        ax.set_xticklabels([str(i + 1) for i in range(n_steps)], fontsize=8)
    else:
        ax.set_xticks([])

    # pattern label on left spine
    ax.set_ylabel(label, fontsize=10, fontweight="bold",
                  rotation=0, labelpad=52, va="center")

    # coloured left border
    ax.spines["left"].set_color(color)
    ax.spines["left"].set_linewidth(4)
    for spine in ("top", "right", "bottom"):
        ax.spines[spine].set_visible(False)


# ── chart builders ────────────────────────────────────────────────────────────

def make_all_stacked(folder, out_path):
    orig_steps, var_steps = load_track_folder(folder)
    all_steps = [orig_steps] + var_steps
    labels = ["Original"] + [f"Var {i + 1}" for i in range(len(var_steps))]
    colors = ALL_COLORS[: len(all_steps)]
    drums = drum_rows(all_steps)
    n_panels = len(all_steps)
    panel_h = max(1.4, len(drums) * 0.55 + 0.5)

    fig, axes = plt.subplots(n_panels, 1,
                             figsize=(14, panel_h * n_panels + 0.6),
                             sharex=False)
    fig.patch.set_facecolor("white")

    for i, (ax, steps, color, label) in enumerate(
            zip(axes, all_steps, colors, labels)):
        draw_panel(ax, steps, color, drums, label,
                   show_xlabel=(i == n_panels - 1))

    fig.suptitle("All Variations — Stacked", fontsize=12,
                 fontweight="bold", y=1.01)
    fig.tight_layout(pad=0.8, h_pad=0.3)
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  -> {out_path}")


def draw_pair_panel(ax, orig_steps, var_steps, var_color, var_label, drums,
                    n_steps=N_STEPS, show_xlabel=False):
    """Single wide panel: original on left half, variation on right half."""
    n_drums = len(drums)
    total = n_steps * 2  # 32 columns

    # alternating bar background — each group of 4 within each half
    for col in range(total):
        half_col = col % n_steps
        bg = "#F2F2F2" if (half_col // 4) % 2 == 0 else "#E6E6E6"
        ax.add_patch(mpatches.Rectangle(
            (col, 0), 1, n_drums, linewidth=0, facecolor=bg, zorder=0))

    def _draw_hits(steps, color, offset):
        for (note, step), vel in steps.items():
            if note not in drums:
                continue
            row = drums.index(note)
            alpha = 0.5 + 0.45 * vel
            ax.add_patch(mpatches.Rectangle(
                (offset + step + 0.05, row + 0.08), 0.9, 0.84,
                linewidth=0, facecolor=color, alpha=alpha, zorder=1))

    _draw_hits(orig_steps, ORIG_COLOR, 0)
    _draw_hits(var_steps,  var_color,  n_steps)

    # grid lines
    for col in range(total + 1):
        if col == n_steps:
            lw, color = 2.5, "black"
        elif col % 4 == 0:
            lw, color = 1.2, "black"
        else:
            lw, color = 0.4, "black"
        ax.axvline(col, color=color, linewidth=lw, zorder=2)
    for row in range(n_drums + 1):
        ax.axhline(row, color="#999999", linewidth=0.4, zorder=2)

    ax.set_xlim(0, total)
    ax.set_ylim(0, n_drums)
    ax.set_yticks(np.arange(n_drums) + 0.5)
    ax.set_yticklabels([DRUM_NAMES.get(d, f"Note {d}") for d in drums],
                       fontsize=12)
    ax.tick_params(axis="both", length=0)

    if show_xlabel:
        ticks = list(range(n_steps)) + list(range(n_steps))
        positions = [i + 0.5 for i in range(total)]
        ax.set_xticks(positions)
        ax.set_xticklabels([str(t + 1) for t in ticks], fontsize=10)
    else:
        ax.set_xticks([])

    # half labels as text inside the panel
    ax.text(n_steps * 0.5, n_drums + 0.2, "Original",
            ha="center", va="bottom", fontsize=18, fontweight="bold",
            color=ORIG_COLOR, transform=ax.transData, clip_on=False)
    ax.text(n_steps * 1.5, n_drums + 0.2, var_label,
            ha="center", va="bottom", fontsize=18, fontweight="bold",
            color=var_color, transform=ax.transData, clip_on=False)

    # coloured left border using two-segment line (orig + var)
    ax.spines["left"].set_color(ORIG_COLOR)
    ax.spines["left"].set_linewidth(4)
    for spine in ("top", "right", "bottom"):
        ax.spines[spine].set_visible(False)


def make_pairs_stacked(folder, out_path):
    orig_steps, var_steps = load_track_folder(folder)
    all_steps = [orig_steps] + var_steps
    drums = drum_rows(all_steps)
    n_vars = len([v for v in var_steps if v])
    panel_h = max(2.2, len(drums) * 0.75 + 1.2)

    fig, axes = plt.subplots(n_vars, 1,
                             figsize=(14, panel_h * n_vars + 0.8),
                             sharex=False)
    if n_vars == 1:
        axes = [axes]
    fig.patch.set_facecolor("white")

    for i, (ax, vsteps) in enumerate(zip(axes, var_steps[:n_vars])):
        draw_pair_panel(ax, orig_steps, vsteps, PAIR_VAR_COLORS[i],
                        f"Var {i + 1}", drums,
                        show_xlabel=(i == n_vars - 1))

    fig.suptitle("Original vs Each Variation — Side-by-Side Pairs",
                 fontsize=12, fontweight="bold", y=1.01)
    fig.tight_layout(pad=0.8, h_pad=1.2)
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  -> {out_path}")


def make_135_chart(folder, out_path):
    """3-pair chart: Original vs Var 1 (Low), Var 3 (Mid), Var 5 (High Spice)."""
    orig_steps, var_steps = load_track_folder(folder)
    all_steps = [orig_steps] + var_steps
    drums = drum_rows(all_steps)
    panel_h = max(2.2, len(drums) * 0.75 + 1.2)

    pairs = [
        (var_steps[0], PAIR_VAR_COLORS[0], "Var 1  (Low Spice)"),
        (var_steps[2], PAIR_VAR_COLORS[2], "Var 3  (Medium Spice)"),
        (var_steps[4], PAIR_VAR_COLORS[4], "Var 5  (High Spice)"),
    ]

    fig, axes = plt.subplots(3, 1, figsize=(14, panel_h * 3 + 0.8), sharex=False)
    fig.patch.set_facecolor("white")

    for i, (ax, (vsteps, color, label)) in enumerate(zip(axes, pairs)):
        draw_pair_panel(ax, orig_steps, vsteps, color, label, drums,
                        show_xlabel=(i == 2))

    fig.suptitle("Original vs Variation — Spice Low / Mid / High",
                 fontsize=12, fontweight="bold", y=1.01)
    fig.tight_layout(pad=0.8, h_pad=1.2)
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  -> {out_path}")


# ── entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python drum_grid_chart.py <track_folder>")
        sys.exit(1)

    folder = sys.argv[1]
    if os.path.isdir(os.path.join(folder, "track_0")):
        folder = os.path.join(folder, "track_0")

    print(f"Generating charts for: {folder}")
    make_all_stacked(folder, os.path.join(folder, "grid_all_stacked.png"))
    make_pairs_stacked(folder, os.path.join(folder, "grid_pairs_stacked.png"))
    make_135_chart(folder, os.path.join(folder, "grid_pairs_135.png"))
    print("Done.")
