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

# Palette -- now sourced from ui_theme.gd (Track A consolidation, see that
# file's class doc); kept as local aliases so no call site below changed.
# FIELD_GREEN_LIGHT has no UiTheme equivalent (matches mandi_tab.gd's own
# same-named local const -- the Kotlin original's "A-Grade"/progress-bar
# accent, not part of the shared role palette) and stays a local literal.
const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK
const WOOD_BROWN_LIGHT := UiTheme.WOOD_BROWN_MID
const GOLD_LIGHT := UiTheme.GOLD_LIGHT
const RIPE_GOLD := UiTheme.RIPE_GOLD
const SAFFRON_DARK := UiTheme.SAFFRON_DARK
const FIELD_GREEN_LIGHT := Color("#66BB6A")
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
	var now := _now()
	var data := build_view_data(_economy, now)
	_body.add_child(_build_monsoon_card(data))
	_body.add_child(_build_festival_card(data))
	_body.add_child(_build_chanda_card(data))
	_body.add_child(_build_daily_tasks_card(data))


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
		"chanda_awaiting_decision": economy.chanda_visit_awaiting_decision(now),
		"chanda_festival": economy.current_chanda_festival(now),
		"chanda_remaining_ms": economy.chanda_visit_phase_remaining_ms(now),
		"chanda_ask": economy.chanda_ask_amount(),
		"chanda_blessing_active": now < economy.state.chanda_blessing_active_until,
		"chanda_blessing_remaining_ms": economy.state.chanda_blessing_active_until - now,
		"can_afford_chanda": economy.state.coins >= economy.chanda_ask_amount(),
		"gems": economy.state.gems,
		"daily_tasks": _daily_task_rows(economy, now),
		"daily_bonus_claimed": economy.daily_tasks_state_preview(now).daily_task_bonus_claimed,
		"can_reroll": _can_reroll(economy, now),
	}


## One row per today's task -- kind, def, progress, claimed. Built from
## daily_tasks_state_preview() (never mutates state), same non-mutating
## read rationale as event_state_preview().
static func _daily_task_rows(economy: GameEconomy, now: int) -> Array:
	var preview := economy.daily_tasks_state_preview(now)
	var rows: Array = []
	for kind: int in preview.daily_task_kinds:
		var task_def := GameData.daily_task_def_for_kind(kind)
		rows.append({
			"kind": kind,
			"def": task_def,
			"progress": mini(int(preview.daily_task_progress.get(kind, 0)), task_def.target),
			"claimed": preview.daily_task_claimed.get(kind, false),
		})
	return rows


static func _can_reroll(economy: GameEconomy, now: int) -> bool:
	var preview := economy.daily_tasks_state_preview(now)
	if preview.gems < GameData.DAILY_TASK_REROLL_COST:
		return false
	for kind: int in preview.daily_task_kinds:
		if preview.daily_task_claimed.get(kind, false):
			return false
	return true


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


func _on_give_chanda_pressed() -> void:
	_economy.give_chanda(_now())
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_decline_chanda_pressed() -> void:
	_economy.decline_chanda(_now())
	_village_board.persist_and_rebuild_if_dirty()
	_populate()


func _on_reroll_daily_tasks_pressed() -> void:
	_economy.reroll_daily_tasks(_now())
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

	# A11Y fix (village-board-and-management-sheets-audit-2026-08-21.md §1,
	# HIGH -- flagged in the audit's own table but never carried into its
	# Summary Table, so it stayed unfixed alongside that pass's BLOCKING
	# rows): white text on the active RIPE_GOLD.lerp(WOOD_BROWN_LIGHT, 0.5)
	# background measured ~3.03:1, below 4.5:1 even for the 17px title (which
	# doesn't clear the large-text 3:1 threshold either) -- same defect
	# family as the RIPE_GOLD active-chip fix already applied elsewhere
	# (agroforestry_tab.gd/niche_farming_tab.gd), same SOIL_BROWN_DARK fix.
	# The inactive WOOD_BROWN_LIGHT background is unaffected -- that's the
	# audit's own explicitly-cited "safe" baseline, used unchanged.
	var text_color: Color = SOIL_BROWN_DARK if active else Color.WHITE
	box.add_child(_make_title_label(
		tr(&"events.monsoon_active_title") if active else tr(&"events.monsoon_inactive_title"), 17, text_color
	))
	var remaining := format_duration(data["monsoon_remaining_ms"])
	# A11Y fix (§5, HIGH): both raised 12px -> this project's 14px floor.
	box.add_child(_make_title_label(
		(tr(&"events.monsoon_ends_in") % remaining) if active else (tr(&"events.monsoon_next_in") % remaining), 14, text_color
	))
	var blurb := _make_title_label(
		tr(&"events.monsoon_blurb"),
		14,
		text_color
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
	# A11Y fix (§5, HIGH): both raised 12px -> this project's 14px floor.
	box.add_child(_make_title_label(
		(tr(&"events.festival_active_ends_in") % remaining) if active else (tr(&"events.festival_inactive_next_in") % remaining), 14
	))
	var crop_def := GameData.crop_def(festival.target_crop)
	var target_blurb := _make_title_label(
		tr(&"events.festival_target_blurb") % [crop_def.emoji, crop_def.display_name],
		14
	)
	target_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(target_blurb)

	box.add_child(_make_title_label(
		(
			(tr(&"events.festival_points") % [data["event_points"], next_threshold]) if next_threshold != null
			else (tr(&"events.festival_points_maxed") % data["event_points"])
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

	# A11Y fix (village-board-and-management-sheets-audit-2026-08-21.md §5,
	# HIGH): raised to this project's 14px floor -- applies to
	# active_label below and both labels in _build_tier_row().
	if data["has_premium"]:
		var active_label := _make_title_label(tr(&"events.premium_pass_active"), 14, RIPE_GOLD)
		box.add_child(active_label)
	else:
		box.add_child(_build_premium_pass_button(active))

	card.add_child(box)
	return card


## The Chanda Visit card (design/gdd/festival-visiting-npcs.md) -- an
## independent companion to the Festival Pass card above, never gated on or
## combined with it. Three states: awaiting a Give/Decline decision, a
## blessing currently active, or neither (a quiet "next visit in X" line).
func _build_chanda_card(data: Dictionary) -> PanelContainer:
	var festival: ChandaFestivalDef = data["chanda_festival"]
	var awaiting: bool = data["chanda_awaiting_decision"]
	var blessing_active: bool = data["chanda_blessing_active"]

	var card := _make_panel(RIPE_GOLD.lerp(WOOD_BROWN_LIGHT, 0.5) if awaiting else WOOD_BROWN_LIGHT, 14)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)

	var text_color: Color = SOIL_BROWN_DARK if awaiting else Color.WHITE
	box.add_child(_make_title_label("%s %s" % [festival.emoji, festival.display_name], 17, text_color))

	if awaiting:
		var ask: int = data["chanda_ask"]
		var blurb := _make_title_label(
			tr(&"events.chanda_ask") % [festival.display_name, ask],
			14, text_color
		)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
		box.add_child(blurb)

		var buttons := HBoxContainer.new()
		buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buttons.add_theme_constant_override("separation", 8)

		var can_afford: bool = data["can_afford_chanda"]
		var give_button := UiTheme.make_chunky_button(
			(tr(&"events.chanda_give") % ask) if can_afford else (tr(&"events.chanda_cant_afford") % ask),
			FIELD_GREEN_LIGHT, Color.WHITE, can_afford
		)
		give_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		give_button.pressed.connect(_on_give_chanda_pressed)
		buttons.add_child(give_button)

		var decline_button := UiTheme.make_chunky_button(tr(&"events.chanda_decline"), WOOD_BROWN_LIGHT, Color.WHITE, true)
		decline_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		decline_button.pressed.connect(_on_decline_chanda_pressed)
		buttons.add_child(decline_button)

		box.add_child(buttons)
	elif blessing_active:
		var remaining := format_duration(data["chanda_blessing_remaining_ms"])
		box.add_child(_make_title_label(
			tr(&"events.chanda_blessing_active") % [
				roundi((GameData.CHANDA_BLESSING_MULTIPLIER - 1.0) * 100.0), remaining
			],
			14, text_color
		))
	else:
		var remaining := format_duration(data["chanda_remaining_ms"])
		box.add_child(_make_title_label(tr(&"events.chanda_next_visitor") % remaining, 14, text_color))

	card.add_child(box)
	return card


## Daily Tasks card (design/gdd/gems-daily-tasks.md) -- 4th card, independent
## of Monsoon/Festival/Chanda above. Gems auto-award on task completion (no
## claim button, matching the Festival Pass's own auto-award-on-threshold
## behavior), so this card is purely a progress readout plus the one Reroll
## action.
func _build_daily_tasks_card(data: Dictionary) -> PanelContainer:
	var card := _make_panel(WOOD_BROWN_LIGHT, 14)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)

	box.add_child(_make_title_label(tr(&"events.daily_tasks_title") % data["gems"], 17))

	var rows: Array = data["daily_tasks"]
	for row: Dictionary in rows:
		box.add_child(_build_daily_task_row(row))

	if data["daily_bonus_claimed"]:
		box.add_child(_make_title_label(tr(&"events.daily_bonus_claimed"), 14, RIPE_GOLD))

	box.add_child(_build_reroll_button(data["can_reroll"], data["gems"]))

	card.add_child(box)
	return card


func _build_daily_task_row(row: Dictionary) -> HBoxContainer:
	var task_def: DailyTaskDef = row["def"]
	var progress: int = row["progress"]
	var claimed: bool = row["claimed"]

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)

	var left := _make_title_label(
		"%s %s %s" % ["✅" if claimed else "▫️", task_def.emoji, task_def.display_name], 14
	)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left)

	hbox.add_child(_make_title_label("%d/%d" % [progress, task_def.target], 14))

	return hbox


## §2.4 disabled-button state (same established pattern as
## _build_premium_pass_button()): gated on both "not yet blocked by
## progress" (data["can_reroll"] already folds in the completion check) and
## affordability, with the label itself explaining which.
func _build_reroll_button(can_reroll: bool, gems: int) -> Button:
	var can_afford := gems >= GameData.DAILY_TASK_REROLL_COST
	var label_text: String
	if not can_afford:
		label_text = tr(&"events.reroll_needs_gems") % GameData.DAILY_TASK_REROLL_COST
	elif not can_reroll:
		label_text = tr(&"events.reroll_unavailable")
	else:
		label_text = tr(&"events.reroll_button") % GameData.DAILY_TASK_REROLL_COST
	var button := UiTheme.make_chunky_button(label_text, SAFFRON_DARK, Color.WHITE, can_reroll)
	if can_reroll:
		button.pressed.connect(_on_reroll_daily_tasks_pressed)
	return button


func _build_tier_row(
	tier_number: int, threshold: int, free_reward: int, premium_reward: int, reached: bool, has_premium: bool
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)

	var left := _make_title_label(
		tr(&"events.tier_row") % ["✅" if reached else "▫️", tier_number, threshold], 14
	)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var reward_text := (
		(tr(&"events.tier_reward_with_premium") % [free_reward, premium_reward]) if has_premium
		else (tr(&"events.tier_reward_locked") % [free_reward, premium_reward])
	)
	row.add_child(_make_title_label(reward_text, 14))

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


## §2.4 disabled-button state: previously only gated on `festival_active`
## (via a hand-rolled disabled StyleBoxFlat) and never checked affordability
## at all -- tapping while festival-active-but-unaffordable silently no-oped
## against GameEconomy.buy_premium_pass()'s own coin guard with no visual
## cue. Now routed through UiTheme.make_chunky_button()'s real disabled
## state (same mechanism every other ported sheet's purchase button uses)
## and gated on both conditions.
func _build_premium_pass_button(festival_active: bool) -> Button:
	var can_afford := _economy.state.coins >= GameData.FESTIVAL_PREMIUM_PASS_COST
	var enabled := festival_active and can_afford
	var label_text := (
		(tr(&"events.premium_pass_buy") % GameData.FESTIVAL_PREMIUM_PASS_COST) if festival_active
		else tr(&"events.premium_pass_unavailable")
	)
	var button := UiTheme.make_chunky_button(label_text, SAFFRON_DARK, Color.WHITE, enabled)
	if enabled:
		button.pressed.connect(_on_premium_pass_pressed)
	return button


# Track A consolidation: every helper below now delegates to ui_theme.gd
# (see that file's class doc) -- call sites throughout this file unchanged.
func _make_panel(bg_color: Color, corner_radius: int = 16, border_color: Color = GOLD_LIGHT) -> PanelContainer:
	return UiTheme.make_panel(bg_color)


func _make_title_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	return UiTheme.make_title_label(text, font_size, color)


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	return UiTheme.make_label_settings(font_size, color)
