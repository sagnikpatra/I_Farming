## The Agroforestry management sheet -- ported from AgroforestryUi.kt's
## `AgroforestryTab` composable. Shown via BottomSheet.open() when
## board_interactor.gd's tap-select handling picks the Agroforestry zone
## (see board_interactor.gd's _maybe_open_zone_sheet()). Shows a build card
## if not yet built, otherwise a Security chip + an instructional line --
## matches the real shipped app's call site exactly (`AgroforestryTab(...,
## showPlots = false)`): the plot grid itself is NOT rendered here, since
## board taps already handle host/Sandalwood planting and host removal
## directly (see AgroHostPicker for the empty-tile picker and
## board_interactor.gd's occupied-host-tile-removes-on-tap handling).
##
## ARCHITECTURE: small static shell in agroforestry_tab.tscn (Scroll/Body
## only), full content built procedurally in _populate() -- same split
## farmhouse_tab.gd/mandi_tab.gd/polyhouse_tab.gd use. Visual language
## matches those sheets exactly (same ported Color.kt palette, StyleBoxFlat
## corner_radius/border/shadow, LabelSettings drop-shadow text, explicit
## mouse_filter on every node) -- not a new idiom.
##
## DESIGN CALL (same rationale as the other sheets): building the
## Agroforestry plot or buying Security does NOT close this sheet -- it
## re-populates in place.
class_name AgroforestryTab
extends VBoxContainer

# Palette -- ported verbatim from app/src/main/java/com/zonkrik/ifarming/
# ui/theme/Color.kt, same values every other ported sheet already uses.
const SOIL_BROWN_DARK := Color("#3E2412")
const WOOD_BROWN_LIGHT := Color("#8A5A34")
const GOLD_LIGHT := Color("#FFE082")
const RIPE_GOLD := Color("#FFC107")
const FIELD_GREEN := Color("#4CAF50")
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)

@onready var _body: VBoxContainer = $Scroll/Body

var _economy: GameEconomy
var _village_board: VillageBoard


## Must be called before this instance is added under a BottomSheet's content
## slot -- same precondition/ordering guarantee as the other tabs'
## configure() methods.
func configure(economy: GameEconomy, village_board: VillageBoard) -> void:
	_economy = economy
	_village_board = village_board


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_populate()


func _populate() -> void:
	for child in _body.get_children():
		child.queue_free()
	var data := build_view_data(_economy)
	if not data["has_agroforestry"]:
		_body.add_child(_build_build_card(data))
		return
	_body.add_child(_build_security_chip(data))
	_body.add_child(_build_hint_label())


# ---------------------------------------------------------------------------
# Pure logic -- unit-tested directly (tests/unit/test_agroforestry_tab.gd),
# no scene-tree dependency.
# ---------------------------------------------------------------------------

## Mirrors AgroforestryTab/AgroBuildCard's own local reads exactly, gathered
## into one testable Dictionary (same pattern every other ported sheet
## uses).
static func build_view_data(economy: GameEconomy) -> Dictionary:
	var state := economy.state
	return {
		"has_agroforestry": state.has_agroforestry,
		"cost": GameData.AGROFORESTRY_UNLOCK_COST,
		"has_security": state.has_security,
		"security_cost": GameData.SECURITY_COST,
	}


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_build_pressed() -> void:
	_economy.buy_agroforestry()
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


## Guarded the same way the Kotlin original's onClick does
## (`if (!state.hasSecurity) viewModel.buySecurity()`) -- same rationale as
## polyhouse_tab.gd's fan-pad/drip guards.
func _on_security_pressed() -> void:
	if _economy.state.has_security:
		return
	_economy.buy_security()
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


# ---------------------------------------------------------------------------
# Widget construction
# ---------------------------------------------------------------------------

func _build_build_card(data: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)

	var emoji_label := Label.new()
	emoji_label.text = "🌳"
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.label_settings = _make_label_settings(48, Color.WHITE)
	box.add_child(emoji_label)

	var title_label := _make_title_label("Clear Land for Agroforestry", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	var blurb_label := _make_title_label(
		(
			"Unlocks a %dx%d plot grid for Sandalwood (Srigandham) cultivation. Sandalwood is " %
			[GameData.AGROFORESTRY_GRID_SIZE, GameData.AGROFORESTRY_GRID_SIZE]
			+ "semi-parasitic -- it must be planted next to a host plant (Pigeon Pea, Neem, or "
			+ "Acacia) and takes weeks to mature, but a single mature tree is worth a fortune."
		),
		13
	)
	blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(blurb_label)

	var build_button := _make_chunky_button("Clear Land for ₹%d" % data["cost"], FIELD_GREEN)
	build_button.pressed.connect(_on_build_pressed)
	box.add_child(build_button)

	return box


func _build_security_chip(data: Dictionary) -> Button:
	var active: bool = data["has_security"]
	var chip := Button.new()
	chip.text = "Security (Fencing + CCTV) ✓" if active else "Security ₹%d" % data["security_cost"]
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = RIPE_GOLD if active else WOOD_BROWN_LIGHT
	style.set_corner_radius_all(20)
	style.set_border_width_all(2)
	style.border_color = GOLD_LIGHT
	style.shadow_size = 3
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	for state_name in ["normal", "hover", "pressed", "focus"]:
		chip.add_theme_stylebox_override(state_name, style)
	chip.add_theme_color_override("font_color", Color.WHITE)
	chip.add_theme_font_size_override("font_size", 13)
	chip.pressed.connect(_on_security_pressed)
	return chip


func _build_hint_label() -> Label:
	var label := _make_title_label(
		"Plant a host next to an empty tile, then Sandalwood beside the host.", 12
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


func _make_chunky_button(label_text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = label_text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(20)
	style.set_border_width_all(2)
	style.border_color = SOIL_BROWN_DARK
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	for state_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state_name, style)
	for color_slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_slot, Color.WHITE)
	button.add_theme_font_size_override("font_size", 14)
	return button


func _make_title_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.label_settings = _make_label_settings(font_size, color)
	return label


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.shadow_size = 4
	settings.shadow_color = TEXT_SHADOW_COLOR
	settings.shadow_offset = Vector2(2, 3)
	return settings
