## Tunable constants for the farm economy. Port of GameData.kt's `GameData`
## object. All values ported verbatim from the Kotlin source and verified
## against design/gdd/crop-economy.md, land-and-structures.md,
## farmhouse-progression.md, mandi-trading.md, liveops-events.md.
##
## Catalogue tables (crops/hosts/decorations/farmhouse levels/festivals) are
## built lazily into static Dictionaries/Arrays on first access rather than
## via a `static func _static_init()` constructor -- `_static_init()` is a
## real Godot 4.4+ feature, but this project's pinned 4.7.1 carries a HIGH
## knowledge-risk flag (docs/engine-reference/godot/VERSION.md) for being
## released after this assistant's training cutoff, so the more
## conservative, unambiguously-safe lazy-cache pattern was preferred over a
## newer-but-still-fine feature where a simple alternative exists.
class_name GameData
extends RefCounted

# --- Land -------------------------------------------------------------------

## A poor farmer doesn't start with a sprawling holding -- just enough to get
## going, matching the marginal-pricing land economy below: everything past
## this has to be earned and paid for, at an increasing price as the farm's
## "valuation" grows.
const STARTING_PLOTS: int = 3
const MAX_PLOTS: int = 16

const _BASE_LAND_COST: int = 150
const _LAND_COST_MULTIPLIER: float = 1.55

## Weather-damaged (or spoiled) crops still sell, but at a steep discount,
## not for zero.
const WEATHER_DAMAGE_YIELD_MULTIPLIER: float = 0.5

# --- Tier 2: Protected Cultivation / Polyhouse ------------------------------

const POLYHOUSE_PLOT_COUNT: int = 4

const POLYHOUSE_BASE_COST: int = 35_000
const POLYHOUSE_SUBSIDY_COST: int = 17_500
const FAN_PAD_COST: int = 70_000
const DRIP_IRRIGATION_COST: int = 5_000
const UV_FILM_COST: int = 7_500

## Doc calls for renewal "every three in-game weeks" -- compressed to 3 real
## days here.
const UV_FILM_DURATION_MS: int = 3 * 24 * 60 * 60 * 1000

## Weather/pest risk for polyhouse crops when the UV film has lapsed (or was
## never bought).
const POLYHOUSE_UNPROTECTED_RISK_PERCENT: int = 10

## Harvest this many crops (any type) to unlock the 50% government subsidy on
## the Polyhouse.
const SUBSIDY_QUEST_TARGET: int = 25

## How long a harvested-but-neglected Polyhouse crop can sit before it's
## treated as spoiled.
const SPOILAGE_GRACE_MS_BASE: int = 4 * 60 * 60 * 1000
const SPOILAGE_GRACE_MS_WITH_DRIP: int = 24 * 60 * 60 * 1000

# --- Tier 3: Agroforestry / Sandalwood --------------------------------------

## Fixed NxN adjacency grid for host-plant/Sandalwood placement puzzles.
const AGROFORESTRY_GRID_SIZE: int = 3
const AGROFORESTRY_UNLOCK_COST: int = 20_000
const SECURITY_COST: int = 50_000

## Doc: 12-15 real years to maturity, compressed to a real 14-21 day wait
## in-game.
const SANDALWOOD_GROW_SECONDS_BASE: int = 21 * 24 * 60 * 60
## Acacia is the "optimized" host per the design doc's soil/host-plant
## optimization note.
const SANDALWOOD_GROW_SECONDS_ACACIA: int = 14 * 24 * 60 * 60

## Sandalwood is only at risk of theft while still Growing (not yet
## harvested), checked once per elapsed real hour so it plays out sensibly
## even across long offline gaps. These are deliberately tiny per-hour
## probabilities: compounded over a multi-week grow, unprotected trees have a
## real (~30%+) chance of being stolen; secured trees are safe.
const THEFT_HOURLY_PROBABILITY_UNPROTECTED: float = 0.00085
const THEFT_HOURLY_PROBABILITY_PROTECTED: float = 0.00006

# --- Tier 4: Niche Regional / Vertical Farming ------------------------------

## Makhana ponds -- cheaper, lower-ceiling alternative to Polyhouse;
## encourages diversification.
const AQUACULTURE_PLOT_COUNT: int = 5
const AQUACULTURE_UNLOCK_COST: int = 15_000

## Saffron vertical racks -- very few tiles, very high cost, needs recurring
## power to keep planting.
const VERTICAL_FARM_PLOT_COUNT: int = 2
const VERTICAL_FARM_UNLOCK_COST: int = 80_000
const ELECTRICITY_COST: int = 8_000
const ELECTRICITY_DURATION_MS: int = 2 * 24 * 60 * 60 * 1000

# --- Mandi / e-NAM trading ---------------------------------------------------

const MANDI_UNLOCK_COST: int = 3_000
const MANDI_TERMINAL_COST: int = 25_000

## Produce from any protected/managed cultivation tier gets an automatic
## A-Grade bump.
const MANDI_GRADE_A_BONUS_PERCENT: int = 12

## Developer-controlled price band so no crop can be pumped or dumped to
## absurd values.
const MANDI_MIN_MULTIPLIER: float = 0.6
const MANDI_MAX_MULTIPLIER: float = 1.6

## Each unit sold through the Mandi adds this much oversupply pressure on
## that crop.
const MANDI_GLUT_PER_UNIT: float = 0.02

## Continuous decay rate for glut; roughly halves every ~3 hours.
const MANDI_GLUT_DECAY_PER_HOUR: float = 0.231

## How often the server-wide demand cycle rotates to a new crop-by-crop
## modifier.
const MANDI_CYCLE_MS: int = 4 * 60 * 60 * 1000

# --- LiveOps: Monsoon Season -------------------------------------------------

## Recurring window, computed purely from device time -- no backend needed.
const MONSOON_CYCLE_MS: int = 6 * 60 * 60 * 1000
const MONSOON_ACTIVE_DURATION_MS: int = 90 * 60 * 1000

## Open-field crops grow this much faster while the Monsoon is active.
const MONSOON_SPEED_MULTIPLIER: float = 0.8

## Chance an un-protected open-field crop is wiped entirely by flooding when
## it matures.
const MONSOON_FLOOD_CHANCE_PERCENT: int = 10

# --- LiveOps: Festival Event Pass --------------------------------------------

const FESTIVAL_CYCLE_MS: int = 8 * 60 * 60 * 1000
const FESTIVAL_ACTIVE_DURATION_MS: int = 60 * 60 * 1000
const FESTIVAL_POINTS_PER_UNIT_SOLD: int = 2
## Balance fix (2026-08-22, design/balance/balance-check-liveops-events-
## 2026-08-22.md): was 5,000. The Premium Pass resets every
## FESTIVAL_CYCLE_MS occurrence (see _with_fresh_event_occurrence()), so
## it must be rebought every 8h to have any effect that cycle -- at the
## old cost, reaching only Tier 1 (the FESTIVAL_TIER_THRESHOLDS[0]
## premium bonus, 500) meant a real -4,500 loss, a "trap purchase" for
## anyone not actively optimizing around it. Lowered to sit at or below
## the smallest tier's own premium bonus, so genuine engagement (reaching
## at least Tier 1) is never a losing trade -- only buying the pass and
## then not engaging at all stays a real risk, which is the intended
## shape for a pass mechanic. Chosen deliberately, not guessed: 400 <
## FESTIVAL_PREMIUM_BONUS[0] (500), giving a guaranteed minimum +100 net
## at Tier 1, +1,600 at Tier 2, +5,600 at Tier 3.
const FESTIVAL_PREMIUM_PASS_COST: int = 400

const FESTIVAL_TIER_THRESHOLDS: Array[int] = [50, 150, 300]
const FESTIVAL_FREE_REWARDS: Array[int] = [500, 1_500, 4_000]
const FESTIVAL_PREMIUM_BONUS: Array[int] = [500, 1_500, 4_000]

# --- LiveOps: Chanda Visit (design/gdd/festival-visiting-npcs.md) -----------
# Independent cycle from the Festival Event Pass above -- a companion
# system, not a replacement; the two share no state and can overlap freely.

const CHANDA_CYCLE_MS: int = 12 * 60 * 60 * 1000
const CHANDA_ACTIVE_DURATION_MS: int = 30 * 60 * 1000

## Ask amount scales lightly with progression -- always a minor, affordable
## ask, never a meaningful economy sink or gate (§4 of the GDD).
const CHANDA_BASE_ASK: int = 20
const CHANDA_ASK_PER_LEVEL: int = 15

## Modest, time-limited sell-price blessing for giving -- deliberately
## weaker than the Festival Pass's own rewards; this is a warmth beat, not
## a min-max lever.
const CHANDA_BLESSING_MULTIPLIER: float = 1.08
const CHANDA_BLESSING_DURATION_MS: int = 2 * 60 * 60 * 1000

# --- Gems & Daily Tasks (design/gdd/gems-daily-tasks.md) --------------------
# The project's first real-calendar-day-anchored system (every other
# LiveOps system above runs on a fixed wall-clock cycle with no calendar
# awareness) -- see GameEconomy.local_day_key() for why day-boundary
# detection is a pure function of (now, timezone_offset), not a hidden
# system-clock read.

## Reroll discards today's picks entirely (not seeded) -- only allowed
## while zero of today's 3 tasks are complete, so it can never discard an
## already-earned reward.
const DAILY_TASK_REROLL_COST: int = 6
## Auto-awarded once, the instant the 3rd task of the day completes.
const DAILY_TASK_ALL_BONUS_GEMS: int = 5
## How many of the 5-entry pool are drawn each day.
const DAILY_TASKS_PER_DAY: int = 3

## design/gdd/gems-second-sink.md's capped grow-time skip -- the second
## gems sink from feature-scoping-2026-08-22.md item 2's own brief
## ("(b) capped convenience skips, e.g. one grow-time skip per day, hard-
## capped"). Priced noticeably above DAILY_TASK_REROLL_COST (a full skip
## is a stronger convenience than a reroll) but still reachable within a
## few days of ordinary play -- a full day's 3 tasks + the all-3 bonus
## nets roughly 14-19 gems at most.
const GROW_SKIP_COST_GEMS: int = 10

static var _daily_task_pool: Array[DailyTaskDef] = []


static func _ensure_daily_task_pool() -> void:
	if not _daily_task_pool.is_empty():
		return
	_daily_task_pool.append(DailyTaskDef.new(DailyTaskKind.Kind.HARVEST, "Harvest 5 crops", "🌾", 5, 3))
	_daily_task_pool.append(DailyTaskDef.new(DailyTaskKind.Kind.PLANT, "Plant 5 seeds", "🌱", 5, 3))
	_daily_task_pool.append(DailyTaskDef.new(DailyTaskKind.Kind.SELL, "Sell crops 3 times", "💰", 3, 4))
	_daily_task_pool.append(DailyTaskDef.new(DailyTaskKind.Kind.WORKER, "Complete 3 worker actions", "👷", 3, 4))
	_daily_task_pool.append(DailyTaskDef.new(DailyTaskKind.Kind.EARN, "Earn ₹500", "🪙", 500, 5))


static func daily_task_pool() -> Array[DailyTaskDef]:
	_ensure_daily_task_pool()
	return _daily_task_pool


static func daily_task_def_for_kind(kind: DailyTaskKind.Kind) -> DailyTaskDef:
	_ensure_daily_task_pool()
	for task in _daily_task_pool:
		if task.kind == kind:
			return task
	return _daily_task_pool[0]  # defensive fallback, mirrors farmhouse_level_def()'s own clamp style

# --- Land expansion ----------------------------------------------------------

## Marginal pricing: each new plot costs more than the last, per the design
## doc's requirement that late-game expansion still applies financial
## pressure.
static func land_expansion_cost(current_plot_count: int) -> int:
	var steps_beyond_start: int = maxi(current_plot_count - STARTING_PLOTS, 0)
	return roundi(float(_BASE_LAND_COST) * pow(_LAND_COST_MULTIPLIER, steps_beyond_start))


static func polyhouse_cost(subsidy_unlocked: bool) -> int:
	return POLYHOUSE_SUBSIDY_COST if subsidy_unlocked else POLYHOUSE_BASE_COST


static func is_subsidy_unlocked(total_harvests: int) -> bool:
	return total_harvests >= SUBSIDY_QUEST_TARGET

# --- Crop catalogue -----------------------------------------------------------

static var _crop_defs: Dictionary = {}


## Falls back to Wheat's def for an out-of-range/unknown ordinal, matching
## farmhouse_level_def()'s existing "always return a safe, valid entry"
## precedent rather than returning null -- keeps every existing call site
## working unchanged. Closes SEC-001 (production/security/security-audit-2026-08-21.md):
## a save-loaded PlotState.crop ordinal outside CropType.Kind's defined
## range previously crashed on this Dictionary lookup, repeatedly, on the
## board's own 3s growth-resolution timer.
static func crop_def(crop: CropType.Kind) -> CropDef:
	_ensure_crop_defs()
	if not _crop_defs.has(crop):
		push_error("GameData.crop_def: unknown crop ordinal %s -- falling back to Wheat" % crop)
		return _crop_defs[CropType.Kind.WHEAT]
	return _crop_defs[crop]


static func _ensure_crop_defs() -> void:
	if not _crop_defs.is_empty():
		return
	_crop_defs[CropType.Kind.WHEAT] = CropDef.new(
		"Wheat", "🌾", 10, 120, 20, 8, PlotKind.Kind.OPEN_FIELD
	)
	_crop_defs[CropType.Kind.PADDY] = CropDef.new(
		"Paddy", "🌱", 30, 20 * 60, 80, 12, PlotKind.Kind.OPEN_FIELD
	)
	_crop_defs[CropType.Kind.TOMATO] = CropDef.new(
		"Tomato", "🍅", 60, 2 * 60 * 60, 240, 15, PlotKind.Kind.OPEN_FIELD
	)
	_crop_defs[CropType.Kind.CAPSICUM] = CropDef.new(
		"Colored Capsicum", "🫑", 150, 40 * 60, 650, 0, PlotKind.Kind.POLYHOUSE
	)
	_crop_defs[CropType.Kind.DUTCH_ROSE] = CropDef.new(
		"Dutch Rose", "🌹", 220, 60 * 60, 1100, 0, PlotKind.Kind.POLYHOUSE
	)
	# Base (Neem/Pigeon Pea host) duration; Acacia hosts shorten this -- see
	# SANDALWOOD_GROW_SECONDS_ACACIA above.
	_crop_defs[CropType.Kind.SANDALWOOD] = CropDef.new(
		"Sandalwood", "🪵", 5_000, SANDALWOOD_GROW_SECONDS_BASE, 500_000, 0, PlotKind.Kind.AGROFORESTRY
	)
	_crop_defs[CropType.Kind.MAKHANA] = CropDef.new(
		"Makhana (Fox Nut)", "🪷", 400, 6 * 60 * 60, 1_800, 0, PlotKind.Kind.AQUACULTURE
	)
	_crop_defs[CropType.Kind.POND_FISH] = CropDef.new(
		"Pond Fish", "🐟", 250, 3 * 60 * 60, 900, 0, PlotKind.Kind.AQUACULTURE
	)
	_crop_defs[CropType.Kind.SAFFRON] = CropDef.new(
		"Saffron", "🌸", 800, 90 * 60, 3_500, 0, PlotKind.Kind.VERTICAL_FARM
	)


## Crop ordinals whose `required_plot_kind` matches `kind`, in CropType.Kind's
## declared ordinal order (mirrors the Kotlin original's
## `CropType.entries.filter { it.requiredPlotKind == plotKind }` -- see
## FarmScreen.kt's SeedPicker composable). Deliberately excludes Sandalwood
## even though its own `required_plot_kind` is AGROFORESTRY: Sandalwood has
## its own dedicated planting entry point (GameEconomy.plant_sandalwood(),
## host-adjacency-gated) and GameEconomy.plant_seed() explicitly rejects it
## outright. A caller of this accessor (currently only seed_picker.gd, which
## plants exclusively via plant_seed()) would otherwise list a row that
## silently no-ops when tapped. As a consequence, an empty Agroforestry cell
## currently has no crops here at all -- board_interactor.gd falls back to
## select-only tap behavior for it, consistent with the dedicated
## "agro-host picker" being separately scoped future work, not a hardcoded
## zone-kind special case here.
static func crops_for_plot_kind(kind: PlotKind.Kind) -> Array[int]:
	_ensure_crop_defs()
	var matching: Array[int] = []
	for key in CropType.Kind.keys():
		var crop: int = CropType.Kind[key]
		if crop == CropType.Kind.SANDALWOOD:
			continue
		if _crop_defs[crop].required_plot_kind == kind:
			matching.append(crop)
	return matching

# --- Host plant catalogue -----------------------------------------------------

static var _host_defs: Dictionary = {}


## Same SEC-001 fix as crop_def() above -- falls back to Pigeon Pea (the
## cheapest, most basic host) for an out-of-range/unknown ordinal.
static func host_type_def(host: HostType.Kind) -> HostTypeDef:
	_ensure_host_defs()
	if not _host_defs.has(host):
		push_error("GameData.host_type_def: unknown host ordinal %s -- falling back to Pigeon Pea" % host)
		return _host_defs[HostType.Kind.PIGEON_PEA]
	return _host_defs[host]


static func _ensure_host_defs() -> void:
	if not _host_defs.is_empty():
		return
	_host_defs[HostType.Kind.PIGEON_PEA] = HostTypeDef.new("Pigeon Pea", "🌿", 15)
	_host_defs[HostType.Kind.NEEM] = HostTypeDef.new("Neem", "🌳", 200)
	_host_defs[HostType.Kind.ACACIA] = HostTypeDef.new("Acacia", "🌲", 350)

# --- Decoration catalogue ------------------------------------------------------

static var _decoration_defs: Dictionary = {}


## Same SEC-001 fix as crop_def() above -- falls back to Potted Plant (the
## cheapest, most basic decoration) for an out-of-range/unknown ordinal.
static func decoration_type_def(decoration: DecorationType.Kind) -> DecorationTypeDef:
	_ensure_decoration_defs()
	if not _decoration_defs.has(decoration):
		push_error("GameData.decoration_type_def: unknown decoration ordinal %s -- falling back to Potted Plant" % decoration)
		return _decoration_defs[DecorationType.Kind.POTTED_PLANT]
	return _decoration_defs[decoration]


static func _ensure_decoration_defs() -> void:
	if not _decoration_defs.is_empty():
		return
	# A Tulsi Vrindavan -- holy basil in a raised, often-decorated pot, a
	# near-ubiquitous fixture outside Indian homes.
	_decoration_defs[DecorationType.Kind.POTTED_PLANT] = DecorationTypeDef.new("Tulsi Plant", "🪴", 50)
	# Marigolds (genda phool), not sunflowers -- the flower actually used in
	# Indian festival garlands and doorway decoration.
	_decoration_defs[DecorationType.Kind.SUNFLOWER] = DecorationTypeDef.new("Marigold", "🏵️", 75)
	_decoration_defs[DecorationType.Kind.BAMBOO] = DecorationTypeDef.new("Bamboo", "🎋", 100)
	# A diya, not a paper lantern -- the small oil lamp lit for Diwali and
	# daily household worship.
	_decoration_defs[DecorationType.Kind.LANTERN] = DecorationTypeDef.new("Diya Lamp", "🪔", 150)
	# A village well/hand-pump, not an ornamental European fountain -- shared
	# water infrastructure, not decoration for its own sake.
	_decoration_defs[DecorationType.Kind.FOUNTAIN] = DecorationTypeDef.new("Village Well", "⛲", 400)
	# A small temple/shrine, not a generic statue.
	_decoration_defs[DecorationType.Kind.STATUE] = DecorationTypeDef.new("Temple Shrine", "🛕", 600)
	_decoration_defs[DecorationType.Kind.DIRT_PATH] = DecorationTypeDef.new("Dirt Path", "🟫", 10)
	_decoration_defs[DecorationType.Kind.RANGOLI] = DecorationTypeDef.new("Rangoli", "🪷", 25)

# --- The Ancestral Farmhouse: core progression hub ----------------------------

static var _farmhouse_levels: Array[FarmhouseLevelDef] = []


static func _ensure_farmhouse_levels() -> void:
	if not _farmhouse_levels.is_empty():
		return
	_farmhouse_levels.append(FarmhouseLevelDef.new(0, "Humble Hut", "🛖", 0, 50, 0, 0))
	_farmhouse_levels.append(FarmhouseLevelDef.new(1, "Kutcha House", "🏠", 2_000, 100, 3, 2))
	_farmhouse_levels.append(FarmhouseLevelDef.new(2, "Pucca House", "🏠", 8_000, 200, 6, 4))
	_farmhouse_levels.append(FarmhouseLevelDef.new(3, "Village Bungalow", "🏡", 25_000, 350, 9, 6))
	_farmhouse_levels.append(FarmhouseLevelDef.new(4, "Courtyard Haveli", "🏡", 75_000, 550, 12, 8))
	_farmhouse_levels.append(FarmhouseLevelDef.new(5, "Grand Haveli", "🏰", 200_000, 800, 15, 10))
	_farmhouse_levels.append(FarmhouseLevelDef.new(6, "Heritage Estate", "🏰", 500_000, 1_200, 18, 12))
	_farmhouse_levels.append(
		FarmhouseLevelDef.new(7, "Modern Agricultural Estate", "🏛️", 1_200_000, 2_000, 20, 15)
	)


## Clamps out-of-range lookups to the last defined tier rather than crashing
## -- a defensive fallback, not a normal code path (mirrors Kotlin's
## `FARMHOUSE_LEVELS.getOrElse(level) { .last() }`).
static func farmhouse_level_def(level: int) -> FarmhouseLevelDef:
	_ensure_farmhouse_levels()
	if level < 0 or level >= _farmhouse_levels.size():
		return _farmhouse_levels[_farmhouse_levels.size() - 1]
	return _farmhouse_levels[level]


static func farmhouse_max_level() -> int:
	_ensure_farmhouse_levels()
	return _farmhouse_levels.size() - 1

# --- Mandi demand cycle ---------------------------------------------------------

## Deterministic per-crop, per-cycle demand swing in percent (-15..20
## inclusive). Pure function of (crop, cycle_index) -- no state to persist,
## and the "tomorrow's forecast" feature just peeks at cycle_index + 1 ahead
## of time once the player has bought the auction terminal.
##
## Seeded per-call (mirrors Kotlin's `Random(seed).nextInt(-15, 21)` --
## Kotlin's nextInt(from, until) is upper-exclusive, so -15..20 inclusive,
## 36 possible values; Godot's RandomNumberGenerator.randi_range(from, to)
## is inclusive on both ends, so the equivalent call is randi_range(-15, 20)).
## The underlying PRNG algorithm differs from Kotlin's (expected, no
## cross-stack parity requirement per ADR-0002) -- what must hold, and is
## covered by tests/unit/test_randomness.gd, is that the SAME (crop,
## cycle_index) pair always produces the SAME result within this Godot build.
static func demand_modifier_percent(crop: int, cycle_index: int) -> int:
	var seed: int = crop * 104_729 + cycle_index * 7_919
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng.randi_range(-15, 20)

# --- LiveOps: Festival Event Pass ------------------------------------------------

static var _festivals: Array[FestivalDef] = []


static func _ensure_festivals() -> void:
	if not _festivals.is_empty():
		return
	_festivals.append(FestivalDef.new("Makar Sankranti", "🪁", CropType.Kind.PADDY))
	_festivals.append(FestivalDef.new("Pongal", "🍚", CropType.Kind.PADDY))
	_festivals.append(FestivalDef.new("Baisakhi", "🌾", CropType.Kind.WHEAT))


static func festival_def(cycle_index: int) -> FestivalDef:
	_ensure_festivals()
	var index: int = int(cycle_index % _festivals.size())
	return _festivals[index]

# --- LiveOps: Chanda Visit (design/gdd/festival-visiting-npcs.md) -----------
# Deliberately plural -- the four festivals represent the real religious
# makeup of a rural Indian village (Hindu, Muslim, Christian, Sikh), not any
# single community. Fixed rotation order via cycle_index % size(), same as
# festival_def() above, so every festival appears equally often.

static var _chanda_festivals: Array[ChandaFestivalDef] = []


static func _ensure_chanda_festivals() -> void:
	if not _chanda_festivals.is_empty():
		return
	_chanda_festivals.append(
		ChandaFestivalDef.new("Durga Puja", "🪔", "Durga Puja blessings to you and your family!")
	)
	_chanda_festivals.append(
		ChandaFestivalDef.new("Eid", "🌙", "Eid Mubarak to you and your family!")
	)
	_chanda_festivals.append(
		ChandaFestivalDef.new("Christmas", "🎄", "A very Merry Christmas to you and your family!")
	)
	_chanda_festivals.append(
		ChandaFestivalDef.new("Baisakhi", "🌾", "Happy Baisakhi -- may your harvest be bountiful!")
	)


static func chanda_festival_def(cycle_index: int) -> ChandaFestivalDef:
	_ensure_chanda_festivals()
	var index: int = int(cycle_index % _chanda_festivals.size())
	return _chanda_festivals[index]


static func festival_count() -> int:
	_ensure_festivals()
	return _festivals.size()
