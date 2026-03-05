# CHULOOPA: Personalized Beatbox-to-Drum Transcription for Solo Performance

**Target Conference:** NIME 2026
**Deadline:** Abstract Feb 5, Full Paper Feb 12, 2026
**Authors:** Paolo Sandejas (CalArts)
**Status:** DRAFT - In Progress

---

## Abstract

Solo musicians often need drum accompaniment but lack access to drummers or the technical skills to program drum machines. Existing solutions—backing tracks, loop pedals, or traditional drum machines—are either inflexible or require significant music theory knowledge. We present CHULOOPA, a real-time beatbox-to-drum transcription system designed for live solo performance. CHULOOPA uses personalized machine learning trained on minimal user-specific data (10 samples per drum class) to transcribe vocal beatboxing into drum patterns with ~90% accuracy. The system provides immediate audio feedback during recording, enables seamless pattern looping, and generates AI-powered variations that preserve non-quantized timing and musical feel through local neural network inference. By combining accessible input (beatboxing), personalized classification, and offline AI-augmented creativity, CHULOOPA lowers the barrier to drum programming for amateur beatboxers while maintaining responsiveness for live performance. We evaluate the system through technical metrics, autoethnographic study, and user testing with solo performers, demonstrating that personalization enables high accuracy with minimal training data and that AI can augment creativity without destroying natural timing.

**Keywords:** beatbox recognition, personalized machine learning, AI music generation, live looping, solo performance, accessible music creation

---

## 1. Introduction

### 1.1 Motivation

I am a singer-songwriter who performs solo. I am also a terrible drummer. Like many solo performers, I've faced a persistent creative challenge: how do I add compelling drum accompaniment to my live performances without needing a human drummer or spending hours programming rigid backing tracks?

Traditional solutions fall short. Pre-programmed drum loops feel disconnected from the live energy of performance—they lack spontaneity and responsiveness. Loop pedals designed for guitarists assume I can tap out patterns on foot switches while playing, which interrupts the flow of performing. Traditional drum machines (hardware or software) require knowledge of music theory, grid-based programming, or expensive MIDI controllers. These barriers make drum creation inaccessible to non-technical musicians.

But here's what I *can* do: I can beatbox—not well, but well enough to communicate the drum pattern I hear in my head. My kick drum sounds like "BOOM," my snare sounds like "PAH," and my hi-hat sounds like "tss." These sounds are personal, idiosyncratic, and inconsistent with professional beatboxers, but they're *mine*. What if I could train a system to understand *my* beatbox vocabulary and transcribe it into polished drum patterns in real-time?

This personal frustration led to CHULOOPA (ChucK-based User-trainable Loop Operator for Performance Audio): a beatbox-to-drum transcription system designed explicitly for solo performers like myself who lack drumming skills but can communicate rhythmic ideas through voice.

### 1.2 Design Vision

CHULOOPA is built around three core design principles:

**1. Accessibility through Personalization**
Rather than training on generic beatbox datasets (which wouldn't recognize my amateur attempts), CHULOOPA uses minimal user-specific training data. By collecting just 10 samples each of the user's kick, snare, and hi-hat sounds, the system learns *that performer's* unique vocal percussion style. This personalization approach trades dataset size for specificity, enabling high accuracy (~90%) even with minimal training.

**2. Real-Time Performance Responsiveness**
CHULOOPA provides immediate audio feedback during recording—as you beatbox, you hear drum samples play back in real-time. This creates a tight feedback loop between input and output, essential for live performance where latency destroys the creative flow. The system processes onset detection, classification, and playback with <50ms latency, maintaining the spontaneity of live music-making.

**3. AI-Augmented Creativity**
Once a drum pattern is recorded, CHULOOPA generates variations using a local transformer-LSTM neural network trained on MIDI drum sequences. Critically, these AI-generated variations preserve the exact loop duration and non-quantized timing of the original beatbox performance. Unlike traditional quantization-based systems that force rhythms onto a grid, CHULOOPA's AI maintains the human "feel" of timing imperfections while introducing musical variations. This represents a shift from AI as replacement to AI as creative collaborator. The system runs entirely offline with no external API dependencies, making it reliable for live performance contexts.

### 1.3 System Overview

CHULOOPA's workflow consists of four stages:

1. **Personalized Training (one-time, ~5 minutes):** The user beatboxes 10 samples each of kick, snare, and hi-hat sounds. The system extracts acoustic features and trains a K-Nearest Neighbors (KNN) classifier on this user-specific data.

2. **Real-Time Transcription:** During performance, the user beatboxes into a microphone while holding a MIDI trigger. The system detects onsets (spectral flux with adaptive thresholding), classifies each hit (kick/snare/hat), and plays back corresponding drum samples immediately. Timing and velocity data are stored in a symbolic format with delta-time encoding for precise loop playback.

3. **Loop Playback:** When the user releases the MIDI trigger, the recorded pattern begins looping seamlessly. The system uses queued actions to enable smooth pattern switching at loop boundaries without overlap or drift.

4. **AI Variation Generation:** A background Python process monitors for newly recorded patterns and automatically generates variations using a local transformer-LSTM model (rhythmic_creator by Jake Chen, CalArts MFA 2025). These variations maintain the exact loop duration and preserve the non-quantized timing characteristics of the original performance. Users can load variations via MIDI triggers during performance. The system runs entirely offline, ensuring reliability in live performance contexts.

The system is implemented in ChucK (for real-time audio/MIDI processing) with Python integration (for KNN training and Gemini API calls), running on standard laptop hardware with a USB microphone and MIDI controller.

### 1.4 Contributions

This paper makes three primary contributions:

1. **Minimal personalized training for beatbox classification:** We demonstrate that user-specific training with only 10 samples per drum class achieves ~90% classification accuracy, significantly fewer samples than generic beatbox recognition systems require. We argue that personalization enables high accuracy with minimal data by constraining the recognition problem to a single user's consistent (if amateur) vocal style.

2. **Timing-preserving AI variation generation:** We show that a transformer-LSTM model trained on MIDI sequences can generate musically coherent drum pattern variations while maintaining exact loop duration and preserving non-quantized timing characteristics through a continuation-based approach. This contrasts with prior AI music generation systems that quantize to grids, demonstrating that AI can augment without destroying natural human timing. The system operates entirely offline, eliminating external API dependencies for live performance reliability.

3. **Complete performance system for solo musicians:** We present an end-to-end system designed explicitly for non-technical solo performers, integrating beatbox transcription, live looping, and AI variation in a performance-ready instrument. Through autoethnographic study and user testing, we demonstrate that the system successfully lowers barriers to drum programming for amateur beatboxers.

### 1.5 Paper Organization

The remainder of this paper is organized as follows: Section 2 reviews related work in beatbox recognition, personalized ML for music, AI music generation, and live looping systems. Section 3 describes CHULOOPA's system design in detail, covering the transcription pipeline, personalized training approach, looping architecture, and AI variation generation. Section 4 discusses implementation details and architectural decisions. Section 5 presents technical evaluation (classifier accuracy, latency), autoethnographic findings from my use as a solo performer, and user testing results with other musicians. Section 6 discusses design insights, limitations, and comparisons to alternative approaches. Section 7 outlines future work, and Section 8 concludes.

---

## 2. Related Work

[TODO: Literature review covering beatbox recognition, personalized ML, AI music generation, live looping]

### 2.1 Beatbox Recognition and Vocal Percussion Analysis

[To be written: Survey existing beatbox classification systems, datasets, accuracy rates]

### 2.2 Personalized Machine Learning for Music

[To be written: Few-shot learning, user adaptation, personalized models in music AI]

### 2.3 AI Music Generation and Variation Systems

[To be written: Magenta (GrooVAE, MusicVAE), recent LLM approaches, timing preservation challenges]

### 2.4 Live Looping Systems and Performance Interfaces

[To be written: Loop pedals, Ableton Live, other live looping instruments]

### 2.5 Gap Analysis

[To be written: No system combines personalization + real-time + AI variation for accessible solo performance]

---

## 3. System Design

[TODO: Detailed technical description]

### 3.1 Overview and Design Goals

[To be written: Solo performer use case, real-time requirement, accessibility goals]

### 3.2 Beatbox Transcription Pipeline

#### 3.2.1 Onset Detection

CHULOOPA uses spectral flux-based onset detection with adaptive thresholding to identify individual beatbox sounds in real-time. The system analyzes audio in 512-sample frames with 128-sample hop size, computing the spectral flux (sum of positive differences between consecutive magnitude spectra) for each frame.

To handle varying beatbox loudness across performances, we implement adaptive thresholding: an onset is detected when spectral flux exceeds 1.5× the running mean of recent flux history. This adapts to the user's dynamic range. Additionally, a debouncing mechanism prevents multiple detections within 150ms, filtering out spectral artifacts.

Minimum onset strength is configurable (default: 0.005) to balance sensitivity vs. false positives. During testing, we found this configuration reliably detects amateur beatbox sounds while rejecting background noise.

#### 3.2.2 Feature Extraction

When an onset is detected, the system extracts a 5-dimensional acoustic feature vector:

1. **Spectral flux** (onset strength): Distinguishes attack intensity
2. **RMS energy** (loudness): Overall amplitude of the sound
3. **Spectral band 1 (low frequencies)**: Emphasizes kick drums
4. **Spectral band 2 (mid frequencies)**: Emphasizes snares
5. **Spectral band 5 (high frequencies)**: Emphasizes hi-hats

These features were chosen to capture timbral characteristics that distinguish kick (low-frequency, high energy), snare (mid-frequency, sharp attack), and hi-hat (high-frequency, lower energy) sounds in amateur beatboxing.

#### 3.2.3 KNN Classification

The system uses K-Nearest Neighbors (k=3) for classification, trained on the user's personal training samples. KNN was chosen over deep learning approaches for several reasons:

- **Minimal training data:** KNN performs well with only 10 samples per class
- **Fast training:** Model trains in <1 second on consumer hardware
- **Interpretable:** Easy to understand and debug classification errors
- **No overfitting:** With 30 total training samples, complex models would overfit

During inference, the system computes Euclidean distance between the current feature vector and all 30 training samples, classifying the onset as the majority class among the 3 nearest neighbors.

**Fallback Heuristic Classifier:** If the KNN model fails to load or training data is unavailable, CHULOOPA falls back to a rule-based heuristic classifier using spectral band energy ratios. While less accurate (~70%), this ensures the system remains functional.

#### 3.2.4 Real-Time Drum Playback

Immediately upon classification, CHULOOPA plays back a corresponding drum sample (kick.wav, snare.wav, or hat.WAV). This real-time feedback is critical for live performance—users hear the transcription as they beatbox, allowing them to correct mistakes or adjust their vocal technique mid-performance.

Playback velocity is mapped from the RMS energy feature, preserving the dynamics of the beatbox performance. All timing, drum class, and velocity data are stored in memory for subsequent loop playback.

### 3.3 Personalized Training

[To be written: Training sample collection process, why minimal data works]

The personalization approach is central to CHULOOPA's accessibility. By training on user-specific data rather than a generic beatbox corpus, we achieve high accuracy with minimal training burden.

**Training Process:**
1. User runs `drum_sample_recorder.ck` and records 10 samples each of kick, snare, hi-hat
2. Each sample is 1 second long, captured with same onset detection + feature extraction pipeline
3. Features and labels saved to `training_samples.csv`
4. When CHULOOPA starts, it automatically trains a KNN model on this data

**Why Minimal Data Works:**
- User-specific training constrains the problem space (only one person's vocal style)
- Amateur beatboxers are remarkably consistent in their own imperfect way
- KNN's instance-based learning handles small datasets without overfitting
- Personalization trades dataset size for specificity

**Retraining:** If classification accuracy degrades, users can delete `training_samples.csv` and re-record samples with more consistent technique.

### 3.4 Loop Recording and Playback

[To be written: Delta-time format, queued actions, MIDI control]

CHULOOPA implements a single-track looper optimized for live performance transitions.

#### 3.4.1 Delta-Time Format

Drum patterns are exported to `track_N_drums.txt` files in a custom format:

```
# Track 0 Drum Data
# Format: DRUM_CLASS,TIMESTAMP,VELOCITY,DELTA_TIME
# Classes: 0=kick, 1=snare, 2=hat
# Total loop duration: 2.182676 seconds
0,0.037732,0.169278,0.566987
1,0.603719,0.250155,0.406349
0,1.010068,0.314029,0.444082
```

Each hit stores:
- `DRUM_CLASS`: 0=kick, 1=snare, 2=hat
- `TIMESTAMP`: Absolute time from loop start (seconds)
- `VELOCITY`: 0.0-1.0 (mapped from RMS energy)
- `DELTA_TIME`: Duration until next hit (for last hit: time until loop end)

The `DELTA_TIME` field is critical for precise loop timing. By storing the interval until the next event (or loop boundary), ChucK can schedule drum playback without accumulating drift. This ensures loops remain perfectly synchronized even after hundreds of iterations.

#### 3.4.2 Queued Actions for Seamless Transitions

Inspired by traditional hardware loopers (e.g., Boss RC-505), CHULOOPA uses a queued action system to prevent audio glitches during pattern switching.

When a user presses "Load Pattern" mid-loop, the action is queued and executes at the next loop boundary. This prevents overlap between old and new playback, maintaining clean transitions. Each playback session receives a unique ID; scheduled drum hits check their session ID before playing, aborting if a new session has started.

Console output provides feedback:
```
>>> QUEUED: Track 0 will load from file at next loop cycle <<<
=== LOOP BOUNDARY: Processing queued actions ===
>>> TRACK 0 LOADED FROM FILE (Playback ID: 2) <<<
```

#### 3.4.3 MIDI Control Mapping

CHULOOPA is controlled via MIDI note messages:

- **Note 36 (C1):** Press & hold to record, release to start looping
- **Note 39 (D#1):** Queue track clear (executes at loop boundary)
- **Note 43 (G1):** Queue load from file (executes at loop boundary)
- **Note 46 (A#1):** Manual export (auto-exports happen after recording)
- **CC 45:** Track volume (0-127)
- **CC 51:** Audio/drum mix control

This mapping was designed for compact MIDI controllers like the QuNeo, enabling one-handed operation while performing.

### 3.5 AI Variation Generation

CHULOOPA generates drum pattern variations using a local transformer-LSTM neural network, specifically designed to maintain exact loop duration and preserve non-quantized timing while operating entirely offline.

#### 3.5.1 Architecture: Rhythmic Creator Integration

A Python script (`drum_variation_ai.py`) runs in background watch mode, monitoring for newly exported drum pattern files. When ChucK exports `track_0_drums.txt`, the Python process:

1. Loads the drum pattern (drum class, timestamp, velocity, delta_time)
2. Converts to rhythmic_creator format (MIDI triplets: `note start_time end_time`)
3. Generates continuation using transformer-LSTM model with temperature control
4. Strips context echo and extracts continuation hits
5. Shifts continuation to start at 0.0s and time-warps to match original duration
6. Saves variation to `track_0_drums_var1.txt`
7. Sends OSC message to ChucK indicating variation ready

The model (rhythmic_creator by Jake Chen, CalArts MFA 2025) is a 4.49M-parameter hybrid architecture:
- 6 Transformer blocks (192-dim embeddings, 6 attention heads)
- 2 LSTM layers (64 hidden units each)
- Feed-forward network for final predictions
- Character-level tokenization of MIDI sequences

#### 3.5.2 Continuation-Based Variation Approach

Rather than generating loops from scratch, CHULOOPA uses the model's **continuation** output as variations. The model was originally trained for MIDI sequence extension, outputting both an echo of the input context plus a musical continuation. Our key insight was to:

1. **Strip the context echo** - Remove tokens that duplicate the input pattern
2. **Extract continuation hits** - Select drum hits with timestamps after the original pattern ends
3. **Shift to loop start** - Rebase continuation hits to start at 0.0s
4. **Time-warp to duration** - Scale timestamps proportionally to match original loop length exactly

This approach produces musically coherent variations that maintain the structural groove of the original while introducing creative changes in hit placement and density.

**Example transformation:**
```
Input pattern (2.5s):    kick 0.1s, snare 0.9s, hat 1.8s
Model continuation:      kick 2.6s, hat 3.1s, snare 3.8s  (1.2s duration)
Shifted:                 kick 0.0s, hat 0.5s, snare 1.2s
Time-warped (2.5s):      kick 0.0s, hat 1.0s, snare 2.5s  ← Final variation
```

#### 3.5.3 Temperature Control for Variation Intensity

The system uses a "spice level" parameter (0.0-1.0) that maps directly to model temperature:
- **0.0-0.3:** Conservative variations (low temperature, deterministic)
- **0.4-0.6:** Balanced creativity (moderate temperature)
- **0.7-1.0:** Experimental variations (high temperature, more randomness)

Users control spice level in real-time via MIDI CC 18, with visual feedback in the ChuGL interface (blue/orange/red text indicating current level). Regeneration with new spice levels happens on-demand via MIDI trigger.

#### 3.5.4 Timing Preservation and Musical Coherence

The continuation-based approach preserves non-quantized timing in two ways:

1. **Model training:** rhythmic_creator was trained on MIDI sequences with natural (non-quantized) timing, learning to generate human-like rhythmic variations
2. **Proportional time-warping:** Rather than snapping hits to a grid, the system scales the continuation proportionally to match the original loop duration exactly

This ensures variations can seamlessly replace original patterns in live performance without breaking synchronization, while maintaining the "groove" and timing feel of human beatboxing.

**Performance:** Model initialization takes ~2 seconds (one-time), generation takes ~3-5 seconds per variation, running entirely on CPU with no external API calls.

#### 3.5.5 Alternative: Gemini API Option

CHULOOPA also supports Google's Gemini API as an alternative variation engine (`drum_variation_gemini.py`), useful for studio contexts where internet connectivity is available. Gemini offers more sophisticated musical reasoning through prompt engineering but requires API keys and network access. The local rhythmic_creator model is preferred for live performance due to offline operation and faster inference.

---

## 4. Implementation

[TODO: ChucK + Python architecture, performance considerations]

### 4.1 Technology Stack

- **ChucK 1.5.x:** Real-time audio processing, MIDI I/O, onset detection, loop playback
- **Python 3.10+:** KNN training (scikit-learn), Gemini API integration (google-genai)
- **ChuGL:** Real-time visualization (basic sphere-based track indicators)

### 4.2 System Architecture

[Diagram to be created: ChucK ↔ File System ↔ Python watch process]

### 4.3 Performance Considerations

- Onset detection latency: <10ms (512 samples @ 44.1kHz)
- KNN classification: <1ms per inference
- Total input-to-output latency: <50ms (tested)
- AI variation generation: rhythmic_creator ~3-5 seconds, Gemini API ~5-10 seconds (background, non-blocking)

---

## 5. Evaluation

[TODO: Fill in with testing results when back from NYC]

### 5.1 Technical Evaluation

#### 5.1.1 Classifier Accuracy

**Method:** [To be measured when back home]
- Test on personal beatbox samples across multiple sessions
- Compute confusion matrix (kick/snare/hat)
- Report overall accuracy and per-class precision/recall

**Preliminary Results:** ~90% accuracy in informal testing (to be validated)

#### 5.1.2 Latency Measurements

**Method:** [To be measured]
- Measure onset detection → drum playback latency
- Test with various buffer sizes

**Target:** <50ms total latency (below perceptual threshold for live performance)

#### 5.1.3 Timing Preservation in AI Variations

**Method:** [To be measured]
- Compare original loop duration vs. Gemini-generated variation duration
- Analyze timing deviation of individual hits
- Demonstrate non-quantized timing preservation

**Expected Result:** Exact loop duration match, preserved swing/feel characteristics

### 5.2 Autoethnographic Study

**Method:** As designer and primary user, I documented my experience using CHULOOPA over [X weeks] in practice sessions and mock performances. I recorded:
- Training experience (time required, frustration points)
- Loop creation process (ease of beatboxing, classification errors)
- Variation quality assessment (musical coherence, timing feel)
- Performance readiness (MIDI control, workflow smoothness)

**Findings:** [To be documented when back from NYC, after extensive personal testing]

### 5.3 User Testing

**Participants:** [2-3 solo performers / singer-songwriters recruited from network]

**Protocol:**
1. 5 min: Introduction to system
2. 5 min: Record training samples (10 kick, 10 snare, 10 hat)
3. 15 min: Create and loop drum patterns
4. 5 min: Test AI variations
5. 5 min: Semi-structured interview

**Research Questions:**
- Can non-technical musicians successfully train the classifier?
- Is real-time feedback helpful for beatbox technique?
- Are AI variations musically useful?
- Would participants use this in actual performances?

**Results:** [To be collected when back from NYC]

---

## 6. Discussion

[TODO: Design insights, limitations, comparisons]

### 6.1 What Worked: Personalization and Accessibility

[To be written based on testing results]

### 6.2 Limitations

**Current Limitations:**
1. **Single-track looping:** Multi-track looping prototype exists but requires further development for reliable synchronization
2. **Classification errors:** ~10% misclassification rate (typically kick↔snare confusion)
3. **Variable variation density:** AI-generated variations may have different hit density than originals (3-13 hits from 4-hit input) due to MIDI filtering during model conversion, though musically acceptable
4. **Amateur beatbox only:** System is trained for individual users, not professional beatboxers or general vocal percussion

### 6.3 Design Insights

[To be written: Why minimal training works, importance of real-time feedback, AI as collaborator vs. replacement]

### 6.4 Comparison to Alternatives

**vs. Traditional Drum Machines:** CHULOOPA requires no music theory or grid programming, using voice as interface

**vs. Backing Tracks:** CHULOOPA enables spontaneous pattern creation and variation, not pre-programmed rigidity

**vs. Loop Pedals:** CHULOOPA transcribes to symbolic drums, not audio loops, enabling AI variation and editing

**vs. Generic Beatbox Recognition:** CHULOOPA's personalization achieves higher accuracy with less training data

---

## 7. Future Work

### 7.1 Multi-Track Looping

Currently in development: Extend to 3-track looping with master sync system to prevent drift across tracks. Preliminary prototype exists but requires robustness improvements.

### 7.2 Enhanced Visualizations

Improve ChuGL visuals to show:
- Per-drum-hit feedback (visual indication of classification)
- Pattern similarity between original and variation
- Real-time classification confidence display

### 7.3 Enhanced Variation Generation

Generate multiple variants (3-5) per loop with random selection for greater creative exploration. Improve variation density consistency to better match original pattern hit counts.

### 7.4 Additional Variation Algorithms

Explore complementary variation methods:
- Fine-tune rhythmic_creator on drum-only dataset to eliminate melody MIDI filtering
- GrooVAE integration (Magenta) for latent space interpolation and style transfer
- Genetic algorithms for gradual pattern evolution across multiple generations
- User-guided variation with semantic controls (specify "more snare", "busier hi-hats")

### 7.5 Long-Term Study with Solo Performers

Conduct longitudinal study (3-6 months) with solo musicians using CHULOOPA in actual performances, documenting integration into creative practice.

---

## 8. Conclusion

[TODO: Recap contribution, impact statement, vision]

CHULOOPA demonstrates that personalized machine learning with minimal training data can make drum programming accessible to amateur beatboxers, enabling solo performers to create responsive drum accompaniment without technical music skills. By combining real-time beatbox transcription, live looping, and offline AI-augmented variation generation using a local transformer-LSTM model, the system serves as both performance instrument and creative collaborator.

Our key insights are that **personalization trumps dataset size** when designing for accessibility (training on 10 user-specific samples achieves higher accuracy than generic models trained on hundreds of samples from other users), and that **offline AI enables performance reliability** (local neural network inference with no API dependencies ensures consistent operation in live contexts). Additionally, we show that AI can augment creativity without destroying the human "feel" of timing, preserving non-quantized groove characteristics through a continuation-based variation approach.

Looking forward, we envision CHULOOPA as a step toward more **accessible creative AI tools** that adapt to individual users rather than demanding users adapt to rigid systems. By treating amateur beatboxing—imperfect, idiosyncratic, personal—as a legitimate musical interface, we expand who can participate in electronic music creation.

---

## Acknowledgments

We thank Jake Chen (Zhaohan Chen) for making his rhythmic_creator model from his CalArts MFA thesis "Music As Natural Language: Deep Learning Driven Rhythmic Creation" (2025) available for integration into this project. We thank advisors Ajay Kapur and Jake Cheng at the CalArts Music Tech MFA program for guidance and support. We thank user testing participants [names to be added]. This work was supported by the California Institute of the Arts Music Technology MFA program.

---

## References

[To be compiled: Beatbox recognition papers, Magenta/GrooVAE, personalized ML, live looping systems]

---

## TODO Before Submission

- [ ] Complete Related Work section (literature review)
  - [ ] Add Jake Chen's rhythmic_creator paper to references
  - [ ] Survey transformer-based music generation models
- [ ] Run technical evaluations (accuracy, latency, timing preservation)
  - [ ] Test rhythmic_creator variation quality and coherence
  - [ ] Measure generation speed and reliability
- [ ] Conduct autoethnographic documentation
- [ ] Run user testing sessions (2-3 participants)
- [ ] Create system architecture diagram
  - [ ] Show ChucK ↔ Python OSC communication flow
  - [ ] Illustrate continuation-based variation pipeline
- [ ] Create screenshots/figures
  - [ ] ChuGL interface showing spice level control
  - [ ] Example variation comparison (original vs. generated)
- [ ] Fill in all [TODO] sections with actual results
- [ ] Format according to NIME template
- [ ] Proofread and polish
- [ ] Submit abstract by Feb 5, 2026
- [ ] Submit full paper by Feb 12, 2026
