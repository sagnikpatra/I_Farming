class_name WalkableGrid
extends RefCounted
## Pure grid-occupancy + pathfinding logic for villager roaming (EPIC-M6,
## see design/gdd/villagers.md §3's walkable-area rule). Deliberately does
## NOT know about GameState, VillageBoard, or any scene node -- callers
## pass in dimensions and a reserved-tile set (from
## VillageSnapshotMapper.max_reserved_tiles() plus decoration positions,
## once that integration is wired -- not this slice, see the GDD's "Next
## Steps"). Keeping this class scene-free makes it directly unit-testable
## with add_child_autofree()-free GUT tests, same reasoning
## village_snapshot_mapper.gd's pure functions already established.
##
## Deviation from the roadmap's original phrasing ("NavigationRegion3D/
## NavigationAgent3D roaming behavior"): the village board is a small,
## fixed 10x12 grid (village_board.gd's GRID_COLS/GRID_ROWS), so a
## hand-rolled BFS grid pathfinder is simpler, fully headless-testable,
## and avoids depending on a HIGH-knowledge-risk Godot 4.7 subsystem this
## project has never used before -- consistent with
## technical-preferences.md's existing preference for lightweight
## hand-rolled systems over heavier engine subsystems (see: manual
## ray-picking instead of a physics engine). Documented here rather than
## silently diverging from the roadmap text.

var _cols: int
var _rows: int
var _reserved: Dictionary = {}  # Vector2i -> true, for O(1) lookup


func _init(cols: int, rows: int, reserved_tiles: Array = []) -> void:
	_cols = cols
	_rows = rows
	for tile in reserved_tiles:
		_reserved[tile] = true


func is_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < _cols and tile.y >= 0 and tile.y < _rows


func is_walkable(tile: Vector2i) -> bool:
	return is_in_bounds(tile) and not _reserved.has(tile)


func get_walkable_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in _cols:
		for y in _rows:
			var tile := Vector2i(x, y)
			if is_walkable(tile):
				result.append(tile)
	return result


## Returns a random walkable tile, excluding `exclude` when a different
## option exists (so callers picking a new roam target don't get handed
## back their current tile). Returns `exclude` itself if it's the only
## walkable tile on the board (degenerate case -- an empty/fully-built
## board shouldn't reach this in practice, but callers must not assume a
## different tile is always returned).
func random_walkable_tile(rng: RandomNumberGenerator, exclude: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	var candidates := get_walkable_tiles()
	if candidates.is_empty():
		return exclude
	if candidates.size() == 1:
		return candidates[0]
	var filtered := candidates.filter(func(t): return t != exclude)
	if filtered.is_empty():
		filtered = candidates
	return filtered[rng.randi_range(0, filtered.size() - 1)]


## Shortest 4-connected path from start to goal, inclusive of both
## endpoints, via plain BFS (no heuristic needed -- the board is 10x12,
## unweighted, and this runs once per villager per target pick, not per
## frame). Returns an empty array if start or goal isn't walkable, or if
## no path exists. Returns [start] if start == goal.
func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not is_walkable(start) or not is_walkable(goal):
		return []
	if start == goal:
		return [start]

	var came_from: Dictionary = {start: start}
	var frontier: Array[Vector2i] = [start]
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			return _reconstruct_path(came_from, start, goal)
		for dir in directions:
			var next: Vector2i = current + dir
			if is_walkable(next) and not came_from.has(next):
				came_from[next] = current
				frontier.append(next)

	return []  # goal unreachable from start


func _reconstruct_path(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [goal]
	var current := goal
	while current != start:
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path
