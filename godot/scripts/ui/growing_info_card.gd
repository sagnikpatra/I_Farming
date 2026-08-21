## Read-only info card for a tapped GROWING plot -- ported from
## GdxVillageBoard.kt's `plot.state is PlotState.Growing` tap branch, which
## sets a `GdxSelection(emoji, title, subtitle = "sells ₹X")` overlay (no
## rotate/flip/remove actions, no live countdown -- that richer per-tile
## progress readout belongs to the older Compose `SandalwoodGrowingTile`/
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


func configure(crop: int) -> void:
	for child in get_children():
		child.queue_free()

	var crop_def := GameData.crop_def(crop)

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# Track A consolidation: delegates to ui_theme.gd (see that file's class
# doc) -- call sites unchanged.
func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	return UiTheme.make_label_settings(font_size, color)
