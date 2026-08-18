## Static per-crop data, analogous to what CropType.kt's enum class carried
## directly on each enum case. Looked up via GameData.crop_def(crop_ordinal) --
## never constructed by gameplay code, only by GameData's catalogue table.
class_name CropDef
extends RefCounted

var display_name: String
var emoji: String
var seed_cost: int
var grow_seconds: int
var base_sell_price: int
## % chance an open-field crop gets hit by weather/pests once it finishes
## growing. Unused outside PlotKind.Kind.OPEN_FIELD.
var weather_risk_percent: int
var required_plot_kind: PlotKind.Kind


func _init(
	p_display_name: String,
	p_emoji: String,
	p_seed_cost: int,
	p_grow_seconds: int,
	p_base_sell_price: int,
	p_weather_risk_percent: int,
	p_required_plot_kind: PlotKind.Kind,
) -> void:
	display_name = p_display_name
	emoji = p_emoji
	seed_cost = p_seed_cost
	grow_seconds = p_grow_seconds
	base_sell_price = p_base_sell_price
	weather_risk_percent = p_weather_risk_percent
	required_plot_kind = p_required_plot_kind
