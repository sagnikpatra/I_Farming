# Land & Structures — Design Document

---
**Status**: Reverse-Documented
**Source**: `app/src/main/java/com/zonkrik/ifarming/game/GameData.kt`, `GameModels.kt`, `GameViewModel.kt`; original design in `v2.md` (Tier 2-4 sections)
**Date**: 2026-08-18
**Verified By**: pending review
**Implementation Status**: Fully implemented
---

> **⚠️ Reverse-Documentation Notice**
>
> Created after the implementation already existed. Cross-referenced against
> `v2.md`, the original economic design research doc. Cross-references
> `crop-economy.md` for the crops each tier unlocks and
> `farmhouse-progression.md` for the farm-wide multipliers this doc treats
> as external inputs.

---

## 1. Overview

**Purpose**: The land-expansion economy and the four cultivation-tier
structures (Polyhouse, Agroforestry, Aquaculture, Vertical Farm) that gate
access to progressively higher-value crops — the "capital-intensive
progression" spine of the game.

**Scope**: Marginal land pricing, each structure's unlock cost and
plot-count grant, each structure's own sub-economy (Polyhouse's Fan & Pad /
Drip Irrigation / UV Film consumables and subsidy quest; Agroforestry's host
plants and Sandalwood theft risk; Vertical Farm's Electricity credit). Also
covers the village board's zone-layout customization (drag/rotate/flip) and
the purely cosmetic decorations system, since both share the same
`ZoneAnchor`/tile-anchor mechanic. **Out of scope**: which crops go in which
plot kind (`crop-economy.md` owns the crop catalogue), Farmhouse-derived
multipliers (`farmhouse-progression.md`), Mandi pricing (`mandi-trading.md`).

**Current Implementation**: Fully implemented — land expansion + 4
structure tiers + zone layout + decorations, all working.

**Design Intent** (from `v2.md`, confirmed matching code):
- **Player fantasy**: "the paradigm shift from open-field subsistence to
  high-tech polyhouse cultivation, lucrative agroforestry, and specialized
  aquatic farming" — each tier is a deliberate capital-intensive investment
  that resets/re-engages the player's wealth-accumulation loop, not a
  smooth numeric upgrade.
- Marginal land pricing exists specifically so "late-game players still face
  financial pressure when expanding," per the doc's economy-balancing
  section (target: price = days-to-earn × daily disposable income).
- Polyhouse's Government Subsidy quest mirrors India's real Mission for
  Integrated Development of Horticulture subsidy scheme — a deliberate
  cultural/mechanical crossover, not incidental.
- Agroforestry/Sandalwood is explicitly the "elder-game structural sink...
  absorbing vast amounts of hoarded wealth" — the host-plant adjacency
  puzzle and theft risk are there to prevent it from being "mindless
  tapping" and to justify the Security sink.
- Vertical Farm/Saffron is explicitly the "min-max" alternative to
  Agroforestry's land-hungry model — "an alternative to the sprawling land
  requirements of Sandalwood agroforestry" for players optimizing
  revenue-per-tile rather than absolute payout.

---

## 2. Detailed Design

### 2.1 Core Mechanics

**Land expansion** (`buyLandExpansion`): adds one `OPEN_FIELD` plot at a
time, up to `MAX_PLOTS = 16` (open-field count specifically, not counting
structure-tier plots). Blocked once at cap.

**Polyhouse (Tier 2)**: one-time unlock grants `POLYHOUSE_PLOT_COUNT = 4`
new plots of kind `POLYHOUSE`. Cost is halved once the government subsidy is
unlocked (see §2.2). Three optional add-on purchases, each independently
gated on already owning a Polyhouse:
- **Fan & Pad** (`buyFanPad`, one-time): halves grow time for Polyhouse
  crops *and* fully negates weather risk, but only while UV Film is also
  active (see `crop-economy.md` §2.2's `speedBoosted` condition).
- **Drip Irrigation** (`buyDripIrrigation`, one-time): extends the
  post-harvest spoilage grace window from 4h to 24h.
- **UV Film** (`renewFilm`, recurring): must be renewed periodically
  (`UV_FILM_DURATION_MS`) or Polyhouse crops fall back to a 10% unprotected
  weather-risk chance.

**Agroforestry (Tier 3)**: one-time unlock clears a fixed
`AGROFORESTRY_GRID_SIZE × AGROFORESTRY_GRID_SIZE` (3×3 = 9 plots) adjacency
grid, each plot tagged with `agroRow`/`agroCol` for neighbor lookups.
Sandalwood (the only crop grown here — see `crop-economy.md`) cannot be
planted on a tile with no orthogonally-adjacent host plant. Host plants
(`HostType`: Pigeon Pea, Neem, Acacia) are placed instantly, occupy their
tile permanently instead of a grow cycle, and can be removed at will
(`removeHost`) to replant a different host. Acacia specifically shortens
Sandalwood's grow time (see `crop-economy.md`). **Security**
(`buySecurity`, one-time) sharply cuts Sandalwood theft odds — see §2.2.

**Aquaculture (Tier 4a)**: one-time unlock grants
`AQUACULTURE_PLOT_COUNT = 5` plots of kind `AQUACULTURE` (Makhana, Pond
Fish). No sub-economy beyond the unlock — "cheaper, lower-ceiling
alternative to Polyhouse," per its own code comment.

**Vertical Farm (Tier 4b)**: one-time unlock grants
`VERTICAL_FARM_PLOT_COUNT = 2` plots of kind `VERTICAL_FARM` (Saffron only).
Requires a recurring **Electricity** credit (`renewElectricity`) to be
active before *starting* any new Saffron grow — an already-growing crop is
unaffected if electricity lapses mid-grow (see `crop-economy.md`'s
`plantSeed` gating).

**Zone layout** (`moveZone`/`rotateZone`/`flipZone`): every structure zone
has a default anchor position; the player can drag/rotate (90° steps)/
mirror it, persisted per zone-id in `GameState.zoneLayout`, purely a layout
preference with **no cost or validation** — unlike decorations, this is
free and has no placement rules enforced at this layer (the 3D board's
ray-picking/collision layer is a separate concern, not owned by this
economy layer).

**Decorations** (`placeDecoration`/`removeDecoration`/`moveDecoration`/
`rotateDecoration`/`flipDecoration`): purely cosmetic placeable items
(`DecorationType`: potted Tulsi plant, Marigold, Bamboo, Diya lamp, Village
Well, Temple Shrine, Dirt Path, Rangoli), each with a coin cost and no
gameplay effect. Shares the same drag/rotate/flip interaction pattern as
zone layout but is a distinct, independently-IDed, addable/removable list
rather than one-anchor-per-fixed-zone.

### 2.2 Rules and Formulas

| Formula | Expression | Purpose | Verified? |
|---|---|---|---|
| Land expansion cost | `150 × 1.55^(openFieldCount − 3)`, rounded | Marginal pricing pressure | ✅ |
| Polyhouse cost | `subsidyUnlocked ? 17,500 : 35,000` | Subsidy quest halves price | ✅ |
| Subsidy unlock | `totalHarvests ≥ 25` (any crop, lifetime) | "Harvest a quota" quest per `v2.md` | ✅ |
| Polyhouse spoilage grace | `hasDripIrrigation ? 24h : 4h` | Consumable extends grace window | ✅ |
| Sandalwood theft (per elapsed hour, deterministic-seeded) | `Random(plotId×1,000,003 + hour×7,919).nextDouble() < hourlyProbability` | Independent per-hour Bernoulli roll, replayable across offline gaps | ✅ |
| Theft hourly probability | `0.00085` unprotected / `0.00006` secured (Security ≈ 14× safer) | Compounds to a real risk over multi-week grows | ✅ |
| Sandalwood grow time | `21 days` base / `14 days` w/ an Acacia neighbor | "Optimized" host per `v2.md` | ✅ |
| Agroforestry adjacency | Manhattan distance 1 in the fixed 3×3 `agroRow`/`agroCol` grid | Host-plant placement puzzle | ✅ |

**Clarifications**: All values trace directly to `v2.md`'s real-world-cost
translation table (e.g. "₹32-38 Lakhs/acre → 35,000 Coins" for the base
Polyhouse) — no discovered mismatch between doc and code.

### 2.3 State and Data

**Data Structures**:
- `PlotKind` (enum): `OPEN_FIELD | POLYHOUSE | AGROFORESTRY | AQUACULTURE | VERTICAL_FARM`
- `HostType` (enum): `PIGEON_PEA(₹15) | NEEM(₹200) | ACACIA(₹350)`
- `Plot.agroRow`/`agroCol`/`hostType`: only meaningful for `AGROFORESTRY` plots
- `ZoneAnchor(tileX, tileY, rotationDegrees, flippedX)`, keyed by zone-id string in `GameState.zoneLayout`
- `DecorationType` (enum, 8 values, each with cost); `Decoration(id, type, tileX, tileY, rotationDegrees, flippedX)` in `GameState.decorations`; `GameState.nextDecorationId` auto-increment

**State Machine**: Structure unlocks are one-way boolean flags
(`hasPolyhouse`, `hasAgroforestry`, `hasAquaculture`, `hasVerticalFarm`,
`hasSecurity`, `hasFanPad`, `hasDripIrrigation`) — no downgrade path exists
anywhere in the code.

**Persistence**: All flags/timestamps/plots/zoneLayout/decorations are part
of the top-level `GameState`, fully persisted.

### 2.4 Integration Points

**Dependencies**: `crop-economy.md` (which crops each `PlotKind` unlocks,
and the theft/spoilage resolution's interaction with the plot lifecycle);
`farmhouse-progression.md` (`growthSpeedMultiplier` applied to Sandalwood's
grow time, per §2.2).

**Dependents**: `crop-economy.md`'s `resolveGrowthCompletions` reads
`hasSecurity`/`hasDripIrrigation`/theft state directly. `villagers.md`'s
villager-count formula reads the structure-unlock boolean flags in §2.3
(`hasPolyhouse`/`hasAgroforestry`/`hasAquaculture`/`hasVerticalFarm`) as a
read-only input — this doc's economy logic has no dependency back on
villagers. `worker-economy.md` (EPIC-M7, drafted) reads which zones exist
and are unlocked, since a worker is assigned to a zone this doc owns —
also read-only, no dependency back.

**API Surface**: `buyLandExpansion`, `buyPolyhouse`, `buyFanPad`,
`buyDripIrrigation`, `renewFilm`, `buyAgroforestry`, `buySecurity`,
`plantHost`, `removeHost`, `plantSandalwood`, `canPlantSandalwood`,
`buyAquaculture`, `buyVerticalFarm`, `renewElectricity`, `moveZone`,
`rotateZone`, `flipZone`, `placeDecoration`, `removeDecoration`,
`moveDecoration`, `rotateDecoration`, `flipDecoration`.

---

## 3. Edge Cases

**Handled in Code**:
- ✅ Land expansion at `MAX_PLOTS`: blocked with an info event
- ✅ Re-buying an already-owned structure/add-on: silently no-ops (`return`)
- ✅ Sandalwood theft re-evaluated consistently across offline gaps (seeded
  per plot+hour, not per real-time-elapsed-since-last-check)
- ✅ Removing a host plant that has an adjacent growing Sandalwood: allowed
  (`removeHost` has no adjacency-safety check) — the Sandalwood keeps
  growing on its already-locked-in `effectiveGrowSeconds`, it just loses
  future replant eligibility from that host once harvested/stolen
- ✅ Zone drag/rotate/flip has no cost or failure mode — always succeeds

**Not Yet Handled**:
- ⚠️ No way to sell back/downgrade a structure once bought — a deliberate
  one-way sink per the design intent, but worth confirming that's permanent
  intent rather than a missing feature

**Unclear**:
- ❓ `moveZone`/decoration placement has **no collision/overlap validation**
  at this state layer — is that intentional (validation belongs entirely to
  the 3D board's ray-picking layer) or a gap that should be enforced here
  too, especially now that the Godot migration is rebuilding that
  interaction layer from scratch (see `docs/architecture/godot-migration-roadmap.md`
  EPIC-M3)?

---

## 4. Dependencies

**Technical Dependencies**: `kotlin.random.Random` (seeded, for theft rolls)

**Design Dependencies**: `crop-economy.md`, `farmhouse-progression.md`

**Content Dependencies**: None beyond emoji glyphs already in `DecorationType`/`HostType`

---

## 5. Balance and Tuning

**Current Values**: see §2.1/§2.2 tables — all trace to `v2.md`'s real-world
cost-equivalency research, treated as deliberately tuned.

**Balance Concerns Identified**:
- ⚠️ Theft probability compounding: `crop-economy.md` already flags
  Sandalwood's payout as needing a `/balance-check` pass; the theft-risk
  curve (unprotected vs. secured) should be validated together with that
  payout, not independently.
- ⚠️ Land expansion's exponential cost has no stated ceiling narrative
  beyond `MAX_PLOTS = 16` — confirm 16 is a deliberate final cap, not a
  placeholder.

**Recommended Balance Pass**: `/balance-check` across land cost curve +
all 4 structure unlock costs + Sandalwood theft/payout together, since
they're the game's primary large-currency sinks.

### Sub-Upgrade Visual Cue (built 2026-08-22)

`feature-scoping-2026-08-22.md` item 1's own text originally floated
"small visual attachments (fence, shed, tint)" for Polyhouse's Fan &
Pad/UV Film/Drip Irrigation, Agroforestry's Security, and Vertical
Farm's Electricity sub-upgrades, without settling which. Decided and
built: **a shared warm emissive tint on the structure's own existing
material, intensity scaling with how many of its own sub-upgrades are
currently active** -- not distinct attachment meshes or per-flag colors.

- **Why tint over attachment meshes**: no sourced 3D asset exists for
  any of the 4 add-ons (a fence, a fan unit, a film sheet, a security
  post are all unmodeled), and building them from scratch is real
  content-creation scope this pass doesn't take on -- the same
  reasoning `real-time-day-night.md`'s villager lamp-lighting stretch
  goal already used to choose a built-in engine light over a sourced
  model. A tint needs no new asset at all.
- `VillageSnapshotMapper` computes `ZoneFixture.active_upgrade_count`
  per zone (Polyhouse: `has_fan_pad` + `has_drip_irrigation` +
  currently-unexpired UV film, each worth 1; Agroforestry: `has_security`
  worth 1; Vertical Farm: currently-unexpired electricity worth 1;
  Aquaculture: always 0 -- it has no sub-upgrade of its own in
  `GameState` today). Time-limited upgrades (UV film, electricity) are
  evaluated against a real `now` threaded through `build()`, mirroring
  `game_economy.gd`'s own `is_film_active()`/`is_electricity_active()`
  exactly (duplicated rather than depending on a `GameEconomy` instance,
  since the mapper is a pure `GameState` function).
- `village_board.gd` applies the tint as an additive emissive boost on
  the building's own material(s) (found the same way toon-shading
  already patches them), not a base-color replacement -- the structure's
  tier-specific model/color (`farmhouse-visual-tiers.md`) and Day/Night/
  seasonal lighting (`real-time-day-night.md`) both stay fully visible
  underneath it.
- **A real tuning correction made from an actual on-device screenshot,
  not guessed**: the first intensity chosen (`UPGRADE_TINT_STEP=0.35`,
  `MAX=1.0`) was verified genuinely too subtle to read against bright
  daytime ambient light -- additive emission needs far more energy to
  compete with strong ambient lighting than it does at Night (where the
  villager-lamp glow read clearly at similar values, against much
  darker ambient). Re-tuned to `STEP=1.2`/`MAX=3.5` and re-verified on
  the same device against the same real save state before/after --
  visibly, clearly brighter the second time.
- **Not** per-flag distinguishable at a glance (a fully-upgraded
  Polyhouse looks identical regardless of *which* 3 upgrades are active)
  -- a deliberate, documented scope reduction from the original brief's
  "communicates which add-ons are active" ambition, not an oversight.

---

## 6. Acceptance Criteria

**What Exists**:
- ✅ Marginal-pricing land expansion, capped
- ✅ All 4 structure tiers with their full sub-economies
- ✅ Zone layout customization (free, unvalidated)
- ✅ Decorations (paid, cosmetic, unvalidated)
- ✅ Sub-upgrade visual cue (§5, built 2026-08-22) -- Polyhouse/
  Agroforestry/Vertical Farm's own add-ons now visibly tint their
  structure; see that section for what's verified vs. tested

**What's Missing**: Nothing identified as unbuilt within this doc's scope.

**Definition of Done**:
- [x] Every structure's unlock cost, plot grant, and sub-economy documented
- [x] Sandalwood's theft/host mechanics fully specified
- [ ] Open question in §3 (layout/decoration collision validation) resolved
- [x] `active_upgrade_count` is independently unit-testable as pure logic
      against a real `GameState`, driven through `GameEconomy`'s real
      `buy_*`/`renew_*` methods -- `tests/unit/test_village_snapshot_mapper.gd`
      (10 new tests: per-structure counts, an expired-upgrade exclusion
      for each time-limited flag, Aquaculture's always-zero case, and
      `build()`'s own backward-compatible default).
- [x] Full GUT suite green (528/528 at the time this was built).
- [x] Verified on-device via a temporary forced-purchase override
      (reverted before commit): all 3 upgradeable structures fully
      upgraded, confirmed visibly tinted with no crash, using the real
      save state's actual coin balance restored afterward (the override
      only mutated in-memory state during the verification session --
      `_ready()` never itself persists to disk, so the player's real save
      was never at risk).

---

## 7. Open Questions and Follow-Up Work

### Questions Needing User Decision
1. **Zone/decoration collision validation**: should this economy layer
   enforce non-overlap, or does that stay entirely a 3D-board concern?
   - Option A: Leave as-is — pure layout preference, no validation here
   - Option B: Add a basic overlap check at this layer too, so it's
     enforced regardless of which rendering layer (LibGDX or Godot) is active

### Flagged Follow-Up Work
- [ ] Run `/balance-check` across land cost + all 4 structure economies
- [ ] Confirm `MAX_PLOTS = 16` is a deliberate final cap
- [ ] Resolve the collision-validation open question, especially relevant
      now given the Godot migration's EPIC-M3 (board interaction) is being
      rebuilt from scratch

---

## 8. Version History

| Date | Author | Changes |
|------|--------|---------|
| 2026-08-18 | Claude (reverse-doc) | Initial reverse-documentation from `game/` package + `v2.md` |

---

**Next Steps**: Draft `farmhouse-progression.md`, `mandi-trading.md`, `liveops-events.md` next.

**Related Skills**: `/balance-check`, `/architecture-decision`

---

*This document was generated by `/reverse-document design app/src/main/java/com/zonkrik/ifarming/game`*
