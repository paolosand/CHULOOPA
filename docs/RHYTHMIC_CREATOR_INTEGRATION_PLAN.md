# Rhythmic Creator Integration Plan for CHULOOPA

**Goal:** Replace Gemini API-based drum variation generation with Jake Chen's Transformer-LSTM hybrid model for offline, deterministic, and research-grade variations.

---

## Executive Summary

**Current System:** CHULOOPA uses Gemini API (`drum_variation_ai.py:498-587`) to generate drum variations
**Target System:** Jake Chen's Transformer-LSTM+FNN hybrid model from `rhythmic_creator` repository
**Integration Point:** Replace `gemini_variation()` function with local PyTorch model inference

**Benefits:**
- ✅ Offline operation (no API calls, no internet required)
- ✅ Deterministic outputs (reproducible for research)
- ✅ No API costs
- ✅ Lower latency (<50ms vs ~1-3s)
- ✅ Research credibility (published model architecture)
- ✅ Full control over variation generation

---

## Part 1: Files Needed from Jake Chen

### Required Model Files

**Priority 1 - CRITICAL:**
1. **Pre-trained weights:**
   - `transformer_LSTM_FNN_hybrid.pt` (best model, 1.09 CE loss)
   - Referenced in `rhythmic_creator/gen.py:90`

2. **Vocabulary mapping:**
   - `training_1.txt` (for building token vocabulary) - **Already in repo**
   - OR the unique_notes vocabulary list directly

**Priority 2 - Recommended:**
3. **Baseline for comparison:**
   - `transformer_base_192d.pt` (Transformer-only baseline)
   - Useful for A/B testing

### Model Architecture Details Needed

From Jake, confirm:
- **Vocabulary size:** Need to verify it matches the dataset
- **Block size:** 256 (context window)
- **Embedding dimension:** 192
- **Number of heads:** 6
- **Number of layers:** 6
- **Dropout:** 0.2
- **LSTM hidden size:** 64
- **LSTM layers:** 2

These are already in `rhythmic_creator/gen.py:11-19`, but confirm they match the saved weights.

---

## Part 2: Data Format Conversion

### Format Differences

**CHULOOPA Format (`DrumPattern`):**
```python
# DrumHit class
drum_class: int      # 0=kick, 1=snare, 2=hat
timestamp: float     # seconds from loop start
velocity: float      # 0.0-1.0
delta_time: float    # seconds until next hit
```

**Rhythmic Creator Format (tokenized):**
```python
# Each MIDI event as triplet
[drum_class, start_time, end_time]
# Example: "41 0.0 0.12 36 0.0 0.13 46 0.0 0.17"
```

**Key Differences:**
1. CHULOOPA uses delta_time, rhythmic_creator uses end_time
2. CHULOOPA has velocity per hit, rhythmic_creator doesn't explicitly store velocity
3. Drum class mapping may differ (CHULOOPA: 0/1/2, rhythmic_creator: MIDI note numbers 36-127)

### Conversion Functions Required

```python
def chuloopa_to_rhythmic_creator(pattern: DrumPattern) -> str:
    """
    Convert CHULOOPA DrumPattern to rhythmic_creator text format.

    Mapping:
    - drum_class 0 (kick) -> MIDI note 36
    - drum_class 1 (snare) -> MIDI note 38
    - drum_class 2 (hat) -> MIDI note 42
    - timestamp -> start_time
    - timestamp + delta_time -> end_time (or short duration like 0.1s)
    - velocity -> ignored (model doesn't use it)

    Returns: space-separated string like "36 0.0 0.1 38 0.5 0.6"
    """

def rhythmic_creator_to_chuloopa(text: str, loop_duration: float) -> DrumPattern:
    """
    Convert rhythmic_creator output to CHULOOPA DrumPattern.

    Reverse mapping:
    - MIDI 36 -> kick (0)
    - MIDI 38 -> snare (1)
    - MIDI 42 -> hat (2)
    - start_time -> timestamp
    - end_time - start_time -> ignored
    - Calculate delta_time from timestamps
    - Assign velocities based on position in pattern or random

    Returns: DrumPattern object
    """
```

---

## Part 3: Integration Architecture

### New File: `src/rhythmic_creator_model.py`

Create a new module that wraps Jake's model:

```python
"""
rhythmic_creator_model.py - PyTorch model wrapper for drum variation generation

This module loads Jake Chen's Transformer-LSTM hybrid model and provides
an interface compatible with CHULOOPA's DrumPattern format.
"""

import torch
from pathlib import Path
from typing import List, Tuple

# Import Jake's model architecture
# (Copy files from rhythmic_creator/models and rhythmic_creator/modules)
from models.lstm_integration import LSTMDecoderModel
from preprocess.preprocessing import MIDIProcessor


class RhythmicCreatorModel:
    """Wrapper for Jake Chen's Transformer-LSTM drum model."""

    def __init__(self,
                 model_path: str,
                 vocab_path: str = 'training_1.txt',
                 device: str = None):
        """
        Args:
            model_path: Path to trained .pt weights file
            vocab_path: Path to vocabulary file (training_1.txt)
            device: 'cuda' or 'cpu' (auto-detect if None)
        """
        self.device = device or ('cuda' if torch.cuda.is_available() else 'cpu')

        # Initialize preprocessing (builds vocabulary)
        self.processor = MIDIProcessor(vocab_path)
        self.vocab_size = len(self.processor.unique_notes)

        # Model hyperparameters (from gen.py)
        self.block_size = 256
        self.n_embd = 192
        self.num_heads = 6
        self.n_layer = 6
        self.dropout = 0.2
        self.n_hidden = 64
        self.lstm_layers = 2

        # Load model
        self.model = LSTMDecoderModel(
            self.block_size, self.vocab_size,
            self.n_embd, self.num_heads, self.n_layer,
            self.dropout, self.n_hidden, self.lstm_layers
        ).to(self.device)

        self.model.load_state_dict(
            torch.load(model_path, map_location=torch.device(self.device))
        )
        self.model.eval()

    def generate_variation(self,
                          input_pattern: str,
                          num_tokens: int = 300,
                          temperature: float = 0.7) -> str:
        """
        Generate variation from input pattern.

        Args:
            input_pattern: Space-separated MIDI events (rhythmic_creator format)
            num_tokens: Number of new tokens to generate
            temperature: Sampling temperature (0.0-1.0)
                        - Lower = more conservative
                        - Higher = more creative

        Returns:
            Generated pattern in rhythmic_creator format
        """
        # Encode input
        encoded = self.processor.encode_with_mapping(input_pattern.split())
        context = torch.tensor([encoded], dtype=torch.long, device=self.device)

        # Initialize LSTM hidden state
        hidden = self.model.init_hidden(1, self.device)

        # Generate
        with torch.no_grad():
            # Apply temperature to logits during generation
            # (Need to modify generate() method to support temperature)
            generated = self.model.generate(
                self.device, context, hidden, max_new_tokens=num_tokens
            )

        # Decode output
        decoded = self.processor.decode_with_mapping(generated[0].tolist())
        return decoded
```

### Modified: `src/drum_variation_ai.py`

Replace `gemini_variation()` function (lines 498-587):

```python
# Add at top of file
try:
    from rhythmic_creator_model import RhythmicCreatorModel
    HAVE_RHYTHMIC_CREATOR = True
except ImportError:
    HAVE_RHYTHMIC_CREATOR = False
    print("Note: rhythmic_creator_model not available")

# Global model instance (load once, reuse)
rhythmic_model = None


def init_rhythmic_creator_model():
    """Initialize the rhythmic creator model (call once at startup)."""
    global rhythmic_model

    if not HAVE_RHYTHMIC_CREATOR:
        print("Warning: rhythmic_creator not available")
        return False

    model_path = Path(__file__).parent / "models" / "transformer_LSTM_FNN_hybrid.pt"
    vocab_path = Path(__file__).parent / "models" / "training_1.txt"

    if not model_path.exists():
        print(f"Warning: Model not found at {model_path}")
        return False

    try:
        rhythmic_model = RhythmicCreatorModel(
            model_path=str(model_path),
            vocab_path=str(vocab_path)
        )
        print(f"✓ Loaded rhythmic_creator model from {model_path}")
        return True
    except Exception as e:
        print(f"Warning: Failed to load rhythmic_creator model: {e}")
        return False


def rhythmic_creator_variation(pattern: DrumPattern,
                               temperature: float = 0.7) -> Tuple[DrumPattern, bool]:
    """
    Generate variation using Jake Chen's Transformer-LSTM model.

    Args:
        pattern: Input drum pattern
        temperature: Spice level (0.0-1.0)

    Returns:
        Tuple of (DrumPattern, success: bool)
    """
    global rhythmic_model

    if rhythmic_model is None:
        if not init_rhythmic_creator_model():
            print("Falling back to groove_preserve")
            return groove_preserve(pattern), False

    try:
        # Convert CHULOOPA -> rhythmic_creator format
        input_text = chuloopa_to_rhythmic_creator(pattern)

        # Calculate how many tokens to generate (roughly 3 tokens per hit)
        num_tokens = len(pattern.hits) * 3

        # Generate variation
        output_text = rhythmic_model.generate_variation(
            input_pattern=input_text,
            num_tokens=num_tokens,
            temperature=temperature
        )

        # Convert rhythmic_creator -> CHULOOPA format
        varied_pattern = rhythmic_creator_to_chuloopa(output_text, pattern.loop_duration)

        if not varied_pattern.hits:
            print("Warning: Model returned empty pattern, falling back")
            return groove_preserve(pattern), False

        print(f"  Generated {len(varied_pattern.hits)} hits (original: {len(pattern.hits)})")
        return varied_pattern, True

    except Exception as e:
        print(f"Warning: rhythmic_creator generation failed: {e}")
        print("Falling back to groove_preserve")
        return groove_preserve(pattern), False


def generate_variation(pattern: DrumPattern,
                       variation_type: str = 'rhythmic_creator',  # NEW DEFAULT
                       **kwargs) -> Tuple[DrumPattern, bool]:
    """
    Generate a variation of the input pattern.

    Updated to use rhythmic_creator as default instead of Gemini.
    """
    if variation_type == 'rhythmic_creator':
        return rhythmic_creator_variation(pattern, temperature=kwargs.get('temperature', 0.7))

    elif variation_type == 'gemini':
        # Keep as fallback option
        return gemini_variation(pattern, temperature=kwargs.get('temperature', 0.7))

    # ... rest of function unchanged ...
```

---

## Part 4: File Organization

### Directory Structure (New)

```
CHULOOPA/
├── src/
│   ├── drum_variation_ai.py              # MODIFIED: Add rhythmic_creator support
│   ├── rhythmic_creator_model.py         # NEW: Model wrapper
│   │
│   ├── models/                            # NEW: Model files directory
│   │   ├── transformer_LSTM_FNN_hybrid.pt # From Jake (4.49M params)
│   │   ├── training_1.txt                 # From Jake (vocabulary)
│   │   │
│   │   └── rhythmic_creator/              # Copy from Jake's repo
│   │       ├── __init__.py
│   │       ├── lstm_integration.py
│   │       ├── transformerdecoder.py
│   │       └── modules/
│   │           ├── __init__.py
│   │           ├── block.py
│   │           ├── feedforward.py
│   │           └── sublayers.py
│   │
│   └── preprocess/                        # Copy from Jake's repo
│       ├── __init__.py
│       └── preprocessing.py
```

---

## Part 5: Implementation Steps

### Phase 1: Setup & File Transfer (Day 1)

1. **Get files from Jake:**
   - [ ] `transformer_LSTM_FNN_hybrid.pt` (send via Google Drive/Dropbox)
   - [ ] `training_1.txt` (already in repo, confirm it's the right one)
   - [ ] Confirm model hyperparameters match gen.py

2. **Copy code files to CHULOOPA:**
   ```bash
   cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"

   # Create directories
   mkdir -p models/rhythmic_creator/modules
   mkdir -p preprocess

   # Copy model architecture files
   cp ../../rhythmic_creator/models/lstm_integration.py models/rhythmic_creator/
   cp ../../rhythmic_creator/models/transformerdecoder.py models/rhythmic_creator/
   cp ../../rhythmic_creator/modules/*.py models/rhythmic_creator/modules/

   # Copy preprocessing
   cp ../../rhythmic_creator/preprocess/preprocessing.py preprocess/

   # Add __init__.py files
   touch models/__init__.py
   touch models/rhythmic_creator/__init__.py
   touch models/rhythmic_creator/modules/__init__.py
   touch preprocess/__init__.py
   ```

3. **Install PyTorch:**
   ```bash
   cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
   pip install torch torchvision torchaudio
   ```

### Phase 2: Data Format Conversion (Day 2)

1. **Implement conversion functions:**
   - Create `src/format_converters.py`
   - Write `chuloopa_to_rhythmic_creator()`
   - Write `rhythmic_creator_to_chuloopa()`
   - Test with sample data

2. **Test conversion round-trip:**
   ```python
   # Load a CHULOOPA pattern
   pattern = DrumPattern.from_file('src/tracks/track_0/track_0_drums.txt')

   # Convert to rhythmic_creator format
   rc_format = chuloopa_to_rhythmic_creator(pattern)

   # Convert back
   reconstructed = rhythmic_creator_to_chuloopa(rc_format, pattern.loop_duration)

   # Verify: should have same number of hits, similar timestamps
   assert len(reconstructed.hits) == len(pattern.hits)
   ```

### Phase 3: Model Wrapper (Day 3)

1. **Create `src/rhythmic_creator_model.py`**
   - Implement `RhythmicCreatorModel` class
   - Test model loading
   - Test generation with dummy input

2. **Add temperature/sampling control:**
   - Jake's model doesn't have temperature in `generate()`
   - Need to add temperature scaling to logits before multinomial sampling
   - OR use top-k/top-p sampling for variation control

### Phase 4: Integration (Day 4)

1. **Modify `drum_variation_ai.py`:**
   - Add `rhythmic_creator_variation()` function
   - Update `generate_variation()` to use new default
   - Keep Gemini as optional fallback

2. **Update CLI:**
   - Change default `--type` to `rhythmic_creator`
   - Keep `gemini` as option for comparison

### Phase 5: Testing (Day 5)

1. **Standalone testing:**
   ```bash
   cd src
   python drum_variation_ai.py --file tracks/track_0/track_0_drums.txt --type rhythmic_creator
   ```

2. **Watch mode testing:**
   ```bash
   # Terminal 1
   cd src
   python drum_variation_ai.py --watch --type rhythmic_creator

   # Terminal 2
   cd src
   chuck chuloopa_drums_v2.ck
   ```

3. **Integration testing:**
   - Record a loop in CHULOOPA
   - Verify variation generates automatically
   - Check OSC messages work
   - Test spice level control (CC 74)
   - Load variation with D1, verify playback

### Phase 6: Refinement (Day 6-7)

1. **Tune generation parameters:**
   - Test different temperature mappings (spice 0.0-1.0 -> model temp 0.5-1.0?)
   - Adjust number of tokens generated
   - Fine-tune conversion functions

2. **Handle edge cases:**
   - Empty patterns
   - Very long patterns (>block_size tokens)
   - Patterns with unusual timing

3. **Performance optimization:**
   - Model stays loaded in memory (no reload per request)
   - CUDA if available
   - Batch processing if generating multiple variations

---

## Part 6: Fallback Strategy

**If rhythmic_creator model fails:**
1. Log error to console
2. Fall back to `groove_preserve()` algorithm
3. Send OSC message to ChucK: `/chuloopa/generation_failed`
4. User can see failure in ChuGL window
5. User can try again with D#1

**Fallback priority:**
```
rhythmic_creator (new default)
  ↓ (if fails)
groove_preserve (algorithmic, always works)
  ↓ (only if user requests)
gemini (requires API key, internet)
```

---

## Part 7: Testing Checklist

### Functional Tests

- [ ] Model loads successfully
- [ ] Format conversion round-trip preserves data
- [ ] Generation produces valid patterns
- [ ] Loop duration is preserved exactly
- [ ] Spice level affects variation amount
- [ ] OSC communication works
- [ ] Pattern loads in ChucK correctly
- [ ] Playback sounds correct

### Performance Tests

- [ ] Generation completes in <500ms (vs 1-3s for Gemini)
- [ ] Memory usage reasonable (<1GB)
- [ ] No crashes on repeated generation
- [ ] Works offline (no internet needed)

### Musical Tests

- [ ] Variations maintain groove structure
- [ ] Low spice (0.0-0.3) = subtle changes
- [ ] High spice (0.7-1.0) = creative variations
- [ ] Patterns sound musical, not random
- [ ] Timing feels natural

---

## Part 8: Documentation Updates

**Files to update:**

1. **README.md:**
   - Update "AI Variation Generation" section
   - Note rhythmic_creator is now default
   - Mention Gemini as optional alternative

2. **CLAUDE.md:**
   - Update architecture diagram
   - Add rhythmic_creator model details
   - Update file structure

3. **requirements.txt:**
   - Add `torch>=2.0.0`
   - Keep `google-genai` as optional

4. **New file: docs/RHYTHMIC_CREATOR_MODEL.md:**
   - Technical details of Jake's model
   - Paper citation
   - Model architecture explanation
   - Training details

---

## Part 9: Research Benefits

### Why This Matters for Your Thesis

1. **Scholarly Credibility:**
   - Gemini is a black box (can't cite methodology)
   - Jake's model is published research (can cite paper + advisor)
   - Transformer-LSTM is established architecture

2. **Reproducibility:**
   - Same input = same output (deterministic with fixed seed)
   - Critical for research validation
   - Can't reproduce Gemini results (non-deterministic API)

3. **CalArts Connection:**
   - Using advisor's (Jake Chen) research
   - Collaborative MFA thesis work
   - Builds on prior CalArts research

4. **Paper Writing:**
   - Can explain model architecture in detail
   - Can cite training methodology
   - Can discuss limitations scientifically
   - Gemini = "we used a proprietary API" (weak for research)

---

## Part 10: Next Steps After Integration

### Short-term (Post-Integration)

1. **Comparative Evaluation:**
   - A/B test: rhythmic_creator vs Gemini vs groove_preserve
   - User study: which variations feel most musical?
   - Metrics: pattern diversity, groove preservation, user preference

2. **Fine-tuning (Optional):**
   - Retrain model on CHULOOPA-specific drum patterns
   - Smaller vocabulary (only kick/snare/hat)
   - Optimize for loop durations used in CHULOOPA

### Long-term (Research)

1. **Paper Section:**
   - "AI-Powered Variation Generation using Transformer-LSTM Architecture"
   - Compare to baseline algorithms
   - Cite Jake's paper

2. **Multi-variation Support:**
   - Generate 3-5 variants per request
   - Let user cycle through them
   - Pick "best" variation automatically

3. **Conditional Generation:**
   - Specify target characteristics: "busier", "simpler", "more swing"
   - Use MIDI CC controls for multi-dimensional variation

---

## Questions for Jake

Before starting integration:

1. **Model Weights:**
   - Can you share `transformer_LSTM_FNN_hybrid.pt`? (Google Drive link?)
   - File size? (~18MB expected for 4.49M params)

2. **Vocabulary:**
   - Is `training_1.txt` in the repo the correct vocab file?
   - Any preprocessing steps needed?

3. **Inference:**
   - Any specific considerations for real-time use?
   - Can we add temperature scaling to the generate() method?
   - Recommended sampling strategy (multinomial vs top-k)?

4. **Limitations:**
   - Max sequence length the model handles well?
   - Performance on very short/long loops?
   - Any known failure modes?

5. **Citation:**
   - Paper published yet? (for thesis citation)
   - Preferred citation format?

---

## Timeline Estimate

**Aggressive (1 week):**
- Day 1: Get files, setup
- Day 2: Data conversion
- Day 3: Model wrapper
- Day 4: Integration
- Day 5: Testing
- Day 6-7: Refinement

**Realistic (2 weeks):**
- Week 1: Setup, conversion, model wrapper, initial integration
- Week 2: Testing, debugging, refinement, documentation

**With buffer (3 weeks):**
- Allows for unexpected issues, model debugging, comparative testing

---

## Success Criteria

Integration is successful when:

✅ Model loads without errors
✅ Generates variations in <500ms
✅ Preserves loop duration exactly
✅ Spice level control works (0.0-1.0)
✅ OSC communication intact
✅ ChucK loads and plays variations correctly
✅ Works offline (no API calls)
✅ No Gemini API key required
✅ Variations sound musical (subjective but critical)

---

## Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Model weights unavailable | Low | High | Ask Jake early, have fallback to groove_preserve |
| Format conversion errors | Medium | Medium | Thorough testing, edge case handling |
| Model too slow for real-time | Low | Medium | Profile performance, optimize if needed |
| Variations sound unmusical | Medium | High | Tune temperature, compare to Gemini, adjust sampling |
| PyTorch dependency issues | Low | Low | Use conda/venv, document exact versions |
| Memory issues on laptop | Low | Medium | Model is small (4.49M params), should be fine |

---

## Conclusion

This integration replaces a proprietary API with research-grade open methodology, improving:
- **Research credibility** (citable, reproducible)
- **Performance** (5-10x faster)
- **Reliability** (offline, deterministic)
- **Cost** ($0 vs Gemini API fees)

The implementation is straightforward given Jake's clean code structure. Main effort is data format conversion and testing musical quality of variations.

**Recommended approach:** Start with Phase 1 (get files from Jake) immediately, then proceed through phases sequentially. Keep Gemini as fallback during development for comparison and safety.
