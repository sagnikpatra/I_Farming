## Info card for a tapped GROWING plot -- ported from GdxVillageBoard.kt's
## `plot.state is PlotState.Growing` tap branch, which sets a
## `GdxSelection(emoji, title, subtitle = "sells ₹X")` overlay (no rotate/
## flip/remove actions, no live countdown -- that richer per-tile progress
## readout belongs to the older Compose `SandalwoodGrowingTile`/
## `AgroPlotCard`, which the real shipped app superseded with board taps
## exactly like every other plot interaction ported so far).
##
## ARCHITECTURE DEVIATION, deliberate and flagged: the Kotlin original shows
## this as a small floating overlay anchored near the tapped tile's screen
## position, not a bottom sheet. This port reuses the existing shared
## BottomSheet instead -- introducing a second, screen-space-anchored
## overlay primitive for one read-only card is a bigger architecture
## decision than this slice warrants (every other tap-triggered surface in
## this project already routes through BottomSheet). Content and behavior
## (emoji/name/"sells ₹X", tap-elsewhere-to-dismiss) match the original;
## only the container chrome differs. Revisit if this reads as visually
## wrong once seen on-device.
##
## feature-scoping-2026-08-22.md item 2's capped grow-time skip (built
## 2026-08-22) adds this card's one action: a "⏩ Skip" button, shown only
## when GameEconomy.can_skip_grow_time() currently allows it -- same
## "the card stays read-only unless it has something to act on" shape
## DecorationInfoCard's Rotate/Flip/Remove row already established, not a
## new UI pattern.
class_name GrowingInfoCard
extends VBoxContainer

# Palette -- now sourced from ui_theme.gd (Track A consolidation, see that
# file's class doc); kept as local aliases so no call site below changed.
const TEXT_SHADOW_COLOR := UiTheme.TEXT_SHADOW_COLOR
# A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §1): this
# whole card is added straight to the BottomSheet's cream body with no
# _make_panel() wrapper, so Color.WHITE (safe only on colored panels) is
# unreadable here -- measured ~1.06:1 contrast.
const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK
const WOOD_BROWN_LIGHT := UiTheme.WOOD_BROWN_MID

var _plot_id: int = -1
var _crop: int = 0
var _economy: GameEconomy
var _village_board: VillageBoard
var _bottom_sheet: BottomSheet


## Must be called before this instance is added under a BottomSheet's
## content slot -- same precondition/ordering guarantee as every other
## ported picker/card's configure() method. `economy`/`village_board`/
## `bottom_sheet` are optional (default null) so every pre-existing call
## site that only ever passed `crop` keeps compiling unchanged; the Skip
## button simply doesn't appear without them.
func configure(plot_id: int, crop: int, economy: GameEconomy = null, village_board: VillageBoard = null, bottom_sheet: BottomSheet = null) -> void:
	_plot_id = plot_id
	_crop = crop
	_economy = economy
	_village_board = village_board
	_bottom_sheet = bottom_sheet
	if is_inside_tree():
		_populate()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_populate()


func _populate() -> void:
	for child in get_children():
		child.queue_free()

	var crop_def := GameData.crop_def(_crop)

	var emoji_label := Label.new()
	emoji_label.text = crop_def.emoji
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.label_settings = _make_label_settings(40, SOIL_BROWN_DARK)
	add_child(emoji_label)

	var name_label := Label.new()
	name_label.text = crop_def.display_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.label_settings = _make_label_settings(18, SOIL_BROWN_DARK)
	add_child(name_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "sells ₹%d" % crop_def.base_sell_price
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.label_settings = _make_label_settings(14, Color(0.243, 0.141, 0.071, 0.9))
	add_child(subtitle_label)

	if _economy != null and _village_board != null and _bottom_sheet != null and _plot_id >= 0:
		var now := int(Time.get_unix_time_from_system() * 1000.0)
		var can_skip := _economy.can_skip_grow_time(now)
		var button := UiTheme.make_chunky_button("⏩ Skip (%d gems)" % GameData.GROW_SKIP_COST_GEMS, WOOD_BROWN_LIGHT, Color.WHITE, can_skip)
		button.pressed.connect(_on_skip_pressed)
		add_child(button)


func _on_skip_pressed() -> void:
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	_economy.skip_grow_time(_plot_id, now)
	# Immediately resolve rather than waiting up to 3s for the next growth
	# tick to notice -- same "the action should read as instant" bar every
	# other ported button (harvest, plant, buy) already meets.
	_economy.resolve_growth_completions(now)
	_play_audio(&"progression_plot_ready_chime")
	_village_board.persist_and_rebuild_if_dirty()
	_bottom_sheet.close()


func _play_audio(event_key: StringName) -> void:
	var audio := _village_board.get_audio_manager()
	if audio != null:
		audio.play_sfx(event_key)


# Track A consolidation: delegates to ui_theme.gd (see that file's class
# doc) -- call sites unchanged.
func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	return UiTheme.make_label_settings(font_size, color)
