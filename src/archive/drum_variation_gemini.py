#!/usr/bin/env python3
"""
drum_variation_gemini.py - Gemini AI-based drum pattern variation generator

This is a standalone version that uses Gemini AI exclusively.
For rhythmic_creator (Jake's model), use drum_variation_ai.py instead.

Usage:
    # Watch mode (auto-generate on file changes)
    python drum_variation_gemini.py --watch

    # Manual variation
    python drum_variation_gemini.py --file tracks/track_0/track_0_drums.txt --temperature 0.7
"""

import os
import sys
import json
import time
import argparse
from pathlib import Path
from dataclasses import dataclass
from typing import List, Tuple

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

# Import core DrumPattern class from main file
from drum_variation_ai import DrumPattern, DrumHit

# =============================================================================
# GEMINI AI SETUP
# =============================================================================

try:
    from google import genai
    HAVE_GEMINI = True
except ImportError:
    HAVE_GEMINI = False
    print("Warning: google-genai not installed. Install with: pip install google-genai")

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
GEMINI_MODEL = "gemini-2.0-flash-exp"

# =============================================================================
# GEMINI VARIATION GENERATOR
# =============================================================================

def pattern_to_gemini_prompt(pattern: DrumPattern) -> str:
    """Convert DrumPattern to Gemini prompt format."""
    lines = [
        f"Loop duration: {pattern.loop_duration:.6f} seconds",
        f"Total hits: {len(pattern.hits)}",
        "",
        "Pattern (DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME):",
        "# Classes: 0=kick, 1=snare, 2=hat"
    ]
    for hit in pattern.hits:
        lines.append(f"{hit.drum_class},{hit.timestamp:.6f},{hit.velocity:.6f},{hit.delta_time:.6f}")
    return "\n".join(lines)


def parse_gemini_pattern(pattern_text: str, loop_duration: float) -> DrumPattern:
    """Parse Gemini's pattern output back to DrumPattern."""
    hits = []
    for line in pattern_text.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split(',')
        if len(parts) >= 4:
            try:
                hits.append(DrumHit(
                    drum_class=int(parts[0]),
                    timestamp=float(parts[1]),
                    velocity=float(parts[2]),
                    delta_time=float(parts[3])
                ))
            except (ValueError, IndexError):
                continue
    return DrumPattern(hits=hits, loop_duration=loop_duration)


def gemini_variation(pattern: DrumPattern, temperature: float = 0.7) -> Tuple[DrumPattern, bool]:
    """Generate variation using Gemini AI.

    Args:
        pattern: Input drum pattern
        temperature: Sampling temperature (0.0-1.0, default 0.7)

    Returns:
        Tuple of (DrumPattern, success: bool)
        - DrumPattern: New pattern with variation (or original if failed)
        - success: True if AI generated, False if fallback was used
    """
    if not HAVE_GEMINI:
        print("  Error: google-genai not installed")
        return pattern, False

    if not GEMINI_API_KEY:
        print("  Error: GEMINI_API_KEY not set in environment")
        return pattern, False

    try:
        # Client reads API key from GEMINI_API_KEY environment variable
        client = genai.Client()

        system_prompt = f"""You are a drum loop generator. Given an input drum pattern you will output a variation of an existing drum pattern given the previous pattern and the output variant's target "spice" level. While maintaining the same key groove and ensuring that the total loop duration is exactly the same. Ensure you always understand the user's groove first before trying to variate.

Add natural human variation through subtle timing shifts, velocity changes, and ghost notes to make the loop feel "alive" like a real drummer playing the groove.

Return the output in the following json format:
{{"reasoning": "", "pattern": ""}}

The pattern field should contain the drum data in the exact same CSV format as the input:
DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME
Where:
- DRUM_CLASS: 0=kick, 1=snare, 2=hat
- TIMESTAMP: seconds from loop start
- VELOCITY: 0.0-1.0
- DELTA_TIME: seconds until next hit (last hit's delta_time = time until loop end)

CRITICAL: The sum of all delta_times must equal the loop duration exactly.

SPICE LEVEL: A float from 0.0 to 1.0 indicating how much variation to apply:
- 0.0 = minimal variation (very close to original)
- 0.5 = moderate variation
- 1.0 = maximum variation (more creative changes)

SPICE LEVEL for this request: {temperature}"""

        user_prompt = pattern_to_gemini_prompt(pattern)

        print(f"  Calling Gemini API ({GEMINI_MODEL})...")
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=system_prompt + "\n\nInput pattern:\n" + user_prompt,
            config={"temperature": temperature}
        )

        # Extract text from response
        response_text = response.text

        # Try to extract JSON from response (may be wrapped in markdown code blocks)
        json_text = response_text
        if "```json" in response_text:
            json_text = response_text.split("```json")[1].split("```")[0]
        elif "```" in response_text:
            json_text = response_text.split("```")[1].split("```")[0]

        # Parse JSON response
        result = json.loads(json_text.strip())
        print(f"  Gemini reasoning: {result.get('reasoning', 'No reasoning provided')[:100]}...")

        # Parse pattern back to DrumPattern
        variation = parse_gemini_pattern(result['pattern'], pattern.loop_duration)

        if not variation.hits:
            print("  Warning: Gemini returned empty pattern")
            return pattern, False

        print(f"  Generated {len(variation.hits)} hits (original: {len(pattern.hits)})")
        return variation, True  # Success!

    except json.JSONDecodeError as e:
        print(f"  Error: Failed to parse Gemini JSON response: {e}")
        return pattern, False
    except Exception as e:
        print(f"  Error: Gemini API call failed: {e}")
        return pattern, False


def generate_variation(input_file: str, output_file: str = None, temperature: float = 0.7):
    """Generate a single variation from input file."""
    print(f"\n{'='*60}")
    print(f"Generating Gemini variation")
    print(f"{'='*60}")
    print(f"Input: {input_file}")
    print(f"Temperature: {temperature:.2f}")
    print()

    # Load pattern
    pattern = DrumPattern.from_file(input_file)
    print(f"Loaded pattern: {len(pattern.hits)} hits, {pattern.loop_duration:.2f}s")

    # Generate variation
    variation, success = gemini_variation(pattern, temperature)

    if not success:
        print("\n✗ Generation failed")
        return False

    # Determine output file
    if output_file is None:
        input_path = Path(input_file)
        var_dir = input_path.parent / "variations"
        var_dir.mkdir(exist_ok=True)
        output_file = var_dir / f"{input_path.stem}_var1.txt"

    # Save variation
    variation.to_file(str(output_file))
    print(f"\n✓ Saved variation to: {output_file}")
    return True


def watch_directory(track_dir: str = "tracks", temperature: float = 0.7):
    """Watch for drum file changes and auto-generate variations."""
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler

    class DrumFileHandler(FileSystemEventHandler):
        def on_modified(self, event):
            if event.is_directory:
                return
            if not event.src_path.endswith('_drums.txt'):
                return
            if '/variations/' in event.src_path:
                return  # Ignore variation files

            print(f"\n{'='*60}")
            print(f"File changed: {event.src_path}")
            print(f"Generating Gemini variation...")
            print(f"{'='*60}")

            time.sleep(0.2)  # Debounce

            # Generate variation
            input_file = event.src_path
            pattern = DrumPattern.from_file(input_file)
            variation, success = gemini_variation(pattern, temperature)

            if success:
                # Save variation
                input_path = Path(input_file)
                var_dir = input_path.parent / "variations"
                var_dir.mkdir(exist_ok=True)
                output_file = var_dir / f"{input_path.stem}_var1.txt"
                variation.to_file(str(output_file))
                print(f"\n✓ Variation saved: {output_file}")
            else:
                print("\n✗ Generation failed")

    # Setup watchdog
    event_handler = DrumFileHandler()
    observer = Observer()
    observer.schedule(event_handler, track_dir, recursive=True)
    observer.start()

    print(f"\n{'='*60}")
    print("Gemini Variation Generator - Watch Mode")
    print(f"{'='*60}")
    print(f"Model: {GEMINI_MODEL}")
    print(f"Temperature: {temperature:.2f}")
    print(f"Watching: {track_dir}")
    print("\nPress Ctrl+C to stop...")
    print(f"{'='*60}\n")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("\n\nStopped watching.")
    observer.join()


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Gemini-based drum pattern variation generator"
    )
    parser.add_argument(
        "--watch",
        action="store_true",
        help="Watch mode: auto-generate on file changes"
    )
    parser.add_argument(
        "--file",
        type=str,
        help="Input drum file for manual generation"
    )
    parser.add_argument(
        "--output",
        type=str,
        help="Output file (default: auto-generate in variations/)"
    )
    parser.add_argument(
        "--temperature",
        type=float,
        default=0.7,
        help="Spice level 0.0-1.0 (default: 0.7)"
    )
    parser.add_argument(
        "--track-dir",
        type=str,
        default="tracks",
        help="Directory to watch (default: tracks)"
    )

    args = parser.parse_args()

    # Check Gemini setup
    if not HAVE_GEMINI:
        print("Error: google-genai not installed")
        print("Install with: pip install google-genai")
        return 1

    if not GEMINI_API_KEY:
        print("Error: GEMINI_API_KEY environment variable not set")
        print("Set it with: export GEMINI_API_KEY='your-api-key'")
        return 1

    # Watch mode
    if args.watch:
        watch_directory(args.track_dir, args.temperature)
        return 0

    # Manual mode
    if args.file:
        success = generate_variation(args.file, args.output, args.temperature)
        return 0 if success else 1

    # No mode specified
    parser.print_help()
    return 1


if __name__ == '__main__':
    sys.exit(main())
