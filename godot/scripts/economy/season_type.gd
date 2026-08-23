## Seasonal calendar system tied to real-world date.
## Each season corresponds to a ~3-month window of the actual calendar year.
## Players can only plant crops during their designated seasons.
class_name SeasonType
extends RefCounted

enum Kind {
	SPRING,    # March 21 - June 20
	SUMMER,    # June 21 - September 22
	MONSOON,   # September 23 - December 21
	WINTER,    # December 22 - March 20
}


## Determines the season for a given epoch-ms timestamp, device-timezone-aware.
## Deliberately a pure function of `now` (matches this codebase's convention
## of every time-dependent formula taking `now` explicitly -- see
## GameEconomy's header comment and local_day_key()) rather than reading the
## wall clock internally, so offline catch-up and unit tests can resolve
## seasons for any timestamp, not just "right now" on the real device.
##
## Example:
##   August 23 (month=8, day=23) -> SUMMER
##   March 21 (month=3, day=21) -> SPRING (boundary, inclusive)
##   December 22 (month=12, day=22) -> WINTER (boundary, inclusive)
static func current_season(now: int = 0) -> int:
	if now == 0:
		now = Time.get_unix_time_from_system() * 1000

	var tz: Dictionary = Time.get_time_zone_from_system()
	var shifted_seconds: int = now / 1000 + int(tz.get("bias", 0)) * 60
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(shifted_seconds)
	var month: int = datetime["month"]
	var day: int = datetime["day"]

	return _determine_season(month, day)


## Internal: determines season from month and day.
## Exact season boundaries per design doc:
##   SPRING:  March 21 - June 20
##   SUMMER:  June 21 - September 22
##   MONSOON: September 23 - December 21
##   WINTER:  December 22 - March 20
static func _determine_season(month: int, day: int) -> int:
	# Spring: March 21 - June 20
	if (month == 3 and day >= 21) or (month > 3 and month < 6) or (month == 6 and day <= 20):
		return Kind.SPRING
	# Summer: June 21 - September 22
	elif (month == 6 and day >= 21) or (month > 6 and month < 9) or (month == 9 and day <= 22):
		return Kind.SUMMER
	# Monsoon: September 23 - December 21
	elif (month == 9 and day >= 23) or (month > 9 and month < 12) or (month == 12 and day <= 21):
		return Kind.MONSOON
	# Winter: December 22 - March 20
	else:
		return Kind.WINTER


## Returns the name of a season as a user-facing string.
static func season_name(season: int) -> String:
	match season:
		Kind.SPRING:
			return "Spring"
		Kind.SUMMER:
			return "Summer"
		Kind.MONSOON:
			return "Monsoon"
		Kind.WINTER:
			return "Winter"
		_:
			return "Unknown"
