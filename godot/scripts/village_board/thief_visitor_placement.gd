## Pure placement logic for the Thief Visit's on-board visiting NPC
## (design/gdd/thief-system.md). Finds a tile near the Farmhouse for the thief
## to stand on, reusing WalkableGrid the same way ChandaVisitorPlacement does.
## A pure static function (farmhouse tile + grid in, thief tile out) so it's
## directly unit-testable without a real VillageBoard scene.
##
## Search priority: adjacent to Farmhouse -> nearby cleared tiles -> random
## empty tile. If every tile is unwalkable (extremely unlikely), returns
## Vector2i(-1, -1) rather than crashing or misplacing the thief.
class_name ThiefVisitorPlacement
extends RefCounted


## Returns a walkable tile for the thief to stand on, searching in order:
## 1. Adjacent to the Farmhouse (all 8 neighbors around farmhouse_tile)
## 2. Nearby cleared tiles within 3-tile radius
## 3. Any random walkable tile on the board
## Returns Vector2i(-1, -1) if no walkable tile exists (defensive fallback).
static func find_thief_tile(
	grid: Array,
	grid_cols: int,
	grid_rows: int,
	farmhouse_tile: Vector2i
) -> Vector2i:
	# Phase 1: Check 8 adjacent tiles around the Farmhouse
	var adjacent_offsets: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),  # North row
		Vector2i(-1,  0),                  Vector2i(1,  0),  # East/West
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1),  # South row
	]

	for offset in adjacent_offsets:
		var candidate := farmhouse_tile + offset
		if _is_walkable(grid, grid_cols, grid_rows, candidate):
			return candidate

	# Phase 2: Search nearby tiles within 3-tile radius (9x9 area centered on farmhouse)
	var nearby_candidates: Array[Vector2i] = []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			# Skip center (farmhouse itself) and already-checked adjacent tiles
			if abs(dx) <= 1 and abs(dy) <= 1:
				continue
			var candidate := farmhouse_tile + Vector2i(dx, dy)
			if _is_walkable(grid, grid_cols, grid_rows, candidate):
				nearby_candidates.append(candidate)

	if not nearby_candidates.is_empty():
		return nearby_candidates[0]  # Deterministic: always pick first found

	# Phase 3: Fallback to ANY walkable tile on the board
	for row in range(grid_rows):
		for col in range(grid_cols):
			var candidate := Vector2i(col, row)
			if _is_walkable(grid, grid_cols, grid_rows, candidate):
				return candidate

	# No walkable tile exists (board fully blocked -- defensive fallback)
	return Vector2i(-1, -1)


static func _is_walkable(grid: Array, grid_cols: int, grid_rows: int, tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= grid_cols or tile.y < 0 or tile.y >= grid_rows:
		return false
	var index := tile.y * grid_cols + tile.x
	if index < 0 or index >= grid.size():
		return false
	return grid[index] == true
