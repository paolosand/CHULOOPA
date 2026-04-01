# Remove `/chuloopa/spice` OSC Send to Python Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the dead `/chuloopa/spice` OSC path from `spice_detector.ck` → Python (port 5000), delete the `current_spice_level` global and handler in `drum_variation_ai_v2.py`, and fix the latent gemini kwarg bug where slot spice was silently ignored.

**Architecture:** In v4, each bank slot has a fixed spice level (`[0.2, 0.4, 0.6, 0.8, 1.0][slot-1]`); `current_ceiling` (from `/chuloopa/spice_ceiling`) controls which slots get generated. `current_spice_level` is never used in the bank generation path. `spice_detector.ck` will continue sending to port 5001 (ChucK v4) unchanged.

**Tech Stack:** ChucK (OSC I/O), Python 3.10+, python-osc (`pythonosc`)

---

## Files Modified

- `src/spice_detector.ck` — remove port 5000 OscOut and send; update header + startup print
- `src/drum_variation_ai_v2.py` — delete `current_spice_level` global, `handle_spice_change()`, dispatcher mapping; fix gemini kwarg; clean up logging

---

### Task 1: Simplify `sendSpice()` in `spice_detector.ck`

**Files:**
- Modify: `src/spice_detector.ck`

- [ ] **Step 1: Remove `OSC_PORT_PYTHON` constant (line 56)**

Remove this line:
```chuck
5000 => int OSC_PORT_PYTHON;   // Python drum_variation_ai.py
```

- [ ] **Step 2: Remove `oout_python` OscOut setup (lines 104–105)**

Remove these two lines:
```chuck
OscOut oout_python;
oout_python.dest("127.0.0.1", OSC_PORT_PYTHON);
```

- [ ] **Step 3: Simplify `sendSpice()` to send only to ChucK (lines 110–118)**

Replace the entire function:
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

- [ ] **Step 4: Update the header comment (lines 1–23)**

Replace the `OSC Output:` block in the header:
```chuck
// OSC Output:
//   /chuloopa/spice <float 0.0-1.0>
//   → Python (127.0.0.1:5000)
//   → ChucK v4 (127.0.0.1:5001)
```

With:
```chuck
// OSC Output:
//   /chuloopa/spice <float 0.0-1.0>
//   → ChucK v4 (127.0.0.1:5001)
```

Also remove from the file description line 7:
```chuck
//       Sends spice via OSC to both Python (port 5000)
//       and ChucK v4 (port 5001) every 500ms.
```

Replace with:
```chuck
//       Sends spice via OSC to ChucK v4 (port 5001) every 500ms.
```

- [ ] **Step 5: Update startup console print (around line 422–424)**

Replace:
```chuck
<<< "OSC Output:" >>>;
<<< "  Python (port:", OSC_PORT_PYTHON, ")" >>>;
<<< "  ChucK v4 (port:", OSC_PORT_CHUCK, ")" >>>;
```

With:
```chuck
<<< "OSC Output:" >>>;
<<< "  ChucK v4 (port:", OSC_PORT_CHUCK, ")" >>>;
```

- [ ] **Step 6: Verify the file compiles**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
chuck --syntax src/spice_detector.ck 2>&1 | head -20
```

Expected: No errors (or only warnings about audio device if run without audio context — that's fine).

- [ ] **Step 7: Commit**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/spice_detector.ck
git commit -m "refactor: remove /chuloopa/spice OSC send to Python port 5000 from spice_detector

spice_detector.ck now sends only to ChucK v4 (port 5001).
Python bank generation is ceiling-driven; current_spice_level was dead code.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Delete `current_spice_level` global and `handle_spice_change` in `drum_variation_ai_v2.py`

**Files:**
- Modify: `src/drum_variation_ai_v2.py`

- [ ] **Step 1: Remove `current_spice_level` global (line 100)**

Remove this line from the global state block:
```python
current_spice_level = 0.5  # Default spice level
```

- [ ] **Step 2: Delete `handle_spice_change()` function (lines 1129–1133)**

Remove the entire function:
```python
def handle_spice_change(address, spice_level):
    """Handle spice level change from ChucK."""
    global current_spice_level
    current_spice_level = max(0.0, min(1.0, spice_level))
    print(f"\n>>> OSC RECEIVED from ChucK: /chuloopa/spice = {current_spice_level:.2f} <<<\n")
```

- [ ] **Step 3: Remove the `/chuloopa/spice` dispatcher mapping (line 1536)**

Remove this line from the dispatcher setup block:
```python
disp.map("/chuloopa/spice", handle_spice_change)
```

- [ ] **Step 4: Verify no remaining references to `current_spice_level`**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
grep -n "current_spice_level" drum_variation_ai_v2.py
```

Expected output (lines that still need fixing in Task 3):
```
1188:    global osc_client, current_spice_level
1201:    print(f"  Current spice level: {current_spice_level:.2f}")
1211:    print(f"\n  Generating variation (spice: {current_spice_level:.2f})")
1212:    varied, success = generate_variation(pattern, variation_type, temperature=current_spice_level)
1241:    print(f"\n✓ Generated variation (spice: {current_spice_level:.2f})")
1243:    print(f"\n✗ Generation FAILED - used fallback (spice: {current_spice_level:.2f})")
1560:    print(f"Current spice level: {current_spice_level:.2f}")
1612:        return gemini_variation(pattern, spice_level=kwargs.get('spice_level', current_spice_level))
1706:    print(f"  Using spice level: {current_spice_level:.2f}")
1720:    print(f"\n  Generating variation (spice: {current_spice_level:.2f})")
```

---

### Task 3: Clean up `generate_variations_for_track()` references

**Files:**
- Modify: `src/drum_variation_ai_v2.py`

This is the legacy single-var generation function (not called in v4 bank path). It still works via CLI but no longer has a live spice value. Replace `current_spice_level` with the literal default `0.5`.

- [ ] **Step 1: Fix the `global` declaration (line 1188)**

Replace:
```python
    global osc_client, current_spice_level
```
With:
```python
    global osc_client
```

- [ ] **Step 2: Remove the spice print (line 1201)**

Remove this line:
```python
    print(f"  Current spice level: {current_spice_level:.2f}")
```

- [ ] **Step 3: Fix generation call and its log (lines 1211–1212)**

Replace:
```python
    print(f"\n  Generating variation (spice: {current_spice_level:.2f})")
    varied, success = generate_variation(pattern, variation_type, temperature=current_spice_level)
```
With:
```python
    print(f"\n  Generating variation (spice: 0.5 default)")
    varied, success = generate_variation(pattern, variation_type, temperature=0.5)
```

- [ ] **Step 4: Fix success/failure prints (lines 1241–1243)**

Replace:
```python
    if success:
        print(f"\n✓ Generated variation (spice: {current_spice_level:.2f})")
    else:
        print(f"\n✗ Generation FAILED - used fallback (spice: {current_spice_level:.2f})")
        print(f"  Press D#1 in ChucK to try again")
```
With:
```python
    if success:
        print(f"\n✓ Generated variation")
    else:
        print(f"\n✗ Generation FAILED - used fallback")
        print(f"  Press D#1 in ChucK to try again")
```

---

### Task 4: Clean up `watch_directory()` startup print and `generate_variation_for_file()`

**Files:**
- Modify: `src/drum_variation_ai_v2.py`

- [ ] **Step 1: Remove spice print from `watch_directory()` startup block (line 1560)**

Remove this line:
```python
    print(f"Current spice level: {current_spice_level:.2f}")
```

- [ ] **Step 2: Fix `generate_variation_for_file()` spice references (lines 1706 and 1720)**

Replace:
```python
        print(f"  Using spice level: {current_spice_level:.2f}")
```
With:
```python
        print(f"  Using spice level: 0.5 (default)")
```

Replace:
```python
        print(f"\n  Generating variation (spice: {current_spice_level:.2f})")
```
With:
```python
        print(f"\n  Generating variation")
```

---

### Task 5: Fix the gemini kwarg bug in `generate_variation()`

**Files:**
- Modify: `src/drum_variation_ai_v2.py`

The bank worker calls `generate_variation(pattern, type, temperature=spice)` where `spice = [0.2, 0.4, 0.6, 0.8, 1.0][slot-1]`. But `gemini_variation` looks for `spice_level` kwarg, not `temperature`, so the slot spice was silently dropped and fell back to `current_spice_level`. Fix it to fall back to `temperature` instead.

- [ ] **Step 1: Fix the gemini kwarg lookup (line 1612)**

Replace:
```python
    elif variation_type == 'gemini':
        return gemini_variation(pattern, spice_level=kwargs.get('spice_level', current_spice_level))
```
With:
```python
    elif variation_type == 'gemini':
        return gemini_variation(pattern, spice_level=kwargs.get('spice_level', kwargs.get('temperature', 0.5)))
```

---

### Task 6: Update OSC docstring and verify no remaining references

**Files:**
- Modify: `src/drum_variation_ai_v2.py`

- [ ] **Step 1: Remove `/chuloopa/spice` from the OSC docstring (lines 1812–1813)**

Replace:
```python
OSC Communication:
    Receives on port 5000:
      /chuloopa/spice <float>        - Spice level (0.0-1.0)
      /chuloopa/regenerate           - Regenerate variations
      /chuloopa/track_cleared        - Track cleared notification
```
With:
```python
OSC Communication:
    Receives on port 5000:
      /chuloopa/regenerate           - Regenerate variations
      /chuloopa/track_cleared        - Track cleared notification
      /chuloopa/spice_ceiling <float> - Spice ceiling from CC 74 (0.0-1.0)
```

- [ ] **Step 2: Verify no remaining `current_spice_level` references**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
grep -n "current_spice_level\|handle_spice_change\|chuloopa/spice\"" drum_variation_ai_v2.py
```

Expected: No output (zero matches).

- [ ] **Step 3: Verify the script imports and parses without errors**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python -c "import drum_variation_ai_v2; print('OK')"
```

Expected:
```
OK
```

- [ ] **Step 4: Commit all Python changes**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
git add src/drum_variation_ai_v2.py
git commit -m "refactor: remove current_spice_level and fix gemini kwarg bug in drum_variation_ai_v2

- Delete current_spice_level global (dead in v4 bank path)
- Delete handle_spice_change() OSC handler
- Remove /chuloopa/spice dispatcher mapping
- Fix gemini spice kwarg: fall back to temperature= not current_spice_level
- Clean up logging references in generate_variations_for_track and generate_variation_for_file
- Update OSC docstring to reflect actual received messages

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 7: Manual smoke test

No automated test suite exists. Verify the v4 pipeline starts cleanly with the three-terminal workflow.

- [ ] **Step 1: Start Python watch mode and confirm no spice handler in logs**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python drum_variation_ai_v2.py --watch 2>&1 | head -30
```

Expected: Startup prints OSC server listening on port 5000. No mention of `current_spice_level`. No `AttributeError` or `NameError`. Stop with Ctrl+C.

- [ ] **Step 2: Run spice_detector and confirm it sends only to port 5001**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
chuck spice_detector.ck 2>&1 | head -20
```

Expected: Startup prints show only `ChucK v4 (port: 5001)` under `OSC Output:`. No port 5000 line. Stop with Ctrl+C.

- [ ] **Step 3: Confirm ceiling-based bank generation still works end-to-end**

With the full v4 pipeline running (all three terminals), record a loop with Note 36. Confirm:
- Python console shows bank generation starting (not spice level)
- ChucK v4 shows `bank_ready` received
- Weighted variation selection fires at loop boundaries

