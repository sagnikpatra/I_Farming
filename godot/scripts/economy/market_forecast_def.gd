## Data class representing a single crop's market forecast for a specific date.
## Used by GameEconomy.refresh_market_forecast() to generate tomorrow's demand
## predictions, enabling strategic player planting decisions.
##
## Design: design/gdd/mandi-trading.md (E-NAM Market Forecasting section)
class_name MarketForecastDef
extends RefCounted


enum DemandLevel {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
}


@export var crop_kind: int  # CropType.Kind ordinal
@export var demand_level: int  # DemandLevel value
@export var price_multiplier: float  # Applied to base_sell_price (e.g., 1.4x for HIGH)
@export var forecast_date: int  # Local day key (year*10000 + month*100 + day)


func _init(crop: int = 0, level: int = DemandLevel.MEDIUM, multiplier: float = 1.0, date: int = 0) -> void:
	crop_kind = crop
	demand_level = level
	price_multiplier = multiplier
	forecast_date = date


static func demand_level_name(level: int) -> String:
	match level:
		DemandLevel.LOW:
			return "Low"
		DemandLevel.MEDIUM:
			return "Medium"
		DemandLevel.HIGH:
			return "High"
		_:
			return "Unknown"


static func demand_level_emoji(level: int) -> String:
	match level:
		DemandLevel.LOW:
			return "📉"  # Downward trend
		DemandLevel.MEDIUM:
			return "➡️"  # Steady
		DemandLevel.HIGH:
			return "📈"  # Upward trend
		_:
			return "❓"
