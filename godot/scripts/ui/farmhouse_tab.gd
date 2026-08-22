## The Farmhouse management sheet -- ported from FarmhouseUi.kt's FarmhouseTab
## composable. Shown via BottomSheet.open() when board_interactor.gd's
## tap-select handling picks the Farmhouse zone (see
## board_interactor.gd's _maybe_open_zone_sheet()). Shows the current level's
## emoji/name/"Level X of Y", a bonuses card (storage/growth-speed/sell-price),
## a storage-usage bar, and either a next-level preview card + upgrade button,
## or a "max level reached" message -- matches the Kotlin original's content
## and behavior exactly.
##
## ARCHITECTURE: small static shell in farmhouse_tab.tscn (Scroll/Body only --
## even smaller than seed_picker.tscn's Title/Scroll/Rows, since here EVERY
## visible element, including the header, is state-dependent and rebuilt by
## _populate(), not just a row list), full content built procedurally in
## _populate() here. Same "small static shell + procedural content" split
## bottom_sheet.gd/seed_picker.gd already established -- see seed_picker.gd's
## header comment for the rationale.
##
## Visual language matches hud.gd/seed_picker.gd exactly (same ported
## Color.kt palette, StyleBoxFlat corner_radius/border/shadow, LabelSettings
## drop-shadow text, explicit mouse_filter on every node) -- not a new idiom.
##
## DESIGN CALL: tapping "Upgrade" does NOT close this sheet, unlike
## SeedPicker's plant action (which closes immediately, matching a one-shot
## "pick one thing and leave" interaction on a plot). Here the sheet stays
## open and re-populates in place (_populate() called again after the
## mutation) so the player immediately sees their new level's stats without
## re-opening the sheet -- arguably better UX for a management screen you
## might tap more than once (e.g. saving up and upgrading twice in a row).
class_name FarmhouseTab
extends VBoxContainer

# Palette -- now sourced from ui_theme.gd (Track A consolidation, see that
# file's class doc); kept as local aliases so no call site below changed.
const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK
const WOOD_BROWN_LIGHT := UiTheme.WOOD_BROWN_MID
const GOLD_LIGHT := UiTheme.GOLD_LIGHT
const RIPE_GOLD := UiTheme.RIPE_GOLD
const SAFFRON_DARK := UiTheme.SAFFRON_DARK
const TEXT_SHADOW_COLOR := UiTheme.TEXT_SHADOW_COLOR

@onready var _body: VBoxContainer = $Scroll/Body

var _economy: GameEconomy
var _village_board: VillageBoard


## Must be called before this instance is added under a BottomSheet's content
## slot -- same precondition/ordering guarantee as SeedPicker.configure(), see
## that function's doc comment.
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
	_body.add_child(_build_header(data))
	_body.add_child(_build_bonuses_card(tr(&"farmhouse.current_bonuses"), data["current"]))
	_body.add_child(_build_storage_card(data))
	if data["is_max_level"]:
		_body.add_child(_build_max_level_message())
	else:
		var next: FarmhouseLevelDef = data["next"]
		_body.add_child(_build_bonuses_card("%s %s %s" % [next.emoji, tr(&"farmhouse.next_label"), next.display_name], next))
		# §2.4 disabled-button state: previously always full-saturation
		# regardless of affordability (the exact BLOCKING gap
		# design/art/ui-visual-direction-2026-08.md §1.1 calls out by name).
		var can_afford: bool = _economy.state.coins >= next.upgrade_cost
		var upgrade_button := _make_chunky_button(tr(&"farmhouse.upgrade_button") % next.upgrade_cost, SAFFRON_DARK, Color.WHITE, can_afford)
		if can_afford:
			upgrade_button.pressed.connect(_on_upgrade_pressed)
		_body.add_child(upgrade_button)


# ---------------------------------------------------------------------------
# Pure logic -- unit-tested directly (tests/unit/test_farmhouse_tab.gd), no
# scene-tree dependency. Not underscore-prefixed for the same reason
# hud.gd's build_inventory_display()/seed_picker.gd's build_row_data() aren't.
# ---------------------------------------------------------------------------

## Everything _populate() needs to know to render this sheet, computed once
## from `economy`'s current state. Mirrors FarmhouseTab composable's own
## local `currentDef`/`isMaxLevel`/`nextDef`/`storageUsed`/`storageCap`/
## `storageProgress` locals exactly, just gathered into one testable
## Dictionary instead of Composable-scoped `val`s.
static func build_view_data(economy: GameEconomy) -> Dictionary:
	var current := GameData.farmhouse_level_def(economy.state.farmhouse_level)
	var is_max_level: bool = economy.state.farmhouse_level >= GameData.farmhouse_max_level()
	var next: FarmhouseLevelDef = null if is_max_level else GameData.farmhouse_level_def(economy.state.farmhouse_level + 1)
	var storage_used := economy.total_inventory_units()
	var storage_cap := economy.storage_capacity()
	var storage_progress: float = clampf(float(storage_used) / float(storage_cap), 0.0, 1.0)
	return {
		"current": current,
		"is_max_level": is_max_level,
		"next": next,
		"storage_used": storage_used,
		"storage_cap": storage_cap,
		"storage_progress": storage_progress,
	}


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_upgrade_pressed() -> void:
	_economy.buy_farmhouse_upgrade()
	if _economy.dirty:
		_play_audio(&"progression_farmhouse_upgrade")
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _play_audio(event_key: StringName) -> void:
	var audio := _village_board.get_audio_manager()
	if audio != null:
		audio.play_sfx(event_key)


# ---------------------------------------------------------------------------
# Widget construction
# ---------------------------------------------------------------------------

func _build_header(data: Dictionary) -> VBoxContainer:
	var current: FarmhouseLevelDef = data["current"]
	var header := VBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 2)

	# A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §1):
	# this header sits directly on BottomSheet's cream background, not inside
	# a _make_panel() card -- these labels must use SOIL_BROWN_DARK, not the
	# Color.WHITE default that's only safe on colored panel backgrounds.
	var emoji_label := Label.new()
	emoji_label.text = current.emoji
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.label_settings = _make_label_settings(44, SOIL_BROWN_DARK)
	header.add_child(emoji_label)

	var name_label := _make_title_label(current.display_name, 20, SOIL_BROWN_DARK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(name_label)

	var level_label := _make_title_label(
		tr(&"farmhouse.level_of") % [current.level, GameData.farmhouse_max_level()], 12, SOIL_BROWN_DARK
	)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(level_label)

	return header


func _build_bonuses_card(title: String, def: FarmhouseLevelDef) -> PanelContainer:
	var card := _make_panel(WOOD_BROWN_LIGHT, 12)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)

	box.add_child(_make_title_label(title, 16))
	# A11Y fix (§5, HIGH): all 3 raised 13px -> this project's 14px floor --
	# these are exactly the "frequently-read numeric/status text" the audit
	# calls out, not decoration.
	box.add_child(_make_title_label(tr(&"farmhouse.storage_capacity") % def.storage_capacity, 14))
	box.add_child(_make_title_label(tr(&"farmhouse.growth_speed") % def.growth_speed_bonus_percent, 14))
	box.add_child(_make_title_label(tr(&"farmhouse.sell_price") % def.sell_price_bonus_percent, 14))

	card.add_child(box)
	return card


func _build_storage_card(data: Dictionary) -> PanelContainer:
	var card := _make_panel(WOOD_BROWN_LIGHT, 12)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)

	box.add_child(_make_title_label(tr(&"farmhouse.storage_label") % [data["storage_used"], data["storage_cap"]], 16))
	box.add_child(_build_storage_bar(data["storage_progress"]))

	card.add_child(box)
	return card


func _build_storage_bar(progress: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = progress
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = SOIL_BROWN_DARK
	bg_style.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = RIPE_GOLD
	fill_style.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("fill", fill_style)

	return bar


func _build_max_level_message() -> Label:
	# A11Y: sits directly on the cream background -- see _build_header()'s note.
	var label := _make_title_label(tr(&"farmhouse.max_level_message"), 14, SOIL_BROWN_DARK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


# Track A consolidation: every helper below now delegates to ui_theme.gd
# (see that file's class doc) -- call sites throughout this file unchanged.
func _make_chunky_button(label_text: String, color: Color, font_color: Color = Color.WHITE, enabled: bool = true) -> Button:
	return UiTheme.make_chunky_button(label_text, color, font_color, enabled)


func _make_panel(bg_color: Color, corner_radius: int = 16, border_color: Color = GOLD_LIGHT) -> PanelContainer:
	return UiTheme.make_panel(bg_color)


func _make_title_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	return UiTheme.make_title_label(text, font_size, color)


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	return UiTheme.make_label_settings(font_size, color)
