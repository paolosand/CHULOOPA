# Parallel Bank Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace sequential 5-slot bank generation (5 serial calls × batch_size=3 = ~75s) with parallel per-slot threads + mid-generation cancellation via stop_event, reducing time-to-first-variation to ~8-12s.

**Architecture:** Each spice slot runs in its own thread calling `generate_variation_batch(batch_size=1)`. A coordinator thread joins them in slot order and fires `/chuloopa/bank_ready` when slot 1 completes. `stop_event` is threaded through the call chain into the model's token loop for ~50-150ms cancellation latency. Track-cleared deletes stale variation files immediately.

**Tech Stack:** Python 3.10+, PyTorch (MPS/CPU), python-osc, threading, pathlib

**Spec:** `docs/superpowers/specs/2026-03-31-parallel-bank-generation-design.md`

---

## File Map

| File | Change |
|---|---|
| `src/rhythmic_creator_model.py` | Add optional `stop_event` param to `generate_variation_batch` (line ~168) and `_generate_with_temperature` (line ~216) |
| `src/drum_variation_ai_v2.py` | (1) Pass global `stop_event` inside `rhythmic_creator_variation` (~line 868); (2) drop `batch_size=3` and candidate scoring (~lines 860-909); (3) new `_run_slot_thread`; (4) parallel `_generation_worker`; (5) atomic `start_full_bank_generation`; (6) no-timeout `cancel_generation`; (7) `handle_track_cleared` with file deletion |

---

## Task 1: Add stop_event to rhythmic_creator_model.py

**Files:**
- Modify: `src/rhythmic_creator_model.py:168-277`

The token generation loop in `_generate_with_temperature` runs `max_new_tokens` iterations. We add an optional `stop_event: threading.Event` that is checked at the top of each iteration. If set, the loop breaks early. The `stop_event` is threaded through `generate_variation_batch` → `_generate_with_temperature`.

- [ ] **Step 1: Add stop_event parameter to `_generate_with_temperature`**

In `src/rhythmic_creator_model.py`, change the signature and add the check at the top of the token loop. The `import time` and diagnostic code already exist — preserve them, just add the `stop_event` param and the break:

```python
def _generate_with_temperature(self,
                               idx: torch.Tensor,
                               hidden: tuple,
                               max_new_tokens: int,
                               temperature: float,
                               stop_event=None) -> torch.Tensor:
    import time  # DIAGNOSTIC
    token_times = []  # DIAGNOSTIC

    for i in range(max_new_tokens):
        # Mid-generation cancellation: check between token iterations (~50-150ms latency)
        if stop_event is not None and stop_event.is_set():
            break

        t0 = time.time()  # DIAGNOSTIC
        idx_crop = idx[:, -self.block_size:]
        logits, loss, h = self.model(self.device, idx_crop, hidden)
        logits = logits[:, -1, :]
        scaled_logits = logits / temperature
        probs = F.softmax(scaled_logits, dim=-1)
        idx_next = torch.multinomial(probs, num_samples=1)
        idx = torch.cat((idx, idx_next), dim=1)

        if i < 10:  # DIAGNOSTIC
            token_times.append(time.time() - t0)  # DIAGNOSTIC

    if token_times:  # DIAGNOSTIC
        avg_time = sum(token_times) / len(token_times)  # DIAGNOSTIC
        print(f"      [Model] Avg time/token (first 10): {avg_time*1000:.1f}ms, total tokens: {max_new_tokens}")  # DIAGNOSTIC

    return idx
```

- [ ] **Step 2: Add stop_event parameter to `generate_variation_batch`**

Change the signature and pass it through to `_generate_with_temperature`:

```python
def generate_variation_batch(self,
                             batch_size: int = 3,
                             input_pattern: str = None,
                             num_tokens: int = 300,
                             temperature: float = 1.0,
                             stop_event=None) -> list:
    if not input_pattern:
        context = torch.zeros((batch_size, 1), dtype=torch.long, device=self.device)
    else:
        input_tokens = input_pattern.split()
        try:
            encoded = self.processor.encode_with_mapping(input_tokens)
        except KeyError as e:
            raise ValueError(f"Unknown token in input pattern: {e}")
        single = torch.tensor([encoded], dtype=torch.long, device=self.device)
        context = single.repeat(batch_size, 1)

    hidden = self.model.init_hidden(batch_size=batch_size, device=self.device)

    with torch.no_grad():
        generated = self._generate_with_temperature(
            context, hidden, num_tokens, temperature, stop_event=stop_event
        )

    results = []
    for i in range(batch_size):
        decoded = self.processor.decode_with_mapping(generated[i].tolist())
        results.append(decoded)

    return results
```

- [ ] **Step 3: Verify stop_event interrupts generation**

Run this quick smoke test from `src/` to confirm the model exits early when stop_event is set:

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python - <<'EOF'
import threading, time
from rhythmic_creator_model import get_model

model = get_model()
stop = threading.Event()

def set_stop():
    time.sleep(0.3)
    stop.set()
    print("  [test] stop_event set")

t = threading.Thread(target=set_stop)
t.start()

t0 = time.time()
result = model.generate_variation_batch(
    batch_size=1,
    input_pattern="36 0.0 0.1 38 0.5 0.6 42 1.0 1.1",
    num_tokens=200,
    temperature=1.0,
    stop_event=stop
)
elapsed = time.time() - t0
t.join()

tokens = len(result[0].split())
print(f"  Generated {tokens} tokens in {elapsed:.2f}s (expected < 200 tokens if cancelled)")
assert elapsed < 5.0, f"Expected early exit, took {elapsed:.2f}s"
assert tokens < 200, f"Expected < 200 tokens, got {tokens}"
print("  PASS: stop_event interrupted generation early")
EOF
```

Expected: generation stops well before 200 tokens, elapsed < 5s.

- [ ] **Step 4: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/rhythmic_creator_model.py
git commit -m "feat: add stop_event mid-generation cancellation to rhythmic_creator_model"
```

---

## Task 2: Drop batch_size=3 and wire stop_event in rhythmic_creator_variation

**Files:**
- Modify: `src/drum_variation_ai_v2.py` (function `rhythmic_creator_variation`, lines ~860-951)

Two changes in one task:
1. Remove `BATCH_SIZE = 3`, the candidate loop (`candidates`, `score_candidate`, `scores`, `best_idx`), and all related print lines (lines ~860-909). The inline `score_candidate` function definition lives at lines ~898-904 — delete the whole function.
2. Pass the module-level `stop_event` global into `generate_variation_batch` so mid-generation cancellation is wired end-to-end.

- [ ] **Step 1: Replace batch generation + scoring with single generate call**

Find the block starting at `BATCH_SIZE = 3` (around line 860) and replace through to `print(f"    Selected candidate...")` with:

```python
print(f"  Generating variation with rhythmic_creator (temp={RHYTHMIC_CREATOR_TEMPERATURE:.2f}, spice={spice_level:.2f})...")
print(f"    Context: {len(pattern.hits)} hits, loop={pattern.loop_duration:.2f}s")
print(f"    Generating: {num_tokens} tokens (~{num_tokens//3} hits) (multiplier={token_multiplier:.1f}×)")

t0 = time.time()
generated_texts = rhythmic_model.generate_variation_batch(
    batch_size=1,
    input_pattern=context_text,
    num_tokens=num_tokens,
    temperature=RHYTHMIC_CREATOR_TEMPERATURE,
    stop_event=stop_event  # module-level global — allows mid-generation cancellation
)
t_generate = time.time() - t0
print(f"    ⏱️  MODEL GENERATION: {t_generate:.2f}s")

loop_dur = pattern.loop_duration
raw_pattern = rhythmic_creator_to_chuloopa(generated_texts[0], loop_duration=loop_dur)

if not raw_pattern.hits or len(raw_pattern.hits) < 2:
    print("  Warning: Generated pattern invalid, falling back")
    return generate_musical_variation(pattern, spice_level), False
```

The code continuing after this block (saving raw model output, timing anchor check) stays unchanged.

- [ ] **Step 2: Quick smoke test**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python -c "
import os
from drum_variation_ai_v2 import DrumPattern, rhythmic_creator_variation, init_rhythmic_creator
init_rhythmic_creator()
f = 'tracks/track_0/track_0_drums.txt'
if os.path.exists(f):
    p = DrumPattern.from_file(f)
    v, ok = rhythmic_creator_variation(p, spice_level=0.5)
    print(f'Generated {len(v.hits)} hits, success={ok}')
else:
    print('No track file — skipping (expected without recording)')
"
```

Expected: `Generated N hits, success=True` or skip message.

- [ ] **Step 3: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/drum_variation_ai_v2.py
git commit -m "feat: drop batch_size=3 and wire stop_event through rhythmic_creator_variation"
```

---

## Task 3: Add _run_slot_thread

**Files:**
- Modify: `src/drum_variation_ai_v2.py` (add new function after `generate_variation_bank`, ~line 1447)

Per-slot worker. Checks stop_event before starting and after generation returns. If cancelled at either point, discards result and does not write the file. Uses spice-scaled humanize fallback on exception.

- [ ] **Step 1: Add `_run_slot_thread` function**

Insert after the `generate_variation_bank` function:

```python
def _run_slot_thread(slot: int, pattern: DrumPattern):
    """Per-slot worker: generates one variation and saves it. Respects stop_event."""
    if stop_event.is_set():
        return  # cancelled before starting — don't write anything

    spice = [0.2, 0.4, 0.6, 0.8, 1.0][slot - 1]
    variations_dir = DEFAULT_VARIATIONS_DIR
    variations_dir.mkdir(parents=True, exist_ok=True)

    if osc_client:
        try:
            osc_client.send_message("/chuloopa/generation_progress",
                                    f"Generating var{slot}/5 (spice {spice:.1f})...")
        except Exception:
            pass

    try:
        varied, success = generate_variation(pattern, current_variation_type, temperature=spice)

        # Post-generation cancel check: discard if cancelled during generation
        if stop_event.is_set():
            return

        output_file = variations_dir / f"track_0_drums_var{slot}.txt"
        varied.to_file(str(output_file))
        print(f"  [Slot {slot}] Saved: {output_file.name} ({len(varied.hits)} hits, spice={spice:.1f})")
        if osc_client:
            try:
                osc_client.send_message("/chuloopa/bank_progress", slot)
            except Exception:
                pass

    except Exception as e:
        print(f"  [Slot {slot}] Generation failed: {e}")
        if stop_event.is_set():
            return  # cancelled — skip fallback too

        try:
            fallback = humanize_pattern(
                pattern,
                timing_variance=0.005 + 0.02 * spice,
                velocity_variance=0.05 + 0.1 * spice
            )
            output_file = variations_dir / f"track_0_drums_var{slot}.txt"
            fallback.to_file(str(output_file))
            print(f"  [Slot {slot}] Fallback saved")
            if osc_client:
                try:
                    osc_client.send_message("/chuloopa/bank_progress", slot)
                except Exception:
                    pass
        except Exception as e2:
            print(f"  [Slot {slot}] Fallback also failed: {e2}")
```

- [ ] **Step 2: Test pre-generation cancellation (stop_event set before call)**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python - <<'EOF'
from pathlib import Path
from drum_variation_ai_v2 import _run_slot_thread, stop_event, DrumPattern, DEFAULT_VARIATIONS_DIR

stop_event.set()

track_file = Path("tracks/track_0/track_0_drums.txt")
if not track_file.exists():
    print("No track file — skipping")
    stop_event.clear()
else:
    pattern = DrumPattern.from_file(str(track_file))
    var_file = DEFAULT_VARIATIONS_DIR / "track_0_drums_var1.txt"
    if var_file.exists():
        var_file.unlink()

    _run_slot_thread(1, pattern)

    assert not var_file.exists(), "File must NOT be written when stop_event pre-set"
    print("PASS: file not written when cancelled before start")
    stop_event.clear()
EOF
```

- [ ] **Step 3: Test mid-generation cancellation (stop_event set during call)**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python - <<'EOF'
import threading, time
from pathlib import Path
from drum_variation_ai_v2 import _run_slot_thread, stop_event, DrumPattern, DEFAULT_VARIATIONS_DIR, init_rhythmic_creator

init_rhythmic_creator()

track_file = Path("tracks/track_0/track_0_drums.txt")
if not track_file.exists():
    print("No track file — skipping")
else:
    pattern = DrumPattern.from_file(str(track_file))
    var_file = DEFAULT_VARIATIONS_DIR / "track_0_drums_var1.txt"
    if var_file.exists():
        var_file.unlink()

    # Set stop_event after 0.3s (mid-generation)
    def delayed_cancel():
        time.sleep(0.3)
        stop_event.set()
        print("  [test] stop_event set mid-generation")

    t = threading.Thread(target=delayed_cancel)
    t.start()

    t0 = time.time()
    _run_slot_thread(1, pattern)
    elapsed = time.time() - t0
    t.join()

    # File should NOT exist (cancelled mid-generation, post-generation guard fires)
    assert not var_file.exists(), f"File must not be written when cancelled mid-generation"
    print(f"PASS: file not written after mid-generation cancel (elapsed {elapsed:.2f}s)")
    stop_event.clear()
EOF
```

Expected: PASS, elapsed well under full generation time.

- [ ] **Step 4: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/drum_variation_ai_v2.py
git commit -m "feat: add _run_slot_thread with pre/mid-generation cancellation guards"
```

---

## Task 4: Implement parallel _generation_worker

**Files:**
- Modify: `src/drum_variation_ai_v2.py` (replace existing `_generation_worker`, ~line 1311)

Replace the serial queue-popping loop with a coordinator that snapshots and clears the queue atomically, spawns one thread per slot, joins them in slot order, and fires `bank_ready` when slot 1 completes.

Note on `spread_priority`: this function now only affects the `join` order (and thus when `bank_ready` fires), not actual generation order — all threads start simultaneously. The docstring on `spread_priority` is misleading; update it in Task 7.

- [ ] **Step 1: Replace `_generation_worker` with parallel coordinator**

```python
def _generation_worker():
    """Coordinator: spawns one thread per slot, joins in order, fires bank_ready on slot 1."""
    global bank_generation_ceiling

    variations_dir = DEFAULT_VARIATIONS_DIR
    variations_dir.mkdir(parents=True, exist_ok=True)

    track_file = DEFAULT_TRACK_DIR / "track_0_drums.txt"
    if not track_file.exists():
        print("  Worker: track file not found, aborting")
        return

    pattern = DrumPattern.from_file(str(track_file))
    if not pattern.hits:
        print("  Worker: no hits in pattern, aborting")
        return

    # Snapshot and clear queue atomically
    with generation_lock:
        slots = list(generation_queue)
        generation_queue.clear()

    if not slots:
        return

    print(f"\n  [Worker] Starting parallel generation: slots={slots}")

    # Spawn one thread per slot — all start simultaneously
    threads = {
        slot: threading.Thread(
            target=_run_slot_thread,
            args=(slot, pattern),
            daemon=True,
            name=f"slot-{slot}"
        )
        for slot in slots
    }
    for t in threads.values():
        t.start()

    completed_slots = set()
    bank_ready_sent = False

    # Join in slot order — bank_ready fires when slot 1 specifically completes
    for slot in slots:
        threads[slot].join()
        completed_slots.add(slot)
        print(f"  [Worker] Slot {slot} joined")

        if slot == 1 and not bank_ready_sent and osc_client:
            try:
                osc_client.send_message("/chuloopa/bank_ready", 0)
                osc_client.send_message("/chuloopa/generation_progress",
                                        "var1 ready — auto-switching enabled")
                bank_ready_sent = True
                print("  [Worker] bank_ready sent (slot 1 complete)")
            except Exception as e:
                print(f"  [Worker] OSC error sending bank_ready: {e}")

    # Fallback: slot 1 not in bank (ceiling too low to reach slot 1)
    if not bank_ready_sent and completed_slots and osc_client:
        lowest = min(completed_slots)
        try:
            osc_client.send_message("/chuloopa/bank_ready", 0)
            osc_client.send_message("/chuloopa/generation_progress",
                                    f"var{lowest} ready — auto-switching enabled")
            bank_ready_sent = True
        except Exception as e:
            print(f"  [Worker] OSC error sending bank_ready fallback: {e}")

    # All-fail case — notify ChucK
    if not bank_ready_sent and osc_client:
        try:
            osc_client.send_message("/chuloopa/generation_progress",
                                    "All slots failed — press D#1 to retry")
        except Exception as e:
            print(f"  [Worker] OSC error sending all-fail message: {e}")

    # Use the ceiling value that was set when this bank started (not current_ceiling,
    # which may have changed while threads were running)
    bank_generation_ceiling = current_ceiling
    print(f"  [Worker] Done. bank_generation_ceiling={bank_generation_ceiling:.2f}")
```

- [ ] **Step 2: Test parallel thread spawning — verify bank_ready fires on slot 1 not slot 5**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python - <<'EOF'
import threading, time
from pathlib import Path
from drum_variation_ai_v2 import (
    _generation_worker, generation_queue, generation_lock,
    DrumPattern, DEFAULT_VARIATIONS_DIR, DEFAULT_TRACK_DIR
)

track_file = DEFAULT_TRACK_DIR / "track_0_drums.txt"
if not track_file.exists():
    print("No track file — skipping")
else:
    # Clean up any existing var files
    for i in range(1, 6):
        f = DEFAULT_VARIATIONS_DIR / f"track_0_drums_var{i}.txt"
        if f.exists():
            f.unlink()

    # Queue all 5 slots
    with generation_lock:
        generation_queue.clear()
        generation_queue.extend([1, 2, 3, 4, 5])

    t0 = time.time()
    worker_thread = threading.Thread(target=_generation_worker)
    worker_thread.start()
    worker_thread.join()
    elapsed = time.time() - t0

    # All 5 slots should complete
    saved = sorted([f.name for f in DEFAULT_VARIATIONS_DIR.glob("track_0_drums_var*.txt")])
    print(f"Saved files: {saved}")
    print(f"Total time: {elapsed:.1f}s")

    # Sanity check: should be faster than 75s (old sequential time)
    assert elapsed < 60, f"Expected parallel speedup, took {elapsed:.1f}s"
    print("PASS: parallel generation completed")
EOF
```

Note: this test uses `--no-ai` implicitly via `use_no_ai`. If `use_no_ai=False` (default), it will run the actual model — which is correct for verifying real parallel speedup. Run with the real model if a track file is present.

- [ ] **Step 3: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/drum_variation_ai_v2.py
git commit -m "feat: parallel _generation_worker — one thread per slot, bank_ready on slot 1"
```

---

## Task 5: Atomic start_full_bank_generation + no-timeout cancel_generation

**Files:**
- Modify: `src/drum_variation_ai_v2.py` (`start_full_bank_generation` ~line 1396, `cancel_generation` ~line 1301)

`cancel_generation` is always called by callers before `start_full_bank_generation` (see `handle_regenerate`, `generate_variation_bank`, `DrumFileHandler.on_modified`). The function itself does not re-call `cancel_generation` — this is by design (callers own the cancel+start sequence). The important fix here is that the queue-clear in `cancel_generation` must be inside the lock, and queue-clear + coordinator-spawn in `start_full_bank_generation` must be in one atomic lock block.

- [ ] **Step 1: Replace `cancel_generation`**

```python
def cancel_generation():
    """Signal running generation to stop and wait for clean exit."""
    global generation_thread, generation_queue
    stop_event.set()
    if generation_thread and generation_thread.is_alive():
        generation_thread.join()  # no timeout — threads exit within ~150ms via stop_event
    stop_event.clear()  # cleared AFTER join — no race window
    with generation_lock:
        generation_queue.clear()
```

- [ ] **Step 2: Replace `start_full_bank_generation`**

```python
def start_full_bank_generation():
    """Start a fresh full bank at current_ceiling. Caller must call cancel_generation() first."""
    global bank_generation_ceiling, generation_thread

    slots = reachable_slots(current_ceiling)
    if not slots:
        print(f"Warning: No slots reachable at ceiling={current_ceiling:.2f} — skipping")
        if osc_client:
            osc_client.send_message("/chuloopa/generation_progress",
                                    f"Ceiling {current_ceiling:.2f} too low — no variations")
        return

    ordered = spread_priority(slots)
    bank_generation_ceiling = current_ceiling
    print(f"\n  Starting bank: ceiling={current_ceiling:.2f}, slots={ordered}")

    # Atomic: queue update + coordinator spawn under single lock
    with generation_lock:
        generation_queue.clear()
        generation_queue.extend(ordered)
        if generation_thread is None or not generation_thread.is_alive():
            generation_thread = threading.Thread(target=_generation_worker, daemon=True)
            generation_thread.start()
            print(f"  Coordinator thread started")
```

- [ ] **Step 3: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/drum_variation_ai_v2.py
git commit -m "feat: atomic start_full_bank_generation + no-timeout cancel_generation"
```

---

## Task 6: Update handle_track_cleared — cancel + delete variation files

**Files:**
- Modify: `src/drum_variation_ai_v2.py` (`handle_track_cleared`, ~line 1163)

- [ ] **Step 1: Replace `handle_track_cleared`**

```python
def handle_track_cleared(address):
    """Cancel in-progress generation and delete all stale variation files."""
    print("\n>>> OSC RECEIVED: /chuloopa/track_cleared — cancelling generation <<<")
    cancel_generation()

    # Delete all variation files — prevents stale files being loaded for new recording
    deleted = []
    for slot in range(1, 6):
        var_file = DEFAULT_VARIATIONS_DIR / f"track_0_drums_var{slot}.txt"
        if var_file.exists():
            var_file.unlink()
            deleted.append(f"var{slot}.txt")

    if deleted:
        print(f"  Deleted stale variation files: {', '.join(deleted)}")
    else:
        print("  No variation files to delete")

    if osc_client:
        try:
            osc_client.send_message("/chuloopa/generation_progress", "Cancelled — track cleared")
        except Exception as e:
            print(f"  OSC error: {e}")
```

- [ ] **Step 2: Test file deletion**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python - <<'EOF'
from pathlib import Path
from drum_variation_ai_v2 import handle_track_cleared, DEFAULT_VARIATIONS_DIR

DEFAULT_VARIATIONS_DIR.mkdir(parents=True, exist_ok=True)
for i in range(1, 4):
    f = DEFAULT_VARIATIONS_DIR / f"track_0_drums_var{i}.txt"
    f.write_text("# dummy\n")

print(f"Created: {[f.name for f in DEFAULT_VARIATIONS_DIR.glob('track_0_drums_var*.txt')]}")

handle_track_cleared("/chuloopa/track_cleared")

remaining = list(DEFAULT_VARIATIONS_DIR.glob("track_0_drums_var*.txt"))
assert len(remaining) == 0, f"Expected 0 files, found: {remaining}"
print("PASS: all variation files deleted on track_cleared")
EOF
```

Expected: `PASS: all variation files deleted on track_cleared`

- [ ] **Step 3: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/drum_variation_ai_v2.py
git commit -m "feat: handle_track_cleared cancels generation and deletes stale variation files"
```

---

## Task 7: Cleanup and integration smoke test

**Files:**
- Modify: `src/drum_variation_ai_v2.py` (remove sentinel logic, update `spread_priority` docstring)

- [ ] **Step 1: Remove stale sentinel logic**

Search for any remaining sentinel references and delete them:

```bash
grep -n "slot == -1\|== -1\|sentinel\|stage1_done\|Stage 1\|Stage 2\|stage1\|stage2" \
  "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src/drum_variation_ai_v2.py"
```

Delete any lines found that relate to the old `-1` sentinel / Stage 1 / Stage 2 pattern (these were in the old `_generation_worker` and `start_full_bank_generation`).

- [ ] **Step 2: Update `spread_priority` docstring**

Find `spread_priority` (~line 1269) and update its docstring to reflect that it now controls join order (not generation order), since all threads start simultaneously:

```python
def spread_priority(slots: list) -> list:
    """Reorder slots for join order: spread coverage across range first, fill gaps second.

    In the parallel model, all threads start simultaneously — this ordering controls
    when bank_ready fires (slot 1 first) and the join sequence, not generation order.

    Stage 1 (first to join): spread first, middle, last
    Stage 2 (later joins): fill gaps
    """
    ...  # implementation unchanged
```

- [ ] **Step 3: Commit cleanup**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/drum_variation_ai_v2.py
git commit -m "chore: remove stale sentinel logic, update spread_priority docstring"
```

- [ ] **Step 4: Manual end-to-end test (requires running system + recorded track)**

With a recorded track file at `src/tracks/track_0/track_0_drums.txt`, open two terminals:

**Terminal 1** — start watch mode with real AI:
```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python drum_variation_ai_v2.py --watch
```

**Terminal 2** — trigger regeneration:
```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python -c "
from pythonosc import udp_client
c = udp_client.SimpleUDPClient('127.0.0.1', 5000)
c.send_message('/chuloopa/regenerate', [])
print('Sent regenerate')
"
```

Expected in Terminal 1:
- `[Worker] Starting parallel generation: slots=[1, 2, 3, 4, 5]`
- Multiple `[Slot N]` lines interleaving (not strictly 1→2→3→4→5 sequential)
- `bank_ready sent (slot 1 complete)` appears before all slots finish
- Total time well under 75s

Note: to verify mid-generation cancellation through the real model (not `--no-ai`), send `/chuloopa/track_cleared` from Terminal 2 shortly after the regenerate — generation should stop within ~150ms and var files should be deleted.
