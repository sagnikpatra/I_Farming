## Covers land-and-structures.md's formula table: land expansion cap
## (TR-land-001), Polyhouse pricing/spoilage (TR-land-002), Agroforestry
## adjacency + Sandalwood theft (TR-land-003), and the remaining structure
## tiers' unlock flows.
extends GutTest

const NOW_QUIET: int = 10_000_000

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 10_000_000


func test_land_expansion_blocked_at_max_plots() -> void:
	# Buy up to MAX_PLOTS (16) open-field plots (starting at 3), then confirm
	# the 17th attempt is blocked with an event and no further plot/coin change.
	for _i in range(GameData.MAX_PLOTS - GameData.STARTING_PLOTS):
		eco.buy_land_expansion()
	var open_field_count: int = 0
	for plot: Plot in eco.state.plots:
		if plot.kind == PlotKind.Kind.OPEN_FIELD:
			open_field_count += 1
	assert_eq(open_field_count, GameData.MAX_PLOTS)

	var coins_before := eco.state.coins
	var plot_count_before := eco.state.plots.size()
	eco.pending_events.clear()
	eco.buy_land_expansion()
	assert_eq(eco.state.plots.size(), plot_count_before)
	assert_eq(eco.state.coins, coins_before)
	assert_true(eco.has_events())


func test_polyhouse_cost_reflects_subsidy_state() -> void:
	assert_eq(GameData.polyhouse_cost(GameData.is_subsidy_unlocked(eco.state.total_harvests)), 35_000)
	eco.state.total_harvests = 25
	assert_eq(GameData.polyhouse_cost(GameData.is_subsidy_unlocked(eco.state.total_harvests)), 17_500)


func test_polyhouse_spoilage_grace_extended_by_drip_irrigation() -> void:
	eco.buy_polyhouse()
	var polyhouse_plot: Plot = null
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.POLYHOUSE:
			polyhouse_plot = p
			break
	eco.plant_seed(polyhouse_plot.id, CropType.Kind.CAPSICUM, NOW_QUIET)
	eco.resolve_growth_completions(NOW_QUIET + polyhouse_plot.state.effective_grow_seconds * 1000)
	assert_eq(polyhouse_plot.state.kind, PlotState.Kind.READY_TO_HARVEST)
	var ready_at: int = polyhouse_plot.state.ready_at_epoch_ms

	# Base grace is 4h. Harvest 5h later -- must arrive spoiled (damaged).
	eco.harvest_plot(polyhouse_plot.id, ready_at + 5 * 60 * 60 * 1000)
	var stock: CropStock = eco.state.inventory[CropType.Kind.CAPSICUM]
	assert_eq(stock.damaged, 1)
	assert_eq(stock.normal, 0)


func test_polyhouse_spoilage_grace_with_drip_irrigation_survives_5_hours() -> void:
	eco.buy_polyhouse()
	eco.buy_drip_irrigation()
	# Also renew the UV film so the weather-damage roll (unseeded, per
	# crop-economy.md's documented "deterministic-but-fresh" distinction --
	# see test_randomness.gd) can't flakily set weather_damaged=true and
	# contaminate this test's assertion that the harvested stock is fresh.
	# The spoilage-*causes*-damage test above doesn't need this guard, since
	# `damaged = weather_damaged OR spoiled` already holds true there
	# regardless of the weather roll's outcome.
	eco.renew_film(NOW_QUIET)
	var polyhouse_plot: Plot = null
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.POLYHOUSE:
			polyhouse_plot = p
			break
	eco.plant_seed(polyhouse_plot.id, CropType.Kind.CAPSICUM, NOW_QUIET)
	eco.resolve_growth_completions(NOW_QUIET + polyhouse_plot.state.effective_grow_seconds * 1000)
	var ready_at: int = polyhouse_plot.state.ready_at_epoch_ms

	# With Drip Irrigation, grace is 24h -- 5h later must still arrive fresh.
	eco.harvest_plot(polyhouse_plot.id, ready_at + 5 * 60 * 60 * 1000)
	var stock: CropStock = eco.state.inventory[CropType.Kind.CAPSICUM]
	assert_eq(stock.normal, 1)
	assert_eq(stock.damaged, 0)


func test_agroforestry_adjacency_gates_sandalwood_planting() -> void:
	eco.buy_agroforestry()
	var agro_plots: Array[Plot] = []
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.AGROFORESTRY:
			agro_plots.append(p)
	assert_eq(agro_plots.size(), GameData.AGROFORESTRY_GRID_SIZE * GameData.AGROFORESTRY_GRID_SIZE)

	# agro_plots[0] is (row 0, col 0); agro_plots[1] is (row 0, col 1) --
	# orthogonally adjacent (Manhattan distance 1).
	var host_plot: Plot = agro_plots[0]
	var adjacent_plot: Plot = agro_plots[1]
	assert_false(eco.can_plant_sandalwood(adjacent_plot.id))

	eco.plant_host(host_plot.id, HostType.Kind.NEEM)
	assert_true(eco.can_plant_sandalwood(adjacent_plot.id))


func test_sandalwood_grow_time_shortened_by_acacia_host() -> void:
	eco.buy_agroforestry()
	var agro_plots: Array[Plot] = []
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.AGROFORESTRY:
			agro_plots.append(p)
	var acacia_host: Plot = agro_plots[0]
	var neem_host: Plot = agro_plots[3]  # row 1, col 0 -- not adjacent to agro_plots[1]
	var target_via_acacia: Plot = agro_plots[1]  # adjacent to agro_plots[0]
	var target_via_neem: Plot = agro_plots[6]  # row 2, col 0 -- adjacent to agro_plots[3]

	eco.plant_host(acacia_host.id, HostType.Kind.ACACIA)
	eco.plant_host(neem_host.id, HostType.Kind.NEEM)

	eco.plant_sandalwood(target_via_acacia.id, NOW_QUIET)
	assert_eq(target_via_acacia.state.effective_grow_seconds, GameData.SANDALWOOD_GROW_SECONDS_ACACIA)

	eco.plant_sandalwood(target_via_neem.id, NOW_QUIET)
	assert_eq(target_via_neem.state.effective_grow_seconds, GameData.SANDALWOOD_GROW_SECONDS_BASE)


func test_sandalwood_theft_probability_constants_match_gdd() -> void:
	assert_eq(GameData.THEFT_HOURLY_PROBABILITY_UNPROTECTED, 0.00085)
	assert_eq(GameData.THEFT_HOURLY_PROBABILITY_PROTECTED, 0.00006)
	# Security makes theft ~14x safer, per land-and-structures.md.
	var ratio := GameData.THEFT_HOURLY_PROBABILITY_UNPROTECTED / GameData.THEFT_HOURLY_PROBABILITY_PROTECTED
	assert_almost_eq(ratio, 14.1667, 0.01)


func test_sandalwood_theft_zero_elapsed_hours_never_steals() -> void:
	assert_false(eco.was_sandalwood_stolen(1, 0, false))


func test_removing_host_does_not_retroactively_stop_an_adjacent_growing_sandalwood() -> void:
	# land-and-structures.md's documented edge case: removeHost has no
	# adjacency-safety check, and the Sandalwood keeps growing on its
	# already-locked-in effective_grow_seconds.
	eco.buy_agroforestry()
	var agro_plots: Array[Plot] = []
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.AGROFORESTRY:
			agro_plots.append(p)
	var host_plot: Plot = agro_plots[0]
	var target_plot: Plot = agro_plots[1]
	eco.plant_host(host_plot.id, HostType.Kind.NEEM)
	eco.plant_sandalwood(target_plot.id, NOW_QUIET)
	assert_eq(target_plot.state.kind, PlotState.Kind.GROWING)

	eco.remove_host(host_plot.id)
	assert_eq(host_plot.host_type, HostType.NONE)
	assert_eq(target_plot.state.kind, PlotState.Kind.GROWING)  # unaffected


func test_aquaculture_unlock_grants_plot_count() -> void:
	var plots_before := eco.state.plots.size()
	eco.buy_aquaculture()
	assert_eq(eco.state.plots.size(), plots_before + GameData.AQUACULTURE_PLOT_COUNT)
	assert_true(eco.state.has_aquaculture)


func test_vertical_farm_saffron_requires_active_electricity_to_start() -> void:
	eco.buy_vertical_farm()
	var vf_plot: Plot = null
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.VERTICAL_FARM:
			vf_plot = p
			break
	eco.pending_events.clear()
	eco.plant_seed(vf_plot.id, CropType.Kind.SAFFRON, NOW_QUIET)
	assert_eq(vf_plot.state.kind, PlotState.Kind.EMPTY)  # blocked, no electricity
	assert_true(eco.has_events())

	eco.renew_electricity(NOW_QUIET)
	eco.plant_seed(vf_plot.id, CropType.Kind.SAFFRON, NOW_QUIET)
	assert_eq(vf_plot.state.kind, PlotState.Kind.GROWING)


func test_vertical_farm_saffron_unaffected_if_electricity_lapses_mid_grow() -> void:
	eco.buy_vertical_farm()
	eco.renew_electricity(NOW_QUIET)
	var vf_plot: Plot = null
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.VERTICAL_FARM:
			vf_plot = p
			break
	eco.plant_seed(vf_plot.id, CropType.Kind.SAFFRON, NOW_QUIET)
	assert_eq(vf_plot.state.kind, PlotState.Kind.GROWING)

	# Well past electricity expiry (2 days) -- the already-Growing crop must
	# still resolve normally, per land-and-structures.md.
	var far_future: int = NOW_QUIET + GameData.ELECTRICITY_DURATION_MS + 10 * 24 * 60 * 60 * 1000
	eco.resolve_growth_completions(far_future)
	assert_eq(vf_plot.state.kind, PlotState.Kind.READY_TO_HARVEST)
