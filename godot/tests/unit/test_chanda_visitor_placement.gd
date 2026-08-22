extends GutTest
## Coverage for ChandaVisitorPlacement.find_visitor_tile() -- pure tile-
## selection logic for design/gdd/festival-visiting-npcs.md's board-NPC
## stretch (decided and built 2026-08-22). No VillageBoard scene needed,
## same rationale as test_walkable_grid.gd itself.

const PLACEHOLDER_COLOR := Color.WHITE


func _make_farmhouse_zone(col: int, row: int, width: int, depth: int) -> ZoneFixture:
	return ZoneFixture.new(
		VillageSnapshotMapper.ZONE_ID_FARMHOUSE, "Farmhouse", "", col, row, width, depth, PLACEHOLDER_COLOR
	)


func test_returns_the_south_tile_when_it_is_walkable() -> void:
	var zone := _make_farmhouse_zone(2, 2, 2, 2)  # occupies (2,2)-(3,3)
	var grid := WalkableGrid.new(10, 10, [])

	var tile := ChandaVisitorPlacement.find_visitor_tile(zone, grid)

	assert_eq(tile, Vector2i(2, 4), "south row, leftmost column, is the first candidate")


func test_falls_back_to_east_column_when_the_south_row_is_blocked() -> void:
	var zone := _make_farmhouse_zone(2, 2, 2, 2)
	var reserved: Array[Vector2i] = [Vector2i(2, 4), Vector2i(3, 4)]  # whole south row
	var grid := WalkableGrid.new(10, 10, reserved)

	var tile := ChandaVisitorPlacement.find_visitor_tile(zone, grid)

	assert_eq(tile, Vector2i(4, 2), "east column, topmost row, is the first candidate once south is blocked")


func test_falls_back_to_north_row_when_south_and_east_are_blocked() -> void:
	var zone := _make_farmhouse_zone(2, 2, 2, 2)
	var reserved: Array[Vector2i] = [
		Vector2i(2, 4), Vector2i(3, 4),  # south row
		Vector2i(4, 2), Vector2i(4, 3),  # east column
	]
	var grid := WalkableGrid.new(10, 10, reserved)

	var tile := ChandaVisitorPlacement.find_visitor_tile(zone, grid)

	assert_eq(tile, Vector2i(3, 1), "north row is swept right-to-left, so the rightmost tile comes first")


func test_falls_back_to_west_column_when_south_east_and_north_are_blocked() -> void:
	var zone := _make_farmhouse_zone(2, 2, 2, 2)
	var reserved: Array[Vector2i] = [
		Vector2i(2, 4), Vector2i(3, 4),  # south row
		Vector2i(4, 2), Vector2i(4, 3),  # east column
		Vector2i(3, 1), Vector2i(2, 1),  # north row
	]
	var grid := WalkableGrid.new(10, 10, reserved)

	var tile := ChandaVisitorPlacement.find_visitor_tile(zone, grid)

	assert_eq(tile, Vector2i(1, 3), "west column is swept bottom-to-top, so the bottom tile comes first")


func test_returns_invalid_tile_when_every_adjacent_tile_is_blocked() -> void:
	var zone := _make_farmhouse_zone(2, 2, 2, 2)
	var reserved: Array[Vector2i] = [
		Vector2i(2, 4), Vector2i(3, 4),  # south
		Vector2i(4, 2), Vector2i(4, 3),  # east
		Vector2i(3, 1), Vector2i(2, 1),  # north
		Vector2i(1, 2), Vector2i(1, 3),  # west
	]
	var grid := WalkableGrid.new(10, 10, reserved)

	var tile := ChandaVisitorPlacement.find_visitor_tile(zone, grid)

	assert_eq(tile, Vector2i(-1, -1), "boxed in on every side -- must fail safely, not crash or misplace")


func test_out_of_bounds_candidates_are_skipped_not_crashed_on() -> void:
	# Farmhouse pinned at the board's top-left corner -- the north row and
	# west column candidates fall outside the grid entirely.
	var zone := _make_farmhouse_zone(0, 0, 2, 2)
	var grid := WalkableGrid.new(10, 10, [])

	var tile := ChandaVisitorPlacement.find_visitor_tile(zone, grid)

	assert_eq(tile, Vector2i(0, 2), "south row is still in-bounds and walkable, so it's still chosen first")
