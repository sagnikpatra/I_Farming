## Covers FarmhouseTab's pure logic -- build_view_data() (current/next tier
## lookup, max-level detection, storage usage+progress) -- extracted
## specifically so it's unit-testable independent of the scene tree (see
## farmhouse_tab.gd's header comment). Node construction/layout/styling is
## explicitly NOT covered here, per this project's testing standards
## (.claude/docs/coding-standards.md: "Visual/Feel" stories get screenshot
## evidence, not automated tests).
extends GutTest

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()


func test_view_data_at_level_zero_reports_current_and_next_tier() -> void:
	var data := FarmhouseTab.build_view_data(eco)
	assert_eq((data["current"] as FarmhouseLevelDef).level, 0)
	assert_false(data["is_max_level"])
	assert_eq((data["next"] as FarmhouseLevelDef).level, 1)


func test_view_data_next_tier_matches_game_data_lookup() -> void:
	eco.state.farmhouse_level = 3
	var data := FarmhouseTab.build_view_data(eco)
	var expected_next := GameData.farmhouse_level_def(4)
	assert_eq((data["next"] as FarmhouseLevelDef).level, expected_next.level)
	assert_eq((data["next"] as FarmhouseLevelDef).upgrade_cost, expected_next.upgrade_cost)


func test_view_data_at_max_level_reports_no_next_tier() -> void:
	eco.state.farmhouse_level = GameData.farmhouse_max_level()
	var data := FarmhouseTab.build_view_data(eco)
	assert_true(data["is_max_level"])
	assert_null(data["next"])


func test_view_data_storage_used_sums_normal_and_damaged_across_crops() -> void:
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(3, 2)
	eco.state.inventory[CropType.Kind.PADDY] = CropStock.new(1, 0)
	var data := FarmhouseTab.build_view_data(eco)
	assert_eq(data["storage_used"], 6)


func test_view_data_storage_cap_reflects_current_level() -> void:
	eco.state.farmhouse_level = 7
	var data := FarmhouseTab.build_view_data(eco)
	assert_eq(data["storage_cap"], 2_000)


func test_view_data_storage_progress_is_fraction_of_capacity() -> void:
	# Level 0 capacity is 50; 25 units held -> exactly half full.
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(25, 0)
	var data := FarmhouseTab.build_view_data(eco)
	assert_almost_eq(data["storage_progress"], 0.5, 0.0001)


func test_view_data_storage_progress_clamps_to_one_when_over_capacity() -> void:
	# Storage can end up over-full transiently (e.g. a level-down edge case
	# that doesn't otherwise occur in this strictly-ascending progression) --
	# the progress bar must never read above 100%.
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(999, 0)
	var data := FarmhouseTab.build_view_data(eco)
	assert_eq(data["storage_progress"], 1.0)
