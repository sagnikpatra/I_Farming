# Balance Check: Mandi Trading

**Date**: 2026-08-22
**Trigger**: `design/gdd/mandi-trading.md` §5's own "Recommended Balance
Pass" — never run. Last of the five economy docs sharing this gap; closes
the full sweep started with `crop-economy.md`.

### Data Sources Analyzed
- `godot/scripts/economy/game_data.gd` — Mandi constants
  (`MANDI_MIN_MULTIPLIER`/`MAX_MULTIPLIER`, `MANDI_GRADE_A_BONUS_PERCENT`,
  demand-swing range)
- `design/gdd/mandi-trading.md`'s own formula table (§2.2)

### Health Summary: HEALTHY

The clamped price band does its job. Mandi vs. direct-sale expected value
splits cleanly and sensibly along the same protected-vs-open-field line
every other system in this economy already uses.

---

## Mandi vs. Direct Sale, Expected Value

`mandi_multiplier = clamp(1.0 + demand% + grade_bonus% − glut, 0.6, 1.6)`.
Demand swings uniformly `-15%` to `+20%` (mean ≈ **+2.5%**). Grade-A bonus
is `+12%` for any protected-cultivation crop (Polyhouse/Agroforestry/
Aquaculture/Vertical Farm), `0%` for Open Field. Assuming zero glut (a
crop the player hasn't been selling heavily through the Mandi recently):

| Crop tier | Average multiplier | Worst-case (−15% demand) | Best-case (+20% demand) |
|---|---|---|---|
| **Open Field** (no grade bonus) | **1.025×** — barely above direct sale's flat 1.0× | **0.85×** — *worse than direct sale* | 1.20× |
| **Protected** (+12% grade bonus) | **1.145×** — clearly, consistently better | **0.97×** — roughly break-even, never far below | 1.32× |

**This is a coherent, sensible split, not a finding that needs fixing**:
Mandi is close to a strict upgrade over direct sale for protected-
cultivation crops (worst case is nearly break-even), but for Open Field
crops it's a genuine gamble — the average is barely positive, and a bad
demand roll makes it worse than just using flat `sellCrop`/`sellAll`.
This matches the design's own framing (confirmed in `mandi_tab.gd`'s own
UI copy: "a genuine alternative to Sell All, not a replacement for it")
and rewards the same protected-cultivation investment every other system
in this economy already rewards. Recorded here because §5 explicitly
asked for this comparison and it had never actually been computed, not
because anything is wrong.

## Outliers Detected

None. Both ends of the price band (`0.6×`–`1.6×`) are reachable but rare
(would need extreme glut stacked with a bad/good demand roll) — the clamp
is doing real work preventing runaway pricing, as §5 already suspected.

## Degenerate Strategies Found

None. Glut only depresses the *specific crop* just sold, so there's no
free lunch in dumping one crop repeatedly — the mechanic behaves exactly
as its own "diversify your portfolio" design intent (§1) describes.

## Progression Analysis

N/A — this system doesn't have its own progression curve; it's a pricing
overlay on `crop-economy.md`'s existing crop set.

## Recommendations

None required — this pass confirms the system is balanced as designed.
The one still-open item is §7's own already-flagged **design** question
(whether the Grade-A bonus should be Fan & Pad-specific per `v2.md`'s
literal description, or stay broadly "any protected crop" as coded) —
correctly left for you, not something a balance-check resolves.

## Values That Need Attention

None. No values were changed by this report.

---

**This closes the 5-system economy balance-check sweep** started with
`crop-economy.md`. Summary across all five: one real economic finding
each in `crop-economy.md` (Tomato/Paddy underperform Wheat on ₹/sec) and
`liveops-events.md` (Premium Pass has negative EV below its top tier);
one minor/nuanced finding each in `farmhouse-progression.md` (an
undocumented but likely-intentional final-tier bonus swap) and
`land-and-structures.md` (structure "tier" numbering doesn't track raw
unlock cost, though total investment ceiling likely explains most of it);
`mandi-trading.md` itself confirmed clean. None of the five required an
immediate code change — every finding is either confirmed-healthy or a
real design call left explicitly for you.
