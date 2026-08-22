class_name VillagerRoamer
extends Node3D
## Drives one Villager (see villager.gd) continuously between random
## walkable tiles on a WalkableGrid, no player interaction, no persistence
## (design/gdd/villagers.md's Detailed Rules, EPIC-M6). This class owns
## movement/facing/target-picking only; it does not know about GameState,
## spawning/population sizing, or how the walkable grid was built -- see
## the GDD's "Next Steps" for what's still unwired.
##
## design/gdd/richer-ambient-villagers.md: villagers.md §3.4's original
## "no idle pauses (the sourced animation library has no standing-idle
## clip)" no longer holds -- direct inspection of Rig_Medium_General.glb
## found real Idle_A/Idle_B clips. Occasionally idle-pauses between walk
## legs now (see the Idle-Pause state below).

const VILLAGER_SCENE: PackedScene = preload("res://scenes/village_board/villager.tscn")

## design/gdd/villagers.md §4 Formulas table -- proposed values, not yet
## balance-tested on-device (documented there as such).
const WALK_SPEED_TILES_PER_SEC: float = 1.2

## design/gdd/richer-ambient-villagers.md §4 Formulas.
const IDLE_PAUSE_CHANCE: float = 0.35
const IDLE_DURATION_MIN_SEC: float = 2.0
const IDLE_DURATION_MAX_SEC: float = 5.0
const IDLE_CLIP_NAMES: Array[String] = ["Idle_A", "Idle_B"]

## design/gdd/richer-ambient-villagers.md's Congregating stretch goal
## (§4 Formulas). In tiles, scaled by _tile_size at call sites.
const CONGREGATE_DISTANCE_TILES: float = 1.6

enum _State { WALKING, IDLE_PAUSE }

var _grid: WalkableGrid
var _tile_size: float = 1.0
var _grid_cols: int = 1
var _grid_rows: int = 1
var _villager: Villager
var _current_tile: Vector2i
var _pending_path: Array[Vector2i] = []
var _rng := RandomNumberGenerator.new()
var _state: _State = _State.WALKING
var _idle_timer: float = 0.0

## Optional, set by the owning VillagerSpawner after all roamers in a
## population exist (see villager_spawner.gd). Called every frame while
## idling to fetch other villagers' current world positions -- deliberately
## a lazily-invoked Callable rather than a direct array/spawner reference,
## so this class stays testable standalone (every existing test of this
## class predates congregating and never sets this, so it's simply skipped)
## and so ordering during population construction doesn't matter (the
## callable is only ever invoked well after the full population exists).
## Left unset (an invalid Callable) means "no congregating" -- not an error.
var other_villager_positions_provider: Callable


## Must be called once before this node starts processing. `grid` is a
## pre-built WalkableGrid (see walkable_grid.gd -- building one from real
## GameState is separate, not-yet-wired integration work). `start_tile`
## must be walkable on `grid`. `grid_cols`/`grid_rows`/`tile_size` must
## match the board this grid was built for, so tile<->world math lines up
## with village_board.gd's own _grid_to_world() centering -- duplicated
## here rather than depending on a live VillageBoard node, so this
## component stays testable without instancing the whole board scene.
func setup(
	grid: WalkableGrid,
	start_tile: Vector2i,
	grid_cols: int,
	grid_rows: int,
	tile_size: float = 1.0,
	character_key: String = "ranger"
) -> void:
	_grid = grid
	_grid_cols = grid_cols
	_grid_rows = grid_rows
	_tile_size = tile_size
	_current_tile = start_tile
	position = _tile_to_world(start_tile)

	_villager = VILLAGER_SCENE.instantiate()
	add_child(_villager)
	_villager.setup(character_key)

	_pick_new_target()


func _process(delta: float) -> void:
	if _grid == null:
		return  # setup() not called yet

	if _state == _State.IDLE_PAUSE:
		_idle_timer -= delta
		if other_villager_positions_provider.is_valid():
			var target: Variant = nearest_congregate_target(position, other_villager_positions_provider.call(), _tile_size)
			if target != null:
				_face_direction((target as Vector3 - position))
		if _idle_timer <= 0.0:
			_state = _State.WALKING
			# Pick the next target immediately rather than just flipping the
			# state flag -- _pending_path is still empty at this point (it
			# was never touched while idling), so leaving it empty would
			# make next frame's `_pending_path.is_empty()` branch below
			# re-roll should_enter_idle_pause() again against the same
			# still-empty path, chaining into another idle pause instead of
			# resuming. The chance should fire once per arrival, not repeat
			# indefinitely while stuck in the empty-path state.
			_pick_new_target()
			if not _pending_path.is_empty():
				_villager.play_animation(Villager.DEFAULT_ANIMATION)
		return

	if _pending_path.is_empty():
		if should_enter_idle_pause(_rng):
			_state = _State.IDLE_PAUSE
			_idle_timer = random_idle_duration(_rng)
			_villager.play_animation(random_idle_clip(_rng))
			return
		_pick_new_target()
		if _pending_path.is_empty():
			return  # nowhere walkable to go -- degenerate board state

	var target_world := _tile_to_world(_pending_path[0])
	var to_target := target_world - position
	to_target.y = 0.0
	var distance := to_target.length()
	var step := WALK_SPEED_TILES_PER_SEC * _tile_size * delta

	if distance <= step:
		position = target_world
		_current_tile = _pending_path[0]
		_pending_path.remove_at(0)
	else:
		var direction := to_target / distance
		position += direction * step
		_face_direction(direction)


## design/gdd/richer-ambient-villagers.md §8's own acceptance criterion:
## the idle chance/duration/clip choice must be independently testable as
## pure logic, not coupled to _process()'s frame-delta accumulation --
## same "extract the pure decision, test it directly" pattern
## board_interactor.gd's gesture functions already established.
static func should_enter_idle_pause(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < IDLE_PAUSE_CHANCE


static func random_idle_duration(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(IDLE_DURATION_MIN_SEC, IDLE_DURATION_MAX_SEC)


static func random_idle_clip(rng: RandomNumberGenerator) -> String:
	return IDLE_CLIP_NAMES[rng.randi_range(0, IDLE_CLIP_NAMES.size() - 1)]


## design/gdd/richer-ambient-villagers.md's Congregating stretch goal.
## Pure: given this villager's own world position and every other
## villager's current world position, returns the nearest one within
## CONGREGATE_DISTANCE_TILES (scaled by `tile_size`), or null if none are
## close enough. Deliberately has zero knowledge of who's idling or
## walking, and zero two-way coordination between roamers -- each roamer
## independently re-checks this every idle-pause frame (see _process()),
## so if a villager happens to idle-pause near another (whether or not
## that other one is idling too), it turns to face them. Two villagers
## idling near each other at the same time reads as "chatting" for free,
## without either roamer needing to know the other exists as anything more
## than a position.
static func nearest_congregate_target(own_position: Vector3, other_positions: Array[Vector3], tile_size: float) -> Variant:
	var nearest_position: Vector3
	var nearest_distance := INF
	for other_position in other_positions:
		var distance := own_position.distance_to(other_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_position = other_position
	if nearest_distance <= CONGREGATE_DISTANCE_TILES * tile_size:
		return nearest_position
	return null


func get_current_tile() -> Vector2i:
	return _current_tile


func get_villager() -> Villager:
	return _villager


func _pick_new_target() -> void:
	var target := _grid.random_walkable_tile(_rng, _current_tile)
	var path := _grid.find_path(_current_tile, target)
	if path.size() > 1:
		_pending_path = path.slice(1)  # drop the starting tile -- already there


## Mirrors village_board.gd's private _grid_to_world() centering formula.
## Duplicated deliberately (small, ~3 lines) rather than depending on a
## live VillageBoard node -- same "decoupled EPIC-M6 component" reasoning
## already used for villager.gd's toon-shading duplication.
func _tile_to_world(tile: Vector2i) -> Vector3:
	var x := (float(tile.x) - float(_grid_cols - 1) / 2.0) * _tile_size
	var z := (float(tile.y) - float(_grid_rows - 1) / 2.0) * _tile_size
	return Vector3(x, 0.0, z)


func _face_direction(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	rotation.y = atan2(direction.x, direction.z)
