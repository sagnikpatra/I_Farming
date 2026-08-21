## Covers TimeOfDay's pure logic (design/gdd/real-time-day-night.md) --
## local_hour()/phase_for_hour()/preset_for_phase(). Node construction/
## application to the live WorldEnvironment/DirectionalLight3D is
## explicitly NOT covered here, per this project's testing standards
## ("Visual/Feel" gets screenshot evidence, not automated tests).
extends GutTest


# --- local_hour() -- pure function, explicit inputs only -----------------------

func test_local_hour_reads_the_correct_utc_hour_at_zero_offset() -> void:
	# 2026-08-22T14:16:40Z
	var now_ms: int = 1787408200000
	assert_eq(TimeOfDay.local_hour(now_ms, 0), 14)


func test_local_hour_shifts_with_timezone_offset() -> void:
	var now_ms: int = 1787408200000  # 14:16:40 UTC
	assert_eq(TimeOfDay.local_hour(now_ms, 5 * 60 + 30), 19)  # UTC+5:30 -> 19:46
	assert_eq(TimeOfDay.local_hour(now_ms, -8 * 60), 6)  # UTC-8 -> 06:16


# --- phase_for_hour() -----------------------------------------------------------

func test_phase_dawn_hours() -> void:
	assert_eq(TimeOfDay.phase_for_hour(5), TimeOfDay.Phase.DAWN)
	assert_eq(TimeOfDay.phase_for_hour(6), TimeOfDay.Phase.DAWN)


func test_phase_day_hours() -> void:
	assert_eq(TimeOfDay.phase_for_hour(7), TimeOfDay.Phase.DAY)
	assert_eq(TimeOfDay.phase_for_hour(12), TimeOfDay.Phase.DAY)
	assert_eq(TimeOfDay.phase_for_hour(17), TimeOfDay.Phase.DAY)


func test_phase_dusk_hours() -> void:
	assert_eq(TimeOfDay.phase_for_hour(18), TimeOfDay.Phase.DUSK)
	assert_eq(TimeOfDay.phase_for_hour(19), TimeOfDay.Phase.DUSK)


func test_phase_night_hours_wrap_across_midnight() -> void:
	assert_eq(TimeOfDay.phase_for_hour(20), TimeOfDay.Phase.NIGHT)
	assert_eq(TimeOfDay.phase_for_hour(23), TimeOfDay.Phase.NIGHT)
	assert_eq(TimeOfDay.phase_for_hour(0), TimeOfDay.Phase.NIGHT)
	assert_eq(TimeOfDay.phase_for_hour(4), TimeOfDay.Phase.NIGHT)


func test_phase_boundaries_are_exact() -> void:
	# The real check is hour >= 5 and hour <= 6 etc. -- exact boundary
	# values pinned down explicitly (this project's testing standard's
	# stated exception to "no hardcoded magic numbers" at a boundary).
	assert_eq(TimeOfDay.phase_for_hour(4), TimeOfDay.Phase.NIGHT)
	assert_eq(TimeOfDay.phase_for_hour(5), TimeOfDay.Phase.DAWN)
	assert_eq(TimeOfDay.phase_for_hour(6), TimeOfDay.Phase.DAWN)
	assert_eq(TimeOfDay.phase_for_hour(7), TimeOfDay.Phase.DAY)
	assert_eq(TimeOfDay.phase_for_hour(17), TimeOfDay.Phase.DAY)
	assert_eq(TimeOfDay.phase_for_hour(18), TimeOfDay.Phase.DUSK)
	assert_eq(TimeOfDay.phase_for_hour(19), TimeOfDay.Phase.DUSK)
	assert_eq(TimeOfDay.phase_for_hour(20), TimeOfDay.Phase.NIGHT)


# --- preset_for_phase() ----------------------------------------------------------

func test_day_preset_matches_the_scenes_existing_defaults_exactly() -> void:
	# village_board.tscn's Environment/DirectionalLight3D SubResources --
	# copied verbatim, not re-derived, so there's no drift risk (see the
	# GDD's own §4 note).
	var preset := TimeOfDay.preset_for_phase(TimeOfDay.Phase.DAY)
	assert_eq(preset["sky_color"], Color(0.63, 0.77, 0.86))
	assert_eq(preset["ambient_color"], Color(1.0, 0.95, 0.85))
	assert_almost_eq(preset["ambient_energy"], 0.45, 0.0001)
	assert_eq(preset["sun_color"], Color(1.0, 0.93, 0.78))
	assert_almost_eq(preset["sun_energy"], 0.55, 0.0001)


func test_every_phase_returns_a_complete_distinct_preset() -> void:
	var phases: Array = [TimeOfDay.Phase.DAWN, TimeOfDay.Phase.DAY, TimeOfDay.Phase.DUSK, TimeOfDay.Phase.NIGHT]
	var seen_sky_colors: Array = []
	for phase in phases:
		var preset := TimeOfDay.preset_for_phase(phase)
		for key in ["sky_color", "ambient_color", "ambient_energy", "sun_color", "sun_energy"]:
			assert_true(preset.has(key), "missing key %s for phase %d" % [key, phase])
		assert_false(seen_sky_colors.has(preset["sky_color"]), "phase %d reuses another phase's sky color" % phase)
		seen_sky_colors.append(preset["sky_color"])
