extends GutTest
## Coverage for VillagerSpawner (godot/scripts/village_board/villager_spawner.gd)
## -- ties VillageSnapshotMapper.villager_count()/build_walkable_grid() to
## actual VillagerRoamer instances (wired live into village_board.gd since
## EPIC-M6), reduced by however many villagers are currently assigned as
## EPIC-M7 workers (see the worker-station section below). These tests
## cover the spawner in isolation against a plain Node3D parent.

const GRID_COLS: int = 10
const GRID_ROWS: int = 12

var eco: GameEconomy
var parent: Node3D


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000_000
	parent = Node3D.new()
	add_child_autofree(parent)


func test_sync_spawns_villager_count_roamers() -> void:
	var spawner := VillagerSpawner.new(parent, GRID_COLS, GRID_ROWS)

	spawner.sync(eco.state)

	# Fresh state: unlocked_zone_count=2 -> villager_count=3 (see
	# test_village_snapshot_mapper.gd's test_villager_count_is_two_at_the_floor
	# -- same formula, same expected result).
	assert_eq(spawner.get_roamer_count(), 3)


func test_sync_spawns_at_distinct_start_tiles() -> void:
	var spawner := VillagerSpawner.new(parent, GRID_COLS, GRID_ROWS)

	spawner.sync(eco.state)

	var seen_tiles: Dictionary = {}
	for roamer in spawner.get_roamers():
		var tile := roamer.get_current_tile()
		assert_false(seen_tiles.has(tile), "no two villagers should start on the same tile")
		seen_tiles[tile] = true


func test_sync_replaces_previous_population_on_second_call() -> void:
	var spawner := VillagerSpawner.new(parent, GRID_COLS, GRID_ROWS)
	spawner.sync(eco.state)
	var first_population := spawner.get_roamers()

	eco.buy_polyhouse()  # unlocked_zone_count 2 -> 3 -> villager_count clamp(2+floor(3*0.75),2,6) = clamp(4,2,6) = 4
	spawner.sync(eco.state)
	var second_population := spawner.get_roamers()

	assert_eq(second_population.size(), 4)
	assert_ne(second_population[0], first_population[0], "sync() should respawn fresh instances, not reuse the old ones")


func test_sync_spawns_nothing_when_board_has_no_walkable_tiles() -> void:
	# A 2x2 board is entirely covered by Farmhouse's own 2x2 footprint at
	# its default anchor (0,0) -- zero walkable tiles, a real degenerate
	# case the spawner must not crash on.
	var spawner := VillagerSpawner.new(parent, 2, 2)

	spawner.sync(eco.state)

	assert_eq(spawner.get_roamer_count(), 0)


func test_clear_removes_all_roamers() -> void:
	var spawner := VillagerSpawner.new(parent, GRID_COLS, GRID_ROWS)
	spawner.sync(eco.state)
	assert_gt(spawner.get_roamer_count(), 0)

	spawner.clear()

	assert_eq(spawner.get_roamer_count(), 0)


# --- EPIC-M7: roaming population shrinks by active worker assignments ---------

func test_sync_spawns_fewer_roamers_per_active_worker_assignment() -> void:
	# Fresh state: villager_count() = 3 (see test_sync_spawns_villager_count_roamers
	# above). One worker assignment should reduce roaming to 2.
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")
	var spawner := VillagerSpawner.new(parent, GRID_COLS, GRID_ROWS)

	spawner.sync(eco.state)

	assert_eq(spawner.get_roamer_count(), 2)


func test_sync_roaming_count_at_maximum_worker_saturation() -> void:
	# Unlock every worker-eligible zone (needed for assign_worker() to
	# accept the assignment -- see game_economy.gd's _is_plot_kind_unlocked()),
	# then assign all 4 -- the most workers any real reachable game state
	# can have. Agroforestry is deliberately NOT bought (not worker-eligible,
	# see game_economy.gd's _WORKER_ELIGIBLE_PLOT_KINDS), so
	# unlocked_zone_count = 5 (farmhouse+mandi+these 3), giving
	# villager_count() = clamp(2+floor(5*0.75),2,6) = 5 -- not the full-6
	# ceiling test_village_snapshot_mapper.gd's ...clamped_to_six... test
	# covers, which does buy Agroforestry too.
	eco.buy_polyhouse()
	eco.buy_aquaculture()
	eco.buy_vertical_farm()
	eco.assign_worker(PlotKind.Kind.OPEN_FIELD, "ranger")
	eco.assign_worker(PlotKind.Kind.POLYHOUSE, "knight")
	eco.assign_worker(PlotKind.Kind.AQUACULTURE, "mage")
	eco.assign_worker(PlotKind.Kind.VERTICAL_FARM, "rogue")
	var spawner := VillagerSpawner.new(parent, GRID_COLS, GRID_ROWS)

	spawner.sync(eco.state)

	assert_eq(spawner.get_roamer_count(), 1, "villager_count()=5 here, minus 4 assigned workers = 1")
