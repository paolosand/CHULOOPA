# Paper Update Checklist — April 23 2026

Tracks all changes needed in the two `.tex` papers once the final model is confirmed.
Sections A and B can be done **now**. Sections C and D wait on model decision.

---

## A. `references.bib` — Add 3 citations (do now, model-independent)

```bibtex
@article{toussaint2004mathematical,
  title={A mathematical analysis of {African}, {Brazilian}, and {Cuban} clave rhythms},
  author={Toussaint, Godfried T.},
  journal={Forma},
  volume={19},
  number={1},
  pages={11--20},
  year={2004}
}

@book{toussaint2013geometry,
  title={The Geometry of Musical Rhythm: What Makes a ``Good'' Rhythm Good?},
  author={Toussaint, Godfried T.},
  year={2013},
  publisher={CRC Press},
  address={Boca Raton, FL}
}

@article{witek2014syncopation,
  title={Syncopation, body-movement and pleasure in groove music},
  author={Witek, Maria A. G. and Clarke, Eric F. and Wallentin, Mikkel and Kringelbach, Morten L. and Vuust, Peter},
  journal={{PLOS ONE}},
  volume={9},
  number={4},
  pages={e94446},
  year={2014},
  doi={10.1371/journal.pone.0094446}
}
```

`gillick2019learning` is already in the file — no action needed there.

---

## B. Deviation score formula — update now (both papers, model-independent)

### `chuloopa_aimc2026_condensed.tex` — Eq. (eq:deviation), ~lines 136–140

**Old equation:**
```latex
\text{dev} = \Delta_{\text{hits}} + 0.3 \times n_{\text{non-standard}}
```

**New equation:**
```latex
\text{dev} = V_{\text{new}} + \frac{\max(0,\,\Delta_{\text{hits}})}{16}
```

**New surrounding prose** (replace the old explanation of Δhits and n_non-standard):

> where $V_{\text{new}}$ is the count of MIDI note classes present in the variation
> but absent from the original (new drum voices introduced), $\Delta_{\text{hits}}$ is
> the signed difference in hit count (variation minus original), and 16 is the number
> of sixteenth-note steps per bar~\citep{toussaint2004mathematical,gillick2019learning}.
> $V_{\text{new}}$ dominates: a single new voice (e.g.\ an open hi-hat) always ranks
> higher than a density change alone. The density term breaks ties and is capped at
> zero so that sparser variations are not penalised.

### `chuloopa_aimc2026.tex` — full paper

Search for `non\_standard` or `0.3 \times` and apply the same equation and prose replacement.

---

## C. Model-specific changes (do after confirming GRID vs. TND model)

*Assumes GRID model (`grid_barpair_best_epoch.pt`) — pure GPT-style causal Transformer
decoder, 6 layers, 8 heads, 256-dim, 4.8M params, 42-token P/N vocabulary, bar-pair
conditional, 16th-note quantized output. Revisit if TND is chosen instead.*

### C1. Architecture description — every occurrence

| File | Location | Current | Replace with |
|---|---|---|---|
| `aimc2026.tex` | Abstract L44 | "transformer-LSTM model" | "GPT-style causal Transformer decoder" |
| `aimc2026.tex` | Abstract L44–45 | "continuation-based variation generation preserves non-quantized timing through proportional time-warping" | "bar-pair conditional generation produces quantized variations from a user-recorded bar" |
| `aimc2026.tex` | Keywords L47 | "transformer-LSTM" | "GPT Transformer" |
| `aimc2026.tex` | §1.3 L81 | "transformer-LSTM model … human 'feel' of timing imperfections" | drop timing-preservation claim; introduce bar-pair approach |
| `aimc2026.tex` | §1.3 L96 | "local transformer-LSTM model … exact loop duration … non-quantized timing" | rewrite for bar-pair + grid quantization |
| `aimc2026.tex` | §2.3 L182–184 | "Transformer-LSTM+FNN hybrid (4.49M params) … 6 Transformer blocks (192-dim, 6 heads) with 2 LSTM layers … character-level tokenization of MIDI events as triplets" | "GPTBarPair: 6-layer causal Transformer decoder (256-dim, 8 heads, 4.8M params, 42-token P/N grid vocabulary)" |
| `aimc2026.tex` | §4.4 L359–365 | same arch block | same replacement |
| `condensed.tex` | Abstract L53 | "hybrid transformer based model" | "GPT-style causal Transformer decoder" |
| `condensed.tex` | §3.3 L133 | "transformer-LSTM-FNN hybrid (4.5M parameters)" | "GPTBarPair (4.8M parameters, 42-token vocabulary)" |
| `condensed.tex` | §5 L229, L251 | "transformer-LSTM" / "transformer-LSTM inference" | "GPT Transformer decoder" |

### C2. Timing-preservation claims — DROP or rewrite

These claims are only valid for the TND model (delta-time format). GRID outputs a
16th-note quantized bar — do not claim groove/feel/microtiming preservation.

| File | Location | Claim to drop or rewrite |
|---|---|---|
| `aimc2026.tex` | Abstract L44–45 | "preserves non-quantized timing through proportional time-warping" |
| `aimc2026.tex` | §1.2 L81 | "CHULOOPA's AI maintains the human 'feel' of timing imperfections" |
| `aimc2026.tex` | Contributions list L128–130 | Items 2 "Continuation-based variation preserving non-quantized timing" and 3 "Proportional time-warping to maintain exact loop duration" |
| `aimc2026.tex` | §2.2 L118–119 | "continuation-based approach … preserving non-quantized 'groove' characteristics" |
| `aimc2026.tex` | §5.2 L476–482 | Entire "Continuation-Based Variation: A Model-Task Mismatch Solution" subsection — rewrite as "Bar-Pair Generation: Conditioning on Performer Input" |
| `aimc2026.tex` | Comparison table L532 | "Timing: Good" for CHULOOPA — now outputs quantized 16th-note grid; update to "Quant." or add footnote |
| `condensed.tex` | Abstract L53 | "continuation-based generation preserves non-quantized timing, maintaining human groove" |
| `condensed.tex` | §5 L223–226 | "continuation-based approach preserves the performer's timing 'fingerprint' (non-quantized groove)" |
| `condensed.tex` | Conclusion L249 | "Continuation-based variation at natural model timing … maintains non-quantized groove" |
| `condensed.tex` | Conclusion L251 | "Local transformer-LSTM inference … demonstrates that sophisticated AI … need not depend on proprietary platforms" — update model name only |

**Replacement framing for dropped timing claims:**

> GPTBarPair generates a quantized variation bar on a 16-step grid. Quantization is applied
> to the user's recording via `quantize_to_steps` (median phase correction;
> \citet{toussaint2004mathematical}) before conditioning the model, and the generated
> grid is dequantized back to absolute timestamps for loop playback. This trades
> microtiming fidelity for structural predictability: every variation shares the same
> rhythmic grid as the original, making the bank musically coherent across spice levels.

### C3. Spice / token-count mechanism — rewrite

The old mechanism (token count ceiling, 0.85×–1.5× multiplier) does not apply to the GRID
model. The new mechanism is temperature.

| File | Location | Current | Replace with |
|---|---|---|---|
| `aimc2026.tex` | §4.4 L344–345 | "per-slot spice controls token count multiplier (0.85×–1.5× context length)" | "per-slot spice controls sampling temperature: `temp = 0.6 + spice × 0.8`" |
| `aimc2026.tex` | §4.4 L386–398 | Token-count multiplier table and slot-ceiling logic | Temperature mapping description + explanation that bank sorting corrects for stochasticity |
| `aimc2026.tex` | §4.4 L348 | "`/chuloopa/bank_ready` when slot 1 completes" | "`/chuloopa/bank_ready` after all 5 slots complete and bank is sorted by deviation score" |
| `condensed.tex` | §3.3 L133 | "token count scales linearly with spice: 0.85× … 1.5×" | "sampling temperature scales with spice: `temp = 0.6 + spice × 0.8`" |

**New spice mechanism prose:**

> Each of the 5 generation threads uses a different sampling temperature (spice 0.2 →
> temp 0.76; spice 1.0 → temp 1.40) to steer the model toward more or less adventurous
> output. Temperature steers \emph{tendency}, not outcome: a high-temperature run may
> occasionally return something conservative. Bank sorting by deviation score (Eq.~X)
> corrects for this: regardless of which thread produced what, slot~1 is always the most
> conservative result and slot~5 the most adventurous.

### C4. Tokenization and format — update

| File | Location | Current | Replace with |
|---|---|---|---|
| `aimc2026.tex` | §4.4 L364 | "Character-level tokenization of MIDI events as triplets [drum\_class, start\_time, end\_time]" | "16th-note grid tokens: alternating P\{step\} (steps 0–15) and N\{pitch\} (MIDI note number), 42-token vocabulary" |
| `aimc2026.tex` | §4.4 L342 | "Converts to rhythmic\_creator format (MIDI triplets)" | "Converts to GPTBarPair format (P/N grid tokens via `quantize\_to\_steps`~\citep{toussaint2004mathematical})" |
| `condensed.tex` | §3.3 | No explicit tokenization description | Add one sentence: "Input is quantized to a 16-step grid~\citep{toussaint2004mathematical} and encoded as alternating P\{step\} / N\{pitch\} tokens before conditioning the model." |

### C5. Training data — verify with Jake, then update

Current claim: "13,000+ MIDI drum sequences" (was for the old model, trained on e-gmd).
Unknown whether the GRID model used the same dataset or a different one.

**Action:** Ask Jake Chen what dataset `grid_barpair_best_epoch.pt` was trained on.
Update the figure at `aimc2026.tex` L182 and `condensed.tex` L133 accordingly.
Also correct CLAUDE.md which incorrectly says "Lakh MIDI."

### C6. Contributions list — replace two items (full paper L126–134)

**Drop:**
- "Continuation-based variation generation preserving non-quantized timing"
- "Proportional time-warping to maintain exact loop duration with natural feel"

**Add:**
- "Bar-pair conditional variation generation using a GPT-style Transformer decoder"
- "16th-note grid quantization with median phase correction for drift-free loop alignment~\citep{toussaint2004mathematical}"

---

## D. CLAUDE.md — one line update (do now)

**Current (§Research Angle):**
> "rhythmic_creator model (Transformer-LSTM-FNN hybrid trained on Lakh MIDI)"

**Replace with:**
> "GPTBarPair model (GPT-style causal Transformer decoder, 6 layers, 8 heads, 256-dim, 42-token P/N grid vocabulary, bar-pair conditional) — training data TBD from Jake"

---

## Summary

| Category | Do now | Wait for model decision |
|---|---|---|
| `references.bib` — 3 new entries | ✅ | |
| Deviation formula (both papers) | ✅ | |
| Architecture description | | ✅ |
| Timing-preservation claims (drop/rewrite) | | ✅ |
| Spice/token mechanism | | ✅ |
| Tokenization format | | ✅ |
| Training data (verify with Jake) | | ✅ |
| Contributions list (full paper) | | ✅ |
| CLAUDE.md | ✅ | |
