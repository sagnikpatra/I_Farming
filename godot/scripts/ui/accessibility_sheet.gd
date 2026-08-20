## Accessibility settings sheet -- closes the BLOCKING §0 finding in
## production/qa/accessibility/village-board-and-management-sheets-audit-
## 2026-08-21.md ("no accessibility settings screen exists at all"). Opened
## via hud.gd's new gear-icon button (_on_accessibility_pressed()), same
## BottomSheet-reuse pattern every other management sheet/picker uses.
##
## Two controls today, matching AccessibilitySettings' two fields:
## - Text size: cycles AccessibilitySettings.TEXT_SCALE_STEPS (100%/115%/
##   130%). Applies to hud.gd's own labels immediately on next HUD build --
##   this sheet does NOT live-rebuild HUD's already-constructed containers
##   (that would mean queue_free()-ing and rebuilding five interdependent
##   Control trees with no on-device verification pass available this
##   round -- a real risk of a new bug for a codebase this careful about
##   verifying UI changes on-device, see hud.gd's own precedent comments).
##   The sheet says so explicitly (see _build_text_scale_row()'s hint
##   label) rather than silently under-delivering.
## - Colorblind-safe palette: toggles AccessibilitySettings.colorblind_safe,
##   which VillageBoard already applies live (see village_board.gd's
##   _on_accessibility_settings_changed()) -- safe to hot-reload because it
##   reuses rebuild(), the same call every other board mutation already
##   goes through.
##
## Audio sliders (Master/Music/SFX/etc, per accessibility-specialist.md's
## Audio Accessibility standards) are deliberately NOT here yet -- no audio
## system exists in this codebase at all (see the audit's §7, DEFER). Add
## them here once EPIC-M8's audio pass lands.
##
## ARCHITECTURE: same "small static shell (Scroll/Body only) + procedural
## content built in _populate()" split every other ported sheet in this
## directory uses -- see farmhouse_tab.gd's header comment for the
## rationale; not a new idiom.
class_name AccessibilitySheet
extends VBoxContainer

# Palette -- ported verbatim, same values every sibling *_tab.gd/*_card.gd
# file already duplicates its own copy of (see farmhouse_tab.gd's header
# comment on this project's established per-file duplication convention).
const SOIL_BROWN_DARK := Color("#3E2412")
const WOOD_BROWN_LIGHT := Color("#8A5A34")
const GOLD_LIGHT := Color("#FFE082")
const FIELD_GREEN := Color("#4CAF50")
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.7)

@onready var _body: VBoxContainer = $Scroll/Body

var _settings: AccessibilitySettings
var _village_board: VillageBoard


## Must be called before this instance is added under a BottomSheet's
## content slot -- same precondition/ordering guarantee as every other
## ported sheet's configure() method.
func configure(settings: AccessibilitySettings, village_board: VillageBoard) -> void:
	_settings = settings
	_village_board = village_board


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_populate()


func _populate() -> void:
	for child in _body.get_children():
		child.queue_free()

	_body.add_child(_make_title_label("♿ Accessibility", 20, SOIL_BROWN_DARK))
	_body.add_child(_build_text_scale_row())
	_body.add_child(_build_colorblind_row())
	_body.add_child(_build_audio_row())


# ---------------------------------------------------------------------------
# Widget construction
# ---------------------------------------------------------------------------

func _build_text_scale_row() -> PanelContainer:
	var card := _make_panel(WOOD_BROWN_LIGHT, 12)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)

	var percent := roundi(_settings.text_scale * 100.0)
	box.add_child(_make_title_label("Text Size: %d%%" % percent, 16))

	var cycle_button := _make_chunky_button("Cycle Text Size", FIELD_GREEN)
	cycle_button.pressed.connect(_on_cycle_text_scale_pressed)
	box.add_child(cycle_button)

	var hint := _make_title_label(
		"Takes effect next time you open the app.", 12, Color(1.0, 1.0, 1.0, 0.8)
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(hint)

	card.add_child(box)
	return card


func _build_colorblind_row() -> PanelContainer:
	var card := _make_panel(WOOD_BROWN_LIGHT, 12)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)

	box.add_child(_make_title_label("Colorblind-Safe Palette", 16))
	var description := _make_title_label(
		(
			"Switches Growing/Ready-to-Harvest plot colors to a blue/orange "
			+ "pair, and applies immediately."
		),
		12
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(description)

	var toggle_label := "Turn Off" if _settings.colorblind_safe else "Turn On"
	var toggle_button := _make_chunky_button(toggle_label, SOIL_BROWN_DARK)
	toggle_button.pressed.connect(_on_toggle_colorblind_pressed)
	box.add_child(toggle_button)

	card.add_child(box)
	return card


## Audio pass (design/audio/audio-core-gameplay-loop.md): a "Mute All Audio"
## toggle button above 4 volume sliders (Master/Ambience/SFX/UI). See
## _build_volume_slider_row()'s own doc comment for why slider drags update
## their label directly instead of calling _populate() (unlike every other
## button-driven row in this file).
func _build_audio_row() -> PanelContainer:
	var card := _make_panel(WOOD_BROWN_LIGHT, 12)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)

	box.add_child(_make_title_label("🔊 Audio", 16))

	var mute_label_text := "Unmute Audio" if _settings.audio_muted else "Mute All Audio"
	var mute_button := _make_chunky_button(mute_label_text, SOIL_BROWN_DARK)
	mute_button.pressed.connect(_on_toggle_audio_muted_pressed)
	box.add_child(mute_button)

	box.add_child(_build_volume_slider_row("Master Volume", _settings.master_volume, _settings.set_master_volume))
	box.add_child(_build_volume_slider_row("Ambience Volume", _settings.ambience_volume, _settings.set_ambience_volume))
	box.add_child(_build_volume_slider_row("Sound Effects Volume", _settings.sfx_volume, _settings.set_sfx_volume))
	box.add_child(_build_volume_slider_row("UI Sounds Volume", _settings.ui_volume, _settings.set_ui_volume))

	card.add_child(box)
	return card


## One label+HSlider pair. Updates the percentage label directly from the
## slider's live `value_changed` signal instead of calling _populate() on
## every tick (unlike this file's button-driven rows) -- HSlider fires
## value_changed continuously while being dragged, and rebuilding this
## card's whole widget tree mid-drag would destroy and recreate the very
## slider the player has their finger on, breaking the drag gesture. The
## setter itself (e.g. AccessibilitySettings.set_master_volume()) still
## persists + emits `settings_changed` on every tick, which is what
## actually applies the change live via village_board.gd's
## _on_accessibility_settings_changed() -- only this card's own label text
## is updated directly (via the captured `percent_label`/`label_text`
## closure) rather than through a full rebuild.
func _build_volume_slider_row(label_text: String, initial_value: float, setter: Callable) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var percent_label := _make_title_label("%s: %d%%" % [label_text, roundi(initial_value * 100.0)], 13)
	row.add_child(percent_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.custom_minimum_size = Vector2(0, 32)
	slider.value_changed.connect(func(value: float) -> void:
		setter.call(value)
		percent_label.text = "%s: %d%%" % [label_text, roundi(value * 100.0)]
	)
	row.add_child(slider)
	return row


func _on_toggle_audio_muted_pressed() -> void:
	_settings.toggle_audio_muted()
	_populate()


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_cycle_text_scale_pressed() -> void:
	_settings.cycle_text_scale()
	_populate()


func _on_toggle_colorblind_pressed() -> void:
	_settings.toggle_colorblind_safe()
	_populate()


# ---------------------------------------------------------------------------
# Shared widget helpers -- same shapes as every sibling *_tab.gd file.
# ---------------------------------------------------------------------------

func _make_chunky_button(label_text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = label_text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(20)
	style.set_border_width_all(2)
	style.border_color = SOIL_BROWN_DARK
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	for state_name in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state_name, style)
	for color_slot in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_slot, Color.WHITE)
	button.add_theme_font_size_override("font_size", 14)
	return button


func _make_panel(bg_color: Color, corner_radius: int, border_color: Color = GOLD_LIGHT) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(corner_radius)
	style.set_border_width_all(2)
	style.border_color = border_color
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_title_label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.label_settings = _make_label_settings(font_size, color)
	return label


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.shadow_size = 4
	settings.shadow_color = TEXT_SHADOW_COLOR
	settings.shadow_offset = Vector2(2, 3)
	return settings
