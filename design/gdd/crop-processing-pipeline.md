# Crop Processing Pipeline

## Overview

The Crop Processing Pipeline allows players to convert raw agricultural commodities into premium refined goods using specialized buildings (spice grinders, textile looms, oil presses, etc.). Each recipe transforms one or more input crops into a single output product over a fixed duration, multiplying the output value by 2–5x. Processing buildings are purchased as upgradeable infrastructure and queue multiple recipes, creating deep resource management and session-extension mechanics.

## Player Fantasy

Players feel like they're running a vertically integrated agribusiness. Raw wheat becomes premium flour; raw cotton becomes fine textile; raw turmeric becomes packaged premium spice. The act of processing transforms simple commodities into luxury goods, dramatically increasing revenue. Watching a full processing queue complete feels rewarding and encourages return sessions. Players optimize their pipeline layout and recipe selection to maximize throughput and profit.

## Detailed Rules

### Processing Buildings

Each processing building:
- Occupies **1 tile** on the farm (like infrastructure)
- Has a **fixed cost** to purchase (₹5k–₹50k depending on building type)
- Can be **active or inactive** (player toggles on/off)
- Processes **one recipe at a time** in a queue
- Supports **multiple recipes** queued simultaneously (max 5 items in queue)
- Has a **queue UI** showing pending and active recipes

### Processing Recipes

Each recipe:
- Has **1–2 input crop types** (e.g., "turmeric" or "cotton")
- Requires a **specific input quantity** (e.g., 10 turmeric to make 1 premium spice jar)
- Produces **exactly 1 output item** per cycle
- Takes a **fixed duration** (60 seconds to 12 hours)
- Has a **base sell price** for the output (stored separately from raw crop price)
- Can have **modifier dependencies** (e.g., "requires Fan & Pad to unlock")

### Processing Workflow

1. **Player taps building** → opens recipe selection UI
2. **Player selects recipe** → checks inventory for required inputs
3. **If inputs available** → recipe is queued, inputs deducted immediately
4. **Recipe processes** → timer counts down, building plays animation
5. **When complete** → output item added to inventory, queue advances
6. **Player collects** → taps building or auto-collects (TBD)

### Queue Behavior

- Maximum 5 recipes queued per building
- Recipes process FIFO (first in, first out)
- Player can **remove pending recipes** (inputs refunded)
- Player can **pause** the building (stops current recipe, queue paused)
- **Offline processing**: recipes continue while player is offline (soft-cap at completion time, not refunded)

### Building Types (MVP)

| Building | Cost | Recipes | Duration Range |
|----------|------|---------|-----------------|
| Spice Grinder | ₹5,000 | Turmeric→Spice, Chili→Powder, Coriander→Powder | 60–120 sec |
| Textile Loom | ₹8,000 | Cotton→Fabric, Jute→Rope | 180–300 sec |
| Oil Press | ₹10,000 | Coconut→Oil, Mustard→Oil, Sesame→Oil | 120–180 sec |
| Essential Oil Distillery | ₹50,000 | Sandalwood→Essential Oil, Rose→Rose Water | 12–24 hours |
| Flour Mill | ₹5,000 | Wheat→Flour, Rice→Rice Flour | 60–90 sec |
| Dairy Processor | ₹8,000 | Milk→Cheese, Milk→Yogurt | 2–4 hours |

## Formulas

### Processing Output Value

```
output_value = base_output_price × quantity_produced
output_price_multiplier = 2.0 to 5.0 (by recipe)

Example: 10 turmeric (₹20 each = ₹200 total) → 1 Premium Spice Jar
  output_price = ₹600 (3x multiplier)
  profit = ₹600 - ₹200 = ₹400 net gain per cycle
  ROI = 400 / 200 = 2.0x on input value
```

### Processing Duration

```
base_duration_seconds = recipe constant (60 to 43,200)
modified_duration = base_duration_seconds × (1.0 / processing_speed_multiplier)

processing_speed_multiplier:
  - Base = 1.0x
  - Fan & Pad unlock = 1.25x (faster processing)
  - Farmhouse Level 5+ = 1.1x (passive bonus)
  - Agile processing equipment (future) = 1.5x
```

### Economic Sink & Faucet

```
coin_sink_per_cycle = base_building_cost / (recipe_cycles_to_break_even)
  Example: Spice Grinder (₹5k) makes ₹400 profit per 60-sec recipe
  Break-even cycles = 5000 / 400 = 12.5 cycles (~12.5 minutes)
  
This forces players to grind extensively to recover building cost,
creating a soft time-gate on building expansion.
```

## Edge Cases

1. **Insufficient inventory** — Player queues recipe but sells/uses input before processing starts
   - **Resolution**: Recipe fails gracefully, inputs deducted anyway, output not produced, toast notification: "You don't have enough [crop]."
   
2. **Building unpurchased** — Player queues recipe but doesn't own building
   - **Resolution**: Prevent queueing in UI (button disabled if building not owned)
   
3. **Queue full** — Player tries to queue 6th recipe
   - **Resolution**: UI shows "Queue Full (5/5)" red indicator, button disabled
   
4. **Processing overflow while offline** — Player is offline for 48 hours, queue completes 10x over
   - **Resolution**: All recipes complete, outputs stored in inventory. No soft-cap or loss. (Inventory is the soft-cap.)
   
5. **Remove recipe mid-processing** — Player taps "Remove" on active recipe
   - **Resolution**: Current recipe cancelled, inputs are NOT refunded (sunk cost), queue advances
   
6. **Building disabled during processing** — Player toggles building off while recipe active
   - **Resolution**: Recipe pauses, resumes when building re-enabled. Timer preserved.

## Dependencies

- **CropType** (already exists) — recipes reference crop inputs
- **CropStock** (already exists) — inventory system holds recipe outputs
- **GameState** (already exists) — persist processing queue state
- **GameData** (already exists) — recipes & building defs stored here
- **Infrastructure unlock system** (already exists via has_polyhouse, etc.) — processing buildings unlocked by progression
- **Farmhouse Level progression** (NEW, Feature 5) — Level 5+ unlocks faster processing
- **E-NAM Market** (already exists) — outputs can be sold at mandi

## Tuning Knobs

| Knob | Safe Range | Effect |
|------|-----------|--------|
| Building cost | ₹2,000–₹100,000 | Controls affordability; higher = longer grind |
| Recipe duration | 30 sec–24 hours | Affects session pacing; short = active grinding, long = offline progress |
| Output multiplier | 1.5x–10x | Controls profitability; higher = more rewarding but inflates economy |
| Queue size | 1–10 | Controls depth; larger = more planning, smaller = simpler |
| Processing speed bonus | 1.0x–2.0x (via multiplier) | Controls power of infrastructure upgrades |

### Safe Ranges Rationale

- **Cost**: Should require 10–20 min of active grinding to break even (₹5k building ÷ ₹300/min farm income)
- **Duration**: Short recipes (60 sec) drive daily habit loops; long recipes (12 hr) drive long-term planning
- **Multiplier**: 2–5x keeps profit margins generous but not game-breaking; above 5x risks inflation
- **Queue size**: 5 items balances complexity and storage mechanics

## Acceptance Criteria

- [ ] Player can purchase a Spice Grinder building for ₹5,000
- [ ] Player can queue a turmeric→spice recipe from inventory
- [ ] Recipe processes over 60 seconds, then completes and moves to inventory
- [ ] Output value is 3x the input value (turmeric ₹200 → spice ₹600)
- [ ] Player can queue up to 5 recipes and see them process FIFO
- [ ] Player can remove a pending recipe (inputs NOT refunded)
- [ ] Recipes continue while offline and complete upon return
- [ ] UI shows queue status (1/5) and estimated completion time
- [ ] Processing speed increases to 1.25x when Fan & Pad is purchased
- [ ] All 6 building types (MVP) are available and functional
- [ ] Unit tests pass: recipe calculation, queue mechanics, edge cases
- [ ] On-device APK: player can build, queue, and collect processed goods
