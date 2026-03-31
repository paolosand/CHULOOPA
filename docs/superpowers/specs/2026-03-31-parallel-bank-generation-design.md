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

Each thread constructs its own `idx` and `hidden` tensors locally inside `generate_variation_batch()`. PyTorch inference with `torch.no_grad()` and independent input tensors is thread-safe. No shared mutable state is written during generation.

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

### 2. New `_run_slot_thread(slot, pattern)` — per-slot worker

Extract slot generation logic into a standalone function (not a method) suitable for threading:

```python
def _run_slot_thread(slot: int, pattern: DrumPattern):
    if stop_event.is_set():
        return  # cancelled before we started — do not write any file

    spice = [0.2, 0.4, 0.6, 0.8, 1.0][slot - 1]
    try:
        varied, success = generate_variation(pattern, current_variation_type, temperature=spice)
        output_file = DEFAULT_VARIATIONS_DIR / f"track_0_drums_var{slot}.txt"
        varied.to_file(str(output_file))
        if osc_client:
            osc_client.send_message("/chuloopa/bank_progress", slot)
    except Exception as e:
        # Spice-scaled fallback (preserves feel at each spice level)
        fallback = humanize_pattern(
            pattern,
            timing_variance=0.005 + 0.02 * spice,
            velocity_variance=0.05 + 0.1 * spice
        )
        output_file = DEFAULT_VARIATIONS_DIR / f"track_0_drums_var{slot}.txt"
        fallback.to_file(str(output_file))
        if osc_client:
            osc_client.send_message("/chuloopa/bank_progress", slot)
```

### Mid-generation cancellation via `stop_event`

`_generate_with_temperature` runs a Python for-loop over tokens. Each iteration is interruptible between tokens (~50-150ms per token on MPS). `stop_event` is passed through `generate_variation_batch` → `_generate_with_temperature` and checked at the **top of each token iteration**:

```python
for i in range(max_new_tokens):
    if stop_event is not None and stop_event.is_set():
        break  # exit early — generation incomplete
    logits, loss, h = self.model(...)
    ...
```

This requires adding an optional `stop_event` parameter to both `generate_variation_batch` and `_generate_with_temperature` in `rhythmic_creator_model.py`.

In `_run_slot_thread`, if generation is cancelled mid-loop the returned pattern will have fewer hits than intended. **Discard it — do not write the file for that slot.** The incomplete pattern is not musically useful.

Updated `_run_slot_thread` cancellation guard:

```python
def _run_slot_thread(slot: int, pattern: DrumPattern):
    if stop_event.is_set():
        return  # cancelled before starting

    spice = [0.2, 0.4, 0.6, 0.8, 1.0][slot - 1]
    try:
        varied, success = generate_variation(pattern, current_variation_type, temperature=spice)
        if stop_event.is_set():
            return  # cancelled during generation — discard result, do not write file
        output_file = DEFAULT_VARIATIONS_DIR / f"track_0_drums_var{slot}.txt"
        varied.to_file(str(output_file))
        if osc_client:
            osc_client.send_message("/chuloopa/bank_progress", slot)
    except Exception as e:
        if stop_event.is_set():
            return  # cancelled — skip fallback too
        fallback = humanize_pattern(
            pattern,
            timing_variance=0.005 + 0.02 * spice,
            velocity_variance=0.05 + 0.1 * spice
        )
        output_file = DEFAULT_VARIATIONS_DIR / f"track_0_drums_var{slot}.txt"
        fallback.to_file(str(output_file))
        if osc_client:
            osc_client.send_message("/chuloopa/bank_progress", slot)
```

### 3. `_generation_worker()` — parallel coordinator

Replace the serial queue loop with a parallel thread coordinator:

```python
def _generation_worker():
    variations_dir = DEFAULT_VARIATIONS_DIR
    variations_dir.mkdir(parents=True, exist_ok=True)

    track_file = DEFAULT_TRACK_DIR / "track_0_drums.txt"
    if not track_file.exists():
        return

    pattern = DrumPattern.from_file(str(track_file))
    if not pattern.hits:
        return

    slots = list(generation_queue)  # snapshot before clearing

    # Spawn one thread per slot
    threads = {slot: threading.Thread(target=_run_slot_thread, args=(slot, pattern), daemon=True)
               for slot in slots}
    for t in threads.values():
        t.start()

    completed_slots = set()
    bank_ready_sent = False

    # Wait for each thread and send bank_ready when slot 1 specifically is done
    for slot in slots:
        threads[slot].join()  # no timeout — generation is not interruptible
        completed_slots.add(slot)

        if slot == 1 and not bank_ready_sent and osc_client:
            osc_client.send_message("/chuloopa/bank_ready", 0)
            osc_client.send_message("/chuloopa/generation_progress", "var1 ready — auto-switching enabled")
            bank_ready_sent = True

    # Handle case where slot 1 was not reachable (ceiling too low to include slot 1)
    # bank_ready fires on the lowest available slot instead
    if not bank_ready_sent and completed_slots and osc_client:
        lowest = min(completed_slots)
        osc_client.send_message("/chuloopa/bank_ready", 0)
        osc_client.send_message("/chuloopa/generation_progress",
                                f"var{lowest} ready — auto-switching enabled (slot 1 not in bank)")
        bank_ready_sent = True

    # All-fail case: if no files were written, notify ChucK
    if not bank_ready_sent and osc_client:
        osc_client.send_message("/chuloopa/generation_progress",
                                "All slots failed — press D#1 to retry")

    global bank_generation_ceiling
    bank_generation_ceiling = current_ceiling
```

**`bank_ready` is gated on slot 1 completion specifically**, not whichever thread finishes first. The `join()` loop iterates over slots in order, so even if slot 1's thread finishes after another thread, we detect its completion and send `bank_ready` at that point.

### 4. `start_full_bank_generation()` — atomically clear queue and start coordinator

Both the queue clear and thread spawn happen under a single lock acquisition to prevent interleaving with concurrent OSC messages:

```python
def start_full_bank_generation():
    global bank_generation_ceiling, generation_thread

    slots = reachable_slots(current_ceiling)
    if not slots:
        if osc_client:
            osc_client.send_message("/chuloopa/generation_progress",
                                    f"Ceiling {current_ceiling:.2f} too low — no variations")
        return

    ordered = spread_priority(slots)
    bank_generation_ceiling = current_ceiling

    with generation_lock:
        generation_queue.clear()
        generation_queue.extend(ordered)
        # Spawn coordinator only if not already running
        if generation_thread is None or not generation_thread.is_alive():
            generation_thread = threading.Thread(target=_generation_worker, daemon=True)
            generation_thread.start()
```

Queue clear + coordinator spawn are now atomic under `generation_lock`, eliminating the window between the two separate lock blocks in the current code.

### 5. `handle_track_cleared()` — cancel generation and delete variation files

When ChucK sends `/chuloopa/track_cleared`, the source pattern no longer exists. Any in-progress or completed variations are now stale and must be discarded:

```python
def handle_track_cleared(address):
    print("Track cleared — cancelling generation and deleting variation files")
    cancel_generation()

    # Delete all variation files so stale variations can't be loaded
    for slot in range(1, 6):
        var_file = DEFAULT_VARIATIONS_DIR / f"track_0_drums_var{slot}.txt"
        if var_file.exists():
            var_file.unlink()

    if osc_client:
        osc_client.send_message("/chuloopa/generation_progress", "Cancelled — track cleared")
```

This ensures that if the user records a new pattern immediately after clearing, ChucK cannot accidentally load variations from the previous recording.

### 6. `cancel_generation()` — no timeout join

Remove the 2-second join timeout. With mid-generation `stop_event` checks between token iterations, in-progress threads will exit within ~50-150ms of `stop_event` being set. `cancel_generation()` blocks until the coordinator thread and all sub-threads finish cleanly:

```python
def cancel_generation():
    global generation_thread, generation_queue
    stop_event.set()
    if generation_thread and generation_thread.is_alive():
        generation_thread.join()  # no timeout — wait for clean finish
    stop_event.clear()
    with generation_lock:
        generation_queue.clear()
```

`stop_event.clear()` is called **after** `join()` completes, ensuring no thread is still running when the flag is reset.

---

## Sequence Diagrams

### Normal flow (new recording)

```
on_file_change / handle_regenerate
        |
        v
cancel_generation()
  - stop_event.set()
  - join coordinator (~50-150ms, mid-generation exit)
  - stop_event.clear()
        |
        v
start_full_bank_generation()
  - compute slots from ceiling
  - [generation_lock] clear queue, extend, spawn coordinator
        |
        v
_generation_worker() (coordinator thread)
  - snapshot slots from queue
  - spawn thread per slot
        |
   [threads run in parallel]
        |
  thread(slot=1) finishes (fewest tokens, usually first)
        ├── save var1.txt
        ├── send /chuloopa/bank_progress 1
        [coordinator join loop detects slot 1 done]
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

### Track cleared mid-generation

```
ChucK sends /chuloopa/track_cleared
        |
        v
handle_track_cleared()
        |
        v
cancel_generation()
  - stop_event.set()
  - threads check stop_event between token iterations → break early (~50-150ms)
  - join coordinator (returns quickly)
  - stop_event.clear()
        |
        v
  delete var1.txt … var5.txt (stale files from previous pattern)
        |
        v
  send /chuloopa/generation_progress "Cancelled — track cleared"
```

---

## Expected Timing

| Scenario | Old | New |
|---|---|---|
| Full bank (ceiling=1.0, 5 slots) | ~75s (15 serial calls) | ~15-20s (parallel) |
| Time to first `bank_ready` | ~45s (Stage 1: 3 serial slots) | ~8-12s (slot 1 done) |

---

## Files Changed

- `src/drum_variation_ai_v2.py` — main changes (worker, slot thread, cancellation, track-cleared handler)
- `src/rhythmic_creator_model.py` — add optional `stop_event` param to `generate_variation_batch` and `_generate_with_temperature`

## Out of Scope

- Changes to `chuloopa_drums_v4.ck` — it already listens to `bank_progress` and `bank_ready`
- Changes to the spice-to-token mapping formula
- Adding new spice slots or changing the 5-slot bank structure
