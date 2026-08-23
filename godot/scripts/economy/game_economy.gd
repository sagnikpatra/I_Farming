## The ported farm economy logic. Port of GameViewModel.kt, minus everything
## Android/ViewModel-specific (StateFlow, viewModelScope, the 1Hz coroutine
## loop). Deliberately `RefCounted`, not a Node/autoload -- see EPIC-M2's
## architecture proposal: this keeps the economy trivially unit-testable
## (`GameEconomy.new()`, no scene tree needed) and defers any autoload
## decision to EPIC-M4 (UI port), when multiple screens might actually need
## shared global access.
##
## DELIBERATE DEVIATION FROM THE KOTLIN SOURCE: every method that needs the
## current time takes `now: int` (epoch ms) as an explicit parameter instead
## of calling `System.currentTimeMillis()` internally. This makes every
## formula here testable with fixed timestamps -- the Kotlin original always
## read the wall clock inline, which made deterministic unit testing of
## time-dependent formulas impossible without extra seams. Callers (the dev
## console, and eventually real UI orchestration) supply `now` once per
## tick/frame via `Time.get_unix_time_from_system() * 1000`.
##
## BUGFIX (a) -- persist-every-second-regardless: see `dirty` below and
## resolve_growth_completions()'s `any_mutation` tracking. The Kotlin
## original called persist() unconditionally inside resolveGrowthCompletions,
## which the 1Hz coroutine loop invoked every second forever regardless of
## whether anything actually changed. Here, every mutating method sets
## `dirty = true`; resolve_growth_completions() only does so when a plot
## actually transitioned. Whatever drives the periodic tick (dev_console.gd's
## Timer, and later real UI) is responsible for checking `dirty` before
## calling SaveSystem.save_state() and clearing it afterward -- see
## save_system.gd and tests/unit/test_persistence_bugfix.gd.
##
## BUGFIX (b) -- single-event overwrite: see `pending_events` below and
## game_event.gd's header comment.
class_name GameEconomy
extends RefCounted

# Preload CropVarietyDef so GDScript can resolve type hints
const _CropVarietyDef = preload("res://scripts/economy/crop_variety_def.gd")

var state: GameState
## FIFO queue of not-yet-consumed notifications. See game_event.gd (bugfix b).
var pending_events: Array[GameEvent] = []
## True if `state` has changed since the last save. See class doc (bugfix a).
var dirty: bool = false

## Unseeded rolls only (weather/pest damage, Monsoon flood) -- reseeded from
## OS entropy once per GameEconomy instance. Kept separate from the seeded
## rolls below (theft, Mandi demand), which each construct their own
## short-lived RandomNumberGenerator per call, so neither source can affect
## the other's internal state.
var _unseeded_rng: RandomNumberGenerator


func _init(initial_state: GameState = null) -> void:
	state = initial_state if initial_state != null else GameState.new()
	_unseeded_rng = RandomNumberGenerator.new()
	_unseeded_rng.randomize()


# --- Event queue --------------------------------------------------------------

func has_events() -> bool:
	return not pending_events.is_empty()


## Removes and returns the oldest pending event, or null if none remain.
func pop_event() -> GameEvent:
	if pending_events.is_empty():
		return null
	return pending_events.pop_front()


## `is_rejection` (default false, additive -- see GameEvent's own class doc
## for the full rationale) marks "the player tried an action and it was
## blocked" (insufficient funds/gems, a daily cap already used, a required
## precondition unmet) as distinct from neutral/positive informational
## events (a purchase/sale succeeded, a festival gift was given, a
## narrative weather/theft outcome). Classified by hand, call site by call
## site, against the real message/context at each one -- not guessed from a
## sample. Drives GameEvent-drain UI (hud.gd's toast queue): a rejection
## plays the `ui_action_rejected` SFX, an informational event doesn't.
func _push_event(message: String, is_rejection: bool = false) -> void:
	pending_events.append(GameEvent.new(message, is_rejection))


func _mark_dirty() -> void:
	dirty = true


func _find_plot(plot_id: int) -> Plot:
	for plot in state.plots:
		if plot.id == plot_id:
			return plot
	return null


func _next_plot_id() -> int:
	var max_id: int = -1
	for plot in state.plots:
		max_id = maxi(max_id, plot.id)
	return max_id + 1


# --- Polyhouse / weather / electricity gates -----------------------------------

## True while the Polyhouse's UV film is bought and not yet expired.
func is_film_active(now: int) -> bool:
	return state.has_polyhouse and state.film_expires_at_epoch_ms != -1 and now < state.film_expires_at_epoch_ms


## Not underscore-prefixed (see was_sandalwood_stolen()'s doc comment for the
## same rationale) so tests/unit/test_crop_economy.gd can cover TR-crop-002's
## per-plot-kind weather-risk table directly.
## Optional `variety` parameter (defaults to 0) applies variety weather-risk
## multiplier to open-field crops only. Managed tiers ignore it.
func effective_weather_risk_percent(plot_kind: PlotKind.Kind, crop: int, now: int, variety: int = 0) -> int:
	match plot_kind:
		PlotKind.Kind.OPEN_FIELD:
			var base_risk := GameData.crop_def(crop).weather_risk_percent
			var variety_def := GameData.crop_variety_def(crop, variety)
			return roundi(float(base_risk) * variety_def.weather_risk_multiplier)
		PlotKind.Kind.POLYHOUSE:
			return 0 if is_film_active(now) else GameData.POLYHOUSE_UNPROTECTED_RISK_PERCENT
		# Sandalwood's risk is theft, handled separately in
		# resolve_growth_completions() -- no weather roll here.
		PlotKind.Kind.AGROFORESTRY:
			return 0
		# Managed ponds and indoor vertical racks are shielded from open-field
		# weather entirely.
		PlotKind.Kind.AQUACULTURE, PlotKind.Kind.VERTICAL_FARM:
			return 0
		_:
			return 0


## True while the Saffron vertical farm's electricity credit is paid up.
func is_electricity_active(now: int) -> bool:
	return state.has_vertical_farm and state.electricity_expires_at_epoch_ms != -1 and now < state.electricity_expires_at_epoch_ms


# --- LiveOps: Monsoon Season ----------------------------------------------------

## A recurring window computed purely from device time -- no live backend
## required.
func is_monsoon_active(now: int) -> bool:
	return posmod(now, GameData.MONSOON_CYCLE_MS) < GameData.MONSOON_ACTIVE_DURATION_MS


## Ms remaining in the current phase (active-until, or until the next Monsoon
## begins).
func monsoon_phase_remaining_ms(now: int) -> int:
	var phase := posmod(now, GameData.MONSOON_CYCLE_MS)
	if phase < GameData.MONSOON_ACTIVE_DURATION_MS:
		return GameData.MONSOON_ACTIVE_DURATION_MS - phase
	return GameData.MONSOON_CYCLE_MS - phase


# --- LiveOps: Festival Event Pass ------------------------------------------------

func is_festival_active(now: int) -> bool:
	return posmod(now, GameData.FESTIVAL_CYCLE_MS) < GameData.FESTIVAL_ACTIVE_DURATION_MS


func current_festival(now: int) -> FestivalDef:
	return GameData.festival_def(now / GameData.FESTIVAL_CYCLE_MS)


func festival_phase_remaining_ms(now: int) -> int:
	var phase := posmod(now, GameData.FESTIVAL_CYCLE_MS)
	if phase < GameData.FESTIVAL_ACTIVE_DURATION_MS:
		return GameData.FESTIVAL_ACTIVE_DURATION_MS - phase
	return GameData.FESTIVAL_CYCLE_MS - phase


## Resets the event-pass fields in place if we've rolled into a new festival
## occurrence.
func _with_fresh_event_occurrence(now: int) -> void:
	var cycle_index: int = now / GameData.FESTIVAL_CYCLE_MS
	if state.event_occurrence_index != cycle_index:
		state.event_occurrence_index = cycle_index
		state.event_points = 0
		state.event_has_premium_pass = false
		state.event_claimed_tier = 0


## What the UI should show for the event pass right now -- a deep-copied
## preview, never mutates `state`. Mirrors Kotlin's pure `eventStatePreview`.
func event_state_preview(now: int) -> GameState:
	var preview: GameState = state.duplicate(true)
	var cycle_index: int = now / GameData.FESTIVAL_CYCLE_MS
	if preview.event_occurrence_index != cycle_index:
		preview.event_occurrence_index = cycle_index
		preview.event_points = 0
		preview.event_has_premium_pass = false
		preview.event_claimed_tier = 0
	return preview


func buy_premium_pass(now: int) -> void:
	if not is_festival_active(now):
		_push_event(tr(&"event.premium_pass_no_festival"), true)
		return
	_with_fresh_event_occurrence(now)
	if state.event_has_premium_pass:
		return
	if state.coins < GameData.FESTIVAL_PREMIUM_PASS_COST:
		_push_event(tr(&"event.premium_pass_need_coins") % GameData.FESTIVAL_PREMIUM_PASS_COST, true)
		return
	state.coins -= GameData.FESTIVAL_PREMIUM_PASS_COST
	state.event_has_premium_pass = true
	_push_event(tr(&"event.premium_pass_activated"))
	_mark_dirty()


## Called after any sale completes; awards festival points/rewards if that
## crop is this festival's target.
func _register_festival_sale(crop: int, units_sold: int, now: int) -> void:
	if units_sold <= 0 or not is_festival_active(now):
		return
	var festival := current_festival(now)
	if crop != festival.target_crop:
		return

	_with_fresh_event_occurrence(now)
	var new_points: int = state.event_points + units_sold * GameData.FESTIVAL_POINTS_PER_UNIT_SOLD

	var coins_gained: int = 0
	var new_tier: int = state.event_claimed_tier
	var last_message: String = ""
	for index in range(GameData.FESTIVAL_TIER_THRESHOLDS.size()):
		var threshold: int = GameData.FESTIVAL_TIER_THRESHOLDS[index]
		var tier_number: int = index + 1
		if new_points >= threshold and state.event_claimed_tier < tier_number:
			var free_reward: int = GameData.FESTIVAL_FREE_REWARDS[index]
			coins_gained += free_reward
			var msg: String = tr(&"event.festival_tier_reached") % [festival.emoji, festival.display_name, tier_number, free_reward]
			if state.event_has_premium_pass:
				var premium_reward: int = GameData.FESTIVAL_PREMIUM_BONUS[index]
				coins_gained += premium_reward
				msg += tr(&"event.festival_tier_premium_bonus_suffix") % premium_reward
			last_message = msg
			new_tier = tier_number

	state.event_points = new_points
	state.event_claimed_tier = new_tier
	state.coins += coins_gained
	if last_message != "":
		_push_event(last_message)
	_mark_dirty()


# --- LiveOps: Chanda Visit (design/gdd/festival-visiting-npcs.md) ---------------
# Independent cycle from the Festival Event Pass above -- see that file's §3.

func is_chanda_visit_active(now: int) -> bool:
	return posmod(now, GameData.CHANDA_CYCLE_MS) < GameData.CHANDA_ACTIVE_DURATION_MS


func current_chanda_festival(now: int) -> ChandaFestivalDef:
	return GameData.chanda_festival_def(now / GameData.CHANDA_CYCLE_MS)


func chanda_visit_phase_remaining_ms(now: int) -> int:
	var phase := posmod(now, GameData.CHANDA_CYCLE_MS)
	if phase < GameData.CHANDA_ACTIVE_DURATION_MS:
		return GameData.CHANDA_ACTIVE_DURATION_MS - phase
	return GameData.CHANDA_CYCLE_MS - phase


## Whether the current visit occurrence (if any) still needs a Give/Decline
## decision -- false once resolved, false when no visit is active at all.
func chanda_visit_awaiting_decision(now: int) -> bool:
	if not is_chanda_visit_active(now):
		return false
	var cycle_index: int = now / GameData.CHANDA_CYCLE_MS
	return state.chanda_last_resolved_cycle_index != cycle_index


## The ask amount for the CURRENT farmhouse level -- computed live, never
## cached, per the GDD's Edge Cases §5.
func chanda_ask_amount() -> int:
	return GameData.CHANDA_BASE_ASK + state.farmhouse_level * GameData.CHANDA_ASK_PER_LEVEL


func _chanda_blessing_multiplier(now: int) -> float:
	if now < state.chanda_blessing_active_until:
		return GameData.CHANDA_BLESSING_MULTIPLIER
	return 1.0


## Deducts the ask amount, starts (or resets -- never stacks, per the GDD's
## Edge Cases §5) the blessing timer, and marks this occurrence resolved.
## No-ops (with a message) if no visit is active, it's already resolved, or
## the ask is unaffordable -- mirrors buy_premium_pass()'s own guard shape.
func give_chanda(now: int) -> void:
	if not chanda_visit_awaiting_decision(now):
		return
	var ask: int = chanda_ask_amount()
	if state.coins < ask:
		_push_event(tr(&"event.chanda_need_coins") % ask, true)
		return
	var festival := current_chanda_festival(now)
	state.coins -= ask
	state.chanda_last_resolved_cycle_index = now / GameData.CHANDA_CYCLE_MS
	state.chanda_blessing_active_until = now + GameData.CHANDA_BLESSING_DURATION_MS
	_push_event("%s %s" % [festival.emoji, festival.give_flavor])
	_mark_dirty()


## Declines the current visit -- costs nothing, grants no buff, marks the
## occurrence resolved so the same visit can't be asked twice. Never a
## worse outcome than doing nothing (per the GDD's Player Fantasy §2).
func decline_chanda(now: int) -> void:
	if not chanda_visit_awaiting_decision(now):
		return
	state.chanda_last_resolved_cycle_index = now / GameData.CHANDA_CYCLE_MS
	_push_event(tr(&"event.chanda_decline_flavor"))
	_mark_dirty()


# --- Gems & Daily Tasks (design/gdd/gems-daily-tasks.md) --------------------
# The project's first real-calendar-day-anchored system -- every LiveOps
# system above runs on a fixed wall-clock cycle with no calendar awareness.
# Progress hooks live at the 5 existing action call sites below (plant_seed,
# harvest_plot, sell_crop, sell_all, _resolve_worker_cycle) -- no new
# gameplay verbs, purely a reward wrapper.

## Pure function of (now, timezone_offset) -- deliberately NOT a hidden
## Time.get_time_zone_from_system() read inside this function, so it's
## directly unit-testable with explicit inputs (see this file's own header
## comment on why every time-dependent formula here takes `now` explicitly).
## _current_local_day_key() below is the one real (non-pure) call site that
## supplies the actual system timezone offset.
static func local_day_key(now_ms: int, timezone_offset_minutes: int) -> int:
	var shifted_seconds: int = now_ms / 1000 + timezone_offset_minutes * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(shifted_seconds)
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)


## The one real (non-pure) read in this system -- reads the device's actual
## current timezone offset. Kept to a single tiny wrapper rather than
## threading a timezone parameter through plant_seed()/harvest_plot()/
## sell_crop()/sell_all()/resolve_worker_actions()'s existing public
## signatures (and every test/call site that already calls them), which
## would be a far wider, riskier change for the same result.
func _current_local_day_key(now: int) -> int:
	var tz: Dictionary = Time.get_time_zone_from_system()
	return local_day_key(now, int(tz.get("bias", 0)))


static func _pick_daily_task_kinds(rng: RandomNumberGenerator) -> Array[int]:
	var pool := GameData.daily_task_pool()
	var available: Array[int] = []
	for i in range(pool.size()):
		available.append(i)
	var kinds: Array[int] = []
	for _i in range(GameData.DAILY_TASKS_PER_DAY):
		var pick_index: int = rng.randi_range(0, available.size() - 1)
		kinds.append(pool[available[pick_index]].kind)
		available.remove_at(pick_index)
	return kinds


## Lazy-reset-on-read, same shape as _with_fresh_event_occurrence(): the
## first economy call of a new local day resets the task set/progress/
## reroll-availability in place. Seeded by day_key -- same date always
## produces the same 3 picks (deterministic, no save-scumming).
func _with_fresh_daily_tasks(now: int) -> void:
	var day_key: int = _current_local_day_key(now)
	if state.daily_task_day_key == day_key:
		return
	state.daily_task_day_key = day_key
	var rng := RandomNumberGenerator.new()
	rng.seed = day_key
	state.daily_task_kinds = _pick_daily_task_kinds(rng)
	state.daily_task_progress = {}
	state.daily_task_claimed = {}
	state.daily_task_bonus_claimed = false


## What the UI should show right now -- a deep-copied preview, never
## mutates `state`, same rationale as event_state_preview(): opening the
## Events sheet on a new day shouldn't be what triggers the rollover, only
## a real gameplay action should.
func daily_tasks_state_preview(now: int) -> GameState:
	var preview: GameState = state.duplicate(true)
	var day_key: int = _current_local_day_key(now)
	if preview.daily_task_day_key != day_key:
		preview.daily_task_day_key = day_key
		var rng := RandomNumberGenerator.new()
		rng.seed = day_key
		preview.daily_task_kinds = _pick_daily_task_kinds(rng)
		preview.daily_task_progress = {}
		preview.daily_task_claimed = {}
		preview.daily_task_bonus_claimed = false
	return preview


## Called from the 5 real action hook points below. No-ops for a kind not
## among today's 3 picks, or a task already claimed (avoids double-award
## on a repeated over-target action -- e.g. selling again after "Sell
## crops 3 times" already hit its target).
func _bump_daily_task_progress(kind: DailyTaskKind.Kind, amount: int, now: int) -> void:
	if amount <= 0:
		return
	_with_fresh_daily_tasks(now)
	if not state.daily_task_kinds.has(kind):
		return
	if state.daily_task_claimed.get(kind, false):
		return
	var new_progress: int = int(state.daily_task_progress.get(kind, 0)) + amount
	state.daily_task_progress[kind] = new_progress
	var task_def := GameData.daily_task_def_for_kind(kind)
	if new_progress >= task_def.target:
		state.daily_task_claimed[kind] = true
		state.gems += task_def.gem_reward
		_push_event(tr(&"event.daily_task_complete") % [task_def.emoji, task_def.display_name, task_def.gem_reward])
		_maybe_award_daily_bonus()
	_mark_dirty()


func _maybe_award_daily_bonus() -> void:
	if state.daily_task_bonus_claimed:
		return
	for kind: int in state.daily_task_kinds:
		if not state.daily_task_claimed.get(kind, false):
			return
	state.daily_task_bonus_claimed = true
	state.gems += GameData.DAILY_TASK_ALL_BONUS_GEMS
	_push_event(tr(&"event.daily_tasks_all_complete") % GameData.DAILY_TASK_ALL_BONUS_GEMS)


## Discards today's picks entirely and draws a fresh, genuinely random 3
## (NOT seeded by day_key -- a seeded reroll would just reproduce the same
## picks). Only allowed while zero of today's 3 tasks are complete, so a
## reroll can never discard an already-earned reward -- see this file's
## header-level design doc for why that's a hard rule, not a soft
## preference.
func reroll_daily_tasks(now: int) -> void:
	_with_fresh_daily_tasks(now)
	for kind: int in state.daily_task_kinds:
		if state.daily_task_claimed.get(kind, false):
			_push_event(tr(&"event.reroll_blocked_progress"), true)
			return
	if state.gems < GameData.DAILY_TASK_REROLL_COST:
		_push_event(tr(&"event.reroll_need_gems") % GameData.DAILY_TASK_REROLL_COST, true)
		return
	state.gems -= GameData.DAILY_TASK_REROLL_COST
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	state.daily_task_kinds = _pick_daily_task_kinds(rng)
	state.daily_task_progress = {}
	state.daily_task_claimed = {}
	state.daily_task_bonus_claimed = false
	_push_event(tr(&"event.reroll_success"))
	_mark_dirty()


## feature-scoping-2026-08-22.md item 2's second gems sink: one capped
## grow-time skip per real calendar day. Deliberately does NOT bypass
## resolve_growth_completions()'s own weather/theft/flood risk logic for
## the target plot -- rewinds planted_at_epoch_ms far enough into the
## past that the very next resolve_growth_completions() call (already
## driven by the existing growth tick) treats it as naturally complete
## and runs through that exact same risk logic unchanged. Paying gems
## buys instant time, not reduced risk -- see design/gdd/gems-second-sink.md.
func skip_grow_time(plot_id: int, now: int) -> void:
	var day_key: int = _current_local_day_key(now)
	if state.grow_skip_day_key != day_key:
		state.grow_skip_day_key = day_key
		state.grow_skip_used_today = false
	if state.grow_skip_used_today:
		_push_event(tr(&"event.grow_skip_already_used"), true)
		return
	if state.gems < GameData.GROW_SKIP_COST_GEMS:
		_push_event(tr(&"event.grow_skip_need_gems") % GameData.GROW_SKIP_COST_GEMS, true)
		return
	var plot := _find_plot(plot_id)
	if plot == null or plot.state.kind != PlotState.Kind.GROWING:
		return  # Stale action racing a tick-driven rebuild -- nothing to skip.
	state.gems -= GameData.GROW_SKIP_COST_GEMS
	state.grow_skip_used_today = true
	plot.state.planted_at_epoch_ms = now - plot.state.effective_grow_seconds * 1000 - 1
	_push_event(tr(&"event.grow_skip_success"))
	_mark_dirty()


## Whether skip_grow_time() would currently succeed for a GROWING plot --
## the UI's own read-only check for enabling/disabling the button, never
## mutates state. Deliberately duplicates skip_grow_time()'s day-key
## comparison read-only (never writes grow_skip_day_key/grow_skip_used_today)
## rather than calling a shared mutating helper, so a UI repaint can never
## itself consume the daily cap.
func can_skip_grow_time(now: int) -> bool:
	if state.gems < GameData.GROW_SKIP_COST_GEMS:
		return false
	var day_key: int = _current_local_day_key(now)
	if state.grow_skip_day_key == day_key and state.grow_skip_used_today:
		return false
	return true


# --- The Ancestral Farmhouse: core progression hub ------------------------------

func storage_capacity() -> int:
	return GameData.farmhouse_level_def(state.farmhouse_level).storage_capacity


func total_inventory_units() -> int:
	var total: int = 0
	for stock: CropStock in state.inventory.values():
		total += stock.total
	return total


## Farm-wide grow-time multiplier from the Farmhouse level (e.g. 0.85 = 15%
## faster).
func _growth_speed_multiplier() -> float:
	return 1.0 - GameData.farmhouse_level_def(state.farmhouse_level).growth_speed_bonus_percent / 100.0


## Farm-wide sell-price multiplier from the Farmhouse level (e.g. 1.10 = 10%
## more), composed with the Chanda Visit blessing (see
## _chanda_blessing_multiplier()) when one is active.
func _sell_price_multiplier(now: int) -> float:
	var farmhouse: float = 1.0 + GameData.farmhouse_level_def(state.farmhouse_level).sell_price_bonus_percent / 100.0
	return farmhouse * _chanda_blessing_multiplier(now)


## Returns the current farmhouse level definition.
func get_farmhouse_level_def() -> FarmhouseLevelDef:
	return GameData.farmhouse_level_def(state.farmhouse_level)


## Returns the processing speed multiplier for the current farmhouse level.
## Used by crop processing systems to scale processing duration.
func get_processing_speed_multiplier() -> float:
	var bonus_percent: float = GameData.farmhouse_level_def(state.farmhouse_level).growth_speed_bonus_percent
	return 1.0 - bonus_percent / 100.0


## Returns total storage capacity at the current farmhouse level.
## Each level's storage_capacity is already the absolute total for that tier
## (see the _ensure_farmhouse_levels() catalogue comments), not a per-level
## delta -- summing across levels would overstate capacity. Same value as
## the pre-existing storage_capacity(); kept as a separate name for
## discoverability from the new farmhouse-progression call sites.
func get_total_storage_capacity() -> int:
	return storage_capacity()


## Attempts to upgrade the farmhouse to the next level.
## Returns true if upgrade succeeded, false otherwise.
func upgrade_farmhouse(now: int) -> bool:
	if state.farmhouse_level >= GameData.farmhouse_max_level():
		return false
	var next_level := GameData.farmhouse_level_def(state.farmhouse_level + 1)
	if state.coins < next_level.upgrade_cost:
		_push_event(tr(&"event.farmhouse_need_coins") % [next_level.upgrade_cost, next_level.display_name], true)
		return false
	state.coins -= next_level.upgrade_cost
	state.farmhouse_level += 1
	_push_event(tr(&"event.farmhouse_upgraded") % [next_level.emoji, next_level.display_name])
	_mark_dirty()
	return true


## Resolves passive income accrual based on time elapsed since last resolution.
## Caps offline accrual at 12 hours maximum. Returns the coins added.
func resolve_passive_income(now: int) -> int:
	var passive_income_rate: int = GameData.farmhouse_level_def(state.farmhouse_level).passive_income_per_hour
	if passive_income_rate <= 0:
		return 0

	# Initialize on first call
	if state.passive_income_last_resolution_epoch_ms == -1:
		state.passive_income_last_resolution_epoch_ms = now
		return 0

	var elapsed_ms: int = now - state.passive_income_last_resolution_epoch_ms
	if elapsed_ms < 0:
		return 0

	var elapsed_hours: float = float(elapsed_ms) / 3_600_000.0
	# Soft cap at 12 hours for offline play to prevent extreme catches-up
	elapsed_hours = minf(elapsed_hours, 12.0)

	var coins_earned: int = roundi(passive_income_rate * elapsed_hours)
	state.pending_passive_income += coins_earned
	state.passive_income_last_resolution_epoch_ms = now
	_mark_dirty()
	return coins_earned


## Collects all pending passive income into the coin pool.
## Returns the amount collected.
func collect_pending_passive_income() -> int:
	var amount: int = state.pending_passive_income
	if amount > 0:
		state.coins += amount
		state.pending_passive_income = 0
		_push_event(tr(&"event.passive_income_collected") % amount)
		_mark_dirty()
	return amount


func buy_farmhouse_upgrade() -> void:
	upgrade_farmhouse(Time.get_unix_time_from_system() as int * 1000)


# --- Seasonal Crop Availability ------------------------------------------------

## Checks if a crop can be planted right now based on the current season.
## Year-round crops are always plantable.
## Seasonal crops can only be planted during their designated seasons.
func can_plant_crop(crop_kind: int, now: int) -> bool:
	var current_season: int = SeasonType.current_season(now)
	return GameData.is_crop_available_this_season(crop_kind, current_season)


# --- Crop lifecycle: plant / harvest / sell --------------------------------------

func plant_seed(plot_id: int, crop: int, now: int, variety: int = 0) -> void:
	# Sandalwood has its own entry point (adjacency + host-dependent duration).
	if crop == CropType.Kind.SANDALWOOD:
		return
	var plot := _find_plot(plot_id)
	if plot == null:
		return
	if plot.state.kind != PlotState.Kind.EMPTY:
		return
	var crop_def := GameData.crop_def(crop)
	if crop_def.required_plot_kind != plot.kind:
		return

	# Check if crop is available this season
	if not can_plant_crop(crop, now):
		var current_season: int = SeasonType.current_season(now)
		var season_name: String = SeasonType.season_name(current_season)
		_push_event(tr(&"event.plant_off_season") % [crop_def.display_name, season_name], true)
		return

	if crop == CropType.Kind.SAFFRON and not is_electricity_active(now):
		_push_event(tr(&"event.plant_needs_electricity"), true)
		return

	# Apply variety modifiers to seed cost
	var variety_def := GameData.crop_variety_def(crop, variety)
	var adjusted_seed_cost := roundi(float(crop_def.seed_cost) * variety_def.seed_cost_multiplier)

	if state.coins < adjusted_seed_cost:
		_push_event(tr(&"event.plant_not_enough_coins") % crop_def.display_name, true)
		return

	var speed_boosted: bool = (
		crop_def.required_plot_kind == PlotKind.Kind.POLYHOUSE
		and state.has_fan_pad
		and is_film_active(now)
	)
	var after_fan_pad: float = float(crop_def.grow_seconds) / 2.0 if speed_boosted else float(crop_def.grow_seconds)
	var monsoon_multiplier: float = 1.0
	if crop_def.required_plot_kind == PlotKind.Kind.OPEN_FIELD and is_monsoon_active(now):
		monsoon_multiplier = GameData.MONSOON_SPEED_MULTIPLIER

	# Apply variety grow-time modifier
	var variety_grow_multiplier: float = variety_def.grow_time_multiplier
	var effective_seconds: int = maxi(roundi(after_fan_pad * variety_grow_multiplier * _growth_speed_multiplier() * monsoon_multiplier), 1)

	state.coins -= adjusted_seed_cost
	plot.state = PlotState.new_growing(crop, now, effective_seconds)
	plot.selected_variety = variety  # Store the selected variety for later reference (harvest, display)
	_bump_daily_task_progress(DailyTaskKind.Kind.PLANT, 1, now)
	_mark_dirty()


## Returns true if the harvested unit landed in the `damaged` bucket (weather/
## pest damage, or Polyhouse spoilage past the grace window) -- false both
## when it landed `normal` AND when no harvest happened at all (invalid plot,
## not ready, storage full). Existing callers (board_interactor.gd's manual
## tap, every pre-EPIC-M7 test) predate this return value and simply discard
## it, same as any other newly-non-void method; only _resolve_worker_cycle()
## below actually reads it, to correct WORKER_WAGE_RATE's tax base -- see
## that call site's own comment for why.
func harvest_plot(plot_id: int, now: int) -> bool:
	var plot := _find_plot(plot_id)
	if plot == null:
		return false
	if plot.state.kind != PlotState.Kind.READY_TO_HARVEST:
		return false
	var ready := plot.state

	var capacity := storage_capacity()
	var current_total := total_inventory_units()
	if current_total >= capacity:
		_push_event(tr(&"event.storage_full") % [current_total, capacity])
		return false

	var spoiled: bool = false
	if plot.kind == PlotKind.Kind.POLYHOUSE:
		var grace: int = GameData.SPOILAGE_GRACE_MS_WITH_DRIP if state.has_drip_irrigation else GameData.SPOILAGE_GRACE_MS_BASE
		spoiled = (now - ready.ready_at_epoch_ms) > grace
	var damaged: bool = ready.weather_damaged or spoiled

	var existing_stock: CropStock = state.inventory.get(ready.crop, null)
	if existing_stock == null:
		existing_stock = CropStock.new()
	if damaged:
		existing_stock.damaged += 1
	else:
		existing_stock.normal += 1
	state.inventory[ready.crop] = existing_stock

	plot.state = PlotState.new_empty()
	state.total_harvests += 1
	_bump_daily_task_progress(DailyTaskKind.Kind.HARVEST, 1, now)

	if spoiled and not ready.weather_damaged:
		_push_event(tr(&"event.harvest_spoiled") % GameData.crop_def(ready.crop).display_name)

	_mark_dirty()
	return damaged


func sell_crop(crop: int, now: int) -> void:
	var stock: CropStock = state.inventory.get(crop, null)
	if stock == null or stock.total == 0:
		return

	var sell_multiplier := _sell_price_multiplier(now)
	var crop_def := GameData.crop_def(crop)
	var normal_value: int = roundi(stock.normal * crop_def.base_sell_price * sell_multiplier)
	var damaged_value: int = roundi(stock.damaged * crop_def.base_sell_price * GameData.WEATHER_DAMAGE_YIELD_MULTIPLIER * sell_multiplier)
	var total_value: int = normal_value + damaged_value
	var units_sold: int = stock.total

	state.coins += total_value
	state.inventory.erase(crop)
	_push_event(tr(&"event.sold_crop") % [units_sold, crop_def.display_name, total_value])
	_register_festival_sale(crop, units_sold, now)
	_bump_daily_task_progress(DailyTaskKind.Kind.SELL, 1, now)
	_bump_daily_task_progress(DailyTaskKind.Kind.EARN, total_value, now)
	_mark_dirty()


func sell_all(now: int) -> void:
	if state.inventory.is_empty():
		return
	var sell_multiplier := _sell_price_multiplier(now)
	var total_value: int = 0
	var sold_stock: Dictionary = {}
	for crop: int in state.inventory.keys():
		var stock: CropStock = state.inventory[crop]
		var crop_def := GameData.crop_def(crop)
		total_value += roundi(stock.normal * crop_def.base_sell_price * sell_multiplier)
		total_value += roundi(stock.damaged * crop_def.base_sell_price * GameData.WEATHER_DAMAGE_YIELD_MULTIPLIER * sell_multiplier)
		sold_stock[crop] = stock

	state.coins += total_value
	state.inventory.clear()
	_push_event(tr(&"event.sold_everything") % total_value)
	for crop: int in sold_stock.keys():
		var stock: CropStock = sold_stock[crop]
		_register_festival_sale(crop, stock.total, now)
	_bump_daily_task_progress(DailyTaskKind.Kind.SELL, 1, now)
	_bump_daily_task_progress(DailyTaskKind.Kind.EARN, total_value, now)
	_mark_dirty()


# --- Growth resolution (lazy, read-time) -----------------------------------------

## Walks every Growing plot and resolves it once its effective grow time has
## elapsed. Called before every state read in the original Kotlin (and by
## dev_console.gd's 1Hz tick here) -- this is what makes offline growth "just
## work" without a live ticking timer.
func resolve_growth_completions(now: int) -> void:
	var any_weather: bool = false
	var any_theft: bool = false
	var any_flood: bool = false
	var any_mutation: bool = false

	for plot: Plot in state.plots:
		if plot.state.kind != PlotState.Kind.GROWING:
			continue
		var growing := plot.state

		if growing.crop == CropType.Kind.SANDALWOOD:
			var elapsed_hours: int = int((now - growing.planted_at_epoch_ms) / 3_600_000)
			if elapsed_hours > 0 and was_sandalwood_stolen(plot.id, elapsed_hours, state.has_security):
				if not any_theft:
					_push_event(tr(&"event.sandalwood_stolen"))
					any_theft = true
				plot.state = PlotState.new_empty()
				any_mutation = true
				continue

		var elapsed_ms: int = now - growing.planted_at_epoch_ms
		if elapsed_ms < growing.effective_grow_seconds * 1000:
			continue

		# Monsoon Season: open-field crops risk total loss to flooding instead
		# of the usual weather-damage roll, unless the player has invested in
		# a Polyhouse.
		if plot.kind == PlotKind.Kind.OPEN_FIELD and is_monsoon_active(now) and not state.has_polyhouse:
			var flooded: bool = (_unseeded_rng.randi() % 100) < GameData.MONSOON_FLOOD_CHANCE_PERCENT
			if flooded:
				if not any_flood:
					var crop_name: String = GameData.crop_def(growing.crop).display_name
					_push_event(tr(&"event.monsoon_flood_wiped") % crop_name)
					any_flood = true
				plot.state = PlotState.new_empty()
				any_mutation = true
				continue
			plot.state = PlotState.new_ready(growing.crop, false, now)
			any_mutation = true
			continue

		var risk: int = effective_weather_risk_percent(plot.kind, growing.crop, now)
		var damaged: bool = (_unseeded_rng.randi() % 100) < risk
		if damaged and not any_weather:
			var crop_name: String = GameData.crop_def(growing.crop).display_name
			_push_event(tr(&"event.weather_clipped") % crop_name)
			any_weather = true
		plot.state = PlotState.new_ready(growing.crop, damaged, now)
		any_mutation = true

	# Bugfix (a): only mark dirty (and thus become eligible for the next
	# autosave) if a plot actually transitioned this call -- see class doc.
	if any_mutation:
		_mark_dirty()

	# Thief NPC Visitor system: check for a thief visit every THIEF_VISIT_INTERVAL_HOURS
	# (design/gdd/thief-system.md). Runs once per resolve_growth_completions() call,
	# independent of individual plot state -- not part of the per-plot loop above.
	resolve_thief_visit(now)

	# Farmhouse passive income (design/gdd/farmhouse-progression.md): same
	# lazy, read-time resolution pattern as everything else in this
	# function -- accrues into pending_passive_income, which
	# collect_pending_passive_income() (farmhouse_tab.gd's Collect button)
	# sweeps into state.coins. Previously defined but never called from
	# anywhere -- see production/session-state/active.md's 2026-08-23 entry.
	resolve_passive_income(now)


# --- EPIC-M7: Worker assignment & automation --------------------------------
#
# design/gdd/worker-economy.md, confirmed 2026-08-21. A worker automates one
# plot kind's harvest-and-replant cycle in exchange for a wage, resolved
# lazily (same pattern as resolve_growth_completions() above, called right
# after it -- see village_board.gd's _on_growth_tick_timeout()) so offline
# automation "just works" without a background service, exactly like
# ordinary crop growth already does.
#
# Keyed by PlotKind.Kind, not the village-board layer's zone-id strings:
# GameEconomy is Foundation-layer and must not depend on village_board
# scripts (Presentation layer) -- PlotKind is already this layer's own
# "which zone" vocabulary (see _plots_of_kind()-style groupings elsewhere in
# this file), so no new cross-layer dependency is introduced. Translating
# between a board zone-id and a PlotKind, if ever needed, is the caller's
# job (e.g. future UI code), not this file's.
#
# AGROFORESTRY is deliberately excluded from worker eligibility: Sandalwood
# planting goes through plant_host()/plant_sandalwood()'s adjacency-puzzle
# entry point, not plant_seed() -- there is no "replant the same crop"
# concept to automate there. Not a gap; a scope boundary, not currently
# revisited by the GDD.

const _WORKER_ELIGIBLE_PLOT_KINDS: Array[PlotKind.Kind] = [
	PlotKind.Kind.OPEN_FIELD,
	PlotKind.Kind.POLYHOUSE,
	PlotKind.Kind.AQUACULTURE,
	PlotKind.Kind.VERTICAL_FARM,
]

## design/gdd/worker-economy.md §4: 15% of the harvested crop's base sell
## value, min ₹1. Explicitly flagged in the GDD as proposed/unbalanced --
## needs a /balance-check pass with real data before treating as final,
## same as land-and-structures.md's own formulas shipped unverified.
const WORKER_WAGE_RATE: float = 0.15


func is_plot_kind_worker_eligible(plot_kind: PlotKind.Kind) -> bool:
	return _WORKER_ELIGIBLE_PLOT_KINDS.has(plot_kind)


## Assigns character_key as plot_kind's worker, replacing any existing
## assignment for that plot kind. Silently no-ops for a non-eligible plot
## kind (AGROFORESTRY, or any future addition) or for a zone the player
## hasn't unlocked yet -- matches this file's existing style of
## silent-no-op on an invalid action (see plant_seed()'s guard clauses
## above) so callers don't need to pre-validate before calling. Found and
## fixed while writing this feature's own tests, not a design question --
## assigning a worker to a zone that doesn't exist yet is an obvious bug,
## not an open edge case.
func assign_worker(plot_kind: PlotKind.Kind, character_key: String) -> void:
	if not is_plot_kind_worker_eligible(plot_kind):
		return
	if not _is_plot_kind_unlocked(plot_kind):
		return
	state.worker_assignments[plot_kind] = WorkerAssignment.new(plot_kind, character_key)
	_mark_dirty()


## OPEN_FIELD has no unlock flag -- it's available from the start of the
## game. The other 3 worker-eligible plot kinds each gate behind their own
## structure's has_* flag (land-and-structures.md §2.3).
func _is_plot_kind_unlocked(plot_kind: PlotKind.Kind) -> bool:
	match plot_kind:
		PlotKind.Kind.OPEN_FIELD:
			return true
		PlotKind.Kind.POLYHOUSE:
			return state.has_polyhouse
		PlotKind.Kind.AQUACULTURE:
			return state.has_aquaculture
		PlotKind.Kind.VERTICAL_FARM:
			return state.has_vertical_farm
		_:
			return false


## Returns the assigned villager to EPIC-M6's ambient-roaming population
## (per design/gdd/villagers.md §3.6, confirmed 2026-08-21) -- the actual
## roaming hand-off is village_board.gd/VillagerSpawner's job, not this
## economy-layer method's; this only clears the persisted assignment.
func unassign_worker(plot_kind: PlotKind.Kind) -> void:
	if not state.worker_assignments.has(plot_kind):
		return
	state.worker_assignments.erase(plot_kind)
	_mark_dirty()


func has_worker_assigned(plot_kind: PlotKind.Kind) -> bool:
	return state.worker_assignments.has(plot_kind)


func get_worker_assignment(plot_kind: PlotKind.Kind) -> WorkerAssignment:
	return state.worker_assignments.get(plot_kind, null)


## Lazy, read-time resolution -- same rationale as resolve_growth_completions()
## above. For every assigned worker, walks that plot kind's ReadyToHarvest
## plots and runs one harvest-and-replant cycle per plot. Must be called
## after resolve_growth_completions() in the same tick so a plot that just
## finished growing is already eligible, not delayed a full extra cycle.
func resolve_worker_actions(now: int) -> void:
	for plot_kind: int in state.worker_assignments.keys():
		for plot: Plot in state.plots:
			if plot.kind != plot_kind:
				continue
			if plot.state.kind != PlotState.Kind.READY_TO_HARVEST:
				continue
			_resolve_worker_cycle(plot, now)


## One worker harvest-and-replant cycle for a single ReadyToHarvest plot,
## implementing design/gdd/worker-economy.md §5's confirmed edge-case rules:
## - Inventory full: skip entirely, no wage charged, retry next resolution
##   (mirrors harvest_plot()'s own manual-tap behavior in that case).
## - Can't afford the replant (or, for Saffron, Electricity has lapsed --
##   plant_seed() already gates that exact case): still harvest (wage
##   charged for that), leave the plot Empty rather than replanting.
## Coins are clamped at 0 -- the GDD never discusses a worker driving the
## player negative, and letting a wage do so would be a surprising,
## undiscussed mechanic; not letting it happen is the conservative default.
func _resolve_worker_cycle(plot: Plot, now: int) -> void:
	if total_inventory_units() >= storage_capacity():
		return  # skip this cycle entirely, no wage -- inventory full

	var crop: int = plot.state.crop
	var crop_def := GameData.crop_def(crop)

	# Balance fix (2026-08-21 /balance-check pass, design/gdd/worker-economy.md
	# §4/§7): must be computed from THIS specific harvest's actual outcome,
	# not assumed undamaged -- harvest_plot() itself is what resolves whether
	# an Open-Field weather/pest roll or a Polyhouse spoilage grace-window
	# miss hits this cycle (both apply to worker-eligible zones), so the wage
	# can only be known correctly after that call returns, not before it.
	var damaged: bool = harvest_plot(plot.id, now)  # plot.state.crop read above; plot is now Empty
	var wage: int = _worker_wage_for(crop_def, damaged)

	state.coins = maxi(state.coins - wage, 0)
	_push_event(tr(&"event.worker_harvested") % [crop_def.emoji, crop_def.display_name, wage])
	_bump_daily_task_progress(DailyTaskKind.Kind.WORKER, 1, now)

	var can_afford_replant: bool = state.coins >= crop_def.seed_cost
	var electricity_ok: bool = crop != CropType.Kind.SAFFRON or is_electricity_active(now)
	if can_afford_replant and electricity_ok:
		plant_seed(plot.id, crop, now)

	_mark_dirty()


## Balance fix (2026-08-21 /balance-check pass): a damaged harvest sells for
## only base_sell_price * GameData.WEATHER_DAMAGE_YIELD_MULTIPLIER (see
## sell_crop()'s identical damaged-value math) -- charging the undamaged rate
## here meant a worker's effective cut on a damaged Open-Field cycle was
## ~30% of what the player actually realized, double the intended
## WORKER_WAGE_RATE, and a direct contradiction of design/gdd/worker-
## economy.md §5's own stated principle ("a worker only ever charges a wage
## for value it actually delivered"). Scaling the tax base the same way the
## sale value itself is scaled restores that principle exactly.
func _worker_wage_for(crop_def: CropDef, damaged: bool = false) -> int:
	var yield_multiplier: float = GameData.WEATHER_DAMAGE_YIELD_MULTIPLIER if damaged else 1.0
	return maxi(roundi(crop_def.base_sell_price * yield_multiplier * WORKER_WAGE_RATE), 1)


## Deterministic, replayable theft check: same plot+hour always resolves the
## same way, so re-evaluating after an offline gap (or after buying Security
## late) is consistent and needs no extra persisted state beyond
## planted_at_epoch_ms. Each hour constructs its own fresh seeded RNG (mirrors
## the Kotlin original's `Random(seed)` per iteration) rather than reusing
## shared RNG state.
##
## Not underscore-prefixed (unlike this file's other internal helpers)
## specifically so tests/unit/test_randomness.gd can exercise the seeded-roll
## formula directly, per ADR-0002's requirement to cover the deliberately-
## seeded systems with reproducibility tests. Not intended to be called from
## outside the growth-resolution pipeline during normal gameplay.
func was_sandalwood_stolen(plot_id: int, elapsed_hours: int, secured: bool) -> bool:
	var hourly_probability: float = (
		GameData.THEFT_HOURLY_PROBABILITY_PROTECTED if secured else GameData.THEFT_HOURLY_PROBABILITY_UNPROTECTED
	)
	for hour in range(1, elapsed_hours + 1):
		var seed: int = plot_id * 1_000_003 + hour * 7_919
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		if rng.randf() < hourly_probability:
			return true
	return false


## Deterministic thief visit check: same session always resolves the same way.
## Theft probability scales with player wealth and is reduced by security level.
## Each hour constructs its own seeded RNG for reproducibility across save/load.
func was_thief_visiting(session_id: int, elapsed_hours: int, player_wealth: int, security_level: int) -> bool:
	# Base probability increases with wealth (wealthy farms attract thieves)
	var wealth_bonus: float = float(player_wealth) * GameData.THIEF_PROBABILITY_MULTIPLIER_PER_WEALTH
	var base_probability: float = GameData.THIEF_PROBABILITY_BASE + wealth_bonus

	# Security reduces probability: level 1 = 50%, level 2 = 20%
	var security_multiplier: float = 1.0
	match security_level:
		1:
			security_multiplier = 0.5
		2:
			security_multiplier = 0.2

	var hourly_probability: float = base_probability * security_multiplier

	for hour in range(1, elapsed_hours + 1):
		var seed: int = session_id * 1_000_007 + hour * 11_113
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		if rng.randf() < hourly_probability:
			return true
	return false


## Calculate steal amount for a thief visit (seeded, deterministic).
func calculate_thief_steal_amount(session_id: int, hour_seed: int) -> int:
	var seed: int = session_id * 1_000_009 + hour_seed * 13_121
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Bugfix: was calling the global randf_range() (Godot's shared, OS-entropy-
	# seeded RNG) instead of rng.randf_range() -- the locally seeded `rng` above
	# was created and seeded but never actually used, so this was never
	# deterministic despite the seeding. Caught by
	# test_steal_amount_deterministic_per_session_and_hour actually running.
	var amount: float = rng.randf_range(float(GameData.THIEF_STEAL_AMOUNT_MIN), float(GameData.THIEF_STEAL_AMOUNT_MAX))
	return roundi(amount)


## Whether a thief visit is currently pending a player decision (let go /
## bribe / chase). Drives ThiefVisitor's board spawn/despawn in
## village_board.gd's _sync_thief_visitor_if_needed(), the same
## boolean-edge pattern chanda_visit_awaiting_decision() established.
func thief_visit_awaiting_decision() -> bool:
	return state.thief_pending_steal_amount > 0


## Thief NPC Visitor system: checks if a thief visit should trigger, and
## if so marks it pending (state.thief_pending_steal_amount) for the player
## to resolve via ThiefInteractionSheet/resolve_thief_decision(). Called
## once per resolve_growth_completions() tick.
## Uses session_id (hash of save slot) and elapsed hours since last thief
## visit to determine if a thief should appear (deterministic per session).
func resolve_thief_visit(now: int) -> void:
	# A visit is already pending a decision -- don't roll another on top of
	# it (nothing to gain from two simultaneous pending steals, and it would
	# silently overwrite the amount the player is currently looking at).
	if thief_visit_awaiting_decision():
		return

	# Thief visits are gated by a 12-hour cooldown (THIEF_VISIT_INTERVAL_HOURS)
	if state.thief_last_visit_epoch_ms != -1:
		var ms_since_last_visit: int = now - state.thief_last_visit_epoch_ms
		if ms_since_last_visit < GameData.THIEF_VISIT_INTERVAL_HOURS * 3_600_000:
			return  # Still within cooldown window

	# Use a simple session_id derived from state for deterministic rolls
	# (same save slot always produces same thief outcome)
	var session_id: int = state.farmhouse_level * 1_000_013 + state.total_harvests * 7_919

	# Elapsed hours since the last thief visit (or since start if never visited)
	var last_check_ms: int = state.thief_last_visit_epoch_ms if state.thief_last_visit_epoch_ms != -1 else 0
	var elapsed_hours: int = int((now - last_check_ms) / 3_600_000)
	if elapsed_hours == 0:
		elapsed_hours = 1  # At minimum, check the current hour

	# Check if thief visits during this window
	if not was_thief_visiting(session_id, elapsed_hours, state.coins, state.thief_security_level):
		return

	# Thief is visiting! Calculate the steal amount and mark it pending --
	# the board NPC (spawned by village_board.gd off this flag) and
	# ThiefInteractionSheet are the real resolution path; the toast below
	# is a secondary ambient notice, not the only way to find out.
	var steal_amount := calculate_thief_steal_amount(session_id, elapsed_hours)
	state.thief_pending_steal_amount = steal_amount
	state.thief_last_visit_epoch_ms = now
	_push_event(tr(&"thief.appeared") % steal_amount)
	_mark_dirty()


## Applies the player's resolved choice from ThiefInteractionSheet.
## `coins_lost` is pre-computed by the sheet itself (let-go/bribe/chase
## formulas -- see design/gdd/thief-system.md's Formulas section); this
## function's job is only to apply that result to state, not recompute it,
## so the loss formulas stay defined in exactly one place. No-ops if no
## visit is currently pending (e.g. a stale/double-fired UI signal).
func resolve_thief_decision(coins_lost: int) -> void:
	if not thief_visit_awaiting_decision():
		return
	var actual_loss: int = mini(coins_lost, state.coins)
	state.coins -= actual_loss
	state.total_theft_losses += actual_loss
	state.thief_pending_steal_amount = 0
	_mark_dirty()


# --- Land & Tier 2: Polyhouse ----------------------------------------------------

func buy_land_expansion() -> void:
	var open_field_count: int = 0
	for plot: Plot in state.plots:
		if plot.kind == PlotKind.Kind.OPEN_FIELD:
			open_field_count += 1
	if open_field_count >= GameData.MAX_PLOTS:
		_push_event(tr(&"event.land_max_size"), true)
		return
	var cost := GameData.land_expansion_cost(open_field_count)
	if state.coins < cost:
		_push_event(tr(&"event.land_need_coins") % cost, true)
		return
	state.coins -= cost
	state.plots.append(Plot.new(_next_plot_id()))
	_mark_dirty()


func buy_polyhouse() -> void:
	if state.has_polyhouse:
		return
	var cost := GameData.polyhouse_cost(GameData.is_subsidy_unlocked(state.total_harvests))
	if state.coins < cost:
		_push_event(tr(&"event.polyhouse_need_coins") % cost, true)
		return
	var next_id := _next_plot_id()
	state.coins -= cost
	state.has_polyhouse = true
	for offset in range(GameData.POLYHOUSE_PLOT_COUNT):
		state.plots.append(Plot.new(next_id + offset, PlotKind.Kind.POLYHOUSE))
	_push_event(tr(&"event.polyhouse_built"))
	_mark_dirty()


func buy_fan_pad() -> void:
	if not state.has_polyhouse or state.has_fan_pad:
		return
	if state.coins < GameData.FAN_PAD_COST:
		_push_event(tr(&"event.fan_pad_need_coins") % GameData.FAN_PAD_COST, true)
		return
	state.coins -= GameData.FAN_PAD_COST
	state.has_fan_pad = true
	_mark_dirty()


func buy_drip_irrigation() -> void:
	if not state.has_polyhouse or state.has_drip_irrigation:
		return
	if state.coins < GameData.DRIP_IRRIGATION_COST:
		_push_event(tr(&"event.drip_need_coins") % GameData.DRIP_IRRIGATION_COST, true)
		return
	state.coins -= GameData.DRIP_IRRIGATION_COST
	state.has_drip_irrigation = true
	_mark_dirty()


func renew_film(now: int) -> void:
	if not state.has_polyhouse:
		return
	if state.coins < GameData.UV_FILM_COST:
		_push_event(tr(&"event.film_need_coins") % GameData.UV_FILM_COST, true)
		return
	state.coins -= GameData.UV_FILM_COST
	state.film_expires_at_epoch_ms = now + GameData.UV_FILM_DURATION_MS
	_push_event(tr(&"event.film_renewed"))
	_mark_dirty()


# --- Tier 3: Agroforestry / Sandalwood --------------------------------------------

func _agro_neighbors(plot: Plot) -> Array[Plot]:
	var neighbors: Array[Plot] = []
	if plot.agro_row == -1 or plot.agro_col == -1:
		return neighbors
	for other: Plot in state.plots:
		if other.kind != PlotKind.Kind.AGROFORESTRY:
			continue
		if other.agro_row == -1 or other.agro_col == -1:
			continue
		if absi(other.agro_row - plot.agro_row) + absi(other.agro_col - plot.agro_col) == 1:
			neighbors.append(other)
	return neighbors


## True if this empty Agroforestry tile sits next to at least one placed host
## plant.
func can_plant_sandalwood(plot_id: int) -> bool:
	var plot := _find_plot(plot_id)
	if plot == null:
		return false
	if plot.kind != PlotKind.Kind.AGROFORESTRY or plot.state.kind != PlotState.Kind.EMPTY or plot.host_type != HostType.NONE:
		return false
	for neighbor in _agro_neighbors(plot):
		if neighbor.host_type != HostType.NONE:
			return true
	return false


func buy_agroforestry() -> void:
	if state.has_agroforestry:
		return
	if state.coins < GameData.AGROFORESTRY_UNLOCK_COST:
		_push_event(tr(&"event.agroforestry_need_coins") % GameData.AGROFORESTRY_UNLOCK_COST, true)
		return
	var next_id := _next_plot_id()
	var size := GameData.AGROFORESTRY_GRID_SIZE
	state.coins -= GameData.AGROFORESTRY_UNLOCK_COST
	state.has_agroforestry = true
	for index in range(size * size):
		var plot := Plot.new(next_id + index, PlotKind.Kind.AGROFORESTRY)
		plot.agro_row = index / size
		plot.agro_col = index % size
		state.plots.append(plot)
	_push_event(tr(&"event.agroforestry_built"))
	_mark_dirty()


func buy_security() -> void:
	if not state.has_agroforestry or state.has_security:
		return
	if state.coins < GameData.SECURITY_COST:
		_push_event(tr(&"event.security_need_coins") % GameData.SECURITY_COST, true)
		return
	state.coins -= GameData.SECURITY_COST
	state.has_security = true
	_mark_dirty()


func plant_host(plot_id: int, host: int) -> void:
	var plot := _find_plot(plot_id)
	if plot == null:
		return
	if plot.kind != PlotKind.Kind.AGROFORESTRY or plot.state.kind != PlotState.Kind.EMPTY or plot.host_type != HostType.NONE:
		return
	var host_def := GameData.host_type_def(host)
	if state.coins < host_def.cost:
		_push_event(tr(&"event.need_coins_for_named_item") % [host_def.cost, host_def.display_name], true)
		return
	state.coins -= host_def.cost
	plot.host_type = host
	_mark_dirty()


func remove_host(plot_id: int) -> void:
	var plot := _find_plot(plot_id)
	if plot == null:
		return
	if plot.host_type == HostType.NONE:
		return
	plot.host_type = HostType.NONE
	_mark_dirty()


func plant_sandalwood(plot_id: int, now: int, variety: int = 0) -> void:
	var plot := _find_plot(plot_id)
	if plot == null:
		return
	if plot.kind != PlotKind.Kind.AGROFORESTRY or plot.state.kind != PlotState.Kind.EMPTY or plot.host_type != HostType.NONE:
		return
	var neighbors := _agro_neighbors(plot)
	var has_host: bool = false
	var has_acacia_host: bool = false
	for neighbor in neighbors:
		if neighbor.host_type != HostType.NONE:
			has_host = true
		if neighbor.host_type == HostType.Kind.ACACIA:
			has_acacia_host = true
	if not has_host:
		_push_event(tr(&"event.sandalwood_needs_host"), true)
		return
	var crop_def := GameData.crop_def(CropType.Kind.SANDALWOOD)
	var variety_def := GameData.crop_variety_def(CropType.Kind.SANDALWOOD, variety)
	var adjusted_seed_cost := roundi(float(crop_def.seed_cost) * variety_def.seed_cost_multiplier)
	if state.coins < adjusted_seed_cost:
		_push_event(tr(&"event.sandalwood_need_coins"), true)
		return
	var base_seconds: int = GameData.SANDALWOOD_GROW_SECONDS_ACACIA if has_acacia_host else GameData.SANDALWOOD_GROW_SECONDS_BASE
	var variety_grow_multiplier: float = variety_def.grow_time_multiplier
	var effective_seconds: int = maxi(roundi(float(base_seconds) * variety_grow_multiplier * _growth_speed_multiplier()), 1)

	state.coins -= adjusted_seed_cost
	plot.state = PlotState.new_growing(CropType.Kind.SANDALWOOD, now, effective_seconds)
	plot.selected_variety = variety
	_mark_dirty()


# --- Tier 4: Niche Regional / Vertical Farming -------------------------------------

func buy_aquaculture() -> void:
	if state.has_aquaculture:
		return
	if state.coins < GameData.AQUACULTURE_UNLOCK_COST:
		_push_event(tr(&"event.aquaculture_need_coins") % GameData.AQUACULTURE_UNLOCK_COST, true)
		return
	var next_id := _next_plot_id()
	state.coins -= GameData.AQUACULTURE_UNLOCK_COST
	state.has_aquaculture = true
	for offset in range(GameData.AQUACULTURE_PLOT_COUNT):
		state.plots.append(Plot.new(next_id + offset, PlotKind.Kind.AQUACULTURE))
	_push_event(tr(&"event.aquaculture_built"))
	_mark_dirty()


func buy_vertical_farm() -> void:
	if state.has_vertical_farm:
		return
	if state.coins < GameData.VERTICAL_FARM_UNLOCK_COST:
		_push_event(tr(&"event.vertical_farm_need_coins") % GameData.VERTICAL_FARM_UNLOCK_COST, true)
		return
	var next_id := _next_plot_id()
	state.coins -= GameData.VERTICAL_FARM_UNLOCK_COST
	state.has_vertical_farm = true
	for offset in range(GameData.VERTICAL_FARM_PLOT_COUNT):
		state.plots.append(Plot.new(next_id + offset, PlotKind.Kind.VERTICAL_FARM))
	_push_event(tr(&"event.vertical_farm_built"))
	_mark_dirty()


func renew_electricity(now: int) -> void:
	if not state.has_vertical_farm:
		return
	if state.coins < GameData.ELECTRICITY_COST:
		_push_event(tr(&"event.electricity_need_coins") % GameData.ELECTRICITY_COST, true)
		return
	state.coins -= GameData.ELECTRICITY_COST
	state.electricity_expires_at_epoch_ms = now + GameData.ELECTRICITY_DURATION_MS
	_push_event(tr(&"event.electricity_paid"))
	_mark_dirty()


# --- Mandi / e-NAM trading -----------------------------------------------------------

## Decays the stored glut for `crop` forward to `now` without mutating state.
func current_glut(crop: int, now: int) -> float:
	var stored: MandiGlut = state.mandi_glut.get(crop, null)
	if stored == null:
		return 0.0
	var elapsed_hours: float = maxf(float(now - stored.updated_at_epoch_ms), 0.0) / 3_600_000.0
	var decayed: float = stored.value * exp(-GameData.MANDI_GLUT_DECAY_PER_HOUR * elapsed_hours)
	return 0.0 if decayed < 0.001 else decayed


## Combines the server-wide demand cycle, this crop's automatic grade bonus
## (protected cultivation only), and its current oversupply glut into one
## clamped price multiplier.
func mandi_price_multiplier(crop: int, now: int) -> float:
	var cycle_index: int = now / GameData.MANDI_CYCLE_MS
	var demand_percent := GameData.demand_modifier_percent(crop, cycle_index)
	var crop_def := GameData.crop_def(crop)
	var grade_bonus_percent: int = GameData.MANDI_GRADE_A_BONUS_PERCENT if crop_def.required_plot_kind != PlotKind.Kind.OPEN_FIELD else 0
	var glut := current_glut(crop, now)
	var raw: float = 1.0 + demand_percent / 100.0 + grade_bonus_percent / 100.0 - glut
	return clampf(raw, GameData.MANDI_MIN_MULTIPLIER, GameData.MANDI_MAX_MULTIPLIER)


## Tomorrow's demand swing, only meaningful once the auction terminal is
## bought.
func mandi_forecast_percent(crop: int, now: int) -> int:
	var next_cycle_index: int = now / GameData.MANDI_CYCLE_MS + 1
	return GameData.demand_modifier_percent(crop, next_cycle_index)


func buy_mandi() -> void:
	if state.has_mandi:
		return
	if state.coins < GameData.MANDI_UNLOCK_COST:
		_push_event(tr(&"event.mandi_need_coins") % GameData.MANDI_UNLOCK_COST, true)
		return
	state.coins -= GameData.MANDI_UNLOCK_COST
	state.has_mandi = true
	_push_event(tr(&"event.mandi_registered"))
	_mark_dirty()


func buy_mandi_terminal() -> void:
	if not state.has_mandi or state.has_mandi_terminal:
		return
	if state.coins < GameData.MANDI_TERMINAL_COST:
		_push_event(tr(&"event.mandi_terminal_need_coins") % GameData.MANDI_TERMINAL_COST, true)
		return
	state.coins -= GameData.MANDI_TERMINAL_COST
	state.has_mandi_terminal = true
	_mark_dirty()


func sell_to_mandi(crop: int, now: int) -> void:
	if not state.has_mandi:
		return
	var stock: CropStock = state.inventory.get(crop, null)
	if stock == null or stock.total == 0:
		return

	var market_multiplier := mandi_price_multiplier(crop, now)
	var farmhouse_multiplier := _sell_price_multiplier(now)
	var combined: float = market_multiplier * farmhouse_multiplier

	var crop_def := GameData.crop_def(crop)
	var normal_value: int = roundi(stock.normal * crop_def.base_sell_price * combined)
	var damaged_value: int = roundi(stock.damaged * crop_def.base_sell_price * GameData.WEATHER_DAMAGE_YIELD_MULTIPLIER * combined)
	var total_value: int = normal_value + damaged_value

	var decayed_glut := current_glut(crop, now)
	var new_glut: float = decayed_glut + stock.total * GameData.MANDI_GLUT_PER_UNIT
	var units_sold: int = stock.total

	state.coins += total_value
	state.inventory.erase(crop)
	state.mandi_glut[crop] = MandiGlut.new(new_glut, now)

	var pct: int = roundi(market_multiplier * 100)
	_push_event(tr(&"event.mandi_sold") % [units_sold, crop_def.display_name, pct, total_value])
	_register_festival_sale(crop, units_sold, now)
	_mark_dirty()


# --- Zone layout: drag/rotate/flip (village board, no cost/validation) --------------

func move_zone(zone_id: String, tile_x: float, tile_y: float) -> void:
	var existing: ZoneAnchor = state.zone_layout.get(zone_id, null)
	var anchor: ZoneAnchor
	if existing != null:
		anchor = ZoneAnchor.new(tile_x, tile_y, existing.rotation_degrees, existing.flipped_x)
	else:
		anchor = ZoneAnchor.new(tile_x, tile_y)
	state.zone_layout[zone_id] = anchor
	_mark_dirty()


func rotate_zone(zone_id: String, default_tile_x: float, default_tile_y: float) -> void:
	var existing: ZoneAnchor = state.zone_layout.get(zone_id, null)
	var base: ZoneAnchor = existing if existing != null else ZoneAnchor.new(default_tile_x, default_tile_y)
	state.zone_layout[zone_id] = ZoneAnchor.new(base.tile_x, base.tile_y, (base.rotation_degrees + 90) % 360, base.flipped_x)
	_mark_dirty()


func flip_zone(zone_id: String, default_tile_x: float, default_tile_y: float) -> void:
	var existing: ZoneAnchor = state.zone_layout.get(zone_id, null)
	var base: ZoneAnchor = existing if existing != null else ZoneAnchor.new(default_tile_x, default_tile_y)
	state.zone_layout[zone_id] = ZoneAnchor.new(base.tile_x, base.tile_y, base.rotation_degrees, not base.flipped_x)
	_mark_dirty()


# --- Decorations: purely cosmetic placeables ----------------------------------------

func place_decoration(type: int, tile_x: float, tile_y: float) -> void:
	var type_def := GameData.decoration_type_def(type)
	if state.coins < type_def.cost:
		_push_event(tr(&"event.need_coins_for_named_item") % [type_def.cost, type_def.emoji], true)
		return
	var decoration := Decoration.new(state.next_decoration_id, type, tile_x, tile_y)
	state.coins -= type_def.cost
	state.decorations.append(decoration)
	state.next_decoration_id += 1
	_mark_dirty()


func remove_decoration(id: int) -> void:
	var kept: Array[Decoration] = []
	for decoration: Decoration in state.decorations:
		if decoration.id != id:
			kept.append(decoration)
	state.decorations = kept
	_mark_dirty()


func move_decoration(id: int, tile_x: float, tile_y: float) -> void:
	for decoration: Decoration in state.decorations:
		if decoration.id == id:
			decoration.tile_x = tile_x
			decoration.tile_y = tile_y
	_mark_dirty()


func rotate_decoration(id: int) -> void:
	for decoration: Decoration in state.decorations:
		if decoration.id == id:
			decoration.rotation_degrees = (decoration.rotation_degrees + 90) % 360
	_mark_dirty()


func flip_decoration(id: int) -> void:
	for decoration: Decoration in state.decorations:
		if decoration.id == id:
			decoration.flipped_x = not decoration.flipped_x
	_mark_dirty()
