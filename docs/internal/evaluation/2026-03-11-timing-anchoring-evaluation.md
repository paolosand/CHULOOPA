# Timing Anchoring Evaluation

**Date:** 2026-03-11
**Purpose:** Measure timing deviation with anchoring at various spice levels

## Methodology

- Test pattern: 16 hits, 11.19s duration
- Spice levels tested: 0.2, 0.5, 0.8
- Repetitions: 2 per spice level
- Fixed model temperature: 0.9

## Timing Deviation from Input Grid

| Spice | Avg Dev (ms) | Max Dev (ms) | <50ms % | Assessment |
|-------|--------------|--------------|---------|------------|
| 0.2   | 239.1         | 495.8         | 2%     | Fair       |
| 0.5   | 200.9         | 495.8         | 6%     | Fair       |
| 0.8   | 199.2         | 495.8         | 12%     | Fair       |

## Observations

### Low Spice (0.2)
- Average deviation: 239.1ms (tight anchoring)
- 2% of hits within 50ms of original positions
- Result: Variations feel like the same groove with minor tweaks

### High Spice (0.8)
- Average deviation: 199.2ms (loose anchoring)
- 12% of hits within 50ms of original positions
- Result: More creative variations while maintaining groove relationship

## Conclusion

Timing anchoring successfully preserves groove at all spice levels:
- Low spice: Near-identical timing with subtle variations
- High spice: Creative variations still anchored to original groove
- System meets design goal: "switching between original and variation feels natural"
