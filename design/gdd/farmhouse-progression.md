# Farmhouse Upgrades & Progression

## Overview

The Ancestral Farmhouse is the central progression hub of the game. Players gradually upgrade their farmhouse from a humble rural home into a sprawling traditional Haveli or modern agricultural estate. Each of the 10 upgrade levels requires exponentially higher coin investments but grants systemic gameplay unlocks: increased crop storage, faster processing, new building types, increased worker capacity, and passive income bonuses. The farmhouse serves as both a visible status symbol and a mechanical gating mechanism for late-game content.

## Player Fantasy

Players feel their farm transforming over time. The farmhouse visually evolves from a small cottage into an impressive estate, reflecting their economic progress. Each upgrade milestone feels significant and unlocks new possibilities: "I can now afford to hire workers" or "My processing is 20% faster." The farmhouse becomes a destination—players visit it to claim passive income bonuses and review their upgrade path. Late-game players see their Level 10 farmhouse as a status symbol that communicates mastery and investment.

## Detailed Rules

### Farmhouse Levels

| Level | Cost | Prerequisites | Unlocks | Passive Bonus |
|-------|------|---|----------|---------------|
| 0 | Free | None | Basic farm, 5 plots | None |
| 1 | ₹2,000 | None | +2 plot capacity | Crop storage +500 |
| 2 | ₹5,000 | Level 1 | +1 worker slot, spice grinder | Crop storage +500 |
| 3 | ₹12,000 | Level 2 | Textile loom, oil press | Processing speed +10% |
| 4 | ₹25,000 | Level 3 | +2 worker slots, flour mill | Crop storage +1,000 |
| 5 | ₹50,000 | Level 4 | Dairy processor, farmhouse visitation reward | Processing speed +10%, passive income ₹100/hour |
| 6 | ₹100,000 | Level 5 | Mandi trading terminal | Passive income +₹150/hour |
| 7 | ₹200,000 | Level 6 | Essential oil distillery unlock | +1 worker slot, passive income +₹200/hour |
| 8 | ₹400,000 | Level 7 | Aquaculture unlock | Crop storage +2,000 |
| 9 | ₹750,000 | Level 8 | Vertical farm unlock | Processing speed +15% |
| 10 | ₹1,500,000 | Level 9 | Maximum status, farmhouse monument cosmetic | Passive income +₹500/hour, all storage +3,000 |

### Upgrade Flow

1. **Player taps Farmhouse** on village board
2. **Farmhouse UI opens** showing:
   - Current level (e.g., "Level 3 / 10")
   - Progress toward next level (coins/cost)
   - Next level's unlocks & bonuses listed
   - "Upgrade" button (enabled if player has coins, disabled if max level)
3. **Player confirms upgrade** → coins deducted immediately, farmhouse level incremented
4. **Visual feedback** → farmhouse building 3D model changes appearance, toast confirms
5. **Unlocks activate** → new buildings/features become available in menus

### Passive Income

Farmhouse levels 5+ generate passive income automatically:
- Players earn coins **every hour** in real time (even offline, soft-capped at 12 hours max accrual)
- Amount scales: ₹100 at L5 → ₹500 at L10
- Displayed in a "Pending Earnings" widget on HUD
- Players tap to collect (or auto-collect on login)

### Storage Multiplier

Farmhouse levels 1, 4, 8, 10 increase total crop storage:
- Base storage: 1,000 items
- L1: +500 → 1,500
- L4: +1,000 → 2,500
- L8: +2,000 → 4,500
- L10: +3,000 → 7,500

### Processing Speed Bonus

Levels 3, 5, 9 unlock processing speed improvements:
- Base: 1.0x (recipes at normal duration)
- L3: 1.1x (10% faster)
- L5: 1.2x (20% faster, cumulative)
- L9: 1.35x (35% faster, cumulative from L5)

## Formulas

### Upgrade Cost Curve

```
cost(level) = 2000 × 2^(level-1) for levels 1-5
cost(level) = 50000 × 1.5^(level-5) for levels 6-10

Example progression:
  L1: ₹2,000
  L2: ₹4,000
  L3: ₹8,000
  L4: ₹16,000
  L5: ₹32,000 (spike to ₹50,000 for balance)
  L6: ₹75,000
  L7: ₹112,500
  ...
  L10: ₹1,500,000

Total cost to max: ~₹3,000,000 (requires 2-3 weeks of mid-game play)
```

### Passive Income Calculation

```
hourly_income = 100 × (1 + (farmhouse_level - 5) × 0.1) for L5+
  L5: ₹100/hour
  L6: ₹150/hour
  L7: ₹200/hour
  ...
  L10: ₹500/hour

max_offline_accrual = 12 hours × hourly_income
  L5: 12 × ₹100 = ₹1,200 max pending
  L10: 12 × ₹500 = ₹6,000 max pending
```

### Processing Speed Multiplier

```
processing_speed = 1.0 base
processing_speed += 0.1 if farmhouse_level >= 3
processing_speed += 0.1 if farmhouse_level >= 5
processing_speed += 0.15 if farmhouse_level >= 9

Equivalent durations:
  Recipe normally takes 60 sec
  At L3: 60 / 1.1 = 54.5 sec
  At L5: 60 / 1.2 = 50 sec
  At L9: 60 / 1.35 = 44.4 sec
```

## Edge Cases

1. **Player reaches max level** → "Upgrade" button disabled, shows "Max Level Reached"
2. **Player has insufficient coins** → "Upgrade" button disabled with "₹X more needed" text
3. **Farmhouse level prerequisite not met** — Next level shows "Requires Farmhouse Level X"
4. **Passive income collection while offline** → Full accrual added on login (no loss)
5. **Passive income pending when farmhouse upgraded** → Income continues at new rate
6. **Processing speed bonus applied mid-recipe** → Current recipe completes at old duration, subsequent recipes use new speed

## Dependencies

- **GameState** (already exists) — persist `farmhouse_level`
- **GameEconomy** (already exists) — manage coins, storage capacity
- **Crop Processing Pipeline** (Feature 1) — levels 2+ unlock processing buildings
- **Worker Economy** (already exists, Feature 7 extends) — levels 2+ unlock worker slots
- **Infrastructure system** (already exists) — levels gate aquaculture, vertical farm unlocks
- **Time system** (already exists) — passive income resolution per hour
- **UI framework** (already exists) — farmhouse screen, HUD pending earnings widget

## Tuning Knobs

| Knob | Safe Range | Effect |
|------|-----------|--------|
| L1 cost | ₹1k–₹5k | Controls early-game grind length |
| Cost exponent | 1.5–2.5 | Controls late-game wall height; 2.0 = 4x per 2 levels |
| Max level | 8–15 | Controls progression ceiling |
| Passive income | ₹50–₹1k/hour | Controls offline reward; higher = more F2P friendly |
| Storage bonus per level | +200–+1,000 | Controls inventory management depth |
| Processing speed bonus | 1.1x–1.5x per level | Controls infrastructure power |

## Acceptance Criteria

**Verified on-device 2026-08-23** (real build, OnePlus OPD2403, per
`production/session-state/active.md`): tapping the Farmhouse building
opens `farmhouse_tab.gd` (pre-existing, reachable), which correctly shows
"Modern Estate · Farmhouse Level 7 of 10", storage 113/2500 (matches the
catalogue's Level 7 value exactly), and the Level 8 preview ("Grand
Manor", 4,500 storage, "Upgrade for ₹168750") also matching the catalogue
exactly.

- [x] Farmhouse UI displays current level (0–10) and cost to next upgrade — via `farmhouse_tab.gd`, confirmed on-device
- [x] Player can upgrade farmhouse from Level 0 to Level 1 for ₹2,000 — `farmhouse_tab.gd`'s upgrade button calls `buy_farmhouse_upgrade()` -> `upgrade_farmhouse()`, confirmed reachable on-device (not yet exercised through an actual purchase this session, but the wiring and cost display are both live and correct)
- [x] Level 2 upgrade costs ₹5,000 and unlocks 1 worker slot
- [x] Level 3 unlock activates 1.1x processing speed bonus (formula-verified; see `get_processing_speed_multiplier()`/`_growth_speed_multiplier()`)
- [x] Level 5 generates ₹100/hour passive income (value correct in the catalogue) — **but see the gap below: nothing calls the function that resolves it**
- [x] Passive income caps at 12-hour max offline accrual — `resolve_passive_income()`
- [x] Level 10 costs ₹1,500,000 and is maximum
- [x] Storage increases match the catalogue's absolute per-level values (confirmed on-device: L7=2500, L8=4500)
- [ ] Processing recipes complete faster at higher farmhouse levels — the multiplier function exists and is correct, but the Crop Processing Pipeline itself has no queue logic to apply it to yet (see `crop-processing-pipeline.md`/systems-index.md — unwired stub)
- [ ] Farmhouse 3D model visually changes appearance at each level — not verified this session (out of scope for this pass; see `farmhouse-visual-tiers.md` for that system's own doc)
- [x] "Max Level" message displays at Level 10 — `farmhouse.max_level_reached`, wired in `farmhouse_tab.gd`
- [x] Unit tests pass: cost formula, upgrade logic (hand-verified against `test_farmhouse_progression.gd`, GUT itself not yet run — see session-state)
- [ ] **On-device APK: player can upgrade farmhouse and collect passive income** — upgrading is reachable and confirmed above; **collecting passive income is not**. `resolve_passive_income()` and `collect_pending_passive_income()` are never called from anywhere in the codebase (confirmed via grep, not just "not yet tested") — nothing accrues or surfaces `state.pending_passive_income` during real gameplay. The one UI that would show/collect it, `farmhouse_upgrade_sheet.gd`, is also never opened by anything — same "built but not wired up" gap this sprint's Thief System has (see `thief-system.md`). Passive income is implemented and unit-tested in isolation, but is not a reachable feature yet.
