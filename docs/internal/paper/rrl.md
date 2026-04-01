# Related Research Literature (RRL) for CHULOOPA NIME 2026 Paper

This document summarizes all relevant research papers, projects, and literature for the CHULOOPA paper's Related Work section.

**Last Updated:** March 10, 2026
**Paper Target:** AIMC 2026 (September 16-18, 2026)

---

## Table of Contents

0. [**NEW: Recent Papers (2023-2025)**](#0-recent-papers-2023-2025) ⭐
1. [Beatbox Recognition & Vocal Percussion](#1-beatbox-recognition--vocal-percussion)
2. [Live Looping Systems](#2-live-looping-systems)
3. [Personalized & Interactive Machine Learning for Music](#3-personalized--interactive-machine-learning-for-music)
4. [AI Music Generation & Variation](#4-ai-music-generation--variation)
5. [Real-Time Music Performance Systems](#5-real-time-music-performance-systems)
6. [Audio Transcription & Analysis](#6-audio-transcription--analysis)
7. [Related Projects in Codebase](#7-related-projects-in-codebase)

---

## 0. Recent Papers (2023-2025) ⭐

**Critical Recent Citations Added March 10, 2026**

This section highlights the most recent research (2023-2025) that directly validates CHULOOPA's approach and provides state-of-the-art context.

### 0.1 Real-Time Automatic Drum Transcription Using Dynamic Few-Shot Learning (2024)
**Authors:** Philipp Weber, Christian Uhle, Meinard Müller
**Venue:** Internet of Sounds 2024
**Affiliation:** Fraunhofer IIS, International Audio Laboratories Erlangen
**URL:** https://publica.fraunhofer.de/bitstreams/ff50d62d-1f2d-47c6-86b4-1e52c603b630/download
**PDF:** Available at Fraunhofer repository

**Summary:**
Demonstrates real-time automatic drum transcription using dynamic few-shot learning. Achieves performance competitive with state-of-the-art offline algorithms while enabling model adaptation at inference time with only a few examples per class. System learns new drum classes and fine-tunes models in real-time by providing minimal training examples.

**Relevance to CHULOOPA:**
- **CRITICAL VALIDATION:** Directly supports CHULOOPA's few-shot approach (10 samples per class)
- **Real-time performance:** Shares <50ms latency requirement for live performance
- **Personalization:** Validates minimal training data for user-specific adaptation
- **Inference-time learning:** Similar to CHULOOPA's user training workflow
- **2024 publication:** Very recent, shows few-shot drum transcription is cutting-edge

**Use in Paper:** Section 2.2 (Personalized ML) - **CRITICAL** citation validating few-shot drum approach
Section 5 (Evaluation) - Benchmark for real-time few-shot performance

**Status:** ✅ **DOWNLOADED** - `/Review of Literature/2024-2025_Recent_Papers/2024_Weber_Few-Shot_Drum_Transcription.pdf` (444 KB, 8 pages)

---

### 0.2 STAR Drums: A Dataset for Automatic Drum Transcription (2025)
**Authors:** Philipp Weber, Stefan Balke, Meinard Müller
**Venue:** Transactions of the International Society for Music Information Retrieval, Vol. 8, No. 1 (2025)
**URL:** https://transactions.ismir.net/articles/244/
**PDF:** https://transactions.ismir.net/articles/244/files/6888ab991b2f2.pdf

**Summary:**
Introduces STAR Drums dataset for automatic drum transcription with 10 drum categories (bass drum, snare drum, hi-hat, open hi-hat, tom, ride cymbals, cymbals, short percussion, tambourine, bell). Uses self-attention mechanisms and tatum-synchronous convolutions for state-of-the-art ADT performance. Over 114 hours of annotated real-world music.

**Relevance to CHULOOPA:**
- **Recent ADT benchmark:** Establishes 2025 state-of-the-art for drum transcription
- **10 drum categories:** More comprehensive than CHULOOPA's 3 classes (kick/snare/hat)
- **Deep learning approach:** Contrasts with CHULOOPA's KNN (why simple works with 30 samples)
- **Dataset size:** 114 hours vs. CHULOOPA's 30 samples (personalization-over-scale)

**Use in Paper:** Section 2.1 (Beatbox Recognition) - Cite for recent ADT state-of-the-art
Section 6 (Discussion) - Contrast large-dataset deep learning vs. personalized KNN

**Status:** ✅ **DOWNLOADED** - `/Review of Literature/2024-2025_Recent_Papers/2025_Weber_STAR_Drums_Dataset.pdf` (2.3 MB)

---

### 0.3 Beatbox Classification to Distinguish User Experiences Using Machine Learning (2025)
**Authors:** Rabiah Abdul Rahim et al.
**Venue:** Journal of Computer Science, Vol. 21, No. 7, pp. 961-970 (2025)
**Publisher:** Science Publications
**URL:** https://thescipub.com/abstract/jcssp.2025.961.970

**Summary:**
Recent beatbox classification study achieving 94.55% accuracy with 1-NN classifier and 93.37% with backpropagation neural networks. Tested multiple feature extraction methods:
- Spectral Centroid
- Spectral Magnitude
- Spectral Contrast
- **MFCC (n_mfcc = 22)** ← **BEST PERFORMING FEATURE**

**Key Finding:** "MFCC (n_mfcc = 22) delivers the best feature representation for our KNN, multi-class and non-linear SVM classification model." Tested with K=3, 5, and 7 neighbors.

**Relevance to CHULOOPA:**
- **2025 publication:** Most recent beatbox classification research
- **1-NN accuracy:** 94.55% validates CHULOOPA's KNN approach and ~90% target
- **CRITICAL: MFCC superiority:** Directly validates CHULOOPA's use of MFCC features (13 coefficients)
- **KNN testing:** Tested k=3,5,7 exactly matching CHULOOPA's k=3 approach
- **Feature extraction:** Spectral features + MFCC align with CHULOOPA's approach
- **User experience focus:** Validates user-centered design approach

**Use in Paper:**
- Section 2.1 (Beatbox Recognition) - CRITICAL citation for MFCC in beatbox classification
- Section 3.2.2 (Feature Extraction) - Validate MFCC feature choice with recent research
- Section 3.2.3 (KNN Classification) - Validate KNN performance for beatbox (94.55% with k=1, similar performance expected with k=3)

**Status:** Journal article - may require subscription

---

### 0.4 Self-Supervised Learning for Acoustic Few-Shot Classification (2025)
**Authors:** Coronel Smith et al.
**Venue:** arXiv preprint arXiv:2409.09647 (September 2024, published as 2025)
**URL:** https://arxiv.org/abs/2409.09647
**PDF:** https://arxiv.org/pdf/2409.09647

**Summary:**
Proposes combining self-supervised pre-training with few-shot classification for acoustic tasks, especially with limited labels. Shows that self-supervised learning approaches outperform fully supervised methods when training data is scarce, as in few-shot scenarios. Addresses exactly the scenario CHULOOPA faces: minimal labeled data (10 samples per class).

**Relevance to CHULOOPA:**
- **Limited label scenario:** Directly addresses CHULOOPA's 10-samples-per-class constraint
- **Self-supervised potential:** Future work direction for CHULOOPA (user-specific pre-training)
- **Few-shot validation:** Academic support for minimal training data approaches
- **2025 cutting-edge:** Shows few-shot audio is active research area

**Use in Paper:** Section 2.2 (Personalized ML) - Cite for few-shot learning with limited labels
Section 7 (Future Work) - Self-supervised pre-training as enhancement

**Status:** ✅ **DOWNLOADED** - `/Review of Literature/2024-2025_Recent_Papers/2025_Smith_Self-Supervised_Few-Shot_Audio.pdf` (514 KB, 3 pages)

---

### 0.5 Transformers and Audio Detection Tasks: An Overview (2024)
**Authors:** José Pereira, Jaime S. Cardoso
**Venue:** Digital Signal Processing, Vol. 155, Article 104883 (2024)
**Publisher:** Elsevier
**URL:** https://www.sciencedirect.com/science/article/pii/S1051200424005803

**Summary:**
Comprehensive survey of transformer architectures for audio detection tasks including music transcription, sound event detection, and audio classification. Reviews Audio Spectrogram Transformer (AST) and other attention-based architectures. Discusses shift from CNNs to transformers in audio processing, highlighting advantages for capturing long-range dependencies.

**Relevance to CHULOOPA:**
- **Transformer context:** Provides background for rhythmic_creator's transformer-LSTM architecture
- **Audio classification:** Contextualizes CHULOOPA's classification task in modern deep learning
- **2024 survey:** Recent comprehensive review of state-of-the-art
- **Design justification:** Explains why CHULOOPA doesn't use transformers (30 samples too small)

**Use in Paper:** Section 2.3 (AI Music Generation) - Context for transformer-based rhythm generation
Section 6 (Discussion) - Justify KNN over transformers for minimal data

**Status:** Elsevier journal - may require subscription

---

### 0.6 FAST: Fast Audio Spectrogram Transformer (2025)
**Authors:** Anugunj Naman, Deepak Ahuja
**Venue:** arXiv preprint arXiv:2501.01104 (January 2025)
**URL:** https://arxiv.org/abs/2501.01104
**PDF:** https://arxiv.org/pdf/2501.01104

**Summary:**
Introduces FAST (Fast Audio Spectrogram Transformer) using efficient convolutional feature extraction inspired by MobileViT. Demonstrates that carefully designed transformers can achieve strong performance on resource-constrained devices without GPU acceleration. Employs 3×3 convolution followed by point-wise convolution for efficient feature extraction.

**Relevance to CHULOOPA:**
- **CPU inference:** Validates CHULOOPA's offline-first CPU-only design
- **Resource constraints:** Shows efficient AI is possible on consumer hardware
- **2025 cutting-edge:** Latest work on efficient transformer architectures
- **Future direction:** Potential for on-device transformer variation generation

**Use in Paper:** Section 2.5 (Co-Creative AI) - Cite for efficient offline AI
Section 7 (Future Work) - On-device transformer models as future enhancement

**Status:** ✅ **DOWNLOADED** - `/Review of Literature/2024-2025_Recent_Papers/2025_Naman_FAST_Audio_Spectrogram_Transformer.pdf` (747 KB, 2 pages)

---

### 0.7 Deep Learning Approaches for Automatic Drum Transcription (2023)
**Authors:** Cahyaningtyas, Purwitasari, Fatichah (Note: Previously incorrectly listed as Maia et al.)
**Venue:** EMITTER International Journal of Engineering Technology, Vol. 11, No. 1 (2023)
**DOI:** https://doi.org/10.24003/emitter.v11i1.764
**URL:** https://emitter.pens.ac.id/index.php/emitter/article/view/764

**Summary:**
Presents an Automatic Drum Transcription (ADT) application using segment and classify method with Deep Learning classification. LSTM models achieve 77-87% accuracy on benchmark datasets using multi-objective optimization. Discusses recent trends focusing on self-attention mechanisms and tatum-synchronous convolutions. Notes that massive amounts of labeled data (>100 hours) are required for neural networks to perform well.

**Relevance to CHULOOPA:**
- **LSTM performance:** 77-87% accuracy provides comparison to CHULOOPA's ~90% with KNN
- **Data requirements:** Highlights neural networks need >100 hours vs. CHULOOPA's 30 samples
- **Design tradeoff:** Deep learning (huge data) vs. KNN (minimal user-specific data)
- **2023 ADT work:** Recent review of ADT approaches

**Use in Paper:** Section 2.1 (Beatbox Recognition) - Context for drum transcription methods
Section 6 (Discussion) - Justify KNN choice: 30 samples insufficient for deep learning

**Status:** ⏳ **NOT YET DOWNLOADED** - Open access but download link requires different method. Try via CalArts library.

---

### 0.8 Study on Classification of Beatbox Sounds Based on Timbre Features (2020)
**Authors:** Yichen Li, Jing Liu, Wei Wu
**Venue:** 2020 IEEE 4th Information Technology, Networking, Electronic and Automation Control Conference (ITNEC), Vol. 1, pp. 1506-1510
**DOI:** 10.1109/ITNEC48623.2020.9084702
**URL:** https://ieeexplore.ieee.org/document/9262748/

**Summary:**
Explores timbre feature extraction for beatbox sound classification using machine learning. Demonstrates that spectral features remain effective for vocal percussion recognition in modern deep learning contexts. Uses features including spectral centroid, MFCC, and temporal characteristics.

**Relevance to CHULOOPA:**
- **Timbre features:** Validates CHULOOPA's spectral-based feature vector
- **Beatbox-specific:** Focused on beatbox (not general percussion)
- **Recent validation:** Shows spectral features still relevant (2020)
- **MFCC usage:** Confirms MFCCs are standard for beatbox timbre classification
- **Feature selection:** Supports flux, energy, spectral bands + MFCC approach

**Use in Paper:** Section 2.1 (Beatbox Recognition) - Validate feature extraction approach
Section 3.2.2 (Feature Extraction) - Support for spectral feature + MFCC choices

**Status:** IEEE Xplore - may require subscription

---

### 0.9 MFCC Coefficient Selection for Audio Classification (2021)
**Authors:** Hasan et al.
**Venue:** The Journal of Engineering (Wiley), 2021
**DOI:** 10.1049/tje2.12082
**URL:** https://ietresearch.onlinelibrary.wiley.com/doi/full/10.1049/tje2.12082

**Summary:**
Empirical study on optimal number of MFCC coefficients for speech recognition. Found that 13 MFCCs gave 74% vowel and 51% word classification accuracy, while 25 MFCCs gave 83% vowel and 57% word classification accuracy on Bengali speech dataset. Standard practice uses 8-13 coefficients for most applications, with up to 20-25 coefficients for tasks requiring detailed pitch and tone information.

**Key Findings:**
- **Standard: 13 coefficients** for general audio/speech tasks
- **Higher accuracy: 20-25 coefficients** when capturing finer pitch/harmonic details
- **Trade-off:** More coefficients = more model complexity, needs more training data
- **Lower-order preference:** Lower coefficients contain more cues about overall spectral shape

**Relevance to CHULOOPA:**
- **CRITICAL: Validates 13 MFCCs** - CHULOOPA's training data uses 13 MFCC coefficients (standard practice)
- **Expansion potential:** Could increase to 20-22 MFCCs (matching 2025 beatbox paper) for improved accuracy
- **Feature design:** Confirms CHULOOPA's MFCC choice aligns with established research
- **Percussion applicability:** While focused on speech, principles apply to percussion timbre classification

**Use in Paper:**
- Section 3.2.2 (Feature Extraction) - CRITICAL citation justifying MFCC coefficient count
- Section 7 (Future Work) - Mention potential to increase to 20-22 coefficients

**Status:** Open access (Wiley Online Library)

---

### 0.10 Spectral Energy Distribution in Human Beatbox Sounds (2022)
**Authors:** [Authors from Springer publication]
**Venue:** Springer (2022)
**DOI:** 10.1007/978-3-032-03729-9_15
**URL:** https://link.springer.com/chapter/10.1007/978-3-032-03729-9_15

**Summary:**
First comprehensive investigation of spectral energy distribution in beatbox sounds. Analyzes formant frequencies and spectral characteristics including center of gravity, standard deviation, skewness, and kurtosis. Provides acoustic signatures for different beatbox drum sounds.

**Relevance to CHULOOPA:**
- **Acoustic signatures:** Confirms each beatbox sound has distinct spectral fingerprint
- **Spectral features:** Validates CHULOOPA's use of spectral bands (band1-5)
- **Recent research:** Shows active research in beatbox spectral analysis (2022)
- **Feature design:** Supports frequency band energy as discriminative features

**Use in Paper:**
- Section 2.1 (Beatbox Recognition) - Cite for beatbox acoustic characterization
- Section 3.2.2 (Feature Extraction) - Validate spectral band feature choices

**Status:** Springer publication - may require subscription

---

### 0.11 Vocal Drum Sounds in Human Beatboxing: Acoustic and Articulatory Study (2021)
**Authors:** Paroni et al.
**Venue:** Journal of the Acoustical Society of America (JASA), Vol. 149, No. 1, pp. 191 (2021)
**DOI:** 10.1121/10.0003046
**URL:** https://pubs.aip.org/asa/jasa/article/149/1/191/610401/
**PDF:** https://hal.univ-grenoble-alpes.fr/hal-03107358v1/file/Paroni_JASA_2021.pdf

**Summary:**
Acoustic and articulatory exploration of vocal drum sounds using electromagnetic articulography (EMA). Examines how vocal tract movements and articulator positions correlate with acoustic output of beatbox percussion sounds. Provides systematic investigation of sound production mechanisms.

**Relevance to CHULOOPA:**
- **Acoustic validation:** Confirms distinct acoustic characteristics for kick/snare/hat
- **Production mechanisms:** Informs understanding of why features discriminate between classes
- **Recent research:** 2021 publication shows continued interest in beatbox acoustics
- **Feature correlation:** Acoustic differences correlate with articulatory differences

**Use in Paper:**
- Section 2.1 (Beatbox Recognition) - Cite for beatbox acoustic/articulatory research
- Section 3.2.2 (Feature Extraction) - Theoretical basis for feature discriminability

**Status:** JASA publication - open access PDF available

---

### Summary: Why These Papers Matter

**Validation of CHULOOPA's Approach:**
1. **Weber et al. (2024)** - Few-shot drum transcription is cutting-edge ✅
2. **Weber et al. (2025)** - Recent ADT state-of-the-art benchmark ✅
3. **Rahim et al. (2025)** - KNN achieves 94.55% for beatbox, **MFCC (n=22) best feature** ✅
4. **Smith et al. (2025)** - Few-shot with limited labels is academically sound ✅

**Context for Design Decisions:**
5. **Pereira & Cardoso (2024)** - Why transformers aren't used (30 samples too small)
6. **Maia et al. (2023)** - Why deep learning isn't used (needs >100 hours)
7. **Naman & Ahuja (2025)** - Efficient offline AI is possible

**Feature Extraction Support (CRITICAL FOR MARCH 2026 FIX):**
8. **Rahim et al. (2025)** - **MFCC (n=22) delivers best feature representation for KNN** ✅
9. **Hasan et al. (2021)** - **13 MFCCs standard, 20-25 for better accuracy** ✅
10. **Li et al. (2020)** - Spectral features + MFCC work for beatbox ✅
11. **Springer (2022)** - Spectral energy distribution validates frequency bands ✅
12. **Paroni et al. (2021)** - Acoustic signatures validate feature discriminability ✅

**Download Summary (March 10, 2026):**

✅ **Successfully Downloaded (4 papers, 4.0 MB total):**
1. Weber et al. 2024 - Few-Shot Drum Transcription (444 KB, 8 pages)
2. Weber et al. 2025 - STAR Drums Dataset (2.3 MB)
3. Smith et al. 2025 - Self-Supervised Few-Shot Audio (514 KB, 3 pages)
4. Naman & Ahuja 2025 - FAST Transformer (747 KB, 2 pages)

⏳ **Not Yet Downloaded (Require Subscription/Alternative Access):**
5. Rahim et al. 2025 - Beatbox Classification (Journal of Computer Science)
6. Pereira & Cardoso 2024 - Transformers Survey (Elsevier - Digital Signal Processing)
7. Cahyaningtyas et al. 2023 - Deep Learning ADT (EMITTER - open access, download issues)
8. Li et al. 2020 - Beatbox Timbre Features (IEEE Xplore)

**Location:** All downloaded PDFs saved to:
`/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Review of Literature/2024-2025_Recent_Papers/`

**Action Items:**
- [x] Download openly available PDFs (4/8 completed)
- [ ] Access subscription papers via CalArts library
- [ ] Extract key details from downloaded PDFs
- [ ] Update paper.md BibTeX with correct author names (Cahyaningtyas not Maia)
- [ ] Update paper.md citations with page numbers from PDFs
- [ ] Create comparison table for Related Work section

---

## 1. Beatbox Recognition & Vocal Percussion

### 1.1 A New Dataset for Amateur Vocal Percussion Analysis (2019)
**Authors:** [Research team - see ResearchGate]
**Venue:** ACM Audio Mostly 2019
**URL:** https://dl.acm.org/doi/10.1145/3356590.3356844

**Summary:**
Introduces the Amateur Vocal Percussion (AVP) dataset to investigate how people with little or no experience in beatboxing approach vocal percussion tasks. The dataset comprises 9,780 utterances recorded by 28 participants with fully annotated onsets and labels (kick drum, snare drum, closed hi-hat, open hi-hat).

**Relevance to CHULOOPA:**
- **Critical benchmark:** This is exactly the domain CHULOOPA targets (amateur beatboxers, not professionals)
- **Dataset comparison:** CHULOOPA uses 10 samples/class (30 total) vs. AVP's 9,780 utterances across 28 users
- **Key distinction:** CHULOOPA personalizes per-user rather than training on multi-user dataset
- **Citation value:** Establishes that amateur beatbox recognition is a recognized research problem

**Use in Paper:** Section 2.1 (Beatbox Recognition) - cite as motivation for personalized approach vs. generic datasets

---

### 1.2 Beatbox Classification Using ACE (Autonomous Classification Engine)
**Authors:** Sinyor, McKay
**Venue:** [Conference/Journal - Semantic Scholar]
**URL:** https://www.semanticscholar.org/paper/Beatbox-Classification-Using-ACE-Sinyor-McKay/1efe613c4888a310b37d56aaac7816557566eccb

**Summary:**
Uses the Autonomous Classification Engine (ACE) to classify beatboxing (vocal percussion) sounds. ACE is a meta-learner that automatically selects optimal features and classification algorithms.

**Relevance to CHULOOPA:**
- **Contrast in approach:** ACE uses complex meta-learning vs. CHULOOPA's intentionally simple KNN
- **Feature extraction:** May provide insights on acoustic features for beatbox classification
- **Generalization focus:** ACE aims for broad generalization; CHULOOPA aims for user-specific accuracy

**Use in Paper:** Section 2.1 - cite as example of generic beatbox classification system

---

### 1.3 Delayed Decision-Making in Real-Time Beatbox Percussion Classification (2010)
**Authors:** [Authors TBD]
**Venue:** Journal of New Music Research, Vol 39, No 3
**URL:** https://www.tandfonline.com/doi/full/10.1080/09298215.2010.512979

**Summary:**
Addresses real-time beatbox percussion classification with delayed decision-making strategies to improve accuracy.

**Relevance to CHULOOPA:**
- **Real-time constraint:** Shares CHULOOPA's <50ms latency requirement for live performance
- **Timing trade-offs:** Explores accuracy vs. latency (CHULOOPA uses debouncing for similar purpose)
- **Classification strategies:** May inform onset detection and classification pipeline

**Use in Paper:** Section 2.1 - cite for real-time beatbox classification approaches

---

### 1.4 Analysis and Automatic Recognition of Human BeatBox Sounds: A Comparative Study
**Authors:** Picart, Brognaux
**Venue:** [Conference - Semantic Scholar]
**URL:** https://www.semanticscholar.org/paper/Analysis-and-automatic-recognition-of-Human-BeatBox-Picart-Brognaux/248ea123fb0412b733f09087aa2f538026abe270

**Summary:**
Comparative study of automatic recognition methods for human beatbox sounds, analyzing different acoustic features and classification techniques.

**Relevance to CHULOOPA:**
- **Feature selection:** Informs CHULOOPA's 5D feature vector (flux, energy, band energies)
- **Benchmark comparison:** Establishes baseline accuracies for beatbox classification
- **Method comparison:** Validates CHULOOPA's choice of KNN vs. more complex methods

**Use in Paper:** Section 2.1 - cite for feature extraction and classification baseline

---

### 1.5 Query-by-Beat-Boxing: Music Retrieval For The DJ
**Authors:** [Authors TBD]
**Venue:** [Conference - ResearchGate]
**URL:** https://www.researchgate.net/publication/220723293_Query-by-Beat-Boxing_Music_Retrieval_For_The_DJ

**Summary:**
Uses beatboxing as a query interface for music retrieval, allowing DJs to search for tracks by beatboxing rhythmic patterns.

**Relevance to CHULOOPA:**
- **Beatbox as interface:** Validates beatboxing as legitimate musical input method
- **Rhythm pattern matching:** Different goal (retrieval vs. transcription) but similar input
- **User study insights:** May provide methodology for evaluating beatbox interfaces

**Use in Paper:** Section 2.4 (Live Performance Systems) - cite as example of beatbox interface design

---

### 1.6 Dubler 2: Real-Time Voice-to-MIDI Software (Commercial Product)
**Company:** Vochlea
**Product:** Dubler 2
**URL:** https://vochlea.com/products/dubler2
**Price:** $149 (commercial software)
**Release:** 2020s (ongoing updates)

**Summary:**
Commercial software that converts vocal input (singing, humming, beatboxing) into MIDI control in real-time for DAW integration. Uses AI-powered pitch tracking technology to analyze vocal characteristics beyond simple pitch-to-MIDI conversion, processing "timbral qualities" to trigger samples, control pitched instruments, and manipulate envelope/velocity parameters. Functions as a MIDI controller operated by voice instead of hands. Supports percussive sample triggering, 14+ musical scales, extensive chord library, and control of 4 CC values simultaneously. Compatible with any DAW accepting MIDI input.

**Relevance to CHULOOPA:**
- **INSPIRATION:** This product directly inspired CHULOOPA's development
- **Commercial alternative:** Represents established voice-to-MIDI market
- **Key differences:**
  - **Dubler 2:** Generic model, DAW-dependent, requires MIDI workflow, commercial ($149)
  - **CHULOOPA:** Personalized user-trainable (10 samples), standalone looper, research project, offline-first
- **Target users:** Both target vocalists/beatboxers lacking instrumental training
- **Real-time:** Both emphasize live processing vs. offline conversion
- **Voice interface:** Validates voice as legitimate music control method

**Design Comparison:**

| Feature | Dubler 2 | CHULOOPA |
|---------|----------|----------|
| **Input** | Singing, humming, beatboxing | Beatboxing only |
| **Output** | MIDI to DAW | Standalone drum loops |
| **ML Approach** | Generic AI pitch tracking | User-trainable KNN (10 samples) |
| **Personalization** | None (generic model) | Per-user training required |
| **Integration** | DAW plugin/MIDI | Standalone ChucK system |
| **Looping** | DAW-dependent | Built-in with AI variations |
| **AI Variations** | None | Transformer-LSTM generation |
| **Price** | $149 commercial | Open research project |
| **Performance** | DAW latency-dependent | <50ms standalone |

**Use in Paper:**
- **Section 1.1 (Motivation):** Mention as inspiration, commercial alternative
- **Section 2.1 (Beatbox Recognition):** Cite as commercial voice-to-MIDI system
- **Section 2.4 (Live Performance):** Compare standalone looper vs. DAW integration
- **Section 6 (Discussion):** Contrast generic vs. personalized approaches
- **Acknowledgments:** Optional mention as inspiration for research direction

**Citation Strategy:**
While Dubler 2 is a commercial product (not peer-reviewed research), it represents an important reference point as:
1. Established commercial voice-to-MIDI solution
2. Direct inspiration for CHULOOPA
3. Demonstrates market validation for voice-controlled music systems
4. Highlights gap: no commercial products offer user-trainable personalization + standalone looping

**Suggested Citation Format (if included):**
```
Vochlea. (2024). Dubler 2: Real-time voice to MIDI software.
Retrieved from https://vochlea.com/products/dubler2
```

---

## 2. Live Looping Systems

### 2.1 The Living Looper: Rethinking the Musical Loop as a Machine Action-Perception Loop (NIME 2023)
**Authors:** Victor Shepardson, Thor Magnusson
**Venue:** NIME 2023
**URL:** https://nime.org/proc/nime2023_32/index.html
**PDF:** https://iil.is/pdf/2023_nime_shepardson_magnusson_living_looper.pdf

**Summary:**
Real-time software system for prediction and continuation of audio signals in looping pedal format. Each channel is activated by footswitch and repeats or continues incoming audio using neural synthesis (RAVE encoder-decoder). Living Loop channels learn in context of other channels, creating shifting networks of agency between players and AI loops. Implements nn_tilde for TorchScript export.

**Relevance to CHULOOPA:**
- **NIME 2023 peer-reviewed:** Establishes state-of-the-art in neural looping systems
- **Key difference:** Audio-based (Living Looper) vs. symbolic/drum-based (CHULOOPA)
- **Shared design:** Footswitch/MIDI control, real-time performance focus, loop-based interaction
- **AI augmentation:** Both use AI to extend creativity (neural continuation vs. pattern variation)
- **Architecture inspiration:** nn_tilde framework informs CHULOOPA's ChucK+Python architecture

**Use in Paper:** Section 2.4 (Live Looping Systems) - CRITICAL citation as related NIME work, contrast audio vs. symbolic approaches

**Status:** This is in Paolo's codebase at `/Code/living-looper/`

---

### 2.2 GrooveTransformer: A Generative Drum Sequencer Eurorack Module (NIME 2024)
**Authors:** Behzad Haki, Nicholas Evans, Sergi Jordà
**Venue:** NIME 2024

**Summary:**
Generative drum sequencer implemented as Eurorack module, uses transformer architecture for drum pattern generation.

**Relevance to CHULOOPA:**
- **Drum pattern generation:** Direct comparison point (transformer vs. Gemini LLM)
- **Hardware vs. software:** Eurorack vs. laptop-based implementation
- **Generative approach:** Both systems generate drum patterns, different input methods
- **NIME 2024:** Very recent work, shows active research in drum generation

**Use in Paper:** Section 2.3 (AI Music Generation) - cite as related drum generation system, contrast generative-only vs. CHULOOPA's transcription+generation

---

### 2.3 dB (Drummer Bot): A Web-based Drummer Bot for Finger-Tapping (NIME 2024)
**Authors:** Çağrı Erdem, Carsten Griwodz
**Venue:** NIME 2024

**Summary:**
Web-based drummer bot that responds to finger-tapping input, creates real-time drum accompaniment.

**Relevance to CHULOOPA:**
- **Alternative input method:** Finger-tapping vs. beatboxing as drum interface
- **Real-time performance:** Shared design goal of live responsiveness
- **Accompaniment focus:** Similar use case (solo performer needing drums)
- **Web-based:** Different platform (browser vs. ChucK), shows diversity of approaches

**Use in Paper:** Section 2.4 (Live Performance Systems) - cite as alternative drum input interface

---

### 2.4 Bishop BoomBox: A Physically Accessible Drum Machine (NIME 2024)
**Authors:** Lloyd May, Lateef McLeod, Michael Mulshine
**Venue:** NIME 2024

**Summary:**
Physically accessible drum machine designed for performers with physical disabilities.

**Relevance to CHULOOPA:**
- **Accessibility angle:** Both systems focus on making drum creation accessible (different barriers)
- **NIME 2024:** Recent work on accessibility in music technology
- **Design philosophy:** Lowering barriers to drum programming through interface design

**Use in Paper:** Section 2.4 - cite for accessibility theme, contrast physical vs. cognitive accessibility

---

## 3. Personalized & Interactive Machine Learning for Music

### 3.1 Exploring the Potential of Interactive Machine Learning for Sound Generation (NIME 2023)
**Authors:** [Authors TBD - check NIME 2023 proceedings]
**Venue:** NIME 2023
**URL:** https://nime.org/proc/nime2023_88/index.html

**Summary:**
Introduces ASCIML (Assistant for Sound Creation with Interactive Machine Learning), allowing musicians to use IML to create personalized datasets and generate new sounds. Implemented in Google Colab with four stages: Data Design, Training, Evaluation, Audio Creation. Study with 27 musicians (no prior ML knowledge) showed preference for microphone recording and synthesis for dataset design, and pre-trained model implementation.

**Relevance to CHULOOPA:**
- **Personalized dataset creation:** ASCIML lets users create custom datasets; CHULOOPA trains on user-specific beatbox
- **Non-ML-expert users:** Both systems target musicians without ML knowledge
- **Minimal training paradigm:** Validates CHULOOPA's approach of user-specific training
- **NIME 2023 peer-reviewed:** Establishes personalization as accepted NIME theme

**Use in Paper:** Section 2.2 (Personalized ML) - CRITICAL citation for personalized ML in music interfaces

---

### 3.2 Building NIMEs with Embedded AI Workshop (NIME 2024)
**Authors:** Charles Martin (organizer) and team
**Venue:** NIME 2024 Workshop
**URL:** https://smcclab.github.io/nime-embedded-ai/

**Summary:**
Workshop providing starting points for developing NIMEs with embedded platforms and machine learning models. Charles Martin has history of AI/ML NIME workshops (2019, 2020, 2021) and Generative AI/HCI workshops at CHI (2022, 2023, 2024).

**Relevance to CHULOOPA:**
- **Embedded ML for NIMEs:** CHULOOPA uses embedded KNN model (scikit-learn)
- **Accessible AI tools:** Workshop focus aligns with CHULOOPA's goal of accessible ML
- **Community context:** Shows active NIME community interest in AI/ML integration

**Use in Paper:** Section 2.2 - cite for context on ML in NIME community

---

### 3.3 Real-Time Co-Creation of Expressive Music Performances (NIME 2023)
**Authors:** [Authors TBD]
**Venue:** NIME 2023
**URL:** https://nime.org/proceedings/2023/nime2023_91.pdf

**Summary:**
Explores real-time co-creation between human performers and AI systems, focusing on expressive music performance.

**Relevance to CHULOOPA:**
- **Human-AI collaboration:** CHULOOPA positions AI as creative partner (variation generation)
- **Real-time constraint:** Shared emphasis on live performance responsiveness
- **Expression preservation:** CHULOOPA's timing preservation aligns with expressiveness focus

**Use in Paper:** Section 2.3 (AI Music Generation) - cite for human-AI collaboration paradigm

---

## 4. AI Music Generation & Variation

### 4.1 LoopGen: Training-Free Loopable Music Generation (2025)
**Authors:** Marincione, Strano, Crisostomi, Ribuoli, Rodolà
**Venue:** arXiv 2025
**URL:** https://arxiv.org/abs/2504.04466
**Citation:** arXiv:2504.04466

**Summary:**
Training-free loop generation using Meta's MAGNeT model from audiocraft library. Focuses on generating loopable music without requiring model training.

**Relevance to CHULOOPA:**
- **Training paradigm contrast:** Training-free (LoopGen) vs. personalized training (CHULOOPA)
- **Loop generation:** Both systems generate loops, different approaches (audio generation vs. drum transcription+variation)
- **Available in codebase:** Paolo has LoopGen at `/Code/loopgen/`
- **Design philosophy:** LoopGen = zero-shot generation; CHULOOPA = few-shot personalization

**Use in Paper:** Section 2.2 (Personalized ML) - cite as contrast to training-free vs. personalized approaches
Section 2.3 (AI Generation) - cite for loop generation state-of-the-art

**Status:** This is in Paolo's codebase at `/Code/loopgen/`

---

### 4.2 SongComposer: AI Composition System (2025)
**Authors:** Ding et al.
**Venue:** [Conference TBD]
**File:** `/Review of Literature/2025 - SongComposer - Ding et al.pdf`

**Summary:**
Recent AI composition system (details TBD - need to read PDF).

**Relevance to CHULOOPA:**
- **AI generation:** Represents state-of-the-art in AI music composition
- **Comparison point:** Full composition vs. CHULOOPA's drum pattern variation

**Use in Paper:** Section 2.3 (AI Music Generation) - cite for broader AI music generation context

**Action:** Read PDF to extract key details

---

### 4.3 Music As Natural Language: Deep Learning Driven Rhythmic Creation
**Authors:** [Authors TBD]
**Venue:** [Conference TBD]
**File:** `/Review of Literature/Music As Natural Language Deep Learning Driven Rhythmic Creation Final (1).pdf`

**Summary:**
Applies deep learning to rhythmic pattern creation, treating music as natural language.

**Relevance to CHULOOPA:**
- **LLM for rhythm:** CHULOOPA uses Gemini (LLM) for drum pattern variation - direct parallel
- **Rhythm generation:** Both systems generate rhythmic patterns
- **Symbolic representation:** May use similar symbolic encoding to CHULOOPA's CSV format

**Use in Paper:** Section 2.3 (AI Generation) - cite for LLM-based rhythm generation

**Action:** Read PDF to extract key details

---

### 4.4 Magenta: GrooVAE and MusicVAE
**Authors:** Google Magenta Team
**Venue:** Various publications
**URL:** https://magenta.tensorflow.org/

**Summary:**
GrooVAE (Groove Variational Autoencoder) for drum pattern humanization and variation. MusicVAE for broader music generation with latent space interpolation.

**Relevance to CHULOOPA:**
- **Direct comparison:** CHULOOPA initially explored GrooVAE, switched to Gemini
- **Design decision justification:** GrooVAE's piano roll conversion proved unreliable for ChucK's non-quantized format
- **State-of-the-art baseline:** Magenta represents established approach to drum variation

**Use in Paper:** Section 2.3 (AI Generation) - CRITICAL to explain why CHULOOPA uses Gemini instead of Magenta
Include in Discussion: Honest assessment of GrooVAE limitations for non-quantized timing

**Status:** Paolo has Magenta setup documented in `magenta_variations.md` (attempted integration)

---

### 4.5 AI Harmonizer: Expanding Vocal Expression with Generative AI (NIME 2025)
**Authors:** [Authors TBD]
**Venue:** NIME 2025
**URL:** https://nime.org/proceedings/2025/nime2025_84.pdf

**Summary:**
Uses generative AI to expand vocal expression through harmonization.

**Relevance to CHULOOPA:**
- **Vocal input:** Both systems use voice as input (harmonizer = pitch, CHULOOPA = percussion)
- **AI augmentation:** Shared philosophy of AI expanding human vocal expression
- **NIME publication:** Very recent (2025) - shows active research in vocal+AI interfaces

**Use in Paper:** Section 2.3 (AI Generation) - cite for vocal+AI augmentation approaches

---

## 5. Real-Time Music Performance Systems

### 5.1 Notochord: Monophonic Music Continuation (AIMC 2022)
**Authors:** Intelligent Instruments Lab
**Venue:** AIMC 2022
**URL:** https://zenodo.org/record/7088404
**Docs:** https://intelligent-instruments-lab.github.io/notochord/

**Summary:**
Real-time neural network model for MIDI performances. RNN-based architecture for musical generation with interactive MIDI processing apps (homunculus, harmonizer, improviser). Integrates with SuperCollider, TidalCycles, fluidsynth.

**Relevance to CHULOOPA:**
- **Real-time music AI:** Shares <50ms latency constraint for live performance
- **MIDI-based:** Both systems output symbolic music (MIDI vs. drum samples)
- **Personalization potential:** Notochord can be trained on user-specific datasets
- **Architecture comparison:** RNN (Notochord) vs. KNN+LLM (CHULOOPA)

**Use in Paper:** Section 2.5 (Real-Time Performance) - cite for real-time AI music generation
Section 2.2 (Personalized ML) - mention user-specific training capabilities

**Status:** This is in Paolo's codebase at `/Code/notochord/`

---

### 5.2 Human-Machine Agencies in Live Coding for Music Performance (2024)
**Authors:** [Authors TBD]
**Venue:** Journal article (Tandfonline)
**URL:** https://www.tandfonline.com/doi/full/10.1080/09298215.2024.2442355

**Summary:**
Explores human-machine agencies in live coding, examining how performers and AI systems share control in music performance.

**Relevance to CHULOOPA:**
- **Agency distribution:** CHULOOPA gives performer control over when variations happen (manual trigger)
- **Human-AI collaboration:** Philosophical framing for CHULOOPA's design
- **Performance paradigm:** Live coding shares real-time, improvisational nature with CHULOOPA

**Use in Paper:** Section 6 (Discussion) - cite for theoretical framing of human-AI collaboration

---

## 6. Audio Transcription & Analysis

### 6.1 Real-Time Monophonic Singing Pitch Detection
**Authors:** [Authors TBD]
**Venue:** [Conference TBD]
**File:** `/Review of Literature/Real-timemonophonicsingingpitchdetection.pdf`

**Summary:**
Real-time pitch detection for monophonic singing, likely using autocorrelation or similar methods.

**Relevance to CHULOOPA:**
- **Real-time transcription:** Shares goal of live audio analysis
- **Monophonic input:** Similar constraint (one sound at a time)
- **Onset detection:** May inform CHULOOPA's spectral flux approach
- **Latency optimization:** Techniques applicable to beatbox transcription

**Use in Paper:** Section 2.1 (Beatbox Recognition) - cite for real-time audio analysis methods

**Action:** Read PDF to extract key details

---

### 6.2 A Musical Approach to Monophonic Audio Transcription and Quantization
**Authors:** [Authors TBD]
**Venue:** [Conference TBD]
**File:** `/Review of Literature/A Musical Approach to Monophonic Audio Transcription and Quantization.pdf`

**Summary:**
Addresses audio-to-MIDI transcription with focus on quantization strategies.

**Relevance to CHULOOPA:**
- **Key distinction:** CHULOOPA preserves NON-quantized timing (critical contribution)
- **Transcription pipeline:** May inform onset detection and symbolic conversion
- **Design contrast:** Traditional systems quantize; CHULOOPA preserves timing feel

**Use in Paper:** Section 2.1 (Beatbox Recognition) - cite to contrast quantization approaches
Section 6 (Discussion) - explain why CHULOOPA avoids quantization

**Action:** Read PDF to extract key details

---

## 7. Related Projects in Codebase

### 7.1 Chuck UAna: Audio-to-MIDI Transcription System
**Location:** `/Code/Chuck UAna/`
**Author:** Paolo Sandejas (thesis work)

**Summary:**
Paolo's earlier project using ChucK for audio-to-MIDI transcription. Uses pitch detection (AutoCorr UAna), MIDI recording/playback, and AI integration framework. Documents integration attempts with Notochord, Magenta, GPT/Claude.

**Relevance to CHULOOPA:**
- **Architecture evolution:** Shows Paolo's progression from pitch-based to onset-based transcription
- **Lessons learned:** Informed CHULOOPA's design decisions
- **Alternative approach:** Melody/pitch vs. percussion/rhythm focus

**Use in Paper:** Optionally mention in Introduction or Discussion as design evolution

---

### 7.2 CHUGL (ChucK Graphics Library)
**Location:** `/Code/CHUGL/`
**Author:** Paolo's learning materials

**Summary:**
Learning guide and visualization framework for ChucK graphics.

**Relevance to CHULOOPA:**
- **Visualization layer:** CHULOOPA uses ChuGL for real-time visual feedback
- **Future work:** Plans to improve ChuGL visualizations mentioned in paper

**Use in Paper:** Section 4 (Implementation) - mention ChuGL for visualization

---

### 7.3 Transformer-From-Scratch
**Location:** `/Code/transformer-from-scratch/`
**Author:** Paolo's educational work

**Summary:**
Educational implementation of transformer architecture.

**Relevance to CHULOOPA:**
- **ML background:** Demonstrates Paolo's understanding of modern ML architectures
- **Optional mention:** Could be referenced if discussing future transformer-based variations

**Use in Paper:** Minimal relevance, skip unless space permits

---

## 8. Additional arXiv Papers (Require Verification)

### Papers with Cryptic Filenames:
**Location:** `/Review of Literature/`

- **2111.05011v2.pdf** - arXiv paper (verify title/content)
- **2312.09911v3.pdf** - arXiv paper (verify title/content)
- **2410.06885v2.pdf** - arXiv paper (verify title/content)
- **000004.pdf, 000007.pdf, 000008.pdf** - Additional papers (verify content)

**Action:** Extract metadata from PDFs to identify papers, verify relevance

---

## 9. Key Gaps in Literature (From CHULOOPA Draft Paper)

Based on the draft paper's Related Work section (Section 2.5), the following gaps should be addressed:

### Research Gaps CHULOOPA Addresses:

1. **No system combines personalization + real-time + AI variation**
   - Living Looper: real-time + AI, but not personalized and audio-based
   - ASCIML: personalized + ML, but not real-time or performance-focused
   - GrooveTransformer: AI generation, but not transcription-based

2. **Minimal training data for personalized models**
   - Most beatbox systems use large generic datasets (AVP: 9,780 utterances)
   - CHULOOPA: 10 samples per class (30 total) per user

3. **Timing preservation in AI generation**
   - Most AI music systems quantize to grids (Magenta GrooVAE uses piano roll)
   - CHULOOPA: Gemini maintains exact loop duration and non-quantized feel

4. **Accessibility focus for amateur beatboxers**
   - Most systems target professional beatboxers or generic users
   - CHULOOPA: Explicitly designed for "shitty drummers who can kinda beatbox"

---

## 10. New Papers Added March 2026

**Papers confirmed via subagent survey of AIMC 2025 proceedings + Jake Chen's recommendations.**

---

### 10.1 ChucK: A Strongly Timed Computer Music Language (CMJ 2015)
**Authors:** Ge Wang, Perry R. Cook, Spencer Salazar
**Venue:** Computer Music Journal, Vol. 39, No. 4, pp. 10–29
**Year:** 2015
**DOI:** 10.1162/COMJ_a_00324
**BibTeX key:** wang2015chuck

**Summary:**
Introduces ChucK, a strongly-timed concurrent computer music language designed for real-time audio synthesis, analysis, and control. Defines the "strongly timed" programming model—time-aware concurrent code that enables precise scheduling at any granularity—and the chuck operator (=>) for signal routing. Core concepts include shreds (concurrent processes), unit generators (UGens), and on-the-fly coding for live performance.

**Relevance to CHULOOPA:**
- **Core technology:** CHULOOPA is implemented entirely in ChucK 1.5.x
- **Strongly-timed scheduling:** CHULOOPA's loop boundary system and queued actions rely on ChucK's time-aware scheduling
- **Concurrent shreds:** Onset detection, classification, and playback run as parallel ChucK shreds
- **MIDI I/O:** ChucK's native MIDI support handles all CHULOOPA controller input

**Use in Paper:** Section 4 (Implementation / Technology Stack) — primary language citation

**Status:** ✅ PDF at `/Review of Literature/2015-cmj-chuck.pdf`

---

### 10.2 ChuGL: Unified Audiovisual Programming in ChucK (NIME 2024)
**Authors:** Andrew Zhu Aday, Ge Wang
**Venue:** International Conference on New Interfaces for Musical Expression (NIME)
**Year:** 2024
**Location:** Utrecht, The Netherlands
**BibTeX key:** aday2024chugl

**Summary:**
ChuGL extends ChucK with a 3D audiovisual programming framework. Introduces Graphics Generators (GGens) that parallel ChucK's Audio Unit Generators (UGens), enabling sample-synchronous audio-graphics manipulation within a single language. Uses a retained-mode scenegraph API with multithreaded synchronization for low-latency audiovisual coupling.

**Relevance to CHULOOPA:**
- **Visual feedback system:** CHULOOPA uses ChuGL for its sphere-based track state visualization (gray/red/green/blue) and real-time spice level display
- **Sample-synchronous updates:** ChuGL's strong timing aligns visual feedback precisely with drum playback
- **AIMC 2026 audience familiarity:** NIME audience knows ChuGL; important to cite

**Use in Paper:** Section 4 (Implementation) — visual feedback system citation

**Status:** ✅ PDF at `/Review of Literature/2024-nime-chugl.pdf`

---

### 10.3 SMART: Tuning a Symbolic Music Generation System with an Audio Domain Aesthetic Reward (AIMC 2025)
**Authors:** Nicolas Jonason, Luca Casini, Bob L.T. Sturm
**Venue:** Proceedings of the 6th Conference on AI Music Creativity (AIMC 2025)
**Year:** 2025
**Location:** Brussels, Belgium, September 10–12
**BibTeX key:** jonason2025smart

**Summary:**
SMART proposes reinforcement learning fine-tuning of symbolic music generation using Meta Audiobox Aesthetics as a reward signal. Uses group relative preference optimization (GRPO) to align symbolic piano MIDI generation with audio aesthetic preferences (content enjoyment, production quality). Shows that RL-based alignment improves content enjoyment ratings but can produce mode collapse with aggressive optimization.

**Relevance to CHULOOPA:**
- **Parameter-controlled variation creativity:** SMART demonstrates explicit user-facing control over generation quality through reward signals; CHULOOPA's "spice" parameter provides analogous real-time control over variation creativity
- **Diversity vs. quality tradeoff:** SMART's mode collapse findings directly inform CHULOOPA's design decision to vary post-processing (timing anchoring) rather than model temperature
- **Same venue (AIMC 2025):** Directly positions CHULOOPA within the AIMC research community

**Use in Paper:** Section 2.3 (AI Generation) — cite for controlled variation generation and diversity/quality tradeoffs

**Status:** ✅ PDF at `/Review of Literature/_SMART (7).pdf` and `aimc-2025/aimc-2025-music_97.pdf`

---

### 10.4 Conditional Generation of Bass Guitar Tablature for Guitar Accompaniment (AIMC 2025)
**Authors:** Olivier Anoufa, Alexandre D'Hooge, Ken Déguernel
**Venue:** Proceedings of the 6th Conference on AI Music Creativity (AIMC 2025)
**Year:** 2025
**Location:** Brussels, Belgium, September 10–12
**Affiliation:** Univ. Lille, CNRS, Centrale Lille, UMR 9189 CRIStAL
**BibTeX key:** anoufa2025bass

**Summary:**
Proposes a transformer-based decoder model for generating idiomatic bass guitar tablatures conditioned on rhythm guitar input. Uses the DadaGP dataset (100,000+ excerpts) with a BiLSTM encoder and transformer decoder architecture. Qualitative analysis shows the model captures harmonic/rhythmic consistency and natural hand movements, with some tendency to copy rhythm guitar too closely.

**Relevance to CHULOOPA:**
- **Conditional symbolic generation:** Both systems generate symbolic music (tablature / drum patterns) conditioned on musical input (guitar track / beatbox recording)
- **Accompaniment for solo performers:** Both address the solo musician's need for AI-generated accompaniment — guitar player needs bass, singer-songwriter needs drums
- **Transformer-LSTM architecture:** Parallel to rhythmic_creator's transformer-LSTM hybrid used in CHULOOPA
- **Idiomaticity and evaluation:** Shared focus on whether AI output "feels right" for the instrument/context

**Use in Paper:** Section 2.3 (AI Generation) — cite for conditional accompaniment generation; Section 6 (Discussion) — cite for comparison of input-conditioned symbolic generation

**Status:** ✅ PDF at `/Review of Literature/Bass_AIMC-6.pdf` and `aimc-2025/AIMC_2025_paper_38.pdf`

---

### 10.5 AI-Assisted Sound Design with Audio Metaphor (AuMe): An Evaluation with Novice Sound Designers (AIMC 2025)
**Authors:** Ge Liu, Keon Ju Lee, Miles Thorogood, Christopher Anderson, Philippe Pasquier
**Venue:** Proceedings of the 6th Conference on AI Music Creativity (AIMC 2025)
**Year:** 2025
**Location:** Brussels, Belgium, September 10–12
**BibTeX key:** liu2025aime

**Summary:**
Evaluates AuMe, an AI-assisted sound design tool, with 71 novice undergraduate sound designers. AuMe uses audio metaphors for sound retrieval. Results show it significantly reduces sourcing/editing time (21.83%) but introduces challenges around creative ownership, system trust, and interpretation gaps. Highlights the tension between AI assistance and pedagogical value in creative education.

**Relevance to CHULOOPA:**
- **Accessible AI for non-experts:** Both target users without technical expertise (novice sound designers / amateur beatboxers); findings on usability barriers directly inform CHULOOPA's UX design
- **Creative ownership:** AuMe's finding that AI assistance raises creative authorship concerns mirrors CHULOOPA's "artist in the loop" design philosophy — keeping the performer central to creative output
- **User experience challenges:** Unexpected AI outputs, interpretation gaps, and trust issues documented in AuMe contextualize CHULOOPA's design decisions (e.g., spice control, visual feedback, offline-first)
- **Same venue:** AIMC 2025 community context

**Use in Paper:** Section 2.4 (Co-Creative AI) — cite for accessible AI design findings and creative ownership discourse

**Status:** ✅ PDF at `/Review of Literature/AuMe_Study_CameraReady.pdf`

---

### 10.6 Revival: Artistic Collaboration and Improvisation between Humans and AI in Music and Visual (AIMC 2025)
**Authors:** Keon Ju Maverick Lee, Philippe Pasquier, Jun Yuri
**Venue:** Proceedings of the 6th Conference on AI Music Creativity (AIMC 2025)
**Year:** 2025
**Location:** Brussels, Belgium, September 10–12
**Affiliation:** Simon Fraser University / Metacreation Lab for Creative AI
**BibTeX key:** lee2025revival

**Summary:**
Presents Revival, a live audiovisual performance by artist collective K-Phi-A combining human percussion, live electronics, and AI musical agents (MACAT and MACataRT). AI agents trained on small curated corpora respond expressively to live input, emulating sophisticated musical styles in real-time. Emphasizes a "small data mindset" — ethical, transparent, artist-specific training datasets — alongside an AI-powered visual synthesizer (Autolume). Uses OSC messaging for real-time audio-visual coordination.

**Relevance to CHULOOPA:**
- **"Small data mindset":** Lee et al. explicitly advocate for small, curated, artist-specific training data over large-scale scraping — directly validating CHULOOPA's "personalization-over-scale" approach with 30 user-specific samples
- **Real-time co-creative performance:** Both systems position AI as responsive collaborator in live performance, with human performers retaining creative agency
- **OSC communication:** Revival uses OSC for system coordination, same as CHULOOPA's Python-ChucK bridge
- **AIMC community:** SFU Metacreation Lab is a central voice in AIMC; this paper directly contextualizes CHULOOPA within the same discourse

**Use in Paper:** Section 2.4 (Co-Creative AI) — **KEY** citation; validates small-data mindset and real-time AI collaboration from within AIMC community

**Note:** This is a DIFFERENT paper from `martin2021revival` (Martin & Bell, NIME 2021) which is already cited. Both share the name "Revival" but are distinct works.

**Status:** ✅ PDF at `aimc-2025/aimc-2025-music_23.pdf`

---

### 10.7 A Short Review of Responsible AI Music Generation (AIMC 2025)
**Authors:** Elizabeth Wilson, Anna Wszeborowska, Nick Bryan-Kinns
**Venue:** Proceedings of the 6th Conference on AI Music Creativity (AIMC 2025)
**Year:** 2025
**Location:** Brussels, Belgium, September 10–12
**Affiliation:** Creative Computing Institute, University of the Arts London
**BibTeX key:** wilson2025responsible

**Summary:**
Surveys 27 contemporary AI models for music generation through the lens of Responsible AI principles: transparency & explainability, fairness, accountability, and ethical AI. Finds that AI music tools lack transparency in model training, insufficient openness in source code and datasets, and predominantly focus on audio generation at the expense of real-time, performance-oriented systems. Argues that research is needed on evaluating AI music tools through user journeys that expose mechanics, limitations, and ethical considerations.

**Relevance to CHULOOPA:**
- **Responsible AI framing:** CHULOOPA's offline-first architecture (local inference, no cloud API), user-trainable model (user owns their training data), and interpretable KNN classifier directly address Wilson et al.'s identified gaps in transparency and accountability
- **Real-time music generation gap:** Wilson et al. identify a lack of focus on real-time generation for performance and improvisation — CHULOOPA addresses this gap directly
- **User journey evaluation:** Their call for user-journey-based evaluation supports CHULOOPA's autoethnographic and user-testing methodology

**Use in Paper:** Section 2.4 (Co-Creative AI) or Introduction — positions CHULOOPA's design decisions within responsible AI discourse; Section 6 (Discussion) — cite for ethical and transparent AI design

**Status:** ✅ PDF at `aimc-2025/AIMC_2025_paper_28.pdf`

---

## 10. Citation Strategy for NIME Paper

### Critical Citations (Must Include):

1. **Living Looper (NIME 2023)** - Related NIME work, looping systems
2. **ASCIML (NIME 2023)** - Personalized ML for music
3. **Amateur Vocal Percussion Dataset (2019)** - Beatbox recognition baseline
4. **LoopGen (2025)** - Training-free vs. personalized approaches
5. **Magenta GrooVAE** - Explain why CHULOOPA uses Gemini instead

### Important Citations (Should Include):

6. **GrooveTransformer (NIME 2024)** - Recent drum generation work
7. **dB Drummer Bot (NIME 2024)** - Alternative drum input interface
8. **Notochord (AIMC 2022)** - Real-time music AI
9. **Beatbox Classification Using ACE** - Generic beatbox classification
10. **Real-Time Beatbox Classification (2010)** - Real-time constraints

### Optional Citations (Space Permitting):

11. **Bishop BoomBox (NIME 2024)** - Accessibility theme
12. **AI Harmonizer (NIME 2025)** - Vocal+AI augmentation
13. **Query-by-Beat-Boxing** - Beatbox as interface
14. **Real-Time Co-Creation (NIME 2023)** - Human-AI collaboration

---

## 11. Summary of NIME 2022-2024 Relevant Papers

### NIME 2023:
- **The Living Looper** (Shepardson, Magnusson) - Neural looping system
- **ASCIML** - Interactive ML for sound generation
- **Real-Time Co-Creation** - Human-AI expressive performance

### NIME 2024:
- **GrooveTransformer** (Haki, Evans, Jordà) - Generative drum sequencer
- **dB Drummer Bot** (Erdem, Griwodz) - Web-based finger-tapping drummer
- **Bishop BoomBox** (May, McLeod, Mulshine) - Accessible drum machine
- **Building NIMEs with Embedded AI Workshop** (Martin et al.) - ML integration workshop

### NIME 2025:
- **AI Harmonizer** - Vocal expression with generative AI

---

## 12. Sources for Further Literature Review

### NIME Proceedings Archives:
- **NIME PubPub:** https://nime.pubpub.org/
- **NIME 2022 Papers:** https://nime.pubpub.org/nime-2022-papers
- **NIME 2023:** https://www.nime2023.org/
- **NIME 2024:** https://nime2024.org/

### Key Search Terms for More Papers:
- "beatbox recognition"
- "vocal percussion classification"
- "personalized music ML"
- "few-shot learning music"
- "real-time music AI"
- "loop generation"
- "timing preservation music AI"
- "accessible music interfaces"
- "drum pattern generation"
- "human-AI music collaboration"

### Related Conferences:
- **ISMIR** (Music Information Retrieval) - ML for music
- **ICMC** (Computer Music Conference) - Music technology
- **SMC** (Sound and Music Computing) - Audio/music computing
- **CHI** (Human-Computer Interaction) - Accessible interfaces

---

## 13. Action Items for Paper Writing

### Immediate (While in NYC, Jan 27-29):
- [ ] Read PDFs in `/Review of Literature/` folder
- [ ] Extract titles/summaries from cryptic arXiv papers
- [ ] Verify citations for all papers listed above
- [ ] Search Google Scholar for "beatbox classification" papers
- [ ] Search NIME proceedings for additional relevant work
- [ ] Draft Related Work section (2.1-2.5)

### When Back Home (Jan 30+):
- [ ] Finalize citations with proper formatting
- [ ] Create comparison table (CHULOOPA vs. related systems)
- [ ] Write gap analysis (Section 2.5)
- [ ] Ensure all critical citations are included

---

## 8. ChucK, ChuGL, and Music Programming Languages

### 8.1 ChucK: A Strongly Timed Computer Music Language (2015)
**Authors:** Ge Wang, Perry R. Cook, Spencer Salazar
**Venue:** Computer Music Journal 39:4
**DOI:** 10.1162/COMJ_a_00324
**URL:** https://www.researchgate.net/publication/250140958_Designing_and_Implementing_the_ChucK_Programming_Language

**Summary:**
ChucK is a strongly timed, concurrent audio programming language for real-time synthesis, composition, and performance. Created at Princeton University in the early 2000s, ChucK enables live coding with on-the-fly addition, removal, and modification of code while programs run.

**Relevance to CHULOOPA:**
- **Foundation:** CHULOOPA is built entirely in ChucK
- **Real-time capability:** ChucK's strongly-timed model enables <50ms latency
- **Unit generators:** CHULOOPA uses ChucK's UGen architecture for audio processing

**Use in Paper:** Section 4 (Implementation) - cite as implementation platform

---

### 8.2 ChucK: A Concurrent, On-the-fly Audio Programming Language (NIME 2004)
**Authors:** Ge Wang, Perry R. Cook
**Venue:** NIME 2004
**URL:** https://soundlab.cs.princeton.edu/publications/chuck_sigmm2004.pdf

**Summary:**
Introduces ChucK's concurrent programming model and on-the-fly capabilities for real-time audio.

**Relevance to CHULOOPA:**
- **NIME publication:** Establishes ChucK's acceptance in NIME community
- **Real-time focus:** Validates ChucK for live performance applications

**Use in Paper:** Section 4 (Implementation)

---

### 8.3 ChuGL: Unified Audiovisual Programming in ChucK (NIME 2024)
**Authors:** Andrew Zhu Aday, Ge Wang
**Venue:** NIME 2024
**URL:** https://nime.org/proc/nime2024_52/
**PDF:** https://mcd.stanford.edu/publish/files/2024-nime-chugl.pdf

**Summary:**
ChuGL extends ChucK's strongly-timed programming model with a 3D rendering engine, introducing Graphics Generators (GGen) that can be manipulated sample-synchronously alongside audio UGens. Uses multithreaded scenegraph architecture for low-latency, high-performance audiovisual synchronization.

**Relevance to CHULOOPA:**
- **Visualization:** CHULOOPA uses ChuGL for real-time visual feedback
- **NIME 2024:** Very recent publication, shows ChucK's continued development
- **Future work:** Plans to significantly improve ChuGL visualizations

**Use in Paper:** Section 4 (Implementation) - cite for visualization layer
Section 7 (Future Work) - reference for improved visuals

---

### 8.4 Programming for Musicians and Digital Artists: Creating music with ChucK (2015)
**Authors:** Ajay Kapur, Perry R. Cook, Spencer Salazar, Ge Wang
**Venue:** Manning Publications
**URL:** https://www.manning.com/books/programming-for-musicians-and-digital-artists

**Summary:**
Comprehensive textbook on ChucK programming for music creation, authored by Paolo's advisor Ajay Kapur and ChucK creators.

**Relevance to CHULOOPA:**
- **Educational resource:** Informed CHULOOPA's development
- **Advisor connection:** Ajay Kapur is Paolo's thesis advisor at CalArts

**Use in Paper:** Acknowledgments - cite Ajay Kapur as advisor

---

### 8.5 The Synthesis Toolkit (STK)
**Authors:** Perry R. Cook, Gary P. Scavone
**Venue:** ICMC 1999
**URL:** https://github.com/thestk/stk

**Summary:**
Open-source audio signal processing and algorithmic synthesis library in C++, integrated into ChucK for instrument synthesis.

**Relevance to CHULOOPA:**
- **STK instruments:** CHULOOPA uses STK-based drum samples
- **Foundation:** Underlying synthesis framework for ChucK

**Use in Paper:** Section 4 (Implementation) - mention STK integration

---

## 9. Transformer-Based Drum Generation

### 9.1 Transformer Neural Networks for Automated Rhythm Generation
**Authors:** [Authors TBD - ResearchGate]
**Venue:** [Conference TBD]
**URL:** https://www.researchgate.net/publication/353365175_Transformer_Neural_Networks_for_Automated_Rhythm_Generation

**Summary:**
Applies Transformer neural networks to automated rhythm generation, capturing long-term dependencies in drum patterns.

**Relevance to CHULOOPA:**
- **Future work:** Potential alternative to Gemini for variation generation
- **Transformer architecture:** State-of-the-art approach for sequence generation

**Use in Paper:** Section 7 (Future Work) - cite as potential variation method

---

### 9.2 Tap2Drum with Transformer Neural Networks (2021)
**Authors:** [Authors TBD]
**Venue:** [Venue TBD]
**URL:** https://zenodo.org/records/5554741

**Summary:**
Master thesis implementing Transformer Neural Network for Tap2Drum beat generation, transforming tapped patterns into full-fledged drum beats.

**Relevance to CHULOOPA:**
- **Similar input method:** Tap-to-drum vs. beatbox-to-drum
- **Transformer approach:** Alternative ML architecture to CHULOOPA's KNN+LLM

**Use in Paper:** Section 2.1 (Beatbox Recognition) - cite as alternative input transformation method

---

### 9.3 Towards Human-Quality Drum Accompaniment Using Deep Generative Models and Transformers
**Authors:** [Authors TBD - Springer]
**Venue:** Springer 2024
**URL:** https://link.springer.com/chapter/10.1007/978-3-031-90167-6_12

**Summary:**
Explores deep generative models and transformers for creating human-quality drum accompaniment.

**Relevance to CHULOOPA:**
- **Accompaniment focus:** Shares goal of creating drum parts for musicians
- **Quality benchmark:** "Human-quality" aligns with CHULOOPA's timing preservation goal

**Use in Paper:** Section 2.3 (AI Generation) - cite for quality comparison

---

### 9.4 The Rhythm In Anything (TRIA): Audio-Prompted Drums Generation with Masked Language Modeling (2024)
**Authors:** [Authors TBD]
**Venue:** arXiv 2024
**URL:** https://arxiv.org/html/2509.15625

**Summary:**
Masked transformer model for mapping rhythmic sound gestures to high-fidelity drum recordings, producing audio of drumkit playing desired rhythms.

**Relevance to CHULOOPA:**
- **Audio-to-drums:** Similar goal but different approach (audio input vs. beatbox classification)
- **Recent work:** Shows active research in drum generation (2024)

**Use in Paper:** Section 2.3 (AI Generation) - cite as related drum generation work

---

## 10. Few-Shot and Personalized Machine Learning

### 10.1 Prototypical Contrastive Learning for Improved Few-Shot Audio Classification (2024)
**Authors:** [Authors TBD]
**Venue:** arXiv 2024
**URL:** https://arxiv.org/html/2509.10074v1

**Summary:**
Proposes prototypical contrastive learning for few-shot audio classification, achieving state-of-the-art on MetaAudio benchmark with 5-way 5-shot classification.

**Relevance to CHULOOPA:**
- **Few-shot learning:** CHULOOPA uses 10 samples per class (similar to 5-shot paradigm)
- **Comparison:** Prototypical networks vs. CHULOOPA's simple KNN

**Use in Paper:** Section 2.2 (Personalized ML) - cite for few-shot learning approaches

---

### 10.2 Few-Shot Continual Learning for Audio Classification (ICASSP 2021)
**Authors:** [Authors TBD - Stanford CCRMA]
**Venue:** ICASSP 2021
**URL:** https://ccrma.stanford.edu/~njb/research/icassp2021_continualFSL.pdf

**Summary:**
Explores few-shot continual learning for audio, where models adapt to new classes with minimal samples.

**Relevance to CHULOOPA:**
- **Continual learning:** Users could retrain CHULOOPA with more samples over time
- **Few-shot paradigm:** Validates minimal training data approach

**Use in Paper:** Section 2.2 (Personalized ML)

---

### 10.3 PALM: Few-Shot Prompt Learning for Audio Language Models (2024)
**Authors:** [Authors TBD]
**Venue:** [Conference 2024]
**URL:** https://asif-hanif.github.io/palm/

**Summary:**
Demonstrates few-shot prompt learning for audio-language models across 11 audio recognition datasets, outperforming other approaches while being computationally efficient.

**Relevance to CHULOOPA:**
- **Few-shot audio:** Validates minimal training data for audio tasks
- **Language models:** Similar to CHULOOPA's use of Gemini LLM

**Use in Paper:** Section 2.2 (Personalized ML) - cite for LLM+audio few-shot learning

---

## 11. Onset Detection and Spectral Analysis

### 11.1 Musical Note Onset Detection Based on a Spectral Sparsity Measure (2021)
**Authors:** [Authors TBD]
**Venue:** EURASIP Journal on Audio, Speech, and Music Processing (2021)
**URL:** https://asmp-eurasipjournals.springeropen.com/articles/10.1186/s13636-021-00214-7

**Summary:**
Proposes onset detection based on spectral sparsity measure, achieving improved performance over traditional spectral flux methods.

**Relevance to CHULOOPA:**
- **Onset detection:** CHULOOPA uses spectral flux; this presents alternative
- **Comparison baseline:** Validates choice of spectral flux approach

**Use in Paper:** Section 2.1 (Beatbox Recognition) - cite for onset detection methods

---

### 11.2 Influence of Adaptive Thresholding on Peaks Detection in Audio Data (2020)
**Authors:** [Authors TBD]
**Venue:** Multimedia Tools and Applications (2020)
**URL:** https://link.springer.com/article/10.1007/s11042-020-08780-2

**Summary:**
Experimental assessment of adaptive thresholding functions for peak detection in audio, comparing fixed vs. adaptive approaches.

**Relevance to CHULOOPA:**
- **Adaptive thresholding:** CHULOOPA uses 1.5× running mean approach
- **Peak picking:** Critical for onset detection accuracy

**Use in Paper:** Section 3.2.1 (Onset Detection) - cite for adaptive thresholding validation

---

### 11.3 Adaptive Whitening for Improved Real-Time Audio Onset Detection
**Authors:** [Authors TBD - ResearchGate]
**Venue:** [Conference TBD]
**URL:** https://www.researchgate.net/publication/250824858_Adaptive_whitening_for_improved_real-time_audio_onset_detection

**Summary:**
Shows that adaptive whitening significantly improves performance of STFT-based onset detection functions including spectral flux.

**Relevance to CHULOOPA:**
- **Real-time focus:** Shares latency constraints
- **Spectral flux improvement:** Potential enhancement to CHULOOPA's approach

**Use in Paper:** Section 7 (Future Work) - cite as potential improvement

---

## 12. LLM-Based Music Generation

### 12.1 ChatMusician: Understanding and Generating Music Intrinsically with LLM (2024)
**Authors:** [Authors TBD]
**Venue:** ACL 2024 Findings
**URL:** https://arxiv.org/abs/2402.16153

**Summary:**
Open-source LLM with intrinsic musical abilities, based on continual pre-training LLaMA2 on ABC notation. Capable of composing full-length music conditioned on texts, chords, melodies, musical forms.

**Relevance to CHULOOPA:**
- **LLM for music:** Validates CHULOOPA's use of Gemini for musical tasks
- **Symbolic representation:** Both use symbolic music formats (ABC vs. CSV)

**Use in Paper:** Section 2.3 (AI Generation) - cite for LLM music generation

---

### 12.2 SongComposer: Large Language Model for Lyric and Melody Generation (2024)
**Authors:** Ding et al.
**Venue:** arXiv 2024
**File:** `/Review of Literature/2025 - SongComposer - Ding et al.pdf`
**URL:** https://arxiv.org/abs/2402.17645

**Summary:**
Addresses rhythm preservation through extended tokenizer vocabulary for song notes with scalar initialization based on musical knowledge. Multi-stage pipeline captures musical structure from motif-level to phrase-level.

**Relevance to CHULOOPA:**
- **Rhythm preservation:** Similar goal to CHULOOPA's timing preservation
- **Musical structure:** Multi-stage pipeline vs. CHULOOPA's single-pass approach

**Use in Paper:** Section 2.3 (AI Generation) - cite for rhythm preservation in LLMs

---

### 12.3 MIDI-LLM: Adapting Large Language Models for Text-to-MIDI Music Generation (2024)
**Authors:** [Authors TBD]
**Venue:** arXiv 2024
**URL:** https://arxiv.org/html/2511.03942v1

**Summary:**
Uses arrival-time MIDI-like tokenization from Anticipatory Music Transformer (AMT) with 10ms quantization for onset time and note duration, offering flexibility without requiring beat-synchronized data.

**Relevance to CHULOOPA:**
- **Timing precision:** 10ms quantization vs. CHULOOPA's non-quantized approach
- **MIDI representation:** Alternative symbolic format to CHULOOPA's delta-time CSV

**Use in Paper:** Section 2.3 (AI Generation) - cite for timing representation approaches

---

## 13. Voice-Based Music Interfaces

### 13.1 Voice at NIME: A Taxonomy of New Interfaces for Vocal Musical Expression (NIME 2022)
**Authors:** [Authors TBD]
**Venue:** NIME 2022
**URL:** https://nime.pubpub.org/pub/180al5zt/
**Interactive Tool:** https://nimevoice2022.vercel.app/

**Summary:**
Systematic review of voice-centered NIME publications from past two decades. Presents taxonomy and classification system for vocal NIMEs with interactive web-based exploration tool.

**Relevance to CHULOOPA:**
- **CRITICAL CITATION:** Establishes voice as legitimate NIME interface
- **Taxonomy:** Where does beatbox-to-drum fit in vocal interface classification?
- **NIME precedent:** Validates vocal input for musical interfaces

**Use in Paper:** Section 2.1 (Beatbox Recognition) - CRITICAL cite for vocal interfaces at NIME

---

### 13.2 VocalCords: Exploring Tactile Interaction and Performance with the Singing Voice (NIME 2024)
**Authors:** [Authors TBD]
**Venue:** NIME 2024
**URL:** https://nime.org/proc/nime2024_82/

**Summary:**
Digital music interface using physical rubber cords as stretch sensors, manipulated by singers while vocalizing to augment voice in real-time.

**Relevance to CHULOOPA:**
- **Voice augmentation:** Both systems augment vocal performance
- **Real-time:** Shares live performance focus

**Use in Paper:** Section 2.4 (Live Performance) - cite as related vocal interface

---

## 14. K-Nearest Neighbors for Audio

### 14.1 Music Genre Classification Using K-Nearest Neighbor and Mel-Frequency Cepstral Coefficients
**Authors:** [Authors TBD]
**Venue:** ResearchGate 2024
**URL:** https://www.researchgate.net/publication/379458563_Music_Genre_Classification_Using_K-Nearest_Neighbor_and_Mel-Frequency_Cepstral_Coefficients

**Summary:**
Achieves 91% accuracy for music genre classification using KNN with MFCC features on GTZAN dataset.

**Relevance to CHULOOPA:**
- **KNN validation:** Shows KNN works well for audio classification
- **Accuracy benchmark:** CHULOOPA's ~90% accuracy aligns with KNN state-of-the-art
- **Feature choice:** MFCC vs. CHULOOPA's flux/energy/band features

**Use in Paper:** Section 3.2.3 (KNN Classification) - cite as KNN baseline for audio

---

## 15. Google Magenta and GrooVAE

### 15.1 GrooVAE: Generating and Controlling Expressive Drum Performances (ICML)
**Authors:** Gillick et al. (Google Magenta)
**Venue:** ICML
**URL:** https://magenta.withgoogle.com/groovae
**GitHub:** https://github.com/magenta/magenta

**Summary:**
Recurrent Variational Autoencoder for generating expressive drum performances. Trained on 13.6 hours of recordings from professional drummers on Roland TD-11. Introduced Groove MIDI Dataset.

**Relevance to CHULOOPA:**
- **CRITICAL:** Explain why CHULOOPA uses Gemini instead of GrooVAE
- **Piano roll limitation:** GrooVAE requires quantized piano roll format
- **CHULOOPA advantage:** Non-quantized timing preservation

**Use in Paper:** Section 2.3 (AI Generation) - CRITICAL discussion of GrooVAE limitations
Section 6 (Discussion) - honest assessment of why Gemini was chosen

---

## 16. Ajay Kapur's Publications (Thesis Advisor)

### 16.1 The Machine Orchestra: An Ensemble of Human Laptop Performers and Robotic Musical Instruments
**Authors:** Ajay Kapur, Michael Darling et al.
**Venue:** [Conference TBD]
**URL:** https://www.researchgate.net/publication/220386587_The_Machine_Orchestra_An_Ensemble_of_Human_Laptop_Performers_and_Robotic_Musical_Instruments

**Summary:**
Mixed ensemble of human and robotic performers at CalArts. Seven electromechanical instruments developed by members. Focuses on combining laptop orchestra with robotic ensemble.

**Relevance to CHULOOPA:**
- **Advisor's work:** Ajay Kapur is Paolo's thesis advisor
- **CalArts context:** Developed at same institution as CHULOOPA
- **Human-machine collaboration:** Similar theme of human+AI performance

**Use in Paper:** Introduction - mention advisor's work in human-machine music
Acknowledgments - cite Ajay Kapur as advisor

---

### 16.2 A History of Robotic Musical Instruments (ICMC 2005)
**Authors:** Ajay Kapur
**Venue:** ICMC 2005
**URL:** https://www.mistic.ece.uvic.ca/publications/2005_icmc_robot.pdf

**Summary:**
Comprehensive history of robotic musical instruments, providing context for mechatronic music creation.

**Relevance to CHULOOPA:**
- **Historical context:** Situates CHULOOPA in tradition of automated music-making
- **Advisor's expertise:** Establishes advisor's background in music robotics

**Use in Paper:** Introduction - optional historical context

---

## 17. Mobile Music and Expressive Interfaces

### 17.1 Designing Smule's Ocarina: The iPhone's Magic Flute (NIME 2009)
**Authors:** Ge Wang
**Venue:** NIME 2009
**URL:** https://nime.org/proc/wang2009/
**Full Article:** Computer Music Journal 38(2):8-21 (2014)

**Summary:**
Wind instrument for iPhone leveraging microphone (breath), multitouch (fingering), accelerometer, GPS/location. One of first mobile/social musical instruments with real-time visualization of global players.

**Relevance to CHULOOPA:**
- **Breath input:** Similar to beatbox input (vocal/breath interface)
- **Mobile/accessible:** Shares goal of accessible music creation
- **NIME precedent:** Validates alternative input methods

**Use in Paper:** Section 2.4 (Live Performance) - cite for alternative input interfaces

---

## 18. Accessible Music Interfaces

### 18.1 Accessible Digital Musical Instruments - A Survey of Inclusive Instruments (NIME/SMC/ICMC Review)
**Authors:** Emma Frid
**Venue:** Multimodal Technologies and Interaction (2019)
**URL:** https://www.mdpi.com/2414-4088/3/3/57

**Summary:**
Systematic review of 113 publications on Accessible Digital Musical Instruments (ADMIs). Identifies 10 control interface types including tangible controllers, BCMIs, adapted instruments, wearables, mouth-operated controllers.

**Relevance to CHULOOPA:**
- **Accessibility theme:** CHULOOPA makes drum programming accessible
- **Interface taxonomy:** Beatbox as mouth-operated controller
- **Design philosophy:** Accessibility through personalization

**Use in Paper:** Section 1 (Introduction) - cite for accessibility motivation
Section 6 (Discussion) - accessibility as design principle

---

### 18.2 Reimagining (Accessible) Digital Musical Instruments: A Survey on Electronic Music-Making Tools (NIME 2021)
**Authors:** [Authors TBD]
**Venue:** NIME 2021
**URL:** https://nime.pubpub.org/pub/reimaginingadmis

**Summary:**
Survey of electronic music-making tools with focus on accessibility. NIME 2020 theme was "Accessibility of Musical Expression."

**Relevance to CHULOOPA:**
- **NIME accessibility theme:** Validates CHULOOPA's accessibility focus
- **Recent work:** Shows continued NIME emphasis on accessibility

**Use in Paper:** Section 1 (Introduction) - cite for accessibility context

---

## 19. User Experience Evaluation in Music Technology

### 19.1 A User Experience Review of Music Interaction Evaluations (NIME 2017)
**Authors:** Brown, Nash
**Venue:** NIME 2017
**URL:** https://www.nime.org/proceedings/2017/nime2017_paper0070.pdf

**Summary:**
Meta-review of 132 papers from NIME/SMC/ICMC 2014-2016. Found usability and aesthetics are primary evaluation focus, while enchantment, motivation, frustration often overlooked. Shift toward experience-focused over task-focused evaluations.

**Relevance to CHULOOPA:**
- **Evaluation methodology:** Guides CHULOOPA's user study design
- **Experience vs. task:** Informs autoethnographic approach

**Use in Paper:** Section 5 (Evaluation) - cite for evaluation methodology

---

### 19.2 Musical Instruments for Novices: Comparing NIME, HCI and Crowdfunding Approaches (2019)
**Authors:** [Authors TBD]
**Venue:** [Conference 2019]
**URL:** https://www.researchgate.net/publication/330921603_Musical_Instruments_for_Novices_Comparing_NIME_HCI_and_Crowdfunding_Approaches_Methods_and_Protocols

**Summary:**
Compares approaches to designing musical instruments for novices across NIME, HCI, and crowdfunding platforms.

**Relevance to CHULOOPA:**
- **Novice focus:** CHULOOPA targets amateur beatboxers
- **Design comparison:** Situates CHULOOPA in novice instrument design tradition

**Use in Paper:** Section 1 (Introduction) - cite for novice-focused design

---

## 20. CURRENT PAPER COUNT: 50+ Papers

---

## 21. Summary Table: 30+ Core Papers for Citation

| # | Paper | Venue | Year | Use in Paper |
|---|-------|-------|------|--------------|
| 1 | Amateur Vocal Percussion Dataset | ACM Audio Mostly | 2019 | Section 2.1 (Beatbox) |
| 2 | Living Looper | NIME | 2023 | Section 2.4 (Looping) - CRITICAL |
| 3 | ASCIML (Interactive ML for Sound) | NIME | 2023 | Section 2.2 (Personalized ML) - CRITICAL |
| 4 | GrooveTransformer | NIME | 2024 | Section 2.3 (AI Generation) |
| 5 | ChuGL: Unified Audiovisual Programming | NIME | 2024 | Section 4 (Implementation) |
| 6 | Voice at NIME: Taxonomy | NIME | 2022 | Section 2.1 (Beatbox) - CRITICAL |
| 7 | ChucK: Strongly Timed Language | CMJ | 2015 | Section 4 (Implementation) |
| 8 | GrooVAE | ICML | 2019 | Section 2.3, 6 (Discussion) - CRITICAL |
| 9 | LoopGen | arXiv | 2025 | Section 2.2, 2.3 |
| 10 | Notochord | AIMC | 2022 | Section 2.5 (Real-time) |
| 11 | ChatMusician | ACL | 2024 | Section 2.3 (LLM) |
| 12 | SongComposer | arXiv | 2024 | Section 2.3 (Rhythm preservation) |
| 13 | Few-Shot Audio Classification (Prototypical) | arXiv | 2024 | Section 2.2 (Few-shot) |
| 14 | Beatbox Classification Using ACE | [Venue] | [Year] | Section 2.1 (Beatbox) |
| 15 | Delayed Decision Real-Time Beatbox | JNMR | 2010 | Section 2.1 (Real-time beatbox) |
| 16 | Spectral Sparsity Onset Detection | EURASIP | 2021 | Section 3.2.1 (Onset) |
| 17 | Adaptive Thresholding Audio Peaks | MTA | 2020 | Section 3.2.1 (Onset) |
| 18 | Transformer Rhythm Generation | [Venue] | [Year] | Section 7 (Future) |
| 19 | MIDI-LLM | arXiv | 2024 | Section 2.3 (LLM) |
| 20 | VocalCords | NIME | 2024 | Section 2.4 (Vocal interfaces) |
| 21 | Accessible DMIs Survey (Frid) | MTI | 2019 | Section 1 (Accessibility) |
| 22 | UX Review Music Interaction | NIME | 2017 | Section 5 (Evaluation) |
| 23 | KNN Music Genre with MFCC | [Venue] | 2024 | Section 3.2.3 (KNN) |
| 24 | Machine Orchestra | [Venue] | [Year] | Introduction (Advisor work) |
| 25 | Ocarina iPhone | NIME | 2009 | Section 2.4 (Mobile) |
| 26 | Real-Time Co-Creation | NIME | 2023 | Section 2.3 (Human-AI) |
| 27 | dB Drummer Bot | NIME | 2024 | Section 2.4 (Drum interfaces) |
| 28 | Bishop BoomBox | NIME | 2024 | Section 2.4 (Accessibility) |
| 29 | Tap2Drum Transformer | Zenodo | 2021 | Section 2.1 (Input transformation) |
| 30 | STK Synthesis Toolkit | ICMC | 1999 | Section 4 (Implementation) |
| 31 | PALM Few-Shot Audio-Language | [Venue] | 2024 | Section 2.2 (Few-shot LLM) |
| 32 | Programming for Musicians (Kapur et al.) | Manning | 2015 | Acknowledgments |

---

## 22. Key Arguments for Related Work Section

### Main Narrative:

1. **Beatbox recognition exists but targets professionals or uses generic datasets**
   → CHULOOPA personalizes for amateurs

2. **Personalized ML for music exists but not for real-time performance**
   → CHULOOPA combines personalization + real-time + live looping

3. **AI music generation exists but quantizes to grids**
   → CHULOOPA preserves non-quantized timing through LLM constraints

4. **Live looping systems exist but don't do transcription + AI variation**
   → CHULOOPA provides complete pipeline: input → transcribe → loop → vary

5. **No system makes drum programming accessible to "shitty drummers"**
   → CHULOOPA fills this gap through personalized beatbox interface

---

**End of RRL Document**

**TOTAL PAPERS: 50+ identified, 32 core papers for citation**

*This document will be updated as more papers are reviewed and citations are finalized.*
