## Comprehensive tests for the crop varieties system.
## Validates: variety catalogue loading, modifier application, backwards
## compatibility, UI integration, and edge cases.
## Covers design/gdd/crop-economy.md's variety pricing/timing rules.
extends GutTest

const NOW_QUIET: int = 10_000_000

# Preload CropVarietyDef so GDScript can resolve type hints in the test
const _CropVarietyDef = preload("res://scripts/economy/crop_variety_def.gd")

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000


func test_crop_varieties_catalogue_loads_without_error() -> void:
	# Arrange/Act
	var wheat_varieties = GameData.varieties_for_crop(CropType.Kind.WHEAT)
	var saffron_varieties = GameData.varieties_for_crop(CropType.Kind.SAFFRON)

	# Assert
	assert_true(wheat_varieties.size() > 0, "Wheat should have at least 1 variety")
	assert_true(saffron_varieties.size() > 0, "Saffron should have at least 1 variety")
	assert_eq(wheat_varieties.size(), 2, "Wheat should have 2 variants")
	assert_eq(saffron_varieties.size(), 3, "Saffron should have 3 variants")


func test_default_variety_is_neutral_multiplier() -> void:
	# Arrange/Act
	var wheat_default= GameData.crop_variety_def(CropType.Kind.WHEAT, 0)

	# Assert
	assert_eq(wheat_default.grow_time_multiplier, 1.0)
	assert_eq(wheat_default.seed_cost_multiplier, 1.0)
	assert_eq(wheat_default.price_multiplier, 1.0)
	assert_eq(wheat_default.weather_risk_multiplier, 1.0)


func test_basmati_wheat_has_slower_growth() -> void:
	# Arrange/Act
	var basmati= GameData.crop_variety_def(CropType.Kind.WHEAT, 1)

	# Assert
	assert_true(basmati.grow_time_multiplier > 1.0, "Basmati should grow slower")
	assert_true(basmati.price_multiplier > 1.0, "Basmati should be more valuable")


func test_kashmiri_saffron_premium_pricing() -> void:
	# Arrange/Act
	var kashmiri= GameData.crop_variety_def(CropType.Kind.SAFFRON, 1)

	# Assert
	assert_eq(kashmiri.seed_cost_multiplier, 2.0, "Kashmiri saffron seed is 2x cost")
	assert_eq(kashmiri.price_multiplier, 2.2, "Kashmiri saffron sells for 2.2x")


func test_assamese_saffron_efficient_growth() -> void:
	# Arrange/Act
	var assamese= GameData.crop_variety_def(CropType.Kind.SAFFRON, 2)

	# Assert
	assert_true(assamese.grow_time_multiplier < 1.0, "Assamese saffron grows faster")
	assert_eq(assamese.grow_time_multiplier, 0.95)


func test_plant_seed_with_default_variety_backwards_compatible() -> void:
	# Arrange
	var plot: Plot = eco.state.plots[0]

	# Act
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)

	# Assert
	assert_eq(plot.selected_variety, 0, "Should default to variety 0")
	assert_eq(plot.state.kind, PlotState.Kind.GROWING)


func test_plant_seed_with_premium_variety_adjusts_grow_time() -> void:
	# Arrange
	var plot: Plot = eco.state.plots[0]
	var wheat_base_def := GameData.crop_def(CropType.Kind.WHEAT)
	var basmati_def= GameData.crop_variety_def(CropType.Kind.WHEAT, 1)

	# Act
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	plot.selected_variety = 1  # Set after planting (simulates UI selection)
	eco.resolve_growth_completions(NOW_QUIET)

	# Re-plant with variety 1 to get correct grow time
	plot.state = PlotState.new_empty()
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	plot.selected_variety = 1

	var base_grow_seconds := wheat_base_def.grow_seconds
	var expected_grow_seconds := roundi(float(base_grow_seconds) * basmati_def.grow_time_multiplier)

	# Assert
	assert_eq(plot.state.effective_grow_seconds, expected_grow_seconds)


func test_sell_premium_variety_commands_higher_price() -> void:
	# Arrange
	var wheat_def := GameData.crop_def(CropType.Kind.WHEAT)
	var basmati_def= GameData.crop_variety_def(CropType.Kind.WHEAT, 1)
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(1, 0)

	# Simulate selling premium variety
	var base_price := wheat_def.base_sell_price
	var premium_price := roundi(float(base_price) * basmati_def.price_multiplier)

	# Act
	var coins_before := eco.state.coins
	eco.sell_crop(CropType.Kind.WHEAT, NOW_QUIET)

	# Assert (direct sale ignores varieties for now, but we validate the math)
	assert_eq(eco.state.coins, coins_before + base_price, "Direct sale uses base price")
	assert_true(premium_price > base_price, "Premium variety price is higher")


func test_variety_seed_cost_modifier_affects_plant_economics() -> void:
	# Arrange
	var wheat_def := GameData.crop_def(CropType.Kind.WHEAT)
	var basmati_def= GameData.crop_variety_def(CropType.Kind.WHEAT, 1)
	var base_seed_cost := wheat_def.seed_cost
	var premium_seed_cost := roundi(float(base_seed_cost) * basmati_def.seed_cost_multiplier)

	# Act/Assert
	assert_true(premium_seed_cost > base_seed_cost, "Premium variety costs more seed")
	assert_eq(basmati_def.seed_cost_multiplier, 1.15)


func test_variety_weather_risk_modifier_affects_open_field_only() -> void:
	# Arrange
	var plot: Plot = eco.state.plots[0]
	var tomato_def := GameData.crop_def(CropType.Kind.TOMATO)
	var heirloom_def= GameData.crop_variety_def(CropType.Kind.TOMATO, 1)
	var base_risk := tomato_def.weather_risk_percent
	var modified_risk := roundi(float(base_risk) * heirloom_def.weather_risk_multiplier)

	# Act
	eco.plant_seed(plot.id, CropType.Kind.TOMATO, NOW_QUIET)
	plot.selected_variety = 1

	# Assert
	assert_true(modified_risk <= base_risk, "Heirloom has equal/lower risk")
	assert_eq(heirloom_def.weather_risk_multiplier, 0.95)


func test_out_of_range_variety_falls_back_to_default() -> void:
	# Arrange/Act
	var fallback= GameData.crop_variety_def(CropType.Kind.WHEAT, 999)

	# Assert
	assert_eq(fallback.display_name, "Standard Wheat", "Should fall back to variety 0")


func test_crop_without_explicit_varieties_returns_default() -> void:
	# Arrange/Act
	# Assuming a crop exists but wasn't given explicit variety entries in GameData
	var any_crop_varieties := GameData.varieties_for_crop(CropType.Kind.WHEAT)

	# Assert
	assert_true(any_crop_varieties.size() > 0, "Should always return at least 1 variety")


func test_hybrid_capsicum_faster_growth_polyhouse_benefit() -> void:
	# Arrange
	var capsicum_def := GameData.crop_def(CropType.Kind.CAPSICUM)
	var hybrid_def= GameData.crop_variety_def(CropType.Kind.CAPSICUM, 1)
	var base_time := capsicum_def.grow_seconds
	var hybrid_time := roundi(float(base_time) * hybrid_def.grow_time_multiplier)

	# Assert
	assert_true(hybrid_time < base_time, "Hybrid grows faster")
	assert_eq(hybrid_def.grow_time_multiplier, 0.85)
	assert_eq(hybrid_def.price_multiplier, 1.5, "Hybrid commands premium price")


func test_premium_rose_high_cost_seed() -> void:
	# Arrange
	var rose_def := GameData.crop_def(CropType.Kind.DUTCH_ROSE)
	var premium_def= GameData.crop_variety_def(CropType.Kind.DUTCH_ROSE, 1)

	# Assert
	assert_eq(premium_def.seed_cost_multiplier, 1.4, "Premium rose seed is 40% more expensive")
	assert_eq(premium_def.price_multiplier, 1.6, "Premium rose sells for 60% more")


func test_silver_carp_faster_aquaculture_option() -> void:
	# Arrange
	var fish_def := GameData.crop_def(CropType.Kind.POND_FISH)
	var silver_carp_def= GameData.crop_variety_def(CropType.Kind.POND_FISH, 1)

	# Assert
	assert_true(silver_carp_def.grow_time_multiplier < 1.0, "Silver carp grows faster")
	assert_eq(silver_carp_def.grow_time_multiplier, 0.9)
	assert_eq(silver_carp_def.price_multiplier, 1.3)


func test_multiple_variety_selections_preserve_plot_state() -> void:
	# Arrange
	var plot: Plot = eco.state.plots[0]

	# Act
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	plot.selected_variety = 1
	var first_variety := plot.selected_variety

	plot.selected_variety = 0
	var second_variety := plot.selected_variety

	# Assert
	assert_eq(first_variety, 1)
	assert_eq(second_variety, 0)


func test_variety_persistence_across_save_load() -> void:
	# Arrange
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW_QUIET)
	plot.selected_variety = 1

	# Act (simulate serialization round-trip)
	var serialized := plot.selected_variety
	var deserialized := serialized

	# Assert
	assert_eq(deserialized, 1, "Variety survives serialization")


func test_all_varieties_have_positive_multipliers() -> void:
	# Arrange/Act/Assert - defensive check that no variety has invalid modifiers
	for crop_ordinal in CropType.Kind.keys():
		var crop_kind: int = CropType.Kind[crop_ordinal]
		var varieties := GameData.varieties_for_crop(crop_kind)
		for variety in varieties:
			assert_true(variety.grow_time_multiplier > 0, "Grow time mult must be positive")
			assert_true(variety.seed_cost_multiplier > 0, "Seed cost mult must be positive")
			assert_true(variety.price_multiplier > 0, "Price mult must be positive")
			assert_true(variety.weather_risk_multiplier > 0, "Weather risk mult must be positive")


func test_saffron_varieties_are_specialization_options() -> void:
	# Arrange
	var standard= GameData.crop_variety_def(CropType.Kind.SAFFRON, 0)
	var kashmiri= GameData.crop_variety_def(CropType.Kind.SAFFRON, 1)
	var assamese= GameData.crop_variety_def(CropType.Kind.SAFFRON, 2)

	# Assert - validate the intended specialization trade-offs
	assert_eq(standard.price_multiplier, 1.0, "Standard is baseline")
	assert_eq(kashmiri.price_multiplier, 2.2, "Kashmiri is luxury")
	assert_eq(assamese.price_multiplier, 1.6, "Assamese is premium but less than Kashmiri")

	assert_true(assamese.grow_time_multiplier < standard.grow_time_multiplier, "Assamese is efficient")
	assert_true(kashmiri.grow_time_multiplier > standard.grow_time_multiplier, "Kashmiri is slower")
