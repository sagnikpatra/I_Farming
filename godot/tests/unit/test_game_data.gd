## Covers GameData's pure formulas and catalogue tables. TR references:
## TR-land-001 (land expansion cost), TR-farmhouse-* (level table),
## crop-economy.md's crop catalogue table, mandi-trading.md's demand-swing
## formula.
extends GutTest


func test_land_expansion_cost_at_starting_plot_count() -> void:
	# stepsBeyondStart = 0 -> 150 * 1.55^0 = 150
	assert_eq(GameData.land_expansion_cost(3), 150)


func test_land_expansion_cost_curve_is_marginal_and_increasing() -> void:
	# Hand-verified: 150*1.55^1=232.5->233, ^2=360.375->360, ^3=558.58->559
	assert_eq(GameData.land_expansion_cost(4), 233)
	assert_eq(GameData.land_expansion_cost(5), 360)
	assert_eq(GameData.land_expansion_cost(6), 559)


func test_land_expansion_cost_below_starting_plots_clamps_to_zero_steps() -> void:
	# Kotlin: stepsBeyondStart.coerceAtLeast(0) -- a count below STARTING_PLOTS
	# (3) must not produce a negative exponent.
	assert_eq(GameData.land_expansion_cost(0), 150)
	assert_eq(GameData.land_expansion_cost(2), 150)


func test_polyhouse_cost_halved_by_subsidy() -> void:
	assert_eq(GameData.polyhouse_cost(false), 35_000)
	assert_eq(GameData.polyhouse_cost(true), 17_500)


func test_subsidy_unlock_threshold() -> void:
	assert_false(GameData.is_subsidy_unlocked(24))
	assert_true(GameData.is_subsidy_unlocked(25))
	assert_true(GameData.is_subsidy_unlocked(1000))


func test_crop_catalogue_matches_gdd_table() -> void:
	# design/gdd/crop-economy.md's crop catalogue table, spot-checked across
	# all 5 plot kinds.
	var wheat := GameData.crop_def(CropType.Kind.WHEAT)
	assert_eq(wheat.seed_cost, 10)
	assert_eq(wheat.grow_seconds, 120)
	assert_eq(wheat.base_sell_price, 20)
	assert_eq(wheat.weather_risk_percent, 8)
	assert_eq(wheat.required_plot_kind, PlotKind.Kind.OPEN_FIELD)

	var paddy := GameData.crop_def(CropType.Kind.PADDY)
	assert_eq(paddy.weather_risk_percent, 12)

	var tomato := GameData.crop_def(CropType.Kind.TOMATO)
	assert_eq(tomato.weather_risk_percent, 15)

	var capsicum := GameData.crop_def(CropType.Kind.CAPSICUM)
	assert_eq(capsicum.seed_cost, 150)
	assert_eq(capsicum.base_sell_price, 650)
	assert_eq(capsicum.required_plot_kind, PlotKind.Kind.POLYHOUSE)

	var dutch_rose := GameData.crop_def(CropType.Kind.DUTCH_ROSE)
	assert_eq(dutch_rose.base_sell_price, 1_100)

	var sandalwood := GameData.crop_def(CropType.Kind.SANDALWOOD)
	assert_eq(sandalwood.seed_cost, 5_000)
	assert_eq(sandalwood.base_sell_price, 500_000)
	assert_eq(sandalwood.grow_seconds, 21 * 24 * 60 * 60)
	assert_eq(sandalwood.required_plot_kind, PlotKind.Kind.AGROFORESTRY)

	var makhana := GameData.crop_def(CropType.Kind.MAKHANA)
	assert_eq(makhana.base_sell_price, 1_800)
	assert_eq(makhana.required_plot_kind, PlotKind.Kind.AQUACULTURE)

	var pond_fish := GameData.crop_def(CropType.Kind.POND_FISH)
	assert_eq(pond_fish.base_sell_price, 900)

	var saffron := GameData.crop_def(CropType.Kind.SAFFRON)
	assert_eq(saffron.seed_cost, 800)
	assert_eq(saffron.base_sell_price, 3_500)
	assert_eq(saffron.required_plot_kind, PlotKind.Kind.VERTICAL_FARM)


func test_host_type_costs() -> void:
	assert_eq(GameData.host_type_def(HostType.Kind.PIGEON_PEA).cost, 15)
	assert_eq(GameData.host_type_def(HostType.Kind.NEEM).cost, 200)
	assert_eq(GameData.host_type_def(HostType.Kind.ACACIA).cost, 350)


func test_decoration_costs() -> void:
	assert_eq(GameData.decoration_type_def(DecorationType.Kind.POTTED_PLANT).cost, 50)
	assert_eq(GameData.decoration_type_def(DecorationType.Kind.STATUE).cost, 600)
	assert_eq(GameData.decoration_type_def(DecorationType.Kind.DIRT_PATH).cost, 10)


func test_farmhouse_level_table_matches_gdd() -> void:
	var lvl0 := GameData.farmhouse_level_def(0)
	assert_eq(lvl0.upgrade_cost, 0)
	assert_eq(lvl0.storage_capacity, 50)
	assert_eq(lvl0.growth_speed_bonus_percent, 0)
	assert_eq(lvl0.sell_price_bonus_percent, 0)

	var lvl7 := GameData.farmhouse_level_def(7)
	assert_eq(lvl7.upgrade_cost, 1_200_000)
	assert_eq(lvl7.storage_capacity, 2_000)
	assert_eq(lvl7.growth_speed_bonus_percent, 20)
	assert_eq(lvl7.sell_price_bonus_percent, 15)

	assert_eq(GameData.farmhouse_max_level(), 7)


func test_farmhouse_level_out_of_range_clamps_to_last_tier() -> void:
	# Mirrors Kotlin's FARMHOUSE_LEVELS.getOrElse(level) { .last() } --
	# defensive fallback, not a normal code path.
	assert_eq(GameData.farmhouse_level_def(99).level, 7)
	assert_eq(GameData.farmhouse_level_def(-1).level, 7)


func test_festival_rotation_matches_gdd() -> void:
	assert_eq(GameData.festival_def(0).display_name, "Makar Sankranti")
	assert_eq(GameData.festival_def(0).target_crop, CropType.Kind.PADDY)
	assert_eq(GameData.festival_def(1).display_name, "Pongal")
	assert_eq(GameData.festival_def(1).target_crop, CropType.Kind.PADDY)
	assert_eq(GameData.festival_def(2).display_name, "Baisakhi")
	assert_eq(GameData.festival_def(2).target_crop, CropType.Kind.WHEAT)
	# Wraps back to the first festival every 3 cycles.
	assert_eq(GameData.festival_def(3).display_name, "Makar Sankranti")
	assert_eq(GameData.festival_def(9).display_name, "Makar Sankranti")


func test_crops_for_plot_kind_open_field_returns_wheat_paddy_tomato_in_declaration_order() -> void:
	var crops := GameData.crops_for_plot_kind(PlotKind.Kind.OPEN_FIELD)
	assert_eq(crops, [CropType.Kind.WHEAT, CropType.Kind.PADDY, CropType.Kind.TOMATO])


func test_crops_for_plot_kind_polyhouse_returns_capsicum_and_dutch_rose() -> void:
	var crops := GameData.crops_for_plot_kind(PlotKind.Kind.POLYHOUSE)
	assert_eq(crops, [CropType.Kind.CAPSICUM, CropType.Kind.DUTCH_ROSE])


func test_crops_for_plot_kind_agroforestry_excludes_sandalwood() -> void:
	# Sandalwood's requiredPlotKind is AGROFORESTRY, but it has its own
	# dedicated entry point (plant_sandalwood()) -- plant_seed() rejects it
	# outright, so listing it in a seed picker would be a silently-dead row.
	assert_eq(GameData.crops_for_plot_kind(PlotKind.Kind.AGROFORESTRY), [])


func test_crops_for_plot_kind_aquaculture_returns_makhana_and_pond_fish() -> void:
	var crops := GameData.crops_for_plot_kind(PlotKind.Kind.AQUACULTURE)
	assert_eq(crops, [CropType.Kind.MAKHANA, CropType.Kind.POND_FISH])


func test_demand_modifier_percent_in_range() -> void:
	# -15..20 inclusive per crop-economy.md/mandi-trading.md (Kotlin's
	# nextInt(-15, 21) is upper-exclusive, so 36 possible values).
	for cycle in range(0, 50):
		var value := GameData.demand_modifier_percent(CropType.Kind.WHEAT, cycle)
		assert_true(value >= -15 and value <= 20, "demand modifier %d out of range for cycle %d" % [value, cycle])
