#!/usr/bin/env python3
"""
Test if simultaneous drum hits are actually a problem or musically valid.

The model generates hits like:
  36 0.50 0.60  # kick
  42 0.50 0.56  # hat

This creates two hits at timestamp 0.50s, which we've been calling "duplicates".
But this is actually SIMULTANEOUS HITS - musically valid!

This test creates a pattern with intentional simultaneous hits and saves it.
