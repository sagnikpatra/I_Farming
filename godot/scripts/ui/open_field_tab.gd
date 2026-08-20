## The Open Field's management sheet -- new for EPIC-M7. Open Field never
## had a zone-level sheet before this (board_interactor.gd's
## _maybe_open_zone_sheet() previously matched ZONE_ID_OPEN_FIELD to a
## no-op "select-only" comment) since it has no build/upgrade mechanic of
## its own -- plot-level taps already handle planting/harvesting directly.
## This sheet exists solely to host worker-assignment UI (see
## worker_assignment_row.gd), the first thing Open Field has ever needed a
## zone-level sheet for.
class_name OpenFieldTab
extends VBoxContainer

@onready var _body: VBoxContainer = $Scroll/Body

var _economy: GameEconomy
var _village_board: VillageBoard


## Must be called before this instance is added under a BottomSheet's content
## slot -- same precondition/ordering guarantee as every other tab's
## configure().
func configure(economy: GameEconomy, village_board: VillageBoard) -> void:
	_economy = economy
	_village_board = village_board


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_populate()


func _populate() -> void:
	for child in _body.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "🌾 Open Field"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(header)

	var row := WorkerAssignmentRow.new()
	row.configure(_economy, _village_board, PlotKind.Kind.OPEN_FIELD)
	_body.add_child(row)
