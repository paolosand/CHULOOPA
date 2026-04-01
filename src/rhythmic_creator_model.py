#!/usr/bin/env python3
"""
rhythmic_creator_model.py - PyTorch model wrapper for Jake Chen's drum variation model

This module loads the Transformer-LSTM+FNN hybrid model and provides
an interface compatible with CHULOOPA's workflow.

Architecture: Transformer-LSTM+FNN Hybrid
Paper: "Music As Natural Language: Deep Learning Driven Rhythmic Creation"
Author: Zhaohan (Jake) Chen, CalArts MFA Thesis 2025
"""

import torch
import torch.nn.functional as F
from pathlib import Path
from typing import Optional

# Import Jake's model architecture
import sys
sys.path.insert(0, str(Path(__file__).parent))

from models.rhythmic_creator.lstm_integration import LSTMDecoderModel
from preprocess.preprocessing import MIDIProcessor


class RhythmicCreatorModel:
    """
    Wrapper for Jake Chen's Transformer-LSTM+FNN hybrid drum model.

    This wrapper:
    - Loads pre-trained model weights
    - Builds vocabulary from training data
    - Adds temperature control to generation
    - Provides clean interface for CHULOOPA
    """

    def __init__(self,
                 model_path: str,
                 vocab_path: str,
                 device: Optional[str] = None):
        """
        Initialize the rhythmic creator model.

        Args:
            model_path: Path to trained .pt weights file
            vocab_path: Path to vocabulary file (training_1.txt)
            device: 'cuda', 'mps', or 'cpu' (auto-detect if None)
        """
        if device:
            self.device = device
        elif torch.cuda.is_available():
            self.device = 'cuda'
        elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            self.device = 'mps'
        else:
            self.device = 'cpu'
        print(f"🎯 Initializing RhythmicCreatorModel on {self.device}...")

        # Initialize preprocessing (builds vocabulary from training data)
        print(f"   Loading vocabulary from {vocab_path}...")
        self.processor = MIDIProcessor(vocab_path)
        self.vocab_size = len(self.processor.unique_notes)
        print(f"   ✓ Vocabulary loaded: {self.vocab_size} unique tokens")

        # Model hyperparameters (from Jake's gen.py and inspection)
        self.block_size = 256     # Context window
        self.n_embd = 192         # Embedding dimension
        self.num_heads = 6        # Attention heads
        self.n_layer = 6          # Transformer blocks
        self.dropout = 0.2        # Dropout rate
        self.n_hidden = 64        # LSTM hidden size
        self.lstm_layers = 2      # LSTM depth

        # Initialize model architecture
        print(f"   Building model architecture...")
        print(f"     - Transformer blocks: {self.n_layer}")
        print(f"     - Attention heads: {self.num_heads}")
        print(f"     - Embedding dim: {self.n_embd}")
        print(f"     - LSTM layers: {self.lstm_layers} × {self.n_hidden} hidden")

        self.model = LSTMDecoderModel(
            block_size=self.block_size,
            vocab_size=self.vocab_size,
            n_embd=self.n_embd,
            num_heads=self.num_heads,
            n_layer=self.n_layer,
            dropout=self.dropout,
            n_hidden=self.n_hidden,
            lstm_layers=self.lstm_layers
        ).to(self.device)

        # Load trained weights
        print(f"   Loading weights from {model_path}...")
        checkpoint = torch.load(model_path, map_location=torch.device(self.device))

        # Handle different checkpoint formats
        if isinstance(checkpoint, dict) and 'state_dict' in checkpoint:
            state_dict = checkpoint['state_dict']
        else:
            state_dict = checkpoint

        self.model.load_state_dict(state_dict)
        self.model.eval()  # Set to evaluation mode

        # Count parameters
        total_params = sum(p.numel() for p in self.model.parameters())
        print(f"   ✓ Model loaded: {total_params:,} parameters")
        print(f"✅ RhythmicCreatorModel ready!\n")

    def generate_variation(self,
                          input_pattern: str = None,
                          num_tokens: int = 300,
                          temperature: float = 1.0,
                          unconditional: bool = False) -> str:
        """
        Generate drum pattern variation with temperature control.

        This method:
        1. Encodes input pattern to tokens (or uses empty context for unconditional)
        2. Initializes LSTM hidden state
        3. Generates with temperature-controlled sampling
        4. Decodes back to text format

        Args:
            input_pattern: Space-separated MIDI events (rhythmic_creator format)
                          Example: "36 0.0 0.12 38 0.5 0.6"
                          If None or unconditional=True, generates from scratch
            num_tokens: Number of new tokens to generate
            temperature: Sampling temperature (0.5-2.0)
                        - Lower (0.5-0.9): Conservative, stays close to training data
                        - Normal (1.0): Standard sampling
                        - Higher (1.1-2.0): Creative, more variation
            unconditional: If True, ignore input_pattern and generate from scratch

        Returns:
            Generated pattern in rhythmic_creator format (space-separated)
        """
        if unconditional or not input_pattern:
            # Unconditional generation: start with zero token (Jake's approach line 70)
            context = torch.zeros((1, 1), dtype=torch.long, device=self.device)
        else:
            # Conditional generation: encode input pattern
            input_tokens = input_pattern.split()
            if not input_tokens:
                raise ValueError("Input pattern is empty")

            try:
                encoded = self.processor.encode_with_mapping(input_tokens)
            except KeyError as e:
                raise ValueError(f"Unknown token in input pattern: {e}")

            context = torch.tensor([encoded], dtype=torch.long, device=self.device)

        # Initialize LSTM hidden state
        hidden = self.model.init_hidden(batch_size=1, device=self.device)

        # Generate with temperature-controlled sampling
        with torch.no_grad():
            generated = self._generate_with_temperature(
                context, hidden, num_tokens, temperature
            )

        # Decode output tokens back to text
        decoded = self.processor.decode_with_mapping(generated[0].tolist())

        return decoded

    def generate_variation_batch(self,
                                 batch_size: int = 3,
                                 input_pattern: str = None,
                                 num_tokens: int = 300,
                                 temperature: float = 1.0,
                                 stop_event=None) -> list:
        """
        Generate N variations in parallel from the same input context.

        Because torch.multinomial samples independently per row, each batch
        element gets a different random variation — same compute cost per token
        as single generation, but N results in one pass.

        Args:
            batch_size: Number of parallel variations to generate
            input_pattern: Space-separated MIDI events (rhythmic_creator format)
            num_tokens: Tokens to generate per variation
            temperature: Sampling temperature

        Returns:
            List of N generated pattern strings
        """
        if not input_pattern:
            context = torch.zeros((batch_size, 1), dtype=torch.long, device=self.device)
        else:
            input_tokens = input_pattern.split()
            try:
                encoded = self.processor.encode_with_mapping(input_tokens)
            except KeyError as e:
                raise ValueError(f"Unknown token in input pattern: {e}")
            # Repeat the same context N times: [1, seq_len] → [N, seq_len]
            single = torch.tensor([encoded], dtype=torch.long, device=self.device)
            context = single.repeat(batch_size, 1)

        hidden = self.model.init_hidden(batch_size=batch_size, device=self.device)

        with torch.no_grad():
            generated = self._generate_with_temperature(
                context, hidden, num_tokens, temperature, stop_event=stop_event
            )

        # Decode each batch element separately
        results = []
        for i in range(batch_size):
            decoded = self.processor.decode_with_mapping(generated[i].tolist())
            results.append(decoded)

        return results

    def _generate_with_temperature(self,
                                   idx: torch.Tensor,
                                   hidden: tuple,
                                   max_new_tokens: int,
                                   temperature: float,
                                   stop_event=None) -> torch.Tensor:
        """
        Generate tokens with temperature-controlled sampling.

        This is a modified version of Jake's generate() method that adds
        temperature scaling to the logits before sampling.

        Args:
            idx: Input token indices [batch_size, seq_len]
            hidden: LSTM hidden state tuple (h, c)
            max_new_tokens: Number of tokens to generate
            temperature: Sampling temperature

        Returns:
            Generated token indices [batch_size, seq_len + max_new_tokens]
        """
        import time  # DIAGNOSTIC

        # Track time per token for first 10 tokens  # DIAGNOSTIC
        token_times = []  # DIAGNOSTIC

        for i in range(max_new_tokens):
            # Mid-generation cancellation: check between token iterations (~50-150ms latency)
            if stop_event is not None and stop_event.is_set():
                break

            t0 = time.time()  # DIAGNOSTIC

            # Crop to block_size if needed
            idx_crop = idx[:, -self.block_size:]

            # Forward pass
            logits, loss, h = self.model(self.device, idx_crop, hidden)

            # Focus on last time step
            logits = logits[:, -1, :]  # [batch_size, vocab_size]

            # Apply temperature scaling
            scaled_logits = logits / temperature

            # Convert to probabilities
            probs = F.softmax(scaled_logits, dim=-1)

            # Sample from distribution
            idx_next = torch.multinomial(probs, num_samples=1)

            # Append to sequence
            idx = torch.cat((idx, idx_next), dim=1)

            # Do NOT update hidden state — matches Jake's original gen.py behavior
            # (hidden stays as initial zero state throughout generation)

            # DIAGNOSTIC: Track timing for first 10 tokens
            if i < 10:  # DIAGNOSTIC
                token_times.append(time.time() - t0)  # DIAGNOSTIC

        # DIAGNOSTIC: Report average time per token
        if token_times:  # DIAGNOSTIC
            avg_time = sum(token_times) / len(token_times)  # DIAGNOSTIC
            print(f"      [Model] Avg time/token (first 10): {avg_time*1000:.1f}ms, total tokens: {max_new_tokens}")  # DIAGNOSTIC

        return idx

    def info(self) -> dict:
        """Get model information."""
        return {
            'vocab_size': self.vocab_size,
            'block_size': self.block_size,
            'n_embd': self.n_embd,
            'num_heads': self.num_heads,
            'n_layer': self.n_layer,
            'n_hidden': self.n_hidden,
            'lstm_layers': self.lstm_layers,
            'device': self.device,
            'total_params': sum(p.numel() for p in self.model.parameters()),
        }


# Global model instance (load once, reuse)
_model_instance = None


def get_model(model_path: str = None, vocab_path: str = None, device: str = None) -> RhythmicCreatorModel:
    """
    Get or create the global model instance.

    This ensures we only load the model once, even if called multiple times.

    Args:
        model_path: Path to model weights (default: src/models/transformer_LSTM_FNN_hybrid.pt)
        vocab_path: Path to vocabulary (default: src/models/training_1.txt)
        device: 'cuda', 'mps', or 'cpu' (auto-detect if None)

    Returns:
        RhythmicCreatorModel instance
    """
    global _model_instance

    if _model_instance is None:
        # Use default paths if not provided
        if model_path is None:
            model_path = Path(__file__).parent / 'models' / 'transformer_LSTM_FNN_hybrid.pt'
        if vocab_path is None:
            vocab_path = Path(__file__).parent / 'models' / 'training_1.txt'

        _model_instance = RhythmicCreatorModel(
            model_path=str(model_path),
            vocab_path=str(vocab_path),
            device=device
        )

    return _model_instance


if __name__ == '__main__':
    # Test model loading
    print("=" * 60)
    print("Testing RhythmicCreatorModel")
    print("=" * 60)
    print()

    model = get_model()

    print("\n📊 Model Info:")
    info = model.info()
    for key, value in info.items():
        print(f"   {key:20s} = {value}")

    # Test generation with simple input
    print("\n🎵 Testing generation...")
    input_pattern = "36 0.0 0.1 38 0.5 0.6 42 1.0 1.1"
    print(f"   Input: {input_pattern}")

    output = model.generate_variation(
        input_pattern=input_pattern,
        num_tokens=30,  # Generate ~10 more drum hits
        temperature=1.0
    )

    print(f"   Output: {output}")
    print(f"   Generated {len(output.split())} tokens")

    print("\n✓ Model test passed!")
