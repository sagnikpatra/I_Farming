## The Polyhouse management sheet -- ported from FarmScreen.kt's PolyhouseTab
## composable (and its PolyhouseBuildCard/PolyhouseUpgradesBar/UpgradeChip
## helpers). Shown via BottomSheet.open() when board_interactor.gd's
## tap-select handling picks the Polyhouse zone (see
## board_interactor.gd's _maybe_open_zone_sheet()). Shows a build card (with
## the Subsidy Quest progress bar) if not yet built, otherwise three upgrade
## chips (Fan & Pad, Drip Irrigation, Renew Film) -- matches the Kotlin
## original's content and behavior exactly, including `showPlots = false`:
## the plot list itself is NOT rendered here (board taps already handle
## planting/harvesting directly, per the direct-tap-harvest correction in
## board_interactor.gd -- this sheet only ever managed upgrades, same as the
## real shipped app's PolyhouseTab(showPlots = false) call site).
##
## ARCHITECTURE: small static shell in polyhouse_tab.tscn (Scroll/Body only),
## full content built procedurally in _populate() -- same split
## farmhouse_tab.gd/mandi_tab.gd use, for the same reason (every visible
## element here is state-dependent). Visual language matches hud.gd/
## seed_picker.gd/farmhouse_tab.gd/mandi_tab.gd exactly (same ported
## Color.kt palette, StyleBoxFlat corner_radius/border/shadow, LabelSettings
## drop-shadow text, explicit mouse_filter on every node) -- not a new idiom.
## The Kotlin original's UpgradeChip uses a two-tone vertical gradient
## (topColor/bottomColor); simplified here to a single flat bg_color per
## chip state, same simplification every other ported sheet already made
## from ChunkyTile/ChunkyButton's gradient look (see hud.gd's class doc on
## "flat StyleBoxFlat styling is the explicit bar for this round").
##
## DESIGN CALL (same rationale as farmhouse_tab.gd's upgrade button /
## mandi_tab.gd's register-and-sell buttons): none of building the
## Polyhouse or buying an upgrade closes this sheet -- each just
## re-populates in place, so building immediately reveals the upgrade chips
## without requiring the player to close and re-tap the zone.
class_name PolyhouseTab
extends VBoxContainer

# Palette -- ported verbatim from app/src/main/java/com/zonkrik/ifarming/
# ui/theme/Color.kt, same values hud.gd/seed_picker.gd/farmhouse_tab.gd/
# mandi_tab.gd already use.
const SOIL_BROWN_DARK := Color("#3E2412")
const WOOD_BROWN_LIGHT := Color("#8A5A34")
const GOLD_LIGHT := Color("#FFE082")
const RIPE_GOLD := Color("#FFC107")
const SAFFRON_DARK := Color("#C56A00")
const FIELD_GREEN := Color("#4CAF50")
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)

@onready var _body: VBoxContainer = $Scroll/Body

var _economy: GameEconomy
var _village_board: VillageBoard


## Must be called before this instance is added under a BottomSheet's content
## slot -- same precondition/ordering guarantee as FarmhouseTab.configure()/
## MandiTab.configure().
func configure(economy: GameEconomy, village_board: VillageBoard) -> void:
	_economy = economy
	_village_board = village_board


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_populate()


func _populate() -> void:
	for child in _body.get_children():
		child.queue_free()
	var data := build_view_data(_economy, _now())
	if not data["has_polyhouse"]:
		_body.add_child(_build_build_card(data))
		return
	_body.add_child(_build_upgrades_row(data))

	# EPIC-M7: worker assignment, only meaningful once the zone exists.
	var worker_row := WorkerAssignmentRow.new()
	worker_row.configure(_economy, _village_board, PlotKind.Kind.POLYHOUSE)
	_body.add_child(worker_row)


func _now() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


# ---------------------------------------------------------------------------
# Pure logic -- unit-tested directly (tests/unit/test_polyhouse_tab.gd), no
# scene-tree dependency. Not underscore-prefixed for the same reason
# hud.gd's build_inventory_display()/seed_picker.gd's build_row_data()/
# farmhouse_tab.gd's build_view_data() aren't.
# ---------------------------------------------------------------------------

## Everything _populate() needs to know to render this sheet, computed once
## from `economy`'s current state. Mirrors PolyhouseTab/PolyhouseBuildCard's
## own local `subsidyUnlocked`/`cost`/`progress`/`filmActive` locals exactly,
## gathered into one testable Dictionary (same pattern
## FarmhouseTab.build_view_data() uses).
static func build_view_data(economy: GameEconomy, now: int) -> Dictionary:
	var state := economy.state
	var subsidy_unlocked := GameData.is_subsidy_unlocked(state.total_harvests)
	return {
		"has_polyhouse": state.has_polyhouse,
		"subsidy_unlocked": subsidy_unlocked,
		"cost": GameData.polyhouse_cost(subsidy_unlocked),
		"subsidy_progress": clampf(
			float(state.total_harvests) / float(GameData.SUBSIDY_QUEST_TARGET), 0.0, 1.0
		),
		"has_fan_pad": state.has_fan_pad,
		"has_drip_irrigation": state.has_drip_irrigation,
		"film_active": economy.is_film_active(now),
	}


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_build_pressed() -> void:
	_economy.buy_polyhouse()
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


## Guarded the same way the Kotlin original's onClick does
## (`if (!state.hasFanPad) viewModel.buyFanPad()`) -- the chip becomes
## inert once active rather than relying solely on buy_fan_pad()'s own
## already-built no-op guard, so a tap on an active chip does nothing
## visible at all (no wasted persist/rebuild call).
func _on_fan_pad_pressed() -> void:
	if _economy.state.has_fan_pad:
		return
	_economy.buy_fan_pad()
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_drip_pressed() -> void:
	if _economy.state.has_drip_irrigation:
		return
	_economy.buy_drip_irrigation()
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


## No active-guard, unlike the two chips above -- matches the Kotlin
## original's "Renew Film" chip exactly (always clickable, since renewing
## early to top up the remaining duration is a legitimate action, not just a
## one-shot unlock).
func _on_film_pressed() -> void:
	_economy.renew_film(_now())
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


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
	emoji_label.text = "🏠"
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.label_settings = _make_label_settings(48, SOIL_BROWN_DARK)
	box.add_child(emoji_label)

	var title_label := _make_title_label("Build a Naturally Ventilated Polyhouse", 18, SOIL_BROWN_DARK)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(title_label)

	var blurb_label := _make_title_label(
		"Unlocks %d protected plots for Colored Capsicum and Dutch Rose." % GameData.POLYHOUSE_PLOT_COUNT,
		13,
		SOIL_BROWN_DARK
	)
	blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(blurb_label)

	box.add_child(_build_subsidy_card(data))

	var build_button := _make_chunky_button("Build for ₹%d" % data["cost"], FIELD_GREEN)
	build_button.pressed.connect(_on_build_pressed)
	box.add_child(build_button)

	return box


func _build_subsidy_card(data: Dictionary) -> PanelContainer:
	var card := _make_panel(WOOD_BROWN_LIGHT, 14)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)

	var title := "🎉 Subsidy unlocked!" if data["subsidy_unlocked"] else "Subsidy Quest"
	box.add_child(_make_title_label(title, 14))
	box.add_child(_build_progress_bar(data["subsidy_progress"]))

	card.add_child(box)
	return card


func _build_progress_bar(progress: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = progress
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	bg_style.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = RIPE_GOLD
	fill_style.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("fill", fill_style)

	return bar


func _build_upgrades_row(data: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	row.add_child(_build_chip(
		"Fan & Pad ✓" if data["has_fan_pad"] else "Fan & Pad", data["has_fan_pad"], _on_fan_pad_pressed
	))
	row.add_child(_build_chip(
		"Drip ✓" if data["has_drip_irrigation"] else "Drip Irrigation", data["has_drip_irrigation"], _on_drip_pressed
	))
	row.add_child(_build_chip(
		"Film Active ✓" if data["film_active"] else "Renew Film", data["film_active"], _on_film_pressed
	))

	return row


func _build_chip(label_text: String, active: bool, on_pressed: Callable) -> Button:
	var chip := Button.new()
	chip.text = label_text
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.focus_mode = Control.FOCUS_NONE
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = RIPE_GOLD if active else WOOD_BROWN_LIGHT
	style.set_corner_radius_all(50)
	style.set_border_width_all(2)
	style.border_color = SAFFRON_DARK if active else GOLD_LIGHT
	style.shadow_size = 3
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	for state_name in ["normal", "hover", "pressed", "focus"]:
		chip.add_theme_stylebox_override(state_name, style)
	# A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §1):
	# Color.WHITE on the active RIPE_GOLD background measured ~1.63:1 contrast
	# -- unreadable. Only the inactive WOOD_BROWN_LIGHT state is dark enough
	# for white text.
	chip.add_theme_color_override("font_color", SOIL_BROWN_DARK if active else Color.WHITE)
	chip.add_theme_font_size_override("font_size", 12)
	chip.pressed.connect(on_pressed)
	return chip


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


func _make_panel(bg_color: Color, corner_radius: int, border_color: Color = GOLD_LIGHT) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(corner_radius)
	style.set_border_width_all(2)
	style.border_color = border_color
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel


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
