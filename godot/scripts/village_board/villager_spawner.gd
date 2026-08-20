class_name VillagerSpawner
extends RefCounted
## Spawns and maintains ambient roaming villagers into a target parent
## node (intended to be the village board's ActorLayer) from live
## GameState, per design/gdd/villagers.md. Ties together
## VillageSnapshotMapper.villager_count()/build_walkable_grid() and
## VillagerRoamer -- the last unbuilt piece of EPIC-M6's roaming chain.
##
## Deliberately decoupled from village_board.gd's rebuild(): that runs on
## every GameState change, including simple plot-timer ticks, but villager
## population should only actually change when unlocked-zone count
## changes. Callers own deciding *when* to call sync() (e.g. once at board
## load, and again after any buy_*() call that might have changed
## villager_count()) -- this class does not poll or hook into GameState
## changes itself. Per the GDD's "no persistence" rule, there is
## deliberately no attempt to preserve a villager's identity/position
## across a sync() -- the population is torn down and respawned fresh
## each time, which is simplest and matches "re-randomize each load."
##
## EPIC-M7: villagers currently assigned as a zone's worker are stationed
## there (village_board.gd's WorkerStation/_sync_worker_stations(), the
## "called" half of villagers.md §3.6) instead of roaming ambiently -- the
## roaming population this class spawns shrinks by the number of active
## GameState.worker_assignments, per "workers are assigned FROM the
## existing roster," not additional to it.

const ROAMER_SCENE: PackedScene = preload("res://scenes/village_board/villager_roamer.tscn")

## All 6 KayKit characters, visually verified 2026-08-21 with
## villager.gd's prop-hiding + accent-recolor passes applied -- see that
## file's own doc comment for the one noted exception (rogue_hooded keeps
## a sculpted-in hood, judged acceptable, not a defect). Each spawned
## villager gets a random key from this list for visual variety, rather
## than one repeated character.
const CHARACTER_KEYS: Array[String] = [
	"barbarian", "knight", "mage", "ranger", "rogue", "rogue_hooded",
]

var _parent: Node3D
var _grid_cols: int
var _grid_rows: int
var _tile_size: float
var _roamers: Array[VillagerRoamer] = []
var _rng := RandomNumberGenerator.new()


func _init(parent: Node3D, grid_cols: int, grid_rows: int, tile_size: float = 1.0) -> void:
	_parent = parent
	_grid_cols = grid_cols
	_grid_rows = grid_rows
	_tile_size = tile_size


## Rebuilds the ambient-roaming population to match `state`'s current
## villager_count() minus however many are currently assigned as workers
## (state.worker_assignments.size() -- see class doc), against a fresh
## WalkableGrid built from `state`. If the board has fewer distinct
## walkable tiles than the target count (a degenerate case the real board
## should never actually reach -- see the GameState-integration check
## finding 63/120 tiles walkable even in the most conservative fresh-game
## state), spawns one villager per distinct walkable tile rather than
## stacking multiple villagers on the same tile or erroring.
func sync(state: GameState) -> void:
	_clear()

	var grid := VillageSnapshotMapper.build_walkable_grid(state, _grid_cols, _grid_rows)
	var walkable := grid.get_walkable_tiles()
	if walkable.is_empty():
		return

	var target_count := VillageSnapshotMapper.villager_count(state)
	var roaming_count: int = maxi(target_count - state.worker_assignments.size(), 0)
	var start_tiles := _pick_distinct_tiles(walkable, mini(roaming_count, walkable.size()))

	for start_tile in start_tiles:
		var roamer := ROAMER_SCENE.instantiate() as VillagerRoamer
		_parent.add_child(roamer)
		var character_key: String = CHARACTER_KEYS[_rng.randi_range(0, CHARACTER_KEYS.size() - 1)]
		roamer.setup(grid, start_tile, _grid_cols, _grid_rows, _tile_size, character_key)
		_roamers.append(roamer)


func get_roamer_count() -> int:
	return _roamers.size()


func get_roamers() -> Array[VillagerRoamer]:
	return _roamers.duplicate()


## Frees every currently-spawned villager. Exposed publicly so a caller
## can depopulate the board entirely (e.g. leaving the village scene)
## without needing to call sync() with a throwaway state.
func clear() -> void:
	_clear()


func _clear() -> void:
	for roamer in _roamers:
		if is_instance_valid(roamer):
			roamer.queue_free()
	_roamers.clear()


## Fisher-Yates partial shuffle via this spawner's own seedable RNG (not
## Array.shuffle(), which uses the global RNG and isn't deterministic for
## tests) -- returns the first `count` tiles of a shuffled copy of
## `tiles`, so villagers don't all start stacked on the same tile.
func _pick_distinct_tiles(tiles: Array[Vector2i], count: int) -> Array[Vector2i]:
	var pool: Array[Vector2i] = tiles.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp: Vector2i = pool[i]
		pool[i] = pool[j]
		pool[j] = temp
	return pool.slice(0, count)
