## Covers AccessibilitySheet's real button/slider-to-AccessibilitySettings
## wiring -- a gap found 2026-08-23: `test_accessibility_settings.gd`
## already covers every setter in isolation, but nothing drove the actual
## UI nodes this sheet builds (does pressing the real Button/dragging the
## real HSlider genuinely call into those setters, the same "don't trust
## the code compiles, drive the real node" standard
## test_growing_info_card.gd/test_decoration_info_card.gd already hold
## themselves to for their own sheets).
extends GutTest

const AccessibilitySheetScene := preload("res://scenes/ui/accessibility_sheet.tscn")


func before_each() -> void:
	# Every setter under test calls AccessibilitySettings.save(), a real
	# disk write to AccessibilitySettings.SAVE_PATH -- same test-isolation
	# class of bug RealSavePaths.wipe_all() was built to close (see that
	# file's own doc comment).
	RealSavePaths.wipe_all()


func after_each() -> void:
	RealSavePaths.wipe_all()


func _find_button_with_text(node: Node, substring: String) -> Button:
	if node is Button and (node as Button).text.contains(substring):
		return node
	for child in node.get_children():
		var found := _find_button_with_text(child, substring)
		if found:
			return found
	return null


func _find_all_sliders(node: Node, out: Array[HSlider]) -> void:
	if node is HSlider:
		out.append(node)
	for child in node.get_children():
		_find_all_sliders(child, out)


## configure() must be called before this instance enters the tree (see
## accessibility_sheet.gd's own doc comment on configure()) -- unlike
## villager_info_card.gd's configure(), this one has no defensive
## is_inside_tree() re-populate check, so _ready()'s _populate() would run
## against a still-null _settings if the order were reversed.
func _build_sheet(settings: AccessibilitySettings) -> AccessibilitySheet:
	var sheet := AccessibilitySheetScene.instantiate() as AccessibilitySheet
	sheet.configure(settings, null)
	add_child_autofree(sheet)
	return sheet


func test_pressing_cycle_text_size_advances_the_real_setting() -> void:
	var settings := AccessibilitySettings.new()
	assert_eq(settings.text_scale, 1.0, "precondition")

	var sheet := _build_sheet(settings)
	var button := _find_button_with_text(sheet, tr(&"a11y.cycle_text_size"))
	assert_not_null(button, "expected a real Cycle Text Size button")
	button.pressed.emit()

	assert_eq(settings.text_scale, AccessibilitySettings.TEXT_SCALE_STEPS[1], "the real button press must advance the real setting, not just look clickable")


func test_pressing_the_colorblind_toggle_flips_the_real_setting() -> void:
	var settings := AccessibilitySettings.new()
	assert_false(settings.colorblind_safe, "precondition")
	var sheet := _build_sheet(settings)
	var button := _find_button_with_text(sheet, tr(&"a11y.turn_on"))
	assert_not_null(button, "expected a real 'turn on' toggle when colorblind_safe starts false")

	button.pressed.emit()

	assert_true(settings.colorblind_safe)


func test_pressing_the_language_toggle_flips_the_real_locale() -> void:
	var settings := AccessibilitySettings.new()
	assert_eq(settings.locale, "en", "precondition")
	var sheet := _build_sheet(settings)
	var button := _find_button_with_text(sheet, tr(&"a11y.language_english"))
	assert_not_null(button, "expected the button to show the CURRENT language (English) as its label")

	button.pressed.emit()

	assert_eq(settings.locale, "hi")


func test_pressing_mute_all_flips_the_real_audio_muted_flag() -> void:
	var settings := AccessibilitySettings.new()
	assert_false(settings.audio_muted, "precondition")
	var sheet := _build_sheet(settings)
	var button := _find_button_with_text(sheet, tr(&"a11y.mute_all"))
	assert_not_null(button, "expected a real Mute All button when audio_muted starts false")

	button.pressed.emit()

	assert_true(settings.audio_muted)


## _build_audio_row() adds sliders in a fixed order: Master, Ambience, SFX,
## UI (see accessibility_sheet.gd's own _build_audio_row()) -- index 0 is
## always the master volume slider, not a guess.
func test_dragging_the_master_volume_slider_updates_the_real_setting() -> void:
	var settings := AccessibilitySettings.new()
	var sheet := _build_sheet(settings)
	var sliders: Array[HSlider] = []
	_find_all_sliders(sheet, sliders)
	assert_eq(sliders.size(), 4, "expected exactly 4 volume sliders (Master/Ambience/SFX/UI)")

	sliders[0].value_changed.emit(0.4)

	assert_almost_eq(settings.master_volume, 0.4, 0.001, "dragging the real slider must call the real setter, not just move visually")


func test_configure_reflects_the_given_settings_not_hardcoded_defaults() -> void:
	# A card built against non-default settings must show that reality
	# (e.g. an already-colorblind-safe player sees "turn off", not "turn
	# on") -- guards against the row builders silently assuming defaults.
	var settings := AccessibilitySettings.new()
	settings.colorblind_safe = true
	var sheet := _build_sheet(settings)

	var button := _find_button_with_text(sheet, tr(&"a11y.turn_off"))
	assert_not_null(button, "a colorblind_safe=true sheet must offer to turn it OFF, not ON")
