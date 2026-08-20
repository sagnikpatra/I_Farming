## Covers SeedPicker's pure logic -- build_row_data() (crop list + affordability)
## and format_crop_details() (the "Xm grow · sells ₹Y" row text) -- extracted
## specifically so they're unit-testable independent of the scene tree (see
## seed_picker.gd's header comment). Node construction/layout/styling is
## explicitly NOT covered here, per this project's testing standards
## (.claude/docs/coding-standards.md: "Visual/Feel" stories get screenshot
## evidence, not automated tests).
extends GutTest


func test_build_row_data_open_field_returns_wheat_paddy_tomato_in_order() -> void:
	var rows := SeedPicker.build_row_data(PlotKind.Kind.OPEN_FIELD, 1000)
	assert_eq(rows.size(), 3)
	assert_eq(rows[0]["crop"], CropType.Kind.WHEAT)
	assert_eq(rows[1]["crop"], CropType.Kind.PADDY)
	assert_eq(rows[2]["crop"], CropType.Kind.TOMATO)


func test_build_row_data_marks_rows_affordable_when_coins_cover_seed_cost() -> void:
	# Wheat=10, Paddy=30, Tomato=60 -- 1000 coins covers all three.
	var rows := SeedPicker.build_row_data(PlotKind.Kind.OPEN_FIELD, 1000)
	for row in rows:
		assert_true(row["affordable"], "crop %s should be affordable at 1000 coins" % row["crop"])


func test_build_row_data_marks_rows_unaffordable_below_seed_cost() -> void:
	# 15 coins covers Wheat (10) but not Paddy (30) or Tomato (60).
	var rows := SeedPicker.build_row_data(PlotKind.Kind.OPEN_FIELD, 15)
	assert_true(rows[0]["affordable"])  # Wheat
	assert_false(rows[1]["affordable"])  # Paddy
	assert_false(rows[2]["affordable"])  # Tomato


func test_build_row_data_affordability_boundary_is_inclusive() -> void:
	# Exactly Wheat's seed cost (10) should count as affordable.
	var rows := SeedPicker.build_row_data(PlotKind.Kind.OPEN_FIELD, 10)
	assert_true(rows[0]["affordable"])


func test_build_row_data_excludes_sandalwood_for_agroforestry() -> void:
	var rows := SeedPicker.build_row_data(PlotKind.Kind.AGROFORESTRY, 1_000_000)
	assert_eq(rows.size(), 0)


func test_build_row_data_zero_coins_returns_all_rows_unaffordable() -> void:
	var rows := SeedPicker.build_row_data(PlotKind.Kind.POLYHOUSE, 0)
	assert_eq(rows.size(), 2)
	for row in rows:
		assert_false(row["affordable"])


func test_format_crop_details_matches_kotlin_original_format() -> void:
	var wheat := GameData.crop_def(CropType.Kind.WHEAT)
	# Wheat: 120s grow, sells 20 -> "2m grow · sells ₹20"
	assert_eq(SeedPicker.format_crop_details(wheat), "2m grow · sells ₹20")


func test_format_crop_details_truncates_partial_minutes_like_gdscript_int_division() -> void:
	# A synthetic 90s grow time -- GDScript's int `/` truncates toward zero,
	# same as Kotlin's Int division in the original ("${crop.growSeconds / 60}m").
	var synthetic := CropDef.new("Test Crop", "🌱", 5, 90, 10, 0, PlotKind.Kind.OPEN_FIELD)
	assert_eq(SeedPicker.format_crop_details(synthetic), "1m grow · sells ₹10")
