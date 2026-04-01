#!/usr/bin/env python3
"""
test_model_persistence.py - Test if model stays loaded between generations

This simulates what happens in watch mode when multiple regenerate requests come in.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from rhythmic_creator_model import get_model, _model_instance

def main():
    print("=" * 70)
    print("  MODEL PERSISTENCE TEST")
    print("=" * 70)
    print()

    print("TEST 1: Check initial state")
    print(f"  _model_instance before first get_model(): {_model_instance}")
    print()

    print("TEST 2: Load model (first time)")
    model1 = get_model()
    print(f"  _model_instance after first get_model(): {_model_instance is not None}")
    print(f"  Model ID: {id(model1)}")
    print()

    print("TEST 3: Get model again (should be cached)")
    model2 = get_model()
    print(f"  Model ID: {id(model2)}")
    print(f"  Same instance? {model1 is model2}")
    print()

    if model1 is model2:
        print("✅ Model is properly cached and reused")
        print("   This means the slowdown is NOT from model reloading")
    else:
        print("❌ Model is being recreated!")
        print("   This would explain the slowdown")

    print()
    print("=" * 70)

if __name__ == '__main__':
    main()
