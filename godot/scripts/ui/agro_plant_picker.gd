## The Agroforestry host/Sandalwood picker -- ported from AgroforestryUi.kt's
## `AgroPlantPicker` composable. Shown via BottomSheet.open() when
## board_interactor.gd's tap-select handling picks an EMPTY, not-yet-hosted
## Agroforestry plot (see board_interactor.gd's
## _maybe_open_agro_plant_picker()). Lists the 3 host plants (Pigeon Pea,
## Neem, Acacia -- each planted instantly) plus Sandalwood itself, whose row
## is enabled only when GameEconomy.can_plant_sandalwood() says this tile
## sits next to an already-placed host -- matches the Kotlin original's
## content and behavior exactly (same dim-when-disabled language
## seed_picker.gd already uses, not a new idiom).
##
## ARCHITECTURE: small static shell in agro_plant_picker.tscn
## (Title/Scroll/Rows), rows built procedurally here -- identical split to
## seed_picker.gd, for the same reason (only the row CONTENT is dynamic:
## host affordability + the coins-dependent, adjacency-dependent Sandalwood
## row). Visual language matches seed_picker.gd exactly (same ported
## Color.kt palette, StyleBoxFlat corner_radius/border/shadow, LabelSettings
## drop-shadow text, explicit mouse_filter on every node) -- not a new idiom.
class_name AgroPlantPicker
extends VBoxContainer

# Palette -- ported verbatim from app/src/main/java/com/zonkrik/ifarming/
# ui/theme/Color.kt, same values seed_picker.gd already uses.
const SOIL_BROWN_DARK := Color("#3E2412")
const WOOD_BROWN_LIGHT := Color("#8A5A34")
const GOLD_LIGHT := Color("#FFE082")
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)
## Matches ChunkyTile's `.copy(alpha = 0.4f)` dimming for unaffordable/
## unplantable rows -- same value seed_picker.gd uses.
const UNAFFORDABLE_ALPHA: float = 0.4

@onready var _title_label: Label = $Title
@onready var _rows_container: VBoxContainer = $Scroll/Rows

var _plot_id: int = -1
var _economy: GameEconomy
var _village_board: VillageBoard
var _bottom_sheet: BottomSheet


## Must be called before this instance is added under a BottomSheet's content
## slot -- same precondition/ordering guarantee as SeedPicker.configure().
func configure(plot_id: int, economy: GameEconomy, village_board: VillageBoard, bottom_sheet: BottomSheet) -> void:
	_plot_id = plot_id
	_economy = economy
	_village_board = village_board
	_bottom_sheet = bottom_sheet


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.text = "Plant on this tile"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.label_settings = _make_label_settings(18, SOIL_BROWN_DARK)
	_populate()


func _populate() -> void:
	for child in _rows_container.get_children():
		child.queue_free()
	var can_plant_sandalwood := _economy.can_plant_sandalwood(_plot_id)
	for row_data in build_row_data(_economy.state.coins, can_plant_sandalwood):
		_rows_container.add_child(_build_row(row_data))


# ---------------------------------------------------------------------------
# Pure logic -- unit-tested directly (tests/unit/test_agro_plant_picker.gd),
# no scene-tree dependency. Not underscore-prefixed for the same reason
# seed_picker.gd's build_row_data() isn't.
# ---------------------------------------------------------------------------

## One row per host type plus Sandalwood, in HostType.Kind declaration order
## then Sandalwood last -- mirrors AgroPlantPicker's
## `HostType.entries.forEach { ... }` then the standalone Sandalwood row.
## Each entry: "kind" ("host" or "sandalwood"), "host" (HostType.Kind ordinal,
## only for "host" rows), "subtitle", "cost", "enabled".
static func build_row_data(coins: int, can_plant_sandalwood: bool) -> Array:
	var rows: Array = []
	for key in HostType.Kind.keys():
		var host: int = HostType.Kind[key]
		var host_def := GameData.host_type_def(host)
		rows.append({
			"kind": "host",
			"host": host,
			"emoji": host_def.emoji,
			"title": host_def.display_name,
			"subtitle": (
				"Instant · shortens Sandalwood grow time" if host == HostType.Kind.ACACIA else "Instant"
			),
			"cost": host_def.cost,
			"enabled": coins >= host_def.cost,
		})

	var sandalwood_def := GameData.crop_def(CropType.Kind.SANDALWOOD)
	var affordable := coins >= sandalwood_def.seed_cost
	rows.append({
		"kind": "sandalwood",
		"host": -1,
		"emoji": sandalwood_def.emoji,
		"title": sandalwood_def.display_name,
		"subtitle": (
			"%d+ days · sells ₹%d" % [sandalwood_def.grow_seconds / 86400, sandalwood_def.base_sell_price]
			if can_plant_sandalwood else "Needs an adjacent host plant"
		),
		"cost": sandalwood_def.seed_cost,
		"enabled": affordable and can_plant_sandalwood,
	})
	return rows


# ---------------------------------------------------------------------------
# Row construction
# ---------------------------------------------------------------------------

func _build_row(row_data: Dictionary) -> Button:
	var enabled: bool = row_data["enabled"]

	var row := Button.new()
	row.text = ""
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.focus_mode = Control.FOCUS_NONE
	row.disabled = not enabled
	row.custom_minimum_size = Vector2(0, 56)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(WOOD_BROWN_LIGHT.r, WOOD_BROWN_LIGHT.g, WOOD_BROWN_LIGHT.b, 1.0 if enabled else UNAFFORDABLE_ALPHA)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 1.0 if enabled else UNAFFORDABLE_ALPHA)
	style.shadow_size = 4 if enabled else 0
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
	emoji_label.text = row_data["emoji"]
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.label_settings = _make_label_settings(26, Color.WHITE)
	left.add_child(emoji_label)

	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.text = row_data["title"]
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.label_settings = _make_label_settings(14, Color.WHITE)
	var details_label := Label.new()
	details_label.text = row_data["subtitle"]
	details_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_label.label_settings = _make_label_settings(12, Color(1.0, 1.0, 1.0, 0.9))
	info.add_child(name_label)
	info.add_child(details_label)
	left.add_child(info)

	var cost_label := Label.new()
	cost_label.text = "₹%d" % row_data["cost"]
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.label_settings = _make_label_settings(14, Color.WHITE)

	content.add_child(left)
	content.add_child(cost_label)
	row.add_child(content)

	if enabled:
		if row_data["kind"] == "host":
			row.pressed.connect(_on_host_pressed.bind(row_data["host"]))
		else:
			row.pressed.connect(_on_sandalwood_pressed)
	return row


func _on_host_pressed(host: int) -> void:
	_economy.plant_host(_plot_id, host)
	if _economy.dirty:
		_play_audio(&"economy_purchase_small")
	_bottom_sheet.close()
	_village_board.persist_and_rebuild_if_dirty()


func _on_sandalwood_pressed() -> void:
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	_economy.plant_sandalwood(_plot_id, now)
	if _economy.dirty:
		_play_audio(&"economy_plant")
	_bottom_sheet.close()
	_village_board.persist_and_rebuild_if_dirty()


func _play_audio(event_key: StringName) -> void:
	var audio := _village_board.get_audio_manager()
	if audio != null:
		audio.play_sfx(event_key)


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.shadow_size = 4
	settings.shadow_color = TEXT_SHADOW_COLOR
	settings.shadow_offset = Vector2(2, 3)
	return settings
