#!/usr/bin/env python3
"""
test_threading_impact.py - Test if threading causes MPS slowdown
"""

import sys
import time
import threading
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from drum_variation_ai import DrumPattern, rhythmic_creator_variation

def generate_in_thread(pattern, results):
    """Run generation in a background thread."""
    print("  [Thread] Starting generation...")
    start = time.time()
    varied, success = rhythmic_creator_variation(pattern, spice_level=0.5)
    elapsed = time.time() - start
    results['elapsed'] = elapsed
    results['success'] = success
    print(f"  [Thread] Complete: {elapsed:.2f}s")

def main():
    print("=" * 70)
    print("  THREADING IMPACT TEST")
    print("=" * 70)
    print()

    # Load pattern
    track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
    if not track_file.exists():
        print("Error: No track file found")
        return 1

    pattern = DrumPattern.from_file(str(track_file))
    print(f"Loaded pattern: {len(pattern.hits)} hits")
    print()

    # Test 1: Main thread (like my test)
    print("TEST 1: Generation in MAIN thread")
    print("-" * 70)
    start = time.time()
    varied, success = rhythmic_creator_variation(pattern, spice_level=0.5)
    main_thread_time = time.time() - start
    print(f"Main thread time: {main_thread_time:.2f}s")
    print()

    # Test 2: Background thread (like OSC handler)
    print("TEST 2: Generation in BACKGROUND thread (like OSC handler)")
    print("-" * 70)
    results = {}
    thread = threading.Thread(target=generate_in_thread, args=(pattern, results))

    start = time.time()
    thread.start()
    thread.join()
    bg_thread_time = time.time() - start
    print(f"Background thread time: {bg_thread_time:.2f}s")
    print()

    # Compare
    print("=" * 70)
    print("RESULTS")
    print("=" * 70)
    print(f"Main thread:       {main_thread_time:.2f}s")
    print(f"Background thread: {bg_thread_time:.2f}s")
    print(f"Slowdown factor:   {bg_thread_time/main_thread_time:.2f}x")
    print()

    if bg_thread_time > main_thread_time * 1.5:
        print("❌ CONFIRMED: Background threads cause significant slowdown!")
        print("   This is the root cause of your ~40s generation times.")
        print()
        print("   SOLUTION: Run model in main thread, not OSC handler thread")
    else:
        print("✅ Threading doesn't seem to be the issue")
        print("   Need to investigate other causes...")

    print()

if __name__ == '__main__':
    main()
