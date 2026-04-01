# Design: Remove `/chuloopa/spice` OSC Send to Python

**Date:** 2026-04-01
**Status:** Approved

## Problem

In the v4 pipeline, `spice_detector.ck` sends `/chuloopa/spice` to two destinations:
- Port 5001 → `chuloopa_drums_v4.ck` (used for audio-driven variation selection)
- Port 5000 → `drum_variation_ai_v2.py` (updates `current_spice_level` — **dead code**)

The bank generation in `drum_variation_ai_v2.py` is driven entirely by `current_ceiling` (from `/chuloopa/spice_ceiling`, sent by CC 74 in `chuloopa_drums_v4.ck`). Each bank slot has a fixed spice level (`[0.2, 0.4, 0.6, 0.8, 1.0][slot-1]`) that is independent of `current_spice_level`. The only paths where `current_spice_level` could matter are:
1. `generate_variations_for_track()` — legacy single-var function, not called in v4
2. `gemini_variation()` fallback — but a latent bug means slot spice doesn't reach it anyway (`temperature=spice` is passed but `spice_level=` is looked for)

## Approach: Surgical Removal (Option A)

Remove the dead OSC path and fix the latent gemini kwarg bug. No restructuring.

## Changes

### `spice_detector.ck`

- Remove `OSC_PORT_PYTHON` constant and `oout_python` OscOut
- Simplify `sendSpice()` to send only to port 5001 (ChucK)
- Update header comment and startup console print to remove port 5000 reference

### `drum_variation_ai_v2.py`

1. **Delete** `current_spice_level = 0.5` global variable
2. **Delete** `handle_spice_change()` function
3. **Remove** `disp.map("/chuloopa/spice", handle_spice_change)` dispatcher registration
4. **Fix gemini kwarg bug** in `generate_variation()`:
   - Change: `kwargs.get('spice_level', current_spice_level)`
   - To: `kwargs.get('spice_level', kwargs.get('temperature', 0.5))`
5. **Remove** logging lines in `generate_variations_for_track()` that reference `current_spice_level`
6. **Remove** `/chuloopa/spice` from the OSC docstring in `main()`

## What Is NOT Changed

- Port 5001 send in `spice_detector.ck` (ChucK still receives spice)
- `current_ceiling` and `handle_ceiling_change()` (ceiling path is active and correct)
- `generate_variations_for_track()` function itself (legacy, may still be called via CLI)
- Bank generation logic, slot spice assignments, or any other generation code
