# Thief System

> **Reverse-documented from implementation.** This GDD did not exist before
> now, despite being referenced throughout `game_economy.gd`,
> `thief_visitor.gd`, and `thief_visitor_placement.gd` as
> `design/gdd/thief-system.md`. Written to describe what was actually built
> and verified compile-clean this session (see
> `production/session-state/active.md`), not an aspirational spec authored
> before the code. Sections below call out what's implemented vs. what's
> still a gap explicitly, rather than presenting the whole system as done.

## Overview

Periodically, and gated by a cooldown, the farm has a chance of a thief
stealing coins. The chance scales up with the player's coin balance
(wealthier farms are more attractive targets) and scales down with a
security investment the player can make. Today the check runs, rolls
correctly, and notifies the player with a toast — but the player-facing
consequence (an actual coin loss, and the three-way let-go/bribe/chase
choice) is not yet wired up; see Acceptance Criteria.

## Player Fantasy

An occasional, low-frequency threat that makes hoarding coins feel
slightly risky rather than purely safe, and makes investing in security
(fencing, guard posts) feel like a real trade-off against spending on
farm growth instead. Not meant to be a frequent or punishing interruption
— a 12-hour cooldown and a low base probability keep it rare.

## Detailed Rules

1. **Cooldown gate.** A thief visit can only be considered once at least
   `THIEF_VISIT_INTERVAL_HOURS` (12h) have passed since
   `state.thief_last_visit_epoch_ms` (or since the game started, if never
   visited). Checked once per `resolve_growth_completions()` call — the
   same lazy, read-time resolution pattern as crop growth, not a live
   ticking timer (per ADR-0004).
2. **Probability roll.** Once past cooldown, each elapsed hour since the
   last visit gets its own deterministic seeded roll (see Formulas). The
   first hour that rolls a hit triggers the visit; the loop stops there.
3. **Security reduces probability**, it does not prevent visits outright.
   Three levels: 0 (none, ×1.0), 1 (fencing, ×0.5), 2 (guard posts, ×0.2).
4. **Steal amount** is a separate seeded roll in
   `[THIEF_STEAL_AMOUNT_MIN, THIEF_STEAL_AMOUNT_MAX]` (₹500–₹2,000),
   independent of the visit-probability roll.
5. **Player choice on a visit** (per `thief_interaction_sheet.gd`, built
   but not yet reachable in-game — see Acceptance Criteria):
   - **Let Them Go** — lose 100% of the steal amount.
   - **Pay Bribe** — lose `THIEF_BRIBE_PERCENTAGE` (50%) of the steal
     amount.
   - **Chase Them Off** — `THIEF_CHASE_SUCCESS_RATE` (30%) chance of
     success. On success, recover `THIEF_CHASE_RECOVERY_RATE` (75%) of
     the steal amount (lose the other 25%). On failure, lose 100% of the
     steal amount plus a `THIEF_CHASE_FAILURE_PENALTY` (₹50) flat
     penalty.

## Formulas

### Visit probability

```
hourly_probability(wealth, security_level) =
    (THIEF_PROBABILITY_BASE + wealth * THIEF_PROBABILITY_MULTIPLIER_PER_WEALTH)
    * security_multiplier(security_level)

security_multiplier(level) = 1.0 if level == 0
                            = 0.5 if level == 1
                            = 0.2 if level == 2

THIEF_PROBABILITY_BASE = 0.001            (0.1% base, per hour)
THIEF_PROBABILITY_MULTIPLIER_PER_WEALTH = 0.00001

Example: wealth = ₹10,000, security level 0
  hourly_probability = (0.001 + 10000 * 0.00001) * 1.0 = 0.101 (10.1%/hour)
Example: same wealth, security level 2 (guard posts)
  hourly_probability = 0.101 * 0.2 = 0.0202 (2.02%/hour)
```

Each candidate hour gets its own `RandomNumberGenerator` seeded from
`session_id * 1_000_007 + hour * 11_113` (where `session_id` is derived
from `farmhouse_level` and `total_harvests` — see `resolve_thief_visit()`)
so the same save state always resolves the same way for a given elapsed-
hours window, matching this codebase's existing deterministic-replay
pattern for Sandalwood theft (`was_sandalwood_stolen()`).

### Steal amount

```
steal_amount = round(random_uniform(THIEF_STEAL_AMOUNT_MIN, THIEF_STEAL_AMOUNT_MAX))
THIEF_STEAL_AMOUNT_MIN = 500
THIEF_STEAL_AMOUNT_MAX = 2000
```

Seeded from `session_id * 1_000_009 + hour_seed * 13_121` — a different
multiplier/salt than the visit-probability roll's seed, so the two rolls
don't correlate.

### Player-choice outcomes

```
let_go:    coins_lost = steal_amount
bribe:     coins_lost = round(steal_amount * THIEF_BRIBE_PERCENTAGE)          # 50%
chase, success (p = THIEF_CHASE_SUCCESS_RATE = 0.3):
           coins_lost = steal_amount - round(steal_amount * THIEF_CHASE_RECOVERY_RATE)  # lose 25%
chase, failure (p = 0.7):
           coins_lost = steal_amount + THIEF_CHASE_FAILURE_PENALTY            # 100% + ₹50

Example: steal_amount = ₹1,000
  let_go -> lose ₹1,000
  bribe  -> lose ₹500
  chase success (30%) -> lose ₹250
  chase failure (70%) -> lose ₹1,050
```

## Edge Cases

1. **Player never invests in security** — `security_level` stays 0
   forever; every roll uses the ×1.0 multiplier. Not a crash risk, just
   the highest-probability case.
2. **Multiple cooldown periods elapse while offline** — `elapsed_hours`
   is computed from the full gap since the last visit, and the roll loop
   checks every one of those hours in sequence (stops at the first hit).
   A long offline gap does not compound into a guaranteed visit or a
   pile-up of multiple visits — the function returns after resolving at
   most one visit per call.
3. **`thief_last_visit_epoch_ms == -1` (never visited)** — treated as
   "0 ms", so the very first `resolve_growth_completions()` call after a
   fresh save has a full elapsed-hours window to roll against rather than
   being skipped.
4. **Farmhouse level 0, zero harvests** — `session_id` is `0`, which is a
   valid (if degenerate) RNG seed base; rolls still vary hour-to-hour via
   the `hour * 11_113` term, so this doesn't produce a stuck always-same
   or always-false result.

## Dependencies

- **GameEconomy** — `resolve_thief_visit()`, called from
  `resolve_growth_completions()`.
- **GameState** — `thief_last_visit_epoch_ms`, `thief_security_level`,
  `total_theft_losses` (persisted fields; see Acceptance Criteria for
  which are actually written to today).
- **GameData** — all `THIEF_*` tuning constants.
- **ThiefVisitor** / **ThiefVisitorPlacement** (`village_board/`) — 3D
  board NPC and its tile-placement search (adjacent-to-Farmhouse, then
  nearby, then any walkable tile).
- **ThiefInteractionSheet** (`ui/`) — the player-choice bottom sheet.
- **Villager** (`village_board/villager.gd`) — reused for the thief's
  rendering/animation, same pattern as `ChandaVisitor`/`VillagerRoamer`.

## Tuning Knobs

| Knob | Current Value | Safe Range | Effect |
|------|---------------|------------|--------|
| `THIEF_VISIT_INTERVAL_HOURS` | 12 | 6–24 | Lower = more frequent visits |
| `THIEF_PROBABILITY_BASE` | 0.001 | 0.0005–0.005 | Floor probability even at ₹0 wealth |
| `THIEF_PROBABILITY_MULTIPLIER_PER_WEALTH` | 0.00001 | 0.000005–0.00005 | How sharply wealth raises risk |
| `THIEF_STEAL_AMOUNT_MIN` / `MAX` | 500 / 2,000 | keep ratio ≤ 1:5 | Stakes per visit |
| `THIEF_SECURITY_FENCING_COST` | ₹15,000 | — | Cost to reach security level 1 |
| `THIEF_SECURITY_GUARD_POSTS_COST` | ₹30,000 | — | Cost to reach security level 2 |
| `THIEF_BRIBE_PERCENTAGE` | 0.5 | 0.3–0.7 | Bribe should stay clearly cheaper than a failed chase |
| `THIEF_CHASE_SUCCESS_RATE` | 0.3 | 0.2–0.5 | Chase should stay a real gamble, not a safe default |
| `THIEF_CHASE_RECOVERY_RATE` | 0.75 | 0.5–1.0 | Reward for a successful chase |
| `THIEF_CHASE_FAILURE_PENALTY` | ₹50 | 0–200 | Extra punishment for a failed chase |

All constants live in `game_data.gd`'s `# --- LiveOps: Thief NPC Visitor
---` section — no hardcoded values in `game_economy.gd` itself, per this
project's data-driven gameplay-code rule.

## Acceptance Criteria

**Implemented and verified this session** (hand-traced against
`test_thief_system.gd`, 353 lines — GUT itself not yet run on this
machine, see session-state):
- [x] Cooldown correctly gates repeat visits within `THIEF_VISIT_INTERVAL_HOURS`
- [x] Visit-probability roll scales up with wealth, down with security level
- [x] Steal-amount roll is independent of the visit roll and stays within `[MIN, MAX]`
- [x] Rolls are deterministic/replayable for a given session_id + elapsed-hours window
- [x] `ThiefVisitorPlacement.find_thief_tile()` finds a valid board tile (adjacent → nearby → any walkable → `Vector2i(-1,-1)` if none)
- [x] `ThiefInteractionSheet` computes correct `coins_lost` for all three player choices

**Not implemented — real gaps, not just untested:**
- [ ] **No actual coin loss happens.** `resolve_thief_visit()` posts a
      toast event and updates the cooldown timestamp, but never deducts
      `state.coins`. The interaction sheet's `thief_choice_made` signal
      (which does carry the right `coins_lost`) has no caller anywhere —
      nothing connects it.
- [ ] **No board NPC ever spawns.** Nothing calls
      `ThiefVisitorPlacement.find_thief_tile()` or instantiates a
      `ThiefVisitor` from `resolve_thief_visit()` or anywhere else.
- [ ] **The interaction sheet never opens.** Nothing calls
      `ThiefInteractionSheet.open_for_thief()`.
- [ ] **Security level is not purchasable.** `state.thief_security_level`
      is read by the probability formula but nothing ever sets it above
      0 — there's no `buy_thief_security()`-equivalent function, despite
      `THIEF_SECURITY_FENCING_COST`/`THIEF_SECURITY_GUARD_POSTS_COST`
      existing as constants.
- [ ] **`state.total_theft_losses` is never incremented.** Persisted field
      with no writer.
- [ ] On-device APK: not yet verified.

Net effect right now: a thief visit is a periodic toast notification with
no economic consequence. The math and the two presentation pieces (board
NPC placement, choice sheet) are each independently correct and tested,
but the three are not connected to each other or to `state.coins`. Wiring
that up is the next real story here, not a small polish item.
