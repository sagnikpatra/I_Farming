# Balance Check: Crop Economy

**Date**: 2026-08-22
**Trigger**: `design/gdd/crop-economy.md` §5's own "Recommended Balance Pass" —
never run despite being flagged since the doc was authored (2026-08-18). Same
recommendation exists, unfulfilled, in `farmhouse-progression.md`,
`land-and-structures.md`, `liveops-events.md`, and `mandi-trading.md` — this
is the first of those five; the other four are a natural follow-up, not done
in this pass.

### Data Sources Analyzed
- `godot/scripts/economy/game_data.gd` — the real tuning-value source of
  truth for this project (this project has no `assets/data/` directory; this
  file fills that role, confirmed against `.claude/docs/directory-structure.md`)
- `godot/scripts/economy/crop_def.gd` — `CropDef`'s field layout
- `design/gdd/crop-economy.md` — design intent, formulas, and existing
  self-flagged concerns

### Health Summary: CONCERNS

Nothing here breaks the game or enables an obviously exploitable loop. The
concern is a real, previously-undocumented economic finding within Tier 1
specifically — everything else checked out consistent with the design
doc's own stated intent.

---

## The Crop Catalogue, By The Numbers

All 9 crops, with two derived columns not in the GDD's own table: raw
profit-per-second (`(sell − seed) / grow_seconds`) and weather-risk-adjusted
profit-per-second (damaged yield sells at `WEATHER_DAMAGE_YIELD_MULTIPLIER
= 0.5`, so expected value = `sell × (1 − risk% × 0.5)`).

| Crop | Plot Kind | Seed | Grow | Sell | Risk | ₹/sec (raw) | ₹/sec (risk-adj.) |
|---|---|---|---|---|---|---|---|
| Wheat 🌾 | Open Field | ₹10 | 2 min | ₹20 | 8% | **0.0833** | 0.0767 |
| Paddy 🌱 | Open Field | ₹30 | 20 min | ₹80 | 12% | 0.0417 | 0.0377 |
| Tomato 🍅 | Open Field | ₹60 | 2 hr | ₹240 | 15% | **0.0250** | 0.0225 |
| Capsicum 🫑 | Polyhouse | ₹150 | 40 min | ₹650 | 0%* | 0.2083 | 0.2083 |
| Dutch Rose 🌹 | Polyhouse | ₹220 | 1 hr | ₹1,100 | 0%* | 0.2444 | 0.2444 |
| Makhana 🪷 | Aquaculture | ₹400 | 6 hr | ₹1,800 | 0% | 0.0648 | 0.0648 |
| Pond Fish 🐟 | Aquaculture | ₹250 | 3 hr | ₹900 | 0% | 0.0602 | 0.0602 |
| Saffron 🌸 | Vertical Farm | ₹800 | 90 min | ₹3,500 | 0% | 0.5000 | 0.5000 |
| Sandalwood 🪵 (base) | Agroforestry | ₹5,000 | 21 days | ₹500,000 | 0%† | 0.2728 | — |
| Sandalwood 🪵 (Acacia) | Agroforestry | ₹5,000 | 14 days | ₹500,000 | 0%† | 0.4092 | — |

\* Assumes UV Film active — see `POLYHOUSE_UNPROTECTED_RISK_PERCENT` (10%) otherwise.
† Sandalwood risks theft, not weather — see Sandalwood note below, not
weather-risk-adjusted in this table.

---

## Outliers Detected

| Item/Value | Expected Range | Actual | Issue |
|---|---|---|---|
| Tomato's ₹/sec | ≥ Wheat's (later Tier-1 crop, higher cost, presumably an "upgrade") | **3.7× worse** than Wheat (0.0225 vs 0.0767, risk-adjusted) | Tomato is the single worst ₹/sec crop in the entire 9-crop catalogue — worse than every Tier 2-4 crop *and* worse than both other Open Field crops |
| Paddy's ₹/sec | Between Wheat and Tomato, or ≥ Wheat's | **2.0× worse** than Wheat (0.0377 vs 0.0767) | Same pattern, smaller magnitude |

## Degenerate Strategies Found

**Within Open Field specifically, Wheat strictly dominates Paddy and Tomato
on ₹/sec.** A player who understands the numbers has no economic reason to
ever plant Paddy or Tomato over repeated Wheat cycles, once affordability
stops being the binding constraint (Tomato's ₹60 seed cost is trivial past
the earliest minutes of play). This is a real intra-tier imbalance the
GDD's own "Balance Concerns Identified" section (§5) doesn't mention —
it only flags Sandalwood's payout (already known) and the missing
hard-currency system (a scope gap, not a formula issue).

**Important context — this may be intentional, not a bug**: the GDD's own
Player Fantasy section (§1) frames Tier 1 as "deliberately low-risk-
low-reward with short grow times... to build a daily-return habit," and
`v2.md`'s stated session-length target is "1-5 minute short loop." Read
that way, Tomato's *lower* ₹/sec but *larger single payout* and *longer,
lower-touch cycle* could be a deliberate ₹/tap-vs-₹/sec tradeoff — a
player who wants fewer check-ins over a longer stretch gets a bigger
single number, at a real ₹/sec cost, rather than Wheat's frequent-small-
payout rhythm. Both readings are defensible from the doc as written; this
report surfaces the number, not a verdict on which reading is correct.

## Progression Analysis

**Cross-tier progression is healthy and matches stated design intent.**
Every Tier 2+ crop (Capsicum, Dutch Rose, Makhana, Pond Fish, Saffron,
Sandalwood) earns more ₹/sec than every Open Field crop, confirming
`crop-economy.md` §1's "higher tiers trade capital intensity and wait
time for risk immunity and much higher margins" holds true as implemented
— this is *not* a finding, just confirmation the intended shape is real.

Within Tier 2+, Saffron (0.50/sec) is the standout — nearly 2× Sandalwood-
Acacia's rate and over 2× Dutch Rose's, the next-best. Saffron's Vertical
Farm has only `VERTICAL_FARM_PLOT_COUNT = 2` plots (vs. Polyhouse's 4,
Aquaculture's 5), and needs a recurring `ELECTRICITY_COST` (₹8,000 /
`ELECTRICITY_DURATION_MS`, 2 days) to keep planting — both real, but
minor, throttles on a raw per-plot rate this high. Not flagged as an
outlier on its own (the plot-count/electricity constraints are exactly
the kind of "capital intensity" tradeoff §1 describes), but worth keeping
in mind if Vertical Farm ever gets a 3rd+ plot slot in a future pass —
the rate would scale linearly with no compensating throttle.

Sandalwood's already-known concern (₹500,000 single payout, §5) stands
as previously documented — no new finding there beyond confirming the
₹/sec math (0.27-0.41/sec) is actually in line with, not wildly above,
the rest of Tier 2-4, once the ~21-day wait is accounted for. The real
risk in Sandalwood's design is the *lack of a discovered per-player cap*
on parallel Agroforestry tiles at scale (§5's own words), not the
per-tile rate itself.

## Recommendations

| Priority | Issue | Suggested Fix | Impact |
|---|---|---|---|
| MEDIUM | Tomato/Paddy underperform Wheat on ₹/sec within the same tier | **Your call, not this report's** — three real options exist: (a) leave as-is if the ₹/tap-vs-₹/sec tradeoff is intentional, (b) raise Tomato's/Paddy's `base_sell_price` or lower their `grow_seconds` in `game_data.gd` to close the gap, (c) explicitly document the tradeoff in `crop-economy.md` §5 as a confirmed intentional design, closing the ambiguity either way | Low engineering risk either way — a pure `game_data.gd` constant tweak if (b), a doc-only change if (a)/(c) |
| LOW | Saffron's rate has no plot-count throttle beyond the current fixed cap | No action needed now — only relevant if `VERTICAL_FARM_PLOT_COUNT` is ever raised | None today |

## Values That Need Attention

None require an immediate code change — this pass found a real economic
pattern worth your explicit decision, not a broken formula, an infinite-
resource loop, or an exploit. No values were changed by this report.

---

**This report was saved directly (Option B) rather than walking through a
live fix** — game-balance tuning is a real design/product call, not
something this session should decide unilaterally on your behalf, even
under a broad standing "keep working autonomously" instruction. Re-run
`/balance-check` after any fix to verify. The other four systems this
same "never run" gap applies to (`farmhouse-progression.md`,
`land-and-structures.md`, `liveops-events.md`, `mandi-trading.md`) are a
natural next pass, not done here.
