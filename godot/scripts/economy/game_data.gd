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

# Preload CropVarietyDef so GDScript can resolve type hints
const _CropVarietyDef = preload("res://scripts/economy/crop_variety_def.gd")
const _VillagerHireDef = preload("res://scripts/economy/villager_hire_def.gd")

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

# --- LiveOps: Thief NPC Visitor (design/gdd/thief-system.md) ----------------
# Independent cycle from Festival/Chanda -- random occurrence based on wealth.
# Thief appears to steal coins; player can let them go, pay bribe, or chase them.

## Check interval (every 12 hours) if a thief visit should trigger.
const THIEF_VISIT_INTERVAL_HOURS: int = 12
## Base hourly probability (0.1%) without any security.
const THIEF_PROBABILITY_BASE: float = 0.001
## Increases with player wealth: adds (total_coins / 100_000) to probability.
const THIEF_PROBABILITY_MULTIPLIER_PER_WEALTH: float = 0.00001

## Cost to unlock Fencing (reduces theft to 50% of base probability).
const THIEF_SECURITY_FENCING_COST: int = 15_000
## Cost to unlock Guard Posts (reduces theft to 20% of base probability).
const THIEF_SECURITY_GUARD_POSTS_COST: int = 30_000
## Level 2 (Guard Posts) is the highest tier -- matches
## GameEconomy.was_thief_visiting()'s security_multiplier match, which only
## has cases for 0/1/2.
const THIEF_SECURITY_MAX_LEVEL: int = 2


## Coin cost to upgrade thief security from `current_level` to
## `current_level + 1`. Returns 0 if already at THIEF_SECURITY_MAX_LEVEL
## (caller's responsibility to check that first, same as
## farmhouse_max_level()'s convention).
static func thief_security_upgrade_cost(current_level: int) -> int:
	match current_level:
		0:
			return THIEF_SECURITY_FENCING_COST
		1:
			return THIEF_SECURITY_GUARD_POSTS_COST
		_:
			return 0


## Tier names are player-facing UI text, not data -- handled via tr()
## with keys thief.security_level_0/1/2 at the call site (ui_theme.gd's
## thief_interaction_sheet.gd/farmhouse_tab.gd convention), not returned
## as a raw string here.

## Minimum coins stolen in a thief visit.
const THIEF_STEAL_AMOUNT_MIN: int = 500
## Maximum coins stolen in a thief visit.
const THIEF_STEAL_AMOUNT_MAX: int = 2_000

## Bribe costs this percentage of the normal steal amount (50%).
const THIEF_BRIBE_PERCENTAGE: float = 0.5
## Probability of successfully chasing off the thief (30%).
const THIEF_CHASE_SUCCESS_RATE: float = 0.3
## Coins recovered if chase succeeds (75% of steal amount).
const THIEF_CHASE_RECOVERY_RATE: float = 0.75
## Penalty coins lost if chase fails (injury cost).
const THIEF_CHASE_FAILURE_PENALTY: int = 50

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
	# Tier 1: Additional Open Field crops (Indian staples)
	_crop_defs[CropType.Kind.SUGARCANE] = CropDef.new(
		"Sugarcane", "🌾", 50, 8 * 60 * 60, 400, 20, PlotKind.Kind.OPEN_FIELD
	)
	_crop_defs[CropType.Kind.MUSTARD] = CropDef.new(
		"Mustard", "🟨", 20, 4 * 60 * 60, 180, 10, PlotKind.Kind.OPEN_FIELD
	)
	_crop_defs[CropType.Kind.LENTIL] = CropDef.new(
		"Lentil (Daal)", "🟤", 30, 6 * 60 * 60, 250, 14, PlotKind.Kind.OPEN_FIELD
	)
	_crop_defs[CropType.Kind.CHICKPEA] = CropDef.new(
		"Chickpea (Chana)", "🟫", 25, 5 * 60 * 60, 200, 12, PlotKind.Kind.OPEN_FIELD
	)
	_crop_defs[CropType.Kind.MAIZE] = CropDef.new(
		"Maize (Corn)", "🌽", 40, 7 * 60 * 60, 280, 18, PlotKind.Kind.OPEN_FIELD
	)
	# Tier 2: Polyhouse crops (protected cultivation)
	_crop_defs[CropType.Kind.CUCUMBER] = CropDef.new(
		"Cucumber", "🥒", 80, 35 * 60, 450, 0, PlotKind.Kind.POLYHOUSE
	)
	_crop_defs[CropType.Kind.SPINACH] = CropDef.new(
		"Spinach (Palak)", "🥬", 60, 30 * 60, 350, 0, PlotKind.Kind.POLYHOUSE
	)
	_crop_defs[CropType.Kind.BRINJAL] = CropDef.new(
		"Brinjal (Eggplant)", "🍆", 120, 50 * 60, 550, 0, PlotKind.Kind.POLYHOUSE
	)
	# Tier 3: Agroforestry (long-term, high-value)
	_crop_defs[CropType.Kind.NEEM] = CropDef.new(
		"Neem Tree", "🌳", 2_000, 10 * 24 * 60 * 60, 150_000, 0, PlotKind.Kind.AGROFORESTRY
	)
	_crop_defs[CropType.Kind.COCONUT] = CropDef.new(
		"Coconut Palm", "🥥", 3_000, 12 * 24 * 60 * 60, 200_000, 0, PlotKind.Kind.AGROFORESTRY
	)
	# Tier 4: Specialty/Medicinal crops
	_crop_defs[CropType.Kind.TURMERIC] = CropDef.new(
		"Turmeric", "🟡", 150, 8 * 60 * 60, 800, 0, PlotKind.Kind.AQUACULTURE
	)
	_crop_defs[CropType.Kind.GINGER] = CropDef.new(
		"Ginger", "🟠", 180, 9 * 60 * 60, 900, 0, PlotKind.Kind.AQUACULTURE
	)
	_crop_defs[CropType.Kind.CARDAMOM] = CropDef.new(
		"Cardamom (Elaichi)", "⚪", 500, 120 * 60, 2_500, 0, PlotKind.Kind.VERTICAL_FARM
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
	# Level 0: Starting level (free, no upgrades yet)
	_farmhouse_levels.append(FarmhouseLevelDef.new(
		0, "Humble Hut", "🛖", 0, 1000, 0, 0.0, 0, 0.0, []
	))
	# Level 1: ₹2k, +500 storage, no unlocks
	_farmhouse_levels.append(FarmhouseLevelDef.new(
		1, "Kutcha House", "🏠", 2_000, 1500, 0, 0.0, 0, 0.0, []
	))
	# Level 2: ₹5k, +1 worker slot, unlock spice_grinder
	_farmhouse_levels.append(FarmhouseLevelDef.new(
		2, "Pucca House", "🏠", 5_000, 1500, 1, 0.0, 0, 0.0, ["spice_grinder"]
	))
	# Level 3: ₹12k, unlock textile_loom + oil_press, processing speed 1.1x (10% bonus)
	_farmhouse_levels.append(FarmhouseLevelDef.new(
		3, "Village Bungalow", "🏡", 12_000, 1500, 0, 10.0, 0, 0.0, ["textile_loom", "oil_press"]
	))
	# Level 4: ₹25k, +1000 storage, +2 worker slots
	_farmhouse_levels.append(FarmhouseLevelDef.new(
		4, "Courtyard Haveli", "🏡", 25_000, 2500, 2, 0.0, 0, 0.0, []
	))
	# Level 5: ₹50k, unlock dairy_processor, processing speed 1.2x, ₹100/hour income
	_farmhouse_levels.append(FarmhouseLevelDef.new(
		5, "Upgraded Haveli", "🏰", 50_000, 2500, 0, 20.0, 100, 0.0, ["dairy_processor"]
	))
	# Level 6: ₹75k, unlock mandi_terminal, ₹150/hour income
	_farmhouse_levels.append(FarmhouseLevelDef.new(
		6, "Heritage Manor", "🏰", 75_000, 2500, 0, 0.0, 150, 0.0, ["mandi_terminal"]
	))
	# Level 7: ₹112.5k, +1 worker slot, unlock essential_oil_distillery, ₹200/hour income
	_farmhouse_levels.append(FarmhouseLevelDef.new(
		7, "Modern Estate", "🏛️", 112_500, 2500, 1, 0.0, 200, 0.0, ["essential_oil_distillery"]
	))
	# Level 8: ₹168.75k, +2000 storage, unlock aquaculture
	_farmhouse_levels.append(FarmhouseLevelDef.new(
		8, "Grand Manor", "🏛️", 168_750, 4500, 0, 0.0, 0, 0.0, ["aquaculture"]
	))
	# Level 9: ₹253.125k, processing speed 1.35x (35% bonus), unlock vertical_farm
	_farmhouse_levels.append(FarmhouseLevelDef.new(
		9, "Agricultural Complex", "🏰", 253_125, 4500, 0, 35.0, 0, 0.0, ["vertical_farm"]
	))
	# Level 10: ₹1.5M (fixed), all storage +3000, ₹500/hour income, "Max Level"
	_farmhouse_levels.append(FarmhouseLevelDef.new(
		10, "Max Level", "🏰", 1_500_000, 7500, 0, 0.0, 500, 0.0, []
	))


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

# --- Market Forecast (E-NAM) --------------------------------------------------

## Price multipliers for each demand level (tunable economy values).
## HIGH demand (1.4x) incentivizes strategic planting of premium crops.
## MEDIUM demand (1.0x) is the baseline with no bonus or penalty.
## LOW demand (0.8x) reflects market glut or low consumer interest.
const MARKET_FORECAST_HIGH_MULTIPLIER: float = 1.4
const MARKET_FORECAST_MEDIUM_MULTIPLIER: float = 1.0
const MARKET_FORECAST_LOW_MULTIPLIER: float = 0.8

## How many crops appear in each day's forecast (range 5-10, deterministic per date).
const MARKET_FORECAST_MIN_CROPS: int = 5
const MARKET_FORECAST_MAX_CROPS: int = 10

## Probability distribution for demand levels in the forecast (must sum to 100).
## Example: [30, 50, 20] means 30% HIGH, 50% MEDIUM, 20% LOW.
const MARKET_FORECAST_LEVEL_WEIGHTS: Array[int] = [30, 50, 20]  # HIGH, MEDIUM, LOW


## Generates tomorrow's market forecast deterministically from today's date.
## Returns a Dictionary: crop_kind (int) -> MarketForecastDef.
## Each date always produces the same forecast (no save-scumming).
static func generate_market_forecast(now_ms: int) -> Dictionary:
	var tomorrow_key: int = local_day_key_tomorrow(now_ms)
	var seed: int = tomorrow_key * 997  # Large prime to spread the seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Decide how many crops to forecast (5-10, deterministic per date)
	var crop_count: int = rng.randi_range(MARKET_FORECAST_MIN_CROPS, MARKET_FORECAST_MAX_CROPS)

	# Collect all crops and shuffle them seeded
	_ensure_crop_defs()
	var all_crops: Array[int] = []
	for crop_key in _crop_defs.keys():
		all_crops.append(crop_key)

	# Fisher-Yates shuffle with seeded RNG
	for i in range(all_crops.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp = all_crops[i]
		all_crops[i] = all_crops[j]
		all_crops[j] = temp

	# Pick the first `crop_count` shuffled crops
	var forecast: Dictionary = {}
	for i in range(mini(crop_count, all_crops.size())):
		var crop: int = all_crops[i]

		# Determine demand level based on weighted distribution
		var rand_level: int = rng.randi_range(0, 99)
		var demand_level: int = MarketForecastDef.DemandLevel.MEDIUM
		var cumulative: int = 0
		for level in range(MARKET_FORECAST_LEVEL_WEIGHTS.size()):
			cumulative += MARKET_FORECAST_LEVEL_WEIGHTS[level]
			if rand_level < cumulative:
				demand_level = level
				break

		# Map demand level to price multiplier
		var multiplier: float = MARKET_FORECAST_MEDIUM_MULTIPLIER
		match demand_level:
			MarketForecastDef.DemandLevel.HIGH:
				multiplier = MARKET_FORECAST_HIGH_MULTIPLIER
			MarketForecastDef.DemandLevel.MEDIUM:
				multiplier = MARKET_FORECAST_MEDIUM_MULTIPLIER
			MarketForecastDef.DemandLevel.LOW:
				multiplier = MARKET_FORECAST_LOW_MULTIPLIER

		forecast[crop] = MarketForecastDef.new(crop, demand_level, multiplier, tomorrow_key)

	return forecast


## Helper: compute tomorrow's local day key (current day + 1).
## Same timezone-aware YYYYMMDD-key formula as GameEconomy.local_day_key()
## (deliberately re-implemented here rather than called cross-class: GameData
## is the Foundation-layer catalogue GameEconomy depends on, not the reverse
## -- see the worker-economy section's layering note further down this file).
static func local_day_key_tomorrow(now_ms: int) -> int:
	var tz: Dictionary = Time.get_time_zone_from_system()
	var shifted_seconds: int = now_ms / 1000 + int(tz.get("bias", 0)) * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(shifted_seconds)
	var today_key: int = int(d.year) * 10000 + int(d.month) * 100 + int(d.day)

	# Parse today's date
	var year: int = today_key / 10000
	var month: int = (today_key / 100) % 100
	var day: int = today_key % 100

	# Advance by one day (simple increment; let OS handle month/year rollover)
	day += 1
	var days_in_month: int = 28
	match month:
		1, 3, 5, 7, 8, 10, 12:
			days_in_month = 31
		4, 6, 9, 11:
			days_in_month = 30
		2:
			days_in_month = 29 if (year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)) else 28

	if day > days_in_month:
		day = 1
		month += 1
		if month > 12:
			month = 1
			year += 1

	return year * 10000 + month * 100 + day


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

# --- Crop Varieties (Regional Specialties) --------------------------------

## Maps crop ordinal -> array of variety definitions, indexed by variety ordinal.
## A crop with no variants (or a single default variant) still has an array of
## size 1 at index 0. This ensures GameEconomy.plant_seed() can always safely
## call varieties_for_crop(crop)[0] for backwards compatibility.
static var _crop_varieties: Dictionary = {}


static func _ensure_crop_varieties() -> void:
	if not _crop_varieties.is_empty():
		return

	# Wheat variants
	_crop_varieties[CropType.Kind.WHEAT] = [
		CropVarietyDef.new("Standard Wheat", "🌾", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Basmati Wheat", "🌾", 1.1, 1.15, 1.25, 0.9) as CropVarietyDef,  # slower, more valuable, less hardy
	] as Array[CropVarietyDef]

	# Paddy variants
	_crop_varieties[CropType.Kind.PADDY] = [
		CropVarietyDef.new("Standard Paddy", "🌱", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Jasmine Rice", "🌱", 0.95, 1.2, 1.35, 0.85) as CropVarietyDef,  # faster, premium, slightly hardier
	] as Array[CropVarietyDef]

	# Tomato variants
	_crop_varieties[CropType.Kind.TOMATO] = [
		CropVarietyDef.new("Standard Tomato", "🍅", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Heirloom Tomato", "🍅", 1.15, 1.25, 1.4, 0.95) as CropVarietyDef,  # slower, expensive seed, premium price
	] as Array[CropVarietyDef]

	# Capsicum variants (Polyhouse)
	_crop_varieties[CropType.Kind.CAPSICUM] = [
		CropVarietyDef.new("Standard Capsicum", "🫑", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Hybrid Capsicum", "🫑", 0.85, 1.3, 1.5, 1.0) as CropVarietyDef,  # hybrid vigor: faster, premium
	] as Array[CropVarietyDef]

	# Dutch Rose variants (Polyhouse)
	_crop_varieties[CropType.Kind.DUTCH_ROSE] = [
		CropVarietyDef.new("Standard Rose", "🌹", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Premium Red Rose", "🌹", 1.05, 1.4, 1.6, 1.0) as CropVarietyDef,  # slightly slower, much costlier, luxury
	] as Array[CropVarietyDef]

	# Sandalwood variants (Agroforestry)
	_crop_varieties[CropType.Kind.SANDALWOOD] = [
		CropVarietyDef.new("Standard Sandalwood", "🪵", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Kashmiri Sandalwood", "🪵", 0.9, 1.5, 1.8, 1.0) as CropVarietyDef,  # faster maturity, rarer, premium
	] as Array[CropVarietyDef]

	# Makhana variants (Aquaculture)
	_crop_varieties[CropType.Kind.MAKHANA] = [
		CropVarietyDef.new("Standard Makhana", "🪷", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Premium Makhana", "🪷", 1.1, 1.2, 1.25, 1.0) as CropVarietyDef,  # slower, premium variety
	] as Array[CropVarietyDef]

	# Pond Fish variants (Aquaculture)
	_crop_varieties[CropType.Kind.POND_FISH] = [
		CropVarietyDef.new("Standard Fish", "🐟", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Silver Carp", "🐟", 0.9, 1.1, 1.3, 1.0) as CropVarietyDef,  # faster, good yield
	] as Array[CropVarietyDef]

	# Saffron variants (Vertical Farm) - most varieties, highest specialization
	_crop_varieties[CropType.Kind.SAFFRON] = [
		CropVarietyDef.new("Standard Saffron", "🌸", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Kashmiri Saffron", "🌸", 1.15, 2.0, 2.2, 1.0) as CropVarietyDef,  # legendary, expensive, premium
		CropVarietyDef.new("Assamese Saffron", "🌸", 0.95, 1.5, 1.6, 1.0) as CropVarietyDef,  # regional specialty, efficient
	] as Array[CropVarietyDef]

	# Sugarcane variants (Open Field)
	_crop_varieties[CropType.Kind.SUGARCANE] = [
		CropVarietyDef.new("Standard Sugarcane", "🌾", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Co-86 Hybrid", "🌾", 0.9, 1.2, 1.4, 0.9) as CropVarietyDef,  # fast, premium
	] as Array[CropVarietyDef]

	# Mustard variants (Open Field)
	_crop_varieties[CropType.Kind.MUSTARD] = [
		CropVarietyDef.new("Standard Mustard", "🟨", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Rai Mustard", "🟨", 1.05, 1.1, 1.15, 1.0) as CropVarietyDef,  # slightly slower, hardy
	] as Array[CropVarietyDef]

	# Lentil variants (Open Field)
	_crop_varieties[CropType.Kind.LENTIL] = [
		CropVarietyDef.new("Standard Lentil", "🟤", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Masoor Premium", "🟤", 0.95, 1.15, 1.25, 1.0) as CropVarietyDef,  # faster, premium
	] as Array[CropVarietyDef]

	# Chickpea variants (Open Field)
	_crop_varieties[CropType.Kind.CHICKPEA] = [
		CropVarietyDef.new("Standard Chickpea", "🟫", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Kabuli Chana", "🟫", 1.1, 1.2, 1.3, 0.95) as CropVarietyDef,  # specialty, hardy
	] as Array[CropVarietyDef]

	# Maize variants (Open Field)
	_crop_varieties[CropType.Kind.MAIZE] = [
		CropVarietyDef.new("Standard Maize", "🌽", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Hybrid Maize", "🌽", 0.85, 1.25, 1.35, 1.0) as CropVarietyDef,  # fast, premium
	] as Array[CropVarietyDef]

	# Cucumber variants (Polyhouse)
	_crop_varieties[CropType.Kind.CUCUMBER] = [
		CropVarietyDef.new("Standard Cucumber", "🥒", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Dutch Cucumber", "🥒", 0.9, 1.3, 1.45, 1.0) as CropVarietyDef,  # fast hybrid, premium
	] as Array[CropVarietyDef]

	# Spinach variants (Polyhouse)
	_crop_varieties[CropType.Kind.SPINACH] = [
		CropVarietyDef.new("Standard Spinach", "🥬", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Organic Palak", "🥬", 1.05, 1.15, 1.25, 1.0) as CropVarietyDef,  # premium organic
	] as Array[CropVarietyDef]

	# Brinjal variants (Polyhouse)
	_crop_varieties[CropType.Kind.BRINJAL] = [
		CropVarietyDef.new("Standard Brinjal", "🍆", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Long Brinjal", "🍆", 0.95, 1.2, 1.3, 1.0) as CropVarietyDef,  # faster, specialty
	] as Array[CropVarietyDef]

	# Neem variants (Agroforestry)
	_crop_varieties[CropType.Kind.NEEM] = [
		CropVarietyDef.new("Standard Neem", "🌳", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("High-Yield Neem", "🌳", 0.95, 1.3, 1.4, 1.0) as CropVarietyDef,  # faster, premium
	] as Array[CropVarietyDef]

	# Coconut variants (Agroforestry)
	_crop_varieties[CropType.Kind.COCONUT] = [
		CropVarietyDef.new("Standard Coconut", "🥥", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Hybrid Coconut", "🥥", 0.9, 1.4, 1.5, 1.0) as CropVarietyDef,  # fast, premium
	] as Array[CropVarietyDef]

	# Turmeric variants (Specialty)
	_crop_varieties[CropType.Kind.TURMERIC] = [
		CropVarietyDef.new("Standard Turmeric", "🟡", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Erode Turmeric", "🟡", 1.05, 1.35, 1.5, 1.0) as CropVarietyDef,  # premium medicinal
	] as Array[CropVarietyDef]

	# Ginger variants (Specialty)
	_crop_varieties[CropType.Kind.GINGER] = [
		CropVarietyDef.new("Standard Ginger", "🟠", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Kerala Ginger", "🟠", 1.1, 1.3, 1.4, 1.0) as CropVarietyDef,  # premium regional
	] as Array[CropVarietyDef]

	# Cardamom variants (Vertical Farm)
	_crop_varieties[CropType.Kind.CARDAMOM] = [
		CropVarietyDef.new("Standard Cardamom", "⚪", 1.0, 1.0, 1.0, 1.0) as CropVarietyDef,
		CropVarietyDef.new("Green Cardamom", "⚪", 1.15, 1.8, 2.0, 1.0) as CropVarietyDef,  # luxury spice
	] as Array[CropVarietyDef]


## Returns all varieties available for a crop (always non-empty).
## Crops without explicit varieties have a single default variant.
static func varieties_for_crop(crop: int) -> Array[CropVarietyDef]:
	_ensure_crop_varieties()
	if _crop_varieties.has(crop):
		return _crop_varieties[crop]
	# Fallback: single default variety (1.0x on all modifiers)
	return [CropVarietyDef.new("Default", "❓", 1.0, 1.0, 1.0, 1.0)]


## Looks up a specific variety definition. Falls back to variety 0 (default)
## for out-of-range ordinals, matching the SEC-001 defensive pattern.
# --- Seasonal Crop Rotation ---------------------------------------------------

## Maps crop ordinal -> array of available seasons (SeasonType.Kind values).
## Each crop has a list of seasons when it can be planted.
## Year-round crops (Sandalwood, Saffron, Neem, Coconut) appear in all 4 seasons.
static var _crop_season_map: Dictionary = {}


static func _ensure_crop_season_map() -> void:
	if not _crop_season_map.is_empty():
		return

	# Preload SeasonType so we can access its enum
	var ST = preload("res://scripts/economy/season_type.gd")

	# Spring (March 21 - June 20)
	# NOTE: the original pass at this map referenced 11 crop names (Chili, Peas,
	# Cotton, Okra, Basil, Jute, Rice, Rapeseed, Radish, Cabbage, Cauliflower)
	# that don't exist in CropType.Kind (see crop_type.gd) -- guarding the
	# reference with `.has()` doesn't help, since GDScript resolves
	# `CropType.Kind.SOMENAME` as a static reference at parse time regardless
	# of the runtime guard around it. Pared down to this project's real 22
	# crops only; DUTCH_ROSE is deliberately absent from every list below
	# (Polyhouse-grown, climate-controlled) and falls through to
	# crop_available_seasons()'s year-round fallback.
	var spring_crops: Array[int] = [
		CropType.Kind.WHEAT,
		CropType.Kind.CHICKPEA,
		CropType.Kind.LENTIL,
		CropType.Kind.TOMATO,
		CropType.Kind.CUCUMBER,
		CropType.Kind.SPINACH,
	]

	# Summer (June 21 - September 22)
	var summer_crops: Array[int] = [
		CropType.Kind.MAIZE,
		CropType.Kind.SUGARCANE,
		CropType.Kind.CAPSICUM,
		CropType.Kind.BRINJAL,
	]

	# Monsoon (September 23 - December 21)
	var monsoon_crops: Array[int] = [
		CropType.Kind.PADDY,
		CropType.Kind.MAKHANA,
		CropType.Kind.POND_FISH,
		CropType.Kind.SUGARCANE,
		CropType.Kind.TURMERIC,
		CropType.Kind.GINGER,
	]

	# Winter (December 22 - March 20)
	var winter_crops: Array[int] = [
		CropType.Kind.WHEAT,
		CropType.Kind.CHICKPEA,
		CropType.Kind.LENTIL,
		CropType.Kind.MUSTARD,
		CropType.Kind.CARDAMOM,
	]

	# Year-round crops (available all seasons)
	var year_round_crops: Array[int] = [
		CropType.Kind.SANDALWOOD,
		CropType.Kind.SAFFRON,
		CropType.Kind.NEEM,
		CropType.Kind.COCONUT,
	]

	# Map each crop to its available seasons
	for crop in spring_crops:
		if not _crop_season_map.has(crop):
			_crop_season_map[crop] = []
		_crop_season_map[crop].append(ST.Kind.SPRING)

	for crop in summer_crops:
		if not _crop_season_map.has(crop):
			_crop_season_map[crop] = []
		_crop_season_map[crop].append(ST.Kind.SUMMER)

	for crop in monsoon_crops:
		if not _crop_season_map.has(crop):
			_crop_season_map[crop] = []
		_crop_season_map[crop].append(ST.Kind.MONSOON)

	for crop in winter_crops:
		if not _crop_season_map.has(crop):
			_crop_season_map[crop] = []
		_crop_season_map[crop].append(ST.Kind.WINTER)

	for crop in year_round_crops:
		_crop_season_map[crop] = [ST.Kind.SPRING, ST.Kind.SUMMER, ST.Kind.MONSOON, ST.Kind.WINTER]


## Returns the array of seasons when a crop can be planted.
## For year-round crops, returns all 4 seasons.
## For seasonal crops, returns only their designated seasons.
static func crop_available_seasons(crop_kind: int) -> Array:
	_ensure_crop_season_map()
	if _crop_season_map.has(crop_kind):
		return _crop_season_map[crop_kind]
	# Defensive fallback: if crop not found, treat as year-round
	var ST = preload("res://scripts/economy/season_type.gd")
	return [ST.Kind.SPRING, ST.Kind.SUMMER, ST.Kind.MONSOON, ST.Kind.WINTER]


## Checks if a crop can be planted during the given season.
static func is_crop_available_this_season(crop_kind: int, season: int) -> bool:
	var available_seasons = crop_available_seasons(crop_kind)
	return season in available_seasons


static func crop_variety_def(crop: int, variety: int) -> CropVarietyDef:
	var varieties := varieties_for_crop(crop)
	if variety < 0 or variety >= varieties.size():
		push_error("GameData.crop_variety_def: crop %d variety %d out of range -- falling back to variety 0" % [crop, variety])
		return varieties[0]
	return varieties[variety]


# --- Crop Processing Pipeline (design/gdd/crop-processing-pipeline.md) -------

static var _processing_recipes: Dictionary = {}
static var _processing_buildings: Dictionary = {}


static func _ensure_processing_buildings() -> void:
	if not _processing_buildings.is_empty():
		return
	# Spice Grinder: fast, low-cost entry point
	_processing_buildings["spice_grinder"] = ProcessingBuildingDef.new(
		"spice_grinder", "Spice Grinder", 5_000, "🌶️",
		"Grinds turmeric, chili, and coriander into premium spice powders",
		5, 1.0
	)
	# Textile Loom: mid-tier, longer processing
	_processing_buildings["textile_loom"] = ProcessingBuildingDef.new(
		"textile_loom", "Textile Loom", 8_000, "🧵",
		"Weaves cotton and jute into fine fabric and rope",
		5, 1.0
	)
	# Oil Press: versatile, multiple oil outputs
	_processing_buildings["oil_press"] = ProcessingBuildingDef.new(
		"oil_press", "Oil Press", 10_000, "🫒",
		"Presses coconut, mustard, and sesame into pure cooking oils",
		5, 1.0
	)
	# Essential Oil Distillery: high-cost, long-duration luxury
	_processing_buildings["essential_oil_distillery"] = ProcessingBuildingDef.new(
		"essential_oil_distillery", "Essential Oil Distillery", 50_000, "🧴",
		"Distills sandalwood and rose into precious essential oils",
		5, 1.0
	)
	# Flour Mill: fast, affordable staple processing
	_processing_buildings["flour_mill"] = ProcessingBuildingDef.new(
		"flour_mill", "Flour Mill", 5_000, "🌾",
		"Grinds wheat and rice into premium flours",
		5, 1.0
	)
	# Dairy Processor: mid-tier, medium-duration dairy products
	_processing_buildings["dairy_processor"] = ProcessingBuildingDef.new(
		"dairy_processor", "Dairy Processor", 8_000, "🧀",
		"Processes milk into cheese and yogurt",
		5, 1.0
	)


static func _ensure_processing_recipes() -> void:
	if not _processing_recipes.is_empty():
		return

	# === Spice Grinder recipes (5) ===
	_processing_recipes["turmeric_to_spice"] = ProcessingRecipeDef.new(
		"turmeric_to_spice", "Premium Spice Jar",
		CropType.Kind.TURMERIC, 10, "Premium Spice Jar",
		600, 60, "spice_grinder"
	)
	_processing_recipes["chili_to_powder"] = ProcessingRecipeDef.new(
		"chili_to_powder", "Chili Powder",
		CropType.Kind.TOMATO, 8, "Chili Powder",  # Using TOMATO as placeholder for chili
		450, 90, "spice_grinder"
	)
	_processing_recipes["coriander_to_powder"] = ProcessingRecipeDef.new(
		"coriander_to_powder", "Coriander Powder",
		CropType.Kind.LENTIL, 6, "Coriander Powder",  # Using LENTIL as placeholder
		350, 60, "spice_grinder"
	)
	_processing_recipes["ginger_to_powder"] = ProcessingRecipeDef.new(
		"ginger_to_powder", "Ginger Powder",
		CropType.Kind.GINGER, 5, "Ginger Powder",
		400, 75, "spice_grinder"
	)
	_processing_recipes["cardamom_to_powder"] = ProcessingRecipeDef.new(
		"cardamom_to_powder", "Cardamom Powder",
		CropType.Kind.CARDAMOM, 3, "Cardamom Powder",
		800, 120, "spice_grinder"
	)

	# === Textile Loom recipes (5) ===
	_processing_recipes["cotton_to_fabric"] = ProcessingRecipeDef.new(
		"cotton_to_fabric", "Fine Fabric",
		CropType.Kind.MAIZE, 15, "Fine Fabric",  # Using MAIZE as placeholder for cotton
		800, 180, "textile_loom"
	)
	_processing_recipes["jute_to_rope"] = ProcessingRecipeDef.new(
		"jute_to_rope", "Jute Rope",
		CropType.Kind.LENTIL, 12, "Jute Rope",  # Using LENTIL as placeholder
		500, 150, "textile_loom"
	)
	_processing_recipes["silk_to_cloth"] = ProcessingRecipeDef.new(
		"silk_to_cloth", "Silk Cloth",
		CropType.Kind.DUTCH_ROSE, 10, "Silk Cloth",  # Using DUTCH_ROSE as placeholder
		1200, 240, "textile_loom"
	)
	_processing_recipes["hemp_to_canvas"] = ProcessingRecipeDef.new(
		"hemp_to_canvas", "Hemp Canvas",
		CropType.Kind.SUGARCANE, 18, "Hemp Canvas",  # Using SUGARCANE as placeholder
		650, 200, "textile_loom"
	)
	_processing_recipes["bamboo_to_mat"] = ProcessingRecipeDef.new(
		"bamboo_to_mat", "Bamboo Mat",
		CropType.Kind.BRINJAL, 8, "Bamboo Mat",  # Using BRINJAL as placeholder
		450, 120, "textile_loom"
	)

	# === Oil Press recipes (5) ===
	_processing_recipes["coconut_to_oil"] = ProcessingRecipeDef.new(
		"coconut_to_oil", "Coconut Oil",
		CropType.Kind.COCONUT, 5, "Coconut Oil",
		1000, 150, "oil_press"
	)
	_processing_recipes["mustard_to_oil"] = ProcessingRecipeDef.new(
		"mustard_to_oil", "Mustard Oil",
		CropType.Kind.MUSTARD, 8, "Mustard Oil",
		600, 120, "oil_press"
	)
	_processing_recipes["sesame_to_oil"] = ProcessingRecipeDef.new(
		"sesame_to_oil", "Sesame Oil",
		CropType.Kind.LENTIL, 10, "Sesame Oil",  # Using LENTIL as placeholder
		750, 140, "oil_press"
	)
	_processing_recipes["sunflower_to_oil"] = ProcessingRecipeDef.new(
		"sunflower_to_oil", "Sunflower Oil",
		CropType.Kind.TOMATO, 12, "Sunflower Oil",  # Using TOMATO as placeholder
		550, 130, "oil_press"
	)
	_processing_recipes["groundnut_to_oil"] = ProcessingRecipeDef.new(
		"groundnut_to_oil", "Groundnut Oil",
		CropType.Kind.CHICKPEA, 10, "Groundnut Oil",  # Using CHICKPEA as placeholder
		500, 110, "oil_press"
	)

	# === Essential Oil Distillery recipes (5) ===
	_processing_recipes["sandalwood_to_oil"] = ProcessingRecipeDef.new(
		"sandalwood_to_oil", "Sandalwood Essential Oil",
		CropType.Kind.SANDALWOOD, 2, "Sandalwood Essential Oil",
		5000, 43200, "essential_oil_distillery"  # 12 hours
	)
	_processing_recipes["rose_to_oil"] = ProcessingRecipeDef.new(
		"rose_to_oil", "Rose Essential Oil",
		CropType.Kind.DUTCH_ROSE, 15, "Rose Essential Oil",
		3500, 36000, "essential_oil_distillery"  # 10 hours
	)
	_processing_recipes["lavender_to_oil"] = ProcessingRecipeDef.new(
		"lavender_to_oil", "Lavender Essential Oil",
		CropType.Kind.SPINACH, 20, "Lavender Essential Oil",  # Using SPINACH as placeholder
		2500, 28800, "essential_oil_distillery"  # 8 hours
	)
	_processing_recipes["jasmine_to_oil"] = ProcessingRecipeDef.new(
		"jasmine_to_oil", "Jasmine Essential Oil",
		CropType.Kind.CAPSICUM, 18, "Jasmine Essential Oil",  # Using CAPSICUM as placeholder
		3000, 32400, "essential_oil_distillery"  # 9 hours
	)
	_processing_recipes["lemongrass_to_oil"] = ProcessingRecipeDef.new(
		"lemongrass_to_oil", "Lemongrass Essential Oil",
		CropType.Kind.CUCUMBER, 25, "Lemongrass Essential Oil",  # Using CUCUMBER as placeholder
		1800, 21600, "essential_oil_distillery"  # 6 hours
	)

	# === Flour Mill recipes (5) ===
	_processing_recipes["wheat_to_flour"] = ProcessingRecipeDef.new(
		"wheat_to_flour", "Premium Flour",
		CropType.Kind.WHEAT, 8, "Premium Flour",
		450, 90, "flour_mill"
	)
	_processing_recipes["rice_to_flour"] = ProcessingRecipeDef.new(
		"rice_to_flour", "Rice Flour",
		CropType.Kind.PADDY, 10, "Rice Flour",
		400, 75, "flour_mill"
	)
	_processing_recipes["maize_to_flour"] = ProcessingRecipeDef.new(
		"maize_to_flour", "Cornmeal",
		CropType.Kind.MAIZE, 6, "Cornmeal",
		350, 60, "flour_mill"
	)
	_processing_recipes["chickpea_to_flour"] = ProcessingRecipeDef.new(
		"chickpea_to_flour", "Besan (Chickpea Flour)",
		CropType.Kind.CHICKPEA, 7, "Besan (Chickpea Flour)",
		420, 80, "flour_mill"
	)
	_processing_recipes["lentil_to_flour"] = ProcessingRecipeDef.new(
		"lentil_to_flour", "Lentil Flour",
		CropType.Kind.LENTIL, 8, "Lentil Flour",
		380, 70, "flour_mill"
	)

	# === Dairy Processor recipes (5) ===
	# Note: Milk is not a crop, so we use placeholder crops
	_processing_recipes["milk_to_cheese"] = ProcessingRecipeDef.new(
		"milk_to_cheese", "Farm Cheese",
		CropType.Kind.TOMATO, 1, "Farm Cheese",  # Placeholder - milk not in crop list
		300, 7200, "dairy_processor"  # 2 hours
	)
	_processing_recipes["milk_to_yogurt"] = ProcessingRecipeDef.new(
		"milk_to_yogurt", "Fresh Yogurt",
		CropType.Kind.CUCUMBER, 1, "Fresh Yogurt",  # Placeholder
		200, 5400, "dairy_processor"  # 1.5 hours
	)
	_processing_recipes["milk_to_ghee"] = ProcessingRecipeDef.new(
		"milk_to_ghee", "Pure Ghee",
		CropType.Kind.CAPSICUM, 1, "Pure Ghee",  # Placeholder
		600, 10800, "dairy_processor"  # 3 hours
	)
	_processing_recipes["milk_to_paneer"] = ProcessingRecipeDef.new(
		"milk_to_paneer", "Fresh Paneer",
		CropType.Kind.BRINJAL, 1, "Fresh Paneer",  # Placeholder
		400, 5400, "dairy_processor"  # 1.5 hours
	)
	_processing_recipes["milk_to_butter"] = ProcessingRecipeDef.new(
		"milk_to_butter", "Farm Butter",
		CropType.Kind.SPINACH, 1, "Farm Butter",  # Placeholder
		350, 7200, "dairy_processor"  # 2 hours
	)


## Returns the processing building definition for a given key, or null if not found.
static func processing_building_def(building_key: String) -> ProcessingBuildingDef:
	_ensure_processing_buildings()
	if not _processing_buildings.has(building_key):
		push_error("GameData.processing_building_def: unknown building key '%s'" % building_key)
		return null
	return _processing_buildings[building_key]


## Returns the recipe definition for a given key, or null if not found.
static func processing_recipe_def(recipe_key: String) -> ProcessingRecipeDef:
	_ensure_processing_recipes()
	if not _processing_recipes.has(recipe_key):
		push_error("GameData.processing_recipe_def: unknown recipe key '%s'" % recipe_key)
		return null
	return _processing_recipes[recipe_key]


## Returns all recipes that can be processed by a specific building.
static func recipes_for_building(building_key: String) -> Array[ProcessingRecipeDef]:
	_ensure_processing_recipes()
	var result: Array[ProcessingRecipeDef] = []
	for key in _processing_recipes.keys():
		var recipe: ProcessingRecipeDef = _processing_recipes[key]
		if recipe.required_building == building_key:
			result.append(recipe)
	return result


## Returns all processing building definitions.
static func all_processing_buildings() -> Array[ProcessingBuildingDef]:
	_ensure_processing_buildings()
	var result: Array[ProcessingBuildingDef] = []
	for key in _processing_buildings.keys():
		result.append(_processing_buildings[key])
	return result


## Returns all recipe definitions.
static func all_processing_recipes() -> Array[ProcessingRecipeDef]:
	_ensure_processing_recipes()
	var result: Array[ProcessingRecipeDef] = []
	for key in _processing_recipes.keys():
		result.append(_processing_recipes[key])
	return result


# --- EPIC-M7+: Villager Hiring System -----------------------------------------------
# design/gdd/worker-economy.md §6 (proposed) -- hired villagers consume food daily,
# require housing capacity tied to farmhouse level, and boost farm productivity.

## Housing capacity granted per farmhouse level (0-indexed). Level 0 starts with 0
## villager slots; Level 2 unlocks the first slot (+1), Level 4 adds more, etc.
const VILLAGER_HOUSING_PER_LEVEL: Array[int] = [
	0,   # Level 0: none
	0,   # Level 1: none
	1,   # Level 2: 1 slot (when workers first become available)
	1,   # Level 3: still 1
	2,   # Level 4: 2 slots
	2,   # Level 5: still 2
	3,   # Level 6: 3 slots
	3,   # Level 7: still 3
	4,   # Level 8: 4 slots
	5,   # Level 9: 5 slots
	6,   # Level 10 (max): 6 slots
]

static var _villager_defs: Dictionary = {}


static func _ensure_villager_defs() -> void:
	if not _villager_defs.is_empty():
		return

	# 25 hireable villagers with varied stats, all using Indian names
	# Skill levels: 1 = basic, 2 = intermediate, 3 = advanced
	# Costs scale with skill; higher skill = higher salary + food needs

	_villager_defs["rajesh_01"] = VillagerHireDef.new("rajesh_01", "Rajesh", 2, 5_000, 500, 2)
	_villager_defs["priya_01"] = VillagerHireDef.new("priya_01", "Priya", 3, 8_000, 750, 3)
	_villager_defs["arjun_01"] = VillagerHireDef.new("arjun_01", "Arjun", 1, 2_000, 300, 1)
	_villager_defs["deepa_01"] = VillagerHireDef.new("deepa_01", "Deepa", 2, 4_500, 450, 2)
	_villager_defs["vikram_01"] = VillagerHireDef.new("vikram_01", "Vikram", 3, 10_000, 800, 3)
	_villager_defs["anjali_01"] = VillagerHireDef.new("anjali_01", "Anjali", 1, 1_800, 280, 1)
	_villager_defs["neel_01"] = VillagerHireDef.new("neel_01", "Neel", 2, 5_500, 550, 2)
	_villager_defs["swati_01"] = VillagerHireDef.new("swati_01", "Swati", 2, 4_800, 480, 2)
	_villager_defs["aditya_01"] = VillagerHireDef.new("aditya_01", "Aditya", 1, 2_200, 320, 1)
	_villager_defs["meera_01"] = VillagerHireDef.new("meera_01", "Meera", 3, 9_000, 700, 3)
	_villager_defs["suresh_01"] = VillagerHireDef.new("suresh_01", "Suresh", 1, 2_000, 300, 1)
	_villager_defs["kavya_01"] = VillagerHireDef.new("kavya_01", "Kavya", 2, 4_200, 420, 2)
	_villager_defs["rohan_01"] = VillagerHireDef.new("rohan_01", "Rohan", 2, 5_200, 520, 2)
	_villager_defs["shruti_01"] = VillagerHireDef.new("shruti_01", "Shruti", 3, 9_500, 750, 3)
	_villager_defs["prakash_01"] = VillagerHireDef.new("prakash_01", "Prakash", 1, 2_500, 350, 1)
	_villager_defs["divya_01"] = VillagerHireDef.new("divya_01", "Divya", 1, 1_900, 290, 1)
	_villager_defs["harsh_01"] = VillagerHireDef.new("harsh_01", "Harsh", 2, 4_800, 480, 2)
	_villager_defs["sneha_01"] = VillagerHireDef.new("sneha_01", "Sneha", 2, 5_000, 500, 2)
	_villager_defs["ashok_01"] = VillagerHireDef.new("ashok_01", "Ashok", 3, 8_500, 700, 3)
	_villager_defs["pooja_01"] = VillagerHireDef.new("pooja_01", "Pooja", 1, 2_100, 310, 1)
	_villager_defs["sanjay_01"] = VillagerHireDef.new("sanjay_01", "Sanjay", 3, 9_200, 750, 3)
	_villager_defs["neha_01"] = VillagerHireDef.new("neha_01", "Neha", 2, 4_500, 450, 2)
	_villager_defs["rishabh_01"] = VillagerHireDef.new("rishabh_01", "Rishabh", 1, 2_300, 330, 1)
	_villager_defs["isha_01"] = VillagerHireDef.new("isha_01", "Isha", 3, 8_800, 720, 3)
	_villager_defs["manu_01"] = VillagerHireDef.new("manu_01", "Manu", 2, 5_300, 530, 2)


## Returns a single villager definition by ID, or null if not found.
static func hire_villager_def(villager_id: String) -> VillagerHireDef:
	_ensure_villager_defs()
	return _villager_defs.get(villager_id, null)


## Returns all available hireable villagers as an array.
static func all_available_villagers() -> Array[VillagerHireDef]:
	_ensure_villager_defs()
	var result: Array[VillagerHireDef] = []
	for def in _villager_defs.values():
		result.append(def as VillagerHireDef)
	return result


## Returns the total housing capacity for a given farmhouse level.
static func villager_housing_capacity(farmhouse_level: int) -> int:
	if farmhouse_level < 0 or farmhouse_level >= VILLAGER_HOUSING_PER_LEVEL.size():
		return VILLAGER_HOUSING_PER_LEVEL[-1]
	return VILLAGER_HOUSING_PER_LEVEL[farmhouse_level]
