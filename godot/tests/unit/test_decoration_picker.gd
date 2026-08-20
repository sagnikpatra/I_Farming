## Covers DecorationPicker's pure logic -- build_row_data() (every
## DecorationType listed, affordability by coins) -- extracted specifically
## so it's unit-testable independent of the scene tree (see
## decoration_picker.gd's header comment). Node construction/layout/styling
## is explicitly NOT covered here, per this project's testing standards.
extends GutTest


func test_build_row_data_lists_every_decoration_type_in_declared_order() -> void:
	var rows := DecorationPicker.build_row_data(1_000_000)
	assert_eq(rows.size(), DecorationType.Kind.keys().size())
	for index in range(rows.size()):
		assert_eq(rows[index]["type"], index)


func test_build_row_data_all_affordable_with_plenty_of_coins() -> void:
	var rows := DecorationPicker.build_row_data(1_000_000)
	for row in rows:
		assert_true(row["affordable"])


func test_build_row_data_cheapest_only_affordable_with_few_coins() -> void:
	# Dirt Path is the cheapest at ₹10.
	var rows := DecorationPicker.build_row_data(10)
	var dirt_path_row = rows.filter(func(r): return r["type"] == DecorationType.Kind.DIRT_PATH)[0]
	assert_true(dirt_path_row["affordable"])
	var statue_row = rows.filter(func(r): return r["type"] == DecorationType.Kind.STATUE)[0]
	assert_false(statue_row["affordable"])


func test_build_row_data_zero_coins_returns_all_rows_unaffordable() -> void:
	var rows := DecorationPicker.build_row_data(0)
	for row in rows:
		assert_false(row["affordable"])
