# AIMC 2026 Paper Evaluation Rubric for CHULOOPA

**Conference:** AI Music Creativity 2026 (September 16, 2026)
**Theme:** TBD
**Paper Title (Working):** "Personal Drum Machines: User-Trainable Beatbox Classification with Real-Time AI Variations for Live Performance"

## Official AIMC Review Criteria

Based on [AIMC 2026 Review Process](https://aimc2026.org/call-for-submissions/review-process), papers are evaluated on:

1. Relevance to AIMC community and grounding in relevant literature
2. Originality or novelty of the submission
3. Artistic/scientific/theoretical quality
4. Readability and organisation
5. Appropriate use of methodology and reasonableness of claims
6. Ethical standards
7. Relationship to the conference theme

**Scoring Scale:** 1 (strong reject) to 5 (strong accept)
**Reviews per Paper:** Minimum 3 reviews
**Note:** AIMC welcomes practice-based approaches with no formal expectation for quantitative user results

---

## Detailed Rubric by Criterion

### 1. Relevance to AIMC Community & Grounding in Literature (Weight: 20%)

| Score | Criteria | CHULOOPA Context |
|-------|----------|------------------|
| **5** | Paper addresses core AIMC themes (AI + music creation/performance) with comprehensive literature review covering AI music, HCI, live coding, machine listening, beatboxing research | ✓ Check coverage of: Magenta, GrooVAE, live coding (TidalCycles, etc.), beatbox transcription, KNN classification in audio, real-time interaction, co-creative systems |
| **4** | Strong relevance with good literature coverage; minor gaps in related work | ✓ Missing 1-2 key related systems but covers main areas |
| **3** | Clearly relevant but literature review has noticeable gaps or lacks depth | ⚠ Need to verify: drum machine learning literature, user-trainable models, variation generation |
| **2** | Tangentially relevant; literature review is superficial or outdated | ⚠ Only cites basic ML papers, misses music-specific work |
| **1** | Poor fit for AIMC; inadequate engagement with relevant literature | ✗ Doesn't connect to AI music creativity discourse |

**Self-Assessment Questions:**
- [ ] Do we cite key AI music generation papers (Magenta, Notochord, GrooVAE, etc.)?
- [ ] Do we reference beatbox transcription/classification work?
- [ ] Do we situate CHULOOPA in live performance/co-creative AI literature?
- [ ] Do we acknowledge user-trainable/personalized ML systems?
- [ ] Do we cite real-time music AI systems (notochord, RAVE, live coding)?

**Target Score:** 4-5

---

### 2. Originality/Novelty (Weight: 25%)

| Score | Criteria | CHULOOPA Strengths |
|-------|----------|-------------------|
| **5** | Multiple significant novel contributions; clear advance over state-of-the-art | ✓ **Novel combo:** User-trainable (10 samples) + real-time (<50ms) + AI variation + live performance focus + OSC integration |
| **4** | Clear novelty in at least 2 areas; meaningful contribution | ✓ Combination of personalization + minimal training data + spice control is novel |
| **3** | Some novelty but incremental; combines existing techniques in new way | ⚠ If we only emphasize KNN classification without the full system innovation |
| **2** | Minor novelty; mostly engineering existing approaches | ✗ Just another beatbox classifier |
| **1** | No novelty; reproduces existing work | ✗ |

**CHULOOPA's Novel Contributions (MUST EMPHASIZE):**
1. ✓ **Personalized training:** 10 samples per class vs. 100s in generic models
2. ✓ **Live performance optimization:** <50ms latency, queued actions at loop boundaries
3. ✓ **Real-time spice control:** Dynamic creativity parameter with visual feedback
4. ✓ **OSC-based Python-ChucK integration:** Seamless AI workflow for live use
5. ✓ **End-to-end system:** Training → performance → variation in single workflow
6. ✓ **Delta-time format:** Precise loop timing for musical accuracy
7. ✓ **Drums-only mode:** Symbolic representation without audio looping

**Novelty Red Flags to Avoid:**
- Don't oversell KNN as novel (it's not—the *application* is)
- Don't claim first beatbox classifier (cite existing work)
- Don't ignore that variation generation uses existing APIs (Gemini)

**Self-Assessment Questions:**
- [ ] Is our novelty claim defensible against related work?
- [ ] Do we clearly articulate what's new vs. what's existing technique?
- [ ] Do we frame novelty as *system design* for live performance, not just algorithms?

**Target Score:** 4-5

---

### 3. Artistic/Scientific/Theoretical Quality (Weight: 20%)

| Score | Criteria | CHULOOPA Evidence Needed |
|-------|----------|-------------------------|
| **5** | Rigorous methodology, compelling artistic outcomes, well-supported claims, thorough evaluation | ✓ User study + performance documentation + accuracy metrics + qualitative analysis |
| **4** | Sound methodology, good evidence for claims, reasonable evaluation | ✓ At minimum: classifier accuracy (>85%), latency measurements, user feedback from performances |
| **3** | Adequate methodology but evaluation is limited; some claims need better support | ⚠ Only technical metrics, no user/performer perspective |
| **2** | Weak methodology, minimal evaluation, overclaimed results | ⚠ No evaluation, only system description |
| **1** | Fundamental methodological flaws, no evaluation | ✗ |

**Required Evidence for Score 4+:**
- [ ] **Technical Metrics:**
  - KNN classifier accuracy (per-user personalized models)
  - Onset detection precision/recall
  - System latency measurements (input → classification → playback)
  - Loop sync accuracy (drift over time)

- [ ] **User/Performer Evaluation:**
  - Informal user testing (N≥5): training time, classification accuracy perception, usability
  - Self-reflection as performer: creative affordances, limitations, musical outcomes
  - Variation quality assessment: musical coherence, spice level effectiveness

- [ ] **Artistic Documentation:**
  - Video/audio of live performances using CHULOOPA
  - Example drum patterns (original vs. variations)
  - Discussion of creative outcomes and limitations

**AIMC Note:** Practice-based approaches accepted—qualitative reflection on artistic outcomes is valid! (See [AIMC Review Process](https://aimc2026.org/call-for-submissions/review-process))

**Self-Assessment Questions:**
- [ ] Do we have objective measurements where appropriate (latency, accuracy)?
- [ ] Do we have subjective assessment from users/performers?
- [ ] Do we discuss both successes AND limitations honestly?
- [ ] Do we provide artistic context (recordings, performances)?

**Target Score:** 4

---

### 4. Readability & Organisation (Weight: 10%)

| Score | Criteria | Paper Structure Check |
|-------|----------|---------------------|
| **5** | Exceptionally clear, well-structured, engaging writing; perfect flow | ✓ Story arc: motivation → design → implementation → evaluation → reflection |
| **4** | Clear and well-organized; easy to follow | ✓ Standard structure, good figures, minimal typos |
| **3** | Generally readable but some organizational issues or unclear sections | ⚠ Confusing technical sections, weak motivation |
| **2** | Difficult to follow; poor organization or many writing issues | ⚠ Unclear structure, too much jargon |
| **1** | Unreadable or incomprehensible | ✗ |

**Recommended Structure:**
1. **Abstract** (200 words)
   - Problem: Generic ML models don't personalize; live performance needs <50ms latency
   - Solution: User-trainable beatbox system with AI variations
   - Contributions: Minimal training data (10 samples), real-time spice control, end-to-end workflow
   - Validation: Accuracy + user feedback + performance documentation

2. **Introduction** (1-1.5 pages)
   - Motivation: Beatboxing as expressive input, personalization matters
   - Context: Live performance constraints (latency, learnability, controllability)
   - Gap: Existing systems either generic OR require extensive training data
   - Our approach: CHULOOPA system overview
   - Contributions list (7 bullet points)

3. **Related Work** (1-1.5 pages)
   - Beatbox transcription/classification
   - User-trainable ML systems
   - Real-time music AI (Notochord, live coding, etc.)
   - Co-creative systems and variation generation
   - Position CHULOOPA in landscape

4. **System Design** (2-2.5 pages)
   - Architecture overview (with diagram!)
   - Training phase (sample recorder, KNN, feature extraction)
   - Performance phase (onset detection, classification, looping, OSC)
   - AI variation generation (Gemini API, spice control)
   - Key design decisions (ChucK-Python OSC, queued actions, delta-time format)

5. **Implementation** (1-1.5 pages)
   - Technical details (sampling rates, thresholds, latency optimization)
   - ChucK + Python integration
   - MIDI controller mapping
   - ChuGL visual feedback

6. **Evaluation** (2-2.5 pages)
   - Technical metrics (accuracy, latency, sync)
   - User study or informal testing
   - Artistic reflection on performances
   - Variation quality assessment
   - Limitations discussion

7. **Discussion** (1 page)
   - Insights: What worked? What didn't? Why?
   - Design tradeoffs (personalization vs. generalization, latency vs. accuracy)
   - Future work (multi-track, pattern evolution, other input modalities)

8. **Conclusion** (0.5 pages)
   - Summary of contributions
   - Broader implications for user-trainable music AI

9. **References** (1-2 pages)
   - Target: 30-50 citations

**Figures to Include:**
- [ ] System architecture diagram (training + performance phases)
- [ ] OSC communication flow (Python ↔ ChucK)
- [ ] Screenshot of ChuGL visual feedback
- [ ] Feature space visualization (KNN classification boundaries)?
- [ ] Example drum patterns (original vs. variation, with delta_time)
- [ ] Performance photo/video stills
- [ ] Latency breakdown chart
- [ ] User study results (if applicable)

**Target Score:** 4-5

---

### 5. Methodology & Reasonableness of Claims (Weight: 15%)

| Score | Criteria | CHULOOPA Claim Assessment |
|-------|----------|--------------------------|
| **5** | Methodology perfectly suited to research questions; all claims well-supported | ✓ Every claim has evidence (metrics, user feedback, or theoretical justification) |
| **4** | Appropriate methodology; claims generally well-supported with minor gaps | ✓ Most claims supported; acknowledge limitations openly |
| **3** | Methodology mostly appropriate but some mismatches; some overclaiming | ⚠ Claims about "AI creativity" without defining criteria |
| **2** | Methodology has significant issues; notable overclaiming | ⚠ "Revolutionary" claims without comparative evaluation |
| **1** | Inappropriate methodology; unreasonable or misleading claims | ✗ |

**Claims to Support with Evidence:**

| Claim | Evidence Required | Status |
|-------|-------------------|--------|
| "Personalized models outperform generic classifiers" | Comparison test: generic model vs. user-trained (or cite literature) | ⚠ Need data |
| "10 samples sufficient for >85% accuracy" | Per-user accuracy metrics across N users | ⚠ Need user study |
| "<50ms latency achieves 'real-time' feel" | Latency measurements + user perception feedback | ⚠ Need measurements |
| "AI variations maintain musical coherence" | Subjective evaluation (user ratings or expert judgment) | ⚠ Need evaluation |
| "Spice control enables creative exploration" | User feedback on variation quality at different spice levels | ⚠ Need user study |
| "Queued actions prevent rhythmic disruption" | Technical demonstration + user confirmation | ✓ Can demonstrate |
| "OSC integration enables seamless workflow" | Timing measurements, reliability testing | ✓ Can measure |

**Unreasonable Claims to AVOID:**
- ✗ "First beatbox classification system" (not true, cite existing work)
- ✗ "Solves beatbox transcription" (overstated—we do 3-class classification, not full transcription)
- ✗ "AI generates creative variations" (define "creative" or use softer language: "musically coherent variations")
- ✗ "Real-time" without defining latency threshold
- ✗ "User-friendly" without user testing

**Reasonable, Defensible Claims:**
- ✓ "Enables personalized beatbox-to-drum mapping with minimal training data"
- ✓ "Achieves low-latency classification suitable for live performance"
- ✓ "OSC-based architecture enables automatic AI variation generation in live workflow"
- ✓ "Spice control parameter allows performers to adjust variation creativity in real-time"
- ✓ "Demonstrates feasibility of end-to-end user-trainable drum machine for live performance"

**Self-Assessment Questions:**
- [ ] Can we back up every major claim with evidence?
- [ ] Have we been honest about limitations?
- [ ] Have we avoided hyperbolic language ("revolutionary," "unprecedented," etc.)?
- [ ] Have we defined subjective terms (e.g., "real-time," "creative," "coherent")?

**Target Score:** 4

---

### 6. Ethical Standards (Weight: 5%)

| Score | Criteria | CHULOOPA Context |
|-------|----------|------------------|
| **5** | Exemplary ethical consideration; proactive discussion of implications | ✓ Discuss AI authorship, data privacy, accessibility, environmental cost |
| **4** | Meets ethical standards; addresses relevant concerns | ✓ Standard consent for user study, acknowledge AI tool use (Gemini) |
| **3** | Adequate ethics but missing some considerations | ⚠ No discussion of AI's role in creativity or data use |
| **2** | Ethical concerns inadequately addressed | ⚠ User data handling unclear |
| **1** | Significant ethical violations or omissions | ✗ |

**Ethical Considerations for CHULOOPA:**

**Data & Privacy:**
- [ ] User voice recordings: How are they stored? Retained? Deleted?
- [ ] Training data ownership: Who owns the personalized models?
- [ ] Gemini API usage: Is user data sent to Google? What are privacy implications?

**AI Authorship & Creativity:**
- [ ] Who is the "author" of AI-generated variations? User? System? Collaborative?
- [ ] How does AI assistance affect performer agency and creativity?
- [ ] Acknowledge role of Gemini API explicitly (not hiding AI use)

**Accessibility:**
- [ ] Is CHULOOPA accessible to users with disabilities?
- [ ] Does beatbox input exclude users with certain vocal limitations?
- [ ] Could system be adapted for alternative input modalities?

**Environmental Impact:**
- [ ] Acknowledge API calls to Gemini have carbon cost
- [ ] Could local models reduce environmental impact?

**User Study Ethics (if applicable):**
- [ ] IRB approval or institutional ethics review?
- [ ] Informed consent from participants
- [ ] Right to withdraw data
- [ ] Anonymization of user feedback

**Recommended Ethics Section (1-2 paragraphs in Discussion):**
- Acknowledge Gemini API usage and data implications
- Discuss collaborative creativity (human-AI authorship)
- Note accessibility considerations and future improvements
- Mention consent and data handling for any user studies

**Target Score:** 4

---

### 7. Relationship to Conference Theme (Weight: 5%)

| Score | Criteria | AIMC 2026 Theme Alignment |
|-------|----------|--------------------------|
| **5** | Exemplifies conference theme; central contribution addresses theme directly | ✓ TBD—theme not yet announced |
| **4** | Strong connection to theme with clear discussion | ✓ |
| **3** | Relevant to theme but connection could be stronger | ⚠ |
| **2** | Weak connection to theme | ⚠ |
| **1** | No clear relationship to theme | ✗ |

**AIMC 2025 Theme:** "The Artist in The Loop" ([AIMC 2025](https://aimusiccreativity.org/2025/))

**If AIMC 2026 has similar theme, CHULOOPA is HIGHLY relevant:**
- ✓ User-trainable: Artist trains their own personalized model
- ✓ Real-time control: Spice parameter keeps artist in creative loop
- ✓ Queued actions: Artist controls when transitions happen
- ✓ Live performance focus: System designed for performer agency

**Generic AIMC Themes CHULOOPA Addresses:**
- AI + Music Creation
- Live Performance Systems
- Co-creative AI
- Real-time Interaction
- Machine Listening
- User-Trainable Systems

**Action Items:**
- [ ] Check AIMC 2026 theme when announced
- [ ] Add 1-2 paragraphs in Introduction/Discussion explicitly connecting to theme
- [ ] Use theme keywords in abstract

**Target Score:** 4-5 (pending theme announcement)

---

## Overall Score Calculation

**Weighted Score Formula:**
```
Total = (Relevance × 0.20) + (Novelty × 0.25) + (Quality × 0.20) +
        (Readability × 0.10) + (Methodology × 0.15) + (Ethics × 0.05) + (Theme × 0.05)
```

**Target Overall Score:** ≥ 4.0 (Accept threshold)

**Competitive Score:** ≥ 4.3 (Strong accept, potential for best paper consideration)

---

## Pre-Submission Checklist

### Content Completeness
- [ ] All 7 novel contributions clearly articulated
- [ ] Related work covers: beatbox, user-trainable ML, real-time music AI, co-creative systems, variation generation
- [ ] System architecture diagram included
- [ ] Technical metrics reported (accuracy, latency, sync)
- [ ] User evaluation conducted (even if informal, N≥5)
- [ ] Artistic documentation provided (video, audio, or stills)
- [ ] Limitations discussed honestly
- [ ] Ethics section addresses data privacy and AI authorship
- [ ] Connection to conference theme made explicit

### Evidence Gaps to Fill BEFORE Submission
- [ ] **User study:** Minimum 5 users, measure training time, perceived accuracy, usability
- [ ] **Latency measurements:** Input → onset detection → classification → playback
- [ ] **Accuracy metrics:** Per-user KNN performance (precision/recall for kick/snare/hat)
- [ ] **Variation quality:** Subjective ratings at different spice levels
- [ ] **Performance documentation:** Record ≥1 live performance or demo video
- [ ] **Loop sync evaluation:** Measure drift over extended performance (e.g., 10 minutes)

### Writing Quality
- [ ] Abstract under word limit, clearly states contributions
- [ ] No typos or grammatical errors
- [ ] Consistent terminology throughout
- [ ] Figures have descriptive captions and are referenced in text
- [ ] Code/data availability statement (GitHub repo?)
- [ ] Supplementary materials prepared (video demo strongly recommended)

### Submission Requirements
- [ ] Paper length within limit (check CFP—typically 4-8 pages)
- [ ] Anonymized for review (if double-blind)
- [ ] References formatted correctly
- [ ] Submitted by deadline (AoE timezone)

---

## Red Flags That Would Lower Score

### Relevance (Criterion 1)
- ✗ No citation of Magenta, GrooVAE, or major AI music generation work
- ✗ Missing recent AIMC papers (2022-2025) in related work
- ✗ Ignoring existing beatbox transcription/classification research

### Novelty (Criterion 2)
- ✗ Claiming KNN itself is novel
- ✗ Overclaiming "first" or "only" without thorough literature review
- ✗ Not acknowledging that Gemini API does variation generation (hiding AI use)

### Quality (Criterion 3)
- ✗ No evaluation beyond "it works for me"
- ✗ No performance documentation (AIMC values artistic outcomes!)
- ✗ Ignoring or downplaying system failures/limitations

### Readability (Criterion 4)
- ✗ Dense technical jargon without explanation
- ✗ Missing system architecture diagram
- ✗ No clear contribution statements
- ✗ Poor figure quality or unlabeled axes

### Methodology (Criterion 5)
- ✗ "Revolutionary" or "groundbreaking" without evidence
- ✗ "Real-time" without defining latency threshold
- ✗ "Creative" without defining what that means
- ✗ Claiming personalization matters without comparison to generic model

### Ethics (Criterion 6)
- ✗ No mention of Gemini API usage
- ✗ No discussion of data privacy for voice recordings
- ✗ No consent process for user study
- ✗ Ignoring accessibility considerations

### Theme (Criterion 7)
- ✗ Not mentioning conference theme at all
- ✗ Generic "AI music" framing without connecting to specific theme

---

## Comparison to Related Work

**Example AIMC Paper:** [Rhythmic Conversations](https://aimc2023.pubpub.org/pub/qot7sw4x/release/2)
- **Similarities:** Live performance, audience interaction, Magenta-based, OSC integration
- **CHULOOPA advantages:** User-trainable (more personalized), real-time spice control, <50ms latency
- **Rhythmic Conversations advantages:** Actual deployment in performances with audiences, venue-specific insights

**Key Takeaway:** AIMC accepts papers without formal quantitative evaluation IF they provide valuable insights through practice-based research and artistic documentation.

---

## Mock Review Scenarios

### Scenario 1: Strong Accept (Score 4.5+)
**Strengths:**
- Novel combination of personalization + minimal training + real-time control
- Solid technical evaluation (accuracy, latency) + user study (N=8)
- Honest discussion of limitations and failure cases
- Video documentation of live performance
- Clear writing with excellent figures
- Addresses ethics thoughtfully

**Weaknesses:**
- User study could be larger
- No comparison to generic classifier baseline

**Verdict:** Accept—strong contribution to live performance AI music systems

---

### Scenario 2: Borderline Accept (Score 3.5-4.0)
**Strengths:**
- Interesting system with clear motivation
- Good technical implementation
- Addresses relevant problem

**Weaknesses:**
- Limited evaluation (only author's experience)
- Overclaims novelty without comparing to existing beatbox systems
- Missing performance documentation
- Literature review has gaps (no Magenta, GrooVAE, or recent AIMC work)

**Verdict:** Weak accept—revise to add evaluation and strengthen related work

---

### Scenario 3: Reject (Score <3.5)
**Strengths:**
- Working system

**Weaknesses:**
- Minimal evaluation (no users, no metrics, no artistic documentation)
- Overstates contributions ("revolutionary," "first," "solves beatbox")
- Poor literature review (only cites generic ML papers)
- No discussion of limitations or failures
- Writing is confusing with missing figures

**Verdict:** Reject—needs substantial revision before reconsideration

---

## Next Steps

1. **Conduct User Study** (CRITICAL)
   - Recruit N≥5 participants
   - Measure: training time, classification accuracy, usability (SUS or NASA-TLX)
   - Collect qualitative feedback on creative affordances

2. **Technical Evaluation**
   - Measure end-to-end latency (breakdown by component)
   - Report per-user classifier accuracy (precision/recall)
   - Test loop sync over extended performance

3. **Artistic Documentation**
   - Record live performance or demo video (3-5 minutes)
   - Export example drum patterns (original + variations)

4. **Literature Review**
   - Comprehensive search: beatbox transcription, user-trainable ML, real-time music AI
   - Read recent AIMC papers (2022-2025) and cite relevant work
   - Position CHULOOPA clearly in landscape

5. **Writing**
   - Draft abstract and introduction with clear contribution statements
   - Create system architecture diagram
   - Write ethics section addressing data privacy and AI authorship

6. **Internal Review**
   - Use this rubric to self-evaluate draft
   - Get feedback from advisor or peers
   - Revise based on mock review scenarios

---

## Resources

- [AIMC 2026 Website](https://aimc2026.org/home)
- [AIMC Review Process](https://aimc2026.org/call-for-submissions/review-process)
- [AIMC 2025 Theme](https://aimusiccreativity.org/2025/)
- [AIMC 2023 Proceedings](https://aimc2023.pubpub.org/) (for example papers)
- [Rhythmic Conversations Paper](https://aimc2023.pubpub.org/pub/qot7sw4x/release/2) (related work example)

---

**Created:** 2026-03-09
**For:** CHULOOPA AIMC 2026 Submission
**Version:** 1.0
