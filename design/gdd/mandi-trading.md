# Mandi Trading — Design Document

---
**Status**: Reverse-Documented
**Source**: `app/src/main/java/com/zonkrik/ifarming/game/GameData.kt` (Mandi constants), `GameViewModel.kt` (`currentGlut`, `mandiPriceMultiplier`, `mandiForecastPercent`, `buyMandi`, `buyMandiTerminal`, `sellToMandi`); original design in `v2.md`'s "The Mandi Trading Ecosystem and the e-NAM Integration" section
**Date**: 2026-08-18
**Verified By**: pending review
**Implementation Status**: Fully implemented
---

> **⚠️ Reverse-Documentation Notice**
>
> Created after the implementation already existed. Cross-references
> `crop-economy.md` (the `CropStock` inventory this system sells) and
> `farmhouse-progression.md` (`sellPriceMultiplier`, combined with this
> system's own market multiplier).

---

## 1. Overview

**Purpose**: A second, variable-price sale channel for harvested crops,
modeled on India's real Agricultural Produce Market Committee mandis and
the e-NAM (electronic National Agriculture Market) system — offered as an
alternative to `crop-economy.md`'s flat-rate `sellCrop`/`sellAll`, not a
replacement for it.

**Scope**: Mandi/terminal unlock costs, the demand-cycle/grade-bonus/glut
pricing model, and the forecast feature. **Out of scope**: the crops/
inventory being sold (`crop-economy.md`) and the farm-wide sell-price bonus
this system multiplies against (`farmhouse-progression.md`).

**Current Implementation**: Fully implemented — single-player, server-less
simulation of market dynamics (no actual multiplayer economy exists; the
"other players flooding the market" narrative from `v2.md` is simulated
purely from the local player's own sell history plus a deterministic
pseudo-random demand cycle).

**Design Intent** (from `v2.md`, confirmed matching code):
- **Why not free peer-to-peer trading**: the doc is explicit that
  "unrestricted peer-to-peer trading frequently leads to catastrophic
  exploitation" and that "developers have actively removed unrestricted
  player trading from newer titles" — the Mandi model exists specifically
  to give social/market-feel *without* the exploit surface, via
  developer-controlled price bands (`MANDI_MIN_MULTIPLIER`/`MAX_MULTIPLIER`)
  rather than player-set prices.
- **Grade-A bonus**: "crops grown in a well-maintained Fan and Pad polyhouse
  without weather debuffs receive an A-Grade certification" — implemented
  more broadly in code as *any* protected-cultivation crop (not
  Fan-and-Pad-specific), a simplification worth confirming intentional (see
  §7).
- **Glut mechanic**: "if thousands of players... flood the market... the
  backend detects oversupply and lowers the price" — since this is
  single-player, code implements this as the *player's own* recent Mandi
  sales creating localized price pressure on that specific crop, achieving
  the same "diversify your portfolio" incentive without needing a backend.
- **Forecast terminal**: "a digital auction terminal grants access to
  market forecasting tools... showing which crops are projected to be in
  high demand the following day" — implemented as a pure peek at next
  cycle's deterministic demand roll, available only after buying the
  terminal.

---

## 2. Detailed Design

### 2.1 Core Mechanics

**Unlocking**: `buyMandi` (₹3,000, one-time) grants access to the
`sellToMandi` channel at all. `buyMandiTerminal` (₹25,000, one-time,
requires Mandi already owned) additionally unlocks `mandiForecastPercent` —
tomorrow's demand swing, visible ahead of time.

**Selling** (`sellToMandi`): unlike `sellCrop`, this channel:
1. Applies a **dynamic market multiplier** (see §2.2) instead of a flat 1.0×
2. **Adds oversupply pressure** ("glut") to that specific crop, which decays
   over real time — selling a lot of one crop through the Mandi temporarily
   depresses that crop's own future Mandi price (not other crops')
3. Still applies the Farmhouse's `sellPriceMultiplier` on top, multiplicatively
4. Still feeds `registerFestivalSale` (see `liveops-events.md`) — Festival
   points accrue from Mandi sales exactly like direct sales

**The demand cycle**: every `MANDI_CYCLE_MS` (4h), each crop gets a fresh
deterministic demand swing (`-15%` to `+20%`), computed as a pure function
of `(crop, cycleIndex)` — **no server, no persisted state needed** for the
demand roll itself, since it's reproducible from wall-clock time alone.

### 2.2 Rules and Formulas

| Formula | Expression | Purpose | Verified? |
|---|---|---|---|
| Demand swing | `Random(seed = crop.ordinal×104,729 + cycleIndex×7,919).nextInt(-15, 21)` percent | Deterministic per-crop-per-cycle, no persistence needed | ✅ |
| Grade-A bonus | `+12%` if `crop.requiredPlotKind != OPEN_FIELD` (i.e. any protected-cultivation crop), else `0%` | Simplified from `v2.md`'s Fan-and-Pad-specific description — see §7 | ✅ (as coded) |
| Glut decay | `storedGlut × e^(−0.231 × hoursElapsed)` | Continuous exponential decay, ~halves every 3h | ✅ |
| Glut accrual | `decayedGlut + unitsSold × 0.02` | Added at time of sale, per unit | ✅ |
| Mandi price multiplier | `clamp(1.0 + demand% + gradeBonus% − glut, 0.6, 1.6)` | Combines all three factors, developer-controlled band | ✅ |
| Combined sell value | `qty × basePrice × mandiMultiplier × farmhouseSellMultiplier` (damaged stock additionally ×0.5) | Stacks with `farmhouse-progression.md`'s bonus multiplicatively | ✅ |
| Forecast | Same demand-swing formula, evaluated at `cycleIndex + 1` | "Tomorrow's" swing, peekable once the terminal is owned | ✅ |

**Clarifications**: The Grade-A bonus's simplification (any protected crop,
not specifically Fan-and-Pad-maintained ones) is a real, if minor,
divergence from `v2.md`'s literal description — flagged in §7 rather than
silently treated as "the design," since it's plausible this was a
deliberate simplification during implementation rather than a considered
design choice.

### 2.3 State and Data

**Data Structures**: `MandiGlut(value, updatedAtEpochMs)`, one entry per
crop in `GameState.mandiGlut: Map<CropType, MandiGlut>` (absent = no glut,
treated as `0.0`). `GameState.hasMandi`/`hasMandiTerminal`: booleans.

**State Machine**: None beyond the two one-way unlock flags — glut itself
isn't a discrete state machine, just a continuously-decaying scalar per
crop, recomputed lazily on read (`currentGlut`) rather than ticked.

**Persistence**: `hasMandi`, `hasMandiTerminal`, `mandiGlut` map — all part
of `GameState`.

### 2.4 Integration Points

**Dependencies**: `crop-economy.md` (the `CropStock` inventory sold here;
`registerFestivalSale`, actually owned by `liveops-events.md`, is called
from this system's `sellToMandi` too); `farmhouse-progression.md`
(`sellPriceMultiplier`).

**Dependents**: None — this is a terminal consumer, nothing reads Mandi
state except the UI layer.

**API Surface**: `buyMandi()`, `buyMandiTerminal()`, `sellToMandi(crop)`,
`currentGlut(state, crop, now)`, `mandiPriceMultiplier(state, crop, now)`,
`mandiForecastPercent(crop, now)`.

---

## 3. Edge Cases

**Handled in Code**:
- ✅ Selling with zero stock of a crop: silently no-ops
- ✅ Selling without owning the Mandi: silently no-ops (not just UI-hidden —
  enforced at the state layer too)
- ✅ Glut decayed below `0.001`: snapped to exactly `0.0` rather than left as
  an ever-shrinking float, avoiding floating-point residue
- ✅ Price multiplier always clamped to `[0.6, 1.6]` regardless of how
  extreme demand+grade−glut computes — can never go negative or unbounded

**Not Yet Handled**:
- ⚠️ No true multiplayer/shared-market simulation exists — by design, per
  `v2.md`'s own reasoning against unrestricted P2P, but worth being
  explicit that "server-wide oversupply" in the original doc is *not*
  implemented as anything beyond the single player's own sell history

**Unclear**:
- ❓ Grade-A bonus simplification (§2.2) — confirm intentional or align to
  `v2.md`'s literal "Fan-and-Pad-maintained Polyhouse only" description

---

## 4. Dependencies

**Technical Dependencies**: `kotlin.random.Random` (seeded, for demand
rolls — same deterministic-seeding pattern as `land-and-structures.md`'s
theft rolls), `kotlin.math.exp` (glut decay).

**Design Dependencies**: `crop-economy.md`, `farmhouse-progression.md`,
`liveops-events.md` (Festival point registration).

**Content Dependencies**: None beyond existing crop/emoji data.

---

## 5. Balance and Tuning

**Current Values**: see §2.2 table — all trace to `v2.md`'s described
mechanics; the price band (`0.6-1.6×`) and glut decay rate read as
deliberately chosen to keep Mandi prices in a bounded, non-exploitable range.

**Balance Concerns Identified**:
- ⚠️ None identified as clearly broken — the clamped band structurally
  prevents runaway pricing. Worth a `/balance-check` pass specifically
  comparing expected Mandi average value vs. direct-sale flat value across
  a full sell history, to confirm the Mandi is actually more profitable on
  average (its whole value proposition) rather than a coin-flip.

**Recommended Balance Pass**: ✅ Run 2026-08-22 —
`design/balance/balance-check-mandi-trading-2026-08-22.md`. Confirmed
healthy: Mandi averages ~14.5% above direct sale for protected-
cultivation crops (worst case nearly break-even) and ~2.5% above for
Open Field crops, though Open Field's worst-case demand roll (-15%)
*can* underperform flat direct sale — a real, intentional-reading
"gamble" for that tier, matching the design's own "alternative to Sell
All, not a replacement" framing. No values changed.

---

## 6. Acceptance Criteria

**What Exists**:
- ✅ Full Mandi unlock + terminal + demand cycle + glut + grade bonus + forecast
- ✅ Correctly stacks with Farmhouse's sell bonus and feeds Festival points

**What's Missing**: Nothing identified as unbuilt within scope.

**Definition of Done**:
- [x] Full pricing formula documented and verified against code
- [x] Glut decay/accrual mechanics documented
- [ ] Grade-A bonus simplification (§7) confirmed intentional or corrected

---

## 7. Open Questions and Follow-Up Work

### Questions Needing User Decision
1. **Grade-A bonus scope**: apply to any protected-cultivation crop (current
   code), or restrict to Fan-and-Pad-maintained Polyhouse crops specifically
   (literal `v2.md` description)?
   - Option A: Keep as-is — simpler rule, already shipped and presumably
     playtested
   - Option B: Narrow to match the original doc exactly

### Flagged Follow-Up Work
- [ ] Resolve the Grade-A bonus question above
- [x] Run `/balance-check` comparing Mandi vs. direct-sale expected value
      — done 2026-08-22, confirmed healthy, see §5.

---

## 8. Version History

| Date | Author | Changes |
|------|--------|---------|
| 2026-08-18 | Claude (reverse-doc) | Initial reverse-documentation from `game/` package + `v2.md` |

---

**Next Steps**: Draft `liveops-events.md` next — the last of the 5 planned economy GDDs.

**Related Skills**: `/balance-check`, `/architecture-decision`

---

*This document was generated by `/reverse-document design app/src/main/java/com/zonkrik/ifarming/game`*
