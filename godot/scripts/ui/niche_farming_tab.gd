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

# Palette -- now sourced from ui_theme.gd (Track A consolidation, see that
# file's class doc); kept as local aliases so no call site below changed.
const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK
const WOOD_BROWN_LIGHT := UiTheme.WOOD_BROWN_MID
const GOLD_LIGHT := UiTheme.GOLD_LIGHT
const RIPE_GOLD := UiTheme.RIPE_GOLD
const FIELD_GREEN := UiTheme.FIELD_GREEN
const TEXT_SHADOW_COLOR := UiTheme.TEXT_SHADOW_COLOR
## §2.4 disabled-button state: the Excavate/Build/electricity actions below
## previously always rendered full-saturation regardless of affordability
## (the same BLOCKING gap design/art/ui-visual-direction-2026-08.md §1.1
## calls out for farmhouse_tab.gd's Upgrade button, present here too).
const UNAFFORDABLE_ALPHA: float = UiTheme.UNAFFORDABLE_ALPHA

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

	_body.add_child(_make_section_header(tr(&"niche.aquaculture_header")))
	if not data["has_aquaculture"]:
		_body.add_child(_build_build_card(
			"🪷", tr(&"niche.aquaculture_title"),
			tr(&"niche.aquaculture_blurb") % GameData.AQUACULTURE_PLOT_COUNT,
			tr(&"niche.aquaculture_button") % data["aquaculture_cost"], data["aquaculture_cost"], _on_build_aquaculture_pressed
		))
	else:
		# EPIC-M7: worker assignment, only meaningful once the zone exists.
		var aquaculture_worker_row := WorkerAssignmentRow.new()
		aquaculture_worker_row.configure(_economy, _village_board, PlotKind.Kind.AQUACULTURE)
		_body.add_child(aquaculture_worker_row)

	_body.add_child(HSeparator.new())

	_body.add_child(_make_section_header(tr(&"niche.vertical_farm_header")))
	if not data["has_vertical_farm"]:
		_body.add_child(_build_build_card(
			"🌸", tr(&"niche.vertical_farm_title"),
			tr(&"niche.vertical_farm_blurb") % GameData.VERTICAL_FARM_PLOT_COUNT,
			tr(&"niche.vertical_farm_button") % data["vertical_farm_cost"], data["vertical_farm_cost"], _on_build_vertical_farm_pressed
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
	if _economy.dirty:
		_play_audio(&"progression_structure_unlock")
		_village_board.play_construction_effect(VillageSnapshotMapper.ZONE_ID_AQUACULTURE)
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_build_vertical_farm_pressed() -> void:
	_economy.buy_vertical_farm()
	if _economy.dirty:
		_play_audio(&"progression_structure_unlock")
		_village_board.play_construction_effect(VillageSnapshotMapper.ZONE_ID_VERTICAL_FARM)
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


## No active-guard -- matches the Kotlin original's ElectricityBar chip
## exactly (`onClick = { viewModel.renewElectricity() }`, always callable,
## since paying early to top up the remaining duration is legitimate, same
## rationale as polyhouse_tab.gd's Renew Film chip).
func _on_electricity_pressed() -> void:
	_economy.renew_electricity(_now())
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

# A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §1): both
# _make_section_header() and _build_build_card() add their labels directly to
# the sheet body, which sits on BottomSheet's cream background -- these must
# use SOIL_BROWN_DARK, not the Color.WHITE default that's only safe on
# colored panel backgrounds.
func _make_section_header(title: String) -> Label:
	return _make_title_label(title, 16, SOIL_BROWN_DARK)


func _build_build_card(
	emoji: String, title: String, description: String, cost_label: String, cost: int, on_pressed: Callable
) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", UiTheme.scale_px(14))

	var emoji_label := Label.new()
	emoji_label.text = emoji
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.label_settings = _make_label_settings(40, SOIL_BROWN_DARK)
	box.add_child(emoji_label)

	# ONE combined Label (title+description joined by a newline), built via
	# UiTheme.make_wrapping_label() (not _make_title_label()/LabelSettings)
	# since this text autowraps -- LabelSettings + autowrap together ghost
	# on this project's pinned gl_compatibility renderer. See that
	# function's own doc comment and
	# docs/engine-reference/godot/breaking-changes.md for the full
	# investigation. Font size 15 keeps both lines at/above this project's
	# 14px accessibility floor (§5, HIGH), same rationale the old separate
	# description_label's own 14px already carried.
	var title_description_label := UiTheme.make_wrapping_label(
		"%s\n%s" % [title, description], 15, SOIL_BROWN_DARK
	)
	title_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_description_label)

	var can_afford: bool = _economy.state.coins >= cost
	var build_button := _make_chunky_button(cost_label, FIELD_GREEN, Color.WHITE, can_afford)
	if can_afford:
		build_button.pressed.connect(on_pressed)
	box.add_child(build_button)

	return box


## Kept as a local pill (not routed through UiTheme.make_chunky_button()) --
## same call this file's sibling sheets already made for their own chips
## (polyhouse_tab.gd's _build_chip()): a rounded pill with active/inactive
## color-swap is a distinct shape from the Kenney 9-slice rectangular button
## chrome, so it stays a local StyleBoxFlat rather than being forced through
## a constructor built for a different silhouette.
##
## §2.4 disabled state (new): previously always clickable regardless of
## affordability -- now dims and disables when `coins` can't cover
## data["electricity_cost"], even while `active` (topping up early while
## already powered is legitimate, but only if the player can actually pay
## for it -- see _on_electricity_pressed()'s own doc comment on why no
## active-guard exists here).
func _build_electricity_chip(data: Dictionary) -> Button:
	var active: bool = data["electricity_active"]
	var can_afford: bool = _economy.state.coins >= data["electricity_cost"]
	var chip := Button.new()
	chip.text = (
		(tr(&"niche.electricity_powered") % format_hours_minutes(data["electricity_remaining_ms"]))
		if active else (tr(&"niche.electricity_pay") % data["electricity_cost"])
	)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.focus_mode = Control.FOCUS_NONE
	chip.disabled = not can_afford
	var base_color: Color = RIPE_GOLD if active else WOOD_BROWN_LIGHT
	var alpha: float = 1.0 if can_afford else UNAFFORDABLE_ALPHA
	var style := StyleBoxFlat.new()
	style.bg_color = Color(base_color.r, base_color.g, base_color.b, alpha)
	style.set_corner_radius_all(UiTheme.scale_px(20))
	style.set_border_width_all(UiTheme.scale_px(2))
	style.border_color = Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, alpha)
	style.shadow_size = UiTheme.scale_px(3) if can_afford else 0
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = UiTheme.scale_px(12)
	style.content_margin_right = UiTheme.scale_px(12)
	style.content_margin_top = UiTheme.scale_px(10)
	style.content_margin_bottom = UiTheme.scale_px(10)
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		chip.add_theme_stylebox_override(state_name, style)
	# A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §1):
	# Color.WHITE on the active RIPE_GOLD background measured ~1.63:1 contrast
	# -- unreadable. Only the inactive WOOD_BROWN_LIGHT state is dark enough
	# for white text.
	var font_color: Color = SOIL_BROWN_DARK if active else Color.WHITE
	var font_alpha: float = 1.0 if can_afford else 0.5
	chip.add_theme_color_override("font_color", Color(font_color.r, font_color.g, font_color.b, font_alpha))
	chip.add_theme_color_override("font_disabled_color", Color(font_color.r, font_color.g, font_color.b, font_alpha))
	# A11Y fix (§5, HIGH): 13px -> this project's 14px floor -- this chip's
	# text ("Powered: Xh Ym left") is frequently-read status, not decoration.
	chip.add_theme_font_size_override("font_size", UiTheme.scale_font(14))
	if can_afford:
		chip.pressed.connect(_on_electricity_pressed)
	return chip


# Track A consolidation: every helper below now delegates to ui_theme.gd
# (see that file's class doc) -- call sites throughout this file unchanged.
func _make_chunky_button(label_text: String, color: Color, font_color: Color = Color.WHITE, enabled: bool = true) -> Button:
	return UiTheme.make_chunky_button(label_text, color, font_color, enabled)


func _make_title_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	return UiTheme.make_title_label(text, font_size, color)


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	return UiTheme.make_label_settings(font_size, color)
