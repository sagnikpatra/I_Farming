## Definition of a single weather event type with its properties and mechanics.
## Part of the Real-Time Weather Events system (design/gdd/weather-events.md).
class_name WeatherEventDef
extends RefCounted

var event_type: int
var probability_per_day: float
var duration_hours: int
var debuff_reduction_percent: int
var immunity_if_polyhouse: bool


func _init(
	p_event_type: int,
	p_probability_per_day: float,
	p_duration_hours: int,
	p_debuff_reduction_percent: int,
	p_immunity_if_polyhouse: bool = true
) -> void:
	event_type = p_event_type
	probability_per_day = p_probability_per_day
	duration_hours = p_duration_hours
	debuff_reduction_percent = p_debuff_reduction_percent
	immunity_if_polyhouse = p_immunity_if_polyhouse


func _to_string() -> String:
	return "WeatherEventDef(type=%s, prob=%.1f%%, duration=%dh, debuff=%d%%)" % [
		WeatherEventType.kind_name(event_type),
		probability_per_day * 100.0,
		duration_hours,
		debuff_reduction_percent
	]
