"""
Convert CHULOOPA drum txt files to step-wise MIDI.

Each hit is snapped to the nearest 16th-note grid.
Tempo is inferred from the loop duration (assumed to be 1 bar of 4/4).

Usage:
    python txt_to_stepwise_midi.py <path_to_txt_or_dir>

If a directory is given, all .txt files (original + variations) are converted.
Output .mid files are written alongside the source .txt files.
"""

import sys
import os
import re
import pretty_midi

STEPS_PER_BAR = 16   # 16th-note resolution
BEATS_PER_BAR = 4    # 4/4 time
NOTE_DURATION_FRAC = 0.9  # slightly less than one step so notes don't bleed


def parse_drum_txt(path):
    loop_duration = None
    hits = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("# Total loop duration:"):
                loop_duration = float(line.split(":")[1].strip().split()[0])
            elif line and not line.startswith("#"):
                parts = line.split(",")
                if len(parts) == 4:
                    midi_note = int(parts[0])
                    timestamp = float(parts[1])
                    velocity = float(parts[2])
                    hits.append((midi_note, timestamp, velocity))
    return loop_duration, hits


def txt_to_midi(txt_path):
    loop_duration, hits = parse_drum_txt(txt_path)
    if loop_duration is None or not hits:
        print(f"  Skipping {txt_path}: no loop duration or no hits")
        return

    # Infer BPM from loop duration as 1 bar of 4/4
    bpm = 60.0 * BEATS_PER_BAR / loop_duration
    step_duration = loop_duration / STEPS_PER_BAR
    note_duration = step_duration * NOTE_DURATION_FRAC

    pm = pretty_midi.PrettyMIDI(initial_tempo=bpm)
    drums = pretty_midi.Instrument(program=0, is_drum=True, name="Drums")

    for midi_note, timestamp, velocity_float in hits:
        # Snap to nearest 16th-note step
        step = round(timestamp / step_duration)
        step = max(0, min(step, STEPS_PER_BAR - 1))
        start = step * step_duration
        end = start + note_duration
        vel = max(1, min(127, int(velocity_float * 127)))
        note = pretty_midi.Note(velocity=vel, pitch=midi_note,
                                start=start, end=end)
        drums.notes.append(note)

    drums.notes.sort(key=lambda n: n.start)
    pm.instruments.append(drums)

    out_path = os.path.splitext(txt_path)[0] + ".mid"
    pm.write(out_path)
    print(f"  -> {out_path}  ({bpm:.1f} BPM, {STEPS_PER_BAR} steps, {len(hits)} hits)")


def find_txt_files(path):
    if os.path.isfile(path):
        return [path] if path.endswith(".txt") else []
    txt_files = []
    for root, _, files in os.walk(path):
        for f in files:
            if f.endswith(".txt") and not f.startswith("#"):
                txt_files.append(os.path.join(root, f))
    return txt_files


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python txt_to_stepwise_midi.py <path_to_txt_or_dir>")
        sys.exit(1)

    target = sys.argv[1]
    files = find_txt_files(target)

    if not files:
        print(f"No .txt files found at: {target}")
        sys.exit(1)

    print(f"Converting {len(files)} file(s)...")
    for f in sorted(files):
        print(f"  {os.path.basename(f)}")
        txt_to_midi(f)

    print("Done.")
