class_name VillagerRoamer
extends Node3D
## Drives one Villager (see villager.gd) continuously between random
## walkable tiles on a WalkableGrid, per design/gdd/villagers.md's Detailed
## Rules: no idle pauses (§3.4 -- the sourced animation library has no
## standing-idle clip), no player interaction, no persistence. This class
## owns movement/facing/target-picking only; it does not know about
## GameState, spawning/population sizing, or how the walkable grid was
## built -- see the GDD's "Next Steps" for what's still unwired.

const VILLAGER_SCENE: PackedScene = preload("res://scenes/village_board/villager.tscn")

## design/gdd/villagers.md §4 Formulas table -- proposed values, not yet
## balance-tested on-device (documented there as such).
const WALK_SPEED_TILES_PER_SEC: float = 1.2

var _grid: WalkableGrid
var _tile_size: float = 1.0
var _grid_cols: int = 1
var _grid_rows: int = 1
var _villager: Villager
var _current_tile: Vector2i
var _pending_path: Array[Vector2i] = []
var _rng := RandomNumberGenerator.new()


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

	if _pending_path.is_empty():
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
