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
