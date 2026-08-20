## The LiveOps Events sheet -- ported from EventsUi.kt's `EventsTab`
## composable (MonsoonCard + FestivalCard). Shown via BottomSheet.open() when
## the HUD's LiveOps banner is tapped (see hud.gd's `_on_liveops_banner_pressed()`)
## -- matches the real shipped app exactly: `IsoSheet.Events` is reached only
## via `LiveOpsBanner(onTapped = { activeSheet = IsoSheet.Events })` in
## FarmScreen.kt, never from a board-zone tap (there is no "Events zone" on
## the board).
##
## ARCHITECTURE: small static shell (Scroll/Body only), full content built
## procedurally in _populate() -- same split every other ported sheet uses.
## Visual language matches those sheets exactly.
##
## DESIGN CALL: buying the Premium Pass does NOT close this sheet -- it
## re-populates in place, immediately showing the "🎫 Premium Pass active"
## confirmation, same rationale as every other ported sheet's purchase flow.
class_name EventsTab
extends VBoxContainer

# Palette -- ported verbatim from app/src/main/java/com/zonkrik/ifarming/
# ui/theme/Color.kt, same values every other ported sheet already uses.
const SOIL_BROWN_DARK := Color("#3E2412")
const WOOD_BROWN_LIGHT := Color("#8A5A34")
const GOLD_LIGHT := Color("#FFE082")
const RIPE_GOLD := Color("#FFC107")
const SAFFRON_DARK := Color("#C56A00")
const FIELD_GREEN_LIGHT := Color("#66BB6A")
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)
const DISABLED_ALPHA: float = 0.4

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
	var now := _now()
	var data := build_view_data(_economy, now)
	_body.add_child(_build_monsoon_card(data))
	_body.add_child(_build_festival_card(data))


func _now() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


# ---------------------------------------------------------------------------
# Pure logic -- unit-tested directly (tests/unit/test_events_tab.gd), no
# scene-tree dependency.
# ---------------------------------------------------------------------------

## Mirrors MonsoonCard/FestivalCard's own local reads exactly, gathered into
## one testable Dictionary (same pattern every other ported sheet uses).
static func build_view_data(economy: GameEconomy, now: int) -> Dictionary:
	var festival := economy.current_festival(now)
	var preview := economy.event_state_preview(now)
	var tier: int = preview.event_claimed_tier
	var next_threshold: Variant = (
		GameData.FESTIVAL_TIER_THRESHOLDS[tier] if tier < GameData.FESTIVAL_TIER_THRESHOLDS.size() else null
	)
	var progress: float = 1.0
	if next_threshold != null:
		progress = clampf(float(preview.event_points) / float(next_threshold), 0.0, 1.0)
	return {
		"monsoon_active": economy.is_monsoon_active(now),
		"monsoon_remaining_ms": economy.monsoon_phase_remaining_ms(now),
		"festival_active": economy.is_festival_active(now),
		"festival_remaining_ms": economy.festival_phase_remaining_ms(now),
		"festival": festival,
		"event_points": preview.event_points,
		"event_tier": tier,
		"next_threshold": next_threshold,
		"progress": progress,
		"has_premium": preview.event_has_premium_pass,
	}


## "XhYm"/"Ym" -- matches EventsUi.kt's formatDuration() (identical logic to
## NicheFarmingUi.kt's formatHoursMinutes(), kept as a separate function here
## the same way MandiTab.is_crop_relevant() is deliberately separate from
## GameData.crops_for_plot_kind() -- same file, same call site, no shared
## dependency worth introducing for two identical one-liners ported from two
## different Kotlin files).
static func format_duration(remaining_ms: int) -> String:
	var total_minutes: int = maxi(remaining_ms / 60_000, 0)
	var hours: int = total_minutes / 60
	var minutes: int = total_minutes % 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	return "%dm" % minutes


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_premium_pass_pressed() -> void:
	_economy.buy_premium_pass(_now())
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


# ---------------------------------------------------------------------------
# Widget construction
# ---------------------------------------------------------------------------

func _build_monsoon_card(data: Dictionary) -> PanelContainer:
	var active: bool = data["monsoon_active"]
	var card := _make_panel(RIPE_GOLD.lerp(WOOD_BROWN_LIGHT, 0.5) if active else WOOD_BROWN_LIGHT, 14)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)

	box.add_child(_make_title_label(
		"🌧️ Monsoon Season -- Active" if active else "☁️ Monsoon Season", 17
	))
	var remaining := format_duration(data["monsoon_remaining_ms"])
	box.add_child(_make_title_label(
		"Ends in %s" % remaining if active else "Next monsoon in %s" % remaining, 12
	))
	var blurb := _make_title_label(
		(
			"While active, open-field crops grow 20% faster but risk a 10% chance of total "
			+ "flood loss when they mature. Polyhouse owners are completely immune."
		),
		12
	)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(blurb)

	card.add_child(box)
	return card


func _build_festival_card(data: Dictionary) -> PanelContainer:
	var festival: FestivalDef = data["festival"]
	var active: bool = data["festival_active"]
	var next_threshold: Variant = data["next_threshold"]

	var card := _make_panel(WOOD_BROWN_LIGHT, 14)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)

	box.add_child(_make_title_label("%s %s" % [festival.emoji, festival.display_name], 17))
	var remaining := format_duration(data["festival_remaining_ms"])
	box.add_child(_make_title_label(
		"Active -- ends in %s" % remaining if active else "Not running -- next festival in %s" % remaining, 12
	))
	var crop_def := GameData.crop_def(festival.target_crop)
	var target_blurb := _make_title_label(
		(
			"Sell %s %s while the festival is running to earn Event Points and climb the reward "
			% [crop_def.emoji, crop_def.display_name]
			+ "tiers."
		),
		12
	)
	target_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(target_blurb)

	box.add_child(_make_title_label(
		(
			"Points: %d / %d" % [data["event_points"], next_threshold] if next_threshold != null
			else "Points: %d -- all tiers reached!" % data["event_points"]
		),
		13
	))
	box.add_child(_build_progress_bar(data["progress"]))

	var tiers_box := VBoxContainer.new()
	tiers_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tiers_box.add_theme_constant_override("separation", 4)
	for index in range(GameData.FESTIVAL_TIER_THRESHOLDS.size()):
		tiers_box.add_child(_build_tier_row(
			index + 1, GameData.FESTIVAL_TIER_THRESHOLDS[index], GameData.FESTIVAL_FREE_REWARDS[index],
			GameData.FESTIVAL_PREMIUM_BONUS[index], data["event_tier"] > index, data["has_premium"]
		))
	box.add_child(tiers_box)

	if data["has_premium"]:
		var active_label := _make_title_label("🎫 Premium Pass active for this festival", 12, RIPE_GOLD)
		box.add_child(active_label)
	else:
		box.add_child(_build_premium_pass_button(active))

	card.add_child(box)
	return card


func _build_tier_row(
	tier_number: int, threshold: int, free_reward: int, premium_reward: int, reached: bool, has_premium: bool
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	var left := _make_title_label(
		"%s Tier %d (%d pts)" % ["✅" if reached else "▫️", tier_number, threshold], 12
	)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var reward_text := (
		"₹%d + ₹%d" % [free_reward, premium_reward] if has_premium
		else "₹%d (+₹%d 🔒)" % [free_reward, premium_reward]
	)
	row.add_child(_make_title_label(reward_text, 12))

	return row


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
	bg_style.bg_color = SOIL_BROWN_DARK
	bg_style.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = FIELD_GREEN_LIGHT
	fill_style.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("fill", fill_style)

	return bar


func _build_premium_pass_button(festival_active: bool) -> Button:
	var button := Button.new()
	button.text = (
		"Buy Premium Pass -- ₹%d" % GameData.FESTIVAL_PREMIUM_PASS_COST if festival_active
		else "Premium Pass available during festivals"
	)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not festival_active
	var style := StyleBoxFlat.new()
	style.bg_color = Color(SAFFRON_DARK.r, SAFFRON_DARK.g, SAFFRON_DARK.b, 1.0 if festival_active else DISABLED_ALPHA)
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 1.0 if festival_active else DISABLED_ALPHA)
	style.shadow_size = 4 if festival_active else 0
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, DISABLED_ALPHA))
	button.add_theme_font_size_override("font_size", 13)
	if festival_active:
		button.pressed.connect(_on_premium_pass_pressed)
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
