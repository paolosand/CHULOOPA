# AIMC 2026 LaTeX Paper - Usage Guide

## Files Created

1. **chuloopa_aimc2026.tex** - Main LaTeX document
2. **chuloopa_references.bib** - Bibliography file with all citations
3. **LATEX_README.md** - This guide

## How to Use with Overleaf

### Option 1: Upload to Overleaf (Recommended)

1. Go to Overleaf (overleaf.com)
2. Create a new blank project or upload the AIMC template
3. Upload these files:
   - `chuloopa_aimc2026.tex`
   - `chuloopa_references.bib`
   - Copy `aimc2026.cls` from the AIMC template directory

4. Set the main document to `chuloopa_aimc2026.tex`
5. Compile with pdfLaTeX

### Option 2: Local Compilation

If you have LaTeX installed locally:

```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/paper"

# Copy the AIMC class file to this directory
cp "/Users/paolosandejas/Downloads/AIMC_2026_Templates/AIMC 2026 Template Latex/aimc2026.cls" .

# Compile (run multiple times for references)
pdflatex chuloopa_aimc2026.tex
bibtex chuloopa_aimc2026
pdflatex chuloopa_aimc2026.tex
pdflatex chuloopa_aimc2026.tex
```

## What's Included

### Completed Sections
- ✅ Abstract
- ✅ Introduction (all subsections)
- ✅ Related Work (comprehensive literature review)
- ✅ System Design (beatbox transcription, KNN classification, AI variation)
- ✅ Implementation (brief overview)
- ✅ Discussion (personalization, limitations, positioning)
- ✅ Future Work
- ✅ Conclusion
- ✅ Author Declarations
- ✅ Acknowledgments
- ✅ 60+ References in BibTeX format

### Sections Marked as TODO (from your draft)
- Section 3.1 (Overview and Design Goals) - placeholder text
- Section 5 (Evaluation) - contains placeholder for actual measurements
- Figures and tables - not yet created

## What You Need to Add

### 1. Missing Content
Fill in the TODO sections:
- Section 3.1: Overview and Design Goals
- Section 5: Complete evaluation results when you return from NYC

### 2. Figures (Required for publication)
You'll need to create these figures in the final version:
- **Figure 1:** System architecture diagram
- **Figure 2:** OSC communication flow
- **Figure 3:** Continuation-based variation pipeline
- **Figure 4:** ChuGL interface screenshot
- **Figure 5:** Drum pattern comparison (original vs. variation)
- **Table 1:** Confusion matrix for classification accuracy

### 3. Final Formatting
Before submission:
- Check page limit (typically 4-8 pages for AIMC)
- Add figures with proper captions
- Anonymize for double-blind review (remove author names in final submission)
- Verify all citations appear correctly

## Current Paper Statistics

- **Approximate Length:** 8-10 pages (will vary with figures)
- **References:** 60+ papers (comprehensive coverage)
- **Sections:** All major sections complete
- **Code Examples:** Included (delta-time format, etc.)

## Notes

- The LaTeX formatting follows AIMC 2026 template exactly
- All section headings use proper capitalization (SECTION NAME for level 1)
- Citations use natbib with apalike style (author-year format)
- The `\aimcnotice` command adds the conference footer
- Abstract is properly formatted in the twocolumn header
- The `ack` environment will hide acknowledgments in anonymous submission

## Quick Edits

To make quick edits to specific sections, search for these labels:
- `\section{INTRODUCTION}` - Introduction
- `\label{sec:related_work}` - Related Work
- `\label{sec:system_design}` - System Design
- `\label{sec:evaluation}` - Evaluation (needs data)
- `\label{sec:discussion}` - Discussion

## Compilation Troubleshooting

If you get errors:
1. Make sure `aimc2026.cls` is in the same directory
2. Check that all citations in the .tex file have entries in the .bib file
3. Run bibtex after the first pdflatex compile
4. Some warnings about citations are normal on first compile

## Next Steps

1. Upload to Overleaf and verify it compiles
2. Review the content and make any edits
3. When back from NYC, add evaluation results
4. Create figures
5. Final polish and submission preparation

Good luck with your AIMC 2026 submission!
