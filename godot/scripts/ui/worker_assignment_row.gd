## Reusable "assign/unassign a worker" UI section (design/gdd/worker-economy.md),
## embedded in every worker-eligible zone's management sheet
## (polyhouse_tab.gd, niche_farming_tab.gd for both Aquaculture and
## Vertical Farm, open_field_tab.gd) -- one row per PlotKind.Kind. Not a
## scene file, matching this project's established "procedural widget
## construction in GDScript" style (see polyhouse_tab.gd's own class doc)
## -- instantiated directly via WorkerAssignmentRow.new() and configure().
##
## VISUAL NOTE: uses plain default-styled Godot controls (Label, Button,
## OptionButton), not the ChunkyButton/StyleBoxFlat/drop-shadow-LabelSettings
## look every other sheet in this project uses. Deliberate scope
## boundary for this first functional slice -- matching visual styling to
## the rest of the UI is a follow-up polish pass, not done here (see
## coding-standards.md's "complete it, then polish it" precedent from
## earlier this session).
class_name WorkerAssignmentRow
extends VBoxContainer

## villager.gd's CHARACTER_SCENES keys -> a display name for the picker.
## Kept here rather than reusing Villager.CHARACTER_SCENES.keys() directly
## so this file doesn't need to know that class's internal structure, just
## the key strings GameEconomy.assign_worker() expects.
const CHARACTER_DISPLAY_NAMES: Dictionary = {
	"barbarian": "Barbarian",
	"knight": "Knight",
	"mage": "Mage",
	"ranger": "Ranger",
	"rogue": "Rogue",
	"rogue_hooded": "Hooded Rogue",
}

var _economy: GameEconomy
var _village_board: VillageBoard
var _plot_kind: PlotKind.Kind
var _option_button: OptionButton


## Must be called once, immediately after instantiation and before adding
## this to a parent sheet -- same configure()-then-add ordering every
## other tab in this project already requires.
func configure(economy: GameEconomy, village_board: VillageBoard, plot_kind: PlotKind.Kind) -> void:
	_economy = economy
	_village_board = village_board
	_plot_kind = plot_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	_populate()


## Public so a parent sheet can force a repopulate after its own action
## might have changed the assignment out from under this row (not
## currently needed by any caller, but a cheap guarantee to offer).
func refresh() -> void:
	_populate()


func _populate() -> void:
	for child in get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "👤 Worker"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	var assignment: WorkerAssignment = _economy.get_worker_assignment(_plot_kind)
	if assignment != null:
		_populate_assigned(assignment)
	else:
		_populate_unassigned()


func _populate_assigned(assignment: WorkerAssignment) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	var status_label := Label.new()
	var display_name: String = CHARACTER_DISPLAY_NAMES.get(assignment.character_key, assignment.character_key)
	status_label.text = "%s is working this zone." % display_name
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(status_label)

	var unassign_button := Button.new()
	unassign_button.text = "Unassign"
	unassign_button.focus_mode = Control.FOCUS_NONE
	unassign_button.pressed.connect(_on_unassign_pressed)
	row.add_child(unassign_button)

	add_child(row)


func _populate_unassigned() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	_option_button = OptionButton.new()
	_option_button.focus_mode = Control.FOCUS_NONE
	for key in CHARACTER_DISPLAY_NAMES.keys():
		_option_button.add_item(CHARACTER_DISPLAY_NAMES[key])
	row.add_child(_option_button)

	var assign_button := Button.new()
	assign_button.text = "Assign"
	assign_button.focus_mode = Control.FOCUS_NONE
	assign_button.pressed.connect(_on_assign_pressed)
	row.add_child(assign_button)

	add_child(row)


func _on_assign_pressed() -> void:
	var keys: Array = CHARACTER_DISPLAY_NAMES.keys()
	var selected_index: int = _option_button.selected if _option_button.selected >= 0 else 0
	var selected_key: String = keys[selected_index]
	_economy.assign_worker(_plot_kind, selected_key)
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_unassign_pressed() -> void:
	_economy.unassign_worker(_plot_kind)
	_village_board.persist_and_rebuild_if_dirty()
	_populate()
