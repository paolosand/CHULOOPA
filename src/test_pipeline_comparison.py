#!/usr/bin/env python3
"""
test_pipeline_comparison.py - Isolate and compare rhythmic creator pipelines

Runs three pipeline variants on the same beatbox input and outputs MIDI files
for listening in Ableton, plus diagnostic data showing where pipelines diverge.

Pipeline A - "Jake Reference" (gold standard):
    DrumPattern → temp MIDI → read back via Jake's extract.py logic →
    model.generate() → MIDI output

Pipeline B - "CHULOOPA Native" (current path):
    DrumPattern → chuloopa_to_rhythmic_creator() →
    RhythmicCreatorModel.generate_variation(temperature=1.0) → MIDI output

Pipeline C - "CHULOOPA + model.generate" (isolates generation function):
    Same context as Pipeline B, but calls model.generate() directly → MIDI output

Usage:
    cd src
    python test_pipeline_comparison.py \\
        --input tracks/track_0/track_0_drums.txt \\
        --output-dir tracks/track_0/comparison_test/ \\
        --num-generations 5 \\
        [--seed 42]
"""

import argparse
import sys
import os
import tempfile
from pathlib import Path
from typing import List, Tuple, Optional

import torch
import torch.nn.functional as F
import pretty_midi

# Ensure src is on path
sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern, DrumHit
from format_converters import chuloopa_to_rhythmic_creator, CHULOOPA_TO_MIDI
from rhythmic_creator_model import RhythmicCreatorModel
from preprocess.preprocessing import MIDIProcessor
from models.rhythmic_creator.lstm_integration import LSTMDecoderModel


# ─────────────────────────────────────────────────────────────────────────────
# Paths (resolved relative to this file's location)
# ─────────────────────────────────────────────────────────────────────────────

SRC_DIR = Path(__file__).parent
MODEL_PATH = SRC_DIR / "models" / "transformer_LSTM_FNN_hybrid.pt"
VOCAB_PATH = SRC_DIR / "models" / "training_1.txt"

# Spice levels: (name, token_multiplier)
# num_tokens = len(context_tokens) * multiplier
SPICE_LEVELS = [("low", 1), ("medium", 3), ("high", 6)]


# ─────────────────────────────────────────────────────────────────────────────
# MIDI helpers (inlined from Jake's utils/generate.py)
# ─────────────────────────────────────────────────────────────────────────────

def save_midi(triplets: List[List[str]], output_path: str):
    """
    Save decoded rhythmic_creator triplets as a MIDI file.
    Inlined from Jake's utils/generate.py:gen().
    triplets: list of [pitch_str, start_str, end_str]
    """
    pm = pretty_midi.PrettyMIDI(initial_tempo=120.0)
    program = pretty_midi.instrument_name_to_program('cello')
    instrument = pretty_midi.Instrument(program=program)

    for triplet in triplets:
        if len(triplet) < 3:
            continue
        try:
            pitch = int(triplet[0])
            start = float(triplet[1])
            end = float(triplet[2])
            note = pretty_midi.Note(velocity=100, pitch=pitch, start=start, end=end)
            instrument.notes.append(note)
        except (ValueError, IndexError):
            continue

    pm.instruments.append(instrument)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    pm.write(output_path)


def decode_to_triplets(decoded_text: str) -> List[List[str]]:
    """Split decoded text into list of [pitch, start, end] triplets."""
    tokens = decoded_text.split()
    triplets = []
    for i in range(0, len(tokens) - 2, 3):
        triplets.append([tokens[i], tokens[i + 1], tokens[i + 2]])
    return triplets


# ─────────────────────────────────────────────────────────────────────────────
# Pipeline A helpers — Jake's context extraction via MIDI roundtrip
# ─────────────────────────────────────────────────────────────────────────────

def pattern_to_midi_bytes(pattern: DrumPattern) -> bytes:
    """
    Convert DrumPattern to a temporary MIDI file and return its bytes.
    This is the first half of Jake's pipeline: he passes a MIDI file as input.
    """
    pm = pretty_midi.PrettyMIDI(initial_tempo=120.0)
    program = pretty_midi.instrument_name_to_program('cello')
    instrument = pretty_midi.Instrument(program=program)

    for hit in pattern.hits:
        midi_note = CHULOOPA_TO_MIDI.get(hit.drum_class, 36)
        start = hit.timestamp
        end = start + 0.1  # short duration, same as chuloopa_to_rhythmic_creator
        note = pretty_midi.Note(velocity=100, pitch=midi_note, start=start, end=end)
        instrument.notes.append(note)

    pm.instruments.append(instrument)

    with tempfile.NamedTemporaryFile(suffix='.mid', delete=False) as f:
        pm.write(f.name)
        with open(f.name, 'rb') as rf:
            data = rf.read()
        os.unlink(f.name)
    return data


def extract_jake_context(pattern: DrumPattern, processor: MIDIProcessor, device: str) -> Tuple[torch.Tensor, List[str]]:
    """
    Jake's context extraction: DrumPattern → temp MIDI → read back → tokenize.
    Mirrors Extract.extract_drum_pattern() from rhythmic_creator/utils/extract.py.

    Key: Jake uses str(round(note.start, 2)) — NOT f"{ts:.2f}".rstrip('0')
    """
    # Write to temp MIDI
    pm_out = pretty_midi.PrettyMIDI(initial_tempo=120.0)
    program = pretty_midi.instrument_name_to_program('cello')
    instrument = pretty_midi.Instrument(program=program)

    for hit in pattern.hits:
        midi_note = CHULOOPA_TO_MIDI.get(hit.drum_class, 36)
        start = hit.timestamp
        end = start + 0.1
        note = pretty_midi.Note(velocity=100, pitch=midi_note, start=start, end=end)
        instrument.notes.append(note)

    pm_out.instruments.append(instrument)

    with tempfile.NamedTemporaryFile(suffix='.mid', delete=False) as f:
        tmp_path = f.name

    try:
        pm_out.write(tmp_path)

        # Read back — exactly like Jake's Extract.extract_drum_pattern()
        dat = pretty_midi.PrettyMIDI(tmp_path)
        flat_list = []
        for instr in dat.instruments:
            for note in instr.notes:
                flat_list.append(str(int(note.pitch)))
                flat_list.append(str(round(note.start, 2)))
                flat_list.append(str(round(note.end, 2)))
    finally:
        os.unlink(tmp_path)

    # Encode
    context_tensor = torch.tensor(
        processor.encode_with_mapping(flat_list),
        dtype=torch.long,
        device=device
    )
    context = context_tensor.reshape(1, len(flat_list))
    return context, flat_list


# ─────────────────────────────────────────────────────────────────────────────
# Pipeline B helpers — CHULOOPA's native context preparation
# ─────────────────────────────────────────────────────────────────────────────

def extract_chuloopa_context(pattern: DrumPattern, processor: MIDIProcessor, device: str) -> Tuple[torch.Tensor, List[str]]:
    """
    CHULOOPA's context extraction: chuloopa_to_rhythmic_creator() → tokenize.
    Uses f"{ts:.2f}".rstrip('0') formatting.
    """
    context_text = chuloopa_to_rhythmic_creator(pattern)
    tokens = context_text.split()

    encoded = processor.encode_with_mapping(tokens)
    context_tensor = torch.tensor([encoded], dtype=torch.long, device=device)
    return context_tensor, tokens


# ─────────────────────────────────────────────────────────────────────────────
# Generation wrappers
# ─────────────────────────────────────────────────────────────────────────────

def generate_jake_style(model: LSTMDecoderModel, device: str,
                        context: torch.Tensor, num_tokens: int,
                        processor: MIDIProcessor) -> str:
    """Generate using Jake's original model.generate() — no temperature wrapper."""
    hidden = model.init_hidden(batch_size=1, device=device)
    with torch.no_grad():
        generated = model.generate(device, context, hidden, max_new_tokens=num_tokens)
    decoded = processor.decode_with_mapping(generated[0].tolist())
    return decoded


def generate_with_temperature(model_wrapper: RhythmicCreatorModel,
                               context: torch.Tensor, num_tokens: int,
                               temperature: float) -> str:
    """Generate using CHULOOPA's _generate_with_temperature wrapper."""
    hidden = model_wrapper.model.init_hidden(batch_size=1, device=model_wrapper.device)
    with torch.no_grad():
        generated = model_wrapper._generate_with_temperature(
            context, hidden, num_tokens, temperature
        )
    decoded = model_wrapper.processor.decode_with_mapping(generated[0].tolist())
    return decoded


# ─────────────────────────────────────────────────────────────────────────────
# Diagnostics
# ─────────────────────────────────────────────────────────────────────────────

def check_vocab_coverage(tokens: List[str], processor: MIDIProcessor) -> List[str]:
    """Return list of tokens not in vocabulary."""
    vocab_set = set(processor.unique_notes)
    return [t for t in tokens if t not in vocab_set]


def analyze_generation(decoded: str, loop_duration: float) -> dict:
    """Compute per-generation statistics from decoded output."""
    tokens = decoded.split()
    triplets = [(tokens[i], tokens[i+1], tokens[i+2])
                for i in range(0, len(tokens) - 2, 3)
                if i + 2 < len(tokens)]

    hits = []
    for pitch_str, start_str, end_str in triplets:
        try:
            pitch = int(pitch_str)
            start = float(start_str)
            hits.append((pitch, start))
        except ValueError:
            continue

    if not hits:
        return {
            'hit_count': 0, 'kicks': 0, 'snares': 0, 'hats': 0,
            'min_time': 0.0, 'max_time': 0.0, 'mean_ioi': 0.0,
            'out_of_range': 0,
        }

    pitches = [h[0] for h in hits]
    starts = sorted([h[1] for h in hits])

    kicks = sum(1 for p in pitches if p in (35, 36))
    snares = sum(1 for p in pitches if p in (37, 38, 39, 40))
    hats = sum(1 for p in pitches if p in (42, 44, 46, 49, 51, 57, 59))
    out_of_range = sum(1 for s in starts if s < 0 or s >= loop_duration)

    iois = [starts[i+1] - starts[i] for i in range(len(starts) - 1)]
    mean_ioi = sum(iois) / len(iois) if iois else 0.0

    return {
        'hit_count': len(hits),
        'kicks': kicks,
        'snares': snares,
        'hats': hats,
        'min_time': min(starts),
        'max_time': max(starts),
        'mean_ioi': mean_ioi,
        'out_of_range': out_of_range,
    }


def consistency_score(generations: List[str]) -> float:
    """
    Measure similarity across generations.
    Returns fraction of unique sequences (0=all identical, 1=all different).
    Also returns token-level agreement at each position.
    """
    if len(generations) <= 1:
        return 0.0
    unique = len(set(generations))
    return unique / len(generations)



def compare_contexts(tokens_a: List[str], tokens_b: List[str], tokens_c: List[str],
                     label_a="Jake", label_b="CHULOOPA", label_c="Quantized") -> bool:
    """Print side-by-side context comparison. Returns True if all match."""
    max_len = max(len(tokens_a), len(tokens_b), len(tokens_c))
    all_match = True

    print(f"\n{'IDX':>4}  {'Jake Reference':>18}  {'CHULOOPA Native':>18}  {'CHULOOPA+generate':>18}  MATCH")
    print("-" * 75)

    for i in range(max_len):
        ta = tokens_a[i] if i < len(tokens_a) else "<MISSING>"
        tb = tokens_b[i] if i < len(tokens_b) else "<MISSING>"
        tc = tokens_c[i] if i < len(tokens_c) else "<MISSING>"
        match = "✓" if ta == tb == tc else "✗ DIFFER"
        if ta != tb or tb != tc:
            all_match = False
        print(f"{i:>4}  {ta:>18}  {tb:>18}  {tc:>18}  {match}")

    return all_match


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Compare rhythmic_creator pipelines")
    parser.add_argument("--input", default="tracks/track_0/track_0_drums.txt",
                        help="Path to input drum pattern .txt file")
    parser.add_argument("--output-dir", default="tracks/track_0/comparison_test/",
                        help="Directory for output MIDI files")
    parser.add_argument("--num-generations", type=int, default=5,
                        help="Number of generations per pipeline")
    parser.add_argument("--seed", type=int, default=None,
                        help="Random seed for deterministic comparison")
    parser.add_argument("--model", default=str(MODEL_PATH),
                        help="Path to model .pt file")
    parser.add_argument("--vocab", default=str(VOCAB_PATH),
                        help="Path to vocab file (training_1.txt)")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 70)
    print("RHYTHMIC CREATOR PIPELINE COMPARISON")
    print("=" * 70)
    print(f"  Input:           {input_path}")
    print(f"  Output dir:      {output_dir}")
    print(f"  Num generations: {args.num_generations}")
    print(f"  Seed:            {args.seed if args.seed is not None else 'random'}")
    print()

    # ── Load drum pattern ──────────────────────────────────────────────────
    print(f"Loading drum pattern from {input_path}...")
    if not input_path.exists():
        print(f"ERROR: File not found: {input_path}")
        sys.exit(1)

    pattern = DrumPattern.from_file(str(input_path))
    print(f"  Hits: {len(pattern.hits)}, Duration: {pattern.loop_duration:.3f}s")
    for hit in pattern.hits:
        drum_name = {0: 'kick', 1: 'snare', 2: 'hat'}.get(hit.drum_class, '?')
        print(f"    [{drum_name}] t={hit.timestamp:.6f}s")

    # ── Save input as MIDI ─────────────────────────────────────────────────
    input_mid_path = str(output_dir / "input_original.mid")
    pm_in = pretty_midi.PrettyMIDI(initial_tempo=120.0)
    prog = pretty_midi.instrument_name_to_program('cello')
    instr_in = pretty_midi.Instrument(program=prog)
    for hit in pattern.hits:
        midi_note = CHULOOPA_TO_MIDI.get(hit.drum_class, 36)
        note = pretty_midi.Note(velocity=100, pitch=midi_note,
                                start=hit.timestamp, end=hit.timestamp + 0.1)
        instr_in.notes.append(note)
    pm_in.instruments.append(instr_in)
    pm_in.write(input_mid_path)
    print(f"  Saved input MIDI: {input_mid_path}")

    # ── Load model ─────────────────────────────────────────────────────────
    print(f"\nLoading model...")
    model_wrapper = RhythmicCreatorModel(
        model_path=args.model,
        vocab_path=args.vocab
    )
    model = model_wrapper.model
    processor = model_wrapper.processor
    device = model_wrapper.device

    # ── Extract contexts ───────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print("CONTEXT EXTRACTION")
    print("=" * 70)

    print("\nPipeline A — Jake Reference (MIDI roundtrip):")
    ctx_a, tokens_a = extract_jake_context(pattern, processor, device)
    print(f"  Tokens: {len(tokens_a)}")
    print(f"  Text:   {' '.join(tokens_a)}")

    missing_a = check_vocab_coverage(tokens_a, processor)
    if missing_a:
        print(f"  WARNING: {len(missing_a)} tokens NOT in vocab: {missing_a}")
    else:
        print(f"  Vocab coverage: OK (all tokens in vocabulary)")

    print("\nPipeline B — CHULOOPA Native (chuloopa_to_rhythmic_creator):")
    ctx_b, tokens_b = extract_chuloopa_context(pattern, processor, device)
    print(f"  Tokens: {len(tokens_b)}")
    print(f"  Text:   {' '.join(tokens_b)}")

    missing_b = check_vocab_coverage(tokens_b, processor)
    if missing_b:
        print(f"  WARNING: {len(missing_b)} tokens NOT in vocab: {missing_b}")
    else:
        print(f"  Vocab coverage: OK (all tokens in vocabulary)")

    print("\nPipeline C — CHULOOPA + model.generate (same context as B):")
    ctx_c = ctx_b.clone()  # Same context prep as B
    tokens_c = list(tokens_b)  # Same tokens
    print(f"  (Same context as Pipeline B)")
    print(f"  Tokens: {len(tokens_c)}")
    print(f"  Text:   {' '.join(tokens_c)}")

    print("\n--- Side-by-side context comparison ---")
    contexts_match = compare_contexts(tokens_a, tokens_b, tokens_c)
    if contexts_match:
        print("\nContext verdict: ALL PIPELINES HAVE IDENTICAL CONTEXT TOKENS")
        print("  → If outputs differ, the bug is in the generation function")
    else:
        print("\nContext verdict: CONTEXT TOKENS DIFFER BETWEEN PIPELINES")
        print("  → Context preparation is different; this likely causes output differences")

    # Token ID comparison
    print("\n--- Token IDs ---")
    ids_a = processor.encode_with_mapping(tokens_a) if not missing_a else []
    ids_b = processor.encode_with_mapping(tokens_b) if not missing_b else []
    ids_c = list(ids_b)

    print(f"  Pipeline A IDs: {ids_a}")
    print(f"  Pipeline B IDs: {ids_b}")
    print(f"  (Pipeline C IDs same as B)")

    if ids_a == ids_b:
        print("  Token IDs: A == B (identical encoding)")
    else:
        print("  Token IDs: A != B (DIFFERENT encoding — this is the bug!)")

    # ── Determine base token count ────────────────────────────────────────
    n_context_tokens = len(tokens_b)
    print(f"\nContext token count: {n_context_tokens}")
    for spice_name, multiplier in SPICE_LEVELS:
        print(f"  {spice_name:6s} spice: {n_context_tokens * multiplier} tokens (×{multiplier})")

    # ── Run generations: outer=spice, inner=generation index ──────────────
    print("\n" + "=" * 70)
    print("GENERATION RUNS")
    print("=" * 70)

    # results[spice_name][pipeline] = list of decoded strings
    all_results = {
        spice_name: {"A": [], "B": [], "C": []}
        for spice_name, _ in SPICE_LEVELS
    }

    for spice_name, multiplier in SPICE_LEVELS:
        num_tokens = n_context_tokens * multiplier
        print(f"\n{'─' * 70}")
        print(f"SPICE LEVEL: {spice_name.upper()}  ({num_tokens} tokens, ×{multiplier})")
        print(f"{'─' * 70}")

        for gen_idx in range(args.num_generations):
            print(f"\n  --- Generation {gen_idx + 1}/{args.num_generations} ---")

            if args.seed is not None:
                torch.manual_seed(args.seed + gen_idx)

            # Pipeline A
            print("    [A] Jake Reference...", end=" ", flush=True)
            decoded_a = generate_jake_style(model, device, ctx_a.clone(), num_tokens, processor)
            stats_a = analyze_generation(decoded_a, pattern.loop_duration)
            all_results[spice_name]["A"].append(decoded_a)
            print(f"hits={stats_a['hit_count']} (k={stats_a['kicks']} s={stats_a['snares']} h={stats_a['hats']}) "
                  f"range=[{stats_a['min_time']:.2f},{stats_a['max_time']:.2f}]")
            save_midi(decode_to_triplets(decoded_a),
                      str(output_dir / f"jake_{spice_name}_{gen_idx + 1}.mid"))

            # Pipeline B
            if args.seed is not None:
                torch.manual_seed(args.seed + gen_idx)
            print("    [B] CHULOOPA Native...", end=" ", flush=True)
            decoded_b = generate_with_temperature(model_wrapper, ctx_b.clone(), num_tokens, temperature=1.0)
            stats_b = analyze_generation(decoded_b, pattern.loop_duration)
            all_results[spice_name]["B"].append(decoded_b)
            print(f"hits={stats_b['hit_count']} (k={stats_b['kicks']} s={stats_b['snares']} h={stats_b['hats']}) "
                  f"range=[{stats_b['min_time']:.2f},{stats_b['max_time']:.2f}]")
            save_midi(decode_to_triplets(decoded_b),
                      str(output_dir / f"chuloopa_{spice_name}_{gen_idx + 1}.mid"))

            # Pipeline C
            if args.seed is not None:
                torch.manual_seed(args.seed + gen_idx)
            print("    [C] CHULOOPA+generate...", end=" ", flush=True)
            decoded_c = generate_jake_style(model, device, ctx_c.clone(), num_tokens, processor)
            stats_c = analyze_generation(decoded_c, pattern.loop_duration)
            all_results[spice_name]["C"].append(decoded_c)
            print(f"hits={stats_c['hit_count']} (k={stats_c['kicks']} s={stats_c['snares']} h={stats_c['hats']}) "
                  f"range=[{stats_c['min_time']:.2f},{stats_c['max_time']:.2f}]")
            save_midi(decode_to_triplets(decoded_c),
                      str(output_dir / f"quantized_{spice_name}_{gen_idx + 1}.mid"))

    # ── Summary table: pipelines × spice levels ───────────────────────────
    print("\n" + "=" * 70)
    print("SUMMARY TABLE  (avg hits | hit range | consistency)")
    print("=" * 70)
    print(f"{'':20s}", end="")
    for spice_name, multiplier in SPICE_LEVELS:
        label = f"{spice_name}(×{multiplier})"
        print(f"  {label:>20s}", end="")
    print()
    print("-" * (20 + 22 * len(SPICE_LEVELS)))

    pipeline_labels = [
        ("A", "Jake Reference"),
        ("B", "CHULOOPA Native"),
        ("C", "CHULOOPA+generate"),
    ]

    for pipe_key, pipe_label in pipeline_labels:
        print(f"  {pipe_label:18s}", end="")
        for spice_name, _ in SPICE_LEVELS:
            results = all_results[spice_name][pipe_key]
            hit_counts = [analyze_generation(d, pattern.loop_duration)['hit_count']
                          for d in results]
            avg_hits = sum(hit_counts) / len(hit_counts) if hit_counts else 0
            score = consistency_score(results)
            cell = f"avg={avg_hits:.0f} c={score:.2f}"
            print(f"  {cell:>20s}", end="")
        print()

    # Per-spice consistency notes
    print()
    for spice_name, multiplier in SPICE_LEVELS:
        print(f"\n  [{spice_name.upper()} spice, ×{multiplier}]")
        for pipe_key, pipe_label in pipeline_labels:
            results = all_results[spice_name][pipe_key]
            hit_counts = [analyze_generation(d, pattern.loop_duration)['hit_count']
                          for d in results]
            score = consistency_score(results)
            ranges = [(analyze_generation(d, pattern.loop_duration)['min_time'],
                       analyze_generation(d, pattern.loop_duration)['max_time'])
                      for d in results]
            avg_min = sum(r[0] for r in ranges) / len(ranges)
            avg_max = sum(r[1] for r in ranges) / len(ranges)
            print(f"    {pipe_label:20s}  hits={min(hit_counts)}-{max(hit_counts)}  "
                  f"range=[{avg_min:.2f},{avg_max:.2f}]  consistency={score:.2f}")

    # ── Interpretation ─────────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print("DIAGNOSIS")
    print("=" * 70)

    ctx_match = (tokens_a == tokens_b)
    if not ctx_match:
        print("\n[!] CONTEXT TOKENS DIFFER (A vs B)")
        print("   → chuloopa_to_rhythmic_creator() formats timestamps differently")
        print("      from Jake's str(round(note.start, 2)) after MIDI roundtrip")
    else:
        print("\n[OK] Context tokens are IDENTICAL across all pipelines")

    # Check generation equivalence at low spice (most comparable to original test)
    results_b_low = all_results["low"]["B"]
    results_c_low = all_results["low"]["C"]
    if ctx_match and results_b_low != results_c_low:
        print("\n[!] Same context, different generation (B vs C at low spice)")
        print("   → _generate_with_temperature() behaves differently from model.generate()")
    elif ctx_match and results_b_low == results_c_low:
        print("\n[OK] B == C at low spice: _generate_with_temperature(temp=1.0) == model.generate()")

    print("\n" + "=" * 70)
    print("OUTPUT FILES")
    print("=" * 70)
    print(f"  {output_dir}/")
    print(f"    input_original.mid")
    for pipe_prefix in ("jake", "chuloopa", "quantized"):
        for spice_name, _ in SPICE_LEVELS:
            for i in range(args.num_generations):
                print(f"    {pipe_prefix}_{spice_name}_{i+1}.mid")

    print("\nDone. Open the MIDI files in Ableton to listen.")
    print("Compare within pipeline: *_low_*.mid vs *_medium_*.mid vs *_high_*.mid")


if __name__ == "__main__":
    main()
