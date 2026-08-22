# Crop Economy — Design Document

---
**Status**: Reverse-Documented
**Source**: `app/src/main/java/com/zonkrik/ifarming/game/GameModels.kt`, `GameData.kt`, `GameViewModel.kt`; original economic design in `v2.md` (Tier 1-4 sections)
**Date**: 2026-08-18
**Verified By**: pending review
**Implementation Status**: Fully implemented
---

> **⚠️ Reverse-Documentation Notice**
>
> This design document was created **after** the implementation already existed.
> It captures current behavior, cross-referenced against `v2.md` (the original
> economic design research doc the code's comments repeatedly cite as "the
> design doc"). Sections owned by other GDDs (land/structure purchases,
> Farmhouse bonuses, Mandi pricing, LiveOps events) are cross-referenced, not
> re-explained — see `design/gdd/land-and-structures.md`,
> `farmhouse-progression.md`, `mandi-trading.md`, `liveops-events.md`.

---

## 1. Overview

**Purpose**: The core planting → growing → harvesting → selling loop that
every other economic system (land, structures, Farmhouse, Mandi, LiveOps)
hooks into. It is the "heartbeat" loop per `v2.md`'s Core Game Loop section.

**Scope**: `CropType` catalog, `PlotState` lifecycle, weather/pest risk
resolution for open-field crops, harvest-time yield quality (normal vs.
damaged), and the flat-rate direct-sale channel (`sellCrop`/`sellAll`).
Explicitly **out of scope** (owned elsewhere): which structure unlocks which
plot kind, Sandalwood's theft mechanic, Farmhouse growth/sell multipliers,
Mandi's dynamic pricing, Monsoon/Festival LiveOps windows — this doc treats
those as external modifiers it plugs into its own formulas.

**Current Implementation**: Fully implemented — 9 crops across 5 plot kinds,
lazy (read-time) growth resolution, deterministic weather/damage rolls.

**Design Intent** (from `v2.md`, confirmed matching code):
- **Player fantasy**: progression from a poor farmer's rudimentary open-field
  plot to capital-intensive, high-tech, high-value cultivation — "the
  paradigm shift from open-field subsistence to high-tech polyhouse
  cultivation, lucrative agroforestry, and specialized aquatic farming."
- Tier 1 (open field) is deliberately low-risk-low-reward with short grow
  times (2 min–2 hr) to build a daily-return habit and function as tutorial.
- Weather/pest risk on exposed open-field crops exists specifically to create
  **loss aversion** — players feel the threat of losing part of their
  investment, motivating them to seek protected-cultivation upgrades.
- Higher tiers trade capital intensity and wait time for risk immunity and
  much higher margins, reinforcing the tiered-investment fantasy rather than
  being purely a numbers-go-up progression.

---

## 2. Detailed Design

### 2.1 Core Mechanics

**Crop Catalogue** (`CropType` enum — `GameModels.kt`):

| Crop | Plot Kind | Seed Cost | Grow Time | Base Sell | Weather Risk |
|---|---|---|---|---|---|
| Wheat 🌾 | Open Field | ₹10 | 2 min | ₹20 | 8% |
| Paddy 🌱 | Open Field | ₹30 | 20 min | ₹80 | 12% |
| Tomato 🍅 | Open Field | ₹60 | 2 hr | ₹240 | 15% |
| Colored Capsicum 🫑 | Polyhouse | ₹150 | 40 min | ₹650 | 0%* |
| Dutch Rose 🌹 | Polyhouse | ₹220 | 1 hr | ₹1,100 | 0%* |
| Sandalwood 🪵 | Agroforestry | ₹5,000 | 21 days (14 w/ Acacia) | ₹500,000 | 0%† |
| Makhana (Fox Nut) 🪷 | Aquaculture | ₹400 | 6 hr | ₹1,800 | 0% |
| Pond Fish 🐟 | Aquaculture | ₹250 | 3 hr | ₹900 | 0% |
| Saffron 🌸 | Vertical Farm | ₹800 | 90 min | ₹3,500 | 0% |

\* Polyhouse crops instead use `POLYHOUSE_UNPROTECTED_RISK_PERCENT` (10%)
whenever the UV Film has lapsed — see §2.2 and `land-and-structures.md`.
† Sandalwood has no weather roll; it risks theft instead — see
`land-and-structures.md`.

**Plot Lifecycle** (`PlotState` sealed class):
```
Empty --plantSeed()--> Growing --[time elapses]--> ReadyToHarvest --harvestPlot()--> Empty
```
- `Growing` captures `effectiveGrowSeconds` **at planting time** — a snapshot
  of whatever speed bonuses (Fan & Pad, Farmhouse level, Monsoon) were active
  then. Buying a speed upgrade mid-grow does not retroactively speed up
  crops already planted; only the next planting benefits.
- Growth resolution is **lazy**: `resolveGrowthCompletions(now)` walks every
  `Growing` plot and transitions it once `now - plantedAtEpochMs >=
  effectiveGrowSeconds * 1000`, run on state-read rather than via a live
  ticking timer. This is what makes offline growth "just work" — the app
  doesn't need to run in the background.
- `ReadyToHarvest` records whether the yield was `weatherDamaged` at the
  moment it finished growing; damage quality is locked in then, not at
  harvest time (Polyhouse spoilage is the one *harvest-time* damage check —
  see `land-and-structures.md`).

**Planting rules** (`plantSeed`):
- Plot must be `Empty` and its `kind` must match `crop.requiredPlotKind`.
- Player must afford `crop.seedCost`.
- Saffron additionally requires an active Electricity credit (Vertical Farm
  operating cost — see `land-and-structures.md`) to start.
- Sandalwood has its own entry point (`plantSandalwood`) — Agroforestry
  adjacency + host-plant requirements are handled there, not here.

**Harvesting rules** (`harvestPlot`):
- Blocked if inventory is already at `storageCapacity` (Farmhouse-derived —
  see `farmhouse-progression.md`); the player must sell or upgrade first.
- Yield goes to `CropStock.normal` or `CropStock.damaged` depending on
  whether it was weather-damaged (Tier 1-2) or arrived spoiled (Polyhouse
  grace-window expiry, checked at harvest time).
- Increments `totalHarvests`, which gates the Polyhouse subsidy unlock (see
  `land-and-structures.md`).

**Direct sale** (`sellCrop`/`sellAll`):
- Always available, no market dynamics — a guaranteed-price fallback to the
  Mandi's variable pricing (`mandi-trading.md`). Damaged stock always sells
  at a flat 50% of normal value regardless of channel.

### 2.2 Rules and Formulas

| Formula | Expression | Purpose | Verified? |
|---|---|---|---|
| Effective grow time | `growSeconds × (FanPad&Polyhouse&FilmActive? 0.5:1) × farmhouseGrowthMultiplier × (Monsoon&OpenField? 0.8:1)`, rounded, min 1s | Snapshotted once at planting | ✅ |
| Open-field weather/pest risk | `crop.weatherRiskPercent` (8-15%, per crop) | Loss-aversion pressure on Tier 1 | ✅ |
| Polyhouse risk | `0%` if UV Film active, else `10%` (`POLYHOUSE_UNPROTECTED_RISK_PERCENT`) | Rewards keeping the Film renewed | ✅ |
| Agroforestry/Aquaculture/Vertical Farm risk | `0%` (weather-immune by design) | Managed/indoor cultivation is sheltered | ✅ |
| Damage roll | `Random.nextInt(100) < risk` | Per-plot independent Bernoulli trial at grow-completion | ✅ |
| Direct sale value | `qty_normal × basePrice × sellMultiplier + qty_damaged × basePrice × 0.5 × sellMultiplier` | Flat-rate sale, no market dynamics | ✅ |
| Damaged-yield multiplier | `WEATHER_DAMAGE_YIELD_MULTIPLIER = 0.5` | Damaged crops still sell, just at a steep discount, not zero | ✅ |

`sellMultiplier` here is the Farmhouse's farm-wide `sellPriceBonusPercent`
(see `farmhouse-progression.md`) — this doc treats it as an opaque input.

**Clarifications**: None — every value above traces directly to `v2.md`'s
Tier 1 description (short grow times, per-crop weather risk creating loss
aversion) with no discovered mismatch between doc and code.

### 2.3 State and Data

**Data Structures**:
- `CropType` (enum): `displayName`, `emoji`, `seedCost`, `growSeconds`,
  `baseSellPrice`, `weatherRiskPercent`, `requiredPlotKind`
- `Plot`: `id`, `kind: PlotKind`, `state: PlotState`, plus Agroforestry-only
  `agroRow`/`agroCol`/`hostType` (see `land-and-structures.md`)
- `PlotState`: `Empty | Growing(crop, plantedAtEpochMs, effectiveGrowSeconds)
  | ReadyToHarvest(crop, weatherDamaged, readyAtEpochMs)`
- `CropStock(normal, damaged)` — per-crop harvested-but-unsold inventory;
  `total` is a derived sum

**State Machine**: see §2.1's lifecycle diagram.

**Persistence**: All of the above lives in `GameState` and is
JSON-serialized via `GameRepository`/`persist()` after every mutating call —
nothing here is session-only or recomputed from scratch on load. Growth
*completion*, however, is recomputed lazily against wall-clock time on every
read, not stored as "already resolved."

### 2.4 Integration Points

**Dependencies**:
- `land-and-structures.md` — which plot kinds exist, their risk/speed
  modifiers (Fan & Pad, UV Film, Electricity), and Sandalwood's
  theft-instead-of-weather resolution
- `farmhouse-progression.md` — `storageCapacity`, `growthSpeedMultiplier`,
  `sellPriceMultiplier`
- `liveops-events.md` — Monsoon's speed/flood override for open-field crops

**Dependents**:
- `mandi-trading.md` — sells the same `CropStock` inventory this doc
  produces, through a variable-price channel instead of the flat direct sale
- `liveops-events.md` — Festival sales are registered against units sold
  through *either* sale channel
- `worker-economy.md` (EPIC-M7, drafted) — an assigned worker calls this
  doc's `harvestPlot()`/`plantSeed()` on the player's behalf, reusing the
  lazy `resolveGrowthCompletions()`-style offline-resolution pattern
  rather than a new mechanism; every rule in this doc (weather risk,
  inventory-capacity blocking, affordability) still applies to an
  automated call exactly as it does to a manual one

**API Surface**:
- `plantSeed(plotId, crop)`, `harvestPlot(plotId)`, `sellCrop(crop)`,
  `sellAll()` — the four player-facing actions
- `resolveGrowthCompletions(now)` — internal, called before every state read

---

## 3. Edge Cases

**Handled in Code**:
- ✅ Storage full at harvest time: blocked with an info event, plot stays
  `ReadyToHarvest` until the player makes room
- ✅ Offline growth: lazy resolution means a plot planted before the app was
  closed resolves correctly (including weather rolls) the next time state is
  read, however long the gap
- ✅ Crop/plot-kind mismatch: planting silently no-ops if `crop.requiredPlotKind
  != plot.kind`
- ✅ Deterministic-but-fresh randomness: weather/damage rolls use
  `Random.nextInt` per resolution call (not seeded to plot+time), so replaying
  the same elapsed-time gap does *not* reproduce the same roll — unlike
  Sandalwood's theft check, which is deliberately seeded (see
  `land-and-structures.md`)

**Not Yet Handled**:
- ⚠️ A `ReadyToHarvest` open-field crop that sits unharvested indefinitely
  never spoils — only Polyhouse crops have a spoilage grace window. This
  asymmetry isn't called out anywhere as intentional vs. an oversight.

**Unclear**:
- ❓ Should open-field/Aquaculture/Vertical-Farm `ReadyToHarvest` stock ever
  degrade if left too long, matching Polyhouse's spoilage pressure? `v2.md`
  doesn't mention it for Tier 1, so current asymmetry may be intentional
  (only "expensive perishables" spoil) — flagged for confirmation rather than
  assumed.

---

## 4. Dependencies

**Technical Dependencies**:
- `kotlin.random.Random` — unseeded per-call rolls for weather/damage
- Wall-clock `System.currentTimeMillis()` — all timing is real-time based, no
  server/backend clock

**Design Dependencies**:
- `land-and-structures.md`, `farmhouse-progression.md`, `mandi-trading.md`,
  `liveops-events.md` — see §2.4

**Content Dependencies**:
- None beyond the emoji glyphs already embedded per `CropType` (no external
  art assets — the app renders crops as emoji/billboards, see
  `core/.../village3d`)

---

## 5. Balance and Tuning

**Current Values**: see the catalogue table in §2.1 — all values trace
directly to `v2.md`'s Tier 1-4 narrative and are treated as deliberately
tuned, not placeholder.

**Balance Concerns Identified**:
- ⚠️ Sandalwood's ₹500,000 base sell price against a ~21-day real-time grow
  is an enormous single-tile payout with no discovered cap on how many
  Agroforestry tiles a player can eventually run in parallel — worth a
  `/balance-check` pass once Agroforestry tile counts are known at scale.
- ⚠️ No hard-currency/premium-currency system exists despite `v2.md`
  specifying a dual soft/hard economy — every purchase in the current game
  uses the single coin currency. This is a design-scope gap, not a
  crop-economy formula issue; flagged here because it's the doc that would
  otherwise imply "wait-timer skip" purchases exist.

**Recommended Balance Pass**:
- ✅ Run 2026-08-22 — `design/balance/balance-check-crop-economy-2026-08-22.md`.
  Cross-tier progression confirmed healthy (every Tier 2+ crop out-earns
  every Open Field crop per-second, matching §1's stated design intent).
  One new finding, not previously documented here: **within** Open
  Field, Wheat's ₹/sec strictly dominates both Paddy's and Tomato's
  (Tomato is the single worst ₹/sec crop in the entire 9-crop
  catalogue).

  **Decision (2026-08-22): confirmed intentional, not retuned.** Unlike
  the Festival Premium Pass finding in the same balance-check sweep
  (`liveops-events.md` §5 — retuned, since that was an unambiguous flaw:
  a mechanic meant to add value doing the opposite in the common case),
  this pattern has a real, plausible design rationale already present in
  this doc's own §1: Tier 1 exists "to build a daily-return habit," and
  `v2.md`'s stated session model explicitly names both a short (1-5 min)
  and long (15+ min) loop. Read that way, Tomato's lower ₹/sec but
  larger single payout and much longer, lower-touch cycle (2 hours vs.
  Wheat's 2 minutes) is a genuine ₹/tap-vs-₹/sec tradeoff serving
  players who can't or don't want to check in every couple of minutes —
  not a formula mistake. Retuning it would mean changing real gameplay
  numbers on pure formula analysis with no playtesting to confirm the
  new feel is actually better, for a mechanic this project's own
  `.claude/docs/coding-standards.md` explicitly classifies as a "Feel"
  quality (verified via playtesting, not automated formula checks).
  Left as-is; closing the ambiguity this way rather than leaving it open
  indefinitely.

---

## 6. Acceptance Criteria

**What Exists**:
- ✅ 9-crop catalogue across 5 plot kinds, each with distinct economics
- ✅ Full plant → grow → harvest → sell lifecycle
- ✅ Weather/pest risk model for open-field and unprotected-Polyhouse crops
- ✅ Damaged-yield partial-value sale path (never zero-value)
- ✅ Offline-safe lazy growth resolution

**What's Missing**:
- ❌ Hard/premium currency (per `v2.md`, not implemented anywhere)
- ❌ Production pipelines / processing buildings (Spice Grinder, Textile
  Loom per `v2.md`) — no code for this exists; out of scope for this doc,
  noted for `design/gdd/systems-index.md` when created

**Definition of Done**:
- [x] Every `CropType` has a defined plot-kind, cost, timing, and risk
- [x] Plot lifecycle is unambiguous and offline-safe
- [x] Damaged-yield handling is defined and non-zero
- [ ] Open question in §3 resolved (open-field spoilage asymmetry)

---

## 7. Open Questions and Follow-Up Work

### Questions Needing User Decision
1. **Open-field/Aquaculture spoilage**: should `ReadyToHarvest` stock outside
   Polyhouse ever degrade if left too long?
   - Option A: Leave as-is — only Polyhouse (highest-value perishables) spoils
   - Option B: Add a longer, gentler grace window to other tiers too

2. **Hard currency**: `v2.md` specifies one; the shipped game doesn't have it.
   - Option A: Treat as an intentional scope cut for this build — coins-only
   - Option B: Flag as a real gap for a future economy pass

### Flagged Follow-Up Work
- [x] Draft `land-and-structures.md`, `farmhouse-progression.md`,
      `mandi-trading.md`, `liveops-events.md` — all 4 exist
- [x] Run `/balance-check` on this doc's own crop table — done 2026-08-22,
      see `design/balance/balance-check-crop-economy-2026-08-22.md`. The
      other 4 economy docs' own `/balance-check` recommendations are
      still individually open — not done as part of this pass.
- [ ] Decide the two open questions above
- [x] Consider an ADR for "lazy/read-time growth resolution over a live
      ticking timer" — written 2026-08-22:
      `docs/architecture/adr-0004-lazy-read-time-growth-resolution.md`

---

## 8. Version History

| Date | Author | Changes |
|------|--------|---------|
| 2026-08-18 | Claude (reverse-doc) | Initial reverse-documentation from `game/` package + `v2.md` |

---

**Next Steps** (update 2026-08-22 — steps 1-2 done, this list had gone
stale):
1. ~~Draft `land-and-structures.md`~~ — done, exists
2. ~~Then `farmhouse-progression.md`, `mandi-trading.md`,
   `liveops-events.md`~~ — done, all exist
3. `/balance-check` run on this doc (2026-08-22); still open for the
   other 4 economy docs individually

**Related Skills**:
- `/balance-check` — validate formulas and progression
- `/architecture-decision` — document the lazy-resolution pattern
- `/reverse-document design app/src/main/java/com/zonkrik/ifarming/game` — continue with the remaining 4 docs

---

*This document was generated by `/reverse-document design app/src/main/java/com/zonkrik/ifarming/game`*
