## Covers every PlotState variant and transition, per ADR-0002's explicit
## risk-mitigation requirement for the sealed-class-replacement translation
## (see plot_state.gd's header comment for the architecture rationale).
extends GutTest


func test_new_empty_has_empty_kind_and_no_payload() -> void:
	var state := PlotState.new_empty()
	assert_eq(state.kind, PlotState.Kind.EMPTY)
	assert_eq(state.crop, -1)


func test_new_growing_carries_crop_and_snapshotted_grow_seconds() -> void:
	var state := PlotState.new_growing(CropType.Kind.WHEAT, 1000, 120)
	assert_eq(state.kind, PlotState.Kind.GROWING)
	assert_eq(state.crop, CropType.Kind.WHEAT)
	assert_eq(state.planted_at_epoch_ms, 1000)
	assert_eq(state.effective_grow_seconds, 120)


func test_new_ready_carries_crop_and_damage_flag() -> void:
	var undamaged := PlotState.new_ready(CropType.Kind.WHEAT, false, 5000)
	assert_eq(undamaged.kind, PlotState.Kind.READY_TO_HARVEST)
	assert_eq(undamaged.weather_damaged, false)
	assert_eq(undamaged.ready_at_epoch_ms, 5000)

	var damaged := PlotState.new_ready(CropType.Kind.WHEAT, true, 5000)
	assert_eq(damaged.weather_damaged, true)


func test_transition_empty_to_growing_via_plant_seed() -> void:
	var eco := GameEconomy.new()
	eco.state.coins = 1000
	var plot: Plot = eco.state.plots[0]
	assert_eq(plot.state.kind, PlotState.Kind.EMPTY)

	eco.plant_seed(plot.id, CropType.Kind.WHEAT, 10_000_000)
	assert_eq(plot.state.kind, PlotState.Kind.GROWING)


func test_transition_growing_to_ready_via_resolve_growth_completions() -> void:
	var eco := GameEconomy.new()
	eco.state.coins = 1000
	var plot: Plot = eco.state.plots[0]
	var now := 10_000_000
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, now)
	assert_eq(plot.state.kind, PlotState.Kind.GROWING)

	# Wheat grows in 120s; not elapsed yet -- stays Growing.
	eco.resolve_growth_completions(now + 60 * 1000)
	assert_eq(plot.state.kind, PlotState.Kind.GROWING)

	# Elapsed -- transitions to ReadyToHarvest.
	eco.resolve_growth_completions(now + 121 * 1000)
	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST)


func test_transition_ready_to_empty_via_harvest() -> void:
	var eco := GameEconomy.new()
	eco.state.coins = 1000
	var plot: Plot = eco.state.plots[0]
	var now := 10_000_000
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, now)
	eco.resolve_growth_completions(now + 200 * 1000)
	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST)

	eco.harvest_plot(plot.id, now + 200 * 1000)
	assert_eq(plot.state.kind, PlotState.Kind.EMPTY)


func test_harvest_blocked_when_not_ready_leaves_state_unchanged() -> void:
	var eco := GameEconomy.new()
	var plot: Plot = eco.state.plots[0]
	assert_eq(plot.state.kind, PlotState.Kind.EMPTY)
	eco.harvest_plot(plot.id, 10_000_000)
	# harvest_plot on an EMPTY (not READY_TO_HARVEST) plot must no-op.
	assert_eq(plot.state.kind, PlotState.Kind.EMPTY)


func test_plant_seed_blocked_when_not_empty_leaves_state_unchanged() -> void:
	var eco := GameEconomy.new()
	eco.state.coins = 1000
	var plot: Plot = eco.state.plots[0]
	var now := 10_000_000
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, now)
	assert_eq(plot.state.kind, PlotState.Kind.GROWING)
	var coins_before := eco.state.coins

	# Second plant_seed call on an already-Growing plot must no-op (crop/plot
	# mismatch guard doesn't apply here -- the EMPTY-state guard does).
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, now)
	assert_eq(plot.state.kind, PlotState.Kind.GROWING)
	assert_eq(eco.state.coins, coins_before)


func test_crop_plot_kind_mismatch_blocks_planting() -> void:
	var eco := GameEconomy.new()
	eco.state.coins = 10_000
	var plot: Plot = eco.state.plots[0]  # OPEN_FIELD
	# Saffron requires VERTICAL_FARM -- planting on an OPEN_FIELD plot must
	# silently no-op (per crop-economy.md's edge cases: "planting silently
	# no-ops if crop.requiredPlotKind != plot.kind").
	eco.plant_seed(plot.id, CropType.Kind.SAFFRON, 10_000_000)
	assert_eq(plot.state.kind, PlotState.Kind.EMPTY)
