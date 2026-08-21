## Covers Hud's pure formatting/display-building logic -- the two functions
## extracted specifically so they're unit-testable independent of the scene
## tree (see hud.gd's header comment, and its build_inventory_display()/
## format_liveops_label() doc comments on why they're not underscore-
## prefixed). Node construction/layout/styling is explicitly NOT covered
## here, per this project's testing standards (.claude/docs/coding-standards.md:
## "Visual/Feel" stories get screenshot evidence, not automated tests).
extends GutTest


func test_inventory_display_skips_zero_stock_crops() -> void:
	var inventory := {
		CropType.Kind.WHEAT: CropStock.new(3, 0),
		CropType.Kind.TOMATO: CropStock.new(0, 0),
	}
	var display := Hud.build_inventory_display(inventory)
	assert_eq(display.size(), 1)
	assert_eq(display[0]["emoji"], GameData.crop_def(CropType.Kind.WHEAT).emoji)
	assert_eq(display[0]["count"], 3)


func test_inventory_display_counts_normal_plus_damaged() -> void:
	var inventory := {CropType.Kind.PADDY: CropStock.new(2, 1)}
	var display := Hud.build_inventory_display(inventory)
	assert_eq(display[0]["count"], 3)


func test_inventory_display_empty_inventory_returns_empty_array() -> void:
	assert_eq(Hud.build_inventory_display({}).size(), 0)


func test_inventory_display_preserves_dictionary_iteration_order() -> void:
	var inventory := {
		CropType.Kind.TOMATO: CropStock.new(1, 0),
		CropType.Kind.WHEAT: CropStock.new(1, 0),
	}
	var display := Hud.build_inventory_display(inventory)
	assert_eq(display[0]["emoji"], GameData.crop_def(CropType.Kind.TOMATO).emoji)
	assert_eq(display[1]["emoji"], GameData.crop_def(CropType.Kind.WHEAT).emoji)


func test_liveops_label_monsoon_only() -> void:
	var festival := GameData.festival_def(0)
	assert_eq(Hud.format_liveops_label(true, false, festival), "🌧️ Monsoon Season")


func test_liveops_label_festival_only() -> void:
	var festival := GameData.festival_def(0)
	var expected := "%s %s" % [festival.emoji, festival.display_name]
	assert_eq(Hud.format_liveops_label(false, true, festival), expected)


func test_liveops_label_monsoon_and_festival_combined() -> void:
	var festival := GameData.festival_def(0)
	var expected := "🌧️ Monsoon · %s %s" % [festival.emoji, festival.display_name]
	assert_eq(Hud.format_liveops_label(true, true, festival), expected)


func test_liveops_label_neither_active_falls_back_to_daily_tasks() -> void:
	# design/gdd/gems-daily-tasks.md -- the banner is now always visible
	# (Daily Tasks has no active/inactive window), so this is the fallback
	# text rather than an empty "hide the banner" signal.
	var festival := GameData.festival_def(0)
	assert_eq(Hud.format_liveops_label(false, false, festival), "📅 Daily Tasks")


func test_liveops_label_chanda_awaiting_takes_priority_over_monsoon_and_festival() -> void:
	var festival := GameData.festival_def(0)
	var chanda := GameData.chanda_festival_def(0)
	var expected := "%s %s chanda visitor" % [chanda.emoji, chanda.display_name]
	assert_eq(Hud.format_liveops_label(true, true, festival, true, chanda), expected)


func test_liveops_label_chanda_not_awaiting_falls_back_to_monsoon_and_festival() -> void:
	var festival := GameData.festival_def(0)
	var expected := "🌧️ Monsoon · %s %s" % [festival.emoji, festival.display_name]
	assert_eq(Hud.format_liveops_label(true, true, festival, false, null), expected)
