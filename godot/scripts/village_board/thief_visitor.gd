class_name ThiefVisitor
extends Node3D
## The Thief Visit's on-board visiting NPC -- design/gdd/thief-system.md.
## Deliberately a standalone small class (like ChandaVisitor) rather than
## repurposing VillagerRoamer: this NPC must stay stationary during the
## entire visit, whereas VillagerRoamer's Idle-Pause state is intentionally
## short (2-5s) before resuming a random walk. Reuses Villager (rendering/
## animation) and the same PickArea-construction shape villager_roamer.gd
## established; the tile-to-world formula is duplicated here for the same
## standalone-testability reason villager_roamer.gd's own copy exists.
##
## Tapping this NPC opens the thief_interaction_sheet (player choice UI),
## showing the steal amount and three player choices: let them go, pay bribe,
## or chase them off.

const VILLAGER_SCENE: PackedScene = preload("res://scenes/village_board/villager.tscn")
const IDLE_CLIP := "Idle_A"
const STEAL_ANIM_CLIP := "Walk_A"
const RUN_AWAY_ANIM_CLIP := "Walk_A"
const _PICK_BOX_SIZE := Vector3(0.5, 1.8, 0.5)

## Unique identifier for this thief visit instance (e.g., a UUID or timestamp).
var thief_id: String = ""
## The villager character model used for rendering (e.g., "ranger", "farmer", etc).
var character_key: String = "ranger"


## `tile` must be walkable -- callers use ThiefVisitorPlacement.find_thief_tile()
## to pick one. `grid_cols`/`grid_rows`/`tile_size` must match the board this
## tile was computed against, so tile<->world math lines up with
## village_board.gd's own _grid_to_world() centering.
func setup(
	p_thief_id: String,
	p_character_key: String,
	tile: Vector2i,
	grid_cols: int,
	grid_rows: int,
	tile_size: float = 1.0
) -> void:
	thief_id = p_thief_id
	character_key = p_character_key
	position = _tile_to_world(tile, grid_cols, grid_rows, tile_size)

	var villager: Villager = VILLAGER_SCENE.instantiate()
	add_child(villager)
	villager.setup(character_key)
	villager.play_animation(IDLE_CLIP)

	_build_pick_area()


## Animates the thief stealing (walk animation + sound, etc.). Called when
## player chooses to let them go or bribe fails. Returns after animation
## completes, allowing the caller to chain further actions.
func play_steal_animation() -> void:
	var villager: Villager = _get_villager_child()
	if villager != null:
		villager.play_animation(STEAL_ANIM_CLIP)
		# Future: emit theft SFX event here (AudioManager.play_event(...))
		await get_tree().create_timer(1.0).timeout


## Animates the thief fleeing (run animation). Called when player successfully
## chases them off. Returns after animation completes.
func play_run_away_animation() -> void:
	var villager: Villager = _get_villager_child()
	if villager != null:
		villager.play_animation(RUN_AWAY_ANIM_CLIP)
		# Future: emit chase-off SFX event here
		await get_tree().create_timer(1.5).timeout


## Animates the thief being bribed (idle/peaceful animation). Called when
## player chooses to pay bribe. Returns after animation completes.
func play_bribe_animation() -> void:
	var villager: Villager = _get_villager_child()
	if villager != null:
		villager.play_animation(IDLE_CLIP)
		# Future: emit bribe SFX event here (coins-paid sound, etc.)
		await get_tree().create_timer(0.8).timeout


## design/gdd/villagers.md rule 8's PickArea shape, reused here -- a sibling
## of the Villager child, not a child of it. Matches the same construction
## pattern ChandaVisitor/VillagerRoamer established.
func _build_pick_area() -> void:
	var pick_area := Area3D.new()
	pick_area.name = "PickArea"
	pick_area.collision_layer = VillageBoard.PICK_LAYER_VILLAGERS
	pick_area.collision_mask = 0
	pick_area.monitoring = false
	pick_area.monitorable = false
	pick_area.set_meta("board_kind", "thief_visitor")
	pick_area.set_meta("thief_id", thief_id)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = _PICK_BOX_SIZE
	shape.shape = box_shape
	shape.position.y = _PICK_BOX_SIZE.y / 2.0
	pick_area.add_child(shape)
	add_child(pick_area)


func _get_villager_child() -> Villager:
	for child in get_children():
		if child is Villager:
			return child
	return null


func _tile_to_world(tile: Vector2i, grid_cols: int, grid_rows: int, tile_size: float) -> Vector3:
	var x := (float(tile.x) - float(grid_cols - 1) / 2.0) * tile_size
	var z := (float(tile.y) - float(grid_rows - 1) / 2.0) * tile_size
	return Vector3(x, 0.0, z)
