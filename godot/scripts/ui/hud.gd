## Always-visible farm HUD -- port of the always-on chrome in FarmScreen.kt
## (title, coin/level readouts, inventory row + Sell All, LiveOps banner,
## Shop button). The 9 management/picker sheet CONTENTS (Farmhouse/Mandi/
## Polyhouse/Agroforestry/Niche/Events tabs, seed/decoration/agro-plant
## pickers) are the NEXT EPIC-M4 slice, once this shell + BottomSheet +
## input-routing are proven -- see docs/architecture/godot-migration-roadmap.md.
## Only the Shop button opens BottomSheet this round, with a placeholder
## "coming soon" body (not real shop content) -- deliberately wired, not a
## true no-op stub, specifically to get one real on-device open/close/
## backdrop-dismiss exercise of that brand-new primitive, since it's the
## highest-risk new piece this round. "Sell All" is the second,
## functionally-real button used to verify board-tap-through-HUD does NOT
## happen (see board_interactor.gd's own header comment, which flags this as
## unverified prior to EPIC-M4).
##
## ARCHITECTURE: hud.tscn is a thin shell (CanvasLayer + RefreshTimer + a
## BottomSheet instance) -- every visible widget (labels, badges, chips,
## buttons) is built procedurally here in _ready()/the _build_*() helpers
## below, the same "generated visual content lives in code" convention
## village_board.gd already established for its meshes/materials (e.g.
## _build_ground(), _apply_toon_shading()). A hand-authored deep Control
## tree in .tscn was considered (and IS what BottomSheet's much smaller,
## 3-node backdrop/panel/slot shell uses -- see bottom_sheet.gd's header
## comment for why that split makes sense at that size), but for a dozen-
## plus interdependent Labels/PanelContainers/StyleBoxes with values pulled
## from a Kotlin source rather than tuned live in the Godot editor, building
## them in one auditable script (with named _build_*() helpers, similar
## spirit to GameData's catalogue tables) is both lower-risk to get right
## without an editor round-trip and easier to keep in sync with
## FarmScreen.kt's layout than a large hand-typed .tscn.
##
## No gradient-bevel shader matching ChunkyComponents.kt pixel-for-pixel --
## flat StyleBoxFlat styling (corner_radius/border/shadow) is the explicit
## bar for this round; the beveled gloss/shadow overlay look is deferred
## polish, the same way EPIC-M1 staged toon-shading after an MVP layout pass.
## Likewise, layout uses fixed pixel margins (not a true dp/density-aware
## conversion of FarmScreen.kt's `.dp` values) -- this project has no
## density-aware UI scaling yet and is "not yet tested on physical hardware
## or other screen sizes/densities" per technical-preferences.md, so a
## precise dp conversion would be false precision.
##
## mouse_filter is set EXPLICITLY on every node built here, never left at
## Godot's default, specifically to make the input-stealing bug class
## board_interactor.gd's header comment flags impossible to reintroduce by
## accident: every purely decorative/layout node (containers, Labels) is
## MOUSE_FILTER_IGNORE; only the three real buttons (Sell All, Shop, the
## LiveOps banner -- now a Button as of EPIC-M4 slice 3's Events sheet) and
## BottomSheet's own backdrop consume input.
##
## Refresh is a plain 0.3s Timer polling GameEconomy's read-only state --
## no GameEconomy-side signals/observers this round (per EPIC-M4 scope), and
## village_board.gd's own accessor (get_economy()) stays read-only from the
## HUD's point of view: VillageBoard remains the sole owner of the
## GameEconomy instance and its save lifecycle. Sell All calls
## GameEconomy.sell_all() directly and then persists via SaveSystem exactly
## the way village_board.gd's try_commit_zone_move() already does (dirty
## flag check, save, clear flag) -- the same established save-triggering
## convention, not a new one invented here.
##
## KNOWN GAP, explicitly not addressed by this file: nothing in the live
## scene graph calls GameEconomy.resolve_growth_completions() on a timer, so
## Growing plots never lazily resolve to READY_TO_HARVEST during a live play
## session -- only tests call it today. HUD's refresh Timer was deliberately
## NOT used to paper over this (that would conflate "HUD refresh" with
## "economy simulation tick" ownership); flagged for a future task to
## resolve deliberately.
class_name Hud
extends CanvasLayer

const EventsTabScene := preload("res://scenes/ui/events_tab.tscn")
const DecorationPickerScene := preload("res://scenes/ui/decoration_picker.tscn")
const OpenFieldTabScene := preload("res://scenes/ui/open_field_tab.tscn")
const AccessibilitySheetScene := preload("res://scenes/ui/accessibility_sheet.tscn")

const HUD_MARGIN: int = 16
## Fixed status-bar clearance approximation -- real safe-area-aware insets
## (DisplayServer.get_display_safe_area()) are deferred; land an approximate
## MVP first, refine once verified on-device (same precedent as EPIC-M1's
## toon-shading pass).
const TOP_SAFE_AREA_OFFSET: int = 40
## Matches FarmScreen.kt's `bottom = 100.dp` exactly in raw magnitude (not a
## true dp-to-px conversion -- see class doc) -- clears space above
## Android's gesture/nav bar for both bottom-anchored HUD groups.
const BOTTOM_MARGIN: int = 100

# Palette -- ported verbatim from app/src/main/java/com/zonkrik/ifarming/
# ui/theme/Color.kt so the Godot HUD reads as the same warm Indian-farm
# palette as the Kotlin original, not a re-invented one.
const SOIL_BROWN_DARK := Color("#3E2412")
const WOOD_BROWN_LIGHT := Color("#8A5A34")
const GOLD_LIGHT := Color("#FFE082")
const RIPE_GOLD := Color("#FFC107")
const SAFFRON_DARK := Color("#C56A00")
const LEVEL_BADGE_BLUE := Color("#1976D2")
## Ported verbatim, same value polyhouse_tab.gd's own copy already uses.
const FIELD_GREEN := Color("#4CAF50")
## Matches OutlinedTitle's `Color.Black.copy(alpha = 0.7f)` exactly -- see
## FarmScreen.kt. OutlinedTitle is actually implemented as a text drop
## shadow, not a true stroke outline, despite the name -- mirrored here via
## LabelSettings.shadow_* rather than outline_*.
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)

@onready var _village_board: VillageBoard = get_node("../VillageBoard") as VillageBoard
@onready var _bottom_sheet: BottomSheet = $BottomSheet
@onready var _refresh_timer: Timer = $RefreshTimer

var _top_left_title: VBoxContainer
var _top_right_resources: HBoxContainer
var _bottom_left_panel: VBoxContainer
var _bottom_right_shop: VBoxContainer
var _bottom_center_nav: HBoxContainer

var _coin_label: Label
var _level_label: Label
var _inventory_row: HBoxContainer
var _liveops_banner: Button
var _sell_all_button: Button
var _shop_button: Button
var _open_field_workers_button: Button
var _accessibility_button: Button


func _ready() -> void:
	# EPIC-M4 slice 2: lets board_interactor.gd find this HUD instance (to
	# reuse its BottomSheet for the seed picker) via
	# get_tree().get_first_node_in_group("hud") instead of a long relative
	# get_node() path coupled to main.tscn's exact tree shape.
	add_to_group("hud")
	_build_top_left_title()
	_build_top_right_resources()
	_build_bottom_left_panel()
	_build_bottom_right_shop()
	_build_bottom_center_nav()
	_reposition_all()

	get_viewport().size_changed.connect(_reposition_all)
	_refresh_timer.timeout.connect(_refresh)
	_refresh_timer.start()

	# Audio pass: single hook point covering EVERY sheet everywhere (SeedPicker,
	# DecorationPicker, AgroPlantPicker, all *_tab.gd sheets, AccessibilitySheet,
	# GrowingInfoCard, DecorationInfoCard) -- they all funnel through this one
	# shared BottomSheet's open()/close(), so this is "hook there once, not per
	# call site" (see bottom_sheet.gd's `opened`/`closed` signals).
	_bottom_sheet.opened.connect(_on_bottom_sheet_opened)
	_bottom_sheet.closed.connect(_on_bottom_sheet_closed)

	_refresh()


## Public so a future sheet-opening script (management tabs, pickers) can
## reuse this exact BottomSheet instance rather than instantiating a second,
## overlapping one -- see bottom_sheet.gd's header comment on reuse intent.
func get_bottom_sheet() -> BottomSheet:
	return _bottom_sheet


# ---------------------------------------------------------------------------
# Live refresh
# ---------------------------------------------------------------------------

func _refresh() -> void:
	if _village_board == null:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	var now := int(Time.get_unix_time_from_system() * 1000.0)

	_coin_label.text = "%d" % economy.state.coins
	_level_label.text = "%d" % economy.state.farmhouse_level
	_refresh_inventory(economy.state.inventory)
	_refresh_liveops_banner(economy, now)
	_reposition_all()


func _refresh_inventory(inventory: Dictionary) -> void:
	for child in _inventory_row.get_children():
		child.queue_free()
	for entry in build_inventory_display(inventory):
		_inventory_row.add_child(_make_inventory_chip(entry["emoji"], entry["count"]))


func _refresh_liveops_banner(economy: GameEconomy, now: int) -> void:
	var monsoon_active := economy.is_monsoon_active(now)
	var festival_active := economy.is_festival_active(now)
	if not monsoon_active and not festival_active:
		_liveops_banner.visible = false
		return
	var festival := economy.current_festival(now)
	_liveops_banner.text = format_liveops_label(monsoon_active, festival_active, festival)
	_liveops_banner.visible = true


## Pure -- no scene-tree dependency, directly unit-testable. Mirrors
## InventoryHUD's inventory-entries iteration in FarmScreen.kt: one entry per
## crop type currently in stock (total > 0), in Dictionary iteration
## (insertion) order. Not underscore-prefixed (mirrors
## GameEconomy.was_sandalwood_stolen()'s naming rationale) specifically so
## tests/unit/test_hud.gd can exercise it directly.
static func build_inventory_display(inventory: Dictionary) -> Array:
	var entries: Array = []
	for crop: int in inventory.keys():
		var stock: CropStock = inventory[crop]
		if stock == null or stock.total <= 0:
			continue
		entries.append({"emoji": GameData.crop_def(crop).emoji, "count": stock.total})
	return entries


## Pure -- mirrors LiveOpsBanner's `label` when-expression in FarmScreen.kt
## exactly (3 branches; empty string when neither is active, which callers
## must check via monsoon_active/festival_active before displaying -- see
## _refresh_liveops_banner()). Not underscore-prefixed for the same testing
## reason as build_inventory_display() above.
static func format_liveops_label(monsoon_active: bool, festival_active: bool, festival: FestivalDef) -> String:
	if monsoon_active and festival_active:
		return "🌧️ Monsoon · %s %s" % [festival.emoji, festival.display_name]
	if monsoon_active:
		return "🌧️ Monsoon Season"
	if festival_active:
		return "%s %s" % [festival.emoji, festival.display_name]
	return ""


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_sell_all_pressed() -> void:
	if _village_board == null:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	_play_ui_audio(&"ui_button_tap")
	# "each Sell-All iteration" per design/audio/audio-core-gameplay-loop.md's
	# event list -- one crop TYPE currently held = one iteration of
	# GameEconomy.sell_all()'s internal per-crop loop, counted before the
	# call clears the inventory (still respects economy_sell's own
	# max_polyphony, so a huge inventory doesn't stack indefinitely).
	var crop_type_count := economy.state.inventory.size()
	var tier_before: int = economy.state.event_claimed_tier
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	economy.sell_all(now)
	if economy.dirty:
		for _i in range(crop_type_count):
			_play_ui_audio(&"economy_sell")
		var tier_after: int = economy.state.event_claimed_tier
		for _i in range(tier_after - tier_before):
			_play_ui_audio(&"liveops_festival_tier_reward")
	_persist_if_dirty(economy)
	_refresh()


func _persist_if_dirty(economy: GameEconomy) -> void:
	if economy.dirty:
		SaveSystem.save_state(economy.state)
		economy.dirty = false


## Opens the LiveOps Events sheet -- matches the real shipped app exactly
## (FarmScreen.kt's `LiveOpsBanner(onTapped = { activeSheet = IsoSheet.Events })`).
## Only reachable while the banner is visible (Monsoon and/or a festival
## active), same as the real app -- there is no other way to open this sheet.
func _on_liveops_banner_pressed() -> void:
	if _village_board == null:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	_play_ui_audio(&"ui_button_tap")
	var tab: EventsTab = EventsTabScene.instantiate()
	tab.configure(economy, _village_board)
	_bottom_sheet.open(tab)


## EPIC-M7: the only reachable path to Open Field's worker-assignment row
## -- see _build_bottom_left_panel()'s own comment on why Open Field has
## no zone-tap route to _maybe_open_zone_sheet().
func _on_open_field_workers_pressed() -> void:
	if _village_board == null:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	_play_ui_audio(&"ui_button_tap")
	var tab: OpenFieldTab = OpenFieldTabScene.instantiate()
	tab.configure(economy, _village_board)
	_bottom_sheet.open(tab)


## Opens the real DecorationPicker (EPIC-M4 slice 3) -- was a placeholder
## "coming soon" stub in EPIC-M4 slice 1, per that slice's own class doc.
## Opens the AccessibilitySheet -- see the accessibility_button's own comment
## at its construction site for what BLOCKING finding this closes.
func _on_accessibility_pressed() -> void:
	if _village_board == null:
		return
	var settings := _village_board.get_accessibility_settings()
	if settings == null:
		return
	_play_ui_audio(&"ui_button_tap")
	var sheet: AccessibilitySheet = AccessibilitySheetScene.instantiate()
	sheet.configure(settings, _village_board)
	_bottom_sheet.open(sheet)


func _on_shop_pressed() -> void:
	if _village_board == null:
		return
	var economy := _village_board.get_economy()
	if economy == null:
		return
	_play_ui_audio(&"ui_button_tap")
	var picker: DecorationPicker = DecorationPickerScene.instantiate()
	picker.configure(economy, _village_board.get_board_interactor(), _bottom_sheet)
	_bottom_sheet.open(picker)


# ---------------------------------------------------------------------------
# Audio pass -- see audio_manager.gd's class doc.
# ---------------------------------------------------------------------------

func _on_bottom_sheet_opened() -> void:
	_play_ui_audio(&"ui_sheet_open")


func _on_bottom_sheet_closed() -> void:
	_play_ui_audio(&"ui_sheet_close")


func _play_ui_audio(event_key: StringName) -> void:
	if _village_board == null:
		return
	var audio := _village_board.get_audio_manager()
	if audio != null:
		audio.play_sfx(event_key)


# ---------------------------------------------------------------------------
# Layout -- corner positioning (see class doc: manual size+position, not
# anchor presets, to stay within APIs this task's author was fully confident
# about rather than trusting hand-typed anchor/offset scene-format numbers).
# ---------------------------------------------------------------------------

func _reposition_all() -> void:
	_fit_and_place(_top_left_title, false, false)
	_fit_and_place(_top_right_resources, true, false)
	_fit_and_place(_bottom_left_panel, false, true)
	_fit_and_place(_bottom_right_shop, true, true)
	_fit_and_place_bottom_center(_bottom_center_nav)


func _fit_and_place(control: Control, right_edge: bool, bottom_edge: bool) -> void:
	var content_size := control.get_combined_minimum_size()
	control.size = content_size
	var viewport_size := get_viewport().get_visible_rect().size
	var x: float = (viewport_size.x - HUD_MARGIN - content_size.x) if right_edge else float(HUD_MARGIN)
	var y: float
	if bottom_edge:
		y = viewport_size.y - BOTTOM_MARGIN - content_size.y
	else:
		y = HUD_MARGIN + TOP_SAFE_AREA_OFFSET
	control.position = Vector2(x, y)


## Horizontal-center variant of _fit_and_place(), for the Quick Nav Bar only
## (EPIC-M5 parity pass) -- every other HUD group anchors to a corner, this
## one is the sole bottom-center exception, matching GdxQuickNavBar.kt's own
## `Modifier.align(Alignment.BottomCenter)` placement. Sits flush with the
## viewport's bottom edge, same HUD_MARGIN clearance the corner groups use
## (not BOTTOM_MARGIN's larger gesture-bar allowance -- the nav bar is a
## single row of small chips, not a stacked column, so it doesn't need as
## much breathing room above the edge).
func _fit_and_place_bottom_center(control: Control) -> void:
	var content_size := control.get_combined_minimum_size()
	control.size = content_size
	var viewport_size := get_viewport().get_visible_rect().size
	var x := (viewport_size.x - content_size.x) / 2.0
	var y := viewport_size.y - HUD_MARGIN - content_size.y
	control.position = Vector2(x, y)


# ---------------------------------------------------------------------------
# Widget construction
# ---------------------------------------------------------------------------

func _build_top_left_title() -> void:
	_top_left_title = VBoxContainer.new()
	_top_left_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_left_title.add_theme_constant_override("separation", 2)
	add_child(_top_left_title)

	_top_left_title.add_child(_make_title_label("Kisan Khet", 24))
	_top_left_title.add_child(_make_title_label("किसान खेत", 14))


func _build_top_right_resources() -> void:
	_top_right_resources = HBoxContainer.new()
	_top_right_resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_right_resources.add_theme_constant_override("separation", 12)
	add_child(_top_right_resources)

	var coin_panel := _make_panel(SOIL_BROWN_DARK, 24)
	var coin_row := HBoxContainer.new()
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_row.add_theme_constant_override("separation", 6)
	var coin_emoji := Label.new()
	coin_emoji.text = "🪙"
	coin_emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_emoji.label_settings = _make_label_settings(18, Color.WHITE)
	_coin_label = _make_title_label("0", 16)
	coin_row.add_child(coin_emoji)
	coin_row.add_child(_coin_label)
	coin_panel.add_child(coin_row)

	var level_panel := _make_circular_panel(LEVEL_BADGE_BLUE, 44, Color.WHITE)
	_level_label = _make_title_label("0", 16)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_panel.add_child(_level_label)

	# A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §0):
	# the one entry point into AccessibilitySheet -- closes the "no
	# accessibility settings screen exists at all" BLOCKING finding.
	_accessibility_button = _make_accessibility_button()
	_accessibility_button.pressed.connect(_on_accessibility_pressed)

	_top_right_resources.add_child(coin_panel)
	_top_right_resources.add_child(level_panel)
	_top_right_resources.add_child(_accessibility_button)


func _build_bottom_left_panel() -> void:
	_bottom_left_panel = VBoxContainer.new()
	_bottom_left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_left_panel.add_theme_constant_override("separation", 10)
	add_child(_bottom_left_panel)

	# Ported as a Button (was a plain PanelContainer before EPIC-M4 slice 3's
	# Events sheet existed to tap into) -- same RIPE_GOLD/SAFFRON_DARK look,
	# now genuinely tappable. font_color stays WHITE, matching
	# _make_chunky_button()'s default (same contrast level the original
	# PanelContainer+white-LabelSettings version already shipped with).
	_liveops_banner = _make_chunky_button("", RIPE_GOLD, SOIL_BROWN_DARK)
	_liveops_banner.visible = false
	_liveops_banner.pressed.connect(_on_liveops_banner_pressed)
	_bottom_left_panel.add_child(_liveops_banner)

	_inventory_row = HBoxContainer.new()
	_inventory_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_row.add_theme_constant_override("separation", 8)
	_bottom_left_panel.add_child(_inventory_row)

	_sell_all_button = _make_chunky_button("Sell All", SAFFRON_DARK)
	_sell_all_button.pressed.connect(_on_sell_all_pressed)
	_bottom_left_panel.add_child(_sell_all_button)

	# EPIC-M7: Open Field is the one worker-eligible zone with no zone-level
	# tap target of its own (has_building=false -- see village_board.gd's
	# _build_zone(), only plots are pickable there), so it can never reach
	# _maybe_open_zone_sheet(). This button is the only way to reach its
	# worker-assignment row (worker_assignment_row.gd) -- Polyhouse and
	# Aquaculture/Vertical Farm already embed the same row inside their own
	# real zone-tap sheets (polyhouse_tab.gd/niche_farming_tab.gd) and don't
	# need this.
	_open_field_workers_button = _make_chunky_button("🌾 Field Worker", FIELD_GREEN)
	_open_field_workers_button.pressed.connect(_on_open_field_workers_pressed)
	_bottom_left_panel.add_child(_open_field_workers_button)


func _build_bottom_right_shop() -> void:
	_bottom_right_shop = VBoxContainer.new()
	_bottom_right_shop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_right_shop.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_bottom_right_shop)

	_shop_button = Button.new()
	_shop_button.text = "🎨"
	_shop_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_button.focus_mode = Control.FOCUS_NONE
	_shop_button.custom_minimum_size = Vector2(64, 64)
	var style := StyleBoxFlat.new()
	style.bg_color = WOOD_BROWN_LIGHT
	style.set_corner_radius_all(32)
	style.set_border_width_all(2)
	style.border_color = GOLD_LIGHT
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.35)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		_shop_button.add_theme_stylebox_override(state_name, style)
	_shop_button.add_theme_font_size_override("font_size", 28)
	_shop_button.pressed.connect(_on_shop_pressed)
	_bottom_right_shop.add_child(_shop_button)

	var shop_label := _make_title_label("Shop", 12)
	shop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom_right_shop.add_child(shop_label)


## Quick Nav Bar (EPIC-M5 parity pass) -- port of GdxQuickNavBar.kt, a row of
## 7 chips that instantly recenter the camera on a zone. One deliberate
## improvement over the Kotlin original, not a divergence to flag as a bug:
## the original only tracks the Farmhouse's *live* (possibly dragged)
## position, using fixed default anchors for the other 6 zones even if the
## player has since dragged one of those too (its own header comment admits
## this: "unlike the other six zones... Home always needs to track wherever
## the Farmhouse actually is"). This port instead reads EVERY target's
## position live via VillageBoard.get_zone_center_world() -- already the
## single source of truth for a zone's current position regardless of
## whether it's been dragged -- so all 7 chips stay accurate, not just Home.
func _build_bottom_center_nav() -> void:
	_bottom_center_nav = HBoxContainer.new()
	_bottom_center_nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_center_nav.add_theme_constant_override("separation", 8)
	add_child(_bottom_center_nav)

	var targets := [
		["🏠", VillageSnapshotMapper.ZONE_ID_FARMHOUSE],
		["🌾", VillageSnapshotMapper.ZONE_ID_OPEN_FIELD],
		["🏚️", VillageSnapshotMapper.ZONE_ID_POLYHOUSE],
		["🌳", VillageSnapshotMapper.ZONE_ID_AGROFORESTRY],
		["🪷", VillageSnapshotMapper.ZONE_ID_AQUACULTURE],
		["🌸", VillageSnapshotMapper.ZONE_ID_VERTICAL_FARM],
		["🏛️", VillageSnapshotMapper.ZONE_ID_MANDI],
	]
	for target in targets:
		_bottom_center_nav.add_child(_build_nav_chip(target[0], target[1]))


func _build_nav_chip(emoji: String, zone_id: String) -> Button:
	var chip := Button.new()
	chip.text = emoji
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = WOOD_BROWN_LIGHT
	style.set_corner_radius_all(50)
	style.set_border_width_all(2)
	style.border_color = SAFFRON_DARK
	style.shadow_size = 3
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	for state_name in ["normal", "hover", "pressed", "focus"]:
		chip.add_theme_stylebox_override(state_name, style)
	chip.add_theme_font_size_override("font_size", 18)
	chip.pressed.connect(_on_nav_chip_pressed.bind(zone_id))
	return chip


func _on_nav_chip_pressed(zone_id: String) -> void:
	if _village_board == null:
		return
	_play_ui_audio(&"ui_button_tap")
	var world_pos := _village_board.get_zone_center_world(zone_id)
	_village_board.get_camera_rig().center_on(Vector2(world_pos.x, world_pos.z))


func _make_inventory_chip(emoji: String, count: int) -> PanelContainer:
	var chip := _make_panel(WOOD_BROWN_LIGHT, 10)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	var emoji_label := Label.new()
	emoji_label.text = emoji
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.label_settings = _make_label_settings(16, Color.WHITE)
	var count_label := _make_title_label(str(count), 14)
	row.add_child(emoji_label)
	row.add_child(count_label)
	chip.add_child(row)
	return chip


## A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §1):
## font_color now defaults to WHITE (correct for the SAFFRON_DARK/FIELD_GREEN
## backgrounds this is normally called with -- that pairing is the audit's
## separate, still-open HIGH finding, not this BLOCKING one) but callers on
## the RIPE_GOLD background (e.g. the LiveOps banner below) must pass
## SOIL_BROWN_DARK explicitly -- white-on-RIPE_GOLD measured ~1.63:1
## contrast, the same unreadable pairing already fixed in polyhouse_tab.gd/
## agroforestry_tab.gd/niche_farming_tab.gd's chip builders.
func _make_chunky_button(label_text: String, color: Color, font_color: Color = Color.WHITE) -> Button:
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
		button.add_theme_color_override(color_slot, font_color)
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
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel


## Approximate circle: a fixed square custom_minimum_size + corner_radius =
## half that size. Not pixel-perfect circular clipping (StyleBoxFlat corner
## rounding on a PanelContainer, not a true circle mask) -- adequate for this
## round's "flat StyleBoxFlat styling is the bar" scope (see class doc).
func _make_circular_panel(bg_color: Color, diameter: int, border_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(diameter, diameter)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(diameter / 2)
	style.set_border_width_all(2)
	style.border_color = border_color
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)
	return panel


## A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §0/§2):
## a real tappable Button (unlike _make_circular_panel()'s decorative
## PanelContainer), sized 44x44 -- comfortably above the ADVISORY touch-
## target note the same audit raised about the Quick Nav Bar's chips (§2),
## which this new button deliberately does not repeat.
func _make_accessibility_button() -> Button:
	var button := Button.new()
	button.text = "⚙"
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(44, 44)
	var style := StyleBoxFlat.new()
	style.bg_color = WOOD_BROWN_LIGHT
	style.set_corner_radius_all(22)
	style.set_border_width_all(2)
	style.border_color = GOLD_LIGHT
	style.shadow_size = 3
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.set_content_margin_all(0)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state_name, style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 20)
	return button


## OutlinedTitle equivalent -- see TEXT_SHADOW_COLOR's doc comment on why
## this is a drop shadow, not a stroke outline. True bold weight would need a
## bundled font resource (this project's fonts are default-OS-fallback only,
## per EPIC-M0's emoji-rendering decision -- see the task's explicit
## out-of-scope note on font bundling); size + shadow carry the emphasis
## instead for this round.
func _make_title_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.label_settings = _make_label_settings(font_size, color)
	return label


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = _scaled_font_size(font_size)
	settings.font_color = color
	settings.shadow_size = 4
	settings.shadow_color = TEXT_SHADOW_COLOR
	settings.shadow_offset = Vector2(2, 3)
	return settings


## A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §0/§5):
## applies AccessibilitySettings.text_scale to every label built via
## _make_label_settings() -- HUD is the one always-visible screen this
## mechanism is wired into today, demonstrating it actually works end to
## end. The per-sheet floors §5 flagged (12-14px body text across the
## *_tab.gd management sheets, and this file's own _make_chunky_button()
## font sizes) are a separate, still-open HIGH finding -- not part of this
## round's BLOCKING-only fix.
func _scaled_font_size(base_size: int) -> int:
	var scale: float = 1.0
	if _village_board != null:
		var settings := _village_board.get_accessibility_settings()
		if settings != null:
			scale = settings.text_scale
	return roundi(float(base_size) * scale)
