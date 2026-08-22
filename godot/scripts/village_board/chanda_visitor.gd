class_name ChandaVisitor
extends Node3D
## The Chanda Visit's on-board visiting NPC -- design/gdd/festival-visiting-
## npcs.md's "future stretch" (a real 3D visitor instead of a sheet-only
## presentation), decided and built 2026-08-22. Deliberately its own small
## class rather than a repurposed VillagerRoamer: this NPC must stay
## stationary for the visit's entire ~30-minute active window, and
## VillagerRoamer's own Idle-Pause state (richer-ambient-villagers.md) is
## intentionally short (2-5s) before resuming a random walk -- reusing it
## would make the visitor wander off almost immediately, the opposite of
## "someone waiting at your door." Reuses Villager (rendering/animation)
## and the same PickArea-construction shape villager_roamer.gd already
## established; the tile-to-world formula is duplicated here for the same
## standalone-testability reason villager_roamer.gd's own copy exists --
## see that file's setup() doc comment.
##
## Tapping this NPC opens the *same* Events sheet the LiveOps banner
## already opens (see board_interactor.gd's _open_chanda_visit_sheet() and
## hud.gd's open_events_sheet()) -- not a new give/decline UI. The board
## presence is a second, cosmetic discovery path into the existing flow,
## not a replacement for it.

const VILLAGER_SCENE: PackedScene = preload("res://scenes/village_board/villager.tscn")
const IDLE_CLIP := "Idle_A"
const _PICK_BOX_SIZE := Vector3(0.5, 1.8, 0.5)

## Public (not underscore-prefixed) -- matches VillagerRoamer.character_key's
## own visibility rationale (available for any future debug/inspection use).
var character_key: String = "ranger"


## `tile` must be walkable -- callers use
## ChandaVisitorPlacement.find_visitor_tile() to pick one adjacent to the
## Farmhouse's current footprint. `grid_cols`/`grid_rows`/`tile_size` must
## match the board this tile was computed against, so tile<->world math
## lines up with village_board.gd's own _grid_to_world() centering (same
## duplication convention as villager_roamer.gd's setup()).
func setup(
	p_character_key: String,
	tile: Vector2i,
	grid_cols: int,
	grid_rows: int,
	tile_size: float = 1.0
) -> void:
	character_key = p_character_key
	position = _tile_to_world(tile, grid_cols, grid_rows, tile_size)

	var villager: Villager = VILLAGER_SCENE.instantiate()
	add_child(villager)
	villager.setup(character_key)
	villager.play_animation(IDLE_CLIP)

	_build_pick_area()


## design/gdd/villagers.md rule 8's PickArea shape, reused here -- a
## sibling of the Villager child, not a child of it. This node never
## moves once placed, so the "moves automatically with the roamer's own
## transform" rationale villager_roamer.gd cites doesn't strictly apply,
## but keeping the same sibling shape avoids a second PickArea-placement
## convention existing for no reason.
func _build_pick_area() -> void:
	var pick_area := Area3D.new()
	pick_area.name = "PickArea"
	pick_area.collision_layer = VillageBoard.PICK_LAYER_VILLAGERS
	pick_area.collision_mask = 0
	pick_area.monitoring = false
	pick_area.monitorable = false
	pick_area.set_meta("board_kind", "chanda_visitor")
	pick_area.set_meta("board_id", character_key)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = _PICK_BOX_SIZE
	shape.shape = box_shape
	shape.position.y = _PICK_BOX_SIZE.y / 2.0
	pick_area.add_child(shape)
	add_child(pick_area)


func _tile_to_world(tile: Vector2i, grid_cols: int, grid_rows: int, tile_size: float) -> Vector3:
	var x := (float(tile.x) - float(grid_cols - 1) / 2.0) * tile_size
	var z := (float(tile.y) - float(grid_rows - 1) / 2.0) * tile_size
	return Vector3(x, 0.0, z)
