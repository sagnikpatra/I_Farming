## A structure zone's custom world position/orientation. Port of
## GameModels.kt's `ZoneAnchor` data class. See GameState.zone_layout and the
## village board's drag/rotate/flip features (owned by EPIC-M1/M3, not this
## epic).
class_name ZoneAnchor
extends Resource

@export var tile_x: float = 0.0
@export var tile_y: float = 0.0
@export var rotation_degrees: int = 0
@export var flipped_x: bool = false


func _init(p_tile_x: float = 0.0, p_tile_y: float = 0.0, p_rotation_degrees: int = 0, p_flipped_x: bool = false) -> void:
	tile_x = p_tile_x
	tile_y = p_tile_y
	rotation_degrees = p_rotation_degrees
	flipped_x = p_flipped_x
