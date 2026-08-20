## Covers MandiTab's pure logic -- is_crop_relevant()/relevant_crops() (which
## crops the player's current unlocks make sellable at the Mandi),
## trend_arrow() (the ▲/―/▼ glyph), and build_row_data() (held units + live
## price/forecast per row) -- extracted specifically so they're unit-testable
## independent of the scene tree (see mandi_tab.gd's header comment). Node
## construction/layout/styling is explicitly NOT covered here, per this
## project's testing standards (.claude/docs/coding-standards.md: "Visual/
## Feel" stories get screenshot evidence, not automated tests).
extends GutTest

const NOW_QUIET: int = 10_000_000

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()


func test_is_crop_relevant_open_field_crop_always_relevant() -> void:
	var wheat := GameData.crop_def(CropType.Kind.WHEAT)
	assert_true(MandiTab.is_crop_relevant(wheat, false, false, false, false))


func test_is_crop_relevant_polyhouse_crop_gated_by_polyhouse_unlock() -> void:
	var capsicum := GameData.crop_def(CropType.Kind.CAPSICUM)
	assert_false(MandiTab.is_crop_relevant(capsicum, false, false, false, false))
	assert_true(MandiTab.is_crop_relevant(capsicum, true, false, false, false))


func test_is_crop_relevant_agroforestry_crop_gated_by_agroforestry_unlock() -> void:
	# Sandalwood is an ordinary sellable crop at the Mandi once Agroforestry
	# is unlocked, unlike the Seed Picker which deliberately excludes it --
	# see mandi_tab.gd's header comment on why this is a separate function
	# from GameData.crops_for_plot_kind().
	var sandalwood := GameData.crop_def(CropType.Kind.SANDALWOOD)
	assert_false(MandiTab.is_crop_relevant(sandalwood, false, false, false, false))
	assert_true(MandiTab.is_crop_relevant(sandalwood, false, true, false, false))


func test_is_crop_relevant_aquaculture_crop_gated_by_aquaculture_unlock() -> void:
	var pond_fish := GameData.crop_def(CropType.Kind.POND_FISH)
	assert_false(MandiTab.is_crop_relevant(pond_fish, false, false, false, false))
	assert_true(MandiTab.is_crop_relevant(pond_fish, false, false, true, false))


func test_is_crop_relevant_vertical_farm_crop_gated_by_vertical_farm_unlock() -> void:
	var saffron := GameData.crop_def(CropType.Kind.SAFFRON)
	assert_false(MandiTab.is_crop_relevant(saffron, false, false, false, false))
	assert_true(MandiTab.is_crop_relevant(saffron, false, false, false, true))


func test_relevant_crops_with_no_unlocks_returns_only_open_field_crops_in_order() -> void:
	var crops := MandiTab.relevant_crops(false, false, false, false)
	assert_eq(crops, [CropType.Kind.WHEAT, CropType.Kind.PADDY, CropType.Kind.TOMATO])


func test_relevant_crops_with_every_unlock_includes_every_crop_in_declared_order() -> void:
	var crops := MandiTab.relevant_crops(true, true, true, true)
	assert_eq(crops, [
		CropType.Kind.WHEAT, CropType.Kind.PADDY, CropType.Kind.TOMATO,
		CropType.Kind.CAPSICUM, CropType.Kind.DUTCH_ROSE, CropType.Kind.SANDALWOOD,
		CropType.Kind.MAKHANA, CropType.Kind.POND_FISH, CropType.Kind.SAFFRON,
	])


func test_trend_arrow_above_102_percent_is_up() -> void:
	assert_eq(MandiTab.trend_arrow(103), "▲")


func test_trend_arrow_below_98_percent_is_down() -> void:
	assert_eq(MandiTab.trend_arrow(97), "▼")


func test_trend_arrow_boundaries_read_as_flat() -> void:
	# Both boundary values themselves (98 and 102) read as flat -- matches
	# MandiUi.kt's MandiCropRow `when` block exactly (pct > 102 / pct < 98).
	assert_eq(MandiTab.trend_arrow(98), "―")
	assert_eq(MandiTab.trend_arrow(102), "―")
	assert_eq(MandiTab.trend_arrow(100), "―")


func test_build_row_data_reports_zero_held_for_crop_never_harvested() -> void:
	var rows := MandiTab.build_row_data(eco, NOW_QUIET)
	var wheat_row = rows.filter(func(r): return r["crop"] == CropType.Kind.WHEAT)[0]
	assert_eq(wheat_row["held"], 0)


func test_build_row_data_reports_held_units_from_inventory() -> void:
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(4, 1)
	var rows := MandiTab.build_row_data(eco, NOW_QUIET)
	var wheat_row = rows.filter(func(r): return r["crop"] == CropType.Kind.WHEAT)[0]
	assert_eq(wheat_row["held"], 5)


func test_build_row_data_pct_and_trend_match_mandi_price_multiplier() -> void:
	var rows := MandiTab.build_row_data(eco, NOW_QUIET)
	var wheat_row = rows.filter(func(r): return r["crop"] == CropType.Kind.WHEAT)[0]
	var expected_pct: int = roundi(eco.mandi_price_multiplier(CropType.Kind.WHEAT, NOW_QUIET) * 100)
	assert_eq(wheat_row["pct"], expected_pct)
	assert_eq(wheat_row["trend"], MandiTab.trend_arrow(expected_pct))


func test_build_row_data_forecast_matches_mandi_forecast_percent() -> void:
	var rows := MandiTab.build_row_data(eco, NOW_QUIET)
	var wheat_row = rows.filter(func(r): return r["crop"] == CropType.Kind.WHEAT)[0]
	assert_eq(wheat_row["forecast_percent"], eco.mandi_forecast_percent(CropType.Kind.WHEAT, NOW_QUIET))


func test_build_row_data_is_graded_true_only_for_non_open_field_crops() -> void:
	var rows := MandiTab.build_row_data(eco, NOW_QUIET)
	var wheat_row = rows.filter(func(r): return r["crop"] == CropType.Kind.WHEAT)[0]
	assert_false(wheat_row["is_graded"])

	eco.state.has_polyhouse = true
	var rows_with_polyhouse := MandiTab.build_row_data(eco, NOW_QUIET)
	var capsicum_row = rows_with_polyhouse.filter(func(r): return r["crop"] == CropType.Kind.CAPSICUM)[0]
	assert_true(capsicum_row["is_graded"])


func test_build_row_data_respects_current_unlock_flags() -> void:
	var rows := MandiTab.build_row_data(eco, NOW_QUIET)
	assert_eq(rows.size(), 3)  # Only the 3 open-field crops with everything else locked.

	eco.state.has_polyhouse = true
	eco.state.has_agroforestry = true
	var rows_unlocked := MandiTab.build_row_data(eco, NOW_QUIET)
	# + Capsicum, Dutch Rose (Polyhouse), + Sandalwood (Agroforestry) = 6.
	assert_eq(rows_unlocked.size(), 6)
