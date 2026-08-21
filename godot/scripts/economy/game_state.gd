## The full persisted game state. Port of GameModels.kt's `GameState` data
## class. Saved/loaded whole via SaveSystem (save_system.gd) as a single
## Godot Resource (.tres), per ADR-0002 -- not JSON, not compatible with the
## old Kotlin/GameRepository.kt schema.
##
## Nullable Long fields in the Kotlin source (film_expires_at_epoch_ms,
## electricity_expires_at_epoch_ms) use a -1 sentinel here, matching the exact
## convention GameRepository.kt itself already used when serializing those
## same fields to JSON (`filmExpiresAtEpochMs ?: -1L`) -- continuity with
## existing prior art, not a new pattern invented for this port.
##
## Dictionary keys below are plain CropType.Kind/String values (Godot 4.4+
## typed Dictionaries are available on this project's pinned 4.7.1, but kept
## untyped here for simplicity porting from Kotlin's Map<CropType, ...> --
## revisit if static-typing the Dictionary value types proves worthwhile).
class_name GameState
extends Resource

@export var coins: int = 300
@export var plots: Array[Plot] = []
## CropType.Kind ordinal (int) -> CropStock.
@export var inventory: Dictionary = {}
@export var last_weather_event: String = ""
## Lifetime harvest count, used to unlock the government Polyhouse subsidy.
@export var total_harvests: int = 0
@export var has_polyhouse: bool = false
@export var has_fan_pad: bool = false
@export var has_drip_irrigation: bool = false
## -1 = no UV film ever bought. Once bought, protection only applies while
## now < this.
@export var film_expires_at_epoch_ms: int = -1
@export var has_agroforestry: bool = false
## Fencing + guard posts / CCTV. Sharply cuts the odds of Sandalwood theft.
@export var has_security: bool = false
@export var has_aquaculture: bool = false
@export var has_vertical_farm: bool = false
## -1 = never paid. New Saffron cycles can only be started while now < this.
@export var electricity_expires_at_epoch_ms: int = -1
## Index into GameData's Farmhouse level table. The central progression hub.
@export var farmhouse_level: int = 0
@export var has_mandi: bool = false
## Digital auction terminal -- unlocks tomorrow's demand forecast.
@export var has_mandi_terminal: bool = false
## CropType.Kind ordinal (int) -> MandiGlut.
@export var mandi_glut: Dictionary = {}
## LiveOps: Festival Event Pass. Which recurring festival "occurrence" these
## fields belong to -- see GameEconomy.with_fresh_event_occurrence() for how
## a new occurrence resets them. -1 = never initialized.
@export var event_occurrence_index: int = -1
@export var event_points: int = 0
@export var event_has_premium_pass: bool = false
## Highest reward tier (0..GameData's festival tier count) already granted
## this occurrence.
@export var event_claimed_tier: int = 0
## LiveOps: Chanda Visit (design/gdd/festival-visiting-npcs.md) -- an
## independent companion system to the Festival Event Pass above, not part
## of it. Which cycle index's visit was last given-to or declined, so the
## same occurrence can't be resolved twice. -1 = never resolved.
@export var chanda_last_resolved_cycle_index: int = -1
## Epoch ms until the give-chanda sell-price blessing is active. 0 = no
## active blessing.
@export var chanda_blessing_active_until: int = 0
## Gems &amp; Daily Tasks (design/gdd/gems-daily-tasks.md) -- the project's
## first real-calendar-day-anchored system. Gems persist indefinitely
## (never reset daily); only the fields below reset on a local day
## rollover, via GameEconomy._with_fresh_daily_tasks().
@export var gems: int = 0
## year*10000 + month*100 + day (local time) of the day these fields were
## last generated for. -1 = never initialized.
@export var daily_task_day_key: int = -1
## Today's DailyTaskKind.Kind ordinals (DAILY_TASKS_PER_DAY of them).
@export var daily_task_kinds: Array[int] = []
## DailyTaskKind.Kind ordinal (int) -> progress count so far today.
@export var daily_task_progress: Dictionary = {}
## DailyTaskKind.Kind ordinal (int) -> bool, whether that task's gem
## reward has already been awarded today (guards against double-award on
## a repeated over-target action).
@export var daily_task_claimed: Dictionary = {}
## Whether today's all-3-complete bonus has already been awarded.
@export var daily_task_bonus_claimed: bool = false
## Custom drag-to-reposition positions for the village board's structure
## zones, keyed by zone id (see village_board scripts' zone-id constants).
## Missing entries fall back to that zone's default anchor. String zone id ->
## ZoneAnchor.
@export var zone_layout: Dictionary = {}
## Purely cosmetic placed items.
@export var decorations: Array[Decoration] = []
## Simple auto-incrementing id source for new decorations, mirrors how plot
## ids already work.
@export var next_decoration_id: int = 0
## EPIC-M7: PlotKind.Kind ordinal (int) -> WorkerAssignment. A plot kind
## with no entry has no assigned worker -- its villager (if any) stays in
## EPIC-M6's ambient-roaming population instead. See
## design/gdd/worker-economy.md and game_economy.gd's assign_worker().
@export var worker_assignments: Dictionary = {}


func _init() -> void:
	for i in range(GameData.STARTING_PLOTS):
		plots.append(Plot.new(i))
