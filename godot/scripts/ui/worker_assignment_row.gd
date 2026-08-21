## Reusable "assign/unassign a worker" UI section (design/gdd/worker-economy.md),
## embedded in every worker-eligible zone's management sheet
## (polyhouse_tab.gd, niche_farming_tab.gd for both Aquaculture and
## Vertical Farm, open_field_tab.gd) -- one row per PlotKind.Kind. Not a
## scene file, matching this project's established "procedural widget
## construction in GDScript" style (see polyhouse_tab.gd's own class doc)
## -- instantiated directly via WorkerAssignmentRow.new() and configure().
##
## Track A (design/art/ui-visual-direction-2026-08.md): this file was
## explicitly named as still using plain default-styled Godot controls
## (Label, Button, OptionButton) -- the one sheet-embedded widget that never
## got the ChunkyButton/StyleBoxTexture/drop-shadow-LabelSettings treatment
## every sibling sheet uses. Now wrapped in a UiTheme card and routes every
## label/button through ui_theme.gd like everywhere else. OptionButton has
## no UiTheme constructor of its own (out of scope to add one this round --
## ui_theme.gd is frozen for this pass, per the task boundary), so this file
## builds its own StyleBoxTexture skin locally, directly off UiTheme's
## PUBLIC texture constants (the same BUTTON_LONG_GREY_TEXTURE family
## UiTheme.make_chunky_button() itself tints) -- not a new visual language,
## just a one-off application of the existing one to a control type UiTheme
## doesn't wrap yet (see _style_option_button()).
##
## No new disabled-button state needed here: GameEconomy.assign_worker()
## has no coin cost (see that function's own doc comment) and every call
## site only ever instantiates this row once its host zone already exists
## (niche_farming_tab.gd's has_aquaculture/has_vertical_farm branches,
## polyhouse_tab.gd's has_polyhouse branch, or unconditionally for
## OPEN_FIELD, which needs no unlock at all) -- Assign is always a valid
## action whenever this row is on screen.
class_name WorkerAssignmentRow
extends VBoxContainer

const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK
const WOOD_BROWN_LIGHT := UiTheme.WOOD_BROWN_MID
const FIELD_GREEN := UiTheme.FIELD_GREEN
const SAFFRON_DARK := UiTheme.SAFFRON_DARK

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
	_populate()


## Public so a parent sheet can force a repopulate after its own action
## might have changed the assignment out from under this row (not
## currently needed by any caller, but a cheap guarantee to offer).
func refresh() -> void:
	_populate()


func _populate() -> void:
	for child in get_children():
		child.queue_free()

	var card := UiTheme.make_panel(WOOD_BROWN_LIGHT)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)

	box.add_child(UiTheme.make_title_label("👤 Worker", 16))

	var assignment: WorkerAssignment = _economy.get_worker_assignment(_plot_kind)
	if assignment != null:
		box.add_child(_build_assigned_row(assignment))
	else:
		box.add_child(_build_unassigned_row())

	card.add_child(box)
	add_child(card)


func _build_assigned_row(assignment: WorkerAssignment) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	var display_name: String = CHARACTER_DISPLAY_NAMES.get(assignment.character_key, assignment.character_key)
	var status_label := UiTheme.make_title_label("%s is working this zone." % display_name, 13, Color.WHITE, false)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(status_label)

	var unassign_button := UiTheme.make_chunky_button("Unassign", SOIL_BROWN_DARK)
	unassign_button.pressed.connect(_on_unassign_pressed)
	row.add_child(unassign_button)

	return row


func _build_unassigned_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	_option_button = OptionButton.new()
	_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in CHARACTER_DISPLAY_NAMES.keys():
		_option_button.add_item(CHARACTER_DISPLAY_NAMES[key])
	_style_option_button(_option_button)
	row.add_child(_option_button)

	var assign_button := UiTheme.make_chunky_button("Assign", FIELD_GREEN)
	assign_button.pressed.connect(_on_assign_pressed)
	row.add_child(assign_button)

	return row


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


# ---------------------------------------------------------------------------
# OptionButton chrome -- see class doc for why this is built locally rather
# than added to ui_theme.gd this round. OptionButton extends Button, so it
# accepts the exact same "normal"/"hover"/"pressed"/"focus"/"disabled"
# StyleBoxTexture override slots UiTheme.make_chunky_button() sets, just
# applied here directly against UiTheme's public texture constants instead
# of through that private helper (_tinted_button_stylebox() is
# underscore-prefixed/internal to ui_theme.gd, not meant to be called from
# outside it).
# ---------------------------------------------------------------------------

func _style_option_button(option_button: OptionButton) -> void:
	option_button.focus_mode = Control.FOCUS_NONE
	option_button.custom_minimum_size = Vector2(0, 48)

	var normal_style := _tinted_option_stylebox(false)
	var pressed_style := _tinted_option_stylebox(true)
	option_button.add_theme_stylebox_override("normal", normal_style)
	option_button.add_theme_stylebox_override("hover", normal_style)
	option_button.add_theme_stylebox_override("focus", normal_style)
	option_button.add_theme_stylebox_override("pressed", pressed_style)
	option_button.add_theme_stylebox_override("disabled", normal_style)

	option_button.add_theme_font_override("font", UiTheme.font_semibold())
	option_button.add_theme_font_size_override("font_size", 14)
	for color_slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		option_button.add_theme_color_override(color_slot, Color.WHITE)


func _tinted_option_stylebox(pressed: bool) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	# WOOD_BROWN_MID uses the kit's own painted "brown" family untinted --
	# same rule UiTheme._tinted_button_stylebox() documents for role_color
	# WOOD_BROWN_MID call sites.
	style.texture = UiTheme.BUTTON_LONG_BROWN_PRESSED_TEXTURE if pressed else UiTheme.BUTTON_LONG_BROWN_TEXTURE
	style.modulate_color = Color.WHITE
	style.texture_margin_left = 22
	style.texture_margin_right = 22
	style.texture_margin_top = 10
	style.texture_margin_bottom = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
