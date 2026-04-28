import torch
import torch.nn as nn
from torch.nn import functional as F
from .modules.block import BlockTwo


def _init_weights(module):
    if isinstance(module, nn.Linear):
        torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)
        if module.bias is not None:
            torch.nn.init.zeros_(module.bias)
    elif isinstance(module, nn.Embedding):
        torch.nn.init.normal_(module.weight, mean=0.0, std=0.02)


class LSTMDecoderModel(nn.Module):
    def __init__(self, block_size, vocab_size,
                 n_embd, num_heads, n_layer, dropout, n_hidden, lstm_layers):
        super().__init__()
        # self.device = device
        self.block_size = block_size
        self.n_hidden = n_hidden
        self.lstm_layers = lstm_layers
        self.tok_embd_tbl = nn.Embedding(vocab_size, n_embd)
        self.pos_embd_tbl = nn.Embedding(block_size, n_embd)

        # lstm in sequential block
        self.blocks = nn.Sequential(*[BlockTwo(n_embd, num_heads, block_size, dropout, n_hidden, lstm_layers)
                                      for _ in range(n_layer)])

        self.dropout = nn.Dropout(dropout)
        self.ln_n = nn.LayerNorm(n_embd)
        self.model_head = nn.Linear(n_embd, vocab_size)
        self.apply(_init_weights)

    def forward(self, device, idx, hidden, targets=None):
        b, t = idx.shape
        tok_emb = self.tok_embd_tbl(idx)  # (b, t, c)
        pos_emb = self.pos_embd_tbl(torch.arange(t, device=device))
        x = tok_emb + pos_emb

        # lstm in sequential block
        x, h = self.blocks((x, hidden))
        x = self.ln_n(x)
        logits = self.model_head(x)

        if targets is None:
            loss = None
        else:
            b, t, c = logits.shape
            logits = logits.view(b * t, c)
            targets = targets.view(b * t)
            loss = F.cross_entropy(logits, targets)
        return logits, loss, h

    def init_hidden(self, batch_size, device):
        hidden = torch.zeros(self.lstm_layers, batch_size, self.n_hidden).to(device)
        cell = torch.zeros(self.lstm_layers, batch_size, self.n_hidden).to(device)
        return hidden, cell

    def detach_hidden(self, hidden):
        hidden, cell = hidden
        hidden = hidden.detach()
        cell = cell.detach()
        return hidden, cell

    def generate(self, device, idx, hidden, max_new_tokens):
        for _ in range(max_new_tokens):
            idx_crop = idx[:, -self.block_size:]
            logits, loss, h = self(device, idx_crop, hidden)
            logits = logits[:, -1, :]
            probs = F.softmax(logits, dim=-1)
            idx_next = torch.multinomial(probs, num_samples=1)
            idx = torch.cat((idx, idx_next), dim=1)
        return idx
