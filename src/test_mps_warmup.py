#!/usr/bin/env python3
"""
test_mps_warmup.py - Test MPS warmup performance

This tests whether PyTorch MPS has a cold-start penalty that can be avoided.
"""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from rhythmic_creator_model import get_model

def main():
    print("=" * 70)
    print("  MPS WARMUP TEST")
    print("=" * 70)
    print()

    model = get_model()

    # Simple test pattern
    test_pattern = "36 0.0 0.1 38 0.5 0.6 42 1.0 1.1"

    print("Running 5 generations with 10-second delays...")
    print("(Simulating real-world usage pattern)")
    print()

    times = []

    for i in range(5):
        print(f"\nGeneration {i+1}/5:")

        start = time.time()
        output = model.generate_variation(
            input_pattern=test_pattern,
            num_tokens=60,
            temperature=0.9
        )
        elapsed = time.time() - start

        times.append(elapsed)
        print(f"  Time: {elapsed:.2f}s")

        if i < 4:  # Don't wait after last one
            print(f"  Waiting 10 seconds before next generation...")
            time.sleep(10)

    print()
    print("=" * 70)
    print("RESULTS:")
    print("=" * 70)
    for i, t in enumerate(times, 1):
        print(f"  Generation {i}: {t:.2f}s")

    print()
    if times[0] > times[1] * 1.5:
        print("❌ First generation is significantly slower (MPS cold start)")
        print(f"   First: {times[0]:.2f}s vs Later avg: {sum(times[1:])/len(times[1:]):.2f}s")
    else:
        print("✅ Generation times are consistent")

    print()

if __name__ == '__main__':
    main()
