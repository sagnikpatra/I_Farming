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

const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)


func configure(crop: int) -> void:
	for child in get_children():
		child.queue_free()

	var crop_def := GameData.crop_def(crop)

	var emoji_label := Label.new()
	emoji_label.text = crop_def.emoji
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.label_settings = _make_label_settings(40, Color.WHITE)
	add_child(emoji_label)

	var name_label := Label.new()
	name_label.text = crop_def.display_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.label_settings = _make_label_settings(18, Color.WHITE)
	add_child(name_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "sells ₹%d" % crop_def.base_sell_price
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.label_settings = _make_label_settings(14, Color(1.0, 1.0, 1.0, 0.9))
	add_child(subtitle_label)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.shadow_size = 4
	settings.shadow_color = TEXT_SHADOW_COLOR
	settings.shadow_offset = Vector2(2, 3)
	return settings
