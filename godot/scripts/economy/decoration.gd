## One placed decoration on the village board. Port of GameModels.kt's
## `Decoration` data class.
class_name Decoration
extends Resource

@export var id: int = 0
## DecorationType.Kind ordinal.
@export var type: int = 0
@export var tile_x: float = 0.0
@export var tile_y: float = 0.0
@export var rotation_degrees: int = 0
@export var flipped_x: bool = false


func _init(
	p_id: int = 0,
	p_type: int = 0,
	p_tile_x: float = 0.0,
	p_tile_y: float = 0.0,
	p_rotation_degrees: int = 0,
	p_flipped_x: bool = false,
) -> void:
	id = p_id
	type = p_type
	tile_x = p_tile_x
	tile_y = p_tile_y
	rotation_degrees = p_rotation_degrees
	flipped_x = p_flipped_x
