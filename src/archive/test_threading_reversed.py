#!/usr/bin/env python3
"""
test_threading_reversed.py - Test threading impact with REVERSED order

This runs background thread FIRST, then main thread.
If background is still slow, it's a threading issue.
If main is slow instead, it's just MPS warmup (first-run penalty).
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
    print("  THREADING IMPACT TEST (REVERSED ORDER)")
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

    # Test 1: BACKGROUND THREAD FIRST (reversed!)
    print("TEST 1: Generation in BACKGROUND thread (like OSC handler)")
    print("-" * 70)
    results = {}
    thread = threading.Thread(target=generate_in_thread, args=(pattern, results))

    start = time.time()
    thread.start()
    thread.join()
    bg_thread_time = time.time() - start
    print(f"Background thread time: {bg_thread_time:.2f}s")
    print()

    # Test 2: MAIN THREAD SECOND
    print("TEST 2: Generation in MAIN thread")
    print("-" * 70)
    start = time.time()
    varied, success = rhythmic_creator_variation(pattern, spice_level=0.5)
    main_thread_time = time.time() - start
    print(f"Main thread time: {main_thread_time:.2f}s")
    print()

    # Compare
    print("=" * 70)
    print("RESULTS")
    print("=" * 70)
    print(f"Background thread (ran FIRST): {bg_thread_time:.2f}s")
    print(f"Main thread (ran SECOND):      {main_thread_time:.2f}s")
    print()

    if bg_thread_time > main_thread_time * 1.5:
        print("❌ Background thread is SLOWER even when running first!")
        print("   This confirms threading is the problem.")
    elif main_thread_time > bg_thread_time * 1.5:
        print("✅ Main thread is slower only because it ran second")
        print("   First run is always slow (MPS warmup), nothing to do with threading")
    else:
        print("✅ Times are similar - no threading penalty")
        print("   First run is always slow (MPS warmup)")

    print()

if __name__ == '__main__':
    main()
