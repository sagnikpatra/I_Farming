## Real-world local-time-driven day/night lighting (design/gdd/real-time-
## day-night.md). Purely cosmetic -- touches only the board's existing
## WorldEnvironment/DirectionalLight3D properties, never gameplay math.
## Lives in the Presentation layer (village_board-specific), not
## game_economy.gd/Foundation, since this has no economy-state involvement
## at all.
##
## local_hour() mirrors GameEconomy.local_day_key()'s exact pure-function
## shape: explicit (now_ms, timezone_offset_minutes) inputs, no hidden
## system-clock read, so it's directly unit-testable with fixed inputs.
class_name TimeOfDay
extends RefCounted

enum Phase { DAWN, DAY, DUSK, NIGHT }


static func local_hour(now_ms: int, timezone_offset_minutes: int) -> int:
	var shifted_seconds: int = now_ms / 1000 + timezone_offset_minutes * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(shifted_seconds)
	return int(d.hour)


## design/gdd/real-time-day-night.md §4's boundary table: Dawn 5-6, Day
## 7-17, Dusk 18-19, Night 20-23 and 0-4.
static func phase_for_hour(hour: int) -> Phase:
	if hour >= 5 and hour <= 6:
		return Phase.DAWN
	if hour >= 7 and hour <= 17:
		return Phase.DAY
	if hour >= 18 and hour <= 19:
		return Phase.DUSK
	return Phase.NIGHT


## Day's values are copied verbatim from village_board.tscn's existing
## Environment/DirectionalLight3D resources (not re-derived), so a player
## who only ever opens the app during daytime hours sees zero visual
## regression -- see this GDD's §4 note.
static func preset_for_phase(phase: Phase) -> Dictionary:
	match phase:
		Phase.DAWN:
			return {
				"sky_color": Color(0.85, 0.65, 0.60),
				"ambient_color": Color(1.0, 0.78, 0.70),
				"ambient_energy": 0.35,
				"sun_color": Color(1.0, 0.75, 0.55),
				"sun_energy": 0.40,
			}
		Phase.DUSK:
			return {
				"sky_color": Color(0.75, 0.42, 0.35),
				"ambient_color": Color(1.0, 0.55, 0.38),
				"ambient_energy": 0.35,
				"sun_color": Color(1.0, 0.48, 0.28),
				"sun_energy": 0.40,
			}
		Phase.NIGHT:
			return {
				"sky_color": Color(0.07, 0.09, 0.20),
				"ambient_color": Color(0.35, 0.40, 0.62),
				"ambient_energy": 0.25,
				"sun_color": Color(0.55, 0.60, 0.80),
				"sun_energy": 0.20,
			}
		_:  # Phase.DAY
			return {
				"sky_color": Color(0.63, 0.77, 0.86),
				"ambient_color": Color(1.0, 0.95, 0.85),
				"ambient_energy": 0.45,
				"sun_color": Color(1.0, 0.93, 0.78),
				"sun_energy": 0.55,
			}
