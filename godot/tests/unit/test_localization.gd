## Localization Phase 1 (docs/architecture/localization-pipeline.md) --
## covers the CSV-translation pipeline actually resolving real English/
## Hindi text for the migrated string keys, and AccessibilitySettings'
## new `locale` field/setter (persistence + the bounded-set guard,
## mirroring test_accessibility_settings.gd's existing coverage shape for
## its other fields).
extends GutTest

const TEST_SAVE_PATH: String = "user://test_locale_accessibility.tres"


func before_each() -> void:
	# TranslationServer is process-global state -- every test resets it to
	# "en" first so an earlier test's locale switch can't leak into a later
	# one (this project's own "must not depend on execution order" rule).
	TranslationServer.set_locale("en")
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func after_each() -> void:
	TranslationServer.set_locale("en")
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


# ---------------------------------------------------------------------------
# CSV -> Translation resource resolves real strings
# ---------------------------------------------------------------------------

func test_english_locale_resolves_migrated_hud_key() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr(&"hud.sell_all"), "Sell All")


func test_hindi_locale_resolves_migrated_hud_key() -> void:
	TranslationServer.set_locale("hi")
	assert_eq(tr(&"hud.sell_all"), "सब बेचें")


func test_english_locale_resolves_migrated_accessibility_key() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr(&"a11y.title"), "♿ Accessibility")


func test_hindi_locale_resolves_migrated_accessibility_key() -> void:
	TranslationServer.set_locale("hi")
	assert_eq(tr(&"a11y.title"), "♿ सुगम्यता")


## A format-string key (used as `tr(...) % percent` at the real call site)
## must survive the CSV round-trip with its `%d%%` placeholder intact, not
## just its literal text -- this is the one migrated key that's actually
## interpolated at runtime, so it's worth its own explicit check.
func test_format_string_key_keeps_its_placeholder() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr(&"a11y.text_size") % 115, "Text Size: 115%")
	TranslationServer.set_locale("hi")
	assert_eq(tr(&"a11y.text_size") % 115, "टेक्स्ट आकार: 115%")


## An unmigrated key must fall through to the key itself (Godot's own
## Translation default), not crash or silently return English text under
## the Hindi locale -- documents the real, honest boundary of what Phase 1
## actually covers rather than leaving it implicit.
func test_unmigrated_key_falls_back_to_the_key_itself() -> void:
	TranslationServer.set_locale("hi")
	assert_eq(tr(&"not.a.real.key"), "not.a.real.key")


## Phase 2 (docs/architecture/localization-pipeline.md) spot-checks --
## farmhouse_tab.gd/mandi_tab.gd's migrated keys, one two-placeholder
## format string from each to catch a placeholder getting dropped or
## reordered in translation, which a single-placeholder check wouldn't.
func test_hindi_locale_resolves_a_farmhouse_two_placeholder_key() -> void:
	TranslationServer.set_locale("hi")
	assert_eq(tr(&"farmhouse.level_of") % [3, 6], "फार्महाउस स्तर 3 / 6")


func test_hindi_locale_resolves_a_mandi_two_placeholder_key() -> void:
	TranslationServer.set_locale("hi")
	assert_eq(tr(&"mandi.tomorrow_forecast") % ["▲", "+", 5], "कल: ▲ +5%")


func test_english_locale_still_resolves_farmhouse_and_mandi_keys() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr(&"farmhouse.current_bonuses"), "Current Bonuses")
	assert_eq(tr(&"mandi.nothing_to_sell"), "Nothing to sell")


# ---------------------------------------------------------------------------
# AccessibilitySettings.locale
# ---------------------------------------------------------------------------

func test_locale_defaults_to_english() -> void:
	var settings := AccessibilitySettings.new()
	assert_eq(settings.locale, "en")


func test_set_locale_to_hindi_updates_the_field() -> void:
	var settings := AccessibilitySettings.new()
	settings.set_locale("hi")
	assert_eq(settings.locale, "hi")


func test_set_locale_rejects_an_unsupported_code() -> void:
	var settings := AccessibilitySettings.new()
	settings.set_locale("fr")
	assert_eq(settings.locale, "en", "an unsupported locale code must be silently rejected, not stored")


func test_set_locale_emits_settings_changed() -> void:
	var settings := AccessibilitySettings.new()
	watch_signals(settings)
	settings.set_locale("hi")
	assert_signal_emitted(settings, "settings_changed")


func test_set_locale_to_the_current_value_does_not_emit_settings_changed() -> void:
	var settings := AccessibilitySettings.new()
	watch_signals(settings)
	settings.set_locale("en")  # already "en" -- a genuine no-op
	assert_signal_not_emitted(settings, "settings_changed")


func test_locale_round_trips_through_save_and_load() -> void:
	var settings := AccessibilitySettings.new()
	settings.set_locale("hi")
	settings.save(TEST_SAVE_PATH)

	var loaded := AccessibilitySettings.load_or_default(TEST_SAVE_PATH)

	assert_eq(loaded.locale, "hi")
