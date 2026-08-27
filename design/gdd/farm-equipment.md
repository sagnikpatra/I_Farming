# Farm Equipment

> **Reverse-documented from implementation, 2026-08-27.** A 50-item
> equipment catalogue (`farm_equipment.gd`) existed in the codebase since
> 2026-08-23 (commit `49825db`, "feat: crop varieties + 50-item farm
> equipment catalogue") but was never wired to anything — no purchase path,
> no UI, no persistence. This GDD documents the real system built on top of
> it this session: purchase, ownership, and land-expansion-tier gating.
> Sections call out what's implemented vs. what's still a gap explicitly.

## Overview

A collection of 50 authentic Indian-farming tools and machinery, from a
₹100 twine bundle to an ₹800,000 solar panel system, that the player can
purchase into a permanent owned collection. Purchasing is gated two ways:
by coins (like every other purchase in the game) and by how many land
expansions the player has bought — framing equipment access as "new
technology becomes available as the farm grows," not just a flat shop.

## Player Fantasy

A long-tail collection/progression goal that rewards players who keep
expanding their land, separate from the crop-economy loop. Early basic
tools (a shovel, a hoe) are available from day one; the most impressive
machinery (a harvester, an agricultural drone, a solar panel system) stays
locked until the farm has genuinely grown, so owning one signals real
long-term investment, not just a lucky coin balance.

## Detailed Rules

1. **Ownership is a collection, not a stack.** Each of the 50
   `FarmEquipment.Kind` items can be owned at most once. Buying an
   already-owned item is a silent no-op (`GameEconomy.buy_equipment()`).
2. **Six tiers, gated by land expansions bought**, checked before coins:

   | Tier | Expansions Required | Example Items |
   |---|---|---|
   | Basic | 0 (available immediately) | Twine, Nails Bundle, Wrench |
   | Common | 0 (available immediately) | Shovel, Hoe, Rake |
   | Standard | 2 | Hand Pump, Bullock Cart, Wooden Plough |
   | Mid-Range | 5 | Motor Pump 3HP, Water Tank, Diesel Engine |
   | Premium | 8 | Harvester Machine, Power Tiller, Sprayer 500L |
   | Luxury | 11 | Solar Panel System, Agricultural Drone |

   "Expansions bought" = `GameEconomy.land_expansions_bought()` = current
   Open Field plot count minus `GameData.STARTING_PLOTS` (3) — 0 at a fresh
   save, up to 13 at `GameData.MAX_PLOTS` (16). The curve (0/0/2/5/8/11)
   leaves every tier reachable well before the 13-expansion cap.
3. **Coins checked after the tier gate.** A locked-tier item shows/behaves
   differently from a merely-unaffordable one — attempting to buy a locked
   item never touches coins at all, and posts a distinct "tier locked"
   event rather than a "need more coins" one.
4. **No board placement, no gameplay bonus yet.** Purchasing only adds the
   item to `GameState.owned_equipment` — see Acceptance Criteria for why,
   and Open Questions for what's deferred.

## Formulas

```
tier(kind) = derived from FarmEquipment.Kind's declaration-order grouping
             (contiguous ranges: Luxury/Premium/Mid-Range/Standard/Common/Basic)

tier_unlock_expansions(tier) =
    0   if tier in {BASIC, COMMON}
    2   if tier == STANDARD
    5   if tier == MID_RANGE
    8   if tier == PREMIUM
    11  if tier == LUXURY

land_expansions_bought() = max(open_field_plot_count - STARTING_PLOTS, 0)
                          = max(open_field_plot_count - 3, 0)

can_buy(kind) = not owned(kind)
            AND land_expansions_bought() >= tier_unlock_expansions(tier(kind))
            AND coins >= equipment_cost(kind)
```

Per-item costs are the original 2026-08-23 catalogue, unchanged by this
pass: ₹100 (Twine, cheapest) to ₹800,000 (Solar Panel System, most
expensive) — see `farm_equipment.gd`'s `equipment_cost()` for the full
50-item table.

## Edge Cases

1. **Buying an already-owned item.** Silent no-op — no event posted, no
   coins touched, `owned_equipment` not duplicated (confirmed by
   `test_buy_equipment_already_owned_is_a_no_op_second_time`).
2. **Attempting a locked-tier item with plenty of coins.** Coins are
   untouched — the tier check runs first and returns before the coin check
   is ever reached (confirmed by
   `test_buy_equipment_locked_tier_does_not_charge_even_if_affordable`).
3. **A fresh save (0 expansions).** Basic and Common tier items (20 of the
   50) are purchasable immediately; nothing else is. Not a bug — this is
   the intended "starts open, expands with the farm" curve.
4. **Maximum land expansion (13 bought, `MAX_PLOTS` reached).** Every tier
   is unlocked; only coins gate anything at that point.

## Dependencies

- **GameEconomy** — `buy_equipment()`, `land_expansions_bought()` (the
  latter refactored out of the pre-existing `buy_land_expansion()`'s own
  plot-counting loop, not a new independent calculation).
- **GameState** — `owned_equipment: Array[int]` (persisted `@export`
  field).
- **FarmEquipment** (`farm_equipment.gd`) — the 50-item catalogue plus the
  `Tier` enum, `equipment_tier()`, and `tier_unlock_expansions()` added
  this pass.
- **EquipmentShop** (`ui/equipment_shop.gd` + `.tscn`) — the browse/buy
  sheet, opened from a new HUD button (🧰, next to the existing 🛒 Shop
  button that opens `DecorationPicker`).
- **Land & Structures** (`land-and-structures.md`) — this doc's land
  expansion mechanic is the tier-gate input; unchanged by this pass, just
  read from.

## Tuning Knobs

| Knob | Current Value | Safe Range | Effect |
|---|---|---|---|
| `FarmEquipment.TIER_UNLOCK_EXPANSIONS` (Standard/Mid-Range/Premium/Luxury) | 2/5/8/11 | keep increasing, keep all ≤ 13 (`MAX_PLOTS - STARTING_PLOTS`) | How fast equipment tiers unlock relative to land-expansion progress |
| Per-item `equipment_cost()` | ₹100–₹800,000 (50 values) | — | Individual item price; unchanged from the original 2026-08-23 catalogue |

## Acceptance Criteria

**What's implemented and tested:**
- [x] `buy_equipment()` — coins-gated, tier-gated (checked before coins),
      already-owned no-op
- [x] `land_expansions_bought()` — correct at a fresh save and after
      expansions
- [x] `EquipmentShop` sheet — lists all 50 items grouped by tier, tappable
      to buy, reachable from a real HUD button
- [x] Ownership persists (`GameState.owned_equipment`, a normal `@export`
      field — round-trips through the existing local save path the same as
      every other state field)
- [x] 15 unit tests (`test_farm_equipment.gd`) covering the gating logic
      and the shop's pure `build_row_data()`

**What's explicitly NOT done (real, tracked gaps, not oversights):**
- [ ] **No board placement.** Purchased equipment doesn't appear on the 3D
      village board at all — a deliberate scope decision (see this
      project's `design/art/ui-visual-direction-2026-08.md`-style
      discipline: none of the 4 sourced Kenney kits contain anything
      resembling farm tools/machinery, and this project doesn't force
      bad-fit models). Would need a genuine new asset-sourcing pass before
      board placement is achievable at this project's existing visual
      quality bar.
  - [ ] **No gameplay bonus.** Owning equipment has zero mechanical effect
      today (no weather-risk reduction, no growth-speed bonus, nothing) —
      a collection/investment goal only. Deferred as a separate, much
      larger design pass (50 items' worth of individual or tiered balance
      formulas) rather than guessed at here.
- [ ] On-device screenshot verification of the shop UI specifically — the
      economy logic is unit-tested and the app was confirmed to still boot
      cleanly with these changes, but no screenshot of the Equipment Shop
      sheet itself, open and populated, has been taken yet.

## Open Questions and Follow-Up Work

1. **Board placement**, once new equipment-appropriate CC0 assets are
   sourced (a real content pass — see the crop-model sourcing precedent
   from this same session for the honesty bar to hold new assets to).
2. **Gameplay bonuses per item or tier** — a genuine economy-design pass,
   not a code task. Needs a `game-designer`/`economy-designer` decision on
   what, if anything, equipment should actually do beyond being ownable.
3. **On-device screenshot** of the Equipment Shop sheet, for this GDD's
   Acceptance Criteria to be fully closed the way `thief-system.md`'s was.
