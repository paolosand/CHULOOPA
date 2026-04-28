import torch.nn as nn
from .sublayers import MultiHeadAttention
from .feedforward import MlPFeedForward, LSTMFeedForward


class AttentionBlock(nn.Module):

    def __init__(self, n_embd, num_heads, block_size, dropout):
        super().__init__()
        head_size = n_embd // num_heads
        self.sa = MultiHeadAttention(num_heads, head_size, n_embd, block_size, dropout)
        self.ffwd = MlPFeedForward(n_embd, dropout)
        self.lyr_norm1 = nn.LayerNorm(n_embd)
        self.lyr_norm2 = nn.LayerNorm(n_embd)

    def forward(self, x):
        x = x + self.sa(self.lyr_norm1(x))
        x = x + self.ffwd(self.lyr_norm2(x))
        return x


class BlockTwo(nn.Module):
    def __init__(self, n_embd, num_heads, block_size, dropout, n_hidden, lstm_layers):
        super().__init__()
        head_size = n_embd // num_heads
        self.sa = MultiHeadAttention(num_heads, head_size, n_embd, block_size, dropout)
        self.lstm_lyr = LSTMFeedForward(n_embd, n_hidden, lstm_layers, dropout)
        self.ffwd = MlPFeedForward(n_embd, dropout)
        self.lyr_norm1 = nn.LayerNorm(n_embd)
        self.lyr_norm2 = nn.LayerNorm(n_embd)
        self.lyr_norm4 = nn.LayerNorm(n_embd)

    def forward(self, inputs):
        x, hidden = inputs
        x = x + self.sa(self.lyr_norm1(x))
        x_lstm, h = self.lstm_lyr(self.lyr_norm4(x), hidden)
        x = x + self.ffwd(self.lyr_norm2(x))
        x = x + x_lstm
        return x, h


class LSTMffBlock(nn.Module):
    def __init__(self, n_embd, n_hidden, lstm_layers, dropout):
        super().__init__()
        self.lstmffwd = LSTMFeedForward(n_embd, n_hidden, lstm_layers, dropout)

    def forward(self, x, hidden):
        x, h = self.lstmffwd(x, hidden)
        return x, h
