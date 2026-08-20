## Covers VillageSnapshotMapper.build(): the pure GameState -> Array[ZoneFixture]
## translation that replaced VillageFixtureData's old hardcoded 3-zone fixture
## (see village_snapshot_mapper.gd's header for the full zone-layout table).
## Every test here drives state through GameEconomy's real buy_*/plant_*
## methods (not hand-faked plot counts) so this suite can't silently drift
## from game_economy.gd's actual behavior.
extends GutTest

const NOW: int = 10_000_000

const VILLAGE_BOARD_SCENE: PackedScene = preload("res://scenes/village_board/village_board.tscn")

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000_000


func _zone_by_id(zones: Array[ZoneFixture], id: String) -> ZoneFixture:
	for zone in zones:
		if zone.id == id:
			return zone
	return null


func _plot_with_id(zone: ZoneFixture, plot_id: int) -> PlotFixture:
	for plot in zone.plots:
		if plot.plot_id == plot_id:
			return plot
	return null


func _agro_plots() -> Array[Plot]:
	var matching: Array[Plot] = []
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.AGROFORESTRY:
			matching.append(p)
	return matching


# --- 1. Default zone anchors on a fresh GameState -----------------------------------

func test_farmhouse_default_anchor_and_footprint_with_no_plots() -> void:
	var zones := VillageSnapshotMapper.build(eco.state)
	var farmhouse := _zone_by_id(zones, "farmhouse")
	assert_not_null(farmhouse)
	assert_eq(farmhouse.tile_col, 0)
	assert_eq(farmhouse.tile_row, 0)
	assert_eq(farmhouse.tile_width, 2)
	assert_eq(farmhouse.tile_depth, 2)
	assert_true(farmhouse.plots.is_empty())


func test_open_field_default_layout_has_starting_plots_plus_one_ghost() -> void:
	var zones := VillageSnapshotMapper.build(eco.state)
	var open_field := _zone_by_id(zones, "open_field")
	assert_not_null(open_field)
	assert_false(open_field.has_building)
	# 3 starting plots at (2,0) (3,0) (4,0) -- open_field's anchor is (2,0),
	# 4 columns wide -- plus one GHOST at the next free slot (5,0), since
	# 3 < GameData.MAX_PLOTS.
	assert_eq(open_field.plots.size(), GameData.STARTING_PLOTS + 1)
	assert_eq(open_field.plots[0].tile_col, 2)
	assert_eq(open_field.plots[0].tile_row, 0)
	assert_eq(open_field.plots[1].tile_col, 3)
	assert_eq(open_field.plots[2].tile_col, 4)
	var ghost := open_field.plots[GameData.STARTING_PLOTS]
	assert_eq(ghost.lifecycle, PlotFixture.Lifecycle.GHOST)
	assert_eq(ghost.tile_col, 5)
	assert_eq(ghost.tile_row, 0)


func test_polyhouse_default_anchor_and_footprint() -> void:
	var zones := VillageSnapshotMapper.build(eco.state)
	var polyhouse := _zone_by_id(zones, "polyhouse")
	assert_not_null(polyhouse)
	assert_eq(polyhouse.tile_col, 6)
	assert_eq(polyhouse.tile_row, 0)
	assert_eq(polyhouse.tile_width, 2)
	assert_eq(polyhouse.tile_depth, 2)


# --- 2. Custom anchor overrides a draggable zone's default, plots shift too --------

func test_custom_anchor_moves_polyhouse_zone_and_its_plots() -> void:
	eco.state.zone_layout["polyhouse"] = ZoneAnchor.new(1.0, 1.0)
	eco.buy_polyhouse()
	var zones := VillageSnapshotMapper.build(eco.state)
	var polyhouse := _zone_by_id(zones, "polyhouse")
	assert_eq(polyhouse.tile_col, 1)
	assert_eq(polyhouse.tile_row, 1)
	assert_false(polyhouse.plots.is_empty())
	# First plot: col = anchor.x + 0%2 = 1, row = anchor.y + 2 + 0/2 = 3.
	assert_eq(polyhouse.plots[0].tile_col, 1)
	assert_eq(polyhouse.plots[0].tile_row, 3)


# --- 3. open_field is never draggable -----------------------------------------------

func test_open_field_ignores_a_zone_layout_entry() -> void:
	eco.state.zone_layout["open_field"] = ZoneAnchor.new(5.0, 5.0)
	var zones := VillageSnapshotMapper.build(eco.state)
	var open_field := _zone_by_id(zones, "open_field")
	assert_eq(open_field.tile_col, 2)
	assert_eq(open_field.tile_row, 0)
	assert_eq(open_field.plots[0].tile_col, 2)
	assert_eq(open_field.plots[0].tile_row, 0)


# --- 4. Locked-zone-hides-its-plots (gated on the flag, not plot presence) ---------

func test_polyhouse_plots_present_once_unlocked() -> void:
	eco.buy_polyhouse()
	var zones := VillageSnapshotMapper.build(eco.state)
	var polyhouse := _zone_by_id(zones, "polyhouse")
	assert_eq(polyhouse.plots.size(), GameData.POLYHOUSE_PLOT_COUNT)


func test_polyhouse_plots_hidden_while_locked_even_with_matching_plots_in_state() -> void:
	eco.state.plots.append(Plot.new(9001, PlotKind.Kind.POLYHOUSE))
	assert_false(eco.state.has_polyhouse)
	var zones := VillageSnapshotMapper.build(eco.state)
	var polyhouse := _zone_by_id(zones, "polyhouse")
	assert_true(polyhouse.plots.is_empty())


func test_agroforestry_plots_present_once_unlocked() -> void:
	eco.buy_agroforestry()
	var zones := VillageSnapshotMapper.build(eco.state)
	var agroforestry := _zone_by_id(zones, "agroforestry")
	assert_eq(agroforestry.plots.size(), GameData.AGROFORESTRY_GRID_SIZE * GameData.AGROFORESTRY_GRID_SIZE)


func test_agroforestry_plots_hidden_while_locked_even_with_matching_plots_in_state() -> void:
	var plot := Plot.new(9002, PlotKind.Kind.AGROFORESTRY)
	plot.agro_row = 0
	plot.agro_col = 0
	eco.state.plots.append(plot)
	assert_false(eco.state.has_agroforestry)
	var zones := VillageSnapshotMapper.build(eco.state)
	var agroforestry := _zone_by_id(zones, "agroforestry")
	assert_true(agroforestry.plots.is_empty())


func test_aquaculture_plots_present_once_unlocked() -> void:
	eco.buy_aquaculture()
	var zones := VillageSnapshotMapper.build(eco.state)
	var aquaculture := _zone_by_id(zones, "aquaculture")
	assert_eq(aquaculture.plots.size(), GameData.AQUACULTURE_PLOT_COUNT)


func test_aquaculture_plots_hidden_while_locked_even_with_matching_plots_in_state() -> void:
	eco.state.plots.append(Plot.new(9003, PlotKind.Kind.AQUACULTURE))
	assert_false(eco.state.has_aquaculture)
	var zones := VillageSnapshotMapper.build(eco.state)
	var aquaculture := _zone_by_id(zones, "aquaculture")
	assert_true(aquaculture.plots.is_empty())


func test_vertical_farm_plots_present_once_unlocked() -> void:
	eco.buy_vertical_farm()
	var zones := VillageSnapshotMapper.build(eco.state)
	var vertical_farm := _zone_by_id(zones, "vertical_farm")
	assert_eq(vertical_farm.plots.size(), GameData.VERTICAL_FARM_PLOT_COUNT)


func test_vertical_farm_plots_hidden_while_locked_even_with_matching_plots_in_state() -> void:
	eco.state.plots.append(Plot.new(9004, PlotKind.Kind.VERTICAL_FARM))
	assert_false(eco.state.has_vertical_farm)
	var zones := VillageSnapshotMapper.build(eco.state)
	var vertical_farm := _zone_by_id(zones, "vertical_farm")
	assert_true(vertical_farm.plots.is_empty())


# --- 5. PlotState.Kind -> PlotFixture.Lifecycle, every variant ----------------------

func test_empty_plot_maps_to_empty_lifecycle() -> void:
	var plot: Plot = eco.state.plots[0]
	var zones := VillageSnapshotMapper.build(eco.state)
	var open_field := _zone_by_id(zones, "open_field")
	var fixture := _plot_with_id(open_field, plot.id)
	assert_not_null(fixture)
	assert_eq(fixture.lifecycle, PlotFixture.Lifecycle.EMPTY)


func test_growing_plot_maps_to_growing_lifecycle() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW)
	var zones := VillageSnapshotMapper.build(eco.state)
	var open_field := _zone_by_id(zones, "open_field")
	var fixture := _plot_with_id(open_field, plot.id)
	assert_not_null(fixture)
	assert_eq(fixture.lifecycle, PlotFixture.Lifecycle.GROWING)


func test_ready_to_harvest_plot_maps_to_ready_to_harvest_lifecycle() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW)
	eco.resolve_growth_completions(NOW + 121 * 1000)  # Wheat grows in 120s.
	assert_eq(plot.state.kind, PlotState.Kind.READY_TO_HARVEST)
	var zones := VillageSnapshotMapper.build(eco.state)
	var open_field := _zone_by_id(zones, "open_field")
	var fixture := _plot_with_id(open_field, plot.id)
	assert_not_null(fixture)
	assert_eq(fixture.lifecycle, PlotFixture.Lifecycle.READY_TO_HARVEST)


# --- 6. Agroforestry host_occupied ---------------------------------------------------

func test_agroforestry_host_occupied_true_only_for_the_hosted_plot() -> void:
	eco.buy_agroforestry()
	var agro_plots := _agro_plots()
	eco.plant_host(agro_plots[0].id, HostType.Kind.PIGEON_PEA)
	var zones := VillageSnapshotMapper.build(eco.state)
	var agroforestry := _zone_by_id(zones, "agroforestry")
	var hosted := _plot_with_id(agroforestry, agro_plots[0].id)
	var unhosted := _plot_with_id(agroforestry, agro_plots[1].id)
	assert_not_null(hosted)
	assert_not_null(unhosted)
	assert_true(hosted.host_occupied)
	assert_false(unhosted.host_occupied)


# --- 7. Aquaculture is_water -----------------------------------------------------------

func test_every_aquaculture_plot_is_tinted_as_water() -> void:
	eco.buy_aquaculture()
	var zones := VillageSnapshotMapper.build(eco.state)
	var aquaculture := _zone_by_id(zones, "aquaculture")
	assert_eq(aquaculture.plots.size(), GameData.AQUACULTURE_PLOT_COUNT)
	for plot in aquaculture.plots:
		assert_true(plot.is_water)


# --- 8. Open-field ghost tile appears only while count < MAX_PLOTS ------------------

func test_open_field_ghost_tile_present_below_max_plots() -> void:
	var zones := VillageSnapshotMapper.build(eco.state)
	var open_field := _zone_by_id(zones, "open_field")
	var ghost_count := 0
	for plot in open_field.plots:
		if plot.lifecycle == PlotFixture.Lifecycle.GHOST:
			ghost_count += 1
	assert_eq(ghost_count, 1)


func test_open_field_ghost_tile_absent_once_fully_expanded() -> void:
	var expansions_needed := GameData.MAX_PLOTS - GameData.STARTING_PLOTS
	for _i in range(expansions_needed):
		eco.buy_land_expansion()
	var open_field_count := 0
	for p: Plot in eco.state.plots:
		if p.kind == PlotKind.Kind.OPEN_FIELD:
			open_field_count += 1
	assert_eq(open_field_count, GameData.MAX_PLOTS)

	var zones := VillageSnapshotMapper.build(eco.state)
	var open_field := _zone_by_id(zones, "open_field")
	assert_eq(open_field.plots.size(), GameData.MAX_PLOTS)
	for plot in open_field.plots:
		assert_ne(plot.lifecycle, PlotFixture.Lifecycle.GHOST)


# --- 9. No-overlap at the worst case (every zone unlocked, every plot slot full) ----

func test_no_footprint_overlap_with_every_zone_unlocked_and_every_plot_slot_full() -> void:
	eco.buy_polyhouse()
	eco.buy_agroforestry()
	eco.buy_aquaculture()
	eco.buy_vertical_farm()
	eco.buy_mandi()
	var expansions_needed := GameData.MAX_PLOTS - GameData.STARTING_PLOTS
	for _i in range(expansions_needed):
		eco.buy_land_expansion()

	var zones := VillageSnapshotMapper.build(eco.state)

	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	var overlaps := board._find_overlapping_tiles(zones)
	assert_eq(overlaps, [] as Array[Vector2i])


# --- 10. resolved_anchor() -- EPIC-M5 layout-overlap fix ---------------------------

func test_resolved_anchor_returns_default_when_no_custom_entry() -> void:
	assert_eq(VillageSnapshotMapper.resolved_anchor(eco.state, "farmhouse"), Vector2i(0, 0))
	assert_eq(VillageSnapshotMapper.resolved_anchor(eco.state, "vertical_farm"), Vector2i(7, 4))


func test_resolved_anchor_returns_custom_rounded_entry_when_present() -> void:
	eco.state.zone_layout["farmhouse"] = ZoneAnchor.new(1.2, 6.8)
	assert_eq(VillageSnapshotMapper.resolved_anchor(eco.state, "farmhouse"), Vector2i(1, 7))


func test_resolved_anchor_open_field_ignores_any_custom_entry_since_its_never_draggable() -> void:
	eco.state.zone_layout["open_field"] = ZoneAnchor.new(9.0, 9.0)
	assert_eq(VillageSnapshotMapper.resolved_anchor(eco.state, "open_field"), Vector2i(2, 0))


# --- 11. max_reserved_tiles() -- EPIC-M5 layout-overlap fix -------------------------

func test_max_reserved_tiles_farmhouse_is_just_the_2x2_building() -> void:
	var tiles := VillageSnapshotMapper.max_reserved_tiles("farmhouse", Vector2i(0, 0))
	assert_eq(tiles.size(), 4)
	for tile in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		assert_true(tiles.has(tile), "expected %s reserved" % tile)


func test_max_reserved_tiles_mandi_is_just_the_1x1_building() -> void:
	var tiles := VillageSnapshotMapper.max_reserved_tiles("mandi", Vector2i(8, 0))
	assert_eq(tiles, [Vector2i(8, 0)])


func test_max_reserved_tiles_open_field_covers_max_plots_rectangle() -> void:
	var tiles := VillageSnapshotMapper.max_reserved_tiles("open_field", Vector2i(2, 0))
	assert_eq(tiles.size(), GameData.MAX_PLOTS)
	for tile in [Vector2i(2, 0), Vector2i(5, 0), Vector2i(2, 3), Vector2i(5, 3)]:
		assert_true(tiles.has(tile), "expected %s reserved" % tile)


func test_max_reserved_tiles_polyhouse_covers_building_and_max_plots() -> void:
	var tiles := VillageSnapshotMapper.max_reserved_tiles("polyhouse", Vector2i(6, 0))
	assert_eq(tiles.size(), 4 + GameData.POLYHOUSE_PLOT_COUNT)
	assert_true(tiles.has(Vector2i(6, 0)))  # building
	assert_true(tiles.has(Vector2i(7, 3)))  # last plot at max capacity


## Regression test for the real bug this fix closes: a Farmhouse dragged to
## tile (1,7) while Agroforestry was still locked created an un-rejectable
## overlap once Agroforestry was later unlocked (found via on-device
## testing, EPIC-M5). This proves the fix would have caught it -- (1,7) is
## reserved by Agroforestry's max footprint at its default anchor even
## though Agroforestry was never unlocked in this test.
func test_max_reserved_tiles_agroforestry_at_default_anchor_includes_the_tile_that_caused_the_real_overlap_bug() -> void:
	var tiles := VillageSnapshotMapper.max_reserved_tiles("agroforestry", Vector2i(0, 4))
	assert_eq(tiles.size(), 4 + GameData.AGROFORESTRY_GRID_SIZE * GameData.AGROFORESTRY_GRID_SIZE)
	assert_true(tiles.has(Vector2i(1, 7)), "the exact tile the real bug dragged Farmhouse onto")
	assert_true(tiles.has(Vector2i(2, 7)))
	assert_true(tiles.has(Vector2i(1, 8)))
	assert_true(tiles.has(Vector2i(2, 8)))


func test_max_reserved_tiles_aquaculture_covers_building_and_max_plots() -> void:
	var tiles := VillageSnapshotMapper.max_reserved_tiles("aquaculture", Vector2i(4, 4))
	assert_eq(tiles.size(), 4 + GameData.AQUACULTURE_PLOT_COUNT)


func test_max_reserved_tiles_vertical_farm_covers_building_and_max_plots() -> void:
	var tiles := VillageSnapshotMapper.max_reserved_tiles("vertical_farm", Vector2i(7, 4))
	assert_eq(tiles.size(), 4 + GameData.VERTICAL_FARM_PLOT_COUNT)


# --- 12. VillageBoard._zone_fits() drag validation -- EPIC-M5 layout-overlap fix ----

func _make_zone_fixture(id: String, col: int, row: int, width: int, depth: int) -> ZoneFixture:
	return ZoneFixture.new(id, id, "", col, row, width, depth, Color.WHITE, [], true, true)


## The direct regression test: dragging the Farmhouse onto a tile only
## Agroforestry's (still-locked) future plot grid needs must be rejected,
## not silently allowed the way the real bug allowed it.
func test_zone_fits_rejects_a_drag_onto_a_locked_zones_future_plot_grid() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	var farmhouse := _make_zone_fixture("farmhouse", 0, 0, 2, 2)
	# eco.state.has_agroforestry is still false here -- deliberately: the
	# real bug happened specifically because the target zone was locked at
	# drag-time.
	assert_false(board._zone_fits(farmhouse, 1, 7))


func test_zone_fits_allows_a_drag_to_open_ground_far_from_any_zone() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	var farmhouse := _make_zone_fixture("farmhouse", 0, 0, 2, 2)
	# Col 9 and rows 9-11 are documented margin (village_snapshot_mapper.gd's
	# header: "max column used is 8, max row used is 8") -- genuinely clear
	# of every zone's max-reserved footprint, in-bounds for a 2x2 zone.
	assert_true(board._zone_fits(farmhouse, 8, 10))
