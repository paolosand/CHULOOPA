#!/usr/bin/env python3
"""
test_cpu_mode.py - Test CPU vs MPS performance

Compares CPU inference (consistent) vs MPS (faster but thermal throttling).
"""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

# Import and set force_cpu flag BEFORE importing model
import drum_variation_ai
from drum_variation_ai import DrumPattern, rhythmic_creator_variation

def test_device(device_name, use_cpu):
    """Test generation with specific device setting."""
    # Reset global model instance
    from rhythmic_creator_model import _model_instance
    import rhythmic_creator_model
    rhythmic_creator_model._model_instance = None
    drum_variation_ai.rhythmic_model = None

    # Set CPU flag
    drum_variation_ai.force_cpu = use_cpu

    # Load pattern
    track_file = Path(__file__).parent / "tracks" / "track_0" / "track_0_drums.txt"
    if not track_file.exists():
        print(f"Error: No track file found at {track_file}")
        return None

    pattern = DrumPattern.from_file(str(track_file))

    print(f"\n{'='*70}")
    print(f"  TESTING: {device_name}")
    print(f"{'='*70}")

    # Run 2 generations to see warmup + steady-state
    times = []
    for i in range(2):
        print(f"\nGeneration {i+1}/2:")
        start = time.time()
        varied, success = rhythmic_creator_variation(pattern, spice_level=0.5)
        elapsed = time.time() - start
        times.append(elapsed)
        print(f"  Time: {elapsed:.2f}s")

    return times

def main():
    print("=" * 70)
    print("  CPU vs MPS PERFORMANCE TEST")
    print("=" * 70)
    print()
    print("This will test both CPU and MPS inference.")
    print("CPU should be slower but more consistent.")
    print("MPS should be faster but may throttle when hot.")
    print()

    # Test MPS first
    mps_times = test_device("MPS (GPU)", use_cpu=False)

    # Wait a bit to let system cool down
    print("\nWaiting 5 seconds before CPU test...")
    time.sleep(5)

    # Test CPU
    cpu_times = test_device("CPU", use_cpu=True)

    if mps_times and cpu_times:
        print()
        print("=" * 70)
        print("  RESULTS SUMMARY")
        print("=" * 70)
        print()
        print(f"MPS (GPU):")
        print(f"  First run:  {mps_times[0]:.2f}s")
        print(f"  Second run: {mps_times[1]:.2f}s")
        print(f"  Average:    {sum(mps_times)/len(mps_times):.2f}s")
        print()
        print(f"CPU:")
        print(f"  First run:  {cpu_times[0]:.2f}s")
        print(f"  Second run: {cpu_times[1]:.2f}s")
        print(f"  Average:    {sum(cpu_times)/len(cpu_times):.2f}s")
        print()

        mps_avg = sum(mps_times) / len(mps_times)
        cpu_avg = sum(cpu_times) / len(cpu_times)

        print("RECOMMENDATION:")
        if cpu_avg < mps_avg * 1.5:
            print("  → Use --cpu flag for consistent performance")
            print(f"    (CPU is only {cpu_avg/mps_avg:.1f}x slower but won't throttle)")
        else:
            print("  → Use MPS (default) for faster performance")
            print(f"    (MPS is {mps_avg/cpu_avg:.1f}x faster when not throttling)")
        print()

if __name__ == '__main__':
    main()
