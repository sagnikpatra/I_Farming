## The seed-picker sheet -- ported from FarmScreen.kt's SeedPicker composable
## (near the bottom of that file). Shown via BottomSheet.open() when
## board_interactor.gd's tap-select handling picks an EMPTY plot whose
## PlotKind has at least one plantable crop (see
## GameData.crops_for_plot_kind() and board_interactor.gd's
## _maybe_open_seed_picker()). Lists every crop valid for the target plot's
## PlotKind, each row showing emoji + name + "Xm grow · sells ₹Y" + cost,
## dimmed/disabled if unaffordable -- matches the Kotlin original's content
## and behavior exactly (filter by requiredPlotKind, dim by coins only, no
## other guard duplicated here -- GameEconomy.plant_seed()'s own guards, e.g.
## the Saffron electricity check, still apply and simply no-op silently if
## violated, same as the Kotlin original never previewed them either).
##
## ARCHITECTURE: small static shell in seed_picker.tscn (Title/Scroll/Rows),
## rows built procedurally here -- same split BottomSheet itself uses (see
## bottom_sheet.gd's header comment), chosen over Hud's "everything in
## script" approach because this shell is genuinely small and static; only
## the row CONTENT is dynamic (crop catalogue + live coin balance).
##
## Visual language matches hud.gd exactly (same ported Color.kt palette,
## StyleBoxFlat corner_radius/border/shadow, LabelSettings drop-shadow text,
## explicit mouse_filter on every node) -- not a new idiom.
class_name SeedPicker
extends VBoxContainer

# Palette -- now sourced from ui_theme.gd (Track A consolidation, see that
# file's class doc); kept as local aliases so no call site below changed.
const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK
const WOOD_BROWN_LIGHT := UiTheme.WOOD_BROWN_MID
const GOLD_LIGHT := UiTheme.GOLD_LIGHT
const TEXT_SHADOW_COLOR := UiTheme.TEXT_SHADOW_COLOR
## Matches ChunkyTile's `.copy(alpha = 0.4f)` dimming for unaffordable rows
## in the Kotlin original.
const UNAFFORDABLE_ALPHA: float = UiTheme.UNAFFORDABLE_ALPHA

@onready var _title_label: Label = $Title
@onready var _rows_container: VBoxContainer = $Scroll/Rows

var _plot_id: int = -1
var _plot_kind: int = PlotKind.Kind.OPEN_FIELD
var _economy: GameEconomy
var _village_board: VillageBoard
var _bottom_sheet: BottomSheet


## Must be called before this instance is added under a BottomSheet's content
## slot (see board_interactor.gd's _maybe_open_seed_picker()) -- _ready()
## (which builds the row list) only fires once this node enters the tree, by
## which point BottomSheet.open() has already called add_child(), so the
## configured values are guaranteed to be set first.
func configure(plot_id: int, plot_kind: int, economy: GameEconomy, village_board: VillageBoard, bottom_sheet: BottomSheet) -> void:
	_plot_id = plot_id
	_plot_kind = plot_kind
	_economy = economy
	_village_board = village_board
	_bottom_sheet = bottom_sheet


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.text = "Choose a seed to plant"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.label_settings = _make_label_settings(18, SOIL_BROWN_DARK)
	_populate()


func _populate() -> void:
	for child in _rows_container.get_children():
		child.queue_free()
	for row_data in build_row_data(_plot_kind, _economy.state.coins):
		_rows_container.add_child(_build_row(row_data["crop"], row_data["affordable"]))


# ---------------------------------------------------------------------------
# Pure logic -- unit-tested directly (tests/unit/test_seed_picker.gd), no
# scene-tree dependency. Not underscore-prefixed for the same reason
# hud.gd's build_inventory_display()/format_liveops_label() aren't.
# ---------------------------------------------------------------------------

## Crop ordinals valid for `plot_kind` (via GameData.crops_for_plot_kind(),
## which already excludes Sandalwood -- see that function's doc comment),
## each paired with whether `coins` can afford its seed cost. Preserves
## crops_for_plot_kind()'s ordering (CropType.Kind declaration order),
## mirroring the Kotlin original's `CropType.entries.filter{...}` order.
static func build_row_data(plot_kind: int, coins: int) -> Array:
	var rows: Array = []
	for crop in GameData.crops_for_plot_kind(plot_kind):
		var crop_def := GameData.crop_def(crop)
		rows.append({"crop": crop, "affordable": coins >= crop_def.seed_cost})
	return rows


## "Xm grow · sells ₹Y" -- matches FarmScreen.kt's SeedPicker row text
## exactly (`"${crop.growSeconds / 60}m grow · sells ₹${crop.baseSellPrice}"`,
## integer-truncating minutes the same way GDScript's int `/` does).
static func format_crop_details(crop_def: CropDef) -> String:
	return "%dm grow · sells ₹%d" % [crop_def.grow_seconds / 60, crop_def.base_sell_price]


# ---------------------------------------------------------------------------
# Row construction
# ---------------------------------------------------------------------------

func _build_row(crop: int, affordable: bool) -> Button:
	var crop_def := GameData.crop_def(crop)

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
	emoji_label.text = crop_def.emoji
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.label_settings = _make_label_settings(26, Color.WHITE)
	left.add_child(emoji_label)

	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.text = crop_def.display_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.label_settings = _make_label_settings(14, Color.WHITE)
	var details_label := Label.new()
	details_label.text = format_crop_details(crop_def)
	details_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A11Y fix (village-board-and-management-sheets-audit-2026-08-21.md §5,
	# HIGH): 12px -> this project's 14px floor for frequently-read text.
	details_label.label_settings = _make_label_settings(14, Color(1.0, 1.0, 1.0, 0.9))
	info.add_child(name_label)
	info.add_child(details_label)
	left.add_child(info)

	var cost_label := Label.new()
	cost_label.text = "₹%d" % crop_def.seed_cost
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.label_settings = _make_label_settings(14, Color.WHITE)

	content.add_child(left)
	content.add_child(cost_label)
	row.add_child(content)

	if affordable:
		row.pressed.connect(_on_row_pressed.bind(crop))
	return row


func _on_row_pressed(crop: int) -> void:
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	_economy.plant_seed(_plot_id, crop, now)
	if _economy.dirty:
		var audio := _village_board.get_audio_manager()
		if audio != null:
			audio.play_sfx(&"economy_plant")
	_bottom_sheet.close()
	_village_board.persist_and_rebuild_if_dirty()


# Track A consolidation: delegates to ui_theme.gd (see that file's class
# doc) -- call sites throughout this file unchanged. The row-building code
# above stays local (not a make_panel()/make_chunky_button()-style helper --
# a bespoke list-row layout duplicated across seed_picker.gd/
# agro_plant_picker.gd/decoration_picker.gd; consolidating that shape into
# ui_theme.gd is out of this round's scope).
func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	return UiTheme.make_label_settings(font_size, color)
