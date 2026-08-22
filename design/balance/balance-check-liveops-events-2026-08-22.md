# Balance Check: LiveOps Events

**Date**: 2026-08-22
**Trigger**: `design/gdd/liveops-events.md` §5's own "Recommended Balance
Pass" — never run. Fourth of the five economy docs sharing this gap.

### Data Sources Analyzed
- `godot/scripts/economy/game_data.gd` — Monsoon/Festival cycle and
  reward constants
- `godot/scripts/economy/game_economy.gd`'s `_with_fresh_event_occurrence()`
  — confirmed the Premium Pass's reset behavior directly in code, not
  assumed from the GDD's own prose
- `design/gdd/liveops-events.md`

### Health Summary: CONCERNS

Monsoon Season's numbers are clean and match design intent exactly. The
Festival Premium Pass has a real, previously-undocumented economic trap:
its expected value is negative unless the player reaches the top reward
tier in *every single* 8-hour occurrence they buy it for.

---

## Monsoon Season — Confirmed Healthy

`MONSOON_SPEED_MULTIPLIER = 0.8` (20% faster) and
`MONSOON_FLOOD_CHANCE_PERCENT = 10` both match §1's stated `v2.md` source
numbers exactly, with no discovered mismatch. Polyhouse immunity is
correctly scoped (gated on farm-wide `has_polyhouse`, applied only to
`OPEN_FIELD` plots — confirmed in code, matching the doc's own detailed
read of this). No finding here.

## The Festival Premium Pass — A Real Finding

**The Premium Pass resets every festival occurrence, not once per
purchase** — confirmed directly in `game_economy.gd`'s
`_with_fresh_event_occurrence()`: `event_has_premium_pass` is reset to
`false` the instant wall-clock time rolls into a new
`FESTIVAL_CYCLE_MS` (8-hour) cycle. A player must **rebuy it every 8
hours** (`FESTIVAL_PREMIUM_PASS_COST = 5,000`) for it to have any effect
that occurrence.

**Expected value by how far the player gets that occurrence** (tier
thresholds `[50, 150, 300]` points at `FESTIVAL_POINTS_PER_UNIT_SOLD = 2`
→ 25/75/150 units of that occurrence's target crop sold; premium bonus
`[500, 1,500, 4,000]` per tier, cumulative):

| Tier reached that occurrence | Premium bonus earned | Net vs. ₹5,000 cost |
|---|---|---|
| None / Tier 1 only (25 units) | ₹500 | **−₹4,500** |
| Through Tier 2 (75 units) | ₹2,000 | **−₹3,000** |
| Through Tier 3 (150 units) | ₹6,000 | **+₹1,000** |

**The pass only turns a profit if the player reaches Tier 3 — the full
150-unit threshold — in that same 8-hour occurrence, every single time
they buy it.** Reaching Tier 3 within the 60-minute active window
(`FESTIVAL_ACTIVE_DURATION_MS`) is achievable *if* the player has
pre-stockpiled 150 units of that occurrence's specific target crop
(Paddy for Makar Sankranti/Pongal, Wheat for Baisakhi) before the window
opens, since `sellAll()`/`sellCrop()` aren't rate-limited — but that's a
real, deliberate-preparation requirement, not something that happens
passively. A player who buys the pass "just in case" and doesn't
specifically prepare for that occurrence's target crop is very likely to
lose money on the purchase, not just underperform.

## Outliers Detected

| Item/Value | Expected Range | Actual | Issue |
|---|---|---|---|
| Premium Pass expected value | Should be ≥0 for a typical/average engagement level, per standard F2P premium-purchase design | Negative unless Tier 3 is reached that specific occurrence | A ₹5,000 purchase that loses money more often than not for anyone not actively optimizing around it |

## Degenerate Strategies Found

None exploitable in the player's favor — if anything, this is the
opposite: a purchase that looks like a value-add ("Premium Pass") but is
a net loss in the common case. Worth flagging for player-trust reasons
as much as pure balance ones — a purchase that frequently loses the
player money reads as a monetization trap even though this is a
soft-currency-only game with no real-money purchase behind it.

## Recommendations

| Priority | Issue | Suggested Fix | Impact |
|---|---|---|---|
| MEDIUM | Premium Pass EV is negative below Tier 3 | **Your call** — three real options: (a) lower `FESTIVAL_PREMIUM_PASS_COST` so even a Tier-1-only occurrence roughly breaks even, (b) let a purchased pass persist across occurrences instead of resetting every 8h (bigger behavior change), or (c) leave as-is if "a pass that rewards planning ahead, and punishes buying it casually" is the intended design — it's a coherent design stance, just not one this doc currently states explicitly | (a)/(c) are `game_data.gd`-constant or doc-only changes; (b) is a real economy-logic change, more involved |

## Values That Need Attention — Resolved 2026-08-22

`FESTIVAL_PREMIUM_PASS_COST` lowered from 5,000 to **400**
(`godot/scripts/economy/game_data.gd`) — chosen at or below
`FESTIVAL_PREMIUM_BONUS[0]` (500), so the smallest tier's own bonus
always covers the pass cost. New net-vs-tier table after the fix:

| Tier reached that occurrence | Premium bonus earned | Net vs. ₹400 cost |
|---|---|---|
| Tier 1 only (25 units) | ₹500 | **+₹100** |
| Through Tier 2 (75 units) | ₹2,000 | **+₹1,600** |
| Through Tier 3 (150 units) | ₹6,000 | **+₹5,600** |

Never negative for anyone who reaches at least Tier 1 that occurrence —
the "trap purchase" property is closed. Verified with a data-level
invariant test (`FESTIVAL_PREMIUM_PASS_COST <= FESTIVAL_PREMIUM_BONUS[0]`,
survives any future constant change) plus a real end-to-end test (buy
the pass, sell exactly 25 Paddy during Makar Sankranti, confirm the
Tier-1 reward alone covers the cost) in `test_game_economy.gd`. Full
suite re-verified 583/583 (up from 581/581), twice, non-flaky.

---

This closes the sweep's one clear-cut fix. Re-run `/balance-check` if
`game_data.gd`'s Festival constants ever change again to verify.
