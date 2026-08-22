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


## design/gdd/farmhouse-visual-tiers.md -- model_path must reflect the
## REAL current farmhouse_level, not a hardcoded value, recomputed fresh
## on every build() call.
func test_farmhouse_model_path_reflects_the_current_level() -> void:
	eco.state.farmhouse_level = 0
	var fresh_zones := VillageSnapshotMapper.build(eco.state)
	assert_eq(_zone_by_id(fresh_zones, "farmhouse").model_path, VillageFixtureData.FARMHOUSE_MODEL_TIER_1)

	eco.state.farmhouse_level = 7
	var upgraded_zones := VillageSnapshotMapper.build(eco.state)
	assert_eq(_zone_by_id(upgraded_zones, "farmhouse").model_path, VillageFixtureData.FARMHOUSE_MODEL_TIER_5)


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


# --- 5b. PlotState.crop -> PlotFixture.crop threading (crop growth-stage geometry) ---

func test_empty_plot_fixture_carries_no_crop() -> void:
	var plot: Plot = eco.state.plots[0]
	var zones := VillageSnapshotMapper.build(eco.state)
	var open_field := _zone_by_id(zones, "open_field")
	var fixture := _plot_with_id(open_field, plot.id)
	assert_not_null(fixture)
	assert_eq(fixture.crop, -1)


func test_growing_plot_fixture_carries_the_real_planted_crop_ordinal() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW)
	var zones := VillageSnapshotMapper.build(eco.state)
	var open_field := _zone_by_id(zones, "open_field")
	var fixture := _plot_with_id(open_field, plot.id)
	assert_not_null(fixture)
	assert_eq(fixture.crop, CropType.Kind.WHEAT)


func test_ready_to_harvest_plot_fixture_still_carries_the_planted_crop_ordinal() -> void:
	var plot: Plot = eco.state.plots[0]
	eco.plant_seed(plot.id, CropType.Kind.WHEAT, NOW)
	eco.resolve_growth_completions(NOW + 121 * 1000)  # Wheat grows in 120s.
	var zones := VillageSnapshotMapper.build(eco.state)
	var open_field := _zone_by_id(zones, "open_field")
	var fixture := _plot_with_id(open_field, plot.id)
	assert_not_null(fixture)
	assert_eq(fixture.crop, CropType.Kind.WHEAT)


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


## 2026-08-23: the test above only proves the healthy/no-overlap case --
## nothing previously verified _find_overlapping_tiles() actually DETECTS
## a real overlap when one exists, despite its own doc comment explicitly
## worrying about this exact failure mode ("a real player hitting this
## rare edge case would have an unrecoverable 'empty board' save with no
## error shown to them at all"). A safety-critical path with only its
## negative case tested is a real gap, found and closed here rather than
## assumed correct because the negative case passed.
func test_detects_a_real_zone_to_zone_footprint_overlap() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	var color := Color.WHITE
	var zone_a := ZoneFixture.new("a", "Zone A", "", 2, 2, 2, 2, color)
	var zone_b := ZoneFixture.new("b", "Zone B", "", 3, 3, 2, 2, color)  # overlaps zone_a at (3,3)

	var overlaps := board._find_overlapping_tiles([zone_a, zone_b])

	assert_eq(overlaps, [Vector2i(3, 3)] as Array[Vector2i])


func test_detects_a_zone_footprint_to_plot_overlap() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	var color := Color.WHITE
	var zone_a := ZoneFixture.new("a", "Zone A", "", 2, 2, 2, 2, color)  # occupies (2,2)-(3,3)
	var plots: Array[PlotFixture] = [PlotFixture.new(3, 3, "plot")]  # lands on zone_a's own tile
	var zone_b := ZoneFixture.new(
		"b", "Zone B", "", 10, 10, 1, 1, color, plots
	)

	var overlaps := board._find_overlapping_tiles([zone_a, zone_b])

	assert_eq(overlaps, [Vector2i(3, 3)] as Array[Vector2i])


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


# --- 13. build_walkable_grid() -- EPIC-M6 roaming's GameState integration ----------

const GRID_COLS: int = 10
const GRID_ROWS: int = 12


func test_build_walkable_grid_marks_documented_margin_as_walkable() -> void:
	var grid := VillageSnapshotMapper.build_walkable_grid(eco.state, GRID_COLS, GRID_ROWS)

	# Same margin tile test_zone_fits_allows_a_drag_to_open_ground... already
	# relies on being genuinely clear of every zone's max-reserved footprint.
	assert_true(grid.is_walkable(Vector2i(9, 10)))


func test_build_walkable_grid_marks_farmhouse_footprint_as_unwalkable() -> void:
	var grid := VillageSnapshotMapper.build_walkable_grid(eco.state, GRID_COLS, GRID_ROWS)

	assert_false(grid.is_walkable(Vector2i(0, 0)))
	assert_false(grid.is_walkable(Vector2i(1, 1)))


func test_build_walkable_grid_reserves_a_not_yet_unlocked_zones_future_footprint() -> void:
	# has_agroforestry is still false -- deliberately conservative policy
	# (see build_walkable_grid()'s doc comment): reserve every zone's
	# maximum footprint regardless of unlock state, same as the drag
	# validation this reuses.
	var grid := VillageSnapshotMapper.build_walkable_grid(eco.state, GRID_COLS, GRID_ROWS)

	assert_false(grid.is_walkable(Vector2i(1, 7)))  # the exact tile the real overlap bug involved


func test_build_walkable_grid_reserves_a_placed_decorations_tile() -> void:
	eco.place_decoration(DecorationType.Kind.LANTERN, 9.0, 9.0)

	var grid := VillageSnapshotMapper.build_walkable_grid(eco.state, GRID_COLS, GRID_ROWS)

	assert_false(grid.is_walkable(Vector2i(9, 9)))


func test_build_walkable_grid_follows_a_custom_zone_anchor() -> void:
	eco.state.zone_layout["polyhouse"] = ZoneAnchor.new(9.0, 9.0)

	var grid := VillageSnapshotMapper.build_walkable_grid(eco.state, GRID_COLS, GRID_ROWS)

	# Default Polyhouse anchor (6,0) should be clear now that it moved...
	assert_true(grid.is_walkable(Vector2i(6, 0)))
	# ...and the new position should be reserved instead.
	assert_false(grid.is_walkable(Vector2i(9, 9)))


# --- point_of_interest_tiles() -- richer-ambient-villagers.md's Lingering stretch goal --

func test_point_of_interest_tiles_is_empty_with_no_decorations() -> void:
	var grid := VillageSnapshotMapper.build_walkable_grid(eco.state, GRID_COLS, GRID_ROWS)

	var pois := VillageSnapshotMapper.point_of_interest_tiles(eco.state, grid)

	assert_true(pois.is_empty())


func test_point_of_interest_tiles_returns_a_decorations_walkable_neighbors() -> void:
	eco.place_decoration(DecorationType.Kind.LANTERN, 9.0, 9.0)
	var grid := VillageSnapshotMapper.build_walkable_grid(eco.state, GRID_COLS, GRID_ROWS)

	var pois := VillageSnapshotMapper.point_of_interest_tiles(eco.state, grid)

	# (9,9) itself is reserved by the decoration (see the reserves-a-placed-
	# decoration's-tile test above) -- its walkable neighbors should be POIs.
	assert_true(pois.has(Vector2i(8, 9)))
	assert_true(pois.has(Vector2i(9, 8)))
	assert_false(pois.has(Vector2i(9, 9)), "the decoration's own tile is an obstacle, never a POI target")


func test_point_of_interest_tiles_excludes_a_neighbor_thats_itself_reserved() -> void:
	# Farmhouse's footprint reserves (0,0)/(1,1) etc (see the farmhouse-
	# footprint-unwalkable test above) -- a decoration placed adjacent to
	# it must not offer that reserved neighbor as a POI.
	eco.place_decoration(DecorationType.Kind.LANTERN, 2.0, 0.0)
	var grid := VillageSnapshotMapper.build_walkable_grid(eco.state, GRID_COLS, GRID_ROWS)

	var pois := VillageSnapshotMapper.point_of_interest_tiles(eco.state, grid)

	assert_false(pois.has(Vector2i(1, 0)), "Farmhouse's own footprint tile must never be offered as a POI target")


func test_point_of_interest_tiles_deduplicates_shared_neighbors() -> void:
	# Two decorations placed two tiles apart share (9,9) as a common
	# neighbor of neither directly, but placing both near the same open
	# corner should never produce duplicate entries for any tile.
	eco.place_decoration(DecorationType.Kind.LANTERN, 8.0, 9.0)
	eco.place_decoration(DecorationType.Kind.LANTERN, 9.0, 10.0)
	var grid := VillageSnapshotMapper.build_walkable_grid(eco.state, GRID_COLS, GRID_ROWS)

	var pois := VillageSnapshotMapper.point_of_interest_tiles(eco.state, grid)

	var seen: Dictionary = {}
	for tile in pois:
		assert_false(seen.has(tile), "no POI tile should be listed twice, even if two decorations share it as a neighbor")
		seen[tile] = true


# --- 14. villager_count() -- design/gdd/villagers.md §4's population formula ------

func test_unlocked_zone_count_is_two_with_only_farmhouse_and_mandi() -> void:
	assert_eq(VillageSnapshotMapper.unlocked_zone_count(eco.state), 2)


func test_unlocked_zone_count_increases_per_structure_unlocked() -> void:
	eco.buy_polyhouse()
	assert_eq(VillageSnapshotMapper.unlocked_zone_count(eco.state), 3)

	eco.buy_aquaculture()
	assert_eq(VillageSnapshotMapper.unlocked_zone_count(eco.state), 4)


func test_villager_count_is_two_at_the_floor() -> void:
	# unlockedZoneCount=2 -> clamp(2 + floor(2*0.75), 2, 6) = clamp(3, 2, 6) = 3
	assert_eq(VillageSnapshotMapper.villager_count(eco.state), 3)


func test_villager_count_is_clamped_to_six_at_the_ceiling() -> void:
	eco.buy_polyhouse()
	eco.buy_aquaculture()
	eco.buy_vertical_farm()
	eco.buy_agroforestry()

	# unlockedZoneCount=6 -> clamp(2 + floor(6*0.75), 2, 6) = clamp(6, 2, 6) = 6
	assert_eq(VillageSnapshotMapper.villager_count(eco.state), 6)


# --- 15. try_commit_zone_move() resyncs villagers -- EPIC-M6 stale-walk-target fix -

## A zone move changes which tiles are reserved without necessarily
## changing villager_count() -- try_commit_zone_move() must resync the
## villager population itself (not rely on persist_and_rebuild_if_dirty(),
## which never runs for this path -- see that method's own comment) or an
## already-spawned villager's walk target could go stale. This test uses
## the board's own internally-loaded economy (via its _ready() ->
## SaveSystem.load_state()), not this file's `eco` -- so it deliberately
## doesn't assert an exact starting population size, only that a
## successful move produces a genuinely different set of villager
## instances, whatever the starting state was.
func test_try_commit_zone_move_resyncs_villagers_on_a_successful_move() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)

	# Normalize to Farmhouse's own documented default anchor first. This
	# test persists to the real user://save.tres via try_commit_zone_move()
	# (the board's own _ready() loads from there too) -- without this, a
	# PRIOR run of this same test could leave Farmhouse already at the
	# target position below, making the real move a same-position no-op
	# and the resync assertion a flaky false negative (caught exactly this
	# way on a second consecutive run, 2026-08-21).
	board.try_commit_zone_move("farmhouse", 0, 0)

	var spawner := board.get_villager_spawner()
	var before := spawner.get_roamers()
	assert_false(before.is_empty(), "expected at least one villager on a fresh board load")

	# Col 9 / row 10 is documented margin, genuinely clear of every zone's
	# max-reserved footprint (see test_zone_fits_allows_a_drag_to_open_ground...
	# above) -- guaranteed a real, different position after the normalize above.
	var moved := board.try_commit_zone_move("farmhouse", 8, 10)

	assert_true(moved)
	var after := spawner.get_roamers()
	assert_false(after.is_empty())
	assert_ne(after[0], before[0], "a successful zone move should resync villagers, not leave stale instances")


# --- 16. Worker stations -- EPIC-M7 visual stationing, the "called" half of ------
# --- villagers.md §3.6 -----------------------------------------------------------

## OPEN_FIELD is used throughout this section (not Polyhouse/Aquaculture/
## Vertical Farm) specifically because it's always unlocked -- these tests
## drive the board's own internally-loaded economy (via SaveSystem, same
## real-save-file coupling test_try_commit_zone_move_resyncs_villagers...
## above already accepts), so a plot kind that needs no purchase first
## keeps this section's assertions independent of ambient save state.

func test_assigning_a_worker_creates_a_worker_station() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	var eco := board.get_economy()

	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")
	board.persist_and_rebuild_if_dirty()

	var station := board.get_worker_station(PlotKind.Kind.OPEN_FIELD)
	assert_not_null(station)
	assert_not_null(station.get_villager())


func test_worker_station_is_positioned_away_from_the_scene_origin() -> void:
	# Weak but meaningful sanity check: Vector3.ZERO would mean setup()
	# was never actually called with a real zone-center position -- the
	# open_field zone's default anchor (2,0) is not centered on the
	# board's origin, so a correctly-wired station must not sit at (0,0,0).
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	var eco := board.get_economy()

	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")
	board.persist_and_rebuild_if_dirty()

	var station := board.get_worker_station(PlotKind.Kind.OPEN_FIELD)
	assert_ne(station.position, Vector3.ZERO)


func test_unassigning_a_worker_removes_its_worker_station() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	var eco := board.get_economy()
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")
	board.persist_and_rebuild_if_dirty()
	assert_not_null(board.get_worker_station(PlotKind.Kind.OPEN_FIELD))

	eco.unassign_worker(PlotKind.Kind.OPEN_FIELD)
	board.persist_and_rebuild_if_dirty()

	assert_null(board.get_worker_station(PlotKind.Kind.OPEN_FIELD))


func test_no_worker_station_exists_for_an_unassigned_plot_kind() -> void:
	var board := VILLAGE_BOARD_SCENE.instantiate() as VillageBoard
	add_child_autofree(board)
	# Defensively normalize first: this test drives the board's own
	# SaveSystem-loaded economy, and a PRIOR test in this section could
	# have left a real, persisted OPEN_FIELD assignment on disk -- without
	# this, that leftover state would make this "nothing assigned" test a
	# flaky false negative depending on run history, same class of bug
	# already caught once this session (see
	# test_try_commit_zone_move_resyncs_villagers_on_a_successful_move's
	# own comment).
	board.get_economy().unassign_worker(PlotKind.Kind.OPEN_FIELD)
	board.persist_and_rebuild_if_dirty()

	assert_null(board.get_worker_station(PlotKind.Kind.OPEN_FIELD))


# --- active_upgrade_count -- land-and-structures.md's sub-upgrade visual cue stretch goal --

func test_polyhouse_upgrade_count_is_zero_before_polyhouse_is_bought() -> void:
	var zones := VillageSnapshotMapper.build(eco.state, NOW)
	assert_eq(_zone_by_id(zones, VillageSnapshotMapper.ZONE_ID_POLYHOUSE).active_upgrade_count, 0)


func test_polyhouse_upgrade_count_is_zero_with_no_sub_upgrades_bought() -> void:
	eco.buy_polyhouse()
	var zones := VillageSnapshotMapper.build(eco.state, NOW)
	assert_eq(_zone_by_id(zones, VillageSnapshotMapper.ZONE_ID_POLYHOUSE).active_upgrade_count, 0)


func test_polyhouse_upgrade_count_counts_fan_pad() -> void:
	eco.buy_polyhouse()
	eco.buy_fan_pad()
	var zones := VillageSnapshotMapper.build(eco.state, NOW)
	assert_eq(_zone_by_id(zones, VillageSnapshotMapper.ZONE_ID_POLYHOUSE).active_upgrade_count, 1)


func test_polyhouse_upgrade_count_counts_all_three_sub_upgrades_together() -> void:
	eco.buy_polyhouse()
	eco.buy_fan_pad()
	eco.buy_drip_irrigation()
	eco.renew_film(NOW)
	var zones := VillageSnapshotMapper.build(eco.state, NOW)
	assert_eq(_zone_by_id(zones, VillageSnapshotMapper.ZONE_ID_POLYHOUSE).active_upgrade_count, 3)


func test_polyhouse_upgrade_count_excludes_an_expired_film() -> void:
	eco.buy_polyhouse()
	eco.renew_film(NOW)
	# Query well past the film's own expiry.
	var zones := VillageSnapshotMapper.build(eco.state, NOW + GameData.UV_FILM_DURATION_MS + 1)
	assert_eq(_zone_by_id(zones, VillageSnapshotMapper.ZONE_ID_POLYHOUSE).active_upgrade_count, 0)


func test_agroforestry_upgrade_count_reflects_security() -> void:
	eco.buy_agroforestry()
	var before := VillageSnapshotMapper.build(eco.state, NOW)
	assert_eq(_zone_by_id(before, VillageSnapshotMapper.ZONE_ID_AGROFORESTRY).active_upgrade_count, 0)

	eco.buy_security()
	var after := VillageSnapshotMapper.build(eco.state, NOW)
	assert_eq(_zone_by_id(after, VillageSnapshotMapper.ZONE_ID_AGROFORESTRY).active_upgrade_count, 1)


func test_vertical_farm_upgrade_count_reflects_active_electricity() -> void:
	eco.buy_vertical_farm()
	var before := VillageSnapshotMapper.build(eco.state, NOW)
	assert_eq(_zone_by_id(before, VillageSnapshotMapper.ZONE_ID_VERTICAL_FARM).active_upgrade_count, 0)

	eco.renew_electricity(NOW)
	var after := VillageSnapshotMapper.build(eco.state, NOW)
	assert_eq(_zone_by_id(after, VillageSnapshotMapper.ZONE_ID_VERTICAL_FARM).active_upgrade_count, 1)


func test_vertical_farm_upgrade_count_excludes_expired_electricity() -> void:
	eco.buy_vertical_farm()
	eco.renew_electricity(NOW)
	var zones := VillageSnapshotMapper.build(eco.state, NOW + GameData.ELECTRICITY_DURATION_MS + 1)
	assert_eq(_zone_by_id(zones, VillageSnapshotMapper.ZONE_ID_VERTICAL_FARM).active_upgrade_count, 0)


func test_aquaculture_upgrade_count_is_always_zero() -> void:
	# Aquaculture has no sub-upgrade of its own in GameState today --
	# documented explicitly (zone_fixture.gd's own active_upgrade_count
	# doc comment) rather than left as an unexplained gap.
	eco.buy_aquaculture()
	var zones := VillageSnapshotMapper.build(eco.state, NOW)
	assert_eq(_zone_by_id(zones, VillageSnapshotMapper.ZONE_ID_AQUACULTURE).active_upgrade_count, 0)


func test_build_defaults_now_to_a_value_that_always_reads_upgrades_as_inactive() -> void:
	# Backward compatibility: every pre-existing call to build(state) with
	# no now argument (every test above this section, and every one
	# already in this file) must keep working exactly as before --
	# confirmed explicitly rather than just assumed from the default value.
	eco.buy_polyhouse()
	eco.renew_film(NOW)
	var zones := VillageSnapshotMapper.build(eco.state)
	assert_eq(_zone_by_id(zones, VillageSnapshotMapper.ZONE_ID_POLYHOUSE).active_upgrade_count, 0)
