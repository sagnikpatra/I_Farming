## A single zone's assigned worker. Port target: no Kotlin equivalent exists
## (EPIC-M7 has no pre-migration original -- see design/gdd/worker-economy.md's
## own note that this whole system was designed fresh this session, not
## ported). Keyed by PlotKind.Kind (the economy layer's own "which zone"
## vocabulary) in GameState.worker_assignments, not by the village-board
## layer's zone-id strings -- see game_economy.gd's assign_worker() doc
## comment for why.
class_name WorkerAssignment
extends Resource

@export var plot_kind: PlotKind.Kind = PlotKind.Kind.OPEN_FIELD
## Which of EPIC-M6's 6 curated characters renders this worker on the board
## (see villager.gd's CHARACTER_SCENES). Recorded here, not re-randomized,
## so the same character consistently represents "the worker for this
## zone" across a session/reload rather than changing identity each sync.
@export var character_key: String = "ranger"


func _init(p_plot_kind: PlotKind.Kind = PlotKind.Kind.OPEN_FIELD, p_character_key: String = "ranger") -> void:
	plot_kind = p_plot_kind
	character_key = p_character_key
