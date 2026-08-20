## Covers accessibility_settings.gd's load_or_default/save round-trip and its
## two documented fallback paths (no prefs file yet, a prefs file that fails
## to load as AccessibilitySettings), plus cycle_text_scale()/
## toggle_colorblind_safe()'s persist-and-emit behavior. Same shape as
## test_save_system.gd's coverage of SaveSystem's equivalent fallback paths
## -- deliberately mirrored, not a new testing idiom.
extends GutTest

const PATH_ROUND_TRIP: String = "user://test_accessibility_round_trip.tres"
const PATH_NO_FILE: String = "user://test_accessibility_does_not_exist.tres"
const PATH_CORRUPT: String = "user://test_accessibility_corrupt.tres"
const PATH_WRONG_TYPE: String = "user://test_accessibility_wrong_type.tres"

const _ALL_PATHS: Array[String] = [
	PATH_ROUND_TRIP,
	PATH_NO_FILE,
	PATH_CORRUPT,
	PATH_WRONG_TYPE,
]


func before_each() -> void:
	_cleanup_files()


func after_each() -> void:
	_cleanup_files()


func _cleanup_files() -> void:
	for path: String in _ALL_PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


# --- No prefs file yet -------------------------------------------------------------

func test_load_or_default_with_no_file_returns_defaults() -> void:
	assert_file_does_not_exist(PATH_NO_FILE)
	var settings := AccessibilitySettings.load_or_default(PATH_NO_FILE)
	assert_almost_eq(settings.text_scale, 1.0, 0.0001)
	assert_false(settings.colorblind_safe)
	assert_almost_eq(settings.master_volume, 1.0, 0.0001)
	assert_almost_eq(settings.ambience_volume, 1.0, 0.0001)
	assert_almost_eq(settings.sfx_volume, 1.0, 0.0001)
	assert_almost_eq(settings.ui_volume, 1.0, 0.0001)
	assert_false(settings.audio_muted)


# --- Corrupt / unreadable prefs -----------------------------------------------------

func test_load_or_default_falls_back_to_defaults_on_unparseable_bytes() -> void:
	var f := FileAccess.open(PATH_CORRUPT, FileAccess.WRITE)
	f.store_string("this is not a valid Godot resource file")
	f.close()
	assert_file_exists(PATH_CORRUPT)

	var settings := AccessibilitySettings.load_or_default(PATH_CORRUPT)
	# Same ResourceLoader.load() parse-failure noise test_save_system.gd's
	# equivalent corrupt-file test already documents and acknowledges.
	assert_engine_error_count(3, "ResourceLoader.load() parse-failure noise, already handled by load_or_default()'s fallback")
	assert_almost_eq(settings.text_scale, 1.0, 0.0001)
	assert_false(settings.colorblind_safe)


func test_load_or_default_falls_back_to_defaults_on_wrong_resource_type() -> void:
	var wrong_resource := Resource.new()
	var save_err := ResourceSaver.save(wrong_resource, PATH_WRONG_TYPE)
	assert_eq(save_err, OK)

	var settings := AccessibilitySettings.load_or_default(PATH_WRONG_TYPE)
	assert_almost_eq(settings.text_scale, 1.0, 0.0001)
	assert_false(settings.colorblind_safe)


# --- Round trip ----------------------------------------------------------------------

func test_save_then_load_or_default_round_trips_both_fields() -> void:
	var settings := AccessibilitySettings.new()
	settings.text_scale = 1.3
	settings.colorblind_safe = true

	var save_ok := settings.save(PATH_ROUND_TRIP)
	assert_true(save_ok)
	assert_file_exists(PATH_ROUND_TRIP)

	var loaded := AccessibilitySettings.load_or_default(PATH_ROUND_TRIP)
	assert_almost_eq(loaded.text_scale, 1.3, 0.0001)
	assert_true(loaded.colorblind_safe)


func test_save_then_load_or_default_round_trips_audio_fields() -> void:
	var settings := AccessibilitySettings.new()
	settings.master_volume = 0.6
	settings.ambience_volume = 0.4
	settings.sfx_volume = 0.75
	settings.ui_volume = 0.2
	settings.audio_muted = true

	var save_ok := settings.save(PATH_ROUND_TRIP)
	assert_true(save_ok)
	assert_file_exists(PATH_ROUND_TRIP)

	var loaded := AccessibilitySettings.load_or_default(PATH_ROUND_TRIP)
	assert_almost_eq(loaded.master_volume, 0.6, 0.0001)
	assert_almost_eq(loaded.ambience_volume, 0.4, 0.0001)
	assert_almost_eq(loaded.sfx_volume, 0.75, 0.0001)
	assert_almost_eq(loaded.ui_volume, 0.2, 0.0001)
	assert_true(loaded.audio_muted)


# --- cycle_text_scale() ----------------------------------------------------------------

func test_cycle_text_scale_advances_through_all_steps_and_wraps() -> void:
	var settings := AccessibilitySettings.new()
	assert_almost_eq(settings.text_scale, 1.0, 0.0001)

	settings.cycle_text_scale()
	assert_almost_eq(settings.text_scale, 1.15, 0.0001)

	settings.cycle_text_scale()
	assert_almost_eq(settings.text_scale, 1.3, 0.0001)

	settings.cycle_text_scale()
	assert_almost_eq(settings.text_scale, 1.0, 0.0001)


func test_cycle_text_scale_emits_changed() -> void:
	var settings := AccessibilitySettings.new()
	watch_signals(settings)
	settings.cycle_text_scale()
	assert_signal_emitted(settings, "settings_changed")


# --- toggle_colorblind_safe() ------------------------------------------------------------

func test_toggle_colorblind_safe_flips_the_flag_each_call() -> void:
	var settings := AccessibilitySettings.new()
	assert_false(settings.colorblind_safe)

	settings.toggle_colorblind_safe()
	assert_true(settings.colorblind_safe)

	settings.toggle_colorblind_safe()
	assert_false(settings.colorblind_safe)


func test_toggle_colorblind_safe_emits_changed() -> void:
	var settings := AccessibilitySettings.new()
	watch_signals(settings)
	settings.toggle_colorblind_safe()
	assert_signal_emitted(settings, "settings_changed")


# --- Audio pass: per-bus volume setters + mute -----------------------------------------

func test_set_master_volume_clamps_to_zero_one_range_and_emits_changed() -> void:
	var settings := AccessibilitySettings.new()
	watch_signals(settings)

	settings.set_master_volume(0.5)
	assert_almost_eq(settings.master_volume, 0.5, 0.0001)
	assert_signal_emitted(settings, "settings_changed")

	settings.set_master_volume(5.0)
	assert_almost_eq(settings.master_volume, 1.0, 0.0001)

	settings.set_master_volume(-2.0)
	assert_almost_eq(settings.master_volume, 0.0, 0.0001)


func test_set_ambience_volume_clamps_and_emits_changed() -> void:
	var settings := AccessibilitySettings.new()
	watch_signals(settings)
	settings.set_ambience_volume(0.3)
	assert_almost_eq(settings.ambience_volume, 0.3, 0.0001)
	assert_signal_emitted(settings, "settings_changed")
	settings.set_ambience_volume(-1.0)
	assert_almost_eq(settings.ambience_volume, 0.0, 0.0001)


func test_set_sfx_volume_clamps_and_emits_changed() -> void:
	var settings := AccessibilitySettings.new()
	watch_signals(settings)
	settings.set_sfx_volume(0.9)
	assert_almost_eq(settings.sfx_volume, 0.9, 0.0001)
	assert_signal_emitted(settings, "settings_changed")
	settings.set_sfx_volume(3.0)
	assert_almost_eq(settings.sfx_volume, 1.0, 0.0001)


func test_set_ui_volume_clamps_and_emits_changed() -> void:
	var settings := AccessibilitySettings.new()
	watch_signals(settings)
	settings.set_ui_volume(0.1)
	assert_almost_eq(settings.ui_volume, 0.1, 0.0001)
	assert_signal_emitted(settings, "settings_changed")
	settings.set_ui_volume(-0.5)
	assert_almost_eq(settings.ui_volume, 0.0, 0.0001)


func test_toggle_audio_muted_flips_the_flag_each_call() -> void:
	var settings := AccessibilitySettings.new()
	assert_false(settings.audio_muted)

	settings.toggle_audio_muted()
	assert_true(settings.audio_muted)

	settings.toggle_audio_muted()
	assert_false(settings.audio_muted)


func test_toggle_audio_muted_emits_changed() -> void:
	var settings := AccessibilitySettings.new()
	watch_signals(settings)
	settings.toggle_audio_muted()
	assert_signal_emitted(settings, "settings_changed")
