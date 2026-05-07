# Design Spec: Rhythmic Creator SUMMARY.md + INTEGRATION.md

**Date:** 2026-04-23  
**Status:** Approved

## Goal

Two concise reference documents to support evaluation of Jake's Rhythmic Creator model variants in the CHULOOPA real-time co-creative system.

## File 1: `SUMMARY.md`

**Location:** `/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/rhythmic_creator/SUMMARY.md`

**Audience:** Paolo — quick personal dev reference during evaluation work with Jake.

### Section 1 — Model Variant Registry

A table listing every known variant as a row. New rows added as Jake sends models. Columns:

| Column | Description |
|--------|-------------|
| Variant | Human name (e.g., "Grid 1-in-1-out") |
| Format | GRID or TND |
| Context | Bars fed as input |
| Output | Bars generated |
| Dataset | `no-repeat` or `repeat` |
| Checkpoint | Filename (or `—` if not yet received) |
| Status | ✅ available / ⏳ pending |

Known variants to populate:

**No-repetition dataset:**
- Grid 1-in-1-out (`grid_barpair_best_epoch.pt` ✅, `baseline_b_best_v2_transformer_GRID.pt` ✅)
- Grid 2-in-1-out (⏳)
- Grid 4-in-1-out (⏳)
- TND 1-in-1-out (⏳)
- TND 2-in-2-out (⏳)

**Repetition dataset:**
- Grid 1-in-1-out (⏳)
- Grid 2-in-1-out (⏳)
- Grid 4-in-1-out (⏳)

### Section 2 — Format Reference

Two short subsections (4–6 lines each):

**GRID format:**
- Token structure: `P{step} N{pitch}` pairs, P0–P15 = 16th-note grid positions
- Sequence: `<SOS> [context bars] <SEP> [output bar] <EOS>`
- Vocab: 42 tokens; checkpoint embeds vocab + config (no separate file needed)
- BPM → step duration: `(60.0 / bpm) / 4.0`

**TND format:**
- Token structure: `T{delta} N{pitch} D{duration}`, TIME_STEP = 0.01s
- Sequence: `<SOS> [context] <SEP> [output] <EOS>`
- Note: TND files exist in dataset but no TND checkpoint available yet

### Section 3 — Evaluation Dimensions

Three bullet-point blocks (3–5 bullets each):

**Latency (CPU):**
- Target: <500ms for real-time use (generation can overlap with loop playback)
- Measure: time from inference call to first token; time to full bar completion
- Test device: MacBook (no GPU)

**Real-time co-creation suitability:**
- What matters: generation speed, context length flexibility, output consistency
- Longer context (2-bar, 4-bar) may improve coherence but increase latency
- GRID quantizes timing; TND preserves micro-timing nuance

**Musician evaluation:**
- Criteria TBD with Jake — placeholder for methodology as it develops
- Will likely cover: rhythmic coherence, stylistic consistency, performance feel

---

## File 2: `INTEGRATION.md`

**Location:** `/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src/models/INTEGRATION.md`

**Audience:** Paolo — how to swap model variants for testing in CHULOOPA.

### Contents (concise)

- Which line in `drum_variation_generator.py` sets the active model checkpoint path
- How to switch between GRID and TND inference wrappers
- One-liner for running the CPU latency timing test

---

## Constraints

- Both files must be concise — no prose padding
- SUMMARY.md is a living doc; rows added as Jake sends new checkpoints
- No implementation instructions in SUMMARY.md (that belongs in INTEGRATION.md)
