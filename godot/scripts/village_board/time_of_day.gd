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

## design/gdd/real-time-day-night.md's Option B stretch goal (built
## 2026-08-22) -- India's 3 broad seasons, per the original scoping
## brief (`feature-scoping-2026-08-22.md` item 3).
enum Season { MONSOON, WINTER, SUMMER }


static func local_hour(now_ms: int, timezone_offset_minutes: int) -> int:
	var shifted_seconds: int = now_ms / 1000 + timezone_offset_minutes * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(shifted_seconds)
	return int(d.hour)


## Mirrors local_hour()'s exact pure-function shape -- explicit inputs,
## no hidden system-clock read, directly unit-testable.
static func local_month(now_ms: int, timezone_offset_minutes: int) -> int:
	var shifted_seconds: int = now_ms / 1000 + timezone_offset_minutes * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(shifted_seconds)
	return int(d.month)


## §4 Formulas: Monsoon Jun-Sep (6-9), Winter Oct-Feb (10-12, 1-2), Summer
## Mar-May (3-5) -- exactly the 3-season boundaries
## `feature-scoping-2026-08-22.md` item 3's Option B table specifies.
## Deliberately unrelated to this project's existing (unrelated) Monsoon
## Season liveops event, which is a fully abstracted wall-clock cycle
## with no tie to the real calendar -- same name, different system, per
## real-time-day-night.md's own Overview ("Monsoon Season keeps its own
## fully independent compressed cycle exactly as documented today").
static func season_for_month(month: int) -> Season:
	if month >= 6 and month <= 9:
		return Season.MONSOON
	if month >= 10 or month <= 2:
		return Season.WINTER
	return Season.SUMMER  # 3-5


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
			# Warmed 2026-08-27 (design/art/ui-visual-direction-2026-08.md
			# §3's "still open" golden-hour item) -- richer amber sky/sun,
			# +0.08 energy on both ambient and sun for a more premium glow.
			# DAY/NIGHT untouched (DAY is pinned to village_board.tscn's
			# baseline via test_day_preset_matches_the_scenes_existing_
			# defaults_exactly(); NIGHT is the already-verified-stable dark
			# end of the range) -- Dawn/Dusk are the actual "golden hour"
			# phases this ask is about, so tuned in isolation from those two.
			return {
				"sky_color": Color(0.90, 0.60, 0.46),
				"ambient_color": Color(1.0, 0.70, 0.52),
				"ambient_energy": 0.42,
				"sun_color": Color(1.0, 0.64, 0.36),
				"sun_energy": 0.48,
			}
		Phase.DUSK:
			# Same 2026-08-27 warming pass as Dawn above -- deeper
			# amber-gold sunset tone, +0.10/+0.03 energy for a stronger,
			# more "premium" glow at the day's other golden-hour phase.
			return {
				"sky_color": Color(0.80, 0.38, 0.28),
				"ambient_color": Color(1.0, 0.48, 0.28),
				"ambient_energy": 0.38,
				"sun_color": Color(1.0, 0.40, 0.16),
				"sun_energy": 0.50,
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


## design/gdd/real-time-day-night.md's Option B stretch goal. A small
## multiplicative tint applied on top of preset_for_phase()'s colors --
## component-wise Color multiplication, values close to 1.0 by design
## ("a loose ambient palette shift," not a full re-tint per the original
## scoping brief's own Option B description). Day/night phase remains the
## dominant visual signal; season is a secondary modifier layered on it.
static func season_tint(season: Season) -> Color:
	match season:
		Season.MONSOON:
			return Color(0.90, 0.95, 1.00)  # cool, slightly desaturated -- overcast
		Season.WINTER:
			return Color(0.95, 0.97, 1.00)  # cool, pale/hazy
		_:  # Season.SUMMER
			return Color(1.05, 1.00, 0.92)  # warm, golden


## Season-aware variant of preset_for_phase() above -- that function is
## left untouched (still returns the exact same phase-only preset it
## always did) so no existing caller's behavior changes; this is the one
## new call site village_board.gd switches to.
static func preset_for_phase_and_season(phase: Phase, season: Season) -> Dictionary:
	var preset := preset_for_phase(phase)
	var tint := season_tint(season)
	preset["sky_color"] = preset["sky_color"] * tint
	preset["ambient_color"] = preset["ambient_color"] * tint
	preset["sun_color"] = preset["sun_color"] * tint
	return preset
