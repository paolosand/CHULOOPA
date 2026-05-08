# CHULOOPA Evaluation

Reproducibility artifacts for the AIMC 2026 paper evaluation.

## Structure

- `eval_run.py` — generate a variation bank (5 slots × N runs) from a drum txt file
- `eval_heatmap.py` — full evaluation: generate banks for test inputs, build heatmaps
- `eval_heatmap_plot.py` — regenerate heatmap PNGs from saved `output/` txt files
- `eval_heatmap_stats.json` — summary statistics from the paper evaluation
- `midi/` — MIDI files used as evaluation inputs (original + 3 generation runs across 8 temperatures)
- `output/` — raw txt variation outputs (test1 × 10 runs × 5 slots, test2 × 10 runs × 5 slots)
- `figures/` — heatmap PNGs included in the paper

## Reproducing the Evaluation

Run from the repo root:

```bash
# Regenerate heatmaps from saved output
python eval/eval_heatmap_plot.py

# Re-run full evaluation (requires model + GPU/MPS, takes ~10 min)
python eval/eval_heatmap.py
```
