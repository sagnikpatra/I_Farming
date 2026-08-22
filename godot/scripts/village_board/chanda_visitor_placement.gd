## Pure placement logic for the Chanda Visit's on-board visiting NPC
## (design/gdd/festival-visiting-npcs.md's "future stretch," decided and
## built 2026-08-22). Finds a stationary tile immediately adjacent to the
## Farmhouse's current footprint for the visitor to stand on, reusing
## WalkableGrid the same way VillagerRoamer/VillagerSpawner already do --
## no new occupancy system invented. A pure function (zone + grid in, tile
## out) so it's directly unit-testable without a real VillageBoard scene,
## same rationale as WalkableGrid itself.
class_name ChandaVisitorPlacement
extends RefCounted


## Returns the first walkable tile found in a fixed, deterministic search
## order around `zone`'s footprint (south row left-to-right, then east
## column top-to-bottom, then north row right-to-left, then west column
## bottom-to-top), or Vector2i(-1, -1) if every adjacent tile is
## unwalkable (the Farmhouse boxed in by other zones/plots/decorations on
## every side -- extremely unlikely at this board's tile counts, but
## handled rather than crashing or misplacing the visitor, same
## defensive-fallback bar as villager_info_card.gd's unknown-character
## fallback).
static func find_visitor_tile(zone: ZoneFixture, walkable_grid: WalkableGrid) -> Vector2i:
	var candidates: Array[Vector2i] = []

	# South row (one tile below the footprint), left to right.
	for col in range(zone.tile_col, zone.tile_col + zone.tile_width):
		candidates.append(Vector2i(col, zone.tile_row + zone.tile_depth))
	# East column, top to bottom.
	for row in range(zone.tile_row, zone.tile_row + zone.tile_depth):
		candidates.append(Vector2i(zone.tile_col + zone.tile_width, row))
	# North row (one tile above the footprint), right to left.
	for col in range(zone.tile_col + zone.tile_width - 1, zone.tile_col - 1, -1):
		candidates.append(Vector2i(col, zone.tile_row - 1))
	# West column, bottom to top.
	for row in range(zone.tile_row + zone.tile_depth - 1, zone.tile_row - 1, -1):
		candidates.append(Vector2i(zone.tile_col - 1, row))

	for tile in candidates:
		if walkable_grid.is_in_bounds(tile) and walkable_grid.is_walkable(tile):
			return tile
	return Vector2i(-1, -1)
