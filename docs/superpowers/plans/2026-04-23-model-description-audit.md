# Model Description Audit Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Catalog every place in the paper, README, and docs where the old rhythmic_creator architecture is described so that a single editing pass can update them once the final model is chosen.

**Architecture:** Read-only audit — no code or paper changes. Produces a checked list of specific files, line numbers, and claim categories. Nothing is changed until the final model (GRID, TND, or another variant) is confirmed.

**Tech Stack:** Markdown only. No code changes.

---

## Background: What Changed

The old model (`transformer_LSTM_FNN_hybrid.pt`) and the new model (`grid_barpair_best_epoch.pt` / `tnd_barpair_best_epoch.pt`) differ on every dimension that the paper currently describes.

| Dimension | Old model (current paper) | GRID model | TND model |
|-----------|--------------------------|------------|-----------|
| Architecture | Transformer-LSTM+FNN hybrid | GPTBarPair (pure Transformer, no LSTM) | GPT-style Transformer |
| Params | 4.49M | 4.8M | TBD |
| Vocab size | 2,869 tokens | 42 tokens | larger (T/N/D triplets) |
| Token format | character-level MIDI triplets [drum_class, start, end] | P/N grid pairs (16th-note position + pitch) | T/N/D delta-time triplets |
| Model purpose | Continuation model | Bar-pair conditional (in→out, NOT continuation) | Bar-pair conditional |
| Timing output | Non-quantized (proportional warp) | 16th-note quantized | Continuous micro-timing |
| Training data | "13,000+ MIDI sequences" / "Lakh MIDI" | e-gmd-barpairs_v2 (12,085 train pairs) | same dataset |
| Context window | 256 tokens | block size 198 | different |
| Checkpoint file | `transformer_LSTM_FNN_hybrid.pt` | `grid_barpair_best_epoch.pt` | `tnd_barpair_best_epoch.pt` |

**Critical impact:** Several paper claims about "timing preservation" and "human feel" are only true for the TND model (or old model). The GRID model quantizes timing to 16th-note steps — the "non-quantized groove" framing does not apply to it.

---

## Claim Categories

When auditing, tag each finding with one or more of these categories:

- **ARCH** — Architecture description (layers, LSTM presence, heads, embedding size)
- **PARAMS** — Parameter count, vocab size, context window
- **TOKENS** — Tokenization format / character-level description
- **DATASET** — Training data description (Lakh vs. e-gmd, count)
- **TIMING** — Non-quantized timing, proportional time-warp, human feel claims
- **CONTINUATION** — "Continuation model" framing; model-task mismatch discussion
- **SPICE** — Spice → token count ceiling mechanism; temperature mapping
- **CHECKPOINT** — Checkpoint filename references
- **LATENCY** — Generation latency (3–5s) — verify with new model before claiming

---

## Files to Audit

| File | Priority | Why |
|------|----------|-----|
| `docs/internal/paper/chuloopa_aimc2026.tex` | P0 | Primary paper — most complete model description |
| `docs/internal/paper/chuloopa_aimc2026_condensed.tex` | P0 | Conference submission version — independent from main |
| `README.md` | P1 | User-facing; mentions "transformer-LSTM" and model details |
| `CLAUDE.md` | P1 | Dev reference; mentions "Lakh MIDI" training data |
| `docs/internal/RHYTHMIC_CREATOR_QUICKSTART.md` | P1 | Temperature guide, vocab size, model info are all old-model-specific |
| `src/models/INTEGRATION.md` | P2 | Line-number references that will shift when code changes |

---

## Task 1: Audit `chuloopa_aimc2026.tex` (main paper)

**File:** `docs/internal/paper/chuloopa_aimc2026.tex`

- [ ] **Step 1: Check Abstract (lines 43–45)**

  Current text includes: *"local transformer-LSTM model for AI-powered variation generation"* and *"continuation-based variation generation preserves non-quantized timing through proportional time-warping"*

  Tags: **ARCH**, **TIMING**, **CONTINUATION**

  When updating: Replace with the architecture name of the final model. If GRID is chosen, the timing-preservation claim must be revised — GRID quantizes to 16th notes. If TND is chosen, non-quantized claim holds but add caveat on generation quality.

- [ ] **Step 2: Check Introduction §3 "AI as Collaborator" paragraph (line 81)**

  Current text: *"maintain the human 'feel' of timing imperfections while introducing musical variations"*

  Tags: **TIMING**

  When updating: If GRID model is final, this claim is false — GRID snaps to grid. Remove or replace with "maintain rhythmic structure" / "preserve hit density."

- [ ] **Step 3: Check System Overview §4 (line 96)**

  Current text: *"local transformer-LSTM model (rhythmic\_creator by Jake Chen, CalArts MFA 2025)"*

  Tags: **ARCH**

- [ ] **Step 4: Check figure caption §1 (line 104)**

  Current text: *"MFCC-13 KNN classification"* — this part is fine; also mentions *"5-variant AI variation bank"* — still correct.

  No change needed unless system design changes.

- [ ] **Step 5: Check Related Work §2.3 "AI Music Generation" (lines 182–186)**

  This is the densest architecture block:
  - Line 182: *"Transformer-LSTM+FNN hybrid architecture (4.49M parameters) trained on over 13,000 MIDI drum sequences"*
  - Line 182: *"6 Transformer blocks (192-dim embeddings, 6 attention heads) with 2 LSTM layers (64 hidden units each)"*
  - Line 182: *"Character-level tokenization of MIDI events as triplets [drum\_class, start\_time, end\_time]"*

  Tags: **ARCH**, **PARAMS**, **TOKENS**, **DATASET**

  When updating: Replace with new architecture block. GPTBarPair: 6 layers, 8 heads, 256 embd, 4.8M params, 42-token vocab, P/N grid pairs (GRID) or T/N/D triplets (TND). Dataset: e-gmd-barpairs_v2, 12,085 train bar pairs.

- [ ] **Step 6: Check Related Work §2.3 continuation framing (lines 183–184)**

  Current text: *"rather than using rhythmic\_creator for unconditional generation (its original purpose), we extract its continuation output as variations"*

  Tags: **CONTINUATION**

  When updating: The new models are bar-pair conditional, not continuation models. The framing of "model-task mismatch" and "reframing" no longer applies in the same way. Replace with: "The model is conditioned on a recorded bar and generates a new bar as output."

- [ ] **Step 7: Check §2.5 "Offline-First AI" (line 206)**

  Current text: *"local transformer-LSTM models (~4.5M parameters) can generate musically coherent variations in 3-5 seconds on consumer CPUs"*

  Tags: **ARCH**, **PARAMS**, **LATENCY**

  When updating: Verify actual latency with new model before claiming specific numbers. Use timing script in `src/models/INTEGRATION.md`.

- [ ] **Step 8: Check System Design §4.4 "AI Variation Generation" model description (lines 359–365)**

  Current text lists: vocab 2,869 tokens, 4,492,981 params, context window 256 tokens, 6 Transformer blocks 192-dim 6 heads, 2 LSTM layers 64 units, "character-level tokenization"

  Tags: **ARCH**, **PARAMS**, **TOKENS**

  When updating: Full block needs rewrite. Remove LSTM layer description entirely for GRID/TND. Update all numbers.

- [ ] **Step 9: Check §4.4 spice mechanism description (lines 384–398)**

  Current text: Spice maps to token count ceiling (0.1→slot1 only, 0.9–1.0→all 5 slots). Each slot's internal spice controls token count multiplier 0.85×–1.5×. Fixed temperature 0.9.

  Tags: **SPICE**

  When updating: The token-count-ceiling mechanism is specific to the old continuation model. The GRID model produces exactly one bar regardless — spice mechanism must be redesigned (e.g., top-k, temperature, or post-hoc bank sorting). Describe whatever mechanism is actually used.

- [ ] **Step 10: Check Discussion §5.2 "Continuation-Based Variation: A Model-Task Mismatch Solution" (lines 476–482)**

  Current text: Entire subsection is built around the old model being a continuation model that we cleverly repurposed. *"The model was trained for MIDI sequence extension, not loop generation."* *"extract its natural continuation output, time-shift to loop start, and proportionally time-warp to match duration."*

  Tags: **CONTINUATION**, **TIMING**

  When updating: This section may need complete rewrite. The new models are explicitly bar-pair conditional — there is no model-task mismatch. The "breakthrough from reframing" narrative no longer applies.

- [ ] **Step 11: Check Conclusion §7.3 (lines 610–614)**

  Current text: *"Local transformer-LSTM inference (4.5M parameters) generates musically coherent variations in 3-5 seconds on consumer CPUs without GPU acceleration."*

  Tags: **ARCH**, **PARAMS**, **LATENCY**

- [ ] **Step 12: Check Acknowledgements (line 644)**

  Current text: *"Jake Chen (Zhaohan Chen) for making his rhythmic\_creator model available"* — still correct; just verify name/role are accurate.

---

## Task 2: Audit `chuloopa_aimc2026_condensed.tex` (conference version)

**File:** `docs/internal/paper/chuloopa_aimc2026_condensed.tex`

Note: This is a separately-edited file — some sections have already been updated relative to the main paper. Audit independently.

- [ ] **Step 1: Check Abstract**

  Current text: *"one of 5 pre-generated variations (from rhythmic\_creator, a hybrid transformer based model drum pattern generator) is selected"* and *"continuation-based generation preserves non-quantized timing, maintaining human groove across variations"*

  Tags: **ARCH**, **TIMING**, **CONTINUATION**

  "Hybrid transformer" is already a looser description — still inaccurate if GRID is chosen (no LSTM). "Continuation-based generation preserves non-quantized timing" — false for GRID model.

- [ ] **Step 2: Check Related Work §2 (line 79)**

  Current text: *"We build on \citet{chen2025music}'s rhythmic\_creator, a transformer-LSTM trained on 13,000+ MIDI sequences"*

  Tags: **ARCH**, **DATASET**

- [ ] **Step 3: Check AI Variation Bank subsection (lines 133–140)**

  Current text describes: *"continuation whose token count scales linearly with spice: 0.85× the input context at spice 0.0, rising to 1.5× at spice 1.0"* and *"hits with timestamps beyond the original loop boundary are trimmed, and the remaining hits are kept unscaled"*

  Tags: **CONTINUATION**, **TIMING**, **SPICE**

  The token-count-scaling mechanism is old-model-specific. "Timestamps beyond boundary are trimmed" describes the old model's natural-timing approach — may or may not apply to GRID model (GRID always outputs exactly 1 bar; no trimming needed).

- [ ] **Step 4: Check Discussion §4.2 "Mediated Musicianship" (lines 223–226)**

  Current text: *"The continuation-based approach preserves the performer's timing 'fingerprint' (non-quantized groove), positioning AI as augmentation rather than replacement."*

  Tags: **CONTINUATION**, **TIMING**

  False for GRID model. If TND is chosen, this holds but add quality caveat.

- [ ] **Step 5: Check Discussion §4.3 "Offline-First" (line 229)**

  Current text: *"Local transformer-LSTM inference (4.5M parameters, CPU-only)"*

  Tags: **ARCH**, **PARAMS**

- [ ] **Step 6: Check Future Work §5 (lines 240–241)**

  Current text: *"fine-tuning rhythmic\_creator on drum-only dataset"*

  Tags: potentially outdated depending on which model is final — verify this is still a valid future goal.

---

## Task 3: Audit `README.md`

**File:** `README.md`

- [ ] **Step 1: Check Quick Start §2 (line 54)**

  Current text: *"Generates a bank of 5 variations at spice levels 0.2/0.4/0.6/0.8/1.0 using Jake Chen's rhythmic\_creator model."*

  Tags: **ARCH** (loose but acceptable); verify spice level mapping is still correct after model swap.

- [ ] **Step 2: Check Technical Architecture §Pipeline (line 127)**

  Current text: *"drum\_variation\_generator.py watches track\_0\_drums.txt → generates 5-variant bank (spice 0.2/0.4/0.6/0.8/1.0) → notifies ChucK via /chuloopa/bank\_ready"* — this description is at the pipeline level, not architecture-specific. Likely fine unless bank generation logic changes.

- [ ] **Step 3: Check Credits (line 234)**

  Current text: *"rhythmic\_creator by Jake Chen (Zhaohan Chen), CalArts MFA 2025 — 'Music As Natural Language: Deep Learning Driven Rhythmic Creation' — Transformer-LSTM hybrid adapted for continuation-based loop variation."*

  Tags: **ARCH**, **CONTINUATION**

  "Transformer-LSTM hybrid" is incorrect for GPTBarPair. "Adapted for continuation-based loop variation" is incorrect for bar-pair conditional models. Both need updating.

---

## Task 4: Audit `CLAUDE.md`

**File:** `CLAUDE.md` (project root)

- [ ] **Step 1: Check Research Angle / Design Decision paragraph**

  Current text: *"Jake Chen's rhythmic\_creator model (Transformer-LSTM-FNN hybrid trained on Lakh MIDI) as the default variation engine"*

  Tags: **ARCH**, **DATASET**

  "Lakh MIDI" is wrong — the model trains on e-gmd (Expanded Groove MIDI Dataset). This needs correction regardless of which final model is chosen.

- [ ] **Step 2: Check CLAUDE.md references to spice=token count**

  Current text: *"Spice = token count ceiling: Spice (0.0-1.0) maps to how many tokens rhythmic\_creator generates above context (max 3×), not temperature"*

  Tags: **SPICE**

  Mechanism-specific to old model. Update once final model's spice mechanism is decided.

---

## Task 5: Audit `docs/internal/RHYTHMIC_CREATOR_QUICKSTART.md`

**File:** `docs/internal/RHYTHMIC_CREATOR_QUICKSTART.md`

This doc is a quickstart guide for the OLD model (`drum_variation_ai.py` with `rhythmic_creator_model.py`). It predates the grid model integration. It should either be:
- Archived/deprecated if the old model is fully replaced
- Updated if the old model remains as a fallback

- [ ] **Step 1: Check model info block**

  Current text: vocab 2,869 tokens, 4,492,981 params, context window 256 tokens, 6 Transformer blocks 192-dim 6 heads, 2 LSTM layers 64 hidden units

  Tags: **ARCH**, **PARAMS**, **TOKENS** — all old-model-specific.

- [ ] **Step 2: Check Temperature Guide**

  Current temperature guide (0.5–1.5 range, spice→temperature mapping) is specific to the old model's temperature parameter. The GRID model uses top-k/temperature differently. The TND model also differs.

  Tags: **SPICE**

- [ ] **Step 3: Check file references**

  References `rhythmic_creator_model.py`, `drum_variation_ai.py`, and `transformer_LSTM_FNN_hybrid.pt` — all old-model files.

  Tags: **CHECKPOINT**

  Decision: Once final model is confirmed, either update this guide or deprecate it and replace with a new guide for the active model.

- [ ] **Step 4: Check "For Your Thesis" block**

  Contains a quote template: *"We integrated Chen's Transformer-LSTM+FNN hybrid architecture [cite], a 4.49M parameter model trained on 13,533 drum sequences."* — all numbers outdated.

  Tags: **ARCH**, **PARAMS**, **DATASET**

---

## Task 6: Audit `src/models/INTEGRATION.md`

**File:** `src/models/INTEGRATION.md`

This doc was written for the GRID model and is already current. Audit only to confirm no stale references slipped in.

- [ ] **Step 1: Verify checkpoint path at line 8**

  Should reference `grid_barpair_best_epoch.pt` — confirm this is the active checkpoint.

- [ ] **Step 2: Verify line numbers in `drum_variation_generator.py`**

  INTEGRATION.md references line 806 (`_GRID_MODEL_PATH`) and line 1793 (TND swap point). These will shift if the file is edited. Note: do not update these until the file is actually changed — update INTEGRATION.md as part of each implementation task that touches those lines.

---

## Summary: Claims Requiring the Most Careful Handling

These are the claims most likely to need significant rewriting (not just number substitution):

1. **"Non-quantized timing preservation"** — True only for TND model or old model. False for GRID. This is a core framing of the paper's contribution §2 and Discussion §5.2 in the main paper, and appears in both paper abstracts.

2. **"Continuation-based variation"** — The new models are bar-pair conditional, not continuation models. Discussion §5.2 of the main paper ("A Model-Task Mismatch Solution") is entirely built on the old continuation framing and requires full rewrite.

3. **"Human feel preserving"** — Tied to non-quantized timing. Needs reassessment per final model choice.

4. **Architecture block in Related Work** — Dense multi-sentence technical description at main paper lines 182–184. Full rewrite needed.

5. **Spice mechanism** — Token-count ceiling design is specific to the old continuation model. New mechanism (whatever it is for GRID/TND) must be described from scratch.

6. **"Trained on Lakh MIDI"** in CLAUDE.md — Factually wrong regardless of model choice. Training data is e-gmd (Expanded Groove MIDI Dataset). Fix immediately.

---

## How to Use This Plan

When the final model is decided:

1. Open this document and work through tasks 1–5 in order, checking off each item.
2. For each checked item, make the edit in the target file with the correct numbers/description.
3. Use SUMMARY.md at `rhythmic_creator/SUMMARY.md` as the authoritative source for architecture specs, param counts, and dataset details.
4. Re-read both paper abstracts last — they summarize claims from throughout the paper, so edit them after the body sections are updated.
5. After all edits, do a final grep for "transformer-LSTM", "LSTM", "continuation-based", "non-quantized", "4.49M", "4.5M", "2869", "13,000", "Lakh", "character-level tokenization" across the repo to catch any missed references.

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
grep -rn --include="*.tex" --include="*.md" \
  "transformer-LSTM\|LSTM\|continuation-based\|non-quantized\|4\.49M\|4\.5M\|2869\|13,000\|Lakh\|character-level" \
  docs/ README.md CLAUDE.md src/models/INTEGRATION.md
```
