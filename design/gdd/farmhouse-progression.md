# Farmhouse Progression — Design Document

---
**Status**: Reverse-Documented
**Source**: `app/src/main/java/com/zonkrik/ifarming/game/GameData.kt` (`FarmhouseLevel`, `FARMHOUSE_LEVELS`), `GameViewModel.kt` (`storageCapacity`, `growthSpeedMultiplier`, `sellPriceMultiplier`, `buyFarmhouseUpgrade`); original design in `v2.md`'s "The Ancestral Farmhouse" section
**Date**: 2026-08-18
**Verified By**: pending review
**Implementation Status**: Fully implemented
---

> **⚠️ Reverse-Documentation Notice**
>
> Created after the implementation already existed. Cross-referenced against
> `v2.md`. Cross-references `crop-economy.md` (consumes the growth-speed
> and sell-price multipliers this doc produces) and `land-and-structures.md`
> (Sandalwood's grow time also uses the growth-speed multiplier).

---

## 1. Overview

**Purpose**: The single central progression hub — an 8-tier home upgrade
that is simultaneously the game's primary long-term coin sink and the
source of three systemic, farm-wide bonuses (storage, growth speed, sell
price) that every other system depends on.

**Scope**: The `FarmhouseLevel` tier table, the upgrade purchase flow, and
the three multiplier functions it feeds into the rest of the economy.
**Out of scope**: how those multipliers are *applied* inside crop
growth/sale formulas (owned by `crop-economy.md`) or Mandi pricing (owned
by `mandi-trading.md`) — this doc treats itself as an upstream input
provider only.

**Current Implementation**: Fully implemented, 8 levels (0-7), fully linear
purchase path (no branching/choice).

**Design Intent** (from `v2.md`, confirmed matching code):
- **Player fantasy**: "a central visual representation of their success" —
  starting as "a humble rural home" and growing into "a sprawling,
  traditional Indian *Haveli* or modern agricultural estate." The level
  names in code (`Humble Hut → Kutcha House → Pucca House → Village
  Bungalow → Courtyard Haveli → Grand Haveli → Heritage Estate → Modern
  Agricultural Estate`) directly encode this real Indian rural-housing
  progression (kutcha = temporary/mud construction, pucca = permanent
  brick/concrete — an authentic terminology choice, not generic fantasy
  tier names).
- **Not cosmetic-only, by design**: "the farmhouse is not merely
  cosmetic; it acts as a central progression mechanic," explicitly
  justified in the doc as necessary infrastructure to "manage the high
  demands of Tier 3 and Tier 4 agriculture" (i.e., without Farmhouse
  investment, the storage/speed/price bonuses needed to run
  Agroforestry/Vertical-Farm-scale operations don't exist).
- **Deliberately exponential cost curve**: "a massive, infinitely scaling
  structural sink for soft currency" — costs are meant to feel steep at
  every tier, not smoothly rising.

---

## 2. Detailed Design

### 2.1 Core Mechanics

**The tier table** (`GameData.FARMHOUSE_LEVELS`, index = level):

| Lvl | Name | Emoji | Upgrade Cost | Storage | Growth Speed Bonus | Sell Price Bonus |
|---|---|---|---|---|---|---|
| 0 | Humble Hut | 🛖 | Free (starting) | 50 | +0% | +0% |
| 1 | Kutcha House | 🏠 | ₹2,000 | 100 | +3% | +2% |
| 2 | Pucca House | 🏠 | ₹8,000 | 200 | +6% | +4% |
| 3 | Village Bungalow | 🏡 | ₹25,000 | 350 | +9% | +6% |
| 4 | Courtyard Haveli | 🏡 | ₹75,000 | 550 | +12% | +8% |
| 5 | Grand Haveli | 🏰 | ₹200,000 | 800 | +15% | +10% |
| 6 | Heritage Estate | 🏰 | ₹500,000 | 1,200 | +18% | +12% |
| 7 | Modern Agricultural Estate | 🏛️ | ₹1,200,000 | 2,000 | +20% | +15% |

**Upgrade flow** (`buyFarmhouseUpgrade`): strictly sequential — always
upgrades from the current level to `current + 1`, never skips a tier, never
downgrades. Blocked at `FARMHOUSE_MAX_LEVEL` (index 7, the last tier).
`farmhouseLevelDef(level)` clamps out-of-range lookups to the last defined
tier (`getOrElse { FARMHOUSE_LEVELS.last() }`) rather than crashing — a
defensive fallback, not a normal code path.

**The three systemic bonuses**, each farm-wide and multiplicative:
- **Storage capacity** (`storageCapacity`): the hard cap on total
  harvested-but-unsold `CropStock` units (`totalInventoryUnits`); harvesting
  is blocked once full (see `crop-economy.md` §2.1).
- **Growth speed multiplier** (`growthSpeedMultiplier`):
  `1.0 − bonusPercent/100`, applied multiplicatively alongside Fan & Pad and
  Monsoon in `crop-economy.md`'s effective-grow-time formula, and to
  Sandalwood's grow time in `land-and-structures.md`.
- **Sell price multiplier** (`sellPriceMultiplier`): `1.0 + bonusPercent/100`,
  applied to every direct sale (`sellCrop`/`sellAll`) and combined
  multiplicatively with the Mandi's own market multiplier in
  `sellToMandi` (see `mandi-trading.md`).

### 2.2 Rules and Formulas

| Formula | Expression | Purpose | Verified? |
|---|---|---|---|
| Growth speed multiplier | `1.0 − growthSpeedBonusPercent / 100.0` | e.g. Level 7 → `0.80` = 20% faster | ✅ |
| Sell price multiplier | `1.0 + sellPriceBonusPercent / 100.0` | e.g. Level 7 → `1.15` = 15% more per sale | ✅ |
| Out-of-range level lookup | `FARMHOUSE_LEVELS.getOrElse(level) { .last() }` | Defensive clamp, not a real gameplay path | ✅ |

**Clarifications**: None — the tier table's costs/bonuses read as
hand-tuned to an exponential curve (`Cost` roughly ×3-4 per tier, doubling
past level 4) matching `v2.md`'s "massive, infinitely scaling structural
sink" intent exactly.

### 2.3 State and Data

**Data Structures**: `FarmhouseLevel(level, displayName, emoji,
upgradeCost, storageCapacity, growthSpeedBonusPercent,
sellPriceBonusPercent)` — a flat data class, no nested state. `GameState`
stores only a single `Int` (`farmhouseLevel`, default 0) — the entire tier
definition is derived from that index via `GameData.farmhouseLevelDef()`,
not persisted redundantly.

**State Machine**: Strictly linear, one-directional: `0 → 1 → 2 → ... → 7`,
no skips, no downgrades, no branches.

**Persistence**: Just the `Int` level index.

### 2.4 Integration Points

**Dependencies**: None — this is a pure, self-contained progression ladder
with no inputs beyond the player's coin balance.

**Dependents** (everything downstream that reads this doc's outputs):
- `crop-economy.md`: `growthSpeedMultiplier` in effective-grow-time;
  `sellPriceMultiplier` in direct-sale value; `storageCapacity` gates
  harvesting
- `land-and-structures.md`: `growthSpeedMultiplier` applied to Sandalwood
- `mandi-trading.md`: `sellPriceMultiplier` combined with the market
  multiplier in `sellToMandi`

**API Surface**: `storageCapacity(state)`, `totalInventoryUnits(state)`
(private helper, but conceptually part of this doc's surface),
`buyFarmhouseUpgrade()`, `farmhouseLevelDef(level)` (in `GameData`).

---

## 3. Edge Cases

**Handled in Code**:
- ✅ Upgrading past the max level: blocked, `return`s early
- ✅ Insufficient coins: blocked with an info event naming the shortfall
- ✅ Out-of-range level index (should never occur in practice): clamped to
  the last tier rather than crashing

**Not Yet Handled**: None identified — this is a small, closed system.

**Unclear**:
- ❓ No way to preview the *next* tier's bonuses before committing coins
  beyond what the UI layer chooses to show — not a gap in this state layer,
  but worth noting for whichever UI doc eventually covers the Farmhouse
  upgrade screen.

---

## 4. Dependencies

**Technical Dependencies**: None.

**Design Dependencies**: Consumed by `crop-economy.md`,
`land-and-structures.md`, `mandi-trading.md` — this doc has no dependencies
of its own, only dependents.

**Content Dependencies**: 8 emoji glyphs, already defined in code.

---

## 5. Balance and Tuning

**Current Values**: see §2.1 table.

**Balance Concerns Identified**:
- ⚠️ The jump from Level 6 (₹500,000) to Level 7 (₹1,200,000) is the
  steepest absolute jump in the table (2.4×, vs. roughly 2.4-3× at every
  other tier) — consistent with the curve, not obviously an outlier, but
  worth confirming intentional during a balance pass alongside Sandalwood's
  ₹500,000 payout (a single Sandalwood harvest could nearly fund a Level 6
  purchase outright).

**Recommended Balance Pass**: `/balance-check` on the full cost curve
against expected coin-earning rate at each game stage, cross-referenced with
`land-and-structures.md`'s structure costs and `crop-economy.md`'s
Sandalwood payout (all three are the game's largest currency sinks/faucets
and should be validated together, not independently).

---

## 6. Acceptance Criteria

**What Exists**:
- ✅ All 8 tiers with distinct names, costs, and three-part bonuses
- ✅ Strictly sequential upgrade path with correct blocking at cap
- ✅ All three bonus multipliers correctly feed into their consuming systems

**What's Missing**: Nothing identified as unbuilt.

**Definition of Done**:
- [x] Full tier table documented with formulas
- [x] All three dependent systems' consumption of these multipliers cross-referenced
- [ ] Balance concern in §5 resolved via `/balance-check`

---

## 7. Open Questions and Follow-Up Work

### Questions Needing User Decision
None blocking — this system is small, closed, and fully consistent with its
source design doc.

### Flagged Follow-Up Work
- [ ] Run `/balance-check` on the cost curve alongside Sandalwood's payout
      and the structure-tier costs (see `land-and-structures.md`)
- [ ] Consider whether a next-tier bonus preview belongs in a future UX doc

---

## 8. Version History

| Date | Author | Changes |
|------|--------|---------|
| 2026-08-18 | Claude (reverse-doc) | Initial reverse-documentation from `game/` package + `v2.md` |

---

**Next Steps**: Draft `mandi-trading.md`, `liveops-events.md` next.

**Related Skills**: `/balance-check`, `/architecture-decision`

---

*This document was generated by `/reverse-document design app/src/main/java/com/zonkrik/ifarming/game`*
