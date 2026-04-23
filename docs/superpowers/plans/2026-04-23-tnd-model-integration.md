# TND Model Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Jake's TND bar-pair model into CHULOOPA's variation pipeline as `tnd_model_variation()`, runnable alongside the existing time-based and grid models.

**Architecture:** Three new pieces: (1) `tnd_model.py` — a GPTBarPair loader (same architecture as the grid model, different vocab); (2) two converter functions in `format_converters.py` that translate between CHULOOPA's DrumPattern and T/N/D token sequences; (3) `tnd_model_variation()` in `drum_variation_generator.py` wired up with the same init/fallback pattern as `rhythmic_creator_variation()`. The checkpoint (`tnd_barpair_best_epoch.pt`) is copied into `src/models/` so all model weights live in one place.

**Tech Stack:** Python, PyTorch, existing DrumPattern/DrumHit dataclasses.

**Worktree:** `/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/`
All paths below are relative to this worktree root.

**Checkpoint facts (verified):**
- Source: `rhythmic_creator/rhythmic_creator_tnd/checkpoints_tnd_barpair/tnd_barpair_best_epoch.pt` (21 MB)
- Keys: `stoi`, `itos`, `config`, `model_state_dict`, `best_val`, `best_epoch`
- Config: `block_size=297, vocab_size=80, n_embd=256, n_head=8, n_layer=6, dropout=0.2`
- T tokens: T0–T34, T36–T39, T41–T48, T56, T62, T72 (max gap = 720ms, gaps at T35/T40/etc.)
- D tokens: D1, D2, D3, D9 — use D2 (20ms) as default for all percussion
- N tokens: N22, N26, N36–N59 (standard GM percussion)

---

## Files

| Action | Path | Purpose |
|--------|------|---------|
| Create | `src/models/__init__.py` | Makes models a package |
| Create | `src/models/rhythmic_creator_tnd/__init__.py` | Makes tnd a package |
| Create | `src/models/tnd_barpair_best_epoch.pt` | Checkpoint (copied from rhythmic_creator repo) |
| Create | `src/models/rhythmic_creator_tnd/tnd_model.py` | GPTBarPair + RhythmicCreatorTNDModel wrapper |
| Modify | `src/format_converters.py` | Add chuloopa_to_tnd_tokens + tnd_tokens_to_chuloopa |
| Create | `src/tests/test_tnd_converters.py` | Unit tests for converter functions |
| Modify | `src/drum_variation_generator.py` | Add tnd_model global, init_tnd_model, tnd_model_variation |
| Create | `src/tests/test_tnd_integration.py` | Integration test: load model + generate variation |

---

## Task 1: Set up models directory and copy checkpoint

**Files:**
- Create: `src/models/__init__.py`
- Create: `src/models/rhythmic_creator_tnd/__init__.py`
- Create: `src/models/tnd_barpair_best_epoch.pt` (copy)

- [ ] **Step 1: Create directory structure and empty init files**

```bash
WORKTREE="/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration"
mkdir -p "$WORKTREE/src/models/rhythmic_creator_tnd"
touch "$WORKTREE/src/models/__init__.py"
touch "$WORKTREE/src/models/rhythmic_creator_tnd/__init__.py"
```

- [ ] **Step 2: Copy checkpoint into src/models/**

```bash
WORKTREE="/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration"
cp "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/rhythmic_creator/rhythmic_creator_tnd/checkpoints_tnd_barpair/tnd_barpair_best_epoch.pt" \
   "$WORKTREE/src/models/tnd_barpair_best_epoch.pt"
```

- [ ] **Step 3: Verify**

```bash
ls -lh "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src/models/"
```

Expected output (3 items):
```
__init__.py
rhythmic_creator_tnd/
tnd_barpair_best_epoch.pt   (≈21 MB)
```

- [ ] **Step 4: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration"
git add src/models/
git commit -m "chore: add models directory and TND checkpoint"
```

---

## Task 2: Create tnd_model.py

**Files:**
- Create: `src/models/rhythmic_creator_tnd/tnd_model.py`

The architecture is identical to the grid model's `GPTBarPair` — only the wrapper class name and the checkpoint path change. The `generate_variation` method works token-agnostically.

- [ ] **Step 1: Write the failing test**

Create `src/tests/test_tnd_model_load.py`:

```python
"""Smoke test: TND model loads and has expected vocab."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from models.rhythmic_creator_tnd.tnd_model import RhythmicCreatorTNDModel

CKPT = os.path.join(os.path.dirname(__file__), '..', 'models', 'tnd_barpair_best_epoch.pt')


def test_model_loads():
    model = RhythmicCreatorTNDModel(CKPT, device='cpu')
    assert len(model.stoi) == 80
    assert '<SOS>' in model.stoi
    assert '<SEP>' in model.stoi
    assert '<EOS>' in model.stoi
    assert 'N36' in model.stoi   # kick
    assert 'N38' in model.stoi   # snare
    assert 'N42' in model.stoi   # hat
    assert 'T0' in model.stoi
    assert 'D2' in model.stoi


def test_generate_returns_tokens():
    model = RhythmicCreatorTNDModel(CKPT, device='cpu')
    # Minimal 2-hit bar: kick at 0ms, snare at 500ms
    context = ['T0', 'N36', 'D2', 'T50', 'N38', 'D2']
    result = model.generate_variation(context, temperature=1.0)
    # Result is a list of strings (may be empty if model generates nothing, but should not error)
    assert isinstance(result, list)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/test_tnd_model_load.py -v
```

Expected: `ImportError: cannot import name 'RhythmicCreatorTNDModel'`

- [ ] **Step 3: Write tnd_model.py**

Create `src/models/rhythmic_creator_tnd/tnd_model.py`:

```python
import math
from pathlib import Path
from typing import Optional

import torch
import torch.nn as nn
import torch.nn.functional as F


class CausalSelfAttention(nn.Module):
    def __init__(self, n_embd: int, n_head: int, block_size: int, dropout: float):
        super().__init__()
        assert n_embd % n_head == 0
        self.n_head = n_head
        self.head_dim = n_embd // n_head
        self.qkv = nn.Linear(n_embd, 3 * n_embd)
        self.proj = nn.Linear(n_embd, n_embd)
        self.attn_drop = nn.Dropout(dropout)
        self.resid_drop = nn.Dropout(dropout)
        mask = torch.tril(torch.ones(block_size - 1, block_size - 1))
        self.register_buffer("mask", mask.view(1, 1, block_size - 1, block_size - 1))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        B, T, C = x.shape
        qkv = self.qkv(x)
        q, k, v = qkv.split(C, dim=2)
        q = q.view(B, T, self.n_head, self.head_dim).transpose(1, 2)
        k = k.view(B, T, self.n_head, self.head_dim).transpose(1, 2)
        v = v.view(B, T, self.n_head, self.head_dim).transpose(1, 2)
        att = (q @ k.transpose(-2, -1)) / math.sqrt(self.head_dim)
        att = att.masked_fill(self.mask[:, :, :T, :T] == 0, float("-inf"))
        att = F.softmax(att, dim=-1)
        att = self.attn_drop(att)
        y = att @ v
        y = y.transpose(1, 2).contiguous().view(B, T, C)
        return self.resid_drop(self.proj(y))


class MLP(nn.Module):
    def __init__(self, n_embd: int, dropout: float):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(n_embd, 4 * n_embd),
            nn.GELU(),
            nn.Linear(4 * n_embd, n_embd),
            nn.Dropout(dropout),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)


class Block(nn.Module):
    def __init__(self, n_embd: int, n_head: int, block_size: int, dropout: float):
        super().__init__()
        self.ln1 = nn.LayerNorm(n_embd)
        self.attn = CausalSelfAttention(n_embd, n_head, block_size, dropout)
        self.ln2 = nn.LayerNorm(n_embd)
        self.mlp = MLP(n_embd, dropout)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = x + self.attn(self.ln1(x))
        x = x + self.mlp(self.ln2(x))
        return x


class GPTBarPair(nn.Module):
    """GPT-style causal Transformer decoder trained on consecutive bar pairs."""

    def __init__(self, vocab_size, block_size, n_embd, n_head, n_layer, dropout):
        super().__init__()
        self.block_size = block_size
        self.tok_emb = nn.Embedding(vocab_size, n_embd)
        self.pos_emb = nn.Embedding(block_size, n_embd)
        self.drop = nn.Dropout(dropout)
        self.blocks = nn.ModuleList([
            Block(n_embd, n_head, block_size, dropout) for _ in range(n_layer)
        ])
        self.ln_f = nn.LayerNorm(n_embd)
        self.head = nn.Linear(n_embd, vocab_size, bias=False)

    def forward(self, idx: torch.Tensor) -> torch.Tensor:
        B, T = idx.shape
        pos = torch.arange(T, device=idx.device).unsqueeze(0)
        x = self.drop(self.tok_emb(idx) + self.pos_emb(pos))
        for block in self.blocks:
            x = block(x)
        return self.head(self.ln_f(x))


class RhythmicCreatorTNDModel:
    """Inference wrapper for the TND bar-pair GPT model."""

    def __init__(self, checkpoint_path: str, device: str = 'cpu'):
        self.device = device
        ckpt = torch.load(checkpoint_path, map_location=device, weights_only=False)

        self.stoi: dict = ckpt['stoi']
        self.itos: dict = ckpt['itos']
        config: dict = ckpt['config']

        self._model = GPTBarPair(
            vocab_size=config['vocab_size'],
            block_size=config['block_size'],
            n_embd=config['n_embd'],
            n_head=config['n_head'],
            n_layer=config['n_layer'],
            dropout=config['dropout'],
        ).to(device)

        self._model.load_state_dict(ckpt['model_state_dict'])
        self._model.eval()

    def generate_variation(
        self,
        context_tokens: list,
        temperature: float = 1.0,
        top_k: Optional[int] = None,
        max_new_tokens: int = 128,
    ) -> list:
        """
        Generate a new bar from a list of T/N/D context tokens.

        Args:
            context_tokens: e.g. ["T0", "N36", "D2", "T50", "N38", "D2", ...]
            temperature:    sampling temperature
            top_k:          if set, restricts sampling to top-k logits
            max_new_tokens: generation budget

        Returns:
            list[str] of T/N/D tokens for the generated bar
        """
        unknown = [t for t in context_tokens if t not in self.stoi]
        if unknown:
            raise ValueError(f"Tokens not in TND vocab: {unknown}")

        seq = ['<SOS>'] + context_tokens + ['<SEP>']
        ids = [self.stoi[t] for t in seq]
        idx = torch.tensor([ids], dtype=torch.long, device=self.device)
        eos_id = self.stoi['<EOS>']

        with torch.no_grad():
            for _ in range(max_new_tokens):
                idx_crop = idx[:, -self._model.block_size:]
                logits = self._model(idx_crop)
                logits = logits[:, -1, :] / temperature
                if top_k is not None:
                    v, _ = torch.topk(logits, min(top_k, logits.size(-1)))
                    logits[logits < v[:, [-1]]] = float('-inf')
                probs = F.softmax(logits, dim=-1)
                idx_next = torch.multinomial(probs, num_samples=1)
                idx = torch.cat([idx, idx_next], dim=1)
                if int(idx_next.item()) == eos_id:
                    break

        all_tokens = [self.itos[int(i)] for i in idx[0].tolist()]
        sep_idx = all_tokens.index('<SEP>') if '<SEP>' in all_tokens else -1
        target = all_tokens[sep_idx + 1:]
        if '<EOS>' in target:
            target = target[:target.index('<EOS>')]
        return target
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/test_tnd_model_load.py -v
```

Expected: `2 passed`

- [ ] **Step 5: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration"
git add src/models/rhythmic_creator_tnd/tnd_model.py src/tests/test_tnd_model_load.py
git commit -m "feat: add RhythmicCreatorTNDModel (GPTBarPair loader for TND checkpoint)"
```

---

## Task 3: Add TND converters to format_converters.py

**Files:**
- Modify: `src/format_converters.py` (append two functions)
- Create: `src/tests/test_tnd_converters.py`

- [ ] **Step 1: Write the failing tests**

Create `src/tests/test_tnd_converters.py`:

```python
"""Unit tests for TND token converters."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from format_converters import chuloopa_to_tnd_tokens, tnd_tokens_to_chuloopa
from drum_variation_generator import DrumPattern, DrumHit

TIME_STEP = 0.01

# Minimal stoi covering what the tests need
MOCK_STOI = {
    '<SOS>': 0, '<EOS>': 1, '<SEP>': 2, '<PAD>': 3,
    **{f'T{i}': 4 + i for i in range(73)},  # T0–T72
    'D1': 77, 'D2': 78, 'D3': 79, 'D9': 80,
    'N36': 81, 'N38': 82, 'N42': 83,
}


def make_pattern(hits_list, loop_duration=2.0):
    hits = [DrumHit(midi_note=n, timestamp=t, velocity=0.8, delta_time=0.0)
            for n, t in hits_list]
    p = DrumPattern(hits=hits, loop_duration=loop_duration)
    p._recalculate_delta_times()
    return p


def test_single_hit_at_zero():
    """Kick at t=0 should produce T0 N36 D2."""
    pattern = make_pattern([(36, 0.0)])
    tokens = chuloopa_to_tnd_tokens(pattern, MOCK_STOI)
    assert tokens == ['T0', 'N36', 'D2']


def test_two_hits_delta_encoding():
    """Kick at 0.0, snare at 0.5 → T0 N36 D2, T50 N38 D2."""
    pattern = make_pattern([(36, 0.0), (38, 0.5)])
    tokens = chuloopa_to_tnd_tokens(pattern, MOCK_STOI)
    assert tokens == ['T0', 'N36', 'D2', 'T50', 'N38', 'D2']


def test_t_value_clamped_when_gap_exceeds_max():
    """Gap of 1.0s (T100) should clamp to T72 (max in vocab)."""
    stoi_limited = {k: v for k, v in MOCK_STOI.items()}
    # Remove T73+ (already not present), just verify T72 is the max
    pattern = make_pattern([(36, 0.0), (38, 1.0)])  # delta = 1.0s = T100
    tokens = chuloopa_to_tnd_tokens(pattern, stoi_limited)
    assert tokens[3] == 'T72'  # clamped to max available


def test_note_not_in_vocab_is_skipped():
    """Note N99 (not in vocab) should be skipped entirely."""
    pattern = make_pattern([(99, 0.0), (36, 0.5)])
    tokens = chuloopa_to_tnd_tokens(pattern, MOCK_STOI)
    # Only the kick at 0.5 remains
    assert 'N99' not in tokens
    assert 'N36' in tokens


def test_roundtrip_two_hits():
    """Tokens → DrumPattern → tokens should recover same timestamps."""
    tokens = ['T0', 'N36', 'D2', 'T50', 'N38', 'D2']
    pattern = tnd_tokens_to_chuloopa(tokens, loop_duration=2.0)
    assert len(pattern.hits) == 2
    assert pattern.hits[0].midi_note == 36
    assert abs(pattern.hits[0].timestamp - 0.0) < 0.001
    assert pattern.hits[1].midi_note == 38
    assert abs(pattern.hits[1].timestamp - 0.5) < 0.001


def test_roundtrip_delta_times_set():
    """tnd_tokens_to_chuloopa must set correct delta_times."""
    tokens = ['T0', 'N36', 'D2', 'T50', 'N38', 'D2']
    pattern = tnd_tokens_to_chuloopa(tokens, loop_duration=2.0)
    assert abs(pattern.hits[0].delta_time - 0.5) < 0.001   # kick → snare gap
    assert abs(pattern.hits[1].delta_time - 1.5) < 0.001   # snare → loop end


def test_tokens_beyond_loop_duration_dropped():
    """Hits beyond loop_duration should be discarded."""
    # T0 N36 D2 at t=0, then T300=3.0s (> loop_duration=2.0)
    tokens = ['T0', 'N36', 'D2', 'T200', 'N38', 'D2']  # t=2.0s exactly, should be dropped
    pattern = tnd_tokens_to_chuloopa(tokens, loop_duration=2.0)
    assert len(pattern.hits) == 1
    assert pattern.hits[0].midi_note == 36


def test_empty_pattern_returns_empty_tokens():
    pattern = DrumPattern(hits=[], loop_duration=2.0)
    tokens = chuloopa_to_tnd_tokens(pattern, MOCK_STOI)
    assert tokens == []


def test_empty_tokens_returns_empty_pattern():
    pattern = tnd_tokens_to_chuloopa([], loop_duration=2.0)
    assert pattern.hits == []
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/test_tnd_converters.py -v
```

Expected: `ImportError: cannot import name 'chuloopa_to_tnd_tokens'`

- [ ] **Step 3: Implement the converters**

Append to `src/format_converters.py`:

```python

# =============================================================================
# TND TOKEN CONVERTERS
# =============================================================================

_TIME_STEP = 0.01  # seconds per T/D unit


def chuloopa_to_tnd_tokens(pattern, stoi: dict) -> list:
    """
    Convert a CHULOOPA DrumPattern to a list of T/N/D token strings.

    T tokens encode inter-onset interval from the previous hit (or bar start).
    D tokens are fixed at D2 (20ms) — the most common percussion duration.
    N tokens not present in the model vocab are skipped.

    Args:
        pattern: DrumPattern with sorted hits
        stoi:    model vocab dict (from RhythmicCreatorTNDModel.stoi)

    Returns:
        list of token strings, e.g. ['T0', 'N36', 'D2', 'T50', 'N38', 'D2']
    """
    if not pattern.hits:
        return []

    available_t = sorted(
        int(tok[1:]) for tok in stoi if tok.startswith('T')
    )
    max_t = available_t[-1] if available_t else 0
    t_set = set(available_t)

    d_tok = 'D2' if 'D2' in stoi else next((t for t in stoi if t.startswith('D')), None)
    if d_tok is None:
        return []

    tokens = []
    prev_time = 0.0

    for hit in sorted(pattern.hits, key=lambda h: h.timestamp):
        n_tok = f'N{hit.midi_note}'
        if n_tok not in stoi:
            prev_time = hit.timestamp
            continue

        delta = hit.timestamp - prev_time
        t_val = round(delta / _TIME_STEP)
        t_val = min(t_val, max_t)

        # Snap to nearest available T value
        if t_val not in t_set:
            t_val = min(available_t, key=lambda x: abs(x - t_val))

        tokens.extend([f'T{t_val}', n_tok, d_tok])
        prev_time = hit.timestamp

    return tokens


def tnd_tokens_to_chuloopa(tokens: list, loop_duration: float):
    """
    Convert a list of T/N/D token strings back to a CHULOOPA DrumPattern.

    Accumulates inter-onset intervals to recover absolute timestamps.
    Hits at or beyond loop_duration are dropped. delta_times are computed
    via DrumPattern._recalculate_delta_times().

    Args:
        tokens:        list of strings from RhythmicCreatorTNDModel.generate_variation
        loop_duration: total loop length in seconds

    Returns:
        DrumPattern with hits and delta_times set
    """
    from drum_variation_generator import DrumPattern, DrumHit

    hits = []
    current_time = 0.0
    i = 0

    while i + 2 < len(tokens):
        t_tok, n_tok, d_tok = tokens[i], tokens[i + 1], tokens[i + 2]
        if t_tok.startswith('T') and n_tok.startswith('N') and d_tok.startswith('D'):
            current_time += int(t_tok[1:]) * _TIME_STEP
            pitch = int(n_tok[1:])
            if current_time < loop_duration:
                hits.append(DrumHit(
                    midi_note=pitch,
                    timestamp=current_time,
                    velocity=assign_velocity(current_time, loop_duration),
                    delta_time=0.0,
                ))
            i += 3
        else:
            i += 1

    if not hits:
        return DrumPattern(hits=[], loop_duration=loop_duration)

    pattern = DrumPattern(hits=hits, loop_duration=loop_duration)
    pattern._recalculate_delta_times()
    return pattern
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/test_tnd_converters.py -v
```

Expected: `9 passed`

- [ ] **Step 5: Run existing tests to check nothing is broken**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/ -v
```

Expected: all previously passing tests still pass.

- [ ] **Step 6: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration"
git add src/format_converters.py src/tests/test_tnd_converters.py
git commit -m "feat: add TND token converters (chuloopa_to_tnd_tokens, tnd_tokens_to_chuloopa)"
```

---

## Task 4: Add tnd_model_variation to drum_variation_generator.py

**Files:**
- Modify: `src/drum_variation_generator.py` (add after `rhythmic_creator_variation`)
- Create: `src/tests/test_tnd_integration.py`

- [ ] **Step 1: Write the failing integration test**

Create `src/tests/test_tnd_integration.py`:

```python
"""Integration test: TND model loads and generates a variation end-to-end."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from drum_variation_generator import DrumPattern, DrumHit, tnd_model_variation


def make_pattern():
    hits = [
        DrumHit(midi_note=36, timestamp=0.0,  velocity=0.8, delta_time=0.5),
        DrumHit(midi_note=38, timestamp=0.5,  velocity=0.7, delta_time=0.5),
        DrumHit(midi_note=36, timestamp=1.0,  velocity=0.8, delta_time=0.5),
        DrumHit(midi_note=38, timestamp=1.5,  velocity=0.7, delta_time=0.5),
    ]
    return DrumPattern(hits=hits, loop_duration=2.0)


def test_tnd_variation_returns_drum_pattern():
    pattern = make_pattern()
    result, success = tnd_model_variation(pattern, spice_level=0.5)
    assert isinstance(result, DrumPattern)
    assert success is True
    assert len(result.hits) >= 1
    assert result.loop_duration == 2.0


def test_tnd_variation_all_hits_within_loop():
    pattern = make_pattern()
    result, _ = tnd_model_variation(pattern, spice_level=0.5)
    for hit in result.hits:
        assert hit.timestamp < result.loop_duration, \
            f"Hit at {hit.timestamp:.3f}s exceeds loop_duration {result.loop_duration:.2f}s"


def test_tnd_variation_delta_times_set():
    pattern = make_pattern()
    result, _ = tnd_model_variation(pattern, spice_level=0.5)
    for hit in result.hits:
        assert hit.delta_time > 0, f"delta_time not set on hit at {hit.timestamp:.3f}s"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/test_tnd_integration.py -v
```

Expected: `ImportError: cannot import name 'tnd_model_variation'`

- [ ] **Step 3: Add tnd_model_variation to drum_variation_generator.py**

Locate the end of `rhythmic_creator_variation` (around line 950) and append the following block directly after it. The exact insertion point is after the closing `except Exception` block of `rhythmic_creator_variation`.

```python

# =============================================================================
# TND BAR-PAIR MODEL VARIATION GENERATOR
# =============================================================================

_TND_MODEL_PATH = Path(__file__).parent / "models" / "tnd_barpair_best_epoch.pt"

tnd_model = None
_tnd_model_lock = threading.Lock()


def init_tnd_model():
    """Initialize TND bar-pair model (call once at startup)."""
    global tnd_model, force_cpu

    try:
        from models.rhythmic_creator_tnd.tnd_model import RhythmicCreatorTNDModel
        from format_converters import chuloopa_to_tnd_tokens, tnd_tokens_to_chuloopa
    except ImportError as e:
        print(f"  TND model not available: {e}")
        return False

    with _tnd_model_lock:
        if tnd_model is not None:
            return True

        if not _TND_MODEL_PATH.exists():
            print(f"  TND checkpoint not found at {_TND_MODEL_PATH}")
            return False

        try:
            import torch
            if force_cpu:
                device = "cpu"
            elif torch.backends.mps.is_available():
                device = "mps"
            else:
                device = "cpu"

            tnd_model = RhythmicCreatorTNDModel(str(_TND_MODEL_PATH), device=device)
            print(f"  TND model loaded on {device} (vocab={len(tnd_model.stoi)} tokens)")
            return True
        except Exception as e:
            print(f"  TND model load failed: {e}")
            return False


def tnd_model_variation(pattern: DrumPattern, spice_level: float = 0.5) -> tuple:
    """
    Generate a variation using the TND bar-pair model.

    Converts CHULOOPA hits to T/N/D tokens, runs inference, converts back.
    Spice maps to temperature: 0.0 → 0.7, 0.5 → 1.0, 1.0 → 1.4.

    Returns:
        Tuple of (DrumPattern, success: bool)
    """
    global tnd_model

    from format_converters import chuloopa_to_tnd_tokens, tnd_tokens_to_chuloopa

    if tnd_model is None:
        if not init_tnd_model():
            print("  TND model not available, falling back to groove_preserve")
            return generate_musical_variation(pattern, spice_level), False

    try:
        loop_duration = pattern.loop_duration
        context_tokens = chuloopa_to_tnd_tokens(pattern, tnd_model.stoi)

        if not context_tokens:
            print("  Warning: No valid TND tokens from pattern, falling back")
            return generate_musical_variation(pattern, spice_level), False

        temperature = 0.7 + (spice_level * 0.7)
        n_hits = len(context_tokens) // 3
        print(f"  Generating TND variation (spice={spice_level:.2f}, temp={temperature:.2f})...")
        print(f"    Context: {n_hits} hits, loop={loop_duration:.2f}s")

        variation_tokens = tnd_model.generate_variation(
            context_tokens,
            temperature=temperature,
        )

        if not variation_tokens:
            print("  Warning: TND model returned empty output, falling back")
            return generate_musical_variation(pattern, spice_level), False

        variation = tnd_tokens_to_chuloopa(variation_tokens, loop_duration)

        if not variation.hits or len(variation.hits) < 2:
            print("  Warning: TND model produced < 2 hits, falling back")
            return generate_musical_variation(pattern, spice_level), False

        print(f"    Variation: {len(variation.hits)} hits")
        return variation, True

    except Exception as e:
        print(f"  TND model error: {e}, falling back")
        return generate_musical_variation(pattern, spice_level), False
```

- [ ] **Step 4: Run integration tests**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/test_tnd_integration.py -v
```

Expected: `3 passed` (note: model inference on CPU may take 15–30s per test)

- [ ] **Step 5: Run full test suite**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration/src"
python -m pytest tests/ -v
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/feat/tnd-model-integration"
git add src/drum_variation_generator.py src/tests/test_tnd_integration.py
git commit -m "feat: add tnd_model_variation() — TND bar-pair model integration"
```
