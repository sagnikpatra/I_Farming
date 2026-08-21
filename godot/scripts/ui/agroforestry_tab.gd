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
const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK
const WOOD_BROWN_LIGHT := UiTheme.WOOD_BROWN_MID
const GOLD_LIGHT := UiTheme.GOLD_LIGHT
const RIPE_GOLD := UiTheme.RIPE_GOLD
const FIELD_GREEN := UiTheme.FIELD_GREEN
const TEXT_SHADOW_COLOR := UiTheme.TEXT_SHADOW_COLOR

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
	if _economy.dirty:
		_play_audio(&"progression_structure_unlock")
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


## Guarded the same way the Kotlin original's onClick does
## (`if (!state.hasSecurity) viewModel.buySecurity()`) -- same rationale as
## polyhouse_tab.gd's fan-pad/drip guards.
func _on_security_pressed() -> void:
	if _economy.state.has_security:
		return
	_economy.buy_security()
	if _economy.dirty:
		_play_audio(&"economy_purchase_small")
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


## Mechanically identical to polyhouse_tab.gd's _play_audio() -- see that
## file for the null-guard rationale (get_audio_manager() returns null in
## unit tests, where _village_board is a bare double with no audio system).
func _play_audio(event_key: StringName) -> void:
	var audio := _village_board.get_audio_manager()
	if audio != null:
		audio.play_sfx(event_key)


# ---------------------------------------------------------------------------
# Widget construction
# ---------------------------------------------------------------------------

# A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §1): labels
# added directly to the sheet body sit on BottomSheet's cream background --
# these must use SOIL_BROWN_DARK, not the Color.WHITE default that's only
# safe on colored panel backgrounds.
func _build_build_card(data: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)

	var emoji_label := Label.new()
	emoji_label.text = "🌳"
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.label_settings = _make_label_settings(48, SOIL_BROWN_DARK)
	box.add_child(emoji_label)

	var title_label := _make_title_label("Clear Land for Agroforestry", 18, SOIL_BROWN_DARK)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	var blurb_label := _make_title_label(
		(
			"Unlocks a %dx%d plot grid for Sandalwood (Srigandham) cultivation. Sandalwood is " %
			[GameData.AGROFORESTRY_GRID_SIZE, GameData.AGROFORESTRY_GRID_SIZE]
			+ "semi-parasitic -- it must be planted next to a host plant (Pigeon Pea, Neem, or "
			+ "Acacia) and takes weeks to mature, but a single mature tree is worth a fortune."
		),
		13,
		SOIL_BROWN_DARK
	)
	blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(blurb_label)

	# §2.4 disabled-button state.
	var can_afford_build: bool = _economy.state.coins >= int(data["cost"])
	var build_button := _make_chunky_button("Clear Land for ₹%d" % data["cost"], FIELD_GREEN, Color.WHITE, can_afford_build)
	if can_afford_build:
		build_button.pressed.connect(_on_build_pressed)
	box.add_child(build_button)

	return box


func _build_security_chip(data: Dictionary) -> Button:
	var active: bool = data["has_security"]
	var can_afford: bool = active or _economy.state.coins >= int(data["security_cost"])
	var chip := _make_chunky_button(
		"Security (Fencing + CCTV) ✓" if active else "Security ₹%d" % data["security_cost"],
		RIPE_GOLD if active else WOOD_BROWN_LIGHT,
		# A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §1):
		# Color.WHITE on the active RIPE_GOLD background measured ~1.63:1
		# contrast -- unreadable. Only the inactive WOOD_BROWN_LIGHT state is
		# dark enough for white text.
		SOIL_BROWN_DARK if active else Color.WHITE,
		can_afford
	)
	if not active and can_afford:
		chip.pressed.connect(_on_security_pressed)
	return chip


func _build_hint_label() -> Label:
	# A11Y: sits directly on the cream background -- see _build_build_card()'s note.
	var label := _make_title_label(
		"Plant a host next to an empty tile, then Sandalwood beside the host.", 12, SOIL_BROWN_DARK
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


# Track A consolidation: every helper below now delegates to ui_theme.gd
# (see that file's class doc) -- call sites throughout this file unchanged.
func _make_chunky_button(label_text: String, color: Color, font_color: Color = Color.WHITE, enabled: bool = true) -> Button:
	return UiTheme.make_chunky_button(label_text, color, font_color, enabled)


func _make_title_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	return UiTheme.make_title_label(text, font_size, color)


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	return UiTheme.make_label_settings(font_size, color)
