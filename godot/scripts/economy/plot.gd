## A single plot of land on the player's farm. Port of GameModels.kt's `Plot`
## data class.
class_name Plot
extends Resource

@export var id: int = 0
@export var kind: PlotKind.Kind = PlotKind.Kind.OPEN_FIELD
@export var state: PlotState = null
## Only meaningful for AGROFORESTRY plots -- position within the fixed
## adjacency grid. -1 = unset (mirrors Kotlin's nullable Int?, same -1
## sentinel convention as host_type below and the epoch-ms fields in
## game_state.gd).
@export var agro_row: int = -1
@export var agro_col: int = -1
## A host plant occupies this tile permanently instead of going through the
## normal grow cycle. HostType.Kind ordinal, or HostType.NONE (-1) if unset.
@export var host_type: int = HostType.NONE


func _init(
	p_id: int = 0,
	p_kind: PlotKind.Kind = PlotKind.Kind.OPEN_FIELD,
	p_state: PlotState = null,
	p_agro_row: int = -1,
	p_agro_col: int = -1,
	p_host_type: int = HostType.NONE,
) -> void:
	id = p_id
	kind = p_kind
	state = p_state if p_state != null else PlotState.new_empty()
	agro_row = p_agro_row
	agro_col = p_agro_col
	host_type = p_host_type
