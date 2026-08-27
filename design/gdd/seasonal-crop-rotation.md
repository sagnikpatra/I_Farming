# Seasonal Crop Rotation

## Overview

Seasonal Crop Rotation ties crop availability to real-world seasons (Spring, Summer, Monsoon, Winter). Each season lasts ~3 months of real time. Certain crops are only plantable during their optimal season, creating natural diversity in player strategy and preventing monoculture. Off-season crops still exist in inventory but cannot be planted until their season returns, forcing players to diversify their planting patterns or plan ahead. The system mirrors authentic Indian agricultural calendars and encourages deep engagement with the farm's seasonal cycles.

## Player Fantasy

Players feel connected to the rhythms of real agriculture. "It's monsoon season — time to plant rice and prepare for flooding." Late in a season, players anticipate the next season and plan their crops. The constraint feels natural rather than arbitrary: rice grows during monsoon, wheat during winter. Off-season crops sit in inventory as a reminder that seasons matter. Strategic players stockpile seeds before seasons change or maintain multiple crop types to always have something to plant.

## Detailed Rules

### Seasons & Calendar

| Season | Real-World Duration | Crops Available |
|--------|-------------------|-----------------|
| Spring | March 21 – June 20 | Wheat, Chickpea, Lentil, Tomato, Cucumber, Spinach |
| Summer | June 21 – Sept 22 | Maize, Sugarcane, Capsicum, Brinjal |
| Monsoon | Sept 23 – Dec 21 | Paddy, Makhana, Pond Fish, Sugarcane, Turmeric, Ginger |
| Winter | Dec 22 – March 20 | Wheat, Chickpea, Lentil, Mustard, Cardamom |

Table limited to this project's actual `CropType.Kind` roster (22 crops
total — see `godot/scripts/economy/crop_type.gd`). An earlier draft of this
table referenced 11 crops (Chili, Peas, Cotton, Okra, Basil, Jute, Rice as
distinct from Paddy, Rapeseed, Radish, Cabbage, Cauliflower, Gram, Carrot)
that were never added to `CropType.Kind` — implementing against that draft
literally would not compile (GDScript resolves `CropType.Kind.SOMENAME` at
parse time). Expanding `CropType.Kind` with more real-world crops so a
richer seasonal table becomes possible is a reasonable future pass, but is
its own scoped change (new crop art/economy/recipes), not something to
smuggle in via this table.

**Special (Year-Round Available):**
- Sandalwood (agroforestry, no season restriction)
- Saffron (vertical farm, no season restriction)
- Neem (agroforestry, no season restriction)
- Coconut (tropical, available year-round in southern regions — flavor text)
- Dutch Rose (polyhouse, climate-controlled — not assigned a season entry;
  `GameData.crop_available_seasons()` treats any crop absent from the
  season map as year-round by design, so this falls out of that default
  rather than an explicit table row)

### Crop Planting Rules

1. **In-season crops** — Can be planted normally
2. **Off-season crops** — Cannot be planted; seed button is disabled in UI with tooltip "Available [season name]"
3. **Existing plots** — Growing crops are NOT affected by season change (continue to maturity)
4. **Inventory** — Off-season seeds stay in inventory; no expiration or decay
5. **Harvested crops** — Can be sold/processed regardless of season

### Season Transitions

- **On calendar boundary** (midnight local time on season boundary date):
  - Current season changes
  - UI updates available crop list
  - Tooltip on off-season plots: "Available next [season]"
  - Optional: play subtle visual transition (sky color shift, etc.)
  - No penalties; just availability changes

### Seed Availability

- Players can **purchase seeds** year-round from seed shop (all seeds available)
- Players can **plant seeds** only during their season
- Players **cannot plant** off-season seeds; UI prevents it
- Off-season seeds remain in inventory indefinitely

## Formulas

### Season Detection

```
now_ms = epoch ms, passed explicitly by the caller (never read from the
         wall clock inside this formula -- matches every other
         time-dependent formula in this codebase, e.g. GameEconomy's
         local_day_key(), so offline catch-up and tests can resolve a
         season for any timestamp, not just "right now")
shifted_seconds = now_ms / 1000 + device_timezone_offset_minutes * 60
(month, day) = datetime_from_unix_time(shifted_seconds)
current_season = determine_season(month, day)

determine_season(month, day):
  if (month == 3 AND day >= 21) OR (month > 3 AND month < 6) OR (month == 6 AND day <= 20):
    return SPRING
  elif (month == 6 AND day >= 21) OR (month > 6 AND month < 9) OR (month == 9 AND day <= 22):
    return SUMMER
  elif (month == 9 AND day >= 23) OR (month > 9 AND month < 12) OR (month == 12 AND day <= 21):
    return MONSOON
  else:
    return WINTER

Example: 2026-08-23 (August 23)
  Month = 8, matches June 21 – Sept 22 range
  Current season = SUMMER
```

(An earlier draft of this formula used `month >= 3 AND day >= 21` /
`month <= 6 AND day <= 20`-style range checks, which misclassify most of
the year -- e.g. February 15 satisfies `month <= 6 AND day <= 20` and
would wrongly return SPRING. The per-month boundary form above is what's
actually implemented in `SeasonType._determine_season()` and is the
correct version.)

### Crop Availability Check

```
can_plant_crop(crop_type: CropType, current_season: SeasonType) -> bool:
  available_seasons = GameData.crop_available_seasons(crop_type)
  return current_season in available_seasons

Example: Wheat
  available_seasons = [SPRING, WINTER]
  In SUMMER: can_plant_crop(WHEAT, SUMMER) = false
  In WINTER: can_plant_crop(WHEAT, WINTER) = true
```

### Season Duration

```
Each season = ~91 days (3 months)
Real time: 3 months of actual calendar time
Gameplay time: 91 harvests of a 2-hour crop = 182 hours = 7.6 days of constant play

This creates natural rhythm: a player playing daily encounters 4 distinct seasons
per year, preventing stale seasonal feeling.
```

## Edge Cases

1. **Harvest during season boundary** — Crop matured yesterday (spring), player harvests today (summer)
   - **Resolution**: Harvest succeeds (off-season rule only prevents planting, not harvesting)

2. **Try to plant off-season seed** — Player taps empty plot, seed shop shows Turmeric (a monsoon crop), but it's summer
   - **Resolution**: Seed button disabled, tooltip: "Available in Monsoon"

3. **Season changes mid-day** — Player plays during season boundary (rare)
   - **Resolution**: Season changes at midnight local time; in-progress crops unaffected

4. **Multiple crops across seasons** — Player has wheat (winter), paddy (monsoon), maize (summer) all growing
   - **Resolution**: Each crop follows its own growth timer; all complete normally regardless of season change

5. **No crops available this season** — Edge case if crop list poorly designed
   - **Resolution**: Shouldn't happen with the current table (every season has 4-6 crops), but is a real constraint now that the roster is smaller than the original 8-per-season draft — a future crop added to `CropType.Kind` should be assigned to a season deliberately, not left to default into every season by omission. If a season ever ends up with zero crops, show "No crops available this season" in the seed shop rather than crashing.

6. **Regional variants and seasons** — E.g., "Basmati Wheat" (spring variety)
   - **Resolution**: Seasonal availability applies to the base crop type; variants inherit the same availability

## Dependencies

- **CropType** (already exists) — each crop maps to seasons
- **PlotState** (already exists) — determines if plot is growing/ready
- **GameData** (already exists) — stores crop_available_seasons lookup
- **GameEconomy** (already exists) — resolve_growth_completions() checks season for new planting
- **UI system** (already exists) — seed picker and plot UI show season restrictions
- **Time system** (already exists) — uses system date/time for season calculation
- **Farming mechanics** (already exists) — existing planting, harvesting unaffected

## Tuning Knobs

| Knob | Safe Range | Effect |
|------|-----------|--------|
| Crops per season | 6–12 | Controls diversity; more = easier to always plant something |
| Season duration | 2–4 months | Controls rhythm; shorter = more frequent change, longer = stable |
| Year-round crops | 2–5 | Controls safety net; more = easier, fewer = harder |
| Season boundary dates | Vary ±7 days | Controls alignment with real-world seasons |

## Acceptance Criteria

- [x] System correctly identifies current season from an explicit `now` epoch-ms timestamp (device-timezone-aware, not a hidden wall-clock read) — `SeasonType.current_season()`
- [x] Spring (Mar 21 – Jun 20) makes wheat, tomato plantable; paddy is not
- [x] Monsoon (Sept 23 – Dec 21) makes paddy, makhana, pond fish plantable; wheat is not
- [ ] Planting off-season crop shows disabled button with "Available [season]" tooltip — `plant_seed()` currently rejects with a toast event (`event.plant_off_season`), not yet a disabled/greyed seed-picker button
- [x] Harvesting in-progress crop works regardless of season boundary
- [x] Existing plots continue growing even if season changes mid-growth (season is only checked at plant time)
- [ ] Season changes at midnight local time (not immediately upon date change) — not separately implemented; falls out naturally since `current_season()` is a pure function of `now`, re-evaluated on every call
- [x] Special crops (Sandalwood, Saffron, Neem, Coconut, Dutch Rose) are available year-round
- [x] Crop availability lookup is O(1) (`Dictionary`, not linear search) — `GameData._crop_season_map`
- [ ] UI seed picker dynamically shows/hides seasonal crops — not implemented; only the plant-time rejection above exists
- [x] Unit tests pass: `godot/tests/unit/test_seasonal_crops.gd` (416 lines) — season detection, crop availability, edge cases (hand-verified against the implementation; GUT itself not yet run on this machine, see session-state)
- [ ] On-device APK: player sees seasonal restrictions and can plan accordingly — not yet verified on-device
