# Always Generate All Spice Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Python always generates all 5 spice-level variations; `chuloopa_main.ck` uses its local `spice_ceiling` to cap variation selection, without Python needing to know the ceiling at all.

**Architecture:** Remove the `/chuloopa/spice_ceiling` OSC message (ChucK → Python) and the ceiling-aware staged generation logic in `drum_variation_generator.py`. Python simply generates slots 1–5 at fixed spice levels [0.2, 0.4, 0.6, 0.8, 1.0] every time. `chuloopa_main.ck` already caps `effective_spice = min(detected_spice, spice_ceiling)` before calling `pickVariationByWeight`, so the ceiling still governs which variant gets selected at runtime without any Python involvement.

**Tech Stack:** Python 3.10+, ChucK, python-osc, `drum_variation_generator.py`, `chuloopa_main.ck`, `spice_detector.ck`

---

## File Map

| File | Change |
|------|--------|
| `src/drum_variation_generator.py` | Remove ceiling state, `handle_ceiling_change`, `reachable_slots`, `compute_new_slots`, `spread_priority`. Simplify `start_full_bank_generation` to always use all 5 slots. |
| `src/chuloopa_main.ck` | Remove the 3-line block in the CC 74 handler that sends `/chuloopa/spice_ceiling` to Python. |
| `src/spice_detector.ck` | Remove `oout_python` and the Python-directed send from `sendSpice` (Python no longer needs the raw spice signal). |

---

## Task 1: Strip ceiling OSC send from `chuloopa_main.ck`

**Files:**
- Modify: `src/chuloopa_main.ck:2127-2135`

The CC 74 handler currently sends `/chuloopa/spice_ceiling` to Python after updating the local `spice_ceiling` variable. The local variable update must stay; only the OSC send must go.

Current code (around line 2127):
```chuck
if(data1 == CC_SPICE_CEILING) {
    data2 / 127.0 => spice_ceiling;
    // Recalculate effective spice with new ceiling
    Math.min(detected_spice_level, spice_ceiling) => effective_spice;
    <<< "Spice ceiling:", (spice_ceiling * 100) $ int, "% | Effective:", (effective_spice * 100) $ int, "%" >>>;
    oout.start("/chuloopa/spice_ceiling");   // <-- DELETE THIS LINE
    spice_ceiling => oout.add;               // <-- DELETE THIS LINE
    oout.send();                             // <-- DELETE THIS LINE
}
```

- [ ] **Step 1: Remove the 3 OSC send lines**

Edit `src/chuloopa_main.ck` so the block reads:
```chuck
if(data1 == CC_SPICE_CEILING) {
    data2 / 127.0 => spice_ceiling;
    // Recalculate effective spice with new ceiling
    Math.min(detected_spice_level, spice_ceiling) => effective_spice;
    <<< "Spice ceiling:", (spice_ceiling * 100) $ int, "% | Effective:", (effective_spice * 100) $ int, "%" >>>;
}
```

- [ ] **Step 2: Grep to confirm no remaining `/chuloopa/spice_ceiling` sends in chuloopa_main.ck**

Run:
```bash
grep -n "spice_ceiling" src/chuloopa_main.ck
```
Expected: lines with the variable declaration/read (`CC_SPICE_CEILING`, `spice_ceiling =>`), but NO line containing `oout.*spice_ceiling`.

- [ ] **Step 3: Commit**

```bash
git add src/chuloopa_main.ck
git commit -m "refactor: remove /chuloopa/spice_ceiling OSC send to Python"
```

---

## Task 2: Remove Python-side ceiling handler and simplify bank generation

**Files:**
- Modify: `src/drum_variation_generator.py`

There are four pieces to remove/simplify, all in one commit:

**A. Remove ceiling global state (lines ~99-104)**

Delete these globals:
```python
current_ceiling = 1.0           # Updated via /chuloopa/spice_ceiling OSC
bank_generation_ceiling = -1.0  # -1 = no bank generated yet; updated before each generation pass
```

**B. Remove `reachable_slots`, `compute_new_slots`, `spread_priority` functions (lines ~1230-1271)**

Delete all three functions.

**C. Simplify `start_full_bank_generation` (lines ~1382-1405)**

Current:
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

Replace with:
```python
def start_full_bank_generation():
    """Start a fresh full bank (all 5 slots). Caller must call cancel_generation() first."""
    global generation_thread

    all_slots = [1, 2, 3, 4, 5]
    print(f"\n  Starting bank: slots={all_slots}")

    with generation_lock:
        generation_queue.clear()
        generation_queue.extend(all_slots)
        if generation_thread is None or not generation_thread.is_alive():
            generation_thread = threading.Thread(target=_generation_worker, daemon=True)
            generation_thread.start()
            print(f"  Coordinator thread started")
```

**D. Remove `handle_ceiling_change` function and its OSC registration (lines ~1147-1160 and ~1576)**

Delete the entire function:
```python
def handle_ceiling_change(address, new_ceiling):
    """Handle spice ceiling change from ChucK v4 CC 74."""
    global current_ceiling
    current_ceiling = max(0.0, min(1.0, new_ceiling))
    print(f"\n>>> OSC RECEIVED: /chuloopa/spice_ceiling = {current_ceiling:.2f} <<<\n")

    if (current_ceiling > bank_generation_ceiling + 0.1
            and bank_generation_ceiling >= 0.0
            and track_file_exists()):
        new_slots = compute_new_slots(current_ceiling, bank_generation_ceiling)
        if new_slots:
            print(f"  Ceiling raised: generating newly reachable slots {new_slots}")
            queue_generation(new_slots)
```

And remove the dispatcher registration line:
```python
disp.map("/chuloopa/spice_ceiling", handle_ceiling_change)
```

Also remove the `global bank_generation_ceiling` reference in `_generation_worker` and the line `bank_generation_ceiling = ceiling_at_start` inside it (search for both occurrences).

- [ ] **Step 1: Remove `current_ceiling` and `bank_generation_ceiling` globals**

In `drum_variation_generator.py`, delete lines:
```python
# Ceiling-aware staged bank generation state
current_ceiling = 1.0           # Updated via /chuloopa/spice_ceiling OSC
bank_generation_ceiling = -1.0  # -1 = no bank generated yet; updated before each generation pass
```

- [ ] **Step 2: Delete `reachable_slots`, `compute_new_slots`, `spread_priority`**

Delete all three function definitions. They span approximately lines 1230–1271.

- [ ] **Step 3: Delete `handle_ceiling_change` function**

Delete the entire `handle_ceiling_change` function (~lines 1147–1160).

- [ ] **Step 4: Rewrite `start_full_bank_generation`**

Replace the function body with the simplified version shown above (always uses all 5 slots).

- [ ] **Step 5: Remove `bank_generation_ceiling` references in `_generation_worker`**

Search the `_generation_worker` function for:
```python
global bank_generation_ceiling
```
and:
```python
bank_generation_ceiling = ceiling_at_start
```
and any reference to `ceiling_at_start`. Delete all of these lines.

- [ ] **Step 6: Remove OSC dispatcher registration for `/chuloopa/spice_ceiling`**

Find the line:
```python
disp.map("/chuloopa/spice_ceiling", handle_ceiling_change)
```
and delete it.

- [ ] **Step 7: Verify no remaining `ceiling` references that would cause NameError**

Run:
```bash
grep -n "ceiling\|reachable_slots\|spread_priority\|compute_new_slots\|bank_generation_ceiling" src/drum_variation_generator.py
```
Expected: zero matches.

- [ ] **Step 8: Smoke test — confirm Python starts without errors**

Run:
```bash
cd src && python drum_variation_generator.py --help
```
Expected: help text printed, no `NameError` or `AttributeError`.

- [ ] **Step 9: Commit**

```bash
git add src/drum_variation_generator.py
git commit -m "refactor: always generate all 5 spice variants, remove ceiling-aware staged generation"
```

---

## Task 3: Stop `spice_detector.ck` from sending spice to Python

**Files:**
- Modify: `src/spice_detector.ck:56,104-117`

Python no longer uses the raw spice signal (it doesn't adjust generation based on live spice). Remove the Python-directed OSC output from `spice_detector.ck`.

Current `sendSpice`:
```chuck
fun void sendSpice(float spice) {
    oout_python.start("/chuloopa/spice");
    spice => oout_python.add;
    oout_python.send();

    oout_chuck.start("/chuloopa/spice");
    spice => oout_chuck.add;
    oout_chuck.send();
}
```

And near the top:
```chuck
5000 => int OSC_PORT_PYTHON;   // Python drum_variation_generator.py
...
OscOut oout_python;
oout_python.dest("127.0.0.1", OSC_PORT_PYTHON);
```

- [ ] **Step 1: Remove `OSC_PORT_PYTHON` constant and `oout_python` setup**

Delete:
```chuck
5000 => int OSC_PORT_PYTHON;   // Python drum_variation_generator.py
```
and:
```chuck
OscOut oout_python;
oout_python.dest("127.0.0.1", OSC_PORT_PYTHON);
```

- [ ] **Step 2: Simplify `sendSpice` to ChucK-only**

Replace:
```chuck
fun void sendSpice(float spice) {
    oout_python.start("/chuloopa/spice");
    spice => oout_python.add;
    oout_python.send();

    oout_chuck.start("/chuloopa/spice");
    spice => oout_chuck.add;
    oout_chuck.send();
}
```
With:
```chuck
fun void sendSpice(float spice) {
    oout_chuck.start("/chuloopa/spice");
    spice => oout_chuck.add;
    oout_chuck.send();
}
```

- [ ] **Step 3: Update the startup banner to remove Python port reference**

Find the banner print block that says:
```chuck
<<< "  Python (port:", OSC_PORT_PYTHON, ")" >>>;
<<< "  ChucK v4 (port:", OSC_PORT_CHUCK, ")" >>>;
```
Replace with:
```chuck
<<< "  ChucK v4 (port:", OSC_PORT_CHUCK, ")" >>>;
```

- [ ] **Step 4: Verify no remaining `oout_python` or `OSC_PORT_PYTHON` references**

Run:
```bash
grep -n "oout_python\|OSC_PORT_PYTHON" src/spice_detector.ck
```
Expected: zero matches.

- [ ] **Step 5: Commit**

```bash
git add src/spice_detector.ck
git commit -m "refactor: stop sending spice to Python (Python no longer needs it)"
```

---

## Self-Review

**Spec coverage:**
- ✅ Python always generates all 5 variants → Task 2 (simplify `start_full_bank_generation`)
- ✅ `chuloopa_main.ck` keeps ceiling tracking → Task 1 (only removes OSC send, not the local logic)
- ✅ No more `/chuloopa/spice_ceiling` from ChucK to Python → Task 1
- ✅ `spice_detector.ck` stops sending to Python → Task 3

**Placeholder scan:** No TBDs. All code shown verbatim.

**Type consistency:** No type changes. All function signatures unchanged. `generation_queue` usage unchanged.

**Risk check:** `_generation_worker` references `ceiling_at_start` which is derived from `bank_generation_ceiling`; Task 2 Step 5 removes these. `queue_generation` (used by the old ceiling handler) is only called from `handle_ceiling_change` — which is deleted — so it can be left in place as a dead but harmless helper, or deleted too. Either is fine; leaving it avoids churn.
