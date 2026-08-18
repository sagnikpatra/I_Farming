## Harvested-but-unsold stock for one crop type, split by yield quality. Port
## of GameModels.kt's `CropStock` data class.
class_name CropStock
extends Resource

@export var normal: int = 0
@export var damaged: int = 0

## Derived, not persisted -- mirrors Kotlin's `val total: Int get() = ...`.
var total: int:
	get:
		return normal + damaged


func _init(p_normal: int = 0, p_damaged: int = 0) -> void:
	normal = p_normal
	damaged = p_damaged
