#!/usr/bin/env python3
"""
test_grid_model.py - Test the GPTBarPair grid model with a CHULOOPA drum recording.

Reads track_0_drums.txt, quantizes it to a 16th-note grid, generates a variation,
and writes both files so ChucK can switch between them seamlessly.

Usage (run from src/):
    python test_grid_model.py
    python test_grid_model.py --drums-file tracks/track_0/track_0_drums.txt
    python test_grid_model.py --temperature 0.8
    python test_grid_model.py --temperature 0.6 --top-k 10

Outputs:
    tracks/track_0/track_0_drums_quantized.txt        (quantized original)
    tracks/track_0/variations/track_0_drums_var_grid.txt  (generated variation)
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from format_converters import chuloopa_txt_to_grid_tokens, grid_tokens_to_chuloopa_txt
from models.rhythmic_creator_grid.grid_model import RhythmicCreatorGridModel

DEFAULT_DRUMS = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
DEFAULT_MODEL = Path(__file__).parent / "models" / "grid_barpair_best_epoch.pt"


def parse_loop_duration(filepath: Path) -> float:
    with open(filepath) as f:
        for line in f:
            if line.startswith("# Total loop duration:"):
                return float(line.split(":")[1].strip().split()[0])
    raise ValueError(f"No loop duration header in {filepath}")


def main():
    parser = argparse.ArgumentParser(description="Test GPTBarPair grid model with CHULOOPA drums")
    parser.add_argument("--drums-file", type=Path, default=DEFAULT_DRUMS,
                        help="Path to track_N_drums.txt (default: track_0_drums.txt)")
    parser.add_argument("--temperature", type=float, default=1.0,
                        help="Sampling temperature (default: 1.0)")
    parser.add_argument("--top-k", type=int, default=None,
                        help="Top-k sampling cutoff (default: None = unrestricted)")
    args = parser.parse_args()

    drums_file = args.drums_file
    if not drums_file.exists():
        print(f"ERROR: {drums_file} not found.")
        sys.exit(1)

    if not DEFAULT_MODEL.exists():
        print(f"ERROR: Model checkpoint not found at {DEFAULT_MODEL}")
        print("Run Task 1 to copy the checkpoint.")
        sys.exit(1)

    # ── BPM inference ──────────────────────────────────────────────────────────
    loop_duration = parse_loop_duration(drums_file)
    bpm = (60.0 * 4) / loop_duration
    step_duration = (60.0 / bpm) / 4.0

    print("=" * 60)
    print("CHULOOPA Grid Model Test")
    print("=" * 60)
    print(f"Input file:    {drums_file}")
    print(f"Loop duration: {loop_duration:.4f}s  (treated as 1 bar)")
    print(f"Inferred BPM:  {bpm:.1f}")
    print(f"Step duration: {step_duration * 1000:.1f}ms  (16th note)")
    print(f"Temperature:   {args.temperature}")
    print(f"Top-k:         {args.top_k}")
    print()

    # ── Convert to grid tokens ─────────────────────────────────────────────────
    context_tokens, _ = chuloopa_txt_to_grid_tokens(str(drums_file), bpm=bpm)

    print(f"Context ({len(context_tokens) // 2} hits):")
    print("  " + " ".join(context_tokens))
    print()

    # ── Load model and generate ────────────────────────────────────────────────
    print(f"Loading model from {DEFAULT_MODEL.name}...")
    model = RhythmicCreatorGridModel(str(DEFAULT_MODEL))
    print(f"Device: {model.device}")
    print()

    print("Generating variation...")
    variation_tokens = model.generate_variation(
        context_tokens,
        temperature=args.temperature,
        top_k=args.top_k,
    )

    print(f"Variation ({len(variation_tokens) // 2} hits):")
    print("  " + " ".join(variation_tokens))
    print()

    # ── Write output files ─────────────────────────────────────────────────────
    quantized_path = drums_file.parent / f"{drums_file.stem}_quantized.txt"
    grid_tokens_to_chuloopa_txt(
        context_tokens, bpm=bpm, loop_duration=loop_duration,
        output_filepath=str(quantized_path)
    )
    print(f"Wrote quantized original → {quantized_path}")

    variations_dir = drums_file.parent / "variations"
    variations_dir.mkdir(exist_ok=True)
    variation_path = variations_dir / f"{drums_file.stem}_var_grid.txt"
    grid_tokens_to_chuloopa_txt(
        variation_tokens, bpm=bpm, loop_duration=loop_duration,
        output_filepath=str(variation_path)
    )
    print(f"Wrote variation          → {variation_path}")
    print()

    # ── Side-by-side comparison ────────────────────────────────────────────────
    ctx_by_step = {}
    for i in range(0, len(context_tokens), 2):
        step = int(context_tokens[i][1:])
        pitch = int(context_tokens[i + 1][1:])
        ctx_by_step.setdefault(step, []).append(pitch)

    var_by_step = {}
    for i in range(0, len(variation_tokens), 2):
        step = int(variation_tokens[i][1:])
        pitch = int(variation_tokens[i + 1][1:])
        var_by_step.setdefault(step, []).append(pitch)

    all_steps = sorted(set(ctx_by_step) | set(var_by_step))

    print(f"{'Step':<6} {'Time (ms)':<12} {'Quantized original':<28} {'Generated variation'}")
    print("-" * 72)
    for step in all_steps:
        ts_ms = step * step_duration * 1000
        ctx_str = " ".join(f"N{p}" for p in sorted(ctx_by_step.get(step, []))) or "-"
        var_str = " ".join(f"N{p}" for p in sorted(var_by_step.get(step, []))) or "-"
        print(f"P{step:<5} {ts_ms:<12.1f} {ctx_str:<28} {var_str}")

    print()
    print("Done. Both files use the same loop duration — safe to switch in ChucK.")


if __name__ == "__main__":
    main()
