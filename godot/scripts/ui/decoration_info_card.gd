## Rotate/Flip/Remove card for a tapped decoration -- ports GdxInfoCard.kt's
## content for the decoration case of GdxVillageBoard.kt's tap dispatch
## (emoji/title/"Decoration" subtitle, plus a "↻"/"⇋"/"Remove" button row --
## no "Manage" action button, since decorations aren't sheet-managed).
## Opened via BoardInteractor._open_decoration_info_card() (EPIC-M5 parity
## pass -- see that function's header comment).
##
## ARCHITECTURE: same "small static shell would be overkill" call as
## growing_info_card.gd -- everything here is built procedurally in
## configure(), no static .tscn content beyond the root container. Visual
## language matches every other ported sheet/card (ported Color.kt palette,
## StyleBoxFlat corner_radius/border/shadow, LabelSettings drop-shadow
## text, explicit mouse_filter on every node).
##
## DESIGN CALL: Rotate/Flip do NOT close the sheet -- they re-populate this
## card in place after each tap (same "stays open, shows the result
## immediately" rationale every other ported sheet's mutation buttons use).
## Remove DOES close the sheet, matching the Kotlin original exactly
## (`onRemove = { viewModel.removeDecoration(decorationId); selection = null }`).
class_name DecorationInfoCard
extends VBoxContainer

const SOIL_BROWN_DARK := Color("#3E2412")
const WOOD_BROWN_LIGHT := Color("#8A5A34")
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)

var _type: int = 0
var _decoration_id: int = -1
var _economy: GameEconomy
var _village_board: VillageBoard
var _bottom_sheet: BottomSheet


## Must be called before this instance is added under a BottomSheet's content
## slot -- same precondition/ordering guarantee as every other ported
## picker/card's configure() method.
func configure(type: int, decoration_id: int, economy: GameEconomy, village_board: VillageBoard, bottom_sheet: BottomSheet) -> void:
	_type = type
	_decoration_id = decoration_id
	_economy = economy
	_village_board = village_board
	_bottom_sheet = bottom_sheet


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_populate()


func _populate() -> void:
	for child in get_children():
		child.queue_free()

	var type_def := GameData.decoration_type_def(_type)

	# A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §1):
	# this card is added straight to the BottomSheet's cream body with no
	# panel wrapper, so Color.WHITE (safe only on colored panels) is
	# unreadable here -- measured ~1.06:1 contrast.
	var emoji_label := Label.new()
	emoji_label.text = type_def.emoji
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.label_settings = _make_label_settings(40, SOIL_BROWN_DARK)
	add_child(emoji_label)

	var name_label := Label.new()
	name_label.text = type_def.display_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.label_settings = _make_label_settings(18, SOIL_BROWN_DARK)
	add_child(name_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Decoration"
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.label_settings = _make_label_settings(14, Color(0.243, 0.141, 0.071, 0.9))
	add_child(subtitle_label)

	var button_row := HBoxContainer.new()
	button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 8)
	button_row.add_child(_make_icon_button("↻", WOOD_BROWN_LIGHT, _on_rotate_pressed))
	button_row.add_child(_make_icon_button("⇋", WOOD_BROWN_LIGHT, _on_flip_pressed))
	button_row.add_child(_make_text_button("Remove", SOIL_BROWN_DARK, _on_remove_pressed))
	add_child(button_row)


func _on_rotate_pressed() -> void:
	_economy.rotate_decoration(_decoration_id)
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_flip_pressed() -> void:
	_economy.flip_decoration(_decoration_id)
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_remove_pressed() -> void:
	_economy.remove_decoration(_decoration_id)
	_village_board.persist_and_rebuild_if_dirty()
	_bottom_sheet.close()


func _make_icon_button(icon: String, color: Color, on_pressed: Callable) -> Button:
	var button := _make_text_button(icon, color, on_pressed)
	button.custom_minimum_size = Vector2(48, 48)
	button.add_theme_font_size_override("font_size", 18)
	return button


func _make_text_button(label_text: String, color: Color, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = SOIL_BROWN_DARK
	style.shadow_size = 3
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	for state_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state_name, style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(on_pressed)
	return button


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.shadow_size = 4
	settings.shadow_color = TEXT_SHADOW_COLOR
	settings.shadow_offset = Vector2(2, 3)
	return settings
