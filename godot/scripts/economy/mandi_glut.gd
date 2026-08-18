## Oversupply pressure for one crop on the Mandi market. Port of
## GameModels.kt's `MandiGlut` data class. [value] decays continuously toward
## zero over real time from [updated_at_epoch_ms] -- see GameEconomy's
## current_glut(). This is what makes selling a lot of one crop through the
## Mandi temporarily depress its own price.
class_name MandiGlut
extends Resource

@export var value: float = 0.0
@export var updated_at_epoch_ms: int = 0


func _init(p_value: float = 0.0, p_updated_at_epoch_ms: int = 0) -> void:
	value = p_value
	updated_at_epoch_ms = p_updated_at_epoch_ms
