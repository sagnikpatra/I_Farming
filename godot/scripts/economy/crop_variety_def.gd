## Per-variety data: display name, grow-time modifier, price modifier, weather risk.
## Looked up via GameData.crop_variety_def(crop_ordinal, variety_ordinal).
##
## Modifiers are multiplicative: a variety with grow_time_multiplier=0.85
## reduces the base crop's grow time by 15%. A price_multiplier=1.20 increases
## the base sell price by 20%.
class_name CropVarietyDef
extends RefCounted

var display_name: String
var emoji: String
## Multiplier on base crop grow time (0.8 = 20% faster, 1.2 = 20% slower).
var grow_time_multiplier: float
## Multiplier on base crop seed cost (for balanced progression).
var seed_cost_multiplier: float
## Multiplier on base crop sell price (premium variants sell for more).
var price_multiplier: float
## Weather risk multiplier (1.0 = standard risk, 0.8 = 20% lower risk).
## Only applies to OPEN_FIELD crops; managed tiers (polyhouse, etc.) ignore this.
var weather_risk_multiplier: float


func _init(
	p_display_name: String,
	p_emoji: String,
	p_grow_time_multiplier: float,
	p_seed_cost_multiplier: float,
	p_price_multiplier: float,
	p_weather_risk_multiplier: float,
) -> void:
	display_name = p_display_name
	emoji = p_emoji
	grow_time_multiplier = p_grow_time_multiplier
	seed_cost_multiplier = p_seed_cost_multiplier
	price_multiplier = p_price_multiplier
	weather_risk_multiplier = p_weather_risk_multiplier
