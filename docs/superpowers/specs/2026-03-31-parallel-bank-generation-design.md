# Parallel Bank Generation Design

**Date:** 2026-03-31
**Status:** Approved for implementation
**Scope:** `src/drum_variation_ai_v2.py`, `src/rhythmic_creator_model.py`

---

## Problem

The current variation bank generation is sequential: for each of 5 spice slots, the system calls `rhythmic_creator_variation()` which runs `generate_variation_batch(batch_size=3)`, scores candidates, and picks the best. This results in ~15 serial model calls (~75 seconds total before ChucK can start auto-switching).

Two root causes:
1. **Serial slots** — 5 slots generated one after another
2. **Wasteful candidate selection** — 3 candidates generated per slot, 2 discarded; unnecessary now that 5 distinct spice levels already provide diversity

---

## Design

### Core Idea

Each spice level generates a different number of tokens:

```
token_multiplier = 0.85 + (spice_level * 0.65)
num_tokens = int(len(context_tokens) * token_multiplier)
```

Spice slots and their token multipliers:
- Slot 1, spice=0.2 → 0.98×
- Slot 2, spice=0.4 → 1.11×
- Slot 3, spice=0.6 → 1.24×
- Slot 4, spice=0.8 → 1.37×
- Slot 5, spice=1.0 → 1.50×

Because each slot needs a different `num_tokens`, they cannot share a single batch call. Instead, all slots are dispatched as **concurrent Python threads**, each running an independent `generate_variation_batch(batch_size=1, num_tokens=own_tokens)` call.

Total time ≈ time for slowest slot (spice=1.0, most tokens).

### Thread Safety

Each thread constructs its own `idx` and `hidden` tensors locally. PyTorch inference with `torch.no_grad()` and independent input tensors is thread-safe. No shared mutable state between threads during generation.

---

## Changes

### 1. `rhythmic_creator_variation()` — drop batch_size=3

Remove `BATCH_SIZE = 3`, candidate scoring, and best-of-N selection. Change to `batch_size=1`. Return the single generated pattern directly (with fallback if invalid).

Before:
```python
BATCH_SIZE = 3
generated_texts = rhythmic_model.generate_variation_batch(batch_size=BATCH_SIZE, ...)
candidates = [...]  # score and pick best
```

After:
```python
generated_texts = rhythmic_model.generate_variation_batch(batch_size=1, ...)
candidate = rhythmic_creator_to_chuloopa(generated_texts[0], loop_duration=loop_dur)
if not candidate.hits or len(candidate.hits) < 2:
    return generate_musical_variation(pattern, spice_level), False
```

### 2. `_generation_worker()` — parallel threads

Replace the serial queue loop with a thread-per-slot approach. When a full bank is requested:

1. Compute reachable slots from `current_ceiling`
2. Spawn one thread per slot — each thread:
   - Calls `generate_variation(pattern, type, temperature=spice)` (which calls the updated `rhythmic_creator_variation`)
   - Saves result to `track_0_drums_var{slot}.txt`
   - Sends `/chuloopa/bank_progress slot` OSC message
3. `bank_ready` fires as soon as the **first slot completes** (slot 1, lowest spice = fewest tokens = first to finish)
4. Worker waits for all threads to finish before updating `bank_generation_ceiling`

### 3. `start_full_bank_generation()` — simplify

Remove Stage 1 / Stage 2 split and sentinel (-1) from the queue. The parallel approach makes staged generation unnecessary — `bank_ready` is sent as soon as any slot is ready.

---

## Sequence Diagram

```
on_file_change / handle_regenerate
        |
        v
cancel_generation()
        |
        v
start_full_bank_generation()
  - compute slots from ceiling
  - spawn thread per slot
        |
   [threads run in parallel]
        |
  thread(slot=1) finishes first
        ├── save var1.txt
        ├── send /chuloopa/bank_progress 1
        └── send /chuloopa/bank_ready 0   ← ChucK enables auto-switching
        |
  thread(slot=2) finishes
        ├── save var2.txt
        └── send /chuloopa/bank_progress 2
        |
  ... slots 3, 4, 5 complete ...
        |
  all threads joined
  bank_generation_ceiling updated
```

---

## Expected Timing

| Scenario | Old | New |
|---|---|---|
| Full bank (ceiling=1.0, 5 slots) | ~75s (15 serial calls) | ~15-20s (parallel) |
| Time to first `bank_ready` | ~45s (Stage 1: 3 slots) | ~8-12s (first slot done) |
| Stage 2 overhead | ~30s (2 more serial calls) | 0 (all parallel) |

---

## Error Handling

- If a thread's generation fails, fall back to `humanize_pattern()` for that slot (same as current fallback in `_generation_worker`)
- If all slots fail, no `bank_ready` is sent; ChucK remains in its current state
- `cancel_generation()` sets `stop_event` — threads should check this flag before starting (not mid-generation, as PyTorch ops are not interruptible)

---

## Out of Scope

- Changes to `chuloopa_drums_v4.ck` — it already listens to `bank_progress` and `bank_ready`
- Changes to the spice-to-token mapping formula
- Adding new spice slots or changing the 5-slot bank structure
