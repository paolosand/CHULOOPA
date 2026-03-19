# Getting Models from Jake - Step by Step Guide

## TL;DR - What to Ask Jake For

**Ask Jake to send you:**

1. ✅ **ALL the .pt model files he has** (even if he doesn't remember which is which)
2. ✅ **The generation script** he uses (gen.py or similar)
3. ✅ **training_1.txt** (vocabulary file) if not already in the repo

**Tell him:**
> "No worries about which config is which - I can use PyTorch to inspect
> the checkpoints and figure out the model architecture from the layer shapes!"

---

## Step 1: Receive Files from Jake

**Expected files:**
- `model_1.pt` (or similar names - he might have 3-5 different configs)
- `model_2.pt`
- `model_3.pt`
- `gen.py` or `generate.py` (his generation script)
- `training_1.txt` (vocabulary)

**Save them temporarily:**
```bash
mkdir -p ~/Downloads/jake_models
# Put all .pt files here
```

---

## Step 2: Install PyTorch (if not already installed)

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
pip install torch
```

---

## Step 3: Inspect the Models

**Run the inspection script on ALL the .pt files:**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/docs"

python inspect_jake_models.py \
    ~/Downloads/jake_models/model_1.pt \
    ~/Downloads/jake_models/model_2.pt \
    ~/Downloads/jake_models/model_3.pt
```

**What you'll see:**

```
================================================================================
INSPECTING: /Users/paolosandejas/Downloads/jake_models/model_1.pt
================================================================================

📦 Checkpoint type: dict
   Keys: ['state_dict']

📊 STATE DICT ANALYSIS:
   Total parameters: 176

🔍 LAYER STRUCTURE:
   tok_embd_tbl.weight                                   (2500, 192)              480,000 params
   pos_embd_tbl.weight                                   (256, 192)                49,152 params
   blocks.0.sa.heads.0.key.weight                        (32, 192)                  6,144 params
   blocks.0.lstm_lyr.lstm.weight_ih_l0                   (256, 192)                49,152 params
   blocks.0.lstm_lyr.fc.weight                           (192, 64)                 12,288 params
   ...
   TOTAL PARAMETERS                                                            4,490,000

🎯 INFERRED CONFIGURATION:
   vocab_size           = 2500
   n_embd               = 192
   block_size           = 256
   num_heads            = 6
   n_layer              = 6
   n_hidden             = 64
   lstm_layers          = 2
   dropout              = 0.2

🏷️  MODEL TYPE:
   ✅ Transformer-LSTM+FNN Hybrid (BEST MODEL)

✓ MATCHES PAPER'S BEST MODEL?
   ✅ YES - This appears to be transformer_LSTM_FNN_hybrid.pt
      (4.49M params, hybrid architecture)
```

---

## Step 4: Identify the Best Model

**The script will show a comparison table:**

```
================================================================================
SUMMARY TABLE
================================================================================

Model                                        Params  Type
-------------------------------------------------------------------------------------
model_1.pt                                4,490,000  LSTM+FNN Hybrid
model_2.pt                                3,810,000  Transformer baseline
model_3.pt                                4,490,000  LSTM only

✅ RECOMMENDED MODEL: model_1.pt
   This matches the paper's best configuration (4.49M params, hybrid)
```

**Look for:**
- ✅ **~4.49M parameters** (matches paper Table 1)
- ✅ **"LSTM+FNN Hybrid"** type (best model from paper)
- ✅ **n_embd = 192, num_heads = 6, n_layer = 6**

---

## Step 5: Copy the Right Model to CHULOOPA

**Once identified (e.g., model_1.pt is the one):**

```bash
# Create models directory
mkdir -p "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src/models"

# Copy the best model
cp ~/Downloads/jake_models/model_1.pt \
   "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src/models/transformer_LSTM_FNN_hybrid.pt"

# Copy vocabulary
cp ~/Downloads/jake_models/training_1.txt \
   "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src/models/"
```

---

## Step 6: Verify the Model Loads

**Test loading:**

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/src"
python
```

```python
import torch
from pathlib import Path

# Load checkpoint
model_path = "models/transformer_LSTM_FNN_hybrid.pt"
checkpoint = torch.load(model_path, map_location=torch.device('cpu'))

print("✓ Model loaded successfully!")
print(f"  Type: {type(checkpoint)}")
print(f"  Keys: {checkpoint.keys() if isinstance(checkpoint, dict) else 'N/A'}")

# Check state dict
if isinstance(checkpoint, dict) and 'state_dict' in checkpoint:
    state_dict = checkpoint['state_dict']
else:
    state_dict = checkpoint

print(f"  State dict layers: {len(state_dict)}")
print(f"  First few layers: {list(state_dict.keys())[:5]}")
```

**Expected output:**
```
✓ Model loaded successfully!
  Type: <class 'collections.OrderedDict'>
  State dict layers: 176
  First few layers: ['tok_embd_tbl.weight', 'pos_embd_tbl.weight', 'blocks.0.lyr_norm1.weight', ...]
```

---

## What the Inspection Script Does

### 1. **Unpacks the .pt file**
PyTorch checkpoints are just Python dictionaries saved with `torch.save()`.
We can load them and inspect the structure without knowing the model code.

### 2. **Analyzes layer shapes**
From the state_dict, we can reverse-engineer:
- **vocab_size**: from `tok_embd_tbl.weight` shape → `(vocab_size, n_embd)`
- **block_size**: from `pos_embd_tbl.weight` shape → `(block_size, n_embd)`
- **n_embd**: embedding dimension (appears in all layers)
- **num_heads**: count attention heads in `blocks.0.sa.heads.*`
- **n_layer**: count distinct `blocks.N.*` patterns
- **n_hidden**: from LSTM layer shapes (if present)
- **lstm_layers**: count LSTM layers (if present)

### 3. **Counts total parameters**
Sums up all parameter counts to verify it matches the paper (4.49M for best model).

### 4. **Detects model type**
- Transformer baseline: no LSTM layers
- Transformer-LSTM: has LSTM, no FNN in parallel
- **Transformer-LSTM+FNN hybrid**: has both LSTM and FNN (BEST)

---

## Understanding Jake's Generation Script

**When Jake sends his generation script, look for:**

### Key info we need:

1. **How he initializes the model:**
   ```python
   model = LSTMDecoderModel(
       block_size=256,
       vocab_size=len(unique_notes),
       n_embd=192,
       # ... etc
   )
   ```

2. **How he loads the checkpoint:**
   ```python
   model.load_state_dict(torch.load('path/to/model.pt'))
   # OR
   checkpoint = torch.load('path/to/model.pt')
   model.load_state_dict(checkpoint['state_dict'])
   ```

3. **How he does generation:**
   ```python
   hidden = model.init_hidden(1, device)
   output = model.generate(device, context, hidden, max_new_tokens=300)
   ```

4. **How he encodes/decodes:**
   ```python
   encoded = processor.encode_with_mapping(input_tokens)
   decoded = processor.decode_with_mapping(output_tokens)
   ```

**We'll adapt this for CHULOOPA!**

---

## Fallback: If No Generation Script

If Jake can't find his generation script, we already have everything we need:

1. **Model architecture:** In `rhythmic_creator/models/lstm_integration.py`
2. **Preprocessing:** In `rhythmic_creator/preprocess/preprocessing.py`
3. **Example usage:** In `rhythmic_creator/gen.py` (we already cloned this)

We just need the trained weights (.pt file) and vocabulary (training_1.txt).

---

## Common Issues & Solutions

### Issue 1: "Missing keys" error when loading

**Problem:**
```python
RuntimeError: Missing keys in state_dict: ['blocks.0.lyr_norm1.weight', ...]
```

**Solution:**
The checkpoint might be wrapped in a dict. Try:

```python
# Instead of:
model.load_state_dict(checkpoint)

# Try:
model.load_state_dict(checkpoint['state_dict'])

# Or:
model.load_state_dict(checkpoint['model'])
```

### Issue 2: Model config doesn't match checkpoint

**Problem:**
```python
RuntimeError: size mismatch for tok_embd_tbl.weight:
copying a param with shape (2500, 192) from checkpoint,
but the shape in current model is (3000, 192)
```

**Solution:**
Your vocab_size is wrong. Use the inspection script to find the correct vocab_size,
then rebuild the vocabulary or use Jake's exact training_1.txt.

### Issue 3: Checkpoint is on GPU, you're on CPU

**Problem:**
```python
RuntimeError: Attempting to deserialize object on CUDA device 0 but no GPU available
```

**Solution:**
Always use `map_location`:
```python
checkpoint = torch.load(model_path, map_location=torch.device('cpu'))
```

---

## Next Steps After Getting Models

Once you have the model and verified it loads:

1. ✅ **Copy model to `src/models/`** (done in Step 5)
2. ✅ **Copy rhythmic_creator code** (architecture files)
3. ✅ **Implement format converters** (already created: `src/format_converters.py`)
4. ✅ **Create model wrapper** (`src/rhythmic_creator_model.py`)
5. ✅ **Integrate into drum_variation_ai.py**
6. ✅ **Test end-to-end**

See the main integration plan for full details:
`/Code/CHULOOPA/docs/RHYTHMIC_CREATOR_INTEGRATION_PLAN.md`

---

## Questions for Jake (Copy-Paste Email)

```
Hey Jake,

Quick update on the integration - I can actually inspect the PyTorch
checkpoints to figure out which config is which, so no worries if you
don't remember!

Can you send me:
1. All the .pt model files you have (3-5 different configs?)
2. Your generation script (gen.py or similar)
3. training_1.txt vocabulary file

I'll use PyTorch to unpack the .pt files and identify which one is
the 4.49M param hybrid model from the paper.

Also, quick questions:
- The model does autoregressive continuation (extending patterns), right?
  Not variation-in-place?
- Any tips for using it to generate fixed-length loops? I'll post-process
  the timestamps to fit CHULOOPA's loop duration.
- Your generate() method doesn't have temperature - OK if I add it?
  (Just dividing logits by temperature before softmax)

Thanks!
Paolo
```

---

## Summary

**You don't need Jake to remember which model is which!**

1. Ask him to send ALL the .pt files + generation script
2. Run `inspect_jake_models.py` on all of them
3. Script will automatically identify the best model (4.49M params, hybrid)
4. Copy that model to CHULOOPA
5. Proceed with integration

**This is actually BETTER** because we verify the model configuration
programmatically rather than relying on filename or memory! 🎯
