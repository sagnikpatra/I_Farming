## Covers AgroPlantPicker's pure logic -- build_row_data() (3 host rows +
## Sandalwood, affordability and adjacency gating) -- extracted specifically
## so it's unit-testable independent of the scene tree (see
## agro_plant_picker.gd's header comment). Node construction/layout/styling
## is explicitly NOT covered here, per this project's testing standards.
extends GutTest


func test_build_row_data_lists_3_hosts_then_sandalwood_in_order() -> void:
	var rows := AgroPlantPicker.build_row_data(1_000_000, true)
	assert_eq(rows.size(), 4)
	assert_eq(rows[0]["host"], HostType.Kind.PIGEON_PEA)
	assert_eq(rows[1]["host"], HostType.Kind.NEEM)
	assert_eq(rows[2]["host"], HostType.Kind.ACACIA)
	assert_eq(rows[3]["kind"], "sandalwood")


func test_build_row_data_acacia_subtitle_mentions_shortened_grow_time() -> void:
	var rows := AgroPlantPicker.build_row_data(1_000_000, true)
	assert_eq(rows[2]["subtitle"], "Instant · shortens Sandalwood grow time")
	assert_eq(rows[0]["subtitle"], "Instant")


func test_build_row_data_host_affordability_reflects_coins() -> void:
	# Pigeon Pea=15, Neem=200, Acacia=350 -- 100 coins covers only the first.
	var rows := AgroPlantPicker.build_row_data(100, true)
	assert_true(rows[0]["enabled"])
	assert_false(rows[1]["enabled"])
	assert_false(rows[2]["enabled"])


func test_build_row_data_sandalwood_disabled_without_adjacent_host() -> void:
	var rows := AgroPlantPicker.build_row_data(1_000_000, false)
	assert_false(rows[3]["enabled"])
	assert_eq(rows[3]["subtitle"], "Needs an adjacent host plant")


func test_build_row_data_sandalwood_disabled_when_unaffordable_even_with_adjacent_host() -> void:
	var rows := AgroPlantPicker.build_row_data(0, true)
	assert_false(rows[3]["enabled"])


func test_build_row_data_sandalwood_enabled_when_affordable_and_adjacent() -> void:
	var sandalwood_def := GameData.crop_def(CropType.Kind.SANDALWOOD)
	var rows := AgroPlantPicker.build_row_data(sandalwood_def.seed_cost, true)
	assert_true(rows[3]["enabled"])
	assert_true(rows[3]["subtitle"].ends_with("· sells ₹%d" % sandalwood_def.base_sell_price))
