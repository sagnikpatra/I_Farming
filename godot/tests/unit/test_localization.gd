## Localization Phase 1 (docs/architecture/localization-pipeline.md) --
## covers the CSV-translation pipeline actually resolving real English/
## Hindi text for the migrated string keys, and AccessibilitySettings'
## new `locale` field/setter (persistence + the bounded-set guard,
## mirroring test_accessibility_settings.gd's existing coverage shape for
## its other fields).
extends GutTest

const TEST_SAVE_PATH: String = "user://test_locale_accessibility.tres"

## Defensively normalize first, in both directions -- TranslationServer is
## process-global state, AND AccessibilitySettings.set_locale() (like every
## setter in that class) always save()s to the real default
## user://accessibility.tres unless given a test-only path. This file's own
## tests call set_locale() on bare AccessibilitySettings.new() instances
## without a test-only path -- so beyond the in-memory
## TranslationServer.set_locale("en") reset, the REAL persisted file must
## also be wiped (RealSavePaths.wipe_all(), see that file's own doc comment
## for the full history), or ANY later test in the suite that instantiates a
## fresh VillageBoard (which loads AccessibilitySettings.load_or_default()
## from that same real path in _ready() and immediately applies its locale
## to the global TranslationServer) silently inherits a contaminated locale
## -- a real, reproducible failure this exposed in test_seed_picker.gd, a
## file that never even touches locale itself.
func before_each() -> void:
	TranslationServer.set_locale("en")
	RealSavePaths.wipe_all()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func after_each() -> void:
	TranslationServer.set_locale("en")
	RealSavePaths.wipe_all()
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


## Same slice, extended for the polyhouse_tab.gd/agroforestry_tab.gd/
## niche_farming_tab.gd migration -- one format-string key from each file.
func test_hindi_locale_resolves_polyhouse_agroforestry_niche_keys() -> void:
	TranslationServer.set_locale("hi")
	assert_eq(tr(&"polyhouse.build_button") % 50000, "₹50000 में बनाएं")
	assert_eq(tr(&"agroforestry.build_button") % 20000, "₹20000 में भूमि साफ़ करें")
	assert_eq(tr(&"niche.electricity_pay") % 500, "⚡ बिजली भुगतान करें ₹500")


func test_english_locale_still_resolves_polyhouse_agroforestry_niche_keys() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr(&"polyhouse.subsidy_quest"), "Subsidy Quest")
	assert_eq(tr(&"agroforestry.hint"), "Plant a host next to an empty tile, then Sandalwood beside the host.")
	assert_eq(tr(&"niche.vertical_farm_title"), "Build a Vertical Farm")


## open_field_tab.gd/events_tab.gd -- the CSV row exercised here
## (events.chanda_blessing_active) is the one with an embedded comma in its
## Hindi text, requiring real CSV quoting; this test would catch a silently
## truncated/misparsed row (a real mistake caught and fixed while authoring
## this same CSV -- worth a permanent regression check, not just a one-time
## manual fix).
func test_hindi_locale_resolves_events_key_with_an_embedded_comma() -> void:
	TranslationServer.set_locale("hi")
	assert_eq(tr(&"events.chanda_blessing_active") % [10, "5m"], "🙏 आशीर्वाद सक्रिय -- +10% बिक्री मूल्य, 5m तक")


func test_hindi_locale_resolves_open_field_header() -> void:
	TranslationServer.set_locale("hi")
	assert_eq(tr(&"open_field.header"), "🌾 खुला खेत")


func test_english_locale_still_resolves_events_keys() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr(&"events.reroll_unavailable"), "Reroll unavailable -- progress made today")
	assert_eq(tr(&"events.tier_reward_locked") % [100, 50], "₹100 (+₹50 🔒)")


## The 3 pickers -- seed_picker.gd/agro_plant_picker.gd have player-facing
## strings inside a `static func` (build_row_data()/format_crop_details()),
## which cannot call tr() (an Object/Node instance method) and must use
## TranslationServer.translate() instead -- a real parse error caught while
## authoring this slice (SeedPicker.format_crop_details() originally used
## tr() and failed to even load). This test exercises that exact path, not
## just the CSV lookup tr() already covers elsewhere in this file.
func test_hindi_locale_resolves_a_static_function_translation() -> void:
	TranslationServer.set_locale("hi")
	assert_eq(TranslationServer.translate(&"agro_plant.sandalwood_details") % [3, 5000], "3+ दिन · ₹5000 में बिकता है")

	var wheat_def := GameData.crop_def(CropType.Kind.WHEAT)
	assert_true(SeedPicker.format_crop_details(wheat_def).contains("बिकता है"), "format_crop_details() must actually resolve the Hindi translation via TranslationServer.translate(), not silently fall back to English")


func test_english_locale_still_resolves_picker_keys() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr(&"seed_picker.title"), "Choose a seed to plant")
	assert_eq(tr(&"agro_plant.title"), "Plant on this tile")
	assert_eq(tr(&"decoration_picker.title"), "Choose a decoration to place")


## decoration_info_card.gd/growing_info_card.gd/worker_assignment_row.gd --
## the last mechanical sweep of Phase 2.
func test_hindi_locale_resolves_info_card_and_worker_row_keys() -> void:
	TranslationServer.set_locale("hi")
	assert_eq(tr(&"decoration_info.remove_button"), "हटाएं")
	assert_eq(tr(&"growing_info.skip_button") % 10, "⏩ स्किप करें (10 जेम्स)")
	assert_eq(tr(&"worker_row.status") % "Knight", "Knight इस क्षेत्र में काम कर रहा है।")


## Regression guard for test_worker_assignment_row.gd's own exact-text
## button lookups (n.text == "Assign"/"Unassign") -- those must keep
## matching under the default English locale after this migration.
func test_english_locale_worker_row_button_text_is_unchanged() -> void:
	TranslationServer.set_locale("en")
	assert_eq(tr(&"worker_row.assign_button"), "Assign")
	assert_eq(tr(&"worker_row.unassign_button"), "Unassign")


# ---------------------------------------------------------------------------
# game_economy.gd's _push_event() message strings (Phase 3) -- the highest-
# risk slice of this whole migration: Godot's `%` string formatting is
# strictly POSITIONAL (no {0}/{1} explicit indices), so a translation that
# reorders a %s/%d pair from the original English argument order doesn't
# just read wrong -- feeding a String into a %d slot raises a real runtime
# error. These tests exercise the real multi-argument keys through real
# GameEconomy actions (not just CSV lookups) specifically to catch that
# class of mistake, not just confirm text length/presence.
# ---------------------------------------------------------------------------

func test_hindi_locale_resolves_a_four_argument_event_message_in_order() -> void:
	# event.mandi_sold: [units_sold(%d), display_name(%s), pct(%d), total_value(%d)]
	TranslationServer.set_locale("hi")
	var text := tr(&"event.mandi_sold") % [5, "गेहूं", 92, 450]
	assert_eq(text, "मंडी ने 5 गेहूं को 92% बाज़ार दर पर ₹450 में खरीदा")


func test_hindi_locale_resolves_a_real_rejection_event_from_game_economy() -> void:
	# The real end-to-end path: a genuine blocked GameEconomy action's
	# message, drained exactly as hud.gd's toast would show it -- not a
	# synthetic tr() call in isolation. Cost computed via the real
	# GameData function rather than a hardcoded guess, so this doesn't
	# silently drift if the constant ever changes.
	TranslationServer.set_locale("hi")
	var economy := GameEconomy.new(GameState.new())
	economy.state.coins = 0
	var expected_cost := GameData.polyhouse_cost(GameData.is_subsidy_unlocked(economy.state.total_harvests))

	economy.buy_polyhouse()

	var event := economy.pop_event()
	assert_eq(event.message, "पॉलीहाउस बनाने के लिए ₹%d चाहिए।" % expected_cost)
	assert_true(event.is_rejection)
	TranslationServer.set_locale("en")


func test_english_locale_still_resolves_a_real_success_event_from_game_economy() -> void:
	TranslationServer.set_locale("en")
	var economy := GameEconomy.new(GameState.new())
	economy.state.coins = 1_000_000

	economy.buy_polyhouse()

	var event := economy.pop_event()
	assert_eq(event.message, "🏠 Polyhouse built! Colored Capsicum and Dutch Rose are now available.")
	assert_false(event.is_rejection)


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
