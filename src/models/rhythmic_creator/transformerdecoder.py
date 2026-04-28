import torch
import torch.nn as nn
from torch.nn import functional as F
from .modules.block import AttentionBlock


def _init_weights(module):
    if isinstance(module, nn.Linear):
        torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)
        if module.bias is not None:
            torch.nn.init.zeros_(module.bias)
    elif isinstance(module, nn.Embedding):
        torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)


class DecoderModel(nn.Module):
    def __init__(self, block_size, vocab_size,
                 n_embd, num_heads, n_layer, dropout):
        super().__init__()
        self.block_size = block_size
        self.tok_embd_tbl = nn.Embedding(vocab_size, n_embd)
        self.pos_embd_tbl = nn.Embedding(block_size, n_embd)
        self.blocks = nn.Sequential(*[AttentionBlock(n_embd, num_heads, block_size, dropout) for _ in range(n_layer)])
        self.ln_n = nn.LayerNorm(n_embd)
        self.model_head = nn.Linear(n_embd, vocab_size)
        self.apply(_init_weights)

    def forward(self, device, idx, targets=None):
        b, t = idx.shape
        tok_emb = self.tok_embd_tbl(idx)  # (b, t, c)
        pos_emb = self.pos_embd_tbl(torch.arange(t, device=device))
        x = tok_emb + pos_emb
        x = self.blocks(x)
        x = self.ln_n(x)
        logits = self.model_head(x)

        if targets is None:
            loss = None
        else:
            b, t, c = logits.shape
            logits = logits.view(b * t, c)
            targets = targets.view(b * t)
            loss = F.cross_entropy(logits, targets)
        return logits, loss

    def generate(self, device, idx, max_new_tokens):
        for _ in range(max_new_tokens):
            idx_crop = idx[:, -self.block_size:]
            logits, loss = self(device, idx_crop)
            logits = logits[:, -1, :]
            probs = F.softmax(logits, dim=-1)
            idx_next = torch.multinomial(probs, num_samples=1)
            idx = torch.cat((idx, idx_next), dim=1)
        return idx
