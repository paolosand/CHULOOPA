# Event Management Branch Summary

**Branch:** event-management-chuck
**Base:** staging (0512b5b)
**Created:** 2026-03-11
**Status:** ✅ Analysis complete, ready for implementation

---

## Purpose

Refactor event management in `chuloopa_drums_v2.ck` to fix inconsistent queuing behavior and improve reliability of pattern loading, clearing, and variation toggling.

---

## Documents in This Branch

### 📊 Analysis
**[EVENT_MANAGEMENT_ANALYSIS.md](./EVENT_MANAGEMENT_ANALYSIS.md)** - Comprehensive 3,800-line analysis covering:
- Current architecture (state variables, event flows)
- Key functions (loading, clearing, queuing, execution)
- OSC communication protocol
- Visual feedback state machine
- 6 identified issues with root cause analysis
- Timing analysis and performance metrics
- Code quality observations

### 📋 Implementation
**[IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)** - Step-by-step guide with:
- 5 phases (3 critical fixes + 2 enhancements)
- Code snippets for each change
- Testing checklist (15 test scenarios)
- 15-hour implementation timeline
- Files to modify with line numbers

---

## Critical Issues Found

### 1. Inconsistent Queuing (High Priority)
**Problem:** Clear track executes IMMEDIATELY while variation toggle QUEUES for loop boundary
```chuck
// Line 2117 - IMMEDIATE
clearTrack(0);

// Line 2125 - QUEUED
toggleVariationMode();  // Sets queued_toggle_variation=1
```
**Impact:** Jarring mid-loop silence, inconsistent UX
**Fix:** Implement `queueClearTrack()` function (Phase 1)

### 2. Silent File Load Failures (High Priority)
**Problem:** `loadVariationFile()` returns 0 on failure but calling code doesn't check
```chuck
loadVariationFile(0, 1);  // No return value check!
```
**Impact:** User sees "loading variation" but plays original, no error message
**Fix:** Add return value checking with error messages (Phase 2)

### 3. Race Condition (High Priority)
**Problem:** Variation ready signal can arrive during new recording
```
t=2s: Release recording → Python generates for loop 1
t=3s: Record loop 2
t=5s: OSC variations_ready for loop 1 (LATE!)
      variations_ready=1 but data is for OLD loop
```
**Impact:** Wrong variation applied to new loop
**Fix:** Invalidate variations on recording start (Phase 3)

---

## Enhancement Opportunities

### 4. Multi-Variation Support (Medium Priority)
**Current:** Hardcoded to always load `var1`
**Proposed:** Cycle through multiple variations (var1, var2, var3, etc.)
**Implementation:** Add `cycleToNextVariation()` function, new MIDI mapping

### 5. Dead Code Cleanup (Low Priority)
**Found:** `queued_clear_track[]` array exists but is NEVER used
**Root Cause:** Clear track is always immediate, queue never set
**Fix:** Remove array OR implement queued clear (Phase 1 does this)

---

## Key Architectural Findings

### ✅ Strengths
- **Playback Session IDs:** Elegant solution to prevent old hits from playing
- **Master Coordinator:** Clean loop boundary synchronization
- **OSC Integration:** Well-structured Python ↔ ChucK communication
- **Visual Feedback:** Comprehensive state machine with color coding

### ❌ Weaknesses
- **Inconsistent Timing:** Some actions immediate, some queued
- **Global State:** All variables global, no encapsulation
- **Magic Numbers:** Hardcoded variation numbers, no constants
- **No Timeouts:** OSC messages wait indefinitely

---

## Implementation Timeline

**Week 1: Critical Fixes (7 hours)**
- Mon-Tue: Queued clear track (Phase 1)
- Wed: Error handling (Phase 2)
- Thu: Race condition fix (Phase 3)
- Fri: Testing & validation

**Week 2: Enhancements (8 hours)**
- Mon-Tue: Multi-variation support (Phase 4)
- Wed: Visual feedback improvements (Phase 5)
- Thu-Fri: Integration testing & docs

**Total:** 15 hours estimated

---

## Testing Strategy

### Before Starting
```bash
# Backup original file
cd .worktrees/event-management-chuck
cp src/chuloopa_drums_v2.ck src/chuloopa_drums_v2.ck.backup
git add -A
git commit -m "backup: save pre-refactor state"
```

### Critical Path Tests (Must Pass)
1. **Queued Clear:** Record loop, press C#1 mid-loop → Verify clears at boundary
2. **Load Failure:** Delete variation file, toggle mode → Verify error message
3. **Race Condition:** Record two loops rapidly → Verify correct variation
4. **Variation Toggle:** Record, wait for ready, toggle → Verify smooth transition
5. **Clear During Variation:** Load variation, clear track → Verify OSC sent

### Edge Cases (Nice to Have)
- Clear with no loop (should be immediate)
- Regenerate during recording (should be ignored)
- Multiple queued actions (should all execute)
- Python offline (should timeout gracefully)

---

## Code Locations Reference

**State Variables:**
- Lines 503-523: Queued actions and variation mode state

**Core Functions:**
- Line 918: `loadDrumDataFromFile()` - Load original pattern
- Line 1100: `loadVariationFile()` - Load AI variation
- Line 1443: `toggleVariationMode()` - Queue variation toggle
- Line 1463: `executeToggleVariation()` - Actually toggle at boundary
- Line 1650: `clearTrack()` - Clear track (IMMEDIATE)

**Event Processing:**
- Lines 1320-1389: Master coordinator (executes queued actions)
- Lines 1400-1440: OSC listener (Python → ChucK)

**Visual Feedback:**
- Lines 1790-1830: Sphere color state machine
- Lines 1835-1850: Shape morphing (spice level)

---

## MIDI Controls (Current)

**Recording:**
- Note 36 (C1): Record track 0 (press & hold)

**Pattern Control:**
- Note 37 (C#1): Clear track 0 (IMMEDIATE - will become QUEUED)
- Note 38 (D1): Toggle variation mode (QUEUED)
- Note 39 (D#1): Regenerate variations (IMMEDIATE)

**Spice Control:**
- CC 74: Spice level knob (0.0-1.0, real-time)

**Proposed Changes (Phase 4):**
- Note 40 (D#1): Cycle to next variation (NEW)
- Note 41 (E1): Regenerate (MOVED from Note 39)

---

## Integration Verification Needed

### Python Side (drum_variation_ai.py)
- [ ] Receives `/chuloopa/track_cleared` OSC message
- [ ] Sends `num_variations` in `/chuloopa/variations_ready`
- [ ] Cancels watchdog on track cleared

### ChucK Side (chuloopa_drums_v2.ck)
- [ ] OSC ports: 5001 receive, 5000 send
- [ ] File paths use `me.dir() + "/tracks/..."`
- [ ] Delta time format preserved

### Visual Feedback (ChuGL)
- [ ] Sphere colors match state correctly
- [ ] Shape morphing based on spice level
- [ ] Text displays accurate information

---

## Success Criteria

### Phase 1-3 Complete (Must Have)
- [ ] Queued clear track working (smooth transitions)
- [ ] File loading errors shown to user (no silent failures)
- [ ] Race condition eliminated (variations match loops)
- [ ] All critical path tests passing
- [ ] No regressions in existing functionality

### Phase 4-5 Complete (Nice to Have)
- [ ] Multi-variation selection working
- [ ] Visual feedback shows variation number
- [ ] Smooth cycling between variations
- [ ] Documentation updated

### Merge Ready (Final Check)
- [ ] Python integration intact
- [ ] Visual feedback accurate
- [ ] Code quality improved
- [ ] CLAUDE.md updated with new behavior
- [ ] QUICK_START.md reflects changes

---

## Commands Reference

**Switch to worktree:**
```bash
cd "/Users/paolosandejas/Documents/CALARTS - Music Tech/MFA Thesis/Code/CHULOOPA/.worktrees/event-management-chuck"
```

**Run system (two terminals):**
```bash
# Terminal 1: Python
cd src
python drum_variation_ai.py --watch

# Terminal 2: ChucK
cd src
chuck chuloopa_drums_v2.ck
```

**Git workflow:**
```bash
git status
git diff src/chuloopa_drums_v2.ck
git add src/chuloopa_drums_v2.ck
git commit -m "feat: implement queued clear track"
```

---

## Questions for User

### Design Decisions Needed
1. **Should clear ALWAYS queue?** Or immediate when no loop exists?
   - Recommendation: Queued if loop exists, immediate otherwise

2. **How many variations to generate?**
   - Current: 1 (var1)
   - Proposal: 3-5 for variety

3. **Should regenerate be queued?**
   - Current: Immediate (sends OSC right away)
   - Recommendation: Keep immediate (doesn't affect playback)

### Technical Clarifications
1. **Timeout for Python OSC?** What if Python offline?
   - Proposal: 5-second timeout, show error message

2. **Delete old variations on new recording?**
   - Current: Overwritten by Python
   - Proposal: Delete immediately on record start

---

## Next Steps

1. **Review analysis document** - Read EVENT_MANAGEMENT_ANALYSIS.md for full details
2. **Confirm design decisions** - Answer questions above
3. **Create backup** - Run backup command before starting
4. **Implement Phase 1** - Start with queued clear track
5. **Test incrementally** - Test after each phase

---

## Related Documentation

- **Main Project:** `../../CLAUDE.md` - Project overview and guidelines
- **User Guide:** `../../QUICK_START.md` - User-facing workflow
- **OSC Testing:** `../../TESTING.md` - Integration test guide
- **Analysis:** `./EVENT_MANAGEMENT_ANALYSIS.md` - This branch's detailed analysis
- **Plan:** `./IMPLEMENTATION_PLAN.md` - Step-by-step implementation

---

**Created:** 2026-03-11 by Claude Code (systematic-debugging skill)
**Status:** Ready for implementation
**Estimated Effort:** 15 hours over 2 weeks
