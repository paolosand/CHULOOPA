#!/usr/bin/env python3
"""
Temperature stability evaluation for rhythmic_creator.

Tests different fixed temperatures to find optimal value for stable,
musical continuations. Documents results for ACM C&C 2026 paper.

Usage:
    cd src/evaluation
    python run_temperature_stability.py
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from drum_variation_ai import DrumPattern, rhythmic_creator_variation
import statistics


def test_temperature_stability():
    """Test rhythmic_creator at various temperatures."""

    # Load test patterns
    test_patterns = {
        'sparse': DrumPattern.from_file('../tracks/track_0/track_0_drums.txt'),
    }

    # Temperatures to test
    temperatures = [0.3, 0.5, 0.7, 0.9, 1.0]

    # Repetitions per temperature
    reps = 10

    results = []

    print("Temperature Stability Evaluation")
    print("=" * 60)

    for temp in temperatures:
        print(f"\nTesting temperature {temp:.1f}...")

        hit_counts = []

        for rep in range(reps):
            # Temporarily override global temperature for testing
            import drum_variation_ai
            old_temp = drum_variation_ai.RHYTHMIC_CREATOR_TEMPERATURE
            drum_variation_ai.RHYTHMIC_CREATOR_TEMPERATURE = temp

            variation, success = rhythmic_creator_variation(
                test_patterns['sparse'],
                spice_level=0.5  # Fixed spice for temperature testing
            )

            drum_variation_ai.RHYTHMIC_CREATOR_TEMPERATURE = old_temp

            if success:
                hit_counts.append(len(variation.hits))

        if hit_counts:
            avg = statistics.mean(hit_counts)
            std = statistics.stdev(hit_counts) if len(hit_counts) > 1 else 0.0
            min_hits = min(hit_counts)
            max_hits = max(hit_counts)

            results.append({
                'temp': temp,
                'avg': avg,
                'std': std,
                'min': min_hits,
                'max': max_hits,
                'range': f"{min_hits}-{max_hits}",
                'consistency': 'High' if std < 2.0 else 'Medium' if std < 5.0 else 'Low'
            })

            print(f"  Avg hits: {avg:.1f} (σ={std:.2f})")
            print(f"  Range: {min_hits}-{max_hits}")
            print(f"  Consistency: {results[-1]['consistency']}")

    # Print summary table
    print("\n" + "=" * 60)
    print("SUMMARY TABLE")
    print("=" * 60)
    print(f"{'Temp':<8} {'Avg Hits':<12} {'Std Dev':<12} {'Range':<15} {'Consistency'}")
    print("-" * 60)

    for r in results:
        print(f"{r['temp']:<8.1f} {r['avg']:<12.1f} {r['std']:<12.2f} {r['range']:<15} {r['consistency']}")

    # Save markdown report
    save_markdown_report(results, test_patterns['sparse'])

    print("\n✓ Temperature stability test complete")
    print("  Results saved to: docs/evaluation/2026-03-11-temperature-stability-test.md")


def save_markdown_report(results, test_pattern):
    """Save results as markdown for paper."""

    report_path = Path(__file__).parent.parent.parent / 'docs' / 'evaluation' / '2026-03-11-temperature-stability-test.md'

    with open(report_path, 'w') as f:
        f.write("# Temperature Stability Test\n\n")
        f.write("**Date:** 2026-03-11\n")
        f.write("**Purpose:** Find optimal fixed temperature for rhythmic_creator\n\n")

        f.write("## Methodology\n\n")
        f.write(f"- Test pattern: {len(test_pattern.hits)} hits, {test_pattern.loop_duration:.2f}s duration\n")
        f.write("- Temperatures tested: 0.3, 0.5, 0.7, 0.9, 1.0\n")
        f.write("- Repetitions: 10 per temperature\n")
        f.write("- Fixed spice level: 0.5 (to isolate temperature effects)\n\n")

        f.write("## Results\n\n")
        f.write("| Temperature | Avg Hits | Std Dev | Hit Count Range | Consistency |\n")
        f.write("|-------------|----------|---------|-----------------|-------------|\n")

        for r in results:
            f.write(f"| {r['temp']:.1f}         | {r['avg']:.1f}     | {r['std']:.2f}     | {r['range']:<15} | {r['consistency']:<11} |\n")

        f.write("\n## Recommendation\n\n")

        # Find best temperature (lowest std dev with reasonable avg)
        best = min(results, key=lambda r: r['std'])

        f.write(f"Temperature **{best['temp']:.1f}** provides best balance:\n")
        f.write(f"- Consistency: {best['consistency']} (σ={best['std']:.2f})\n")
        f.write(f"- Average output: {best['avg']:.1f} hits\n")
        f.write(f"- Range: {best['range']} hits\n\n")

        f.write("This temperature will be used as `RHYTHMIC_CREATOR_TEMPERATURE` for all subsequent evaluations.\n")


if __name__ == '__main__':
    test_temperature_stability()
