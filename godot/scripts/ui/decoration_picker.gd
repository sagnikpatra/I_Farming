## The decoration shop picker -- ported from GdxDecorationPicker.kt (the real
## shipped app's picker, opened from the HUD's 🎨 Shop button -- not
## AgroforestryUi.kt-adjacent FarmScreen.kt's older equivalent, same
## authority precedent as GdxVillageBoard.kt's direct-tap-harvest behavior
## established earlier this epic). Lists every DecorationType with cost,
## dimmed when unaffordable -- same row shape as seed_picker.gd. Tapping a
## row does NOT place the decoration immediately: it arms
## BoardInteractor.arm_decoration_placement() and closes this sheet, so the
## NEXT tap anywhere on the board places it there (matches the Kotlin
## original's doc comment exactly: "a decoration needs a world position that
## only the board itself can resolve").
##
## ARCHITECTURE: small static shell in decoration_picker.tscn
## (Title/Scroll/Rows), rows built procedurally here -- identical split to
## seed_picker.gd. Visual language matches seed_picker.gd exactly.
class_name DecorationPicker
extends VBoxContainer

# Palette -- ported verbatim from app/src/main/java/com/zonkrik/ifarming/
# ui/theme/Color.kt, same values seed_picker.gd already uses.
const SOIL_BROWN_DARK := Color("#3E2412")
const WOOD_BROWN_LIGHT := Color("#8A5A34")
const GOLD_LIGHT := Color("#FFE082")
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)
const UNAFFORDABLE_ALPHA: float = 0.4

@onready var _title_label: Label = $Title
@onready var _rows_container: VBoxContainer = $Scroll/Rows

var _economy: GameEconomy
var _board_interactor: BoardInteractor
var _bottom_sheet: BottomSheet


## Must be called before this instance is added under a BottomSheet's content
## slot -- same precondition/ordering guarantee as SeedPicker.configure().
func configure(economy: GameEconomy, board_interactor: BoardInteractor, bottom_sheet: BottomSheet) -> void:
	_economy = economy
	_board_interactor = board_interactor
	_bottom_sheet = bottom_sheet


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.text = "Choose a decoration to place"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.label_settings = _make_label_settings(18, SOIL_BROWN_DARK)
	_populate()


func _populate() -> void:
	for child in _rows_container.get_children():
		child.queue_free()
	for row_data in build_row_data(_economy.state.coins):
		_rows_container.add_child(_build_row(row_data["type"], row_data["affordable"]))


# ---------------------------------------------------------------------------
# Pure logic -- unit-tested directly (tests/unit/test_decoration_picker.gd),
# no scene-tree dependency. Not underscore-prefixed for the same reason
# seed_picker.gd's build_row_data() isn't.
# ---------------------------------------------------------------------------

## DecorationType ordinals in declaration order, each paired with whether
## `coins` can afford it -- mirrors GdxDecorationPicker.kt's
## `DecorationType.entries.forEach { ... }` exactly (no filtering: every
## decoration type is always listed, just dimmed if unaffordable).
static func build_row_data(coins: int) -> Array:
	var rows: Array = []
	for key in DecorationType.Kind.keys():
		var type: int = DecorationType.Kind[key]
		var type_def := GameData.decoration_type_def(type)
		rows.append({"type": type, "affordable": coins >= type_def.cost})
	return rows


# ---------------------------------------------------------------------------
# Row construction
# ---------------------------------------------------------------------------

func _build_row(type: int, affordable: bool) -> Button:
	var type_def := GameData.decoration_type_def(type)

	var row := Button.new()
	row.text = ""
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.focus_mode = Control.FOCUS_NONE
	row.disabled = not affordable
	row.custom_minimum_size = Vector2(0, 56)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(WOOD_BROWN_LIGHT.r, WOOD_BROWN_LIGHT.g, WOOD_BROWN_LIGHT.b, 1.0 if affordable else UNAFFORDABLE_ALPHA)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 1.0 if affordable else UNAFFORDABLE_ALPHA)
	style.shadow_size = 4 if affordable else 0
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		row.add_theme_stylebox_override(state_name, style)

	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)

	var left := HBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)

	var emoji_label := Label.new()
	emoji_label.text = type_def.emoji
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.label_settings = _make_label_settings(26, Color.WHITE)
	left.add_child(emoji_label)

	var name_label := Label.new()
	name_label.text = type_def.display_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.label_settings = _make_label_settings(14, Color.WHITE)
	left.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "₹%d" % type_def.cost
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.label_settings = _make_label_settings(14, Color.WHITE)

	content.add_child(left)
	content.add_child(cost_label)
	row.add_child(content)

	if affordable:
		row.pressed.connect(_on_row_pressed.bind(type))
	return row


func _on_row_pressed(type: int) -> void:
	_board_interactor.arm_decoration_placement(type)
	_bottom_sheet.close()


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.shadow_size = 4
	settings.shadow_color = TEXT_SHADOW_COLOR
	settings.shadow_offset = Vector2(2, 3)
	return settings
