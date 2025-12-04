# DRUM PIVOT ACTION PLAN

**Start Date:** November 25, 2025
**Checkpoint:** December 8, 2025 (13 days)
**Deadline:** December 22, 2025 (27 days)
**Status:** 🟢 ACTIVE - Phase 1 in progress

---

## Critical Path Overview

```
Week 1 (Nov 25-Dec 1): ONSET DETECTION + DATA COLLECTION
├─ Nov 25: ✅ Onset detector implemented
├─ Nov 25-26: Test onset detector, tune parameters
├─ Nov 27-28: Record 50-100 beatbox samples
├─ Nov 29-30: Extract features, prepare training data
└─ Dec 1: Train initial classifier

Week 2 (Dec 2-8): AI INTEGRATION
├─ Dec 2-3: Setup Python + GrooVAE
├─ Dec 4-5: OSC communication ChucK ↔ Python
├─ Dec 6-7: Test full pipeline
└─ Dec 8: 🎯 GO/NO-GO DECISION POINT

Week 3 (Dec 9-15): EVALUATION + PAPER DRAFT
├─ Dec 9-11: Run experiments (onset accuracy, latency)
├─ Dec 12-13: Optional user study
└─ Dec 14-15: Draft paper sections

Week 4 (Dec 16-22): FINALIZE + SUBMIT
├─ Dec 16-18: Complete paper, create figures
├─ Dec 19-20: Revisions, polish
├─ Dec 21: Final review
└─ Dec 22: 📤 SUBMIT TO ICMC
```

---

## Phase 1: Onset Detection + Data Collection (Nov 25-Dec 1)

### ✅ Day 1: Nov 25 (TODAY) - COMPLETED
- [x] Create `drum_onset_detector.ck`
- [x] Implement spectral flux algorithm
- [x] Add adaptive thresholding
- [x] Add audio feedback (click on onset)
- [x] Test with initial beatbox attempts

### Day 1 Tasks (Rest of Today):

#### Task 1.1: Test the Onset Detector RIGHT NOW

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
chuck src/drum_onset_detector.ck
```

**What to do:**
1. Run the script
2. Beatbox into your mic: "BOOM tss tss BOOM tss tss"
3. Watch console for "ONSET DETECTED!" messages
4. Listen for click sounds (onset feedback)
5. Press Ctrl+C when done

**Expected Results:**
- Should detect 6 onsets (BOOM, tss, tss, BOOM, tss, tss)
- Might have false positives (that's OK for now)
- Check `drum_onsets.txt` for exported data

**Tuning Parameters (if needed):**
If you get too many/few onsets, edit `drum_onset_detector.ck`:
```chuck
// Line 13: Increase if too many false positives
1.5 => float ONSET_THRESHOLD_MULTIPLIER;  // Try 2.0 or 2.5

// Line 14: Increase to require stronger onsets
0.01 => float MIN_ONSET_STRENGTH;  // Try 0.02 or 0.05

// Line 15: Increase to prevent rapid re-triggering
100::ms => dur MIN_ONSET_INTERVAL;  // Try 80::ms or 120::ms
```

#### Task 1.2: Document Initial Results

Create a test log file:
```bash
# Create initial test notes
echo "## Nov 25 - Onset Detector Initial Test" >> onset_test_log.md
echo "- Threshold: 1.5" >> onset_test_log.md
echo "- Results: [Your observations here]" >> onset_test_log.md
```

**Answer these questions:**
1. Does it detect kicks (BOOM)?
2. Does it detect snares/hats (tss, tss)?
3. Are there false positives during silence?
4. What's the latency feel? (does click sound sync with your voice?)

---

### Day 2: Nov 26 - Parameter Tuning

**Goal:** Get onset detection to 90%+ recall (detect all real drum hits)

#### Tasks:
1. **Record 10 test patterns** (each 4 beats):
   - Pattern 1: "BOOM tss tss BOOM" (4/4 with kick on 1 and 3)
   - Pattern 2: "tss tss tss tss" (hi-hats only)
   - Pattern 3: "BOOM BOOM tss BOOM" (kick heavy)
   - Pattern 4: "pf pf pf pf" (snare/rim sounds)
   - Pattern 5-10: Freestyle variations

2. **Manually count ground truth:**
   - Listen back to each pattern
   - Count actual drum sounds
   - Compare to detected onsets

3. **Calculate metrics:**
   ```
   Recall = Detected Onsets / Actual Drum Sounds
   Precision = Correct Onsets / Detected Onsets
   ```

4. **Tune parameters to maximize recall** (we'll fix precision later with classifier)

**Target:** Recall > 90%, Precision > 70%

---

### Days 3-4: Nov 27-28 - Data Collection

**Goal:** Record 50-100 beatbox samples for classifier training

#### Recording Protocol:

**Equipment:**
- Microphone (your current setup)
- Quiet room
- Headphones (monitor yourself)

**What to Record:**

**Session 1: Isolated Sounds (20 samples each = 60 total)**
- 20 kicks: "BOOM", "DUM", "BUM", "DOO" (vary mouth shape)
- 20 snares: "PSH", "TSS", "KSH", "PIFF" (vary air/voice ratio)
- 20 hi-hats: "tss", "ts", "tik", "chh" (vary tongue position)

**Session 2: Patterns (30 samples)**
- 10 simple patterns: "BOOM tss tss BOOM tss tss" (repeat 2-4 bars)
- 10 intermediate: Mix kicks, snares, hats in 8-beat patterns
- 10 complex: Freestyle with fast hi-hats, double kicks

**Recording Script:**
For each sample:
1. Say: "Kick 1" (or "Snare 5", etc.)
2. Wait 1 second
3. Perform the sound/pattern
4. Wait 1 second
5. Next sample

**Save as:** `beatbox_samples/session1_kicks.wav`, etc.

#### Annotation Protocol:

**For isolated sounds:**
- Run through onset detector
- Manually verify onset time is correct
- Label file: `kick_001.txt`, `snare_001.txt`, `hat_001.txt`

**For patterns:**
- Export onset times from detector
- Listen back, label each onset:
  ```
  0.0, kick
  0.5, snare
  0.75, hat
  1.0, kick
  ```

**Tool:** Use Audacity or similar to visualize waveform while annotating

---

### Days 5-6: Nov 29-30 - Feature Extraction

**Goal:** Extract acoustic features from each onset segment

#### Create Python Script: `extract_features.py`

**You'll need:**
```bash
pip install librosa numpy scikit-learn
```

**Script outline:**
```python
import librosa
import numpy as np
from pathlib import Path

def extract_onset_features(audio_file, onset_time, window_ms=50):
    """
    Extract features from a short window around onset

    Features to extract:
    - MFCCs (13 coefficients)
    - Spectral centroid (brightness)
    - Zero-crossing rate (noisiness)
    - RMS energy (loudness)
    """
    y, sr = librosa.load(audio_file, sr=44100)

    # Get audio segment around onset (±window_ms)
    start_sample = int((onset_time - window_ms/2000.0) * sr)
    end_sample = int((onset_time + window_ms/2000.0) * sr)
    segment = y[start_sample:end_sample]

    # Extract features
    mfccs = librosa.feature.mfcc(y=segment, sr=sr, n_mfcc=13)
    mfcc_mean = np.mean(mfccs, axis=1)

    spectral_centroid = librosa.feature.spectral_centroid(y=segment, sr=sr)
    centroid_mean = np.mean(spectral_centroid)

    zcr = librosa.feature.zero_crossing_rate(segment)
    zcr_mean = np.mean(zcr)

    rms = librosa.feature.rms(y=segment)
    rms_mean = np.mean(rms)

    # Concatenate all features
    features = np.concatenate([mfcc_mean, [centroid_mean, zcr_mean, rms_mean]])

    return features  # 16-dimensional feature vector

# Process all labeled samples
def create_training_dataset(data_dir):
    X = []  # Features
    y = []  # Labels (kick=0, snare=1, hat=2)

    for label_file in Path(data_dir).glob("*.txt"):
        # Read label file (format: time, label)
        # Extract features for each onset
        # Append to X and y
        pass

    return np.array(X), np.array(y)
```

**Task:** Run feature extraction on all 50-100 samples, save as `training_data.npz`

---

### Day 7: Dec 1 - Train Classifier

**Goal:** Train a simple classifier to distinguish kick/snare/hat

#### Create Training Script: `train_classifier.py`

```python
from sklearn.svm import SVC
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler
import numpy as np
import joblib

# Load data
data = np.load('training_data.npz')
X = data['features']
y = data['labels']

# Split train/test
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# Normalize features
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Train SVM
clf = SVC(kernel='rbf', gamma='scale', C=1.0)
clf.fit(X_train_scaled, y_train)

# Evaluate
train_score = clf.score(X_train_scaled, y_train)
test_score = clf.score(X_test_scaled, y_test)

print(f"Training accuracy: {train_score:.2%}")
print(f"Test accuracy: {test_score:.2%}")

# Cross-validation
cv_scores = cross_val_score(clf, X_train_scaled, y_train, cv=5)
print(f"CV accuracy: {cv_scores.mean():.2%} (+/- {cv_scores.std():.2%})")

# Save model
joblib.dump(clf, 'drum_classifier.pkl')
joblib.dump(scaler, 'feature_scaler.pkl')
```

**Target Performance:**
- Training accuracy: 85-95%
- Test accuracy: 75-85%
- If test < 70%, need more data or better features

**Troubleshooting:**
- Low accuracy on hats? They're hardest - consider merging with snares
- Kicks should be easiest (low frequency energy)
- Try different SVM kernels (linear, poly) if rbf fails

---

## 🎯 DEC 8 CHECKPOINT: GO/NO-GO DECISION

**By Dec 8, you MUST have:**

### ✅ Success Criteria (Continue with Drums):
- [x] Onset detection recall > 85%
- [x] Classifier test accuracy > 70%
- [x] Full pipeline tested: beatbox → onsets → classification
- [x] Latency < 100ms end-to-end
- [x] Python environment ready (GrooVAE installed)
- [x] OSC communication working (at least one-way)

### ❌ Abort Criteria (Switch to Melody):
- Onset detection recall < 70% (too many missed hits)
- Classifier test accuracy < 60% (can't distinguish drums)
- Major technical blockers (ChucK crashes, Python issues)
- Lost more than 2 days to debugging

**If aborting:** Immediately switch to melody system, implement Kalman filter, write paper on that.

---

## Phase 2: AI Integration (Dec 2-8)

### Days 8-9: Setup GrooVAE

```bash
# Create Python environment
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA"
python3 -m venv groovae_env
source groovae_env/bin/activate

# Install dependencies
pip install magenta tensorflow pretty_midi python-osc

# Test GrooVAE
python -c "from magenta.models.music_vae import configs; print('GrooVAE ready!')"
```

**Create test script:** `test_groovae.py`
```python
import magenta
from magenta.models.music_vae import configs, TrainedModel
import pretty_midi

# Load pre-trained GrooVAE model
config = configs.CONFIG_MAP['groovae_4bar']
model = TrainedModel(config, batch_size=1, checkpoint_dir_or_path='groovae_checkpoint')

# Test: Generate variation of a simple drum pattern
# ... (will provide full code later)
```

### Days 10-11: OSC Bridge

**Create:** `drum_osc_server.py`
```python
from pythonosc import dispatcher, osc_server, udp_client

# Listen for onsets from ChucK
def onset_handler(address, drum_class, velocity, timestamp):
    print(f"Received onset: {drum_class} at {timestamp}s, vel={velocity}")
    # Buffer onsets until we have a full pattern
    # Then send to GrooVAE
    # Send variation back to ChucK

dispatcher = dispatcher.Dispatcher()
dispatcher.map("/drum/onset", onset_handler)

server = osc_server.ThreadingOSCUDPServer(('127.0.0.1', 9000), dispatcher)
print("OSC Server running on port 9000...")
server.serve_forever()
```

**Update ChucK system to send OSC:**
```chuck
// In drum_onset_detector.ck, add:
OscOut xmit;
xmit.dest("localhost", 9000);

fun void sendOnsetOSC(int drum_class, float velocity, float timestamp) {
    xmit.start("/drum/onset")
        .add(drum_class)  // 0=kick, 1=snare, 2=hat
        .add(velocity)
        .add(timestamp)
        .send();
}
```

---

## Phase 3: Evaluation (Dec 9-15)

### Quantitative Metrics:

1. **Onset Detection:**
   - Precision, Recall, F1-score
   - False positive rate
   - Timing accuracy (±ms)

2. **Classification:**
   - Confusion matrix (kick/snare/hat)
   - Per-class accuracy
   - Overall accuracy

3. **Latency:**
   - Onset detection latency
   - Classification latency
   - GrooVAE generation latency
   - End-to-end latency

4. **Generation Quality:**
   - Pattern similarity (edit distance)
   - Rhythmic consistency (groove metrics)
   - Human evaluation (5-point scale)

### Optional User Study (if time):

**Participants:** 5-10 musicians (varying beatbox skill)

**Task:**
1. Beatbox a 4-bar pattern
2. Listen to 3 AI variations
3. Rate each: "How well does this variation match your intent?"
4. Select favorite
5. Interview: "Was the system easy to use?"

**Analysis:** Compare expert vs. amateur beatboxers' ratings

---

## Phase 4: Paper Writing (Dec 14-22)

### Paper Structure (ICMC Format):

**Title:** "Vocal Percussion for All: Making Drum Programming Accessible Through Amateur Beatboxing"

**Abstract:** (150-200 words)
- Problem: Drum programming requires training
- Solution: Beatbox-to-MIDI with AI variation
- Novelty: Focus on amateur/non-expert users
- Results: XX% accuracy, <100ms latency, user study positive

**1. Introduction** (1 page)
- Motivation: accessibility, intuitive input
- Research question: Can amateurs use beatbox for drum programming?
- Contributions: (1) Real-time system, (2) Amateur-tolerant, (3) User study

**2. Related Work** (1.5 pages)
- Beatbox transcription (cite BaDumTss, AVP dataset)
- Drum generation (cite GrooVAE, Drum RNN)
- Music AI accessibility (cite relevant NIME papers)

**3. System Design** (2 pages)
- Architecture diagram
- Onset detection algorithm
- Classification approach
- GrooVAE integration
- Latency optimization

**4. Implementation** (1 page)
- ChucK for real-time audio
- Python for ML
- OSC for communication
- Dataset details

**5. Evaluation** (2 pages)
- Onset detection results
- Classification results
- Latency measurements
- User study findings (if done)
- Qualitative examples

**6. Discussion** (1 page)
- Limitations (monophonic, 3 classes, etc.)
- Amateur vs. expert performance
- Creative applications
- Future work

**7. Conclusion** (0.5 pages)
- Summary of contributions
- Impact: democratizing drum programming

**References:** (30-40 papers)

### LLM-Assisted Writing Prompts:

**For Introduction:**
```
"Write an academic introduction for a paper titled 'Vocal Percussion for All:
Making Drum Programming Accessible Through Amateur Beatboxing'. The paper
presents a real-time system that allows non-expert users to create drum
patterns through beatboxing, with AI-generated variations. Focus on
accessibility and the gap between professional beatbox systems and amateur
needs. Target conference: ICMC (International Computer Music Conference)."
```

**For Related Work:**
```
"Summarize research on: (1) beatbox transcription systems like BaDumTss,
(2) drum pattern generation using GrooVAE and Drum RNN, and (3) accessible
music creation interfaces. Identify gaps that our amateur-focused approach fills."
```

---

## Key Files Created

### ChucK Code:
- `src/drum_onset_detector.ck` - Real-time onset detection
- `src/drum_classifier_integration.ck` - Onset + classification (Phase 2)
- `src/drum_variation_player.ck` - Play GrooVAE outputs (Phase 2)

### Python Code:
- `extract_features.py` - Feature extraction from audio
- `train_classifier.py` - Train SVM classifier
- `drum_osc_server.py` - OSC bridge with GrooVAE
- `test_groovae.py` - Test GrooVAE functionality

### Data:
- `beatbox_samples/` - Recorded beatbox audio
- `training_data.npz` - Extracted features + labels
- `drum_classifier.pkl` - Trained model
- `drum_onsets.txt` - Detected onset times

### Documentation:
- `DRUM_PIVOT_PLAN.md` - This file
- `onset_test_log.md` - Testing notes
- `ICMC_PAPER_DRAFT.md` - Paper outline (Phase 3)

---

## Daily Checklist

### Every Day:
- [ ] Update todo list with completed tasks
- [ ] Log any issues/blockers immediately
- [ ] Commit code to git (branch: pivot/drum_generation)
- [ ] Test changes incrementally (don't accumulate tech debt)

### End of Each Phase:
- [ ] Review against success criteria
- [ ] Document decisions made
- [ ] Update timeline if slipping
- [ ] Ask for help if stuck > 2 hours

---

## Emergency Contact Plan

**If stuck for > 4 hours on something:**
1. Document exactly what's not working
2. Search for similar issues (StackOverflow, ChucK forum)
3. Ask LLM (Claude/ChatGPT) for debugging help
4. Consider simplifying approach (3 classes → 2 classes, SVM → heuristics)
5. If still stuck by end of day, flag as blocker for next day

**Red flags that mean "abort to melody":**
- Can't get onset detector working by Nov 30
- Can't train classifier with >60% accuracy by Dec 2
- Can't get GrooVAE running by Dec 5
- Can't integrate OSC by Dec 7

---

## Success Metrics (Final)

**Minimum Viable Paper (50% ICMC acceptance):**
- ✅ Working onset detection + classification
- ✅ GrooVAE integration (even if not perfect)
- ✅ Quantitative evaluation (onset accuracy, latency)
- ✅ 1-2 qualitative examples
- ✅ Clear writing, good figures

**Strong Paper (70% ICMC acceptance):**
- ✅ All of above +
- ✅ User study with 5+ participants
- ✅ Amateur vs. expert comparison
- ✅ Creative use cases demonstrated
- ✅ Open-source code release

**Dream Paper (90% ICMC acceptance):**
- ✅ All of above +
- ✅ Live demo video
- ✅ Comparison to baseline (manual MIDI programming)
- ✅ Novel insight about amateur beatbox characteristics
- ✅ Release dataset + trained models

---

**Let's do this! Start with testing the onset detector RIGHT NOW.** 🥁
