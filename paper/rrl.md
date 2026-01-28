# Related Research Literature (RRL) for CHULOOPA NIME 2026 Paper

This document summarizes all relevant research papers, projects, and literature for the CHULOOPA paper's Related Work section.

**Last Updated:** January 27, 2026
**Paper Target:** NIME 2026 (Abstract: Feb 5, Full Paper: Feb 12)

---

## Table of Contents

1. [Beatbox Recognition & Vocal Percussion](#1-beatbox-recognition--vocal-percussion)
2. [Live Looping Systems](#2-live-looping-systems)
3. [Personalized & Interactive Machine Learning for Music](#3-personalized--interactive-machine-learning-for-music)
4. [AI Music Generation & Variation](#4-ai-music-generation--variation)
5. [Real-Time Music Performance Systems](#5-real-time-music-performance-systems)
6. [Audio Transcription & Analysis](#6-audio-transcription--analysis)
7. [Related Projects in Codebase](#7-related-projects-in-codebase)

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
