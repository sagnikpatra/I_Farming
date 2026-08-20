extends GutTest
## Coverage for VillagerRoamer (godot/scripts/village_board/villager_roamer.gd)
## -- movement/target-picking on top of WalkableGrid + Villager. Actual
## walking smoothness/animation was confirmed visually via a windowed
## real-GPU render (same technique used for Villager's own verification);
## these tests guard the deterministic parts: position math and continuous
## re-targeting.

const ROAMER_SCENE: PackedScene = preload("res://scenes/village_board/villager_roamer.tscn")


func test_setup_positions_roamer_at_start_tile_world_position() -> void:
	var grid := WalkableGrid.new(3, 3, [])
	var roamer := ROAMER_SCENE.instantiate() as VillagerRoamer
	add_child_autofree(roamer)

	roamer.setup(grid, Vector2i(1, 1), 3, 3, 1.0)

	# grid_cols=3 -> center col is 1 -> world x = (1 - 1) * 1.0 = 0
	assert_almost_eq(roamer.position.x, 0.0, 0.001)
	assert_almost_eq(roamer.position.z, 0.0, 0.001)


func test_setup_spawns_a_villager_child_with_an_animation_player() -> void:
	var grid := WalkableGrid.new(3, 3, [])
	var roamer := ROAMER_SCENE.instantiate() as VillagerRoamer
	add_child_autofree(roamer)

	roamer.setup(grid, Vector2i(0, 0), 3, 3)

	assert_not_null(roamer.get_villager())
	assert_not_null(roamer.get_villager().get_animation_player())


func test_roamer_moves_toward_its_target_over_time() -> void:
	# Two-tile grid: only one possible target, so movement is deterministic.
	var grid := WalkableGrid.new(2, 1, [])
	var roamer := ROAMER_SCENE.instantiate() as VillagerRoamer
	add_child_autofree(roamer)
	roamer.setup(grid, Vector2i(0, 0), 2, 1, 1.0)
	var start_position := roamer.position

	simulate(roamer, 5, 0.1)  # 0.5s of simulated movement at 1.2 tiles/sec

	assert_ne(roamer.position, start_position, "roamer should have moved from its start position")


func test_roamer_reaches_and_switches_to_the_only_other_tile() -> void:
	var grid := WalkableGrid.new(2, 1, [])
	var roamer := ROAMER_SCENE.instantiate() as VillagerRoamer
	add_child_autofree(roamer)
	roamer.setup(grid, Vector2i(0, 0), 2, 1, 1.0)

	# Distance between the two tiles is 1.0 world unit; at
	# WALK_SPEED_TILES_PER_SEC=1.2 and delta=0.1 (0.12 units/step), arrival
	# snaps on the 9th _process call. 10 calls lands just past that and
	# comfortably before the ~18th-call return-trip arrival back at (0,0)
	# (see test_roamer_keeps_moving_continuously... below for that leg).
	simulate(roamer, 10, 0.1)

	assert_eq(roamer.get_current_tile(), Vector2i(1, 0))


func test_roamer_keeps_moving_continuously_after_reaching_a_target() -> void:
	# Same two-tile grid: after reaching (1,0) it must immediately head
	# back toward (0,0) rather than stopping -- no idle pauses, per
	# design/gdd/villagers.md Detailed Rules §3.4. Step counts follow the
	# same per-call arithmetic as the test above: arrival at (1,0) on call
	# 9, arrival back at (0,0) on call 18 (9 calls for each leg).
	var grid := WalkableGrid.new(2, 1, [])
	var roamer := ROAMER_SCENE.instantiate() as VillagerRoamer
	add_child_autofree(roamer)
	roamer.setup(grid, Vector2i(0, 0), 2, 1, 1.0)

	simulate(roamer, 10, 0.1)  # crosses to (1,0) (arrives on call 9)
	assert_eq(roamer.get_current_tile(), Vector2i(1, 0))

	simulate(roamer, 8, 0.1)  # 10 + 8 = 18 calls total -> crosses back
	assert_eq(roamer.get_current_tile(), Vector2i(0, 0))
