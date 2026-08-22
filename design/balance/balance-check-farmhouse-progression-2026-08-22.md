# Balance Check: Farmhouse Progression

**Date**: 2026-08-22
**Trigger**: `design/gdd/farmhouse-progression.md` §5's own "Recommended
Balance Pass" — never run despite being flagged since the doc was authored.
Second of the five economy docs sharing this gap (see `balance-check-
crop-economy-2026-08-22.md` for the first).

### Data Sources Analyzed
- `godot/scripts/economy/game_data.gd`'s `_ensure_farmhouse_levels()` —
  confirmed matches `design/gdd/farmhouse-progression.md` §2.1's table
  exactly, value for value
- `design/gdd/farmhouse-progression.md` — design intent, formulas, and
  existing self-flagged concerns

### Health Summary: HEALTHY (one new minor observation, not a concern)

The one balance concern this doc already flags (§5, the Level 6→7 cost
jump) is confirmed accurate and already correctly characterized as "not
obviously an outlier." This pass found one additional small pattern worth
recording, not a problem.

---

## Confirming the Existing §5 Concern

Marginal cost multiplier per tier: 4.0×, 3.125×, 3.0×, 2.667×, 2.5×, 2.4×
(levels 0→1 through 6→7). The ratio actually *decreases* monotonically —
the curve isn't accelerating in relative terms, even though absolute
costs obviously keep growing (₹2,000 → ₹1,200,000 across 7 upgrades).
§5's own read ("consistent with the curve, not obviously an outlier") is
correct. No action needed here beyond what's already documented.

## New Observation: The Final Tier Swaps Its Bonus Emphasis

Every tier from 0→1 through 5→6 adds exactly **+3% growth speed and +2%
sell price** per level — a perfectly consistent, clearly deliberate
per-tier increment. Level 6→7 (the final upgrade) breaks that pattern:
**+2% growth speed, +3% sell price** — the two bonus types swap which one
gets the larger increment, only at the capstone tier.

This is a clean, consistent swap (not a stray typo — both numbers still
sum to the same +5% total per tier the rest of the table uses), so it
reads as an intentional design choice: a final "market sophistication"
capstone (fitting "Modern Agricultural Estate," a more commercial-
sounding tier name than the ones before it) that leans toward sell-price
over growth-speed. Flagged here only because it wasn't previously
documented anywhere — not treated as a bug.

## Outliers Detected

None beyond the already-known, already-correctly-assessed Level 6→7 cost
jump.

## Degenerate Strategies Found

None. The tier progression is strictly linear (no skip-tier option, no
branching), so there's no comparative choice between tiers to exploit —
every player takes every tier in order.

## Recommendations

| Priority | Issue | Suggested Fix | Impact |
|---|---|---|---|
| LOW | Final-tier bonus swap (+2%/+3% vs. the consistent +3%/+2% every other tier) isn't documented as intentional anywhere | Add one sentence to §2.1 or §5 confirming it's deliberate (or, if it was actually unintentional, align it to +3%/+2% like every other tier) | Doc-only if intentional; a single `game_data.gd` constant if not — your call, not this report's |

## Values That Need Attention

None require a code change. No values were changed by this report.

---

Re-run `/balance-check` after any fix to verify. Next in this sweep:
`land-and-structures.md`.
