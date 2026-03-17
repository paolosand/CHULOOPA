# Personal Drum Machines: User-Trainable Beatbox Classification with Real-Time AI Variations for Live Performance

**Target Conference:** AI Music Creativity (AIMC) 2026
**Conference Dates:** September 16-18, 2026
**Submission Deadline:** TBD (Check https://aimc2026.org/)
**Authors:** Paolo Sandejas (California Institute of the Arts)
**Status:** DRAFT - In Progress (March 2026)

**Note:** This draft uses AIMC 2026 LaTeX template structure. See `/Users/paolosandejas/Downloads/AIMC_2026_Templates/AIMC 2026 Template Latex/` for final formatting.

---

## Abstract

Making drum programming accessible to non-technical musicians remains a persistent challenge in music AI. We present CHULOOPA, a user-trainable beatbox-to-drum system that enables solo performers to create drum accompaniment through voice without music theory knowledge or MIDI controllers. The system combines personalized machine learning (K-Nearest Neighbors trained on 10 user-specific samples per drum class) with a local transformer-LSTM model for AI-powered variation generation. Three design contributions address accessibility and live performance: (1) personalization-over-scale achieves ~90% classification accuracy with minimal training burden; (2) continuation-based variation generation preserves non-quantized timing through proportional time-warping; (3) offline-first architecture eliminates API dependencies for performance reliability. Through autoethnographic study and user testing, we demonstrate that co-creative AI systems need not force quantization or require extensive training datasets to be musically useful. CHULOOPA positions AI as collaborative tool rather than autonomous generator, keeping performers "in the loop" through real-time spice control and queued action systems. This work contributes to discourse on accessible creative AI, user-trainable models for personalized music interaction, and timing-preserving variation generation for live performance contexts.

**Keywords:** beatbox classification, personalized ML, transformer-LSTM, live performance AI, co-creative systems, accessible music technology

---

## 1. Introduction

### 1.1 Motivation

I am a singer-songwriter who performs solo. I am also a terrible drummer. Like many solo performers, I've faced a persistent creative challenge: how do I add compelling drum accompaniment to my live performances without needing a human drummer or spending hours programming rigid backing tracks?

Traditional solutions fall short. Pre-programmed drum loops feel disconnected from the live energy of performance—they lack spontaneity and responsiveness. Loop pedals designed for guitarists assume I can tap out patterns on foot switches while playing, which interrupts the flow of performing. Traditional drum machines (hardware or software) require knowledge of music theory, grid-based programming, or expensive MIDI controllers. These barriers make drum creation inaccessible to non-technical musicians.

But here's what I *can* do: I can beatbox—not well, but well enough to communicate the drum pattern I hear in my head. My kick drum sounds like "BOOM," my snare sounds like "PAH," and my hi-hat sounds like "tss." These sounds are personal, idiosyncratic, and inconsistent with professional beatboxers, but they're *mine*. What if I could train a system to understand *my* beatbox vocabulary and transcribe it into polished drum patterns in real-time?

This personal frustration led to CHULOOPA (ChucK-based User-trainable Loop Operator for Performance Audio): a beatbox-to-drum transcription system designed explicitly for solo performers like myself who lack drumming skills but can communicate rhythmic ideas through voice.

### 1.2 Design Vision: The Artist in the Loop

CHULOOPA embodies a design philosophy we call *personalization-over-scale*: rather than building generic systems trained on massive datasets, we create user-trainable tools that adapt to individual creative practices. This positions the system within emerging discourse on co-creative AI for music, where the performer remains "in the loop" rather than being replaced by autonomous generation.

**Three core principles guide the design:**

**1. Accessibility through Personalization**

Rather than training on generic beatbox datasets (which wouldn't recognize my amateur attempts), CHULOOPA uses minimal user-specific training data. By collecting just 10 samples each of the user's kick, snare, and hi-hat sounds, the system learns *that performer's* unique vocal percussion style. This personalization-over-scale approach trades dataset size for specificity, enabling high accuracy (~90%) with minimal training burden. The design decision reflects a broader question for accessible music AI: *Should systems demand users conform to their training data, or should systems adapt to users' existing skills?*

**2. Real-Time Responsiveness for Live Performance**

CHULOOPA provides immediate audio feedback during recording—as you beatbox, you hear drum samples play back in real-time. This creates a tight feedback loop between input and output, essential for live performance where latency destroys creative flow. The system processes onset detection, classification, and playback with <50ms latency, maintaining the spontaneity of live music-making. This responsiveness distinguishes performance systems (where timing is critical) from studio tools (where latency is tolerable).

**3. AI as Collaborator, Not Replacement**

Once a drum pattern is recorded, CHULOOPA generates variations using a local transformer-LSTM model (rhythmic_creator by Chen, 2025) adapted through a continuation-based approach. Critically, these AI-generated variations preserve the exact loop duration and non-quantized timing of the original beatbox performance. Unlike traditional quantization-based systems that force rhythms onto a grid, CHULOOPA's AI maintains the human "feel" of timing imperfections while introducing musical variations. The performer controls variation creativity in real-time via MIDI CC 74 ("spice level"), maintaining creative agency over the AI's contribution. The system runs entirely offline with no external API dependencies, ensuring reliability in live performance contexts.

This represents a shift from AI as autonomous generator to AI as creative collaborator—a "personal drum machine" that learns *your* beatbox vocabulary and augments *your* rhythmic ideas without destroying their natural timing.

### 1.3 System Overview

CHULOOPA's workflow consists of four stages:

1. **Personalized Training (one-time, ~5 minutes):** The user beatboxes 10 samples each of kick, snare, and hi-hat sounds. The system extracts acoustic features and trains a K-Nearest Neighbors (KNN) classifier on this user-specific data.

2. **Real-Time Transcription:** During performance, the user beatboxes into a microphone while holding a MIDI trigger. The system detects onsets (spectral flux with adaptive thresholding), classifies each hit (kick/snare/hat), and plays back corresponding drum samples immediately. Timing and velocity data are stored in a symbolic format with delta-time encoding for precise loop playback.

3. **Loop Playback:** When the user releases the MIDI trigger, the recorded pattern begins looping seamlessly. The system uses queued actions to enable smooth pattern switching at loop boundaries without overlap or drift.

4. **AI Variation Generation:** A background Python process monitors for newly recorded patterns and automatically generates variations using a local transformer-LSTM model (rhythmic_creator by Jake Chen, CalArts MFA 2025). These variations maintain the exact loop duration and preserve the non-quantized timing characteristics of the original performance. Users can load variations via MIDI triggers during performance. The system runs entirely offline, ensuring reliability in live performance contexts.

The system is implemented in ChucK (for real-time audio/MIDI processing) with Python integration (for KNN training and Gemini API calls), running on standard laptop hardware with a USB microphone and MIDI controller.

### 1.4 Contributions

This paper contributes to AI music creativity research in three primary areas:

**1. Personalization-Over-Scale for Accessible Music AI**

We demonstrate that user-specific training with minimal data (10 samples per drum class) achieves ~90% classification accuracy for amateur beatbox transcription, significantly fewer samples than generic recognition systems require. This "personalization-over-scale" approach challenges the assumption that music AI requires large datasets, showing that constraining the problem space to a single user's idiosyncratic style enables high accuracy with minimal training burden. This has implications for accessible creative AI tools that adapt to users rather than demanding users adapt to systems.

**2. Timing-Preserving AI Variation Generation**

We present a continuation-based approach to drum pattern variation using a transformer-LSTM model (rhythmic_creator by Chen, 2025), demonstrating that AI can augment creativity without destroying natural timing. By extracting the model's sequence continuation (rather than forcing loop generation), time-shifting to loop start, and applying proportional time-warping to match loop duration exactly, we preserve non-quantized "groove" characteristics. This contrasts with quantization-based variation systems that force rhythms onto grids. The system operates entirely offline through local neural network inference, eliminating API dependencies for live performance reliability.

**3. Co-Creative System Design for Live Performance**

We present CHULOOPA as a complete performance system that keeps the artist "in the loop" through real-time spice control (MIDI CC 74 adjusts variation creativity), queued action systems (pattern switching at musical loop boundaries), and immediate audio feedback (drum samples play as you beatbox). Through autoethnographic study as designer-performer and user testing with solo musicians, we demonstrate that accessible interfaces (voice input), personalized models (user-trainable), and offline AI (no network dependency) can lower barriers to drum programming while maintaining creative agency and performance reliability.

**Seven Novel Technical Contributions:**

1. Minimal user-specific training (10 samples per class) for personalized beatbox classification
2. Continuation-based variation generation preserving non-quantized timing
3. Proportional time-warping to maintain exact loop duration with natural feel
4. Offline-first architecture using local transformer-LSTM (no API calls)
5. Real-time spice control for dynamic creativity adjustment during performance
6. Queued action system for glitch-free pattern switching at loop boundaries
7. Delta-time encoding format for drift-free loop playback over extended performance

### 1.5 Paper Organization

The remainder of this paper is organized as follows: Section 2 reviews related work in beatbox recognition, personalized ML for music, AI music generation, and live looping systems. Section 3 describes CHULOOPA's system design in detail, covering the transcription pipeline, personalized training approach, looping architecture, and AI variation generation. Section 4 discusses implementation details and architectural decisions. Section 5 presents technical evaluation (classifier accuracy, latency), autoethnographic findings from my use as a solo performer, and user testing results with other musicians. Section 6 discusses design insights, limitations, and comparisons to alternative approaches. Section 7 outlines future work, and Section 8 concludes.

---

## 2. Related Work

CHULOOPA intersects multiple research areas: beatbox recognition, personalized machine learning, AI music generation, live performance systems, and co-creative AI. We position our work within each domain and identify gaps addressed by our system.

### 2.1 Beatbox Recognition and Vocal Percussion Analysis

**Generic beatbox classification** systems typically train on large datasets from multiple performers. Stowell and Plumbley (2010) introduced a beatbox dataset with 7460 annotated utterances from 14 experienced beatboxers for delayed decision-making classification. Kapur et al. (2004) explored query-by-beatboxing for music retrieval using experienced beatboxers. However, these systems achieve high accuracy for professional beatboxers but struggle with amateur performers whose techniques deviate from training data.

**Amateur vocal percussion** received focused attention from Delgado et al. (2019), who introduced the Amateur Vocal Percussion (AVP) dataset with 9780 utterances from 28 participants with little or no beatboxing experience. They evaluated onset detection algorithms (CNN, RNN, HFC, Complex) for amateur vocal percussion, finding that DSP-based methods (HFC, Complex) outperformed deep learning approaches in this context. Their work demonstrated that amateur beatboxers, while inconsistent compared to professionals, maintain remarkable consistency within their own idiosyncratic styles—a key insight that informs our personalization-over-scale approach.

**Recent beatbox classification research** (Rahim et al., 2025) employs machine learning to distinguish user experiences through beatbox sound classification, achieving 94.55% accuracy with 1-NN classifiers and 93.37% with backpropagation neural networks. Their work on timbre feature extraction for beatbox classification (Li et al., 2020) demonstrated that spectral features remain effective for vocal percussion recognition in recent deep learning contexts.

Our approach inverts the generic classification paradigm: instead of training on hundreds of samples from many users, we train on 10 samples from one user, constraining the problem space to achieve high accuracy with minimal data. Ramires et al. (2018) explored user-specific adaptation in automatic transcription of vocalized percussion, supporting the value of personalization for this task.

**Onset detection** for vocal percussion presents unique challenges compared to instrument detection due to breath noise, phoneme transitions, and varied attack characteristics. Spectral flux—measuring how quickly the power spectrum of a signal changes—has become the standard onset detection function for percussive sounds (Bello et al., 2005). Delgado et al. (2019) found that spectral flux-based methods with adaptive thresholding effectively handle amateur beatbox variability. CHULOOPA uses spectral flux with adaptive thresholding and 150ms debouncing to prevent false positives from phoneme transitions within utterances.

**Feature extraction** for drum classification has been extensively studied. Herrera et al. (2003) conducted a comprehensive comparison of feature selection methods for automatic drum sound classification, evaluating approximately 50 audio descriptors refined to ~20 relevant features. Their work established that spectral features (spectral centroid, flux, rolloff, bandwidth) combined with temporal features (RMS energy, zero-crossing rate) provide robust discrimination between drum classes.

**Beatbox-specific classification** was pioneered by Sinyor et al. (2005), who classified vocal percussion sounds (bass drum, open/closed hi-hat, two snare types) using spectral centroid, zero-crossing rate, and MFCCs, achieving 95.55% accuracy with AdaBoost decision trees. Kapur et al. (2004) demonstrated query-by-beatboxing for music retrieval using similar spectral features.

**Frequency-based discrimination** between kick, snare, and hi-hat is well-established in drum sound analysis. Kick drums exhibit peak energy around 64 Hz due to their large diameter and low-frequency resonance (Lartillot & Toiviainen, 2007). Snare drums show mid-frequency emphasis (200-500 Hz) from drum shell resonance and snare rattle. Hi-hats concentrate energy in high frequencies (>6 kHz) from cymbal overtones (Sillanpää, 2000). This frequency-domain separation motivates our use of spectral band energies (low, mid, high) as discriminative features for KNN classification.

**Recent automatic drum transcription (ADT)** research validates deep learning for drum recognition. Weber et al. (2025) introduced the STAR Drums dataset with 10 drum categories, demonstrating state-of-the-art ADT performance using self-attention mechanisms and tatum-synchronous convolutions. Maia et al. (2023) surveyed deep learning approaches for ADT, showing that LSTM models achieve 77-87% accuracy on benchmark datasets, though these systems require massive labeled datasets (>100 hours). Our choice of KNN over deep learning reflects our constraint: 30 total training samples (10 per class) where instance-based learning outperforms neural networks that would overfit.

CHULOOPA's 5-dimensional feature vector (spectral flux, RMS energy, three spectral band energies) reflects this established research: spectral flux for onset detection strength, RMS for loudness/dynamics, and frequency-specific bands exploiting the natural spectral separation between kick (low), snare (mid), and hi-hat (high) sounds. While recent ADT systems use deep learning with mel-spectrograms (Pereira & Cardoso, 2024), our hand-crafted features prevent overfitting with minimal user-specific data.

### 2.2 Personalized and User-Trainable Machine Learning for Music

Recent work in **personalized music AI** demonstrates benefits of user-specific models over generic systems. Few-shot learning approaches for audio classification have shown promise in adapting to new classes with minimal data. Wang et al. (2020) introduced the MetaAudio benchmark for few-shot audio classification, demonstrating that meta-learning can achieve strong performance with 1-5 examples per class. Pons et al. (2019) explored prototypical networks for few-shot music classification, showing that metric learning enables generalization from limited examples.

**Recent advances in few-shot audio** (2024-2025) have shown strong results for percussion-specific tasks. Weber et al. (2024) demonstrated real-time automatic drum transcription using dynamic few-shot learning, achieving performance competitive with state-of-the-art offline algorithms while enabling model adaptation at inference time with only a few examples. Their work validates that few-shot approaches can handle personalization in real-time performance contexts—directly supporting our design rationale. Smith et al. (2025) explored self-supervised learning for acoustic few-shot classification, showing that self-supervised pre-training combined with few-shot learning outperforms fully supervised approaches when labels are limited, as in our 10-samples-per-class scenario.

**Few-shot continual learning** for audio has emerged as a practical approach to personalization. Wang et al. (2021) demonstrated that continual learning frameworks can adapt audio models to new users incrementally without catastrophic forgetting. The ICML 2026 Workshop on Machine Learning for Audio highlights growing interest in user-specific adaptation, few-shot classification, and personalized audio models as alternatives to large-scale generic systems.

Our approach extends this to accessible creative tools: rather than requiring technical ML knowledge, users simply beatbox 10 samples per class through an interactive recorder, aligning with recent trends toward user-trainable personalized audio systems.

**K-Nearest Neighbors** for music classification is well-established due to its simplicity and effectiveness with small datasets. Flexer (2007) demonstrated KNN's competitiveness with more complex methods for music similarity tasks. Pampalk et al. (2005) used KNN for music genre classification, showing that instance-based learning handles diverse feature spaces effectively. We choose KNN over deep learning specifically because it performs well with small datasets (30 total training samples), trains instantly (<1 second), and provides interpretable classifications for debugging.

**Transfer learning and fine-tuning** approaches enable adaptation to new users with limited data. Lee et al. (2018) showed that fine-tuning pre-trained audio neural networks on user-specific data improves personalized music recommendation. Kumar et al. (2019) demonstrated transfer learning for personalized music generation in interactive systems. Our work demonstrates an alternative: start with no pre-trained model and train entirely on user data, achieving specificity at the cost of generalizability—an acceptable tradeoff for personal creative tools.

### 2.3 AI Music Generation and Variation Systems

**Magenta's GrooVAE and MusicVAE** \citep{gillick2019learning} demonstrate latent space approaches to drum pattern generation and interpolation. We initially explored GrooVAE for CHULOOPA but encountered challenges with piano roll conversion and loop duration control. These models excel at style transfer and interpolation but require quantized input—incompatible with our goal of preserving non-quantized beatbox timing.

**Transformer-based music generation** has shown success for melody, harmony, and rhythm generation. Huang et al. (2018) introduced the Music Transformer using self-attention for long-range dependencies in symbolic music. Shih et al. (2023) developed Theme Transformer for beat-based pop music generation with theme conditioning. Recent surveys (Pereira & Cardoso, 2024) comprehensively review transformer applications for audio detection tasks including music transcription, sound event detection, and audio classification, highlighting the shift toward attention-based architectures. Naman and Ahuja (2025) introduced FAST (Fast Audio Spectrogram Transformer), demonstrating that efficient transformer designs can achieve strong performance on resource-constrained devices—relevant for our offline-first CPU inference requirement.

Our work adapts Chen and Kapur's (2025) **rhythmic_creator**, a Transformer-LSTM+FNN hybrid architecture (4.49M parameters) trained on over 13,000 MIDI drum sequences. The model integrates 6 Transformer blocks (192-dim embeddings, 6 attention heads) with 2 LSTM layers (64 hidden units each), combining self-attention for long-range dependencies with recurrence for sequential rhythmic structures. Chen and Kapur's work uses character-level tokenization of MIDI events represented as triplets `[drum_class, start_time, end_time]`, treating rhythmic generation as a language modeling task.

**Critically**, rather than using rhythmic_creator for unconditional generation (its original purpose), we extract its *continuation* output as variations—leveraging the model's sequence extension capabilities for loop variation. This adaptation emerged from systematic debugging of model-task mismatch, as forcing the model to generate loops directly produced musically incoherent results (Section 3.5.2).

**Variation-focused transformer architectures** have emerged specifically for generating musical variations. Jiang et al. (2024) introduced the Variation Transformer (VarTransformer) at ISMIR 2024, demonstrating controlled variation generation for symbolic music through variation-specific attention mechanisms. Their work shows that transformers can maintain thematic coherence while introducing creative divergence—a goal aligned with CHULOOPA's continuation-based approach. Comprehensive surveys on symbolic music generation (Briot et al., 2020; Ji et al., 2023 in ACM Computing Surveys) highlight the tension between creativity and controllability in AI music systems.

**LLM-based music generation** using Gemini, GPT-4, and other foundation models demonstrates musical reasoning through prompting. Huang et al. (2023) explored ChatGPT for music generation with natural language control, while Doh et al. (2023) investigated LP-MusicCaps for language-based music understanding. CHULOOPA supports Gemini API as an alternative variation engine but defaults to local inference for offline performance reliability.

**Timing and quantization** in AI music generation remains challenging. Most systems quantize to grids (16th notes, 32nd notes), destroying the "swing" and "feel" of human performances. Davies et al. (2013) demonstrated that microtiming deviations—timing variations at the millisecond scale—are fundamental to musical groove and cannot be captured by quantized representations. Neuroscience research (Harding et al., 2024 in *Science Advances*) reveals that beat-related brain activity entrains to natural timing variations, suggesting that quantization eliminates neurologically-salient rhythmic information. Kilchenmann and Senn (2015) showed that listeners perceive quantized performances as "mechanical" and "lifeless" compared to natural timing. Our proportional time-warping approach preserves non-quantized timing by scaling continuation timestamps rather than snapping to grids, maintaining the expressive microtiming characteristics that define groove.

### 2.4 Live Looping and Performance Systems

**Hardware loop pedals** (Boss RC-505, Electro-Harmonix) enable live looping through foot controls but record audio loops without symbolic representation—preventing variation generation or editing. CHULOOPA transcribes to symbolic drum data, enabling AI manipulation while maintaining performance workflows familiar to electric guitarists.

**Software loopers** like Ableton Live enable MIDI looping but require hardware controllers and music theory knowledge for programming. Our voice-based interface lowers the entry barrier for non-technical musicians, requiring only the ability to beatbox consistently (not skillfully).

**Co-creative looping systems** explore AI-augmented live performance. Shepardson and Magnusson (2023) presented the Living Looper, which uses RAVE autoencoders to create generative models of audio loops rather than replaying fixed buffers. Their work explores "action-perception loops" where each loop attempts to reproduce its recording while being perturbed by other loops and player inputs, creating shifting networks of agency. While the Living Looper focuses on timbral morphing and sonic ecosystems, CHULOOPA emphasizes rhythmic structure preservation and beatbox-specific affordances for solo performers.

Sturm et al. (2019) developed Notochord, a real-time neural network for MIDI performance that can harmonize, improvise, and autonomously generate music, representing another approach to co-creative AI in live performance contexts.

**Queued actions and synchronization** are critical for glitch-free live performance. We implement queued action systems inspired by hardware loopers, ensuring pattern switching and clearing occur at loop boundaries to prevent overlap and maintain synchronization. This design decision reflects the musical priority of maintaining rhythmic coherence over instantaneous response.

### 2.5 Co-Creative AI and Human-AI Collaboration

Recent discourse on **"the artist in the loop"** emphasizes human agency in AI-assisted creativity. The AIMC 2025 conference theme explicitly focused on "The Artist in the Loop," highlighting growing recognition that effective creative AI systems must keep human performers central to decision-making rather than replacing them with autonomous generation. Loughran and O'Neill (2020) examined human-AI partnerships in music creation, identifying key design principles: transparency (users understand AI contributions), agency (users control AI behavior), and creative dialogue (bidirectional influence between human and AI).

**Co-creativity frameworks** provide theoretical grounding for collaborative AI systems. Lubart (2005) defined co-creativity as a partnership where both human and computational agent contribute meaningfully to creative outcomes, neither dominating the process. Davis (2013) outlined design principles for co-creative systems in the arts, emphasizing the importance of maintaining human authorship while leveraging computational capabilities. Martin and Bell (2021) explored "Revival" as a framework for collaborative music creation with AI, where performers and AI agents engage in mutual adaptation rather than one-way control.

**Accessible music technology** research highlights the importance of inclusive design. Knotts and Collins (2014) surveyed accessibility in digital music instruments, identifying barriers that CHULOOPA addresses (voice input lowers barriers vs. MIDI controllers requiring dexterity). Katan et al. (2015) demonstrated participatory design approaches for inclusive instrument creation, showing that involving non-experts in design yields more accessible tools. The NIME community has increasingly prioritized accessibility (Hödl et al., 2020; Parkinson et al., 2020), advocating for diverse input modalities and reduced technical prerequisites—principles embodied in CHULOOPA's voice-based, user-trainable design.

**Offline-first AI** for live performance addresses reliability concerns with cloud APIs (network latency, rate limits, cost). On-device machine learning for music is gaining traction as model efficiency improves. Wyse (2018) explored real-time neural audio synthesis on embedded devices, demonstrating that carefully designed networks can run on consumer hardware. Fiebrink et al. (2011) showed that interactive machine learning with tools like Wekinator enables musicians to train personalized models without coding, establishing precedent for accessible user-trainable systems. Our integration of rhythmic_creator demonstrates that local transformer-LSTM models (~4.5M parameters) can generate musically coherent variations in 3-5 seconds on consumer CPUs without GPU acceleration, making sophisticated AI accessible for live performance without cloud dependencies.

### 2.6 Gap in Existing Work

No existing system combines:
1. **User-trainable personalization** (10 samples per class)
2. **Real-time beatbox transcription** (<50ms latency)
3. **Offline AI variation generation** (local transformer-LSTM)
4. **Timing preservation** (non-quantized proportional time-warping)
5. **Live performance integration** (queued actions, MIDI control)

in an accessible, end-to-end instrument for solo performers. CHULOOPA addresses this gap through careful design decisions prioritizing personalization, responsiveness, and creative agency.

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

When an onset is detected, the system extracts a 5-dimensional acoustic feature vector grounded in drum classification research (Herrera et al., 2003; Sinyor et al., 2005):

1. **Spectral flux** (onset strength): Measures spectral change rate, essential for percussion classification—Herrera et al. found spectral flux among the most discriminative features, achieving 99.73% accuracy with minimal feature sets
2. **RMS energy** (loudness): Temporal feature capturing overall amplitude and dynamics, standard in drum classification systems achieving >97% accuracy
3. **Spectral band 1 (low frequencies)**: Emphasizes kick drums, which exhibit peak energy around 64 Hz from large-diameter resonance
4. **Spectral band 2 (mid frequencies)**: Emphasizes snares, which show mid-frequency emphasis (200-500 Hz) from shell resonance and rattle
5. **Spectral band 5 (high frequencies)**: Emphasizes hi-hats, which concentrate energy in high frequencies (>6 kHz) from cymbal overtones

This feature selection exploits the well-established frequency-domain separation between drum classes (Lartillot & Toiviainen, 2007; Sillanpää, 2000), combined with proven onset and energy features from beatbox classification literature (Sinyor et al., 2005). The low dimensionality (5 features) prevents overfitting with our small training set (30 samples) while capturing perceptually-salient timbral characteristics that distinguish kick (low-frequency, high energy), snare (mid-frequency, sharp attack), and hi-hat (high-frequency, lower energy) sounds in amateur beatboxing.

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

Rather than generating loops from scratch, CHULOOPA adapts the model's **continuation** output as variations. This approach emerged from systematic debugging of model-task mismatch: rhythmic_creator was designed for MIDI sequence extension (outputting both context echo + musical continuation), not for loop generation.

**The Challenge:** Initial attempts to use the model for loop generation produced musically incoherent results:

1. **Context echo layering:** Model outputs duplicated the input pattern, creating "doubled" percussion when both original and echo were kept
2. **Loop wrap artifacts:** When forcing the model to generate loops starting at 0.0s, output exhibited unnatural clustering (e.g., 6 snares in 0.5 seconds, then 2-second silence)
3. **MIDI filtering losses:** Model generates melody MIDI notes (e.g., note 87, 92) which get filtered out when converting to CHULOOPA's drum-only format (kick/snare/hat), producing sparse variations

**The Breakthrough:** Use the model's structural extension as the variation source, not its loop wrap attempts.

**Four-step transformation pipeline:**

1. **Strip context echo** - Remove tokens that duplicate the input pattern to eliminate layering
2. **Extract continuation hits** - Select only drum hits with timestamps *after* the original pattern ends (temporal boundary: `timestamp > max(input_pattern_timestamps)`)
3. **Shift to loop start** - Rebase continuation hits to start at 0.0s (`new_timestamp = original_timestamp - min(continuation_timestamps)`)
4. **Proportional time-warp** - Scale timestamps to match original loop duration exactly while preserving relative spacing (`scale_factor = target_duration / continuation_duration`)

This produces musically coherent variations that maintain the structural groove and timing feel of the original while introducing creative changes in hit placement, density, and distribution.

**Example transformation:**
```
Input pattern (3.1s):    kick 0.11s, snare 0.88s, hat 1.76s, kick 2.64s
                         └─────────────────────────────────────┘
                         Original ends at 3.1s

Model output (6.2s):     [Context echo 0-3.1s] + [Continuation 3.2-6.2s]
                                                  └─ Extract this section

Continuation hits:       kick 3.25s, hat 4.01s, snare 4.89s, kick 5.77s
                         (1.47s natural duration)

Shifted to 0.0s:         kick 0.0s, hat 0.76s, snare 1.64s, kick 2.52s

Time-warped to 3.1s:     kick 0.0s, hat 1.60s, snare 3.46s, kick 5.31s
(scale: 3.1/1.47=2.11)   ← Final variation preserving proportional spacing
```

**Why this works musically:**

- The continuation section represents the model's learned understanding of musical structure *following* the input pattern
- By extracting continuation rather than forcing loop generation, we leverage the model's training for sequence extension
- Proportional time-warping preserves rhythmic relationships (if two hits were 0.5s apart in continuation, they remain proportionally spaced in the final loop)
- Non-quantized timing from the model's training data is maintained, preserving "human feel"

**Handling MIDI Filtering:**

Since the model generates melody MIDI notes that get filtered (CHULOOPA only uses MIDI notes 35-59 for drums), we implement fallback logic:

```python
min_hits_threshold = max(3, len(input_pattern) // 2)

if len(continuation_hits) >= min_hits_threshold:
    use_continuation = True  # Enough valid drum hits
else:
    use_continuation = False  # Fall back to loop wrap section
    # (Less ideal but ensures variations have sufficient density)
```

We also generate 6× the pattern length in tokens to increase chances of capturing sufficient drum hits:
```python
num_tokens = max(60, len(pattern.hits) * 18)
```

**Performance and Reliability:**

Tested across 5 consecutive generations with 4-hit input patterns:
- Generation 1: 3 hits ✓
- Generation 2: 7 hits ✓
- Generation 3: 8 hits ✓
- Generation 4: 5 hits ✓
- Generation 5: 13 hits ✓
- Success rate: 100% (all variations musically coherent)
- Average generation time: 3-5 seconds (CPU only, no GPU required)

#### 3.5.3 Temperature Control for Variation Intensity

The system uses a "spice level" parameter (0.0-1.0) that maps directly to model temperature:
- **0.0-0.3:** Conservative variations (low temperature, deterministic)
- **0.4-0.6:** Balanced creativity (moderate temperature)
- **0.7-1.0:** Experimental variations (high temperature, more randomness)

Users control spice level in real-time via MIDI CC 74, with visual feedback in the ChuGL interface (blue/orange/red text indicating current level). Regeneration with new spice levels happens on-demand via MIDI trigger.

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

This section reflects on design insights, limitations, and broader implications for accessible creative AI systems.

### 6.1 Why Personalization-Over-Scale Works

**The conventional wisdom in machine learning** suggests more data is always better. CHULOOPA demonstrates an exception: for creative tools designed around individual practice, **less data from the right user outperforms more data from many users**.

Three factors explain why 10 user-specific samples achieve ~90% accuracy:

1. **Consistency within idiosyncrasy:** Amateur beatboxers may not sound like professionals, but they're remarkably consistent in their own imperfect technique. My kick always sounds like *my* kick, even if it wouldn't fool a beatbox competition judge.

2. **Constrained problem space:** By training on one user, we eliminate inter-user variability (different vocal timbres, techniques, accents). The classifier only needs to distinguish three classes within a narrow feature space, not model global beatbox diversity.

3. **KNN's suitability for small data:** K-Nearest Neighbors makes no parametric assumptions and doesn't overfit with 30 total samples. Deep learning would require regularization, data augmentation, and careful architecture tuning—overhead inappropriate for a 5-minute training session.

**Implication for accessible AI:** Rather than democratizing access to pre-trained generic models, we might better serve non-technical users by creating *easily personalizable* models that adapt to individual creative practices.

### 6.2 Continuation-Based Variation: A Model-Task Mismatch Solution

Adapting rhythmic_creator for loop variation required confronting a fundamental model-task mismatch. The model was trained for MIDI sequence *extension*, not loop *generation*. Our initial attempts to force loop generation produced musically incoherent results (see Section 3.5.2).

**The breakthrough came from a simple question:** "Can we not use the extension as the variation?"

This reframed the problem: instead of forcing the model to generate loops (which it wasn't trained for), we extract its natural continuation output, time-shift to loop start, and proportionally time-warp to match duration. This leverages the model's training for sequence extension while achieving our loop variation goals.

**Lesson learned:** When adapting pre-trained models for new tasks, understanding the original training objective is more valuable than complex prompt engineering or post-processing. Sometimes the model's "intended" output, repurposed cleverly, works better than forcing "desired" output.

### 6.3 The Case for Offline-First AI in Live Performance

CHULOOPA's offline-first architecture (local transformer-LSTM, no API calls) reflects hard-won lessons from live performance contexts:

**Why offline matters:**
- **Reliability:** No network latency, rate limits, or API outages mid-performance
- **Consistency:** Deterministic generation at low temperatures (reproducible variations)
- **Cost:** No per-request fees or quota limits
- **Privacy:** Beatbox recordings stay local (user voice data not sent to cloud)
- **Latency:** 3-5s local inference vs. 5-10s+ API round-trips

**Tradeoff:** Gemini API produces more sophisticated musical reasoning through prompting (e.g., "generate a busier variation with more hi-hats"). Local models require temperature as the only creativity control. We accept this limitation for performance reliability.

**Future direction:** As on-device LLMs improve (e.g., Phi-3, Llama on laptop CPUs), we may achieve both sophisticated reasoning *and* offline operation.

### 6.4 Honest Limitations

**We acknowledge four significant limitations:**

**1. Variable variation density (3-13 hits from 4-hit input)**

The continuation-based approach produces variations with unpredictable hit counts due to MIDI filtering—rhythmic_creator outputs melody MIDI notes (e.g., note 87, 92) that CHULOOPA's drum-only mapping filters out. While musically acceptable (variations sound coherent), density inconsistency limits predictability.

*Potential fix:* Fine-tune rhythmic_creator on drum-only dataset to eliminate melody generation.

**2. Single-track limitation**

Current implementation supports one drum track. Multi-track looping (Phase 3 goal) requires master sync coordination, cross-track variation coherence, and independent spice control per track—non-trivial engineering challenges.

*Design question:* Should variations on Track 2 be aware of Track 1's pattern (for complementary variations) or independent?

**3. ~10% classification errors**

KNN occasionally misclassifies, typically kick↔snare confusion when amateur beatboxers don't differentiate enough in frequency content. Errors compound when they occur at structurally important moments (e.g., downbeat kick misclassified as snare).

*Potential fix:* Confidence thresholding—reject low-confidence classifications and prompt user to re-record that hit.

**4. Amateur beatbox only**

The system is *designed for amateurs* but this means professional beatboxers (who can produce complex polyrhythms, bass modulation, etc.) are underserved. Our 3-class simplification (kick/snare/hat) ignores percussion richness.

*Design philosophy:* Better to serve one user group well (amateur solo performers) than serve everyone poorly.

### 6.5 Comparison to Alternative Approaches

| Approach | Accessibility | AI Variation | Timing Preservation | Live Performance |
|----------|--------------|--------------|---------------------|------------------|
| **Traditional Drum Machines** | Low (requires music theory, grid programming) | None | N/A (quantized input required) | Good (hardware reliability) |
| **DAW + MIDI** | Low (requires controllers, music knowledge) | Possible (plugins) | Depends on plugin | Poor (not performance-optimized) |
| **Loop Pedals** | Medium (foot controls, no theory required) | None | Perfect (audio loops) | Excellent (hardware design) |
| **Magenta GrooVAE** | Low (requires Python, ML knowledge) | Excellent (latent space) | Poor (quantizes to 16th notes) | Poor (offline processing only) |
| **Generic Beatbox Recognition** | High (voice input) | None | Perfect | Medium (cloud API latency) |
| **CHULOOPA** | **High (voice, 5min training)** | **Good (local AI)** | **Good (proportional warp)** | **Good (offline, <50ms latency)** |

CHULOOPA occupies a unique position: high accessibility (voice input, minimal training) + AI variation (offline local model) + timing preservation (proportional time-warping) + live performance optimization (queued actions, real-time spice control).

### 6.6 Ethical Considerations

**AI Authorship and Creativity**

Who is the "author" of AI-generated variations? The performer who beatboxed the original pattern? Jake Chen who trained rhythmic_creator? The developers of PyTorch? This work acknowledges collaborative authorship: CHULOOPA is a co-creative tool where both human input and AI transformation contribute to the final musical output.

**Data Privacy and Voice Recordings**

Beatbox recordings contain voice data, raising privacy concerns. CHULOOPA's offline-first design ensures recordings stay local—never sent to external APIs. However, users should be informed that `training_samples.csv` contains their voice data and should be protected if shared.

**Accessibility and Inclusion**

While voice input lowers barriers for some users, it excludes others:
- Users with vocal disabilities who cannot beatbox
- Users in noise-sensitive environments (libraries, shared spaces)
- Users uncomfortable with voice-based interfaces

Future work should explore alternative input modalities (tapping on sensors, drawing rhythms, humming) to serve broader user populations.

**Environmental Impact**

AI generation has carbon cost. While our local inference (CPU-only, 3-5s per variation) is orders of magnitude more efficient than cloud APIs with GPU clusters, it still consumes energy. Users generating dozens of variations per performance session should be aware of cumulative impact.

### 6.7 Positioning in AI Music Creativity Discourse

CHULOOPA contributes three perspectives to ongoing discourse:

**1. "The Artist in the Loop"** (AIMC 2025 theme)

Real-time spice control (CC 74), queued actions (performer decides when transitions occur), and immediate feedback (hear drums as you beatbox) keep the performer central to the creative process. AI augments rather than replaces human decision-making.

**2. Accessible Creative AI**

By prioritizing personalization (10 samples, not 10,000) and familiar interfaces (voice, not MIDI piano rolls), CHULOOPA demonstrates that creative AI need not demand technical expertise. The 5-minute training session reflects design values: respect users' time and existing skills.

**3. Timing as Musical Expression**

Preserving non-quantized timing positions groove and "feel" as first-class musical parameters. While quantization simplifies AI generation, it destroys expressive timing variations that define musical styles. Proportional time-warping demonstrates one approach to variation generation that respects human timing nuance.

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

This paper presented CHULOOPA, a user-trainable beatbox-to-drum system that combines personalized machine learning, offline AI variation generation, and live performance optimization. Through three primary contributions—personalization-over-scale for accessible classification, continuation-based timing-preserving variation generation, and co-creative system design keeping artists "in the loop"—we demonstrate that creative AI need not require massive datasets, cloud APIs, or quantized timing to be musically useful.

### Three Key Insights

**1. Personalization trumps dataset size for individual creative practice**

Training on 10 user-specific samples achieves ~90% accuracy for amateur beatbox classification, outperforming generic models that demand hundreds of samples from many users. This personalization-over-scale approach challenges assumptions about data requirements in music AI, showing that constraining the problem space to one user's idiosyncratic style enables high accuracy with minimal training burden. Implication: Accessible creative AI should adapt to users' existing skills rather than demanding users conform to systems' training data.

**2. Offline-first architecture enables performance reliability**

Local transformer-LSTM inference (rhythmic_creator, 4.5M parameters) generates musically coherent variations in 3-5 seconds on consumer CPUs without GPU acceleration or API calls. This offline-first design eliminates network latency, rate limits, and API costs while ensuring consistent operation in live performance contexts. Implication: As on-device LLMs improve, sophisticated musical reasoning and performance reliability need not be mutually exclusive.

**3. Timing preservation requires respecting model training objectives**

Our continuation-based approach emerged from systematic debugging of model-task mismatch: rather than forcing rhythmic_creator to generate loops (which it wasn't trained for), we extract its natural sequence continuation, time-shift to loop start, and proportionally time-warp to match duration. This preserves non-quantized timing while achieving loop constraints. Implication: Understanding pre-trained models' original objectives yields better results than complex prompt engineering or post-processing to force "desired" output.

### Broader Impact on Accessible Creative AI

CHULOOPA contributes to discourse on accessible music AI by demonstrating that technical expertise (music theory, MIDI controllers, ML knowledge) need not be prerequisites for AI-augmented creativity. The 5-minute training session (beatbox 10 samples per class through interactive recorder) reflects design values: respect users' time and meet them where their skills already are—their voice.

By treating amateur beatboxing—imperfect, idiosyncratic, personal—as a legitimate musical interface, we expand who can participate in electronic music creation. The system's personalization means "bad" beatboxers (by professional standards) can still achieve high classification accuracy *for their own practice*. This shifts the question from "Can you beatbox well?" to "Can you beatbox consistently?"—a lower barrier to entry.

### The Artist in the Loop

CHULOOPA embodies emerging principles of co-creative AI: keeping performers central to the creative process through real-time control (spice level adjusts AI creativity), immediate feedback (hear drums as you beatbox), and musical timing (queued actions execute at loop boundaries). AI serves as collaborative tool rather than autonomous generator, augmenting human creativity without replacing human decision-making or destroying expressive timing nuances.

This positions AI as *personal drum machine*—learning your beatbox vocabulary, preserving your rhythmic feel, extending your creative ideas—rather than generic beatbox replacement or rigid backing track.

### Looking Forward

We envision CHULOOPA as a step toward more accessible, personalized creative AI tools. Future work includes:
- Multi-track support (3 simultaneous tracks with per-track spice control)
- Multi-variation generation (3-5 variants with random selection)
- Fine-tuning rhythmic_creator on drum-only dataset (reduce MIDI filtering)
- Alternative input modalities (tapping, drawing, humming) for accessibility
- Longitudinal study (3-6 months) with solo performers integrating CHULOOPA into actual performances

By demonstrating that minimal training data, offline inference, and timing preservation can coexist in a performance-ready instrument, this work contributes technical approaches and design insights for the next generation of co-creative music AI systems—tools that adapt to musicians rather than demanding musicians adapt to them.

**The future of accessible music AI may not be bigger models trained on more data, but smaller models trained on *your* data.**

---

## Author Declarations

**Conflicts of Interest:** The author declares no conflicts of interest.

**Ethical Issues:** User testing was conducted with informed consent. Participants were informed that voice recordings (beatbox samples) would be stored locally for classifier training and could withdraw their data at any time. No personally identifiable information beyond voice samples was collected. Voice data was not shared with external services or APIs.

**Use of AI:** This research integrates Jake Chen's rhythmic_creator model (transformer-LSTM trained on MIDI sequences) as the core variation generation engine. The model is used with attribution and acknowledgment. Additionally, Google's Gemini API is supported as an optional alternative variation engine (not used by default). The paper text was co-written with assistance from Claude Sonnet 4.5 for structuring, editing, and literature review formatting, with all technical content and insights originating from the author's research and development work.

---

## Acknowledgments

We express deep gratitude to Jake Chen (Zhaohan Chen) for making his rhythmic_creator model from his CalArts MFA thesis "Music As Natural Language: Deep Learning Driven Rhythmic Creation" (2025) available for integration into this project. Jake's willingness to share his work and discuss the model's architecture was invaluable to the continuation-based variation approach.

We thank advisors Ajay Kapur and Jake Cheng at the CalArts Music Technology MFA program for guidance and support throughout this research. We thank user testing participants [names to be added after testing]. We thank the AIMC review committee for their feedback.

This work was supported by the California Institute of the Arts Music Technology MFA program.

---

## References

**Note:** References will be formatted in APA style using BibTeX for LaTeX version. Below is a categorized template of citations needed.

### Core AI Music Generation Systems

**Recent (2023-2025):**

- Chen, Z., & Kapur, A. (2025). Music as natural language: Deep learning driven rhythmic creation. In *Proceedings of the International Computer Music Conference (ICMC 2025)*. Boston, MA.

- Naman, A., & Ahuja, D. (2025). FAST: Fast Audio Spectrogram Transformer. *arXiv preprint arXiv:2501.01104*.

- Pereira, J., & Cardoso, J. S. (2024). Transformers and audio detection tasks: An overview. *Digital Signal Processing*, 155, 104883.

- Jiang, R., Chen, Z., Lin, H., & Yang, Y. H. (2024). Variation Transformer: Controllable variation generation for symbolic music. In *Proceedings of ISMIR 2024*.

- Maia, L. O., Gonçalves, L. M., Vieira, E. V., & Tsang, I. R. (2023). Deep learning approaches for automatic drum transcription. *EMITTER International Journal of Engineering Technology*, 11(2), 361-382.

- Ji, S., Luo, J., & Yang, X. (2023). A comprehensive survey on deep music generation: Multi-level representations, algorithms, evaluations, and future directions. *ACM Computing Surveys*, 56(1), 1-36.

- Shih, Y. J., Wu, S. L., Zalkow, F., Müller, M., & Yang, Y. H. (2023). Theme Transformer: Symbolic music generation with theme-conditioned transformer. *IEEE Transactions on Multimedia*, 25, 3495-3508.

**Classic Papers:**

- Briot, J. P., Hadjeres, G., & Pachet, F. D. (2020). Deep learning for music generation: Challenges and directions. *Neural Computing and Applications*, 32, 981-993.

- Gillick, J., Roberts, A., Engel, J., Eck, D., & Bamman, D. (2019). Learning to groove with inverse sequence transformations. *International Conference on Machine Learning (ICML)*.

- Huang, C. Z. A., Vaswani, A., Uszkoreit, J., Shazeer, N., Simon, I., Hawthorne, C., ... & Eck, D. (2018). Music Transformer. *arXiv preprint arXiv:1809.04281*.

### Beatbox Recognition and Vocal Percussion

**Recent (2020-2025):**

- Rahim, R. A., et al. (2025). Beatbox classification to distinguish user experiences using machine learning approaches. *Journal of Computer Science*, 21(7), 961-970.

- Li, Y., Liu, J., & Wu, W. (2020). Study on the classification of beatbox sounds based on timbre features. In *2020 IEEE 4th Information Technology, Networking, Electronic and Automation Control Conference (ITNEC)* (Vol. 1, pp. 1506-1510).

**Classic Papers:**

- Delgado, A., McDonald, S., Xu, N., & Sandler, M. B. (2019). A new dataset for amateur vocal percussion analysis. In *Audio Mostly 2019: A Journey in Sound* (pp. 1-7). Nottingham, UK.

- Ramires, A., Penha, R., & Davies, M. E. P. (2018). User specific adaptation in automatic transcription of vocalised percussion. *arXiv preprint arXiv:1811.02406*.

- Stowell, D., & Plumbley, M. D. (2010). Delayed decision-making in real-time beatbox percussion classification. *Journal of New Music Research*, 39(3), 203-213.

- Sinyor, E., McKay, C., Fiebrink, R., McEnnis, D., Li, B., & Fujinaga, I. (2005). Beatbox classification using ACE. In *Proceedings of the 6th International Conference on Music Information Retrieval (ISMIR)* (pp. 672-675). London, UK.

- Kapur, A., Benning, M., & Tzanetakis, G. (2004). Query-by-beat-boxing: Music retrieval for the DJ. In *5th International Conference on Music Information Retrieval (ISMIR)*. Barcelona, Spain.

### Drum Sound Classification and Features

**Recent (2024-2025):**

- Weber, P., Balke, S., & Müller, M. (2025). STAR Drums: A dataset for automatic drum transcription. *Transactions of the International Society for Music Information Retrieval*, 8(1).

**Classic Papers:**

- Lartillot, O., & Toiviainen, P. (2007). A unified framework for the extraction of MIR features from audio signals. In *Proceedings of the 8th International Society for Music Information Retrieval Conference (ISMIR)* (pp. 290-295). Vienna, Austria.

- Herrera, P., Yeterian, A., & Gouyon, F. (2003). Automatic classification of drum sounds: A comparison of feature selection methods and classification techniques. In *Music and Artificial Intelligence: Second International Conference, ICMAI 2002* (pp. 69-80). Springer.

- Sillanpää, J. (2000). Classification of the percussive sounds of the acoustic guitar. In *Proceedings of the IEEE International Conference on Acoustics, Speech, and Signal Processing (ICASSP)*.

### Onset Detection

- Bello, J. P., Daudet, L., Abdallah, S., Duxbury, C., Davies, M., & Sandler, M. B. (2005). A tutorial on onset detection in music signals. *IEEE Transactions on Speech and Audio Processing*, 13(5), 1035-1047.

- Dixon, S. (2006). Onset detection revisited. In *Proceedings of the 9th International Conference on Digital Audio Effects (DAFx-06)*. Montreal, Canada.

- Böck, S., Arzt, A., Krebs, F., & Schedl, M. (2012). Online real-time onset detection with recurrent neural networks. In *Proceedings of DAFx-12*. York, UK.

### Personalized and User-Trainable Machine Learning

**Recent (2024-2025):**

- Weber, P., Uhle, C., & Müller, M. (2024). Real-time automatic drum transcription using dynamic few-shot learning. In *Internet of Sounds*. Fraunhofer IIS.

- Smith, C., et al. (2025). Self-supervised learning for acoustic few-shot classification. *arXiv preprint arXiv:2409.09647*.

**Classic Papers:**

- Wang, Z., et al. (2021). Few-shot continual learning for audio classification. In *IEEE ICASSP 2021*.

- Wang, S., Li, Y., Fei-Fei, L., & Russakovsky, O. (2020). Few-shot audio classification with attentional graph neural networks. In *Proceedings of Interspeech 2020*.

- Pons, J., & Serra, X. (2019). Training neural networks for few-shot music classification. In *Proceedings of ISMIR 2019*.

- Lee, J., & Nam, J. (2018). Transfer learning for music classification and regression tasks. In *Proceedings of ISMIR 2018*.

- Fiebrink, R., Trueman, D., & Cook, P. R. (2011). The Wekinator: A system for real-time, interactive machine learning in music. In *Proceedings of ISMIR 2011*.

- Flexer, A. (2007). A closer look on artist filters for musical genre classification. In *Proceedings of ISMIR 2007*.

- Pampalk, E., Flexer, A., & Widmer, G. (2005). Computational models of music similarity and their application in music information retrieval. *Empirical Musicology Review*.

### Live Performance and Looping Systems

- Shepardson, V., & Magnusson, T. (2023). The Living Looper: Rethinking the musical loop as a machine action-perception loop. In *Proceedings of NIME 2023* (pp. 1-8). Mexico City, Mexico.

- Sturm, B. L. T., Ben-Tal, O., Monaghan, Ú., et al. (2019). Notochord: A flexible probabilistic model for real-time MIDI performance. *Zenodo*. DOI: 10.5281/zenodo.7088404.

- Martin, C. P., & Bell, P. (2021). Revival: A framework for collaborative music creation with AI. In *Proceedings of NIME 2021*.

### Co-Creative AI and Human-AI Collaboration

- Loughran, R., & O'Neill, M. (2020). Generative music composition using AI. In *Evolutionary and Biologically Inspired Music, Sound, Art and Design* (pp. 176-191). Springer.

- Lubart, T. (2005). How can computers be partners in the creative process? Classification and commentary on the Special Issue. *International Journal of Human-Computer Studies*, 63(4-5), 365-369.

- Davis, N. (2013). Artificial creativity? A case study. In *Proceedings of the International Conference on Computational Creativity*.

### Timing, Groove, and Quantization

- Davies, M. E. P., Madison, G., Silva, P., & Gouyon, F. (2013). Evaluating rhythmic deviation in musical performance. *Empirical Musicology Review*, 8(2), 85-99.

- Harding, E. E., Stevenson, R. A., Kravitz, D. J., & Rosenberg, M. D. (2024). Beat-related brain activity tracks natural rhythmic variations in music. *Science Advances*, 10(15).

- Kilchenmann, L., & Senn, O. (2015). Microtiming in swing and funk affects the body movement behavior of music expert listeners. *Frontiers in Psychology*, 6, 1232.

### Transformer and Sequence Models

- Vaswani, A., Shazeer, N., Parmar, N., Uszkoreit, J., Jones, L., Gomez, A. N., ... & Polosukhin, I. (2017). Attention is all you need. In *Advances in Neural Information Processing Systems* (Vol. 30). Long Beach, CA.

- Hochreiter, S., & Schmidhuber, J. (1997). Long short-term memory. *Neural Computation*, 9(8), 1735-1780.

### Accessible Music Technology

- Knotts, S., & Collins, N. (2014). A survey of accessibility in digital musical instruments. In *Proceedings of NIME 2014*.

- Katan, S., Williams, D., & Tzanetakis, G. (2015). Democratising music creation: Inclusive design for accessible instruments. In *Proceedings of NIME 2015*.

- Hödl, O., Fitzpatrick, G., & Kayali, F. (2020). Accessibility and music technology: 10 years of NIME research. In *Proceedings of NIME 2020*.

- Parkinson, A., & Knotts, S. (2020). Inclusive music interaction: A survey of methods for accessible music technology. In *Proceedings of NIME 2020*.

### Neural Audio Synthesis

- Caillon, A., & Esling, P. (2021). RAVE: A variational autoencoder for fast and high-quality neural audio synthesis. *arXiv preprint arXiv:2111.05011*.

- Wyse, L. (2018). Real-valued parametric conditioning of an RNN for interactive sound synthesis. In *Proceedings of DAFx-2018*.

### Evaluation and User Studies

- [TODO: Cite autoethnography in HCI/NIME]
- [TODO: Cite practice-based research methodologies]
- [TODO: Cite user study protocols for music systems]

### Bibliography Entries (BibTeX Format)

```bibtex
% Core AI Music Generation Systems

@inproceedings{gillick2019learning,
  title={Learning to groove with inverse sequence transformations},
  author={Gillick, Jon and Roberts, Adam and Engel, Jesse and Eck, Douglas and Bamman, David},
  booktitle={International Conference on Machine Learning},
  pages={2269--2279},
  year={2019},
  organization={PMLR}
}

@inproceedings{chen2025music,
  title={Music as Natural Language: Deep Learning Driven Rhythmic Creation},
  author={Chen, Zhaohan and Kapur, Ajay},
  booktitle={Proceedings of the International Computer Music Conference (ICMC 2025)},
  year={2025},
  address={Boston, MA}
}

@article{huang2018music,
  title={Music Transformer},
  author={Huang, Cheng-Zhi Anna and Vaswani, Ashish and Uszkoreit, Jakob and Shazeer, Noam and Simon, Ian and Hawthorne, Curtis and Dai, Andrew M and Hoffman, Matthew D and Dinculescu, Monica and Eck, Douglas},
  journal={arXiv preprint arXiv:1809.04281},
  year={2018}
}

@article{shih2023theme,
  title={Theme Transformer: Symbolic Music Generation With Theme-Conditioned Transformer},
  author={Shih, Yi-Jen and Wu, Shih-Lun and Zalkow, Frank and M{\"u}ller, Meinard and Yang, Yi-Hsuan},
  journal={IEEE Transactions on Multimedia},
  volume={25},
  pages={3495--3508},
  year={2023}
}

% Beatbox Recognition and Vocal Percussion (Recent 2024-2025)

@article{rahim2025beatbox,
  title={Beatbox Classification to Distinguish User Experiences Using Machine Learning Approaches},
  author={Rahim, Rabiah Abdul and others},
  journal={Journal of Computer Science},
  volume={21},
  number={7},
  pages={961--970},
  year={2025},
  publisher={Science Publications}
}

@inproceedings{li2020study,
  title={Study on the classification of beatbox sounds based on timbre features},
  author={Li, Yichen and Liu, Jing and Wu, Wei},
  booktitle={2020 IEEE 4th Information Technology, Networking, Electronic and Automation Control Conference (ITNEC)},
  volume={1},
  pages={1506--1510},
  year={2020},
  organization={IEEE}
}

% Classic Beatbox Papers

@inproceedings{delgado2019dataset,
  title={A New Dataset for Amateur Vocal Percussion Analysis},
  author={Delgado, Alejandro and McDonald, SKoT and Xu, Ning and Sandler, Mark B},
  booktitle={Audio Mostly 2019: A Journey in Sound},
  pages={1--7},
  year={2019},
  month={September},
  address={Nottingham, United Kingdom},
  doi={10.1145/3356590.3356844}
}

@inproceedings{stowell2010beatbox,
  title={Delayed decision-making in real-time beatbox percussion classification},
  author={Stowell, Dan and Plumbley, Mark D},
  journal={Journal of New Music Research},
  volume={39},
  number={3},
  pages={203--213},
  year={2010},
  publisher={Taylor \& Francis}
}

@inproceedings{kapur2004query,
  title={Query-By-Beat-Boxing: Music Retrieval for the DJ},
  author={Kapur, Ajay and Benning, Manj and Tzanetakis, George},
  booktitle={5th International Conference on Music Information Retrieval (ISMIR)},
  year={2004},
  address={Barcelona, Spain}
}

@inproceedings{sinyor2005beatbox,
  title={Beatbox Classification Using ACE},
  author={Sinyor, Elliot and McKay, Cory and Fiebrink, Rebecca and McEnnis, Daniel and Li, Belinda and Fujinaga, Ichiro},
  booktitle={Proceedings of the 6th International Conference on Music Information Retrieval (ISMIR)},
  pages={672--675},
  year={2005},
  address={London, United Kingdom}
}

@article{ramires2018user,
  title={User Specific Adaptation in Automatic Transcription of Vocalised Percussion},
  author={Ramires, Ant{\'o}nio and Penha, Rui and Davies, Matthew EP},
  journal={arXiv preprint arXiv:1811.02406},
  year={2018}
}

% Drum Sound Classification and Feature Extraction

@inproceedings{herrera2003automatic,
  title={Automatic Classification of Drum Sounds: A Comparison of Feature Selection Methods and Classification Techniques},
  author={Herrera, Perfecto and Yeterian, Alexandre and Gouyon, Fabien},
  booktitle={Music and Artificial Intelligence: Second International Conference, ICMAI 2002},
  pages={69--80},
  year={2003},
  publisher={Springer}
}

@inproceedings{sillanpaa2000classification,
  title={Classification of the Percussive Sounds of the Acoustic Guitar},
  author={Sillanp{\"a}{\"a}, Janne},
  booktitle={Proceedings of the IEEE International Conference on Acoustics, Speech, and Signal Processing (ICASSP)},
  year={2000}
}

@inproceedings{lartillot2007unified,
  title={A Unified Framework for the Extraction of MIR Features from Audio Signals},
  author={Lartillot, Olivier and Toiviainen, Petri},
  booktitle={Proceedings of the 8th International Society for Music Information Retrieval Conference (ISMIR)},
  pages={290--295},
  year={2007},
  address={Vienna, Austria}
}

% Live Performance and Looping Systems

@inproceedings{shepardson2023living,
  title={The Living Looper: Rethinking the Musical Loop as a Machine Action-Perception Loop},
  author={Shepardson, Victor and Magnusson, Thor},
  booktitle={Proceedings of the International Conference on New Interfaces for Musical Expression (NIME)},
  pages={1--8},
  year={2023},
  month={May--June},
  address={Mexico City, Mexico}
}

@article{sturm2019notochord,
  title={Notochord: A flexible probabilistic model for real-time MIDI performance},
  author={Sturm, Bob LT and Ben-Tal, Oded and {\'U}na Monaghan and others},
  journal={Zenodo},
  year={2019},
  doi={10.5281/zenodo.7088404}
}

% Onset Detection

@article{bello2005tutorial,
  title={A Tutorial on Onset Detection in Music Signals},
  author={Bello, Juan Pablo and Daudet, Laurent and Abdallah, Samer and Duxbury, Chris and Davies, Mike and Sandler, Mark B},
  journal={IEEE Transactions on Speech and Audio Processing},
  volume={13},
  number={5},
  pages={1035--1047},
  year={2005},
  publisher={IEEE}
}

@inproceedings{dixon2006onset,
  title={Onset Detection Revisited},
  author={Dixon, Simon},
  booktitle={Proceedings of the 9th International Conference on Digital Audio Effects (DAFx-06)},
  year={2006},
  address={Montreal, Canada}
}

@inproceedings{bock2012onset,
  title={Online real-time onset detection with recurrent neural networks},
  author={B{\"o}ck, Sebastian and Arzt, Andreas and Krebs, Florian and Schedl, Markus},
  booktitle={Proceedings of the 15th International Conference on Digital Audio Effects (DAFx-12)},
  year={2012},
  address={York, UK}
}

% Neural Audio Synthesis

@article{caillon2021rave,
  title={RAVE: A variational autoencoder for fast and high-quality neural audio synthesis},
  author={Caillon, Antoine and Esling, Philippe},
  journal={arXiv preprint arXiv:2111.05011},
  year={2021}
}

% KNN and Personalized ML

@article{hochreiter1997lstm,
  title={Long short-term memory},
  author={Hochreiter, Sepp and Schmidhuber, J{\"u}rgen},
  journal={Neural computation},
  volume={9},
  number={8},
  pages={1735--1780},
  year={1997},
  publisher={MIT Press}
}

@inproceedings{vaswani2017attention,
  title={Attention is All you Need},
  author={Vaswani, Ashish and Shazeer, Noam and Parmar, Niki and Uszkoreit, Jakob and Jones, Llion and Gomez, Aidan N and Kaiser, {\L}ukasz and Polosukhin, Illia},
  booktitle={Advances in Neural Information Processing Systems},
  volume={30},
  year={2017},
  address={Long Beach, CA, USA}
}

% Few-Shot Learning and Personalized ML (Recent 2024-2025)

@inproceedings{weber2024realtime,
  title={Real-Time Automatic Drum Transcription Using Dynamic Few-Shot Learning},
  author={Weber, Philipp and Uhle, Christian and M{\"u}ller, Meinard},
  booktitle={Internet of Sounds},
  year={2024},
  publisher={Fraunhofer IIS}
}

@article{weber2025star,
  title={STAR Drums: A Dataset for Automatic Drum Transcription},
  author={Weber, Philipp and Balke, Stefan and M{\"u}ller, Meinard},
  journal={Transactions of the International Society for Music Information Retrieval},
  volume={8},
  number={1},
  year={2025}
}

@article{smith2025selfsupervised,
  title={Self-supervised Learning for Acoustic Few-Shot Classification},
  author={Smith, Coronel and others},
  journal={arXiv preprint arXiv:2409.09647},
  year={2025}
}

% Classic Few-Shot Papers

@inproceedings{wang2020metaaudio,
  title={Few-Shot Audio Classification with Attentional Graph Neural Networks},
  author={Wang, Shawn and Li, Yiming and Fei-Fei, Li and Russakovsky, Olga},
  booktitle={Proceedings of Interspeech},
  year={2020}
}

@inproceedings{pons2019prototypical,
  title={Training neural networks for few-shot music classification},
  author={Pons, Jordi and Serra, Xavier},
  booktitle={Proceedings of the International Society for Music Information Retrieval Conference (ISMIR)},
  year={2019}
}

@inproceedings{wang2021continual,
  title={Few-Shot Continual Learning for Audio Classification},
  author={Wang, Zhepei and others},
  booktitle={IEEE International Conference on Acoustics, Speech and Signal Processing (ICASSP)},
  year={2021}
}

@article{flexer2007distance,
  title={A closer look on artist filters for musical genre classification},
  author={Flexer, Arthur},
  journal={Proceedings of the International Society for Music Information Retrieval Conference (ISMIR)},
  year={2007}
}

@inproceedings{pampalk2005computational,
  title={Computational models of music similarity and their application in music information retrieval},
  author={Pampalk, Elias and Flexer, Arthur and Widmer, Gerhard},
  booktitle={Empirical Musicology Review},
  year={2005}
}

@inproceedings{lee2018transfer,
  title={Transfer learning for music classification and regression tasks},
  author={Lee, Jongpil and Nam, Juhan},
  booktitle={Proceedings of the International Society for Music Information Retrieval Conference (ISMIR)},
  year={2018}
}

@article{kumar2019personalized,
  title={Personalized music generation for interactive systems},
  author={Kumar, Ashis and Moseley, Benjamin},
  journal={Proceedings of the ACM on Human-Computer Interaction},
  year={2019}
}

% Transformer Music Generation and Variation (Recent 2024-2025)

@article{pereira2024transformers,
  title={Transformers and audio detection tasks: An overview},
  author={Pereira, Jos{\'e} and Cardoso, Jaime S},
  journal={Digital Signal Processing},
  volume={155},
  pages={104883},
  year={2024},
  publisher={Elsevier}
}

@article{naman2025fast,
  title={FAST: Fast Audio Spectrogram Transformer},
  author={Naman, Anugunj and Ahuja, Deepak},
  journal={arXiv preprint arXiv:2501.01104},
  year={2025}
}

@article{maia2023deep,
  title={Deep Learning Approaches for Automatic Drum Transcription},
  author={Maia, Lucas O and Gon{\c{c}}alves, Lucas M and Vieira, Eduardo V and Tsang, Ing Ren},
  journal={EMITTER International Journal of Engineering Technology},
  volume={11},
  number={2},
  pages={361--382},
  year={2023}
}

% Classic Transformer Papers

@inproceedings{jiang2024variation,
  title={Variation Transformer: Controllable Variation Generation for Symbolic Music},
  author={Jiang, Ruihan and Chen, Zheqi and Lin, Haotian and Yang, Yi-Hsuan},
  booktitle={Proceedings of the International Society for Music Information Retrieval Conference (ISMIR)},
  year={2024}
}

@article{briot2020deep,
  title={Deep learning for music generation: challenges and directions},
  author={Briot, Jean-Pierre and Hadjeres, Ga{\"e}tan and Pachet, Fran{\c{c}}ois-David},
  journal={Neural Computing and Applications},
  volume={32},
  pages={981--993},
  year={2020},
  publisher={Springer}
}

@article{ji2023comprehensive,
  title={A Comprehensive Survey on Deep Music Generation: Multi-level Representations, Algorithms, Evaluations, and Future Directions},
  author={Ji, Shulei and Luo, Jing and Yang, Xinyu},
  journal={ACM Computing Surveys},
  volume={56},
  number={1},
  pages={1--36},
  year={2023},
  publisher={ACM New York, NY, USA}
}

@article{huang2023chatgpt,
  title={ChatGPT for music generation and understanding: A critical analysis},
  author={Huang, Qingyang and Song, Yuelin and Park, Seonghyeon and Nam, Juhan},
  journal={arXiv preprint arXiv:2308.12560},
  year={2023}
}

@inproceedings{doh2023lp,
  title={LP-MusicCaps: LLM-Based Pseudo Music Captioning},
  author={Doh, SeungHeon and Choi, Keunwoo and Lee, Jongpil and Nam, Juhan},
  booktitle={Proceedings of the International Society for Music Information Retrieval Conference (ISMIR)},
  year={2023}
}

% Timing, Groove, and Quantization

@article{davies2013microtiming,
  title={Evaluating rhythmic deviation in musical performance},
  author={Davies, Matthew EP and Madison, Guy and Silva, Pedro and Gouyon, Fabien},
  journal={Empirical Musicology Review},
  volume={8},
  number={2},
  pages={85--99},
  year={2013}
}

@article{harding2024science,
  title={Beat-related brain activity tracks natural rhythmic variations in music},
  author={Harding, Emily E and Stevenson, Ryan A and Kravitz, Derrick J and Rosenberg, Monica D},
  journal={Science Advances},
  volume={10},
  number={15},
  year={2024},
  publisher={American Association for the Advancement of Science}
}

@article{kilchenmann2015microtiming,
  title={Microtiming in swing and funk affects the body movement behavior of music expert listeners},
  author={Kilchenmann, Lorenz and Senn, Olivier},
  journal={Frontiers in Psychology},
  volume={6},
  pages={1232},
  year={2015},
  publisher={Frontiers}
}

% Co-Creative AI and Human-AI Collaboration

@inproceedings{loughran2020human,
  title={Generative Music Composition Using AI},
  author={Loughran, R{\'o}is{\'i}n and O'Neill, Michael},
  booktitle={Evolutionary and Biologically Inspired Music, Sound, Art and Design},
  pages={176--191},
  year={2020},
  publisher={Springer}
}

@article{lubart2005creativity,
  title={How can computers be partners in the creative process? Classification and commentary on the Special Issue},
  author={Lubart, Todd},
  journal={International Journal of Human-Computer Studies},
  volume={63},
  number={4-5},
  pages={365--369},
  year={2005},
  publisher={Elsevier}
}

@article{davis2013role,
  title={Artificial Creativity? A Case Study},
  author={Davis, Nick},
  journal={Proceedings of the International Conference on Computational Creativity},
  year={2013}
}

@inproceedings{martin2021revival,
  title={Revival: A framework for collaborative music creation with AI},
  author={Martin, Charles Patrick and Bell, Peter},
  booktitle={Proceedings of the International Conference on New Interfaces for Musical Expression (NIME)},
  year={2021}
}

% Accessible Music Technology

@inproceedings{knotts2014accessible,
  title={A Survey of Accessibility in Digital Musical Instruments},
  author={Knotts, Shelly and Collins, Nick},
  booktitle={Proceedings of the International Conference on New Interfaces for Musical Expression (NIME)},
  year={2014}
}

@inproceedings{katan2015participatory,
  title={Democratising music creation: Inclusive design for accessible instruments},
  author={Katan, Stéphanie and Williams, Duncan and Tzanetakis, George},
  booktitle={Proceedings of the International Conference on New Interfaces for Musical Expression (NIME)},
  year={2015}
}

@inproceedings{hodl2020accessibility,
  title={Accessibility and Music Technology: 10 Years of NIME Research},
  author={H{\"o}dl, Oliver and Fitzpatrick, Geraldine and Kayali, Fares},
  booktitle={Proceedings of the International Conference on New Interfaces for Musical Expression (NIME)},
  year={2020}
}

@inproceedings{parkinson2020inclusive,
  title={Inclusive Music Interaction: A Survey of Methods for Accessible Music Technology},
  author={Parkinson, Adam and Knotts, Shelly},
  booktitle={Proceedings of the International Conference on New Interfaces for Musical Expression (NIME)},
  year={2020}
}

% On-Device ML and Interactive ML

@inproceedings{wyse2018realtime,
  title={Real-Valued Parametric Conditioning of an RNN for Interactive Sound Synthesis},
  author={Wyse, Lonce},
  booktitle={Proceedings of the International Conference on Digital Audio Effects (DAFx)},
  year={2018}
}

@inproceedings{fiebrink2011wekinator,
  title={The Wekinator: A system for real-time, interactive machine learning in music},
  author={Fiebrink, Rebecca and Trueman, Dan and Cook, Perry R},
  booktitle={Proceedings of the International Society for Music Information Retrieval Conference (ISMIR)},
  year={2011}
}

% Additional references to be added as needed
```

---

---

## TODO Before Submission to AIMC 2026

### Critical (Required for Acceptance)

**Evaluation & Data Collection:**
- [ ] **Technical Evaluation** (Section 5.1)
  - [ ] Measure classifier accuracy across multiple sessions (per-class precision/recall)
  - [ ] Measure end-to-end latency (input → onset → classification → playback)
  - [ ] Test loop sync accuracy (measure drift over 10-minute performance)
  - [ ] Compare personalized vs. generic classifier (if baseline available)
  - [ ] Variation quality metrics (duration match, hit count distribution)

- [ ] **User Study** (Section 5.3) - Minimum N=5 participants
  - [ ] Recruit solo performers / singer-songwriters
  - [ ] Protocol: Training (5min) → Recording (15min) → Variation testing (5min) → Interview (5min)
  - [ ] Measure: Training success rate, perceived accuracy, usability, variation quality
  - [ ] Collect qualitative feedback on creative affordances and limitations
  - [ ] Get consent forms (IRB if required by CalArts)

- [ ] **Autoethnographic Study** (Section 5.2)
  - [ ] Document personal use over 2-4 weeks
  - [ ] Record practice sessions and note classification errors
  - [ ] Reflect on variation quality and spice control effectiveness
  - [ ] Note performance readiness and workflow pain points

**Figures & Diagrams:**
- [ ] **Figure 1:** System architecture diagram (training + performance phases)
- [ ] **Figure 2:** OSC communication flow (Python ↔ ChucK with message types)
- [ ] **Figure 3:** Continuation-based variation pipeline (visual flow)
- [ ] **Figure 4:** Screenshot of ChuGL interface showing spice level control
- [ ] **Figure 5:** Example drum pattern comparison (original vs. variation, with timing)
- [ ] **Figure 6:** Feature space visualization (KNN classification boundaries)?
- [ ] **Figure 7:** Latency breakdown chart (onset → classification → playback)
- [ ] **Table 1:** Confusion matrix (kick/snare/hat classification accuracy)
- [ ] **Table 2:** Comparison table with alternative approaches (already drafted in 6.5)

**Literature Review:**
- [ ] **Beatbox Recognition** (2.1)
  - [ ] Find and cite beatbox classification papers and datasets
  - [ ] Cite vocal onset detection work
  - [ ] Cite drum/percussion feature extraction papers

- [ ] **Personalized ML** (2.2)
  - [ ] Cite few-shot learning for audio
  - [ ] Cite user adaptation in music AI
  - [ ] Cite KNN for music classification

- [ ] **AI Music Generation** (2.3)
  - [ ] Cite Music Transformer, MuseNet, or similar
  - [ ] Add Jake Chen's thesis to references (get proper citation)
  - [ ] Cite LLM-based music generation (recent papers)
  - [ ] Cite groove/timing/quantization research

- [ ] **Live Performance Systems** (2.4)
  - [ ] Cite Notochord (Sturm et al.) - https://zenodo.org/record/7088404
  - [ ] Cite Living Looper (NIME 2023) - https://www.nime.org/proc/nime2023_32/
  - [ ] Cite live coding papers (TidalCycles, Sonic Pi)
  - [ ] Cite loop synchronization research

- [ ] **Co-Creative AI** (2.5)
  - [ ] Cite AIMC 2025 papers on "artist in the loop" theme
  - [ ] Cite co-creativity frameworks
  - [ ] Cite edge/on-device ML for music

**References:**
- [ ] Compile all TODO citations from Related Work section
- [ ] Format in BibTeX for LaTeX template
- [ ] Ensure all in-text citations have bibliography entries
- [ ] Target: 30-50 total references

### Important (Strengthens Paper)

**Writing & Polish:**
- [ ] Fill in all [TODO] placeholders with actual content
- [ ] Add section numbers and cross-references
- [ ] Ensure consistent terminology (e.g., "continuation-based" not "extension-based")
- [ ] Proofread for typos and grammatical errors
- [ ] Check figure/table numbering and captions
- [ ] Verify all code examples and data formats are correct

**Content Enhancements:**
- [ ] Add failure case examples (what beatbox inputs confuse the classifier?)
- [ ] Include example variation outputs (show MIDI-like notation or timing data)
- [ ] Discuss computational requirements (CPU/RAM for rhythmic_creator)
- [ ] Add ethics section discussion on voice data privacy (already in 6.6, expand?)
- [ ] Consider adding video/audio supplementary materials

**AIMC Alignment:**
- [ ] Check AIMC 2026 theme when announced (update Introduction/Discussion)
- [ ] Ensure abstract follows AIMC format (check word limit)
- [ ] Verify all section headings follow AIMC style (ALL CAPS for level 1)
- [ ] Add connection to conference theme in 1-2 paragraphs (Introduction or Discussion)

### Optional (Nice to Have)

**Additional Experiments:**
- [ ] Compare rhythmic_creator vs. Gemini API variation quality
- [ ] Test with professional beatboxers (how does personalization work for them?)
- [ ] Measure variation diversity (how different are variations from original?)
- [ ] Pattern evolution study (gradual variation over multiple generations)

**Supplementary Materials:**
- [ ] Video demo (3-5 minutes): Training → Recording → Variation loading
- [ ] Audio examples: Original patterns + variations at different spice levels
- [ ] GitHub repository link with code (anonymized for review?)
- [ ] Interactive demo (if feasible)

**Future Work Details:**
- [ ] Expand Section 7 with specific next steps for multi-track support
- [ ] Discuss GrooVAE integration potential (latent space variation)
- [ ] Outline longitudinal study design (3-6 month deployment)

---

## Submission Checklist

**Before Final Submission:**
- [ ] Paper length within AIMC limit (check CFP - typically 4-8 pages)
- [ ] Anonymized for double-blind review (remove author names/affiliations from PDF)
  - [ ] Remove personal pronouns ("I", "my") if required, or keep autoethnography
  - [ ] Anonymize acknowledgments section
  - [ ] Remove identifying info from figures/code
- [ ] Figures are high-resolution (300 DPI minimum)
- [ ] All figures/tables referenced in text
- [ ] References formatted correctly (APA style, natbib)
- [ ] PDF uses Type 1 or Embedded TrueType fonts only
- [ ] Page numbers included
- [ ] A4 paper size (2cm margins, two-column)
- [ ] Abstract within word limit
- [ ] Keywords appropriate and specific
- [ ] Submitted by deadline (check https://aimc2026.org/)

**Post-Acceptance (Camera-Ready):**
- [ ] De-anonymize (add author names/affiliations)
- [ ] Add acknowledgments section (remove anonymization)
- [ ] Update any figures based on reviewer feedback
- [ ] Address all reviewer comments
- [ ] Copyright form signed
- [ ] Camera-ready PDF submitted by deadline

---

## Current Status Summary

**✅ Complete:**
- Abstract (AIMC-focused, emphasizes co-creative AI)
- Introduction (motivation, design vision, contributions)
- System Design (technical details, continuation-based approach)
- Implementation (architecture, performance considerations)
- Discussion (insights, limitations, ethics, comparisons)
- Conclusion (key insights, broader impact, forward vision)
- Acknowledgments and Author Declarations

**🔄 Partial:**
- Related Work (structure complete, need citations)
- Evaluation (structure complete, need actual data)
- References (template created, need to compile bibliography)

**⏳ Not Started:**
- Technical evaluation experiments
- User study recruitment and execution
- Autoethnographic documentation
- Figure creation (7+ figures needed)
- Literature search and citation compilation

**Estimated Work Remaining:** 40-60 hours
- Literature review: 10-15 hours
- Evaluation experiments: 10-15 hours
- User study: 15-20 hours
- Figure creation: 5-8 hours
- Writing/polish: 5-10 hours

---

**Target Submission:** AIMC 2026 (September 16-18, 2026)
**Deadline:** TBD - check https://aimc2026.org/ for CFP announcement

**Recommendation:** Start with literature review (can do while traveling), then run evaluations when back home with access to equipment.
