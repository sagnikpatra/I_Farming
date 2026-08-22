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

# Palette -- now sourced from ui_theme.gd (Track A consolidation, see that
# file's class doc); kept as local aliases so no call site below changed.
const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK
const WOOD_BROWN_LIGHT := UiTheme.WOOD_BROWN_MID
const TEXT_SHADOW_COLOR := UiTheme.TEXT_SHADOW_COLOR

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
	subtitle_label.text = tr(&"decoration_info.subtitle")
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
	button_row.add_child(_make_text_button(tr(&"decoration_info.remove_button"), SOIL_BROWN_DARK, _on_remove_pressed))
	add_child(button_row)


func _on_rotate_pressed() -> void:
	_economy.rotate_decoration(_decoration_id)
	_play_audio(&"ui_rotate_flip")
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_flip_pressed() -> void:
	_economy.flip_decoration(_decoration_id)
	_play_audio(&"ui_rotate_flip")
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_remove_pressed() -> void:
	_economy.remove_decoration(_decoration_id)
	_village_board.persist_and_rebuild_if_dirty()
	_bottom_sheet.close()


func _play_audio(event_key: StringName) -> void:
	var audio := _village_board.get_audio_manager()
	if audio != null:
		audio.play_sfx(event_key)


# Track A consolidation: Rotate/Flip previously used a bespoke square
# StyleBoxFlat button for a single glyph -- now routed through
# UiTheme.make_circular_emoji_button(), the same circular-glyph chrome
# hud.gd's Quick Nav Bar chips use for its own icon-less pictographs (↻/⇋
# have no sourced icon-kit equivalent, same rationale as hud.gd's own
# _build_nav_chip() comment). Remove now delegates to
# UiTheme.make_chunky_button() -- the same Kenney 9-slice chrome every
# other ported sheet's text buttons use.
func _make_icon_button(glyph: String, color: Color, on_pressed: Callable) -> Button:
	var button := UiTheme.make_circular_emoji_button(glyph, color, 48)
	button.pressed.connect(on_pressed)
	return button


func _make_text_button(label_text: String, color: Color, on_pressed: Callable) -> Button:
	var button := UiTheme.make_chunky_button(label_text, color)
	button.pressed.connect(on_pressed)
	return button


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	return UiTheme.make_label_settings(font_size, color)
