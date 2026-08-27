## Weather event types and their properties.
## Part of the Real-Time Weather Events system (design/gdd/weather-events.md).
class_name WeatherEventType
extends RefCounted

class Kind:
	const MONSOON: int = 0
	const HEATWAVE: int = 1
	const PEST_ATTACK: int = 2
	const DROUGHT: int = 3


static func kind_name(kind: int) -> String:
	match kind:
		Kind.MONSOON:
			return "Monsoon"
		Kind.HEATWAVE:
			return "Heatwave"
		Kind.PEST_ATTACK:
			return "Pest Attack"
		Kind.DROUGHT:
			return "Drought"
		_:
			return "Unknown"


static func kind_emoji(kind: int) -> String:
	match kind:
		Kind.MONSOON:
			return "🌊"
		Kind.HEATWAVE:
			return "🔥"
		Kind.PEST_ATTACK:
			return "🦗"
		Kind.DROUGHT:
			return "🌵"
		_:
			return "❓"
