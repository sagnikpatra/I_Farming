# LiveOps Events — Design Document

---
**Status**: Reverse-Documented
**Source**: `app/src/main/java/com/zonkrik/ifarming/game/GameData.kt` (Monsoon/Festival constants, `FestivalDef`), `GameViewModel.kt` (`isMonsoonActive`, `monsoonPhaseRemainingMs`, Monsoon flood resolution in `resolveGrowthCompletions`, `isFestivalActive`, `currentFestival`, `festivalPhaseRemainingMs`, `withFreshEventOccurrence`, `buyPremiumPass`, `registerFestivalSale`); original design in `v2.md`'s "Live Operations, Dynamic Events, and Backend Flexibility" section
**Date**: 2026-08-18
**Verified By**: pending review
**Implementation Status**: Fully implemented
---

> **⚠️ Reverse-Documentation Notice**
>
> Created after the implementation already existed. Cross-references
> `crop-economy.md` (Monsoon's growth/flood override on open-field crops)
> and `mandi-trading.md`/`crop-economy.md` (both sale channels register
> Festival points).

---

## 1. Overview

**Purpose**: Two recurring, backend-free "live" events layered on top of
the core economy — Monsoon Season (a recurring risk/reward window for
open-field farming) and the Festival Event Pass (a Battle-Pass-style
progression track tied to real Indian festivals).

**Scope**: Both events' cycle/active-window timing, Monsoon's growth-speed/
flood mechanics, and the Festival Pass's points/tiers/premium-pass economy.
**Out of scope**: the crops/sales these events modify (`crop-economy.md`,
`mandi-trading.md` own those formulas; this doc treats them as places it
plugs in a multiplier or a points hook).

**Current Implementation**: Fully implemented. Notably: **entirely
client-computed from wall-clock time**, no backend/server exists — both
events' "cycles" are `now.mod(cycleLengthMs)` against fixed constants, not
anything a live-ops team pushes remotely. This is a deliberate architecture
choice (see `v2.md` excerpt below), not a placeholder for a future backend.

**Design Intent** (from `v2.md`, confirmed matching code, with one
significant divergence flagged):
- **Why LiveOps at all**: "the modern free-to-play ecosystem relies heavily
  on Live Operations to maintain player engagement... India's agriculture
  is deeply intertwined with the monsoon season, providing a perfect
  thematic wrapper for server-wide LiveOps events."
- **Monsoon**: doc describes "a server-wide Monsoon Season event lasting
  one real-world week... 20% faster... 10% chance of flooding... Polyhouse
  owners entirely immune." Code implements the same risk/reward shape but
  **massively compressed in real time** (6h cycle / 90min active window,
  not one real-world week) — consistent with the project's established
  pattern elsewhere of compressing multi-day/week real-world durations into
  shorter in-game equivalents (e.g. UV Film's "three in-game weeks"
  compressed to 3 real days, per `crop-economy.md`'s own code comments).
  The 20%/10% numbers themselves match exactly.
- **Festival Pass**: doc describes global leaderboards ("compete to supply
  the most sugarcane and rice") with cosmetic rewards (rangolis, machine
  skins) and a Premium Pass granting "accelerated growth timers, exclusive
  high-yield seeds, and premium cosmetics." **Significant divergence,
  already flagged in `crop-economy.md`'s original findings**: code has
  **no leaderboard** (single-player, no backend to compare players against)
  and the Premium Pass grants **only extra coin rewards per tier**, not
  accelerated timers or exclusive seeds/cosmetics. This is either a
  deliberate scope cut for a single-player build or a real gap — flagged
  in §7, not silently treated as "the design."

---

## 2. Detailed Design

### 2.1 Core Mechanics

**Monsoon Season**: recurring window, `now.mod(MONSOON_CYCLE_MS) <
MONSOON_ACTIVE_DURATION_MS` determines active/inactive
(`isMonsoonActive`). While active, **open-field crops only** (checked in
`crop-economy.md`'s `resolveGrowthCompletions`):
- Get a `0.8×` grow-time multiplier (20% faster) if planted while Monsoon is
  active — this is captured once at planting time, same
  snapshot-at-plant-time rule as every other speed modifier
- At grow-completion, roll a flat 10% chance of total crop loss (flood) —
  **replacing** the normal weather-damage roll entirely, not stacking with it
- **Polyhouse owners are structurally immune**: the flood check is gated on
  `plot.kind == OPEN_FIELD && !current.hasPolyhouse` — note this is
  "owns *a* Polyhouse" globally, not "this specific plot is a Polyhouse
  plot" (which would be redundant, since Polyhouse plots are never
  `OPEN_FIELD` anyway) — the immunity is real and correctly scoped to
  open-field plots only, gated on Polyhouse ownership as a whole-farm flag

**Festival Event Pass**: recurring window (`FESTIVAL_CYCLE_MS` = 8h,
`FESTIVAL_ACTIVE_DURATION_MS` = 60min active), cycling through 3 real
festivals in fixed rotation by `cycleIndex % 3` (Makar Sankranti → Pongal →
Baisakhi → repeat). Each festival has one **target crop** (Paddy for the
first two, Wheat for Baisakhi). While that festival is active, selling
*any quantity* of the target crop through *either* sale channel
(`sellCrop`/`sellAll` or `sellToMandi`) earns
`unitsSold × FESTIVAL_POINTS_PER_UNIT_SOLD (2)` points toward that
occurrence's tally. Points accumulate toward 3 fixed thresholds
(`FESTIVAL_TIER_THRESHOLDS = [50, 150, 300]`), each granting a one-time
coin reward (`FESTIVAL_FREE_REWARDS`) the moment it's first crossed, plus
an *additional* premium-only bonus (`FESTIVAL_PREMIUM_BONUS`) if the
Premium Pass was purchased for that occurrence.

**Fresh occurrence reset** (`withFreshEventOccurrence`): the moment
wall-clock time rolls into a new `cycleIndex`, that occurrence's `points`,
`hasPremiumPass`, and `claimedTier` all reset to zero/false — this is a
**pure function applied lazily on read** (called from every
Festival-related entry point, not a one-time transition), so no explicit
"event ended" processing is needed; the game simply always evaluates
against "the current occurrence" without caring whether it just changed.

### 2.2 Rules and Formulas

| Formula | Expression | Purpose | Verified? |
|---|---|---|---|
| Monsoon active | `now.mod(MONSOON_CYCLE_MS) < MONSOON_ACTIVE_DURATION_MS` | 6h cycle, 90min active window | ✅ |
| Monsoon speed bonus | `0.8×` grow time, open-field only, snapshotted at plant time | Matches `v2.md`'s 20% exactly | ✅ |
| Monsoon flood chance | `10%`, open-field + non-Polyhouse-owner only, replaces weather roll | Matches `v2.md` exactly | ✅ |
| Festival active | `now.mod(FESTIVAL_CYCLE_MS) < FESTIVAL_ACTIVE_DURATION_MS` | 8h cycle, 60min active window | ✅ |
| Current festival | `FESTIVALS[(now / FESTIVAL_CYCLE_MS) % 3]` | Fixed 3-festival rotation | ✅ |
| Festival points | `unitsSold × 2`, target crop only, either sale channel | Accrues during the active window | ✅ |
| Tier reward | Free: `[500, 1500, 4000]` at `[50, 150, 300]` points; Premium adds `[500, 1500, 4000]` more | Battle-Pass-style tiered payout | ✅ |

**Clarifications**: The real-world-time compression (Monsoon: 1 week →
6h/90min; matches the project's established pattern) and the Festival
Pass's coin-only-bonus simplification (vs. `v2.md`'s described
timer/seed/cosmetic rewards) are both treated as **discovered divergences**,
not silently corrected — see §7.

### 2.3 State and Data

**Data Structures**: `FestivalDef(displayName, emoji, targetCrop)` — 3
static instances in `GameData.FESTIVALS`. `GameState` fields:
`eventOccurrenceIndex` (which cycle these fields belong to, `-1` = never
initialized), `eventPoints`, `eventHasPremiumPass`, `eventClaimedTier`
(highest tier already granted this occurrence, 0-3).

**State Machine**: Implicit, not an explicit enum — "occurrence" identity
is just `now / FESTIVAL_CYCLE_MS`; `withFreshEventOccurrence` is the sole
transition function, applied idempotently on every read.

**Persistence**: The four `GameState` fields above; Monsoon has **no
persisted state at all** — it's purely a function of wall-clock time, no
`GameState` fields exist for it beyond what's already needed elsewhere
(`hasPolyhouse`).

### 2.4 Integration Points

**Dependencies**: `crop-economy.md` (Monsoon's growth/flood override plugs
into `resolveGrowthCompletions`; Festival's target-crop check reads
`CropType`); `mandi-trading.md` (Mandi sales also register Festival points).

**Dependents**: None — these are terminal modifiers, nothing else reads
LiveOps state.

**API Surface**: `isMonsoonActive(now)`, `monsoonPhaseRemainingMs(now)`,
`isFestivalActive(now)`, `currentFestival(now)`, `festivalPhaseRemainingMs(now)`,
`eventStatePreview(now)` (read-only, for UI), `buyPremiumPass()`,
(`registerFestivalSale` is called internally by both sale functions, not
player-facing directly).

---

## 3. Edge Cases

**Handled in Code**:
- ✅ Buying the Premium Pass outside an active Festival window: blocked
  with an info event
- ✅ Buying the Premium Pass twice in one occurrence: silently no-ops
  (`if (current.eventHasPremiumPass) return`)
- ✅ Crossing multiple tier thresholds in a single sale (e.g. selling enough
  at once to jump from 0 to 200 points): all newly-crossed tiers are
  awarded in one pass (`forEachIndexed` loop checks every threshold, not
  just the next one)
- ✅ Occurrence rollover mid-session: handled lazily and consistently
  everywhere via `withFreshEventOccurrence`, no special-cased "event ended"
  logic needed

**Not Yet Handled**:
- ⚠️ No leaderboard/multiplayer comparison exists, per the `v2.md`
  divergence in §1 — by apparent design for a single-player build, not
  flagged as broken, but worth confirming

**Unclear**:
- ❓ Premium Pass reward scope (coins only vs. `v2.md`'s described timers/
  seeds/cosmetics) — deliberate scope cut, or a gap to fill in later?

---

## 4. Dependencies

**Technical Dependencies**: Wall-clock `System.currentTimeMillis()` only —
no backend, no server-pushed event configuration.

**Design Dependencies**: `crop-economy.md`, `mandi-trading.md`.

**Content Dependencies**: 3 festival definitions (names/emoji/target crop)
already in code; no additional content identified as needed.

---

## 5. Balance and Tuning

**Current Values**: see §2.2 — Monsoon's numbers match `v2.md` exactly;
Festival's cadence/thresholds/rewards are original to the implementation
(not literally specified in `v2.md`'s prose beyond "tiered... free vs.
premium").

**Balance Concerns Identified**:
- ⚠️ Real-time compression means Monsoon (90min active out of every 6h) and
  Festival (60min active out of every 8h) windows could overlap
  unpredictably with typical play session lengths — worth confirming these
  cadences were chosen against actual expected session-length data, not
  arbitrarily.

**Recommended Balance Pass**: `/balance-check` on event cadence vs. the
project's stated session-length targets (`v2.md`'s "1-5 minute short loop /
15+ minute long loop" model).

---

## 6. Acceptance Criteria

**What Exists**:
- ✅ Both events fully functional, backend-free, wall-clock-driven
- ✅ Monsoon's speed/flood/Polyhouse-immunity mechanics complete
- ✅ Festival's points/tiers/premium-pass/dual-sale-channel integration complete

**What's Missing** (relative to `v2.md`, not relative to a "definition of
done" for the shipped feature):
- ❌ Leaderboard/multiplayer comparison (`v2.md`, not implemented)
- ❌ Premium Pass timer/seed/cosmetic rewards (`v2.md` describes them, code
  grants coins only)

**Definition of Done**:
- [x] Both events' timing/formulas documented and verified against code
- [x] Divergences from `v2.md` explicitly catalogued, not silently corrected
- [ ] Open questions in §7 resolved

---

## 7. Open Questions and Follow-Up Work

### Questions Needing User Decision
1. **Premium Pass reward scope**: keep coin-only bonuses (current, simpler),
   or build out the `v2.md`-described accelerated timers/exclusive seeds/
   cosmetics?
   - Option A: Keep as-is
   - Option B: Extend Premium Pass rewards per the original design doc
2. **Leaderboard**: is a single-player LiveOps model (no leaderboard) the
   permanent design, or a placeholder for an eventual backend?

### Flagged Follow-Up Work
- [ ] Resolve both questions above
- [ ] Run `/balance-check` on event cadence vs. session-length targets
- [ ] If Option B is chosen for the Premium Pass, this touches
      `crop-economy.md`'s grow-speed formula and would need a coordinated
      update there too

---

## 8. Version History

| Date | Author | Changes |
|------|--------|---------|
| 2026-08-18 | Claude (reverse-doc) | Initial reverse-documentation from `game/` package + `v2.md` |

---

**Next Steps**: All 5 planned economy GDDs are now written
(`crop-economy.md`, `land-and-structures.md`, `farmhouse-progression.md`,
`mandi-trading.md`, `liveops-events.md`). Next: populate the TR registry
and proceed to EPIC-M2's actual GDScript port.

**Related Skills**: `/balance-check`, `/architecture-decision`, `/architecture-review` (TR registry)

---

*This document was generated by `/reverse-document design app/src/main/java/com/zonkrik/ifarming/game`*
