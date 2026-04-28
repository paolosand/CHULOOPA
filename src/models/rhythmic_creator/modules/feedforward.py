import torch.nn as nn
import torch
import math


class MlPFeedForward(nn.Module):
    def __init__(self, n_embd, dropout):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(n_embd, 4 * n_embd),
            nn.ReLU(),
            nn.Linear(4 * n_embd, n_embd),
            nn.Dropout(dropout),
        )

    def forward(self, x):
        return self.net(x)


class LSTMFeedForward(nn.Module):
    def __init__(self, n_embd, n_hidden, lstm_layers, dropout):
        super().__init__()
        self.lstm = nn.LSTM(n_embd, n_hidden, num_layers=lstm_layers, dropout=dropout,
                            batch_first=True)
        self.dl = nn.Dropout(dropout)
        self.fc = nn.Linear(n_hidden, n_embd)
        self.lstm_layers = lstm_layers
        self.n_embd = n_embd
        self.n_hidden = n_hidden
        self._init_weights()

    def forward(self, x, hidden):
        x, h = self.lstm(x, hidden)
        x = self.dl(x)
        x = self.fc(x)
        return x, h

    def _init_weights(self):
        non_embd_layer_range = 1 / math.sqrt(self.n_hidden)
        for i in range(self.lstm_layers):
            self.lstm.all_weights[i][0] = torch.FloatTensor(self.n_embd, self.n_hidden).uniform_(-non_embd_layer_range,
                                                                                                 non_embd_layer_range)
            self.lstm.all_weights[i][1] = torch.FloatTensor(self.n_hidden, self.n_hidden).uniform_(
                -non_embd_layer_range, non_embd_layer_range)
