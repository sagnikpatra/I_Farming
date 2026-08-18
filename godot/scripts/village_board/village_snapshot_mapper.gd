## Translates the real economy's GameState (scripts/economy/) into the plain
## ZoneFixture list village_board.gd renders. Replaces EPIC-M1/M3's
## VillageFixtureData.get_fixture_zones() hardcoded 3-zone stand-in now that
## EPIC-M2's real economy data exists. Pure function, no scene-tree
## dependency -- fully unit-testable with a bare GameState.new()
## (see tests/unit/test_village_snapshot_mapper.gd).
##
## Loosely mirrors the pre-migration Kotlin reference
## (app/.../ui/gdx/VillageSnapshotMapper.kt)'s zone-anchor/plot-layout
## structure and its anchorOf() custom-anchor resolution, but does NOT reuse
## its coordinate scheme: the Kotlin version used unbounded floats around the
## origin with one-tile-per-building. This board uses a fixed positive
## 10x12 grid (village_board.gd's GRID_COLS/GRID_ROWS) with real multi-tile
## building footprints (see zone_fixture.gd's tile_width/tile_depth) -- a
## deliberate upgrade over the Kotlin model, not a port of its layout.
##
## ZONE LAYOUT (all coordinates are absolute board-grid tile (col, row),
## board is GRID_COLS=10 (cols 0-9) x GRID_ROWS=12 (rows 0-11)). Verified
## overlap-free at the worst case -- every zone unlocked, every plot slot
## full -- max column used is 8, max row used is 8, leaving col 9 and rows
## 9-11 as margin. See tests/unit/test_village_snapshot_mapper.gd's
## no-overlap test for the automated check.
##
## | Zone id         | Default anchor | Building footprint         | Plot layout (relative to resolved anchor) |
## |------------------|-----------------|-----------------------------|--------------------------------------------|
## | farmhouse        | (0,0)           | 2x2 -> cols[0,1] rows[0,1]  | none (Farmhouse has no attached plots in the real economy) |
## | open_field       | (2,0)           | none (has_building=false)  | up to GameData.MAX_PLOTS=16, 4 columns, row-major: col = anchor.x + index%4, row = anchor.y + index/4 -> cols[2,5] rows[0,3] at full expansion, plus a GHOST tile at the next free slot |
## | polyhouse        | (6,0)           | 2x2 -> cols[6,7] rows[0,1]  | up to POLYHOUSE_PLOT_COUNT=4, 2 columns, directly below building: col = anchor.x + index%2, row = anchor.y + 2 + index/2 -> cols[6,7] rows[2,3] |
## | mandi            | (8,0)           | 1x1 -> col[8] row[0]        | none (a market, not a farm zone) |
## | agroforestry     | (0,4)           | 2x2 -> cols[0,1] rows[4,5]  | fixed AGROFORESTRY_GRID_SIZE=3x3 grid using each plot's own agro_col/agro_row (NOT a sequential index -- meaningful adjacency-puzzle coordinates): col = anchor.x + plot.agro_col, row = anchor.y + 2 + plot.agro_row -> cols[0,2] rows[6,8] |
## | aquaculture      | (4,4)           | 2x2 -> cols[4,5] rows[4,5]  | up to AQUACULTURE_PLOT_COUNT=5, 3 columns: col = anchor.x + index%3, row = anchor.y + 2 + index/3 -> cols[4,6] rows[6,7] |
## | vertical_farm    | (7,4)           | 2x2 -> cols[7,8] rows[4,5]  | up to VERTICAL_FARM_PLOT_COUNT=2, 2 columns: col = anchor.x + index%2, row = anchor.y + 2 + index/2 -> cols[7,8] row[6] |
##
## Custom anchor resolution: for each of the six *draggable* zones (all
## except open_field, which is never draggable and has no zone_layout entry),
## state.zone_layout.get(zone_id) overrides the default anchor above when
## present (tile_x/tile_y rounded to int via roundi() for the tile grid).
## Every attached plot's position is computed relative to this *resolved*
## anchor, so a dragged zone's plots move with it on the next rebuild.
## rotation_degrees/flipped_x are read from ZoneAnchor but not rendered --
## ZoneFixture has no rotation/flip fields yet and board_interactor.gd has no
## rotate/flip gesture (EPIC-M3 only built tap+drag) -- out of scope here.
class_name VillageSnapshotMapper
extends RefCounted

const ZONE_ID_FARMHOUSE := "farmhouse"
const ZONE_ID_OPEN_FIELD := "open_field"
const ZONE_ID_POLYHOUSE := "polyhouse"
const ZONE_ID_MANDI := "mandi"
const ZONE_ID_AGROFORESTRY := "agroforestry"
const ZONE_ID_AQUACULTURE := "aquaculture"
const ZONE_ID_VERTICAL_FARM := "vertical_farm"

const FARMHOUSE_ANCHOR := Vector2i(0, 0)
const OPEN_FIELD_ANCHOR := Vector2i(2, 0)
const POLYHOUSE_ANCHOR := Vector2i(6, 0)
const MANDI_ANCHOR := Vector2i(8, 0)
const AGROFORESTRY_ANCHOR := Vector2i(0, 4)
const AQUACULTURE_ANCHOR := Vector2i(4, 4)
const VERTICAL_FARM_ANCHOR := Vector2i(7, 4)

# Reasonable plinth colors -- see zone_fixture.gd's plinth_color and
# village_board.gd's palette. Farmhouse/Mandi/Polyhouse reuse the two/three
# values already tuned+verified against a screenshot in the old
# village_fixture_data.gd (do not re-tune); the three new Tier-3/4 zones get
# new colors within the same warm/Indian-architecture palette convention.
const FARMHOUSE_PLINTH_COLOR := Color(0.66, 0.34, 0.17)  # terracotta, unchanged
const MANDI_PLINTH_COLOR := Color(0.79, 0.60, 0.24)  # mustard/ochre, unchanged
const POLYHOUSE_PLINTH_COLOR := Color(0.63, 0.54, 0.45)  # warm stone/taupe, unchanged
# Earthy olive-brown -- warmer/browner than the ground's cooler sun-baked
# olive (village_board.gd's GROUND_COLOR) so the Agroforestry plinth doesn't
# visually blend into the grass it sits on.
const AGROFORESTRY_PLINTH_COLOR := Color(0.34, 0.38, 0.18)
# Blue-teal pond tone, reads as "managed water" against the warm palette.
const AQUACULTURE_PLINTH_COLOR := Color(0.18, 0.42, 0.46)
# Saffron-adjacent coral/pink -- Saffron is the Vertical Farm's flagship crop.
const VERTICAL_FARM_PLINTH_COLOR := Color(0.80, 0.42, 0.38)
# open_field has has_building=false, so its plinth_color is never rendered --
# any value is fine here, kept distinct (all-zero-alpha) so it can't be
# mistaken for an intentional color if this ever changes.
const OPEN_FIELD_PLINTH_COLOR_UNUSED := Color(0.0, 0.0, 0.0, 0.0)


static func build(state: GameState) -> Array[ZoneFixture]:
	var zones: Array[ZoneFixture] = []
	zones.append(_build_farmhouse(state))
	zones.append(_build_open_field(state))
	zones.append(_build_polyhouse(state))
	zones.append(_build_mandi(state))
	zones.append(_build_agroforestry(state))
	zones.append(_build_aquaculture(state))
	zones.append(_build_vertical_farm(state))
	return zones


## Resolves a draggable zone's saved custom anchor (state.zone_layout),
## rounded to the tile grid, or the zone's fixed default if none is saved.
## Mirrors the Kotlin reference's anchorOf() -- see this file's header.
static func _resolve_anchor(state: GameState, zone_id: String, default_anchor: Vector2i) -> Vector2i:
	var existing: ZoneAnchor = state.zone_layout.get(zone_id, null)
	if existing == null:
		return default_anchor
	return Vector2i(roundi(existing.tile_x), roundi(existing.tile_y))


static func _lifecycle_from_plot_state(kind: PlotState.Kind) -> PlotFixture.Lifecycle:
	match kind:
		PlotState.Kind.GROWING:
			return PlotFixture.Lifecycle.GROWING
		PlotState.Kind.READY_TO_HARVEST:
			return PlotFixture.Lifecycle.READY_TO_HARVEST
		_:
			return PlotFixture.Lifecycle.EMPTY


static func _plot_label(plot: Plot) -> String:
	if plot.state.kind == PlotState.Kind.EMPTY:
		return "empty"
	return GameData.crop_def(plot.state.crop).display_name


static func _plots_of_kind(state: GameState, kind: PlotKind.Kind) -> Array[Plot]:
	var matching: Array[Plot] = []
	for plot: Plot in state.plots:
		if plot.kind == kind:
			matching.append(plot)
	return matching


## Shared EMPTY/GROWING/READY_TO_HARVEST -> PlotFixture layout used by every
## plain crop-plot zone (Polyhouse, Aquaculture, Vertical Farm): plots laid
## out sequentially in `columns`-wide rows, starting `row_offset` tiles below
## the zone's anchor.
static func _simple_zone_plots(
	state: GameState, kind: PlotKind.Kind, anchor: Vector2i, columns: int, row_offset: int, is_water: bool
) -> Array[PlotFixture]:
	var plots: Array[PlotFixture] = []
	var matching := _plots_of_kind(state, kind)
	for index in range(matching.size()):
		var plot: Plot = matching[index]
		var col := anchor.x + index % columns
		var row := anchor.y + row_offset + index / columns
		var fixture := PlotFixture.new(col, row, _plot_label(plot))
		fixture.lifecycle = _lifecycle_from_plot_state(plot.state.kind)
		fixture.plot_id = plot.id
		fixture.is_water = is_water
		plots.append(fixture)
	return plots


static func _build_farmhouse(state: GameState) -> ZoneFixture:
	var anchor := _resolve_anchor(state, ZONE_ID_FARMHOUSE, FARMHOUSE_ANCHOR)
	return ZoneFixture.new(
		ZONE_ID_FARMHOUSE, "Farmhouse", VillageFixtureData.FARMHOUSE_MODEL,
		anchor.x, anchor.y, 2, 2,
		FARMHOUSE_PLINTH_COLOR,
		[],
		true, true
	)


## Never draggable (no zone_layout entry, no custom-anchor resolution) --
## the Kotlin reference's OPEN_FIELD_ANCHOR is likewise never passed through
## anchorOf(). Adds a trailing GHOST tile at the next free slot while
## open_field_count < GameData.MAX_PLOTS, omitted entirely once full.
static func _build_open_field(state: GameState) -> ZoneFixture:
	var anchor := OPEN_FIELD_ANCHOR
	var columns := 4
	var plots: Array[PlotFixture] = []
	var open_field_plots := _plots_of_kind(state, PlotKind.Kind.OPEN_FIELD)
	for index in range(open_field_plots.size()):
		var plot: Plot = open_field_plots[index]
		var col := anchor.x + index % columns
		var row := anchor.y + index / columns
		var fixture := PlotFixture.new(col, row, _plot_label(plot))
		fixture.lifecycle = _lifecycle_from_plot_state(plot.state.kind)
		fixture.plot_id = plot.id
		plots.append(fixture)
	if open_field_plots.size() < GameData.MAX_PLOTS:
		var ghost_index := open_field_plots.size()
		var col := anchor.x + ghost_index % columns
		var row := anchor.y + ghost_index / columns
		var ghost := PlotFixture.new(col, row, "next_expansion")
		ghost.lifecycle = PlotFixture.Lifecycle.GHOST
		plots.append(ghost)
	return ZoneFixture.new(
		ZONE_ID_OPEN_FIELD, "Open Field", "",
		anchor.x, anchor.y, 0, 0,
		OPEN_FIELD_PLINTH_COLOR_UNUSED,
		plots,
		true, false
	)


static func _build_polyhouse(state: GameState) -> ZoneFixture:
	var anchor := _resolve_anchor(state, ZONE_ID_POLYHOUSE, POLYHOUSE_ANCHOR)
	var plots: Array[PlotFixture] = []
	if state.has_polyhouse:
		plots = _simple_zone_plots(state, PlotKind.Kind.POLYHOUSE, anchor, 2, 2, false)
	return ZoneFixture.new(
		ZONE_ID_POLYHOUSE, "Polyhouse", "",
		anchor.x, anchor.y, 2, 2,
		POLYHOUSE_PLINTH_COLOR,
		plots,
		state.has_polyhouse, true
	)


static func _build_mandi(state: GameState) -> ZoneFixture:
	var anchor := _resolve_anchor(state, ZONE_ID_MANDI, MANDI_ANCHOR)
	return ZoneFixture.new(
		ZONE_ID_MANDI, "Mandi", VillageFixtureData.MANDI_MODEL,
		anchor.x, anchor.y, 1, 1,
		MANDI_PLINTH_COLOR,
		[],
		state.has_mandi, true
	)


## agro_col/agro_row are meaningful adjacency-puzzle coordinates (see
## game_economy.gd's _agro_neighbors()), not a sequential fill index --
## used directly rather than through _simple_zone_plots().
static func _build_agroforestry(state: GameState) -> ZoneFixture:
	var anchor := _resolve_anchor(state, ZONE_ID_AGROFORESTRY, AGROFORESTRY_ANCHOR)
	var plots: Array[PlotFixture] = []
	if state.has_agroforestry:
		for plot: Plot in state.plots:
			if plot.kind != PlotKind.Kind.AGROFORESTRY:
				continue
			var col := anchor.x + plot.agro_col
			var row := anchor.y + 2 + plot.agro_row
			var has_host: bool = plot.host_type != HostType.NONE
			var fixture := PlotFixture.new(col, row, "host" if has_host else _plot_label(plot))
			fixture.host_occupied = has_host
			fixture.lifecycle = _lifecycle_from_plot_state(plot.state.kind)
			fixture.plot_id = plot.id
			plots.append(fixture)
	return ZoneFixture.new(
		ZONE_ID_AGROFORESTRY, "Agroforestry", "",
		anchor.x, anchor.y, 2, 2,
		AGROFORESTRY_PLINTH_COLOR,
		plots,
		state.has_agroforestry, true
	)


static func _build_aquaculture(state: GameState) -> ZoneFixture:
	var anchor := _resolve_anchor(state, ZONE_ID_AQUACULTURE, AQUACULTURE_ANCHOR)
	var plots: Array[PlotFixture] = []
	if state.has_aquaculture:
		plots = _simple_zone_plots(state, PlotKind.Kind.AQUACULTURE, anchor, 3, 2, true)
	return ZoneFixture.new(
		ZONE_ID_AQUACULTURE, "Aquaculture", "",
		anchor.x, anchor.y, 2, 2,
		AQUACULTURE_PLINTH_COLOR,
		plots,
		state.has_aquaculture, true
	)


static func _build_vertical_farm(state: GameState) -> ZoneFixture:
	var anchor := _resolve_anchor(state, ZONE_ID_VERTICAL_FARM, VERTICAL_FARM_ANCHOR)
	var plots: Array[PlotFixture] = []
	if state.has_vertical_farm:
		plots = _simple_zone_plots(state, PlotKind.Kind.VERTICAL_FARM, anchor, 2, 2, false)
	return ZoneFixture.new(
		ZONE_ID_VERTICAL_FARM, "Vertical Farm", "",
		anchor.x, anchor.y, 2, 2,
		VERTICAL_FARM_PLINTH_COLOR,
		plots,
		state.has_vertical_farm, true
	)
