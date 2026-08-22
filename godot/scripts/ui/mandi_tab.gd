## The Mandi management sheet -- ported from MandiUi.kt's MandiTab composable.
## Shown via BottomSheet.open() when board_interactor.gd's tap-select handling
## picks the Mandi zone (see board_interactor.gd's _maybe_open_zone_sheet()) --
## fires whether or not the Mandi is built yet (village_board.gd's
## _build_zone() gives every zone with has_building=true, including locked
## ones, a PickArea; VillageSnapshotMapper._build_mandi() always returns a
## Mandi ZoneFixture with has_building=true regardless of state.has_mandi --
## see that file). If not yet built, shows a build/register card; otherwise
## an intro blurb, a Digital Auction Terminal unlock offer (if not yet
## bought), then one row per crop relevant to the player's current unlocks.
##
## ARCHITECTURE: small static shell in mandi_tab.tscn (Scroll/Body only),
## full content built procedurally in _populate() -- same split
## farmhouse_tab.gd uses, for the same reason (every visible element here is
## state-dependent: which crops are relevant, held units, live price, whether
## the terminal/Mandi itself is even built yet -- there's no static portion
## worth hand-authoring in the editor). Visual language matches hud.gd/
## seed_picker.gd/farmhouse_tab.gd exactly (same ported Color.kt palette,
## StyleBoxFlat corner_radius/border/shadow, LabelSettings drop-shadow text,
## explicit mouse_filter on every node) -- not a new idiom.
##
## DESIGN CALL (same rationale as farmhouse_tab.gd's upgrade button): none of
## registering the Mandi, buying the terminal, or selling a crop closes this
## sheet -- each just re-populates in place (_populate() called again after
## the mutation), so e.g. registering immediately reveals the crop list
## without requiring the player to close and re-tap the zone.
class_name MandiTab
extends VBoxContainer

# Palette -- ported verbatim from app/src/main/java/com/zonkrik/ifarming/
# ui/theme/Color.kt, same values hud.gd/seed_picker.gd/farmhouse_tab.gd
# already use. FIELD_GREEN_LIGHT is new to this file (the Kotlin original's
# "A-Grade" tag color, not used by any prior-ported screen).
const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK
const WOOD_BROWN_LIGHT := UiTheme.WOOD_BROWN_MID
const GOLD_LIGHT := UiTheme.GOLD_LIGHT
const RIPE_GOLD := UiTheme.RIPE_GOLD
const SAFFRON_DARK := UiTheme.SAFFRON_DARK
const FIELD_GREEN_LIGHT := Color("#66BB6A")
const TEXT_SHADOW_COLOR := UiTheme.TEXT_SHADOW_COLOR
## Matches ChunkyTile-style dimming for a disabled "Sell" button when nothing
## is held -- same alpha SeedPicker uses for unaffordable rows.
const DISABLED_ALPHA: float = 0.4

@onready var _body: VBoxContainer = $Scroll/Body

var _economy: GameEconomy
var _village_board: VillageBoard


## Must be called before this instance is added under a BottomSheet's content
## slot -- same precondition/ordering guarantee as SeedPicker.configure()/
## FarmhouseTab.configure().
func configure(economy: GameEconomy, village_board: VillageBoard) -> void:
	_economy = economy
	_village_board = village_board


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_populate()


func _populate() -> void:
	for child in _body.get_children():
		child.queue_free()
	if not _economy.state.has_mandi:
		_body.add_child(_build_build_card())
		return

	_body.add_child(_build_intro())
	if not _economy.state.has_mandi_terminal:
		_body.add_child(_build_terminal_offer())

	var now := _now()
	for row_data in build_row_data(_economy, now):
		_body.add_child(_build_crop_row(row_data))


func _now() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


# ---------------------------------------------------------------------------
# Pure logic -- unit-tested directly (tests/unit/test_mandi_tab.gd), no
# scene-tree dependency. Not underscore-prefixed for the same reason
# hud.gd's build_inventory_display()/seed_picker.gd's build_row_data() aren't.
# ---------------------------------------------------------------------------

## True if `crop_def` should be listed in the Mandi's crop list given the
## player's current zone unlocks. Mirrors MandiUi.kt's `relevantCrops` filter
## `when` block exactly. Deliberately NOT the same set GameData.
## crops_for_plot_kind() returns: that function exists for the Seed Picker
## and deliberately excludes Sandalwood (its own dedicated planting entry
## point) -- but Sandalwood is a completely ordinary sellable crop once
## harvested, so it belongs in scope here whenever Agroforestry is unlocked.
## Reusing crops_for_plot_kind() for Mandi would therefore have been a real
## (if subtle) behavioral bug, not just a style choice -- this is a
## deliberately separate function, not a duplicate of an existing one.
static func is_crop_relevant(
	crop_def: CropDef, has_polyhouse: bool, has_agroforestry: bool, has_aquaculture: bool, has_vertical_farm: bool
) -> bool:
	match crop_def.required_plot_kind:
		PlotKind.Kind.OPEN_FIELD:
			return true
		PlotKind.Kind.POLYHOUSE:
			return has_polyhouse
		PlotKind.Kind.AGROFORESTRY:
			return has_agroforestry
		PlotKind.Kind.AQUACULTURE:
			return has_aquaculture
		PlotKind.Kind.VERTICAL_FARM:
			return has_vertical_farm
		_:
			return false


## Crop ordinals relevant given these unlock flags, in CropType.Kind's
## declared ordinal order (mirrors Kotlin's `CropType.entries.filter{...}`
## order, same convention GameData.crops_for_plot_kind() and
## SeedPicker.build_row_data() already follow).
static func relevant_crops(
	has_polyhouse: bool, has_agroforestry: bool, has_aquaculture: bool, has_vertical_farm: bool
) -> Array[int]:
	var matching: Array[int] = []
	for key in CropType.Kind.keys():
		var crop: int = CropType.Kind[key]
		if is_crop_relevant(GameData.crop_def(crop), has_polyhouse, has_agroforestry, has_aquaculture, has_vertical_farm):
			matching.append(crop)
	return matching


## "▲"/"▼"/"―" for a rounded market-rate percent. Matches MandiUi.kt's
## MandiCropRow `when` block exactly (`pct > 102 -> "▲"; pct < 98 -> "▼";
## else -> "―"`) -- note both boundaries (98, 102) themselves read as "―".
static func trend_arrow(pct: int) -> String:
	if pct > 102:
		return "▲"
	if pct < 98:
		return "▼"
	return "―"


## One row's worth of display data per relevant crop -- held units, rounded
## market-rate percent + trend arrow, tomorrow's forecast percent, and
## whether this crop earns the A-Grade tag (any non-open-field cultivation).
## Mirrors MandiCropRow's per-item locals exactly, gathered into one testable
## Dictionary per row instead of Composable-scoped `val`s (same pattern
## FarmhouseTab.build_view_data() uses).
static func build_row_data(economy: GameEconomy, now: int) -> Array:
	var rows: Array = []
	var state := economy.state
	var crops := relevant_crops(state.has_polyhouse, state.has_agroforestry, state.has_aquaculture, state.has_vertical_farm)
	for crop in crops:
		var stock: CropStock = state.inventory.get(crop, null)
		var held: int = stock.total if stock != null else 0
		var multiplier := economy.mandi_price_multiplier(crop, now)
		var pct: int = roundi(multiplier * 100)
		var crop_def := GameData.crop_def(crop)
		rows.append({
			"crop": crop,
			"held": held,
			"pct": pct,
			"trend": trend_arrow(pct),
			"forecast_percent": economy.mandi_forecast_percent(crop, now),
			"is_graded": crop_def.required_plot_kind != PlotKind.Kind.OPEN_FIELD,
		})
	return rows


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_build_pressed() -> void:
	_economy.buy_mandi()
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_terminal_pressed() -> void:
	_economy.buy_mandi_terminal()
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_sell_pressed(crop: int) -> void:
	var tier_before: int = _economy.state.event_claimed_tier
	_economy.sell_to_mandi(crop, _now())
	if _economy.dirty:
		_play_audio(&"economy_sell")
		var tier_after: int = _economy.state.event_claimed_tier
		for _i in range(tier_after - tier_before):
			_play_audio(&"liveops_festival_tier_reward")
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _play_audio(event_key: StringName) -> void:
	var audio := _village_board.get_audio_manager()
	if audio != null:
		audio.play_sfx(event_key)


# ---------------------------------------------------------------------------
# Widget construction
# ---------------------------------------------------------------------------

# A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §1): both
# _build_build_card() and _build_intro() add their labels directly to the
# sheet body, which sits on BottomSheet's cream background -- these must use
# SOIL_BROWN_DARK, not the Color.WHITE default that's only safe on colored
# panel backgrounds.
func _build_build_card() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)

	var emoji_label := Label.new()
	emoji_label.text = "🏛️"
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.label_settings = _make_label_settings(48, SOIL_BROWN_DARK)
	box.add_child(emoji_label)

	var title_label := _make_title_label(tr(&"mandi.register_title"), 18, SOIL_BROWN_DARK)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	var blurb_label := _make_title_label(tr(&"mandi.register_blurb"), 13, SOIL_BROWN_DARK)
	blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(blurb_label)

	var build_button := _make_chunky_button(tr(&"mandi.register_button") % GameData.MANDI_UNLOCK_COST, SAFFRON_DARK)
	build_button.pressed.connect(_on_build_pressed)
	box.add_child(build_button)

	return box


func _build_intro() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)

	var title_label := _make_title_label(tr(&"mandi.intro_title"), 18, SOIL_BROWN_DARK)
	box.add_child(title_label)

	var blurb_label := _make_title_label(tr(&"mandi.intro_blurb"), 12, SOIL_BROWN_DARK)
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(blurb_label)

	return box


func _build_terminal_offer() -> Button:
	var can_afford := _economy.state.coins >= GameData.MANDI_TERMINAL_COST
	var button := _make_chunky_button(
		tr(&"mandi.terminal_offer") % GameData.MANDI_TERMINAL_COST,
		WOOD_BROWN_LIGHT,
		Color.WHITE,
		can_afford
	)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD
	if can_afford:
		button.pressed.connect(_on_terminal_pressed)
	return button


func _build_crop_row(row_data: Dictionary) -> PanelContainer:
	var crop: int = row_data["crop"]
	var held: int = row_data["held"]
	var crop_def := GameData.crop_def(crop)

	var card := _make_panel(WOOD_BROWN_LIGHT, 12)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)

	var info_row := HBoxContainer.new()
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var left := HBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)

	var emoji_label := Label.new()
	emoji_label.text = crop_def.emoji
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.label_settings = _make_label_settings(24, Color.WHITE)
	left.add_child(emoji_label)

	var name_col := VBoxContainer.new()
	name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 4)
	var name_label := _make_title_label(crop_def.display_name, 14)
	name_row.add_child(name_label)
	# A11Y fix (village-board-and-management-sheets-audit-2026-08-21.md §5,
	# HIGH): both raised to this project's 14px floor -- "Held: N" and
	# "A-Grade" are exactly the frequently-read status/numeric text the
	# audit calls out, not decoration.
	if row_data["is_graded"]:
		var graded_label := _make_title_label(tr(&"mandi.a_grade"), 14, FIELD_GREEN_LIGHT)
		name_row.add_child(graded_label)
	name_col.add_child(name_row)
	name_col.add_child(_make_title_label(tr(&"mandi.held") % held, 14))
	left.add_child(name_col)

	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(_make_title_label("%s %d%%" % [row_data["trend"], row_data["pct"]], 15))
	if _economy.state.has_mandi_terminal:
		var forecast: int = row_data["forecast_percent"]
		var forecast_trend := "▲" if forecast >= 0 else "▼"
		var forecast_sign := "+" if forecast >= 0 else ""
		# A11Y fix (village-board-and-management-sheets-audit-2026-08-21.md
		# §5, HIGH): 10px -> this project's 14px floor.
		right.add_child(_make_title_label(tr(&"mandi.tomorrow_forecast") % [forecast_trend, forecast_sign, forecast], 14))

	info_row.add_child(left)
	info_row.add_child(right)
	box.add_child(info_row)

	var sell_button := _build_sell_button(crop, held)
	box.add_child(sell_button)

	card.add_child(box)
	return card


func _build_sell_button(crop: int, held: int) -> Button:
	var affordable_to_sell := held > 0
	var button := _make_chunky_button(
		(tr(&"mandi.sell_button") % held) if affordable_to_sell else tr(&"mandi.nothing_to_sell"),
		SAFFRON_DARK,
		Color.WHITE,
		affordable_to_sell
	)
	if affordable_to_sell:
		button.pressed.connect(_on_sell_pressed.bind(crop))
	return button


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
