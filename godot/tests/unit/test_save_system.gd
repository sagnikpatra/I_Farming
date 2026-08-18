## Covers save_system.gd's load_state/save_state round-trip, plus its two
## documented fallback paths: no save file exists yet, and a save file that
## fails to load as a GameState (corrupt bytes, or a resource of the wrong
## type) -- both must fall back to a fresh GameState rather than propagating
## an error, per GameRepository.kt's original
## `runCatching { deserialize(raw) }.getOrDefault(GameState())` behavior.
extends GutTest

const PATH_ROUND_TRIP: String = "user://test_save_round_trip.tres"
const PATH_LIFECYCLE: String = "user://test_save_lifecycle.tres"
const PATH_NO_FILE: String = "user://test_save_does_not_exist.tres"
const PATH_CORRUPT: String = "user://test_save_corrupt.tres"
const PATH_WRONG_TYPE: String = "user://test_save_wrong_type.tres"

const _ALL_PATHS: Array[String] = [
	PATH_ROUND_TRIP,
	PATH_LIFECYCLE,
	PATH_NO_FILE,
	PATH_CORRUPT,
	PATH_WRONG_TYPE,
]


func before_each() -> void:
	_cleanup_files()


func after_each() -> void:
	_cleanup_files()


func _cleanup_files() -> void:
	for path: String in _ALL_PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


# --- No save file yet -------------------------------------------------------------

func test_load_state_with_no_save_file_returns_a_fresh_state() -> void:
	assert_file_does_not_exist(PATH_NO_FILE)
	var state := SaveSystem.load_state(PATH_NO_FILE)
	assert_eq(state.coins, 300)
	assert_eq(state.plots.size(), GameData.STARTING_PLOTS)


# --- Corrupt / unreadable save -----------------------------------------------------

func test_load_state_falls_back_to_a_fresh_state_on_unparseable_bytes() -> void:
	var f := FileAccess.open(PATH_CORRUPT, FileAccess.WRITE)
	f.store_string("this is not a valid Godot resource file")
	f.close()
	assert_file_exists(PATH_CORRUPT)

	var state := SaveSystem.load_state(PATH_CORRUPT)
	# ResourceLoader.load() logs 3 engine-level errors while failing to parse
	# the garbage bytes, *before* save_system.gd's own null-check falls back
	# to a fresh GameState -- expected and already handled (see the
	# push_warning in save_system.gd), so acknowledge them here rather than
	# letting GUT flag them as unexpected test failures.
	assert_engine_error_count(3, "ResourceLoader.load() parse-failure noise, already handled by SaveSystem's fallback")
	assert_eq(state.coins, 300)
	assert_eq(state.plots.size(), GameData.STARTING_PLOTS)


func test_load_state_falls_back_to_a_fresh_state_on_wrong_resource_type() -> void:
	# A validly-saved .tres that just isn't a GameState -- the loader's
	# `not (loaded is GameState)` branch, distinct from the null/parse-failure
	# branch covered above.
	var wrong_resource := Resource.new()
	var save_err := ResourceSaver.save(wrong_resource, PATH_WRONG_TYPE)
	assert_eq(save_err, OK)

	var state := SaveSystem.load_state(PATH_WRONG_TYPE)
	assert_eq(state.coins, 300)
	assert_eq(state.plots.size(), GameData.STARTING_PLOTS)


# --- Round trip ----------------------------------------------------------------------

func test_save_state_then_load_state_round_trips_progression_and_economy_fields() -> void:
	var eco := GameEconomy.new()
	# Comfortably covers buy_polyhouse (35,000) + buy_agroforestry (20,000) +
	# buy_mandi (3,000) with coins left over -- a hardcoded literal here
	# previously left insufficient funds for buy_agroforestry, silently
	# no-opping it and leaving no AGROFORESTRY plot to attach a host to.
	eco.state.coins = 200_000
	eco.buy_polyhouse()
	eco.buy_agroforestry()
	eco.buy_mandi()
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(7, 2)
	eco.state.mandi_glut[CropType.Kind.WHEAT] = MandiGlut.new(1.5, 42_000)
	eco.state.farmhouse_level = 3
	eco.state.total_harvests = 30
	eco.state.has_security = true
	eco.state.film_expires_at_epoch_ms = 99_999
	eco.state.electricity_expires_at_epoch_ms = 88_888
	eco.state.event_occurrence_index = 5
	eco.state.event_points = 120
	eco.state.event_has_premium_pass = true
	eco.state.event_claimed_tier = 2
	eco.state.zone_layout["farmhouse"] = ZoneAnchor.new(1.5, -2.25, 180, true)
	eco.state.decorations.append(Decoration.new(0, DecorationType.Kind.LANTERN, 3.0, 4.0, 90, false))
	eco.state.next_decoration_id = 1

	var agro_plot: Plot = null
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.AGROFORESTRY:
			agro_plot = p
			break
	agro_plot.host_type = HostType.Kind.NEEM

	# Captured after all the purchases above, not hardcoded -- the exact coin
	# balance depends on the unlock costs, which aren't this test's concern.
	var coins_before_save: int = eco.state.coins

	var save_ok := SaveSystem.save_state(eco.state, PATH_ROUND_TRIP)
	assert_true(save_ok)
	assert_file_exists(PATH_ROUND_TRIP)

	var loaded := SaveSystem.load_state(PATH_ROUND_TRIP)
	assert_eq(loaded.coins, coins_before_save)
	assert_true(loaded.has_polyhouse)
	assert_true(loaded.has_agroforestry)
	assert_true(loaded.has_mandi)
	assert_eq(loaded.plots.size(), eco.state.plots.size())
	assert_eq(loaded.farmhouse_level, 3)
	assert_eq(loaded.total_harvests, 30)
	assert_true(loaded.has_security)
	assert_eq(loaded.film_expires_at_epoch_ms, 99_999)
	assert_eq(loaded.electricity_expires_at_epoch_ms, 88_888)
	assert_eq(loaded.event_occurrence_index, 5)
	assert_eq(loaded.event_points, 120)
	assert_true(loaded.event_has_premium_pass)
	assert_eq(loaded.event_claimed_tier, 2)

	var loaded_stock: CropStock = loaded.inventory[CropType.Kind.WHEAT]
	assert_eq(loaded_stock.normal, 7)
	assert_eq(loaded_stock.damaged, 2)

	var loaded_glut: MandiGlut = loaded.mandi_glut[CropType.Kind.WHEAT]
	assert_almost_eq(loaded_glut.value, 1.5, 0.0001)
	assert_eq(loaded_glut.updated_at_epoch_ms, 42_000)

	var loaded_anchor: ZoneAnchor = loaded.zone_layout["farmhouse"]
	assert_almost_eq(loaded_anchor.tile_x, 1.5, 0.0001)
	assert_almost_eq(loaded_anchor.tile_y, -2.25, 0.0001)
	assert_eq(loaded_anchor.rotation_degrees, 180)
	assert_true(loaded_anchor.flipped_x)

	assert_eq(loaded.decorations.size(), 1)
	var loaded_decoration: Decoration = loaded.decorations[0]
	assert_eq(loaded_decoration.type, DecorationType.Kind.LANTERN)
	assert_almost_eq(loaded_decoration.tile_x, 3.0, 0.0001)
	assert_eq(loaded_decoration.rotation_degrees, 90)
	assert_eq(loaded.next_decoration_id, 1)

	var loaded_agro: Plot = null
	for p: Plot in loaded.plots:
		if p.kind == PlotKind.Kind.AGROFORESTRY:
			loaded_agro = p
			break
	assert_not_null(loaded_agro)
	assert_eq(loaded_agro.host_type, HostType.Kind.NEEM)


func test_save_state_then_load_state_round_trips_plot_lifecycle_states() -> void:
	var eco := GameEconomy.new()
	eco.state.coins = 1_000_000
	var now := 10_000_000

	# Plant and fully resolve one plot to READY_TO_HARVEST first.
	var ready_plot: Plot = eco.state.plots[1]
	eco.plant_seed(ready_plot.id, CropType.Kind.WHEAT, now)
	eco.resolve_growth_completions(now + 121 * 1000)
	assert_eq(ready_plot.state.kind, PlotState.Kind.READY_TO_HARVEST)

	# Plant a second plot right at that same moment -- Wheat's 120s grow time
	# means it's still mid-grow when we resolve again immediately, so it
	# stays GROWING (planting both plots at the same `now` and resolving once
	# past 120s would flip both to READY_TO_HARVEST, defeating the point of
	# this fixture -- see the bug this replaced).
	var growing_plot: Plot = eco.state.plots[0]
	var planted_at: int = now + 121 * 1000
	eco.plant_seed(growing_plot.id, CropType.Kind.WHEAT, planted_at)
	eco.resolve_growth_completions(planted_at)
	assert_eq(growing_plot.state.kind, PlotState.Kind.GROWING)

	SaveSystem.save_state(eco.state, PATH_LIFECYCLE)
	var loaded := SaveSystem.load_state(PATH_LIFECYCLE)

	var loaded_growing: Plot = null
	var loaded_ready: Plot = null
	for p: Plot in loaded.plots:
		if p.id == growing_plot.id:
			loaded_growing = p
		elif p.id == ready_plot.id:
			loaded_ready = p

	assert_not_null(loaded_growing)
	assert_eq(loaded_growing.state.kind, PlotState.Kind.GROWING)
	assert_eq(loaded_growing.state.crop, CropType.Kind.WHEAT)
	assert_eq(loaded_growing.state.planted_at_epoch_ms, planted_at)
	assert_eq(loaded_growing.state.effective_grow_seconds, growing_plot.state.effective_grow_seconds)

	assert_not_null(loaded_ready)
	assert_eq(loaded_ready.state.kind, PlotState.Kind.READY_TO_HARVEST)
	assert_eq(loaded_ready.state.crop, CropType.Kind.WHEAT)
	assert_eq(loaded_ready.state.ready_at_epoch_ms, ready_plot.state.ready_at_epoch_ms)
	assert_eq(loaded_ready.state.weather_damaged, ready_plot.state.weather_damaged)
