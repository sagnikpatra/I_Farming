## The Niche-farming management sheet -- ported from NicheFarmingUi.kt's
## `NicheFarmingTab` composable. Shown via BottomSheet.open() when
## board_interactor.gd's tap-select handling picks either the Aquaculture or
## the Vertical Farm zone (both open this SAME sheet, matching the real
## shipped app -- Kotlin's `IsoSheet.Niche` is one combined sheet for both
## zones, not two separate ones; see board_interactor.gd's
## _maybe_open_zone_sheet()). Shows two stacked sections (🪷 Makhana Ponds,
## 🌸 Saffron Vertical Farm), each with its own build card or, once built,
## its own status row -- matches `showPlots = false`: no plot grid here,
## board taps already handle planting/harvesting directly, same rationale as
## polyhouse_tab.gd/agroforestry_tab.gd.
##
## ARCHITECTURE: small static shell (Scroll/Body only), full content built
## procedurally in _populate() -- same split every other ported sheet uses.
## Visual language matches those sheets exactly.
##
## DESIGN CALL (same rationale as the other sheets): building either zone or
## paying the electricity bill does NOT close this sheet -- it re-populates
## in place, so buying Aquaculture immediately reveals nothing further to
## configure there (no upgrades), while paying electricity keeps the
## Vertical Farm section visible with its updated remaining-time readout.
class_name NicheFarmingTab
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
	var data := build_view_data(_economy, _now())

	_body.add_child(_make_section_header("🪷 Makhana Ponds"))
	if not data["has_aquaculture"]:
		_body.add_child(_build_build_card(
			"🪷", "Excavate Ponds",
			(
				"Unlocks %d pond plots for Makhana (Fox Nut) and Pond Fish -- a cheaper, " %
				GameData.AQUACULTURE_PLOT_COUNT
				+ "faster-cycling alternative to Polyhouse crops."
			),
			"Excavate for ₹%d" % data["aquaculture_cost"], _on_build_aquaculture_pressed
		))
	else:
		# EPIC-M7: worker assignment, only meaningful once the zone exists.
		var aquaculture_worker_row := WorkerAssignmentRow.new()
		aquaculture_worker_row.configure(_economy, _village_board, PlotKind.Kind.AQUACULTURE)
		_body.add_child(aquaculture_worker_row)

	_body.add_child(HSeparator.new())

	_body.add_child(_make_section_header("🌸 Saffron Vertical Farm"))
	if not data["has_vertical_farm"]:
		_body.add_child(_build_build_card(
			"🌸", "Build a Vertical Farm",
			(
				"Only %d tiles, but Saffron sells for more per unit than anything except " %
				GameData.VERTICAL_FARM_PLOT_COUNT
				+ "Sandalwood. Running the grow lights needs a recurring electricity payment "
				+ "to keep planting new cycles."
			),
			"Build for ₹%d" % data["vertical_farm_cost"], _on_build_vertical_farm_pressed
		))
	else:
		_body.add_child(_build_electricity_chip(data))
		# EPIC-M7: worker assignment, only meaningful once the zone exists.
		var vertical_farm_worker_row := WorkerAssignmentRow.new()
		vertical_farm_worker_row.configure(_economy, _village_board, PlotKind.Kind.VERTICAL_FARM)
		_body.add_child(vertical_farm_worker_row)


func _now() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


# ---------------------------------------------------------------------------
# Pure logic -- unit-tested directly (tests/unit/test_niche_farming_tab.gd),
# no scene-tree dependency.
# ---------------------------------------------------------------------------

## Mirrors NicheFarmingTab/ElectricityBar's own local reads exactly,
## gathered into one testable Dictionary (same pattern every other ported
## sheet uses).
static func build_view_data(economy: GameEconomy, now: int) -> Dictionary:
	var state := economy.state
	var electricity_active := economy.is_electricity_active(now)
	var remaining_ms: int = 0
	if state.electricity_expires_at_epoch_ms != -1:
		remaining_ms = maxi(state.electricity_expires_at_epoch_ms - now, 0)
	return {
		"has_aquaculture": state.has_aquaculture,
		"aquaculture_cost": GameData.AQUACULTURE_UNLOCK_COST,
		"has_vertical_farm": state.has_vertical_farm,
		"vertical_farm_cost": GameData.VERTICAL_FARM_UNLOCK_COST,
		"electricity_active": electricity_active,
		"electricity_remaining_ms": remaining_ms,
		"electricity_cost": GameData.ELECTRICITY_COST,
	}


## "XhYm"/"Ym" -- matches NicheFarmingUi.kt's formatHoursMinutes() exactly
## (hours omitted entirely when zero, minutes always shown).
static func format_hours_minutes(remaining_ms: int) -> String:
	var total_minutes: int = maxi(remaining_ms / 60_000, 0)
	var hours: int = total_minutes / 60
	var minutes: int = total_minutes % 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	return "%dm" % minutes


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_build_aquaculture_pressed() -> void:
	_economy.buy_aquaculture()
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_build_vertical_farm_pressed() -> void:
	_economy.buy_vertical_farm()
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


## No active-guard -- matches the Kotlin original's ElectricityBar chip
## exactly (`onClick = { viewModel.renewElectricity() }`, always callable,
## since paying early to top up the remaining duration is legitimate, same
## rationale as polyhouse_tab.gd's Renew Film chip).
func _on_electricity_pressed() -> void:
	_economy.renew_electricity(_now())
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


# ---------------------------------------------------------------------------
# Widget construction
# ---------------------------------------------------------------------------

func _make_section_header(title: String) -> Label:
	return _make_title_label(title, 16)


func _build_build_card(
	emoji: String, title: String, description: String, cost_label: String, on_pressed: Callable
) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)

	var emoji_label := Label.new()
	emoji_label.text = emoji
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.label_settings = _make_label_settings(40, Color.WHITE)
	box.add_child(emoji_label)

	var title_label := _make_title_label(title, 17)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	var description_label := _make_title_label(description, 13)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(description_label)

	var build_button := _make_chunky_button(cost_label, FIELD_GREEN)
	build_button.pressed.connect(on_pressed)
	box.add_child(build_button)

	return box


func _build_electricity_chip(data: Dictionary) -> Button:
	var active: bool = data["electricity_active"]
	var chip := Button.new()
	chip.text = (
		"⚡ Powered: %s left" % format_hours_minutes(data["electricity_remaining_ms"])
		if active else "⚡ Pay Electricity ₹%d" % data["electricity_cost"]
	)
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
	chip.pressed.connect(_on_electricity_pressed)
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
