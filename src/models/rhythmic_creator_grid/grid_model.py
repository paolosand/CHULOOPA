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

    def __init__(
        self,
        vocab_size: int,
        block_size: int,
        n_embd: int,
        n_head: int,
        n_layer: int,
        dropout: float,
    ):
        super().__init__()
        self.block_size = block_size - 1

        self.token_emb = nn.Embedding(vocab_size, n_embd)
        self.pos_emb = nn.Embedding(self.block_size, n_embd)
        self.drop = nn.Dropout(dropout)

        self.blocks = nn.ModuleList([
            Block(n_embd, n_head, block_size, dropout) for _ in range(n_layer)
        ])
        self.ln_f = nn.LayerNorm(n_embd)
        self.head = nn.Linear(n_embd, vocab_size)

    def forward(self, idx: torch.Tensor) -> torch.Tensor:
        B, T = idx.shape
        pos = torch.arange(0, T, device=idx.device)
        x = self.token_emb(idx) + self.pos_emb(pos)[None, :, :]
        x = self.drop(x)
        for block in self.blocks:
            x = block(x)
        x = self.ln_f(x)
        return self.head(x)


class RhythmicCreatorGridModel:
    """
    Wrapper for Jake Chen's GPTBarPair drum variation model.

    Given a list of P/N tokens representing one bar of context, generates
    a new bar as a list of P/N tokens.

    Usage:
        model = RhythmicCreatorGridModel("path/to/grid_barpair_best_epoch.pt")
        variation = model.generate_variation(["P0", "N36", "P4", "N38", ...])
    """

    def __init__(self, checkpoint_path: str, device: Optional[str] = None):
        if device:
            self.device = device
        elif torch.cuda.is_available():
            self.device = 'cuda'
        elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            self.device = 'mps'
        else:
            self.device = 'cpu'

        ckpt = torch.load(checkpoint_path, map_location=self.device, weights_only=False)

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
        ).to(self.device)

        self._model.load_state_dict(ckpt['model_state_dict'])
        self._model.eval()

    def generate_variation(
        self,
        context_tokens: list,
        temperature: float = 1.0,
        top_k: Optional[int] = None,
        max_new_tokens: int = 64,
    ) -> list:
        """
        Generate a new bar from a list of P/N context tokens.

        Args:
            context_tokens: e.g. ["P0", "N36", "P4", "N38", ...]
            temperature:    sampling temperature (lower = more conservative)
            top_k:          if set, restricts sampling to top-k logits
            max_new_tokens: generation budget (stops earlier at <EOS>)

        Returns:
            list[str] of P/N tokens for the generated bar
        """
        unknown = [t for t in context_tokens if t not in self.stoi]
        if unknown:
            raise ValueError(f"Tokens not in model vocab: {unknown}")

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
