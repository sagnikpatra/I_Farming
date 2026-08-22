# Balance Check: Land & Structures

**Date**: 2026-08-22
**Trigger**: `design/gdd/land-and-structures.md` §5's own "Recommended
Balance Pass" — never run. Third of the five economy docs sharing this
gap (see `balance-check-crop-economy-2026-08-22.md` for the first).

### Data Sources Analyzed
- `godot/scripts/economy/game_data.gd` — land/structure cost constants,
  confirmed matching the GDD's own tables
- `design/gdd/land-and-structures.md`, `crop-economy.md`'s crop-rate
  numbers (from the first report in this sweep, reused rather than
  re-derived)

### Health Summary: CONCERNS (one real finding, with an important nuance)

### Land Expansion Cost Curve

`land_expansion_cost(count) = round(150 × 1.55^(count − 3))`. Full cost to
go from `STARTING_PLOTS = 3` to `MAX_PLOTS = 16` (13 purchases):

| Plot # | Cost | Plot # | Cost | Plot # | Cost |
|---|---|---|---|---|---|
| 4 | ₹150 | 9 | ₹1,342 | 14 | ₹12,006 |
| 5 | ₹233 | 10 | ₹2,080 | 15 | ₹18,609 |
| 6 | ₹360 | 11 | ₹3,224 | 16 | ₹28,844 |
| 7 | ₹559 | 12 | ₹4,997 | | **Total: ₹81,016** |
| 8 | ₹866 | 13 | ₹7,746 | | |

This is a clean, smooth geometric curve with no jumps or anomalies — no
finding here. §7's open question ("Confirm `MAX_PLOTS = 16` is a
deliberate final cap") is a genuine design call, correctly left for you,
not resolved by this report.

## Outliers Detected

| Item/Value | Expected Range | Actual | Issue |
|---|---|---|---|
| Structure unlock cost vs. stated tier number | Tier 2 < Tier 3 < Tier 4a/4b (ascending with tier) | Aquaculture (**"Tier 4a," ₹15,000**) < Agroforestry (**"Tier 3," ₹20,000**) < Polyhouse (**"Tier 2," ₹35,000**) < Vertical Farm ("Tier 4b," ₹80,000) | Base unlock cost does not ascend with the stated tier number — Polyhouse (Tier 2) costs *more* to unlock than both Agroforestry (Tier 3) and Aquaculture ("Tier 4a") |

**Important nuance — this is real but likely overstated by base cost
alone**: Polyhouse's *base* unlock cost is the second-highest of the
four, but it's also the only structure with 3 additional optional
sub-purchases (Fan & Pad ₹70,000, Drip Irrigation ₹5,000, UV Film
₹7,500 recurring) — a fully-built-out Polyhouse represents ~₹117,500+
of total possible investment, well above Agroforestry's unlock +
Security (₹20,000 + ₹50,000 = ₹70,000) and clearly above Aquaculture's
unlock-only ₹15,000. Read that way, "tier" may track *total investment
ceiling* rather than *base unlock cost* — in which case the ordering is
closer to correct than the raw table suggests, though Aquaculture
undercutting Agroforestry (₹15,000 vs. ₹20,000, both effectively
unlock-only-ish costs — Agroforestry's Security add-on is optional, not
required to use the tier at all) is harder to explain the same way.

## Degenerate Strategies Found

None identified. Each structure gates a genuinely different crop set
with no overlapping choice to exploit (a player doesn't choose *between*
Polyhouse and Aquaculture for the same crop — they're mutually
exclusive unlocks feeding different plot kinds).

## Progression Analysis

Sandalwood theft-risk math confirmed consistent with the GDD's own
stated claim: unprotected, compounding `0.00085`/hour over the 21-day
(504-hour) base grow works out to roughly a 35% cumulative theft chance
— matching §5's "~30%+" description closely. Secured (`0.00006`/hour),
the same math gives roughly 3% — confirms Security (₹50,000) is a real,
substantial risk reduction (~12× safer), not a token purchase.

## Recommendations

| Priority | Issue | Suggested Fix | Impact |
|---|---|---|---|
| LOW | Structure "tier" numbering doesn't match base-unlock-cost ordering | **Your call** — either relabel the tiers to track something other than raw unlock cost explicitly (e.g., "capital-intensity tier" incorporating sub-purchases), or just leave it, since it's a labeling/framing question rather than a formula bug | Doc-only either way; no `game_data.gd` values look obviously wrong on their own |

## Values That Need Attention

None require a code change. No values were changed by this report.

---

Re-run `/balance-check` after any fix to verify. Next in this sweep:
`mandi-trading.md`.
