extends GutTest
## Coverage for WalkableGrid (godot/scripts/village_board/walkable_grid.gd)
## -- the pure occupancy/pathfinding logic behind EPIC-M6's roaming
## villagers (design/gdd/villagers.md §3). Pure RefCounted logic, no scene
## tree needed.


func test_is_walkable_true_for_open_tile_in_bounds() -> void:
	var grid := WalkableGrid.new(5, 5, [])

	assert_true(grid.is_walkable(Vector2i(2, 2)))


func test_is_walkable_false_for_reserved_tile() -> void:
	var grid := WalkableGrid.new(5, 5, [Vector2i(2, 2)])

	assert_false(grid.is_walkable(Vector2i(2, 2)))


func test_is_walkable_false_for_out_of_bounds_tile() -> void:
	var grid := WalkableGrid.new(5, 5, [])

	assert_false(grid.is_walkable(Vector2i(-1, 0)))
	assert_false(grid.is_walkable(Vector2i(5, 0)))
	assert_false(grid.is_walkable(Vector2i(0, 5)))


func test_get_walkable_tiles_excludes_reserved() -> void:
	var grid := WalkableGrid.new(2, 2, [Vector2i(0, 0)])

	var walkable := grid.get_walkable_tiles()

	assert_eq(walkable.size(), 3)
	assert_false(walkable.has(Vector2i(0, 0)))


func test_random_walkable_tile_excludes_current_when_alternative_exists() -> void:
	var grid := WalkableGrid.new(2, 1, [])  # two walkable tiles: (0,0) and (1,0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	for i in 20:
		var picked := grid.random_walkable_tile(rng, Vector2i(0, 0))
		assert_ne(picked, Vector2i(0, 0), "should always pick the other tile when one exists")


func test_random_walkable_tile_returns_only_tile_when_degenerate() -> void:
	var grid := WalkableGrid.new(1, 1, [])  # exactly one walkable tile
	var rng := RandomNumberGenerator.new()

	var picked := grid.random_walkable_tile(rng, Vector2i(0, 0))

	assert_eq(picked, Vector2i(0, 0))


func test_find_path_returns_single_tile_when_start_equals_goal() -> void:
	var grid := WalkableGrid.new(3, 3, [])

	var path := grid.find_path(Vector2i(1, 1), Vector2i(1, 1))

	assert_eq(path, [Vector2i(1, 1)])


func test_find_path_returns_empty_when_start_not_walkable() -> void:
	var grid := WalkableGrid.new(3, 3, [Vector2i(0, 0)])

	var path := grid.find_path(Vector2i(0, 0), Vector2i(2, 2))

	assert_eq(path.size(), 0)


func test_find_path_returns_empty_when_goal_not_walkable() -> void:
	var grid := WalkableGrid.new(3, 3, [Vector2i(2, 2)])

	var path := grid.find_path(Vector2i(0, 0), Vector2i(2, 2))

	assert_eq(path.size(), 0)


func test_find_path_returns_direct_path_on_open_grid() -> void:
	var grid := WalkableGrid.new(3, 1, [])

	var path := grid.find_path(Vector2i(0, 0), Vector2i(2, 0))

	assert_eq(path, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])


func test_find_path_routes_around_a_reserved_obstacle() -> void:
	# 3-wide corridor with the middle column's middle tile blocked --
	# forces the path to detour through (1,0) or (1,2) instead of a
	# straight line through (1,1).
	var grid := WalkableGrid.new(3, 3, [Vector2i(1, 1)])

	var path := grid.find_path(Vector2i(0, 1), Vector2i(2, 1))

	assert_eq(path.size(), 5, "shortest detour around a single blocked tile is 5 steps")
	assert_false(path.has(Vector2i(1, 1)), "path must not cross the reserved tile")
	assert_eq(path[0], Vector2i(0, 1))
	assert_eq(path[-1], Vector2i(2, 1))


func test_find_path_returns_empty_when_goal_fully_enclosed() -> void:
	# Goal at (1,1) is walkable but surrounded on all 4 sides by reserved
	# tiles -- unreachable despite being a valid walkable tile itself.
	var reserved: Array[Vector2i] = [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]
	var grid := WalkableGrid.new(3, 3, reserved)

	var path := grid.find_path(Vector2i(0, 0), Vector2i(1, 1))

	assert_eq(path.size(), 0)
