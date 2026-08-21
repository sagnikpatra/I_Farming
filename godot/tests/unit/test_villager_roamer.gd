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
	# richer-ambient-villagers.md's Idle-Pause makes the exact tile after a
	# fixed step count depend on random rolls (should_enter_idle_pause()),
	# and a continuously back-and-forth 2-tile roamer can complete extra
	# round trips within a large step budget just as easily as it can idle
	# -- padding the step count can't make this deterministic on its own.
	# Seeded explicitly instead: seed 2 is confirmed (see
	# tests/unit/test_villager_roamer.gd's own history) to roll "no idle"
	# on this leg's should_enter_idle_pause() check, restoring the original
	# exact, fast, fully deterministic step-count assertion. Idle-Pause's
	# own behavior is covered directly by the tests below instead, which
	# force the state rather than depending on any RNG outcome.
	roamer._rng.seed = 2

	# Distance between the two tiles is 1.0 world unit; at
	# WALK_SPEED_TILES_PER_SEC=1.2 and delta=0.1 (0.12 units/step), arrival
	# snaps on the 9th _process call. 10 calls lands just past that.
	simulate(roamer, 10, 0.1)

	assert_eq(roamer.get_current_tile(), Vector2i(1, 0))


func test_roamer_keeps_moving_continuously_after_reaching_a_target() -> void:
	# Same two-tile grid: after reaching (1,0) it must eventually head back
	# toward (0,0) rather than stopping forever -- richer-ambient-
	# villagers.md allows a temporary Idle-Pause between legs now
	# (villagers.md §3.4's original "no idle pauses" no longer holds, see
	# that GDD's Overview), but never a permanent stop. Seeded the same way
	# as the test above so both legs' should_enter_idle_pause() checks roll
	# "no idle," keeping this test's exact step-count assertions
	# deterministic.
	var grid := WalkableGrid.new(2, 1, [])
	var roamer := ROAMER_SCENE.instantiate() as VillagerRoamer
	add_child_autofree(roamer)
	roamer.setup(grid, Vector2i(0, 0), 2, 1, 1.0)
	roamer._rng.seed = 2

	simulate(roamer, 10, 0.1)  # crosses to (1,0) (arrives on call 9)
	assert_eq(roamer.get_current_tile(), Vector2i(1, 0))

	simulate(roamer, 8, 0.1)  # 10 + 8 = 18 calls total -> crosses back
	assert_eq(roamer.get_current_tile(), Vector2i(0, 0))


# --- Idle-Pause (design/gdd/richer-ambient-villagers.md) -----------------------

func test_roamer_does_not_move_while_idling() -> void:
	var grid := WalkableGrid.new(3, 3, [])
	var roamer := ROAMER_SCENE.instantiate() as VillagerRoamer
	add_child_autofree(roamer)
	roamer.setup(grid, Vector2i(1, 1), 3, 3, 1.0)
	# Force Idle-Pause directly rather than hunting for an RNG seed that
	# happens to roll it -- same "control the state, not the randomness"
	# approach used elsewhere in this suite.
	roamer._state = VillagerRoamer._State.IDLE_PAUSE
	roamer._idle_timer = 3.0
	var position_before := roamer.position

	simulate(roamer, 5, 0.1)

	assert_eq(roamer.position, position_before, "roamer should not move while idling")
	assert_eq(roamer._state, VillagerRoamer._State.IDLE_PAUSE, "should still be idling -- timer hasn't elapsed")


func test_roamer_resumes_walking_after_the_idle_timer_elapses() -> void:
	var grid := WalkableGrid.new(3, 3, [])
	var roamer := ROAMER_SCENE.instantiate() as VillagerRoamer
	add_child_autofree(roamer)
	roamer.setup(grid, Vector2i(1, 1), 3, 3, 1.0)
	roamer._state = VillagerRoamer._State.IDLE_PAUSE
	roamer._idle_timer = 0.05

	simulate(roamer, 1, 0.1)  # delta (0.1) > remaining idle timer (0.05)

	assert_eq(roamer._state, VillagerRoamer._State.WALKING)


# --- Idle-Pause pure decision functions -----------------------------------------
# Same "extract the pure decision, test it directly" pattern
# board_interactor.gd's gesture functions established -- a fixed seed is
# still deterministic (this project's "no random seeds" testing rule means
# no *unseeded* RNG, not that a constant seed is forbidden -- GameData.
# demand_modifier_percent() already uses this exact pattern).

func test_should_enter_idle_pause_matches_the_configured_chance_statistically() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var true_count := 0
	var total := 2000
	for i in range(total):
		if VillagerRoamer.should_enter_idle_pause(rng):
			true_count += 1
	var ratio := float(true_count) / float(total)
	assert_almost_eq(ratio, VillagerRoamer.IDLE_PAUSE_CHANCE, 0.06)


func test_random_idle_duration_stays_within_the_configured_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321
	for i in range(200):
		var duration := VillagerRoamer.random_idle_duration(rng)
		assert_true(duration >= VillagerRoamer.IDLE_DURATION_MIN_SEC)
		assert_true(duration <= VillagerRoamer.IDLE_DURATION_MAX_SEC)


func test_random_idle_clip_always_returns_one_of_the_named_clips() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(100):
		var clip := VillagerRoamer.random_idle_clip(rng)
		assert_true(VillagerRoamer.IDLE_CLIP_NAMES.has(clip))
