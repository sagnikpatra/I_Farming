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


func _push_event(message: String) -> void:
	pending_events.append(GameEvent.new(message))


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
func effective_weather_risk_percent(plot_kind: PlotKind.Kind, crop: int, now: int) -> int:
	match plot_kind:
		PlotKind.Kind.OPEN_FIELD:
			return GameData.crop_def(crop).weather_risk_percent
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
		_push_event("The Premium Pass can only be bought during an active festival.")
		return
	_with_fresh_event_occurrence(now)
	if state.event_has_premium_pass:
		return
	if state.coins < GameData.FESTIVAL_PREMIUM_PASS_COST:
		_push_event("Need ₹%d for the Premium Pass." % GameData.FESTIVAL_PREMIUM_PASS_COST)
		return
	state.coins -= GameData.FESTIVAL_PREMIUM_PASS_COST
	state.event_has_premium_pass = true
	_push_event("🎫 Premium Pass activated for this festival!")
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
			var msg: String = "%s %s Tier %d reached! +₹%d" % [festival.emoji, festival.display_name, tier_number, free_reward]
			if state.event_has_premium_pass:
				var premium_reward: int = GameData.FESTIVAL_PREMIUM_BONUS[index]
				coins_gained += premium_reward
				msg += " (+₹%d Premium bonus)" % premium_reward
			last_message = msg
			new_tier = tier_number

	state.event_points = new_points
	state.event_claimed_tier = new_tier
	state.coins += coins_gained
	if last_message != "":
		_push_event(last_message)
	_mark_dirty()


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
## more).
func _sell_price_multiplier() -> float:
	return 1.0 + GameData.farmhouse_level_def(state.farmhouse_level).sell_price_bonus_percent / 100.0


func buy_farmhouse_upgrade() -> void:
	if state.farmhouse_level >= GameData.farmhouse_max_level():
		return
	var next_level := GameData.farmhouse_level_def(state.farmhouse_level + 1)
	if state.coins < next_level.upgrade_cost:
		_push_event("Need ₹%d to upgrade to %s." % [next_level.upgrade_cost, next_level.display_name])
		return
	state.coins -= next_level.upgrade_cost
	state.farmhouse_level += 1
	_push_event("%s Welcome to your new %s!" % [next_level.emoji, next_level.display_name])
	_mark_dirty()


# --- Crop lifecycle: plant / harvest / sell --------------------------------------

func plant_seed(plot_id: int, crop: int, now: int) -> void:
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
	if crop == CropType.Kind.SAFFRON and not is_electricity_active(now):
		_push_event("Renew the electricity credit to power the grow lights.")
		return
	if state.coins < crop_def.seed_cost:
		_push_event("Not enough coins for %s seeds." % crop_def.display_name)
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
	var effective_seconds: int = maxi(roundi(after_fan_pad * _growth_speed_multiplier() * monsoon_multiplier), 1)

	state.coins -= crop_def.seed_cost
	plot.state = PlotState.new_growing(crop, now, effective_seconds)
	_mark_dirty()


func harvest_plot(plot_id: int, now: int) -> void:
	var plot := _find_plot(plot_id)
	if plot == null:
		return
	if plot.state.kind != PlotState.Kind.READY_TO_HARVEST:
		return
	var ready := plot.state

	var capacity := storage_capacity()
	var current_total := total_inventory_units()
	if current_total >= capacity:
		_push_event("📦 Storage full (%d/%d)! Sell crops or upgrade your Farmhouse." % [current_total, capacity])
		return

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

	if spoiled and not ready.weather_damaged:
		_push_event("🥀 That %s sat too long and spoiled a little." % GameData.crop_def(ready.crop).display_name)

	_mark_dirty()


func sell_crop(crop: int, now: int) -> void:
	var stock: CropStock = state.inventory.get(crop, null)
	if stock == null or stock.total == 0:
		return

	var sell_multiplier := _sell_price_multiplier()
	var crop_def := GameData.crop_def(crop)
	var normal_value: int = roundi(stock.normal * crop_def.base_sell_price * sell_multiplier)
	var damaged_value: int = roundi(stock.damaged * crop_def.base_sell_price * GameData.WEATHER_DAMAGE_YIELD_MULTIPLIER * sell_multiplier)
	var total_value: int = normal_value + damaged_value
	var units_sold: int = stock.total

	state.coins += total_value
	state.inventory.erase(crop)
	_push_event("Sold %d %s for ₹%d" % [units_sold, crop_def.display_name, total_value])
	_register_festival_sale(crop, units_sold, now)
	_mark_dirty()


func sell_all(now: int) -> void:
	if state.inventory.is_empty():
		return
	var sell_multiplier := _sell_price_multiplier()
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
	_push_event("Sold everything for ₹%d" % total_value)
	for crop: int in sold_stock.keys():
		var stock: CropStock = sold_stock[crop]
		_register_festival_sale(crop, stock.total, now)
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
					_push_event("💀 Thieves made off with a Sandalwood tree before you could harvest it!")
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
					_push_event("🌊 Monsoon floods wiped out your %s! Polyhouse owners are immune." % crop_name)
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
			_push_event("⛈️ Unseasonal weather clipped your %s!" % crop_name)
			any_weather = true
		plot.state = PlotState.new_ready(growing.crop, damaged, now)
		any_mutation = true

	# Bugfix (a): only mark dirty (and thus become eligible for the next
	# autosave) if a plot actually transitioned this call -- see class doc.
	if any_mutation:
		_mark_dirty()


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
	var wage: int = _worker_wage_for(crop_def)

	harvest_plot(plot.id, now)  # plot.state.crop read above; plot is now Empty

	state.coins = maxi(state.coins - wage, 0)
	_push_event("A worker harvested %s %s (wage: ₹%d)." % [crop_def.emoji, crop_def.display_name, wage])

	var can_afford_replant: bool = state.coins >= crop_def.seed_cost
	var electricity_ok: bool = crop != CropType.Kind.SAFFRON or is_electricity_active(now)
	if can_afford_replant and electricity_ok:
		plant_seed(plot.id, crop, now)

	_mark_dirty()


func _worker_wage_for(crop_def: CropDef) -> int:
	return maxi(roundi(crop_def.base_sell_price * WORKER_WAGE_RATE), 1)


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


# --- Land & Tier 2: Polyhouse ----------------------------------------------------

func buy_land_expansion() -> void:
	var open_field_count: int = 0
	for plot: Plot in state.plots:
		if plot.kind == PlotKind.Kind.OPEN_FIELD:
			open_field_count += 1
	if open_field_count >= GameData.MAX_PLOTS:
		_push_event("Your farm has reached its maximum size for now.")
		return
	var cost := GameData.land_expansion_cost(open_field_count)
	if state.coins < cost:
		_push_event("Need ₹%d to expand your land." % cost)
		return
	state.coins -= cost
	state.plots.append(Plot.new(_next_plot_id()))
	_mark_dirty()


func buy_polyhouse() -> void:
	if state.has_polyhouse:
		return
	var cost := GameData.polyhouse_cost(GameData.is_subsidy_unlocked(state.total_harvests))
	if state.coins < cost:
		_push_event("Need ₹%d to build a Polyhouse." % cost)
		return
	var next_id := _next_plot_id()
	state.coins -= cost
	state.has_polyhouse = true
	for offset in range(GameData.POLYHOUSE_PLOT_COUNT):
		state.plots.append(Plot.new(next_id + offset, PlotKind.Kind.POLYHOUSE))
	_push_event("🏠 Polyhouse built! Colored Capsicum and Dutch Rose are now available.")
	_mark_dirty()


func buy_fan_pad() -> void:
	if not state.has_polyhouse or state.has_fan_pad:
		return
	if state.coins < GameData.FAN_PAD_COST:
		_push_event("Need ₹%d for Fan & Pad Climate Control." % GameData.FAN_PAD_COST)
		return
	state.coins -= GameData.FAN_PAD_COST
	state.has_fan_pad = true
	_mark_dirty()


func buy_drip_irrigation() -> void:
	if not state.has_polyhouse or state.has_drip_irrigation:
		return
	if state.coins < GameData.DRIP_IRRIGATION_COST:
		_push_event("Need ₹%d for Drip Irrigation." % GameData.DRIP_IRRIGATION_COST)
		return
	state.coins -= GameData.DRIP_IRRIGATION_COST
	state.has_drip_irrigation = true
	_mark_dirty()


func renew_film(now: int) -> void:
	if not state.has_polyhouse:
		return
	if state.coins < GameData.UV_FILM_COST:
		_push_event("Need ₹%d to renew the UV-stabilized film." % GameData.UV_FILM_COST)
		return
	state.coins -= GameData.UV_FILM_COST
	state.film_expires_at_epoch_ms = now + GameData.UV_FILM_DURATION_MS
	_push_event("UV-stabilized film renewed. Climate control active.")
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
		_push_event("Need ₹%d to clear land for Agroforestry." % GameData.AGROFORESTRY_UNLOCK_COST)
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
	_push_event("🌳 Agroforestry plots cleared. Plant a host, then Sandalwood beside it.")
	_mark_dirty()


func buy_security() -> void:
	if not state.has_agroforestry or state.has_security:
		return
	if state.coins < GameData.SECURITY_COST:
		_push_event("Need ₹%d for fencing and security." % GameData.SECURITY_COST)
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
		_push_event("Need ₹%d for %s." % [host_def.cost, host_def.display_name])
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


func plant_sandalwood(plot_id: int, now: int) -> void:
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
		_push_event("Sandalwood needs a host plant (Pigeon Pea, Neem, or Acacia) next to it.")
		return
	var crop_def := GameData.crop_def(CropType.Kind.SANDALWOOD)
	if state.coins < crop_def.seed_cost:
		_push_event("Not enough coins for a Sandalwood sapling.")
		return
	var base_seconds: int = GameData.SANDALWOOD_GROW_SECONDS_ACACIA if has_acacia_host else GameData.SANDALWOOD_GROW_SECONDS_BASE
	var effective_seconds: int = maxi(roundi(base_seconds * _growth_speed_multiplier()), 1)

	state.coins -= crop_def.seed_cost
	plot.state = PlotState.new_growing(CropType.Kind.SANDALWOOD, now, effective_seconds)
	_mark_dirty()


# --- Tier 4: Niche Regional / Vertical Farming -------------------------------------

func buy_aquaculture() -> void:
	if state.has_aquaculture:
		return
	if state.coins < GameData.AQUACULTURE_UNLOCK_COST:
		_push_event("Need ₹%d to excavate ponds." % GameData.AQUACULTURE_UNLOCK_COST)
		return
	var next_id := _next_plot_id()
	state.coins -= GameData.AQUACULTURE_UNLOCK_COST
	state.has_aquaculture = true
	for offset in range(GameData.AQUACULTURE_PLOT_COUNT):
		state.plots.append(Plot.new(next_id + offset, PlotKind.Kind.AQUACULTURE))
	_push_event("🪷 Ponds excavated! Makhana and Pond Fish are now available.")
	_mark_dirty()


func buy_vertical_farm() -> void:
	if state.has_vertical_farm:
		return
	if state.coins < GameData.VERTICAL_FARM_UNLOCK_COST:
		_push_event("Need ₹%d to build the vertical farm." % GameData.VERTICAL_FARM_UNLOCK_COST)
		return
	var next_id := _next_plot_id()
	state.coins -= GameData.VERTICAL_FARM_UNLOCK_COST
	state.has_vertical_farm = true
	for offset in range(GameData.VERTICAL_FARM_PLOT_COUNT):
		state.plots.append(Plot.new(next_id + offset, PlotKind.Kind.VERTICAL_FARM))
	_push_event("🌸 Saffron vertical farm built! Pay for electricity to start growing.")
	_mark_dirty()


func renew_electricity(now: int) -> void:
	if not state.has_vertical_farm:
		return
	if state.coins < GameData.ELECTRICITY_COST:
		_push_event("Need ₹%d for the electricity bill." % GameData.ELECTRICITY_COST)
		return
	state.coins -= GameData.ELECTRICITY_COST
	state.electricity_expires_at_epoch_ms = now + GameData.ELECTRICITY_DURATION_MS
	_push_event("Electricity bill paid. Grow lights powered.")
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
		_push_event("Need ₹%d to register at the Local Mandi." % GameData.MANDI_UNLOCK_COST)
		return
	state.coins -= GameData.MANDI_UNLOCK_COST
	state.has_mandi = true
	_push_event("🏛️ Registered at the Local Mandi -- e-NAM auctions are now open to you.")
	_mark_dirty()


func buy_mandi_terminal() -> void:
	if not state.has_mandi or state.has_mandi_terminal:
		return
	if state.coins < GameData.MANDI_TERMINAL_COST:
		_push_event("Need ₹%d for a digital auction terminal." % GameData.MANDI_TERMINAL_COST)
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
	var farmhouse_multiplier := _sell_price_multiplier()
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
	_push_event("🏛️ Mandi bought %d %s at %d%% market rate for ₹%d" % [units_sold, crop_def.display_name, pct, total_value])
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
		_push_event("Need ₹%d for %s." % [type_def.cost, type_def.emoji])
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
