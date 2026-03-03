#!/usr/bin/env python3
"""
inspect_jake_models.py - Inspect PyTorch checkpoint files to determine model configuration

This script unpacks Jake's saved .pt files and reverse-engineers the model config
by analyzing the state_dict layer shapes and parameter counts.

Usage:
    python inspect_jake_models.py model1.pt model2.pt model3.pt
"""

import torch
import sys
from pathlib import Path
from collections import OrderedDict


def inspect_checkpoint(checkpoint_path: str):
    """
    Load and inspect a PyTorch checkpoint file.

    Args:
        checkpoint_path: Path to .pt file
    """
    print("=" * 80)
    print(f"INSPECTING: {checkpoint_path}")
    print("=" * 80)

    try:
        # Load checkpoint (CPU mode, no GPU needed)
        checkpoint = torch.load(checkpoint_path, map_location=torch.device('cpu'))

        # Check what's in the checkpoint
        if isinstance(checkpoint, dict):
            print(f"\n📦 Checkpoint type: dict")
            print(f"   Keys: {list(checkpoint.keys())}")

            # Extract state_dict (might be nested)
            if 'state_dict' in checkpoint:
                state_dict = checkpoint['state_dict']
                print(f"   Found nested 'state_dict' key")
            elif 'model' in checkpoint:
                state_dict = checkpoint['model']
                print(f"   Found nested 'model' key")
            else:
                state_dict = checkpoint
                print(f"   Using checkpoint directly as state_dict")

        else:
            # Checkpoint is the state_dict directly
            state_dict = checkpoint
            print(f"\n📦 Checkpoint type: {type(checkpoint)}")

        print(f"\n📊 STATE DICT ANALYSIS:")
        print(f"   Total parameters: {len(state_dict)}")

        # Analyze layer structure
        print(f"\n🔍 LAYER STRUCTURE:")
        total_params = 0

        for name, param in state_dict.items():
            param_count = param.numel()
            total_params += param_count
            print(f"   {name:60s} {str(param.shape):30s} {param_count:>12,} params")

        print(f"\n   {'TOTAL PARAMETERS':60s} {'':<30s} {total_params:>12,}")

        # Reverse-engineer configuration
        print(f"\n🎯 INFERRED CONFIGURATION:")
        config = infer_config(state_dict)

        for key, value in config.items():
            print(f"   {key:20s} = {value}")

        # Determine model type
        print(f"\n🏷️  MODEL TYPE:")
        if any('lstm' in name.lower() for name in state_dict.keys()):
            if any('fc' in name or 'ffwd' in name for name in state_dict.keys()):
                print(f"   ✅ Transformer-LSTM+FNN Hybrid (BEST MODEL)")
            else:
                print(f"   ⚠️  Transformer-LSTM (replaces FNN)")
        else:
            print(f"   📝 Transformer Baseline")

        # Check if this matches Jake's best model specs
        print(f"\n✓ MATCHES PAPER'S BEST MODEL?")
        is_best = check_if_best_model(config, total_params)

        if is_best:
            print(f"   ✅ YES - This appears to be transformer_LSTM_FNN_hybrid.pt")
            print(f"      (4.49M params, hybrid architecture)")
        else:
            print(f"   ⚠️  NO - Different configuration")

        return config, total_params, state_dict

    except Exception as e:
        print(f"\n❌ ERROR loading checkpoint: {e}")
        import traceback
        traceback.print_exc()
        return None, None, None


def infer_config(state_dict):
    """
    Reverse-engineer model configuration from state_dict.

    Looks for:
    - vocab_size: from tok_embd_tbl.weight shape
    - n_embd: from embedding dimension
    - block_size: from pos_embd_tbl.weight shape
    - num_heads: from attention layer shapes
    - n_layer: count of attention blocks
    - n_hidden: from LSTM hidden size (if present)
    - lstm_layers: from LSTM layer count (if present)
    """
    config = {}

    # Vocabulary size
    if 'tok_embd_tbl.weight' in state_dict:
        vocab_size, n_embd = state_dict['tok_embd_tbl.weight'].shape
        config['vocab_size'] = vocab_size
        config['n_embd'] = n_embd

    # Block size (context window)
    if 'pos_embd_tbl.weight' in state_dict:
        block_size, _ = state_dict['pos_embd_tbl.weight'].shape
        config['block_size'] = block_size

    # Count attention blocks (n_layer)
    block_nums = set()
    for name in state_dict.keys():
        if 'blocks.' in name:
            try:
                block_num = int(name.split('blocks.')[1].split('.')[0])
                block_nums.add(block_num)
            except:
                pass
    config['n_layer'] = len(block_nums) if block_nums else None

    # Number of heads (from attention layer)
    # Look for pattern like: blocks.0.sa.heads.0.key.weight
    for name in state_dict.keys():
        if 'heads.' in name and '.key.weight' in name:
            try:
                # Count number of heads in first block
                head_nums = set()
                for n in state_dict.keys():
                    if 'blocks.0.sa.heads.' in n:
                        head_num = int(n.split('heads.')[1].split('.')[0])
                        head_nums.add(head_num)
                config['num_heads'] = len(head_nums) if head_nums else None
                break
            except:
                pass

    # LSTM configuration
    lstm_layers_found = []
    for name in state_dict.keys():
        if 'lstm' in name.lower():
            # Extract LSTM layer info
            if 'weight_ih_l' in name:
                layer_num = int(name.split('weight_ih_l')[1].split('_')[0])
                lstm_layers_found.append(layer_num)

                # Get hidden size from weight shape
                if 'n_hidden' not in config:
                    weight_shape = state_dict[name].shape
                    # LSTM weight_ih shape is (4*hidden_size, input_size)
                    config['n_hidden'] = weight_shape[0] // 4

    if lstm_layers_found:
        config['lstm_layers'] = max(lstm_layers_found) + 1

    # Dropout (can't infer from state_dict, use default)
    config['dropout'] = 0.2  # Standard value, can't determine from checkpoint

    return config


def check_if_best_model(config, total_params):
    """
    Check if this matches the paper's best model specs.

    Best model (from paper Table 1):
    - Transformer-LSTM+FNN Hybrid
    - 4.49M parameters
    - n_embd = 192
    - num_heads = 6
    - n_layer = 6
    - n_hidden = 64
    - lstm_layers = 2
    """
    target_params = 4_490_000  # 4.49M
    tolerance = 0.1  # 10% tolerance

    param_match = (total_params >= target_params * (1 - tolerance) and
                   total_params <= target_params * (1 + tolerance))

    config_match = (
        config.get('n_embd') == 192 and
        config.get('num_heads') == 6 and
        config.get('n_layer') == 6 and
        config.get('n_hidden') == 64 and
        config.get('lstm_layers') == 2
    )

    return param_match and config_match


def compare_checkpoints(checkpoint_paths):
    """Compare multiple checkpoint files side-by-side."""
    print("\n" + "=" * 80)
    print("CHECKPOINT COMPARISON")
    print("=" * 80)

    results = []
    for path in checkpoint_paths:
        config, params, state_dict = inspect_checkpoint(path)
        if config is not None:
            results.append((path, config, params))
        print()  # Spacing

    if len(results) > 1:
        print("\n" + "=" * 80)
        print("SUMMARY TABLE")
        print("=" * 80)
        print(f"\n{'Model':40s} {'Params':>12s} {'Type':30s}")
        print("-" * 85)

        for path, config, params in results:
            model_name = Path(path).name

            # Determine type
            if config.get('n_hidden') and config.get('lstm_layers'):
                model_type = "LSTM+FNN Hybrid" if 'ffwd' in str(config) else "LSTM only"
            else:
                model_type = "Transformer baseline"

            print(f"{model_name:40s} {params:>12,} {model_type:30s}")

        print()

        # Find the best model
        best_idx = None
        for i, (path, config, params) in enumerate(results):
            if check_if_best_model(config, params):
                best_idx = i
                break

        if best_idx is not None:
            print(f"\n✅ RECOMMENDED MODEL: {Path(results[best_idx][0]).name}")
            print(f"   This matches the paper's best configuration (4.49M params, hybrid)")
        else:
            print(f"\n⚠️  No exact match found for best model config")
            print(f"   Choose the model with ~4.49M params and LSTM+FNN architecture")


def generate_config_file(config, output_path="model_config.py"):
    """Generate a Python config file from inferred configuration."""

    code = f'''"""
Model configuration (auto-generated from checkpoint inspection)
"""

# Model architecture
BLOCK_SIZE = {config.get('block_size', 256)}
VOCAB_SIZE = {config.get('vocab_size', 'UNKNOWN')}
N_EMBD = {config.get('n_embd', 192)}
NUM_HEADS = {config.get('num_heads', 6)}
N_LAYER = {config.get('n_layer', 6)}
DROPOUT = {config.get('dropout', 0.2)}

# LSTM configuration (if hybrid model)
N_HIDDEN = {config.get('n_hidden', 64)}
LSTM_LAYERS = {config.get('lstm_layers', 2)}

# Model type detection
HAS_LSTM = {config.get('n_hidden') is not None}
IS_HYBRID = {config.get('n_hidden') is not None}  # Has both LSTM and FNN

# Device
DEVICE = 'cuda' if torch.cuda.is_available() else 'cpu'
'''

    with open(output_path, 'w') as f:
        f.write(code)

    print(f"\n💾 Saved configuration to: {output_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python inspect_jake_models.py model1.pt [model2.pt ...]")
        print()
        print("Example:")
        print("  python inspect_jake_models.py transformer_LSTM_FNN_hybrid.pt")
        print()
        sys.exit(1)

    checkpoint_paths = sys.argv[1:]

    # Check files exist
    for path in checkpoint_paths:
        if not Path(path).exists():
            print(f"❌ File not found: {path}")
            sys.exit(1)

    # Compare checkpoints
    compare_checkpoints(checkpoint_paths)


if __name__ == '__main__':
    main()
