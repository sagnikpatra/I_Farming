## The Open Field's management sheet -- new for EPIC-M7. Open Field never
## had a zone-level sheet before this (board_interactor.gd's
## _maybe_open_zone_sheet() previously matched ZONE_ID_OPEN_FIELD to a
## no-op "select-only" comment) since it has no build/upgrade mechanic of
## its own -- plot-level taps already handle planting/harvesting directly.
## This sheet exists solely to host worker-assignment UI (see
## worker_assignment_row.gd), the first thing Open Field has ever needed a
## zone-level sheet for.
##
## Track A note: this file has no locally-duplicated _make_panel()/
## _make_chunky_button()-style helpers to consolidate -- it builds no
## panels or buttons of its own (WorkerAssignmentRow owns all of that). Its
## one visible element, the header, WAS a bare default-styled `Label.new()`
## (no LabelSettings at all) -- inconsistent with every sibling sheet's
## SOIL_BROWN_DARK/drop-shadow header text and jarring next to
## worker_assignment_row.gd's own now-restyled content directly below it.
## Fixed cheaply via UiTheme now that this file is already being touched.
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

	_body.add_child(UiTheme.make_title_label(tr(&"open_field.header"), 18, UiTheme.SOIL_BROWN_DARK))

	var row := WorkerAssignmentRow.new()
	row.configure(_economy, _village_board, PlotKind.Kind.OPEN_FIELD)
	_body.add_child(row)
