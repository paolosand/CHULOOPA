#!/usr/bin/env python3
"""
diagnose_performance.py - Diagnose why generation is so slow

Checks for:
- System thermal state (throttling)
- Memory pressure
- GPU availability and performance
- PyTorch configuration
"""

import sys
import subprocess
import platform
from pathlib import Path

def check_system_info():
    """Check basic system information."""
    print("=" * 70)
    print("SYSTEM INFORMATION")
    print("=" * 70)

    print(f"Platform: {platform.system()} {platform.release()}")
    print(f"Machine: {platform.machine()}")
    print(f"Processor: {platform.processor()}")

    # Check macOS version
    try:
        result = subprocess.run(['sw_vers'], capture_output=True, text=True)
        print("\nmacOS Version:")
        print(result.stdout)
    except:
        pass

    print()

def check_thermal_state():
    """Check if system is thermally throttling."""
    print("=" * 70)
    print("THERMAL STATE")
    print("=" * 70)

    try:
        # Check thermal pressure
        result = subprocess.run(['pmset', '-g', 'therm'], capture_output=True, text=True)
        print(result.stdout)

        if 'CPU_Speed_Limit' in result.stdout:
            print("⚠️  CPU speed limiting detected!")
    except Exception as e:
        print(f"Could not check thermal state: {e}")

    print()

def check_power_mode():
    """Check power/performance mode."""
    print("=" * 70)
    print("POWER MODE")
    print("=" * 70)

    try:
        # Check power adapter status
        result = subprocess.run(['pmset', '-g', 'ps'], capture_output=True, text=True)
        print(result.stdout)

        if 'Battery' in result.stdout and 'AC Power' not in result.stdout:
            print("⚠️  Running on battery power (GPU may be throttled)")
    except Exception as e:
        print(f"Could not check power mode: {e}")

    print()

def check_memory():
    """Check memory pressure."""
    print("=" * 70)
    print("MEMORY PRESSURE")
    print("=" * 70)

    try:
        result = subprocess.run(['vm_stat'], capture_output=True, text=True)
        lines = result.stdout.split('\n')

        # Parse key metrics
        for line in lines[:10]:  # First 10 lines have the important stats
            print(line)

        # Check for swap usage
        if any('swapins' in line or 'swapouts' in line for line in lines):
            print("\n⚠️  System may be swapping (performance degradation)")
    except Exception as e:
        print(f"Could not check memory: {e}")

    print()

def check_pytorch():
    """Check PyTorch configuration."""
    print("=" * 70)
    print("PYTORCH CONFIGURATION")
    print("=" * 70)

    try:
        import torch
        print(f"PyTorch version: {torch.__version__}")
        print(f"Python version: {sys.version.split()[0]}")

        if hasattr(torch.backends, 'mps'):
            print(f"MPS available: {torch.backends.mps.is_available()}")
            print(f"MPS built: {torch.backends.mps.is_built()}")

        # Try a simple MPS operation and time it
        if torch.backends.mps.is_available():
            import time
            device = torch.device('mps')

            print("\nTesting MPS performance...")
            print("(Simple matrix multiplication on GPU)")

            # Warmup
            x = torch.randn(1000, 1000, device=device)
            y = torch.randn(1000, 1000, device=device)
            _ = torch.matmul(x, y)

            # Actual test
            start = time.time()
            for _ in range(10):
                result = torch.matmul(x, y)
            torch.mps.synchronize()  # Wait for GPU to finish
            elapsed = (time.time() - start) / 10

            print(f"Average matmul time: {elapsed*1000:.2f}ms")

            if elapsed > 0.1:
                print("⚠️  MPS performance is slow (possible throttling)")
            else:
                print("✅ MPS performance looks normal")
    except Exception as e:
        print(f"Error checking PyTorch: {e}")
        import traceback
        traceback.print_exc()

    print()

def check_background_processes():
    """Check for resource-heavy background processes."""
    print("=" * 70)
    print("TOP PROCESSES (by CPU)")
    print("=" * 70)

    try:
        result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
        lines = result.stdout.split('\n')

        # Sort by CPU usage (3rd column)
        processes = []
        for line in lines[1:]:  # Skip header
            parts = line.split()
            if len(parts) > 10:
                try:
                    cpu = float(parts[2])
                    if cpu > 5.0:  # Only show processes using >5% CPU
                        processes.append((cpu, parts[10]))
                except:
                    pass

        processes.sort(reverse=True)

        if processes:
            print("\nProcesses using >5% CPU:")
            for cpu, name in processes[:10]:
                print(f"  {cpu:>6.1f}%  {name}")
        else:
            print("No high-CPU processes detected")
    except Exception as e:
        print(f"Could not check processes: {e}")

    print()

def main():
    print()
    print("=" * 70)
    print("  CHULOOPA PERFORMANCE DIAGNOSTIC")
    print("=" * 70)
    print()

    check_system_info()
    check_thermal_state()
    check_power_mode()
    check_memory()
    check_pytorch()
    check_background_processes()

    print("=" * 70)
    print("RECOMMENDATIONS")
    print("=" * 70)
    print()
    print("If you see warnings above, try:")
    print("  1. Close heavy applications (browsers with many tabs, etc.)")
    print("  2. Plug in power adapter (if on battery)")
    print("  3. Let Mac cool down if it's hot")
    print("  4. Restart Python process if memory pressure is high")
    print()

if __name__ == '__main__':
    main()
