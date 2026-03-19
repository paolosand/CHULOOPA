# drum_variation_ai_v2.py — Design Spec
**Date:** 2026-03-19
**Status:** Approved

---

## Overview

Two-part upgrade to `drum_variation_ai_v2.py`:

1. **Fix generation to match stable v1** — align `DrumHit` format, token count, output window, and anchor defaults with the working `drum_variation_ai.py` pipeline
2. **Ceiling-aware staged bank generation** — integrate live spice ceiling from `spice_detector.ck` to drive intelligent batch generation for the v4 pipeline

---

## Part 1: Fix Generation to Match Stable (v1)

### Problems in v2 vs. stable

| Issue | stable (v1) | v2 (broken) |
|---|---|---|
| `DrumHit` field | `midi_note` (GM MIDI: 36/38/42) | `drum_class` (0/1/2 legacy) |
| File format header | `MIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME` | `DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME` |
| Token count | `0.7 + spice * 2.3` (spice-driven, 0.7x–3.0x) | Fixed `2.5x` (ignores spice) |
| Model output window | 0→T (single loop) | 0→2T (echo + continuation) |
| `use_no_anchor` default | `True` (anchoring OFF) | `False` (anchoring ON) |
| Gemini spice | Controls hit density (multiplier) | Controls sampling temperature |
| Candidate scoring | Target based on spice multiplier | Target based on 2x hits over 2T |
| format_converters import | Imports `VALID_GM_DRUM_NOTES` | Missing |

### Fixes Required

**`DrumHit` dataclass:** rename `drum_class` → `midi_note`, update all references throughout the file (`copy()`, `to_file()`, `from_file()`, all algorithmic variation functions).

**`from_file()`:** update to handle both old `drum_class` (0/1/2) and new `midi_note` (GM) notation with backward-compat mapping `{0:36, 1:38, 2:42}` (already done in v1, copy to v2).

**`to_file()`:** update header to `MIDI_NOTE,TIMESTAMP,VELOCITY,DELTA_TIME` and write `midi_note` field.

**`rhythmic_creator_variation()`:**
- Token count: `token_multiplier = 0.7 + (spice_level * 2.3)`, `num_tokens = int(len(context_tokens) * token_multiplier)`
- Output window: `rhythmic_creator_to_chuloopa(gen_text, loop_duration=loop_dur)` (not `2 * loop_dur`)
- Candidate scoring: `target_count = len(pattern.hits) * (0.7 + spice_level * 2.3)` (matches token multiplier)

**`use_no_anchor` global default:** `True` (anchoring OFF by default, same as v1).

**`gemini_variation()`:** replace temperature-as-sampling-param with spice-as-hit-density (copy v1's `hit_multiplier = 0.7 + (spice_level * 1.3)` approach and updated system prompt).

**format_converters import:** add `VALID_GM_DRUM_NOTES` import alongside existing imports.

**Algorithmic variation functions:** update all references from `drum_class` to `midi_note`, update MIDI note values from `[0,1,2]` to `[36,38,42]` throughout `mutate_pattern`, `densify_pattern`, `timing_anchor`, `generate_musical_variation`, `simplify_pattern`, `groove_preserve`.

---

## Part 2: Ceiling-Aware Staged Bank Generation

### Bank Structure

5 slots: `track_0_drums_var1.txt` → `track_0_drums_var5.txt`

Spice levels are **fixed** at [0.2, 0.4, 0.6, 0.8, 1.0] — midpoints of ChucK's hardcoded selection zones:

```
effective_spice < 0.1  →  original
0.1 – 0.29             →  var1  (generated at spice=0.2)
0.3 – 0.49             →  var2  (generated at spice=0.4)
0.5 – 0.69             →  var3  (generated at spice=0.6)
0.7 – 0.89             →  var4  (generated at spice=0.8)
0.9 – 1.0              →  var5  (generated at spice=1.0)
```

Ceiling determines **how many slots are reachable**, not the spice levels themselves:

```
ceiling < 0.3   →  var1 only        (1 slot)
ceiling < 0.5   →  var1–2           (2 slots)
ceiling < 0.7   →  var1–3           (3 slots)
ceiling < 0.9   →  var1–4           (4 slots)
ceiling >= 0.9  →  var1–5           (5 slots)
ceiling = 0.0   →  no slots (skip generation, log warning)
```

Helper function:
```python
def reachable_slots(ceiling: float) -> list[int]:
    """Return list of var indices (1-5) reachable at given ceiling."""
    if ceiling < 0.1:
        return []
    elif ceiling < 0.3:
        return [1]
    elif ceiling < 0.5:
        return [1, 2]
    elif ceiling < 0.7:
        return [1, 2, 3]
    elif ceiling < 0.9:
        return [1, 2, 3, 4]
    else:
        return [1, 2, 3, 4, 5]
```

### Staged Generation

When a new recording is detected (file change watchdog) or D#1 is pressed, Python generates in two stages for fast initial coverage.

**Stage 1 — Spread (generated first, gives musical coverage across the range):**

Pick first, middle, and last of the reachable set:
```
5 reachable (ceiling >= 0.9):  var1, var3, var5
4 reachable (ceiling >= 0.7):  var1, var2, var4  (first, 2nd, last of 4)
3 reachable (ceiling >= 0.5):  var1, var2, var3  (all — no split)
≤ 2 reachable:                 all slots (no split)
```

After Stage 1 completes: send individual `/chuloopa/bank_progress N` for each Stage 1 slot (already done per-slot as they finish), then send `/chuloopa/bank_ready 0` to enable ChucK's auto-switching. The value `0` is ignored by the updated ChucK handler (see ChucK changes below) — it just sets the `bank_ready` flag.

**Stage 2 — Gap fill (background, continues while performer plays):**
```
5 reachable:  var2, var4
4 reachable:  var3
3+ reachable: nothing
```
Each completed slot sends `/chuloopa/bank_progress N`.

### Ceiling Change Handling

**New Python state:**
```python
current_ceiling = 1.0           # Updated via /chuloopa/spice_ceiling OSC
bank_generation_ceiling = -1.0  # -1 = no bank generated yet; updated before each generation pass
stop_event = threading.Event()  # Set to cancel in-progress generation thread
generation_lock = threading.Lock()  # Ensures one generation thread at a time
```

**`bank_generation_ceiling` lifecycle:**
- Initialized to `-1.0` (sentinel: no bank generated yet)
- Updated to `current_ceiling` immediately **before** starting a new bank generation (watchdog or D#1)
- Updated to `current_ceiling` after each ceiling-raise generation pass completes

**`/chuloopa/spice` (raw spice from spice_detector):** Python still receives this on port 5000 and updates `current_spice_level` for logging and status display. It does NOT trigger any generation. Generation is only triggered by: (1) file-change watchdog, (2) D#1 (`/chuloopa/regenerate`), (3) ceiling-raise (`/chuloopa/spice_ceiling`).

**New OSC handler:**
```python
def handle_ceiling_change(address, new_ceiling):
    global current_ceiling
    current_ceiling = max(0.0, min(1.0, new_ceiling))

    # Only act if ceiling is raised AND a bank has been generated AND a pattern exists
    if (current_ceiling > bank_generation_ceiling + 0.1
            and bank_generation_ceiling >= 0.0
            and track_file_exists()):
        new_slots = compute_new_slots(current_ceiling, bank_generation_ceiling)
        if new_slots:
            queue_generation(new_slots)
```

**`compute_new_slots(new_ceiling, old_ceiling)`:**
```python
def compute_new_slots(new_ceiling: float, old_ceiling: float) -> list[int]:
    """Return slots that are reachable at new_ceiling but were not at old_ceiling."""
    old_slots = set(reachable_slots(old_ceiling))
    new_slots = set(reachable_slots(new_ceiling))
    newly_reachable = sorted(new_slots - old_slots)
    # Apply Stage 1 spread priority: spread first, gaps second
    return spread_priority(newly_reachable)
```

**`queue_generation(slots)`:**
```python
def queue_generation(slots: list[int]):
    """Append slots to generation queue; start worker thread if not already running."""
    with generation_lock:
        generation_queue.extend(slots)
        if generation_thread is None or not generation_thread.is_alive():
            start_generation_worker()
```

**Generation worker thread:**
- Pops slots from `generation_queue` one at a time
- Generates each slot's variation at the fixed spice level for that slot
- Sends `/chuloopa/bank_progress N` after each slot
- Checks `stop_event.is_set()` between slots; exits early if set
- Updates `bank_generation_ceiling` to `current_ceiling` after completing all queued slots

### Concurrency and Cancellation

**Thread cancellation (for new recording or D#1):**
```python
def cancel_generation():
    """Signal the running generation thread to stop and wait for it."""
    stop_event.set()
    if generation_thread and generation_thread.is_alive():
        generation_thread.join(timeout=2.0)  # Wait up to 2s for clean exit
    stop_event.clear()
    generation_queue.clear()
```

**Watchdog (new recording):** calls `cancel_generation()` first, then resets `bank_generation_ceiling = current_ceiling` and starts a fresh full bank generation for all reachable slots.

**D#1 (`/chuloopa/regenerate`):** same as watchdog — calls `cancel_generation()`, resets state, generates full bank at current ceiling.

**Ceiling-raise:** does NOT cancel in-progress generation. Instead appends new slots to `generation_queue`. Worker picks them up after finishing the current slot.

### D#1 Regenerate Behavior in v2

Pressing D#1 sends `/chuloopa/regenerate`. In v2:
- Cancel any in-progress generation (call `cancel_generation()`)
- Clear `generation_queue`
- Set `bank_generation_ceiling = current_ceiling`
- Generate all reachable slots at `current_ceiling` using Stage 1/2 staged order
- Send `bank_progress N` per slot, `bank_ready 0` after Stage 1

This is identical to the watchdog trigger behavior — D#1 is a manual "regenerate full bank."

---

## ChucK v4 Changes Required

**1. Add `/chuloopa/spice_ceiling` send in CC 74 handler** (`chuloopa_drums_v4.ck`):
```chuck
// After: data2 / 127.0 => spice_ceiling;
oout.start("/chuloopa/spice_ceiling");
spice_ceiling => oout.add;
oout.send();
```

**2. Update `bank_ready` OSC handler** — remove the sequential slot-marking loop. Slots are now marked individually by `bank_progress` messages. `bank_ready` just sets the flag to enable auto-switching:
```chuck
else if(msg.address == "/chuloopa/bank_ready") {
    1 => bank_ready;
    1 => variations_ready;
    0 => generation_failed;
    <<< "Bank ready — auto-switching enabled" >>>;
}
```

---

## OSC Protocol Summary

| Direction | Message | Trigger |
|---|---|---|
| spice_detector → Python | `/chuloopa/spice <float>` | Every 500ms (updates display only, no generation) |
| ChucK v4 → Python | `/chuloopa/spice_ceiling <float>` | CC 74 change **(NEW)** |
| ChucK v4 → Python | `/chuloopa/regenerate` | D#1 press |
| ChucK v4 → Python | `/chuloopa/track_cleared` | C#1 press (existing) |
| Python → ChucK v4 | `/chuloopa/bank_progress <int>` | Each slot complete (slot index N) |
| Python → ChucK v4 | `/chuloopa/bank_ready 0` | After Stage 1 complete (enables auto-switching) |
| Python → ChucK v4 | `/chuloopa/generation_progress <str>` | Status updates |
| Python → ChucK v4 | `/chuloopa/error <str>` | On failure |

---

## Files Changed

- `src/drum_variation_ai_v2.py` — all Part 1 + Part 2 changes above
- `src/chuloopa_drums_v4.ck` — add `/chuloopa/spice_ceiling` send + update `bank_ready` handler
